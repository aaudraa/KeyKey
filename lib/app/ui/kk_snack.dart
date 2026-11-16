import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/core/platform/sensitive_clipboard.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Bildirimdeki düğme ("Geri al" gibi).
final class KkSnackAction {
  const new({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

/// Ekrandaki bildirim ve bağlı olduğu katman. Aynı anda tek bildirim olur.
OverlayEntry? _entry;
OverlayState? _overlay;

/// Üstten inen cam bildirim. Kök gezginin katmanına eklenir; gösteren ekran
/// kapansa da kalır, alttan açılan pencerelerin de üstünde durur. Öncekini
/// kapatıp yerine geçer.
void showKkSnack(
  BuildContext context,
  String message, {
  KkSnackAction? action,
}) {
  final overlay = Navigator.of(context, rootNavigator: true).overlay!;
  _removeNow();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => KkSnack(
      message: message,
      action: action,
      onDismissed: () {
        if (identical(_entry, entry)) _removeNow();
      },
    ),
  );
  _entry = entry;
  _overlay = overlay;
  overlay.insert(entry);
}

/// Bildirimi sonra göstermek için bir ekranın bağlamından alınan işlev. `await`
/// öncesinde alınır: o arada ekran kapansa da bildirim kök gezginde çıkar.
typedef KkSnackShow = void Function(String message, {KkSnackAction? action});

KkSnackShow kkSnackFor(BuildContext context) {
  final root = Navigator.of(context, rootNavigator: true).context;
  return (message, {action}) {
    if (root.mounted) showKkSnack(root, message, action: action);
  };
}

/// Açık bildirimi hemen kapatır (ör. kasa kilitlenince).
void hideKkSnack() => _removeNow();

void _removeNow() {
  final entry = _entry;
  final overlay = _overlay;
  _entry = null;
  _overlay = null;
  // Katman artık ağaçta değilse (uygulama yeniden kuruldu) yapacak iş yok.
  if (entry == null || overlay == null || !overlay.mounted) return;
  void remove() {
    if (overlay.mounted) entry.remove();
  }

  // Çizim sırasında katman değiştirilemez; kare bitince kaldırılır.
  if (SchedulerBinding.instance.schedulerPhase ==
      SchedulerPhase.persistentCallbacks) {
    SchedulerBinding.instance.addPostFrameCallback((_) => remove());
  } else {
    remove();
  }
}

/// Durum çubuğunun altında ortada duran cam hap.
class KkSnack extends StatefulWidget {
  const new({
    required this.message,
    required this.onDismissed,
    this.action,
    super.key,
  });

  /// Hapın kendisi; testler yerini ve boyunu bununla ölçer.
  static const pillKey = Key('kk-snack-pill');

  /// Yukarı bu kadar kaydırılınca kapanır.
  static const double _dismissDrag = 24;

  final String message;
  final KkSnackAction? action;
  final VoidCallback onDismissed;

  @override
  State<KkSnack> createState() => _KkSnackState();
}

class _KkSnackState extends State<KkSnack> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  late final Animation<double> _shown = CurvedAnimation(
    parent: _controller,
    curve: KkMotion.standard,
    reverseCurve: KkMotion.exit,
  );
  Timer? _timer;
  bool _started = false;
  bool _closing = false;
  double _drag = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller
      ..duration = KkMotion.of(context, KkMotion.base)
      ..reverseDuration = KkMotion.of(context, KkMotion.panelClose);
    if (_started) return;
    _started = true;
    _controller.forward();
    // TalkBack açıkken düğmeye ulaşmak uzun sürer; düğmeli bildirim
    // kendiliğinden kapanmaz.
    final hasAction = widget.action != null;
    if (hasAction && MediaQuery.accessibleNavigationOf(context)) return;
    _timer = Timer(
      hasAction ? KkMotion.snackWithAction : KkMotion.snack,
      _dismiss,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() => _drag = (_drag + details.delta.dy).clamp(-200, 0));
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_drag <= -KkSnack._dismissDrag || velocity < -300) {
      unawaited(_dismiss());
    } else {
      setState(() => _drag = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: ink,
    );
    final action = widget.action;
    final pill = GlassSurface(
      key: KkSnack.pillKey,
      blur: true,
      strong: true,
      borderRadius: const BorderRadius.all(Radius.circular(28)),
      padding: EdgeInsets.only(
        left: 20,
        right: action == null ? 20 : 8,
        top: 14,
        bottom: 14,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(widget.message, style: textStyle)),
            if (action != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  if (_closing) return;
                  action.onPressed();
                  unawaited(_dismiss());
                },
                style: TextButton.styleFrom(
                  foregroundColor: ink,
                  textStyle: textStyle?.copyWith(fontWeight: FontWeight.w800),
                ),
                child: Text(action.label),
              ),
            ],
          ],
        ),
      ),
    );
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 16,
      right: 16,
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedBuilder(
          animation: _shown,
          builder: (context, child) => Opacity(
            opacity: _shown.value.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, _drag - (1 - _shown.value) * 32),
              child: child,
            ),
          ),
          child: GestureDetector(
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Semantics(container: true, liveRegion: true, child: pill),
          ),
        ),
      ),
    );
  }
}

/// Gizli bir değeri (parola, kod) güvenli panoya kopyalar ve bildirir. Pano
/// 30 saniye sonra temizlenir. Kasa bu arada kilitlenirse sessizce geçer
/// (`false`): yönlendirme zaten kilit ekranına gidiyor.
Future<bool> copySensitive(
  BuildContext context,
  WidgetRef ref,
  String value,
) async {
  final l10n = AppLocalizations.of(context);
  try {
    await ref.read(sensitiveClipboardProvider).copy(value);
  } on VaultLockedException {
    return false;
  }
  if (!context.mounted) return true;
  showKkSnack(
    context,
    l10n.copiedWillClear(SensitiveClipboard.clearAfter.inSeconds),
  );
  return true;
}

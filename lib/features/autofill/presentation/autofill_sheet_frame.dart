import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:keykey/app/ui/keykey_logo.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Doldurma ekranının çerçevesi: arkadaki uygulama hafifçe karartılmış
/// görünür, KeyKey'in içeriği alttan açılan yarım penceredir.
///
/// Pencere arkasını bulanıklaştırmaz; kendi opak zeminini ve lekelerini
/// çizer. Karartılmış alana dokunmak, tutamacı hızlı aşağı kaydırmak ya da
/// pencerenin yarısından fazla aşağı çekmek [onDismiss] çağırır; doldurma
/// ekranında bu hiçbir şey doldurmadan kapatır.
class AutofillSheetFrame extends StatefulWidget {
  const new({
    required this.child,
    required this.onDismiss,
    this.expanded = false,
    super.key,
  });

  /// Tutamak; testler aşağı kaydırmayı bunun üzerinden yapar.
  static const handleKey = Key('autofill-sheet-handle');

  /// Karartmanın koyuluğu.
  static const double scrimOpacity = 0.35;

  /// Yarım pencerenin en çok boyu, ekranın oranı olarak.
  static const double compactHeight = 0.62;

  /// Uzamış pencerenin boyu, ekranın oranı olarak.
  static const double expandedHeight = 0.92;

  /// Bu hızdan hızlı aşağı kaydırma pencereyi kapatır.
  static const double dismissVelocity = 300;

  /// Pencerenin üst köşeleri.
  static const radius = BorderRadius.vertical(top: Radius.circular(30));

  final Widget child;
  final VoidCallback onDismiss;

  /// `true` ise pencere neredeyse bütün ekranı kaplar (arama için).
  final bool expanded;

  @override
  State<AutofillSheetFrame> createState() => _AutofillSheetFrameState();
}

class _AutofillSheetFrameState extends State<AutofillSheetFrame>
    with TickerProviderStateMixin {
  final GlobalKey _sheetKey = GlobalKey();

  /// Açılış: 0 altta gizli, 1 yerinde.
  late final AnimationController _open = AnimationController(vsync: this);

  /// Bırakılan pencerenin yerine dönüşü.
  late final AnimationController _settle = AnimationController(vsync: this)
    ..addListener(_onSettle);

  /// Parmakla aşağı çekilen yol.
  double _drag = 0;
  double _settleFrom = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _open.duration = KkMotion.of(context, KkMotion.panelOpen);
    if (_open.duration == Duration.zero) {
      _open.value = 1;
    } else {
      _open.forward();
    }
  }

  void _onSettle() =>
      setState(() => _drag = lerpDouble(_settleFrom, 0, _settle.value) ?? 0);

  @override
  void dispose() {
    _open.dispose();
    _settle.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _settle.stop();
    setState(
      () => _drag = (_drag + details.delta.dy).clamp(0, double.infinity),
    );
  }

  void _onDragEnd(DragEndDetails details) {
    final height = _sheetKey.currentContext?.size?.height ?? double.infinity;
    if ((details.primaryVelocity ?? 0) > AutofillSheetFrame.dismissVelocity ||
        _drag > height / 2) {
      widget.onDismiss();
      return;
    }
    _settleFrom = _drag;
    _settle.duration = KkMotion.of(context, KkMotion.base);
    if (_settle.duration == Duration.zero) {
      setState(() => _drag = 0);
    } else {
      _settle.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sheet = ClipRRect(
      key: _sheetKey,
      borderRadius: AutofillSheetFrame.radius,
      child: Stack(
        children: [
          const Positioned.fill(child: KkBackdrop()),
          Material(
            type: MaterialType.transparency,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    key: AutofillSheetFrame.handleKey,
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                    child: SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 5,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Flexible(child: widget.child),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: FadeTransition(
                  opacity: _open,
                  child: ModalBarrier(
                    color: Colors.black.withValues(
                      alpha: AutofillSheetFrame.scrimOpacity,
                    ),
                    onDismiss: widget.onDismiss,
                    semanticsLabel: l10n.autofillClose,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedBuilder(
                  animation: _open,
                  builder: (context, child) {
                    // Yay eğrisi hedefi biraz geçer; pencerenin altı açılmasın
                    // diye yukarı taşma kesilir.
                    final shown = KkMotion.spring
                        .transform(_open.value)
                        .clamp(0.0, 1.0);
                    return FractionalTranslation(
                      translation: Offset(0, 1 - shown),
                      child: Transform.translate(
                        offset: Offset(0, _drag),
                        child: child,
                      ),
                    );
                  },
                  child: widget.expanded
                      ? SizedBox(
                          height: height * AutofillSheetFrame.expandedHeight,
                          child: sheet,
                        )
                      : ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                height * AutofillSheetFrame.compactHeight,
                          ),
                          child: sheet,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Pencerenin üst satırı: küçük logo, başlık, varsa eşleşme sayısı ve
/// kapatma düğmesi.
class AutofillSheetHeader extends StatelessWidget {
  const new({required this.title, required this.onClose, this.info, super.key});

  final String title;
  final VoidCallback onClose;

  /// Başlığın sağındaki ikincil yazı (ör. "2 eşleşme").
  final String? info;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 8, 4),
      child: Row(
        children: [
          // Süs; ekran okuyucu başlığı okur.
          const ExcludeSemantics(child: KeyKeyLogo(size: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (info != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Text(
                info!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          IconButton(
            tooltip: l10n.autofillClose,
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

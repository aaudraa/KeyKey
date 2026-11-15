import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_done_mark.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_menu.dart';
import 'package:keykey/app/ui/kk_metrics.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/app/ui/kk_pressable.dart';

/// Cam daire içinde simge düğmesi (geri oku, düzenle). Görünen boyu [size],
/// dokunma alanı en az 48 dp.
class KkCircleButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = KkMetrics.circleButton,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return KkPressable(
      pressedScale: KkPressable.smallScale,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        style: kkCircleButtonStyle(KkGlass.of(context), size),
        onPressed: onPressed,
      ),
    );
  }
}

/// Kök ekranlardaki üst çubuk: solda kalın başlık. Başlık sabittir;
/// kaydırınca büyüyüp küçülmez (telefon denemesi 5).
PreferredSizeWidget kkRootAppBar(
  BuildContext context, {
  required String title,
  List<Widget> actions = const [],
}) {
  final theme = Theme.of(context);
  return AppBar(
    automaticallyImplyLeading: false,
    toolbarHeight: 56,
    titleSpacing: 20,
    title: Semantics(
      header: true,
      child: Text(
        title,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontSize: KkMetrics.rootTitle,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurface,
        ),
      ),
    ),
    actions: [...actions, const SizedBox(width: 8)],
  );
}

/// Listenin başındaki arama kutusu kayıp gidince üst çubukta, üç noktanın
/// solunda beliren arama simgesi. Dokununca liste başa döner ve kutu
/// odaklanır (telefon denemesi 5).
class KkBarSearchButton extends StatelessWidget {
  const new({
    required this.tooltip,
    required this.scrollController,
    required this.focusNode,
    super.key,
  });

  /// Simgenin belirdiği kaydırma: arama kutusunun çoğu çubuğun altına
  /// girmiştir.
  static const double showAfter = 48;

  final String tooltip;
  final ScrollController scrollController;
  final FocusNode focusNode;

  Future<void> _search(BuildContext context) async {
    final duration = KkMotion.of(context, KkMotion.base);
    if (scrollController.hasClients) {
      if (duration == Duration.zero) {
        scrollController.jumpTo(0);
      } else {
        await scrollController.animateTo(
          0,
          duration: duration,
          curve: KkMotion.standard,
        );
      }
    }
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final offset = KkScrollState.maybeOf(context)?.offset;
    if (offset == null) return const SizedBox.shrink();
    final button = KkPressable(
      key: const ValueKey('ara'),
      pressedScale: KkPressable.smallScale,
      child: IconButton(
        tooltip: tooltip,
        icon: const Icon(Icons.search_rounded),
        style: kkCircleButtonStyle(KkGlass.of(context), 44),
        onPressed: () => _search(context),
      ),
    );
    return ValueListenableBuilder<double>(
      valueListenable: offset,
      builder: (context, pixels, _) => AnimatedSwitcher(
        duration: KkMotion.of(context, KkMotion.fast),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: pixels > showAfter
            ? button
            : const SizedBox.shrink(key: ValueKey('yok')),
      ),
    );
  }
}

/// Alt ekranların üst çubuğu: geri gidilebiliyorsa solda cam daire içinde
/// Android geri oku, yanında başlık.
PreferredSizeWidget kkAppBar(
  BuildContext context, {
  String? title,
  List<Widget> actions = const [],
  Widget? titleTrailing,
}) {
  final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
  final theme = Theme.of(context);
  final titleText = title == null
      ? null
      : Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: KkMetrics.subTitle,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        );
  return AppBar(
    automaticallyImplyLeading: false,
    toolbarHeight: 52,
    leadingWidth: canPop ? 64 : null,
    titleSpacing: canPop ? 4 : 20,
    leading: canPop
        ? Center(
            child: KkCircleButton(
              icon: Icons.arrow_back_rounded,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          )
        : null,
    title: titleTrailing == null
        ? titleText
        : Row(
            children: [
              if (titleText != null) Flexible(child: titleText),
              const SizedBox(width: 12),
              titleTrailing,
            ],
          ),
    actions: [...actions, const SizedBox(width: 8)],
  );
}

/// Form ekranlarının altındaki tek büyük düğme (ör. "Kaydet"). Klavye
/// açılınca klavyenin üstüne çıkar.
class KkBottomAction extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.done = false,
    this.onDone,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  /// İşlem sürüyor: düğmede ilerleme halkası, dokunuş etkisiz.
  final bool busy;

  /// İş bitti (madde 2.2): yazı çizilerek beliren onay işaretine döner,
  /// düğme soluklaşmadan etkisizleşir; işaret bitince [onDone] (ekran kapanır).
  final bool done;
  final VoidCallback? onDone;

  static void _ignore() {}

  @override
  Widget build(BuildContext context) {
    final bottom = math.max(
      MediaQuery.viewInsetsOf(context).bottom,
      MediaQuery.viewPaddingOf(context).bottom,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 16),
      child: KkRiseIn(
        child: SizedBox(
          width: double.infinity,
          child: KkPressable(
            child: FilledButton(
              onPressed: done ? _ignore : (busy ? null : onPressed),
              child: done
                  ? KkDoneMark(semanticLabel: label, onDone: onDone)
                  : busy
                  ? Semantics(
                      label: label,
                      child: const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

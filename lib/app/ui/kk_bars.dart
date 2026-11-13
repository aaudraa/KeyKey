import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_done_mark.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_menu.dart';
import 'package:keykey/app/ui/kk_metrics.dart';
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

/// Kök ekranlardaki üst çubuk: solda kalın başlık.
///
/// [largeTitle] açıksa başlık çubukta değil, listenin başındaki
/// [KkLargeTitle]'dadır ve arama kutusuyla birlikte kayar; o kayıp gidince
/// çubukta küçük başlık belirir (madde 1.9, telefon denemesi 4).
PreferredSizeWidget kkRootAppBar(
  BuildContext context, {
  required String title,
  List<Widget> actions = const [],
  bool largeTitle = false,
}) {
  final theme = Theme.of(context);
  return AppBar(
    automaticallyImplyLeading: false,
    toolbarHeight: 56,
    titleSpacing: 20,
    title: largeTitle
        ? _BarTitle(title: title)
        : Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: KkMetrics.rootTitle,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
    actions: [...actions, const SizedBox(width: 8)],
  );
}

/// Sekmenin listeyle birlikte kayan büyük başlığı. Listenin ilk öğesi olur;
/// üst çubuğu `kkRootAppBar(largeTitle: true)` ile kurulur.
class KkLargeTitle extends StatelessWidget {
  const new(this.title, {super.key});

  final String title;

  /// Çubuktaki küçük başlığın belirmeye başladığı ve tamamen göründüğü
  /// kaydırma: büyük başlık bu arada üst çubuğun altına girer.
  static const double barFadeStart = 24;
  static const double barFadeEnd = 44;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          header: true,
          child: Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: KkMetrics.largeTitle,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Büyük başlık kayıp gidince çubukta solarak beliren küçük başlık. Büyük
/// başlık görünürken ağaçta yoktur; başlık iki kez okunmaz.
class _BarTitle extends StatelessWidget {
  const new({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final offset = KkScrollState.maybeOf(context)?.offset;
    if (offset == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final text = Semantics(
      header: true,
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontSize: KkMetrics.subTitle,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
    return ValueListenableBuilder<double>(
      valueListenable: offset,
      builder: (context, pixels, child) {
        final t =
            ((pixels - KkLargeTitle.barFadeStart) /
                    (KkLargeTitle.barFadeEnd - KkLargeTitle.barFadeStart))
                .clamp(0.0, 1.0);
        if (t == 0) return const SizedBox.shrink();
        return Opacity(opacity: t, child: child);
      },
      child: text,
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
            fontWeight: FontWeight.w700,
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

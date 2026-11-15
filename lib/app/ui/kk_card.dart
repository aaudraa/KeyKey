import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_metrics.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/app/ui/kk_pressable.dart';

/// Listelerdeki cam kart. Normal yazı boyutunda hepsi aynı boydadır:
/// başlık ve alt yazı tek satırda kesilir. Telefonun yazı boyutu büyüyünce
/// kart da büyür, yoksa metin kesilir (erişilebilirlik). Arkasını
/// bulanıklaştırmaz; liste takılmadan kayar.
class KkCard extends StatefulWidget {
  const new({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.minHeight = KkMetrics.cardHeight,
    this.customSemanticsActions,
    this.flash = false,
    super.key,
  });

  /// Parlama katmanı (testler için).
  static const Key flashKey = ValueKey('kk-card-flash');

  /// Parlamadan önceki bekleme: liste görünür olunca ekran geçişi biter.
  static const Duration flashDelay = KkMotion.enter;

  /// Parlamanın en koyu anında zeminin yazı rengiyle örtülme oranı.
  static const double flashPeak = 0.10;

  /// Son kaydedilen kart (madde 2.2): zemin bir kez %0→%10→%0 koyulaşır,
  /// [KkMotion.emphasis] boyunca. Liste görünmüyorsa (ör. form hâlâ
  /// üstte) görünür olana kadar bekler; sonradan `false` olması bekleyen
  /// parlamayı iptal etmez.
  final bool flash;

  /// Ekran okuyucunun işlem listesinde görünen ek işler (ör. uzun basınca
  /// açılan pencerenin işleri).
  final Map<CustomSemanticsAction, VoidCallback>? customSemanticsActions;

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  /// Normal yazı boyutundaki yükseklik.
  final double minHeight;

  @override
  State<KkCard> createState() => _KkCardState();
}

class _KkCardState extends State<KkCard> with SingleTickerProviderStateMixin {
  static const _radius = BorderRadius.all(
    Radius.circular(KkMetrics.cardRadius),
  );

  /// Yalnızca parlayan kartta kurulur.
  AnimationController? _flash;
  bool _flashPending = false;

  @override
  void initState() {
    super.initState();
    _flashPending = widget.flash;
  }

  @override
  void didUpdateWidget(KkCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flash && !oldWidget.flash) {
      _flashPending = true;
      _maybeFlash();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeFlash();
  }

  void _maybeFlash() {
    if (!_flashPending || !TickerMode.valuesOf(context).enabled) return;
    _flashPending = false;
    if (MediaQuery.disableAnimationsOf(context)) return;
    (_flash ??= AnimationController(
      vsync: this,
      duration: KkCard.flashDelay + KkMotion.emphasis,
    )).forward(from: 0);
  }

  @override
  void dispose() {
    _flash?.dispose();
    super.dispose();
  }

  /// Gecikmeden sonra yarım sinüs: 0 → tepe → 0.
  double get _flashAlpha {
    final flash = _flash;
    if (flash == null || !flash.isAnimating) return 0;
    final start =
        KkCard.flashDelay.inMicroseconds / flash.duration!.inMicroseconds;
    final t = ((flash.value - start) / (1 - start)).clamp(0.0, 1.0);
    return KkCard.flashPeak * math.sin(t * math.pi);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Widget texts = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle.merge(
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: KkMetrics.cardTitle,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: widget.title,
        ),
        if (widget.subtitle != null)
          DefaultTextStyle.merge(
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: KkMetrics.cardSubtitle,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: widget.subtitle!,
          ),
      ],
    );

    final content = Padding(
      padding: EdgeInsetsDirectional.only(
        start: widget.leading == null ? 16 : 11,
        end: widget.trailing == null ? 16 : 4,
        top: 3,
        bottom: 3,
      ),
      child: Row(
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: 12),
          ],
          Expanded(child: texts),
          ?widget.trailing,
        ],
      ),
    );

    final interactive = widget.onTap != null || widget.onLongPress != null;
    final ink = theme.colorScheme.onSurface;
    final Widget card = GlassSurface(
      child: AnimatedBuilder(
        animation: _flash ?? kAlwaysDismissedAnimation,
        builder: (context, child) => DecoratedBox(
          key: KkCard.flashKey,
          decoration: BoxDecoration(
            color: ink.withValues(alpha: _flashAlpha),
            borderRadius: _radius,
          ),
          child: child,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Semantics(
            customSemanticsActions: widget.customSemanticsActions,
            child: InkWell(
              borderRadius: _radius,
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: widget.minHeight),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      label: widget.semanticLabel,
      container: widget.semanticLabel != null,
      child: interactive ? KkPressable(child: card) : card,
    );
  }
}

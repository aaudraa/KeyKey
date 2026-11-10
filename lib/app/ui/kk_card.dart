import 'package:flutter/material.dart';

/// Filigranın kartın hangi kenarında duracağı.
enum WatermarkSide { start, end }

/// Listelerdeki küçük kart. Normal yazı boyutunda hepsi aynı boydadır:
/// başlık ve alt yazı tek satırda kesilir. Telefonun yazı boyutu büyüyünce
/// kart da büyür, yoksa metin kesilir (erişilebilirlik).
class KkCard extends StatelessWidget {
  const new({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.watermark,
    this.watermarkSide = WatermarkSide.end,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    super.key,
  });

  /// Normal yazı boyutundaki yükseklik (iki satır).
  static const double minHeight = 60;

  /// Filigranın görünürlüğü.
  static const double watermarkOpacity = 0.2;

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// Kartın kenarına yaslanan, dışına taşıp kırpılan silik resim.
  final Widget? watermark;
  final WatermarkSide watermarkSide;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = theme.cardTheme.shape as RoundedRectangleBorder?;
    final radius =
        (shape?.borderRadius as BorderRadius?) ??
        const BorderRadius.all(Radius.circular(14));
    final start = watermarkSide == WatermarkSide.start;

    final Widget texts = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle.merge(
          style: theme.textTheme.titleSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: title,
        ),
        if (subtitle != null)
          DefaultTextStyle.merge(
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: subtitle!,
          ),
      ],
    );

    final content = Padding(
      padding: EdgeInsetsDirectional.only(
        start: start && watermark != null ? 28 : 14,
        end: trailing == null ? 14 : 4,
        top: 6,
        bottom: 6,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(child: texts),
          ?trailing,
        ],
      ),
    );

    return Semantics(
      label: semanticLabel,
      container: semanticLabel != null,
      child: Card(
        child: ClipRRect(
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: minHeight),
              child: Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [
                  if (watermark != null)
                    PositionedDirectional(
                      top: 0,
                      bottom: 0,
                      width: 72,
                      start: start ? -14 : null,
                      end: start ? null : -14,
                      child: ExcludeSemantics(
                        child: Opacity(
                          opacity: watermarkOpacity,
                          child: OverflowBox(
                            maxWidth: double.infinity,
                            maxHeight: double.infinity,
                            child: watermark,
                          ),
                        ),
                      ),
                    ),
                  content,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

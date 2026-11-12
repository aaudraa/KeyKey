import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_motion.dart';

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
    this.minHeight = 64,
    super.key,
  });

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

class _KkCardState extends State<KkCard> {
  static const _radius = BorderRadius.all(Radius.circular(22));
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Widget texts = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle.merge(
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: widget.title,
        ),
        if (widget.subtitle != null)
          DefaultTextStyle.merge(
            style: theme.textTheme.bodySmall?.copyWith(
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
        top: 8,
        bottom: 8,
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
    return Semantics(
      label: widget.semanticLabel,
      container: widget.semanticLabel != null,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: KkMotion.of(context, KkMotion.fast),
        child: GlassSurface(
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: _radius,
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              onHighlightChanged: interactive
                  ? (value) => setState(() => _pressed = value)
                  : null,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: widget.minHeight),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

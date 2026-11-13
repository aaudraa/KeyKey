import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_metrics.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/app/ui/kk_section.dart';

/// Küçük anahtar: 36×21 görünür, 48×48 dokunulur. Açıkken iz yazı
/// renginde, topuz zemin renginde; topuz yaylanarak kayar (madde 1.7).
class KkSwitch extends StatelessWidget {
  const new({required this.value, required this.onChanged, super.key});

  /// Testler için izin anahtarı.
  static const trackKey = Key('kk-switch-track');

  static const Size _track = Size(36, 21);
  static const double _thumb = 15;

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = KkGlass.of(context);
    final enabled = onChanged != null;
    final duration = KkMotion.of(context, KkMotion.base);
    return Semantics(
      toggled: value,
      enabled: enabled,
      onTap: enabled ? () => onChanged!(!value) : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: SizedBox.square(
          dimension: KkMetrics.minTouch,
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.38,
              child: AnimatedContainer(
                key: trackKey,
                duration: duration,
                curve: Curves.easeOutCubic,
                width: _track.width,
                height: _track.height,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: value ? scheme.onSurface : glass.fill,
                  borderRadius: BorderRadius.circular(_track.height / 2),
                  border: Border.all(
                    color: value ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
                child: AnimatedAlign(
                  duration: duration,
                  curve: KkMotion.spring,
                  alignment: value
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: Container(
                    width: _thumb - 2,
                    height: _thumb - 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value ? glass.ground : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Anahtarlı ayar satırı (`SwitchListTile`'ın yerine). Satıra dokunmak da
/// değeri çevirir. [info] verilirse anahtarın hemen solunda (i) durur.
class KkSwitchTile extends StatelessWidget {
  const new({
    required this.title,
    required this.value,
    required this.onChanged,
    this.secondary,
    this.subtitle,
    this.infoTitle,
    this.info,
    super.key,
  }) : assert(
         (infoTitle == null) == (info == null),
         'infoTitle ve info birlikte verilir',
       );

  final Widget title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? secondary;
  final Widget? subtitle;
  final String? infoTitle;
  final String? info;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      child: ListTile(
        enabled: enabled,
        leading: secondary,
        title: title,
        subtitle: subtitle,
        onTap: enabled ? () => onChanged!(!value) : null,
        contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 4),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (info != null) KkInfoButton(title: infoTitle!, info: info!),
            ExcludeSemantics(
              child: KkSwitch(value: value, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}

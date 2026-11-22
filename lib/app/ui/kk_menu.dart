import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_glass.dart';

/// Üç nokta menüsünün bir öğesi.
class KkMenuItem<T> {
  const new({
    required this.value,
    required this.label,
    this.icon,
    this.checked = false,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// Seçili olduğu (ör. geçerli sıralama) onay simgesiyle gösterilir.
  final bool checked;
  final bool enabled;
}

/// Sağ üstteki cam daire düğme ve açılan dolu menü. Menü kendi yolu olarak
/// açılır; geri tuşu ve dışına dokunmak kapatır.
class KkMenuButton<T> extends StatelessWidget {
  const new({
    required this.tooltip,
    required this.items,
    required this.onSelected,
    this.icon = Icons.more_vert_rounded,
    super.key,
  });

  final String tooltip;
  final List<KkMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final glass = KkGlass.of(context);
    return PopupMenuButton<T>(
      tooltip: tooltip,
      icon: Icon(icon),
      style: kkCircleButtonStyle(glass, 44),
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      menuPadding: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      // Sekmenin gezgininde açılırsa perdesi alt menüyü örtmez; sekme
      // değişince menü öteki sekmede açık kalırdı (#173, S7).
      useRootNavigator: true,
      onSelected: onSelected,
      itemBuilder: (context) => [_GlassMenuEntry<T>(items)],
    );
  }
}

/// Bütün öğeleri tek dolu gövdede çizen menü girdisi.
class _GlassMenuEntry<T> extends PopupMenuEntry<T> {
  const new(this.items);

  final List<KkMenuItem<T>> items;

  @override
  double get height => 48.0 * items.length;

  @override
  bool represents(T? value) => items.any((item) => item.value == value);

  @override
  State<_GlassMenuEntry<T>> createState() => _GlassMenuEntryState<T>();
}

class _GlassMenuEntryState<T> extends State<_GlassMenuEntry<T>> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = KkGlass.of(context);
    const radius = BorderRadius.all(Radius.circular(20));
    return GlassSurface(
      fill: glass.raised,
      borderRadius: radius,
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in widget.items)
                  InkWell(
                    onTap: item.enabled
                        ? () => Navigator.of(context).pop(item.value)
                        : null,
                    child: Semantics(
                      selected: item.checked,
                      enabled: item.enabled,
                      button: true,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: 48,
                          minWidth: 200,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              if (item.icon != null) ...[
                                Icon(
                                  item.icon,
                                  size: 20,
                                  color: item.enabled
                                      ? glass.accent
                                      : theme.disabledColor,
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: item.enabled
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.38),
                                  ),
                                ),
                              ),
                              if (item.checked) ...[
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.check_rounded,
                                  size: 20,
                                  color: glass.accent,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cam daire düğmenin görünüşü; `KkCircleButton` ve menü düğmesi paylaşır.
ButtonStyle kkCircleButtonStyle(KkGlass glass, double size) => ButtonStyle(
  fixedSize: WidgetStatePropertyAll(Size.square(size)),
  minimumSize: WidgetStatePropertyAll(Size.square(size)),
  tapTargetSize: MaterialTapTargetSize.padded,
  backgroundColor: WidgetStatePropertyAll(glass.fill),
  side: WidgetStatePropertyAll(BorderSide(color: glass.hairline)),
  shape: const WidgetStatePropertyAll(CircleBorder()),
);

import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_motion.dart';

/// Alt menüdeki bir sekme.
class GlassNavItem {
  const new({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Ekranın altında, kenarlardan ayrık cam şerit: sekmeler, ince bir ayraç ve
/// en uçta turuncu "+". Seçili sekme simgesi ve adıyla parlak bir kapsülde,
/// diğerleri yalnızca simge. `Scaffold(extendBody: true)` ile kullanılır,
/// içerik arkasından kayar.
class GlassNavBar extends StatelessWidget {
  const new({
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    required this.onAdd,
    required this.addOpen,
    required this.addLabel,
    required this.closeLabel,
    super.key,
  });

  static const double height = 64;

  /// Ekranın altından boşluk.
  static const double bottomGap = 16;

  /// Testler için şeridin ve "+" düğmesinin anahtarları.
  static const pillKey = Key('glass-nav-pill');
  static const addKey = Key('glass-nav-add');

  static const double _tabWidth = 52;
  static const double _addSize = 48;
  static const double _inner = 8;

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<GlassNavItem> items;
  final VoidCallback onAdd;

  /// "+" kutusu açık: "+" çarpıya döner ve "Kapat" diye okunur.
  final bool addOpen;
  final String addLabel;
  final String closeLabel;

  /// Ad ve "Sekme 1/3": eski NavigationBar ile aynı okunuş.
  String _semanticLabel(MaterialLocalizations l, int i) =>
      '${items[i].label}\n'
      '${l.tabLabel(tabIndex: i + 1, tabCount: items.length)}';

  /// Seçili sekmenin adı şeride sığıyor mu? Büyük yazıda ya da dar ekranda
  /// ad gizlenir, sekme yalnızca simgeyle kalır.
  bool _showLabel(BuildContext context, double maxWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    if (scaler.scale(10) > 13) return false;
    final style = _labelStyle(context);
    final painter = TextPainter(
      text: TextSpan(text: items[selectedIndex].label, style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final labelWidth = painter.width;
    painter.dispose();
    final needed =
        _tabWidth * items.length +
        labelWidth +
        16 +
        1 +
        _inner * 4 +
        _addSize +
        _inner * 2;
    return needed <= maxWidth;
  }

  static TextStyle? _labelStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = KkGlass.of(context);
    final localizations = MaterialLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const radius = BorderRadius.all(Radius.circular(height / 2));

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomGap + bottomInset,
        left: 16,
        right: 16,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showLabel = _showLabel(context, constraints.maxWidth);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GlassSurface(
                key: pillKey,
                blur: true,
                strong: true,
                borderRadius: radius,
                child: SizedBox(
                  height: height,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _inner),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < items.length; i++)
                          _NavTab(
                            item: items[i],
                            selected: i == selectedIndex,
                            showLabel: showLabel,
                            semanticLabel: _semanticLabel(localizations, i),
                            onTap: () => onSelected(i),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _inner,
                          ),
                          child: SizedBox(
                            width: 1,
                            height: 28,
                            child: ColoredBox(color: glass.border),
                          ),
                        ),
                        _AddButton(
                          open: addOpen,
                          label: addOpen ? closeLabel : addLabel,
                          onTap: onAdd,
                        ),
                      ],
                    ),
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

class _NavTab extends StatelessWidget {
  const new({
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.semanticLabel,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final bool showLabel;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = KkGlass.of(context);
    final duration = KkMotion.of(context, KkMotion.base);
    final withLabel = selected && showLabel;
    return Semantics(
      label: semanticLabel,
      selected: selected,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox(
          height: GlassNavBar.height,
          child: Center(
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOutCubic,
              height: 48,
              constraints: const BoxConstraints(
                minWidth: GlassNavBar._tabWidth,
              ),
              padding: EdgeInsets.symmetric(horizontal: withLabel ? 14 : 0),
              decoration: BoxDecoration(
                color: selected
                    ? glass.capsule
                    : glass.capsule.withValues(alpha: 0),
                borderRadius: BorderRadius.circular(24),
              ),
              child: AnimatedSize(
                duration: duration,
                curve: Curves.easeOutCubic,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? item.selectedIcon : item.icon,
                      color: selected
                          ? glass.accent
                          : theme.colorScheme.onSurface,
                    ),
                    if (withLabel) ...[
                      const SizedBox(width: 8),
                      Text(
                        item.label,
                        maxLines: 1,
                        style: GlassNavBar._labelStyle(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const new({required this.open, required this.label, required this.onTap});

  final bool open;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = KkGlass.of(context);
    return Semantics(
      label: label,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: SizedBox.square(
        key: GlassNavBar.addKey,
        dimension: GlassNavBar._addSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: glass.ctaGradient,
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: AnimatedRotation(
                turns: open ? 0.125 : 0,
                duration: KkMotion.of(context, KkMotion.base),
                curve: Curves.easeOutCubic,
                child: Icon(Icons.add_rounded, color: glass.onCta, size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Listelerin sonunda bırakılacak boşluk; son satır menünün altında kalmasın.
const double kNavClearance = GlassNavBar.height + GlassNavBar.bottomGap * 2;

/// Listelerin sonunda bırakılacak bütün boşluk: menü ve altındaki sistem
/// gezinme çubuğu. Android 15+ uygulamayı kenardan kenara çizer; menü
/// çubuğun üstünde durduğu için liste de o kadar yukarıda bitmeli.
double navClearance(BuildContext context) =>
    kNavClearance + MediaQueryData.fromView(View.of(context)).padding.bottom;

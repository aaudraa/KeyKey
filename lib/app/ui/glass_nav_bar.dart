import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Alt menüdeki bir sekme.
class GlassNavItem {
  const new({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;

  /// Görünmez; ekran okuyucu okur.
  final String label;
}

/// Ekranın altında yüzen, buzlu cam görünümlü küçük menü. Yalnızca simge
/// gösterir; seçili sekme dolu simgeyle ve altında bir noktayla belirtilir.
/// `Scaffold(extendBody: true)` ile kullanılır, içerik arkasından kayar.
class GlassNavBar extends StatelessWidget {
  const new({
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    super.key,
  });

  static const double height = 56;
  static const double itemWidth = 64;

  /// Ekranın altından boşluk.
  static const double bottomGap = 16;

  /// Testler için yuvarlak şeridin anahtarı.
  static const pillKey = Key('glass-nav-pill');

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<GlassNavItem> items;

  /// Ad ve "Sekme 1/3": eski NavigationBar ile aynı okunuş.
  String _semanticLabel(MaterialLocalizations l, int i) =>
      '${items[i].label}\n'
      '${l.tabLabel(tabIndex: i + 1, tabCount: items.length)}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final localizations = MaterialLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const radius = BorderRadius.all(Radius.circular(height / 2));

    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap + bottomInset),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DecoratedBox(
            key: pillKey,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.55),
                    borderRadius: radius,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: SizedBox(
                    height: height,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < items.length; i++)
                          _NavButton(
                            item: items[i],
                            selected: i == selectedIndex,
                            semanticLabel: _semanticLabel(localizations, i),
                            onTap: () => onSelected(i),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const new({
    required this.item,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurface;
    return Semantics(
      label: semanticLabel,
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: GlassNavBar.height / 2,
        child: SizedBox(
          width: GlassNavBar.itemWidth,
          height: GlassNavBar.height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? item.selectedIcon : item.icon, color: color),
              const SizedBox(height: 4),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
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

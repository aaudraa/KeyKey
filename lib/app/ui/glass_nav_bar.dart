import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_metrics.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/app/ui/kk_pressable.dart';

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
/// en uçta turuncu "+". Seçili sekme simgesi ve adıyla hafif koyu bir kapsülde,
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
    this.tabsHidden = false,
    super.key,
  });

  static const double height = KkMetrics.navHeight;

  /// Ekranın altından boşluk.
  static const double bottomGap = 16;

  /// Testler için şeridin ve "+" düğmesinin anahtarları.
  static const pillKey = Key('glass-nav-pill');
  static const addKey = Key('glass-nav-add');

  static const double _tabWidth = KkMetrics.minTouch;

  /// "+" düğmesinin dokunma alanı; görünen daire [KkMetrics.addSize].
  static const double _addSize = KkMetrics.minTouch;
  static const double _inner = 8;

  /// Şeridin ekran kenarlarından uzaklığı.
  static const double _side = 16;

  /// Dar ekranda (küçük telefon, büyük "ekran boyutu" ayarı) sekmeler
  /// sığsın diye kenar ve iç boşluklar daralır; sekmelerin dokunma alanı
  /// 48 dp'de kalır.
  static const double _innerCompact = 4;
  static const double _sideCompact = 4;

  /// Sekmeler, ayraç ve "+" verilen boşluklarla [width]'e sığıyor mu?
  bool _fits(double width, {required double inner, required double side}) =>
      _tabWidth * items.length + 1 + inner * 4 + _addSize + side * 2 <= width;

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<GlassNavItem> items;
  final VoidCallback onAdd;

  /// "+" kutusu açık: "+" çarpıya döner ve "Kapat" diye okunur.
  final bool addOpen;
  final String addLabel;
  final String closeLabel;

  /// "+" kutusu açıkken sekmeler ekran okuyucudan gizlenir; odak kutuda
  /// kalır.
  final bool tabsHidden;

  /// Ad ve "Sekme 1/3": eski NavigationBar ile aynı okunuş.
  String _semanticLabel(MaterialLocalizations l, int i) =>
      '${items[i].label}\n'
      '${l.tabLabel(tabIndex: i + 1, tabCount: items.length)}';

  @override
  Widget build(BuildContext context) {
    final glass = KkGlass.of(context);
    final localizations = MaterialLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const radius = BorderRadius.all(Radius.circular(height / 2));
    final compact = !_fits(
      MediaQuery.sizeOf(context).width,
      inner: _inner,
      side: _side,
    );
    final inner = compact ? _innerCompact : _inner;
    final side = compact ? _sideCompact : _side;

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomGap + bottomInset,
        left: side,
        right: side,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          KkRiseIn(
            child: GlassSurface(
              key: pillKey,
              blur: true,
              vibrant: true,
              sheen: true,
              fill: glass.navFill,
              borderRadius: radius,
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: inner),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        ExcludeSemantics(
                          excluding: tabsHidden,
                          child: _NavTab(
                            item: items[i],
                            selected: i == selectedIndex,
                            semanticLabel: _semanticLabel(localizations, i),
                            onTap: () => onSelected(i),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: inner),
                        child: SizedBox(
                          width: 1,
                          height: 28,
                          child: ColoredBox(color: glass.hairline),
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
          ),
        ],
      ),
    );
  }
}

class _NavTab extends StatefulWidget {
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
  State<_NavTab> createState() => _NavTabState();
}

/// Seçilen sekmenin simgesi küçük bir zıplama yapar (madde 1.5):
/// %100 → %118 → %100.
class _NavTabState extends State<_NavTab> with SingleTickerProviderStateMixin {
  static const double _bounce = 0.18;

  late final AnimationController _jump = AnimationController(
    vsync: this,
    duration: KkMotion.base,
  );

  @override
  void didUpdateWidget(_NavTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _jump.duration = KkMotion.of(context, KkMotion.base);
      if (_jump.duration == Duration.zero) return;
      _jump.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _jump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final selected = widget.selected;
    final onTap = widget.onTap;
    final theme = Theme.of(context);
    final glass = KkGlass.of(context);
    final duration = KkMotion.of(context, KkMotion.base);
    return Semantics(
      label: widget.semanticLabel,
      selected: selected,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: KkPressable(
        pressedScale: KkPressable.smallScale,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: SizedBox(
            height: GlassNavBar.height,
            child: Center(
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                height: KkMetrics.navTab,
                constraints: const BoxConstraints(
                  minWidth: GlassNavBar._tabWidth,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? glass.tint
                      : glass.tint.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(KkMetrics.navTab / 2),
                ),
                // Ad gösterilmez (#163); seçili sekme dolu simge ve vurguyla
                // ayrılır, ekran okuyucu adı Semantics'ten okur.
                child: AnimatedBuilder(
                  animation: _jump,
                  builder: (context, child) => Transform.scale(
                    scale: 1 + _bounce * math.sin(math.pi * _jump.value),
                    child: child,
                  ),
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    color: selected
                        ? glass.accent
                        : theme.colorScheme.onSurface,
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
      // Görünen daire 40 dp; dokunma alanı çevresindeki 48 dp'lik kare.
      child: KkPressable(
        pressedScale: KkPressable.smallScale,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox.square(
            key: GlassNavBar.addKey,
            dimension: GlassNavBar._addSize,
            child: Center(
              child: SizedBox.square(
                dimension: KkMetrics.addSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: glass.brand,
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
                        child: Icon(
                          Icons.add_rounded,
                          color: glass.onBrand,
                          size: 24,
                        ),
                      ),
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

/// Listelerin sonunda bırakılacak boşluk; son satır menünün altında kalmasın.
const double kNavClearance = GlassNavBar.height + GlassNavBar.bottomGap * 2;

/// Listelerin sonunda bırakılacak bütün boşluk: menü ve altındaki sistem
/// gezinme çubuğu. Android 15+ uygulamayı kenardan kenara çizer; menü
/// çubuğun üstünde durduğu için liste de o kadar yukarıda bitmeli.
double navClearance(BuildContext context) =>
    kNavClearance + MediaQueryData.fromView(View.of(context)).padding.bottom;

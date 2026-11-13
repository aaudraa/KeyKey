import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_glass.dart';

const _items = [
  GlassNavItem(
    icon: Icons.lock_outline,
    selectedIcon: Icons.lock,
    label: 'Kasa',
  ),
  GlassNavItem(
    icon: Icons.shield_outlined,
    selectedIcon: Icons.shield,
    label: '2FA',
  ),
  GlassNavItem(
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    label: 'Ayarlar',
  ),
];

Widget _host({
  int selected = 0,
  ValueChanged<int>? onSelected,
  VoidCallback? onAdd,
  bool addOpen = false,
  ThemeData? theme,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: KkScaffold(
      extendBody: true,
      body: ListView(children: [for (var i = 0; i < 40; i++) Text('Satır $i')]),
      bottomNavigationBar: GlassNavBar(
        selectedIndex: selected,
        onSelected: onSelected ?? (_) {},
        items: _items,
        onAdd: onAdd ?? () {},
        addOpen: addOpen,
        addLabel: 'Ekle',
        closeLabel: 'Kapat',
      ),
    ),
  );
}

class _Switcher extends StatefulWidget {
  const new();

  @override
  State<_Switcher> createState() => _SwitcherState();
}

class _SwitcherState extends State<_Switcher> {
  int selected = 0;

  @override
  Widget build(BuildContext context) => _host(
    selected: selected,
    onSelected: (i) => setState(() => selected = i),
  );
}

void main() {
  testWidgets('seçili sekmenin adı görünür, diğerlerinin görünmez', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(find.text('Kasa'), findsOneWidget);
    expect(find.text('2FA'), findsNothing);
    expect(find.text('Ayarlar'), findsNothing);
  });

  testWidgets('seçim değişince ad yeni sekmeye geçer', (tester) async {
    await tester.pumpWidget(const _Switcher());
    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pumpAndSettle();
    expect(find.text('2FA'), findsOneWidget);
    expect(find.text('Kasa'), findsNothing);
    expect(find.byIcon(Icons.shield), findsOneWidget);
  });

  testWidgets('şerit 52 dp, altta 16 dp boşluk, dokunma hedefleri yeterli', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host());

    final screen = tester.getRect(find.byType(Scaffold));
    final pill = tester.getRect(find.byKey(GlassNavBar.pillKey));
    expect(pill.height, GlassNavBar.height);
    expect(GlassNavBar.height, 52);
    expect(screen.bottom - pill.bottom, GlassNavBar.bottomGap);
    expect(tester.getSize(find.byKey(GlassNavBar.addKey)).width, 48);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('ekran okuyucu sekme adını, sırasını ve "+" düğmesini okur', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host());
    expect(
      tester.getSemantics(find.bySemanticsLabel('Kasa\nTab 1 of 3')),
      matchesSemantics(
        label: 'Kasa\nTab 1 of 3',
        isSelected: true,
        hasSelectedState: true,
        isButton: true,
        hasTapAction: true,
      ),
    );
    final node = tester.getSemantics(find.bySemanticsLabel('2FA\nTab 2 of 3'));
    expect(node.flagsCollection.isSelected, Tristate.isFalse);
    expect(find.bySemanticsLabel('Ekle'), findsOneWidget);

    await tester.pumpWidget(_host(addOpen: true));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Kapat'), findsOneWidget);
    expect(find.bySemanticsLabel('Ekle'), findsNothing);
    semantics.dispose();
  });

  testWidgets('"+" onAdd çağırır, açıkken döner', (tester) async {
    var adds = 0;
    await tester.pumpWidget(_host(onAdd: () => adds++));
    await tester.tap(find.byKey(GlassNavBar.addKey));
    expect(adds, 1);
    expect(
      tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
      0,
    );
    await tester.pumpWidget(_host(addOpen: true));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
      0.125,
    );
  });

  testWidgets('içerik menünün arkasından görünür (buzlu cam)', (tester) async {
    await tester.pumpWidget(_host());
    expect(
      find.descendant(
        of: find.byType(GlassNavBar),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
  });

  testWidgets('menü camı kartlardan saydam ve daha çok bulanıklaştırır', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    final glass = AppTheme.light.extension<KkGlass>()!;
    final pill = find.byKey(GlassNavBar.pillKey);
    final fills = tester
        .widgetList<DecoratedBox>(
          find.descendant(of: pill, matching: find.byType(DecoratedBox)),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color);
    expect(fills, contains(glass.navFill));
    final filter = tester
        .widget<BackdropFilter>(
          find.descendant(of: pill, matching: find.byType(BackdropFilter)),
        )
        .filter;
    // Güçlü bulanıklık ve renk doygunluğu (alttan kayan içerik canlı ama
    // okunmaz görünür).
    expect(filter.toString(), contains('blur(${GlassSurface.navBlurSigma}'));
    expect(filter.toString(), contains('compose'));
  });

  testWidgets('dar ekranda ve %200 yazıda şerit sığar, "+" görünür', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(textScale: 2));
    await tester.pumpAndSettle();
    final pill = tester.getRect(find.byKey(GlassNavBar.pillKey));
    expect(pill.left, greaterThanOrEqualTo(0));
    expect(pill.right, lessThanOrEqualTo(320));
    final add = tester.getRect(find.byKey(GlassNavBar.addKey));
    expect(add.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
    // Büyük yazıda ad gizlenir; sekme ekran okuyucuda yine adıyla okunur.
    expect(find.text('Kasa'), findsNothing);
  });

  for (final (name, theme) in [
    ('açık', AppTheme.light),
    ('koyu', AppTheme.dark),
  ]) {
    testWidgets('$name temada menü yazısı okunur', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: KkScaffold(
            extendBody: true,
            body: const SizedBox.expand(),
            bottomNavigationBar: GlassNavBar(
              selectedIndex: 0,
              onSelected: (_) {},
              items: _items,
              onAdd: () {},
              addOpen: false,
              addLabel: 'Ekle',
              closeLabel: 'Kapat',
            ),
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }
}

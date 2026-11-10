import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';

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

Widget _host({required int selected, required ValueChanged<int> onSelected}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      extendBody: true,
      body: ListView(children: [for (var i = 0; i < 40; i++) Text('Satır $i')]),
      bottomNavigationBar: GlassNavBar(
        selectedIndex: selected,
        onSelected: onSelected,
        items: _items,
      ),
    ),
  );
}

void main() {
  testWidgets('dokunulan sekmenin sırası bildirilir', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(_host(selected: 0, onSelected: taps.add));

    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.tap(find.byIcon(Icons.settings_outlined));
    expect(taps, [1, 2]);
  });

  testWidgets('seçili sekme dolu simgeyle, diğerleri çizgiyle', (tester) async {
    await tester.pumpWidget(_host(selected: 1, onSelected: (_) {}));

    expect(find.byIcon(Icons.shield), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNothing);
  });

  testWidgets('yazı görünmez ama ekran okuyucu sekme adını ve sırasını okur', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(selected: 2, onSelected: (_) {}));

    expect(find.text('Ayarlar'), findsNothing);
    final node = tester.getSemantics(find.byIcon(Icons.settings));
    expect(node.label, 'Ayarlar\nTab 3 of 3');
    expect(node.flagsCollection.isSelected, Tristate.isTrue);
    expect(
      tester.getSemantics(find.byIcon(Icons.lock_outline)).label,
      'Kasa\nTab 1 of 3',
    );
    semantics.dispose();
  });

  testWidgets(
    'menü küçük, ekranın altından ayrık ve dokunma hedefleri yeterli',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(selected: 0, onSelected: (_) {}));

      final bar = tester.getRect(find.byType(GlassNavBar));
      final screen = tester.getRect(find.byType(Scaffold));
      final pill = tester.getRect(find.byKey(GlassNavBar.pillKey));
      expect(pill.height, GlassNavBar.height);
      expect(pill.width, lessThan(screen.width / 2));
      expect(screen.bottom - pill.bottom, greaterThanOrEqualTo(16));
      expect(bar.bottom, screen.bottom);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    },
  );

  testWidgets('içerik menünün arkasından görünür (buzlu cam)', (tester) async {
    await tester.pumpWidget(_host(selected: 0, onSelected: (_) {}));
    expect(
      find.descendant(
        of: find.byType(GlassNavBar),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
  });
}

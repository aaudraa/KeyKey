import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_menu.dart';

Future<List<String>> _pump(WidgetTester tester) async {
  final selected = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        appBar: AppBar(
          actions: [
            KkMenuButton<String>(
              tooltip: 'Diğer işlemler',
              items: const [
                KkMenuItem(
                  value: 'ad',
                  label: 'Ada göre sırala',
                  checked: true,
                ),
                KkMenuItem(value: 'son', label: 'Son değişene göre sırala'),
                KkMenuItem(
                  value: 'rapor',
                  label: 'Parola raporu',
                  icon: Icons.shield_outlined,
                  enabled: false,
                ),
              ],
              onSelected: selected.add,
            ),
          ],
        ),
      ),
    ),
  );
  return selected;
}

void main() {
  testWidgets('düğme ipucuyla bulunur ve dokunma alanı en az 48 dp', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(find.byTooltip('Diğer işlemler'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('açılınca öğeler görünür, seçili olanda onay, cam', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byTooltip('Diğer işlemler'));
    await tester.pumpAndSettle();
    expect(find.text('Ada göre sırala'), findsOneWidget);
    expect(find.text('Son değişene göre sırala'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('öğeye dokununca seçilir ve menü kapanır', (tester) async {
    final selected = await _pump(tester);
    await tester.tap(find.byTooltip('Diğer işlemler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Son değişene göre sırala'));
    await tester.pumpAndSettle();
    expect(selected, ['son']);
    expect(find.text('Ada göre sırala'), findsNothing);
  });

  testWidgets('etkisiz öğe seçilmez', (tester) async {
    final selected = await _pump(tester);
    await tester.tap(find.byTooltip('Diğer işlemler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parola raporu'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
  });

  testWidgets('geri tuşu menüyü kapatır', (tester) async {
    await _pump(tester);
    await tester.tap(find.byTooltip('Diğer işlemler'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Ada göre sırala'), findsNothing);
  });
}

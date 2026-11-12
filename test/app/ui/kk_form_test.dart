import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_form.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

Widget _host(Widget child, {double textScale = 1}) => MaterialApp(
  theme: AppTheme.light,
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(body: ListView(children: [child])),
  ),
);

void main() {
  testWidgets('kapalıyken yongalar yok, açılınca görünür ve ekler', (
    tester,
  ) async {
    final added = <String>[];
    await tester.pumpWidget(
      _host(
        KkMoreOptions(
          options: [
            KkOption(label: 'Not', onAdd: () => added.add('not')),
            KkOption(label: 'Klasör', onAdd: () => added.add('klasör')),
          ],
        ),
      ),
    );
    expect(find.text('Daha fazla seçenek'), findsOneWidget);
    expect(find.text('Not'), findsNothing);

    await tester.tap(find.text('Daha fazla seçenek'));
    await tester.pumpAndSettle();
    expect(find.text('Not'), findsOneWidget);
    expect(find.text('Klasör'), findsOneWidget);

    await tester.tap(find.text('Not'));
    await tester.pumpAndSettle();
    expect(added, ['not']);
  });

  testWidgets('seçenek yoksa hiçbir şey çizilmez', (tester) async {
    await tester.pumpWidget(_host(const KkMoreOptions(options: [])));
    expect(find.text('Daha fazla seçenek'), findsNothing);
  });

  testWidgets('%200 yazıda taşma yok', (tester) async {
    await tester.pumpWidget(
      _host(
        textScale: 2,
        KkMoreOptions(
          options: [
            for (final label in ['Klasör', 'Not', 'Özel alan', 'Başka site'])
              KkOption(label: label, onAdd: () {}),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Daha fazla seçenek'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('alan kartının kaldırma düğmesi çağırır ve 48 dp', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var removed = 0;
    await tester.pumpWidget(
      _host(
        KkFieldCard(
          onRemove: () => removed++,
          removeTooltip: 'Alanı kaldır',
          child: const TextField(),
        ),
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(find.byTooltip('Alanı kaldır'));
    expect(removed, 1);
    handle.dispose();
  });
}

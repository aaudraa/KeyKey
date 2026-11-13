import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_form.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_motion.dart';
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

  testWidgets('açılınca ok 180° döner, yongalar sırayla küçükten büyür', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        KkMoreOptions(
          options: [
            KkOption(label: 'Not', onAdd: () {}),
            KkOption(label: 'Klasör', onAdd: () {}),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Daha fazla seçenek'));
    await tester.pump();
    await tester.pump(KkMotion.stagger);
    double opacity(String label) => tester
        .widget<Opacity>(
          find
              .ancestor(of: find.text(label), matching: find.byType(Opacity))
              .first,
        )
        .opacity;
    double scale(String label) => tester
        .widget<Transform>(
          find
              .ancestor(of: find.text(label), matching: find.byType(Transform))
              .first,
        )
        .transform
        .storage[0];
    expect(opacity('Not'), greaterThan(opacity('Klasör')));
    expect(scale('Not'), lessThan(1.2));
    expect(scale('Klasör'), lessThan(1));
    await tester.pumpAndSettle();
    expect(opacity('Klasör'), 1);
    expect(scale('Klasör'), closeTo(1, 0.001));
    expect(
      tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
      0.5,
    );
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

  // Telefon denemesi 5: alanın sol üstündeki etiket çerçeve çizgisine
  // oturuyor, kart yarısını kesiyordu.
  for (final (name, theme) in [
    ('açık', AppTheme.light),
    ('koyu', AppTheme.dark),
  ]) {
    testWidgets('$name: dolu alanın etiketi kartın içinde kalır', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: KkFieldCard(
                key: const Key('kart'),
                child: TextField(
                  controller: TextEditingController(text: 'ali'),
                  decoration: const InputDecoration(
                    labelText: 'Kullanıcı adı',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('kart')),
          matching: find.byType(GlassSurface),
        ),
      );
      final label = tester.getRect(find.text('Kullanıcı adı'));
      final value = tester.getRect(find.text('ali'));
      expect(label.top, greaterThanOrEqualTo(card.top + 4));
      expect(value.top, greaterThan(label.bottom - 1));
      expect(value.bottom, lessThanOrEqualTo(card.bottom - 4));
    });
  }

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

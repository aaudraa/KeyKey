import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';

void main() {
  testWidgets('kök ekranda geri düğmesi yok, itilmiş ekranda var ve döner', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => KkScaffold(
            appBar: kkRootAppBar(context, title: 'Kasa'),
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => KkScaffold(
                      appBar: kkAppBar(context, title: 'Ayrıntı'),
                      body: const SizedBox.expand(),
                    ),
                  ),
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Kasa'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);

    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.text('Ayrıntı'), findsOneWidget);
    final back = find.byTooltip('Back');
    expect(back, findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    // Başlık solda.
    expect(
      tester.getTopLeft(find.text('Ayrıntı')).dx,
      lessThan(
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
      ),
    );

    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text('Ayrıntı'), findsNothing);
    handle.dispose();
  });

  testWidgets('alt düğme klavyenin üstünde durur', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: KkScaffold(
          body: const TextField(),
          bottomNavigationBar: KkBottomAction(
            label: 'Kaydet',
            onPressed: () {},
          ),
        ),
      ),
    );
    final rect = tester.getRect(find.widgetWithText(FilledButton, 'Kaydet'));
    expect(rect.bottom, lessThanOrEqualTo(800 - 300));
    expect(rect.width, greaterThan(300));
  });

  testWidgets('meşgulken dokunuş çağırmaz, halka görünür', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: KkScaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: KkBottomAction(
            label: 'Kaydet',
            busy: true,
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('yuvarlak düğme en az 48 dp ve ipucu taşır', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: KkCircleButton(
              icon: Icons.edit_rounded,
              tooltip: 'Düzenle',
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(find.byTooltip('Düzenle'));
    expect(taps, 1);
    handle.dispose();
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_done_mark.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/app/ui/kk_pressable.dart';

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
    // Düğme açılışta alttan yaylanarak gelir; yerine oturunca ölçülür.
    await tester.pumpAndSettle();
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

  testWidgets('kaydedilince yazı onay işaretine döner, ikinci dokunuş '
      'çağırmaz, bitince onDone', (tester) async {
    var taps = 0;
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: KkScaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: KkBottomAction(
            label: 'Kaydet',
            done: true,
            onDone: () => done++,
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    expect(find.byType(KkDoneMark), findsOneWidget);
    expect(find.text('Kaydet'), findsNothing);
    // Düğme soluklaşmaz: etkisiz ama marka renginde kalır.
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
      true,
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(done, 1);
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

  testWidgets('kökte başlık sabit durur, kaydırınca küçülmez', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => KkScaffold(
            appBar: kkRootAppBar(context, title: 'Kurulum'),
            body: ListView(
              children: [
                for (var i = 0; i < 50; i++)
                  SizedBox(height: 60, child: Text('satır $i')),
              ],
            ),
          ),
        ),
      ),
    );
    final before = tester.getRect(find.text('Kurulum'));
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Kurulum')), before);
  });

  // Telefon denemesi 5: arama kutusu kayıp gidince üst çubukta, üç
  // noktanın solunda simge olarak durur.
  testWidgets('arama kutusu kayınca çubukta simge belirir, dokununca başa '
      'döner ve kutuyu odaklar', (tester) async {
    final scroll = ScrollController();
    final focus = FocusNode();
    addTearDown(scroll.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => KkScaffold(
            appBar: kkRootAppBar(
              context,
              title: 'Kasa',
              actions: [
                KkBarSearchButton(
                  tooltip: 'Ara',
                  scrollController: scroll,
                  focusNode: focus,
                ),
                IconButton(
                  tooltip: 'Diğer işlemler',
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {},
                ),
              ],
            ),
            body: ListView(
              controller: scroll,
              children: [
                TextField(focusNode: focus),
                for (var i = 0; i < 50; i++)
                  SizedBox(height: 60, child: Text('satır $i')),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byTooltip('Ara'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Ara'), findsOneWidget);
    expect(
      tester.getCenter(find.byTooltip('Ara')).dx,
      lessThan(tester.getCenter(find.byTooltip('Diğer işlemler')).dx),
    );

    await tester.tap(find.byTooltip('Ara'));
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    expect(focus.hasFocus, isTrue);
    expect(find.byTooltip('Ara'), findsNothing);
  });

  testWidgets('alttaki ana düğme açılışta alttan yaylanarak gelir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          bottomNavigationBar: KkBottomAction(
            label: 'Kaydet',
            onPressed: () {},
          ),
          body: const SizedBox(),
        ),
      ),
    );
    double dy() => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(KkRiseIn),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .storage[13];
    expect(dy(), closeTo(24, 0.01));
    await tester.pump(KkMotion.enter);
    expect(dy(), closeTo(0, 0.01));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_card.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/app/ui/kk_pressable.dart';

Widget _host(List<Widget> children, {double textScale = 1}) => MaterialApp(
  theme: AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(body: ListView(children: children)),
  ),
);

void main() {
  testWidgets('normal yazıda kart 54 dp, uzun ad kesilir ve boy değişmez', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        const KkCard(key: Key('kisa'), title: Text('A')),
        KkCard(
          key: const Key('uzun'),
          title: Text('Çok uzun bir kayıt adı ' * 10),
          subtitle: Text('kullanici@ornek.com ' * 10),
        ),
      ]),
    );

    expect(tester.getSize(find.byKey(const Key('kisa'))).height, 54);
    expect(tester.getSize(find.byKey(const Key('uzun'))).height, 54);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en az boy değiştirilebilir', (tester) async {
    await tester.pumpWidget(
      _host([const KkCard(key: Key('kart'), title: Text('A'), minHeight: 72)]),
    );
    expect(tester.getSize(find.byKey(const Key('kart'))).height, 72);
  });

  testWidgets('yazı %200 olunca kart büyür ve taşmaz', (tester) async {
    await tester.pumpWidget(
      _host(textScale: 2, [
        const KkCard(
          key: Key('kart'),
          title: Text('GitHub'),
          subtitle: Text('ali@example.com'),
        ),
      ]),
    );

    expect(
      tester.getSize(find.byKey(const Key('kart'))).height,
      greaterThan(54),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('liste kartı arkasını bulanıklaştırmaz', (tester) async {
    await tester.pumpWidget(_host([const KkCard(title: Text('GitHub'))]));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('dokununca onTap, uzun basınca onLongPress çağrılır', (
    tester,
  ) async {
    var taps = 0;
    var longs = 0;
    await tester.pumpWidget(
      _host([
        KkCard(
          title: const Text('GitHub'),
          onTap: () => taps++,
          onLongPress: () => longs++,
        ),
      ]),
    );
    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('GitHub'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(longs, 1);
  });

  testWidgets('sondaki düğmeye dokunmak kartı açmaz', (tester) async {
    var taps = 0;
    var copies = 0;
    await tester.pumpWidget(
      _host([
        KkCard(
          title: const Text('GitHub'),
          onTap: () => taps++,
          trailing: IconButton(
            tooltip: 'Kopyala',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () => copies++,
          ),
        ),
      ]),
    );
    await tester.tap(find.byTooltip('Kopyala'));
    await tester.pumpAndSettle();
    expect(copies, 1);
    expect(taps, 0);
  });

  double flashAlpha(WidgetTester tester) =>
      (tester.widget<DecoratedBox>(find.byKey(KkCard.flashKey)).decoration
              as BoxDecoration)
          .color!
          .a;

  testWidgets('son kaydedilen kart bir kez parlar: zemin %0→%10→%0', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([const KkCard(title: Text('GitHub'), flash: true)]),
    );
    expect(flashAlpha(tester), 0);
    await tester.pump();
    // Ekran geçişi biter, sonra parlama.
    await tester.pump(KkCard.flashDelay);
    expect(flashAlpha(tester), closeTo(0, 0.01));
    await tester.pump(KkMotion.emphasis ~/ 2);
    expect(flashAlpha(tester), closeTo(0.10, 0.01));
    await tester.pumpAndSettle();
    expect(flashAlpha(tester), 0);
  });

  testWidgets('görünmeyen listede parlamaz, görünür olunca parlar', (
    tester,
  ) async {
    Widget host({required bool visible, required bool flash}) => TickerMode(
      enabled: visible,
      child: _host([KkCard(title: const Text('GitHub'), flash: flash)]),
    );
    await tester.pumpWidget(host(visible: false, flash: true));
    await tester.pump(KkCard.flashDelay + KkMotion.emphasis);
    expect(flashAlpha(tester), 0);
    // Kimlik okununca temizlenir; kart bekleyen parlamayı unutmaz.
    await tester.pumpWidget(host(visible: false, flash: false));
    await tester.pumpWidget(host(visible: true, flash: false));
    await tester.pump();
    await tester.pump(KkCard.flashDelay + KkMotion.emphasis ~/ 2);
    expect(flashAlpha(tester), closeTo(0.10, 0.01));
  });

  testWidgets('basılıyken kart hafifçe küçülür', (tester) async {
    await tester.pumpWidget(
      _host([KkCard(title: const Text('GitHub'), onTap: () {})]),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('GitHub')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      KkPressable.cardScale,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/kk_card.dart';

Widget _host(List<Widget> children, {double textScale = 1}) => MaterialApp(
  theme: AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(body: ListView(children: children)),
  ),
);

void main() {
  testWidgets('normal yazıda kart 64 dp, uzun ad kesilir ve boy değişmez', (
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

    expect(tester.getSize(find.byKey(const Key('kisa'))).height, 64);
    expect(tester.getSize(find.byKey(const Key('uzun'))).height, 64);
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
      greaterThan(64),
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
      lessThan(1),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });
}

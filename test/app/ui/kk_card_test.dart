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
  testWidgets(
    'kısa ve uzun adlı, alt yazılı ve alt yazısız kartlar aynı boyda',
    (tester) async {
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

      final short = tester.getSize(find.byKey(const Key('kisa'))).height;
      final long = tester.getSize(find.byKey(const Key('uzun'))).height;
      expect(short, 60);
      expect(long, 60);
      expect(tester.takeException(), isNull);
    },
  );

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
      greaterThan(60),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dokununca onTap çağrılır', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host([KkCard(title: const Text('GitHub'), onTap: () => taps++)]),
    );
    await tester.tap(find.text('GitHub'));
    expect(taps, 1);
  });

  testWidgets('filigran kartın içinde kırpılır, yazıyı örtmez', (tester) async {
    await tester.pumpWidget(
      _host([
        const KkCard(
          key: Key('kart'),
          title: Text('GitHub'),
          watermark: SizedBox(key: Key('filigran'), width: 120, height: 120),
        ),
      ]),
    );

    final card = tester.getRect(find.byKey(const Key('kart')));
    expect(tester.getSize(find.byKey(const Key('kart'))).height, 60);
    // Filigran kartın sağ kenarına yaslı, kartın dışına taşar ama kırpılır.
    final mark = tester.getRect(find.byKey(const Key('filigran')));
    expect(mark.right, greaterThan(card.right));
    expect(
      find.ancestor(
        of: find.byKey(const Key('filigran')),
        matching: find.byType(ClipRRect),
      ),
      findsOneWidget,
    );
  });
}

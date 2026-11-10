import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/theme.dart';
import 'package:keykey/app/ui/keykey_logo.dart';

void main() {
  testWidgets('logo istenen boyda ve "KeyKey" diye okunuyor', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: KeyKeyLogo(size: 80))),
    );

    expect(find.bySemanticsLabel('KeyKey'), findsOneWidget);
    expect(tester.getSize(find.byType(KeyKeyLogo)), const Size(80, 80));
  });

  test('yol yalnızca desteklenen komutları kullanır ve kutuya sığar', () {
    final path = KeyKeyLogo.parsePath(KeyKeyLogo.pathData);
    final bounds = path.getBounds();

    expect(bounds.left, 24);
    expect(bounds.top, 14);
    expect(bounds.right, 90);
    expect(bounds.bottom, 86);
    // K'nın iki kolu arasındaki boşluk dolu sayılmaz, gövde dolu sayılır.
    expect(path.contains(const Offset(30, 50)), isTrue);
    expect(path.contains(const Offset(60, 20)), isFalse);
  });

  test('desteklenmeyen komut hata verir', () {
    expect(
      () => KeyKeyLogo.parsePath('M0 0c1 1 2 2 3 3z'),
      throwsFormatException,
    );
  });

  test('logo rengi marka turuncusu', () {
    expect(KeyKeyLogo.color, KkColors.brandOrange);
  });
}

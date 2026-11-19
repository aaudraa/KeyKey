import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/card_number.dart';

void main() {
  test('kartın doldurulacak değerleri alınıyor', () {
    final card = AutofillCard.of(
      CardContent(
        name: 'Örnek kart',
        cardholder: 'DENEME KİŞİ',
        number: '4111111111111111',
        expiry: CardExpiry(month: 12, year: 2028),
        securityCode: '123',
        pin: '1234',
      ),
    );

    expect(card.number, '4111111111111111');
    expect(card.cardholder, 'DENEME KİŞİ');
    expect(card.expMonth, 12);
    expect(card.expYear, 2028);
    expect(card.securityCode, '123');
  });

  test('son kullanması olmayan kartta ay ve yıl yok', () {
    final card = AutofillCard.of(CardContent(name: 'Boş'));

    expect(card.expMonth, isNull);
    expect(card.expYear, isNull);
    expect(card.number, isEmpty);
  });

  test('değerler metne dökülmüyor', () {
    final card = AutofillCard.of(
      CardContent(
        name: 'Örnek',
        number: '4111111111111111',
        securityCode: '123',
      ),
    );

    expect(card.toString(), isNot(contains('4111')));
    expect(card.toString(), isNot(contains('123')));
  });
}

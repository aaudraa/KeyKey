import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/vault/data/card_number.dart';

void main() {
  group('detectCardBrand', () {
    final cases = {
      '4111111111111111': CardBrand.visa,
      '5555555555554444': CardBrand.mastercard,
      '2223000048400011': CardBrand.mastercard,
      '378282246310005': CardBrand.amex,
      '9792000000000001': CardBrand.troy,
      '6011111111111117': CardBrand.discover,
      '6221260000000000': CardBrand.discover,
      '6200000000000005': CardBrand.unionPay,
      '3530111333300000': CardBrand.jcb,
      '30569309025904': CardBrand.diners,
      '6759649826438453': CardBrand.maestro,
    };
    for (final MapEntry(key: number, value: brand) in cases.entries) {
      test('$number → ${brand.name}', () {
        expect(detectCardBrand(number), brand);
      });
    }

    test('tanınmayan ya da boş numara markasızdır', () {
      expect(detectCardBrand(''), isNull);
      expect(detectCardBrand('1234'), isNull);
    });

    test('markaların görünen adları', () {
      expect(CardBrand.amex.label, 'American Express');
      expect(CardBrand.diners.label, 'Diners Club');
      expect(CardBrand.troy.label, 'Troy');
    });
  });

  test('passesLuhn', () {
    expect(passesLuhn('4111111111111111'), isTrue);
    expect(passesLuhn('378282246310005'), isTrue);
    expect(passesLuhn('4111111111111112'), isFalse);
    expect(passesLuhn(''), isFalse);
  });

  test('groupCardNumber markaya göre gruplar', () {
    expect(groupCardNumber('378282246310005'), '3782 822463 10005');
    expect(groupCardNumber('4111111111111111'), '4111 1111 1111 1111');
    expect(groupCardNumber('30569309025904'), '3056 930902 5904');
    expect(groupCardNumber('411111'), '4111 11');
    expect(groupCardNumber(''), '');
  });

  test('maskCardNumber yalnızca son dört haneyi gösterir', () {
    expect(maskCardNumber('4111111111111111'), '•••• •••• •••• 1111');
    expect(maskCardNumber('378282246310005'), '•••• •••••• •0005');
    expect(maskCardNumber('4111111111111111123'), '•••• •••• •••• •••1 123');
    expect(maskCardNumber('1234'), '1234');
    expect(maskCardNumber(''), '');
  });

  test('lastFour', () {
    expect(lastFour('4111111111111111'), '1111');
    expect(lastFour('12'), '12');
  });

  test(
    'normalizeCardNumber boşluk ve tireyi atar, başka karakteri reddeder',
    () {
      expect(normalizeCardNumber('4111-1111 1111 1111'), '4111111111111111');
      expect(normalizeCardNumber(''), '');
      expect(normalizeCardNumber('4111x'), isNull);
      expect(normalizeCardNumber('1' * 20), isNull);
      expect(normalizeCardNumber('1' * 19), '1' * 19);
    },
  );

  group('CardExpiry', () {
    test('tryParse AA/YY okur', () {
      final expiry = CardExpiry.tryParse('12/28')!;
      expect(expiry.month, 12);
      expect(expiry.year, 2028);
    });

    test('tryParse geçersiz metni reddeder', () {
      for (final text in ['13/28', '00/30', '1/2', 'ab/cd', '', '1228']) {
        expect(CardExpiry.tryParse(text), isNull, reason: text);
      }
    });

    test('ay sonunda geçer', () {
      final february = CardExpiry(month: 2, year: 2028);
      expect(february.isExpiredAt(DateTime(2028, 2, 29, 23, 59)), isFalse);
      expect(february.isExpiredAt(DateTime(2028, 3)), isTrue);
      final december = CardExpiry(month: 12, year: 2028);
      expect(december.isExpiredAt(DateTime(2028, 12, 31)), isFalse);
      expect(december.isExpiredAt(DateTime(2029)), isTrue);
    });

    test('format iki haneli ay ve yıl yazar', () {
      expect(CardExpiry(month: 2, year: 2028).format(), '02/28');
    });

    test('aralık dışı değerler kurucuda reddedilir', () {
      expect(() => CardExpiry(month: 0, year: 2028), throwsArgumentError);
      expect(() => CardExpiry(month: 13, year: 2028), throwsArgumentError);
      expect(() => CardExpiry(month: 1, year: 1999), throwsArgumentError);
      expect(() => CardExpiry(month: 1, year: 2100), throwsArgumentError);
    });

    test('eşitlik', () {
      expect(
        CardExpiry(month: 1, year: 2030),
        CardExpiry(month: 1, year: 2030),
      );
    });
  });
}

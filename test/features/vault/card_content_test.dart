import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/card_number.dart';
import 'package:keykey/features/vault/data/record_content.dart';

Uint8List _json(Map<String, Object?> value) => utf8.encode(jsonEncode(value));

Map<String, Object?> _valid() => {
  'version': 1,
  'name': 'Maaş kartı',
  'cardholder': 'AD SOYAD',
  'number': '4111111111111111',
  'expMonth': 12,
  'expYear': 2028,
  'securityCode': '123',
  'pin': '1234',
  'notes': 'Bir not',
  'favorite': true,
  'folder': 'Banka',
  'trashedAt': null,
};

void main() {
  final full = CardContent(
    name: 'Maaş kartı',
    cardholder: 'AD SOYAD',
    number: '4111111111111111',
    expiry: CardExpiry(month: 12, year: 2028),
    securityCode: '123',
    pin: '1234',
    notes: 'Bir not',
    favorite: true,
    folder: 'Banka',
    trashedAt: DateTime.utc(2026, 11, 19, 12),
  );

  test('gidiş-dönüş', () {
    final back = CardContent.fromJsonBytes(full.toJsonBytes());
    expect(back.name, full.name);
    expect(back.cardholder, full.cardholder);
    expect(back.number, full.number);
    expect(back.expiry, full.expiry);
    expect(back.securityCode, full.securityCode);
    expect(back.pin, full.pin);
    expect(back.notes, full.notes);
    expect(back.favorite, isTrue);
    expect(back.folder, 'Banka');
    expect(back.trashedAt, full.trashedAt);
  });

  test('son kullanması olmayan kart', () {
    final empty = CardContent(name: 'Boş');
    final back = CardContent.fromJsonBytes(empty.toJsonBytes());
    expect(back.expiry, isNull);
    expect(back.number, '');
    expect(back.folder, isNull);
  });

  test('alan adları tasarımdaki gibi', () {
    final decoded =
        jsonDecode(utf8.decode(full.toJsonBytes())) as Map<String, Object?>;
    expect(decoded.keys.toSet(), _valid().keys.toSet());
    expect(decoded['version'], 1);
    expect(decoded['expMonth'], 12);
    expect(decoded['expYear'], 2028);
    expect(decoded['securityCode'], '123');
    expect(decoded['trashedAt'], full.trashedAt!.millisecondsSinceEpoch);
  });

  test('geçerli JSON okunur', () {
    final card = CardContent.fromJsonBytes(_json(_valid()));
    expect(card.expiry, CardExpiry(month: 12, year: 2028));
    expect(card.cardBrand, CardBrand.visa);
  });

  test('sabit örnek dosya açılıyor', () {
    // Bu dosya değişmez: 1.4.0'da kaydedilen kartlar her sürümde açılmalı.
    final fixture = File('test/fixtures/vault/card-v1.json').readAsBytesSync();

    final card = CardContent.fromJsonBytes(fixture);

    expect(card.name, 'Örnek kart');
    expect(card.cardholder, 'DENEME KİŞİ');
    expect(card.number, '4111111111111111');
    expect(card.expiry, CardExpiry(month: 12, year: 2028));
    expect(card.securityCode, '123');
    expect(card.pin, '1234');
    expect(card.notes, 'Not');
    expect(card.favorite, isTrue);
    expect(card.folder, 'Banka');
    expect(card.trashedAt, isNull);
  });

  group('katı okuma', () {
    final broken = <String, Map<String, Object?> Function()>{
      'bilinmeyen sürüm': () => _valid()..['version'] = 2,
      'eksik alan': () => _valid()..remove('pin'),
      'fazla alan': () => _valid()..['brand'] = 'Visa',
      'rakam dışı numara': () => _valid()..['number'] = '4111 1111',
      '20 haneli numara': () => _valid()..['number'] = '1' * 20,
      '5 haneli güvenlik kodu': () => _valid()..['securityCode'] = '12345',
      '13 haneli PIN': () => _valid()..['pin'] = '1' * 13,
      'yalnızca ay': () => _valid()..['expYear'] = null,
      'yalnızca yıl': () => _valid()..['expMonth'] = null,
      'ay 13': () => _valid()..['expMonth'] = 13,
      'yıl 1999': () => _valid()..['expYear'] = 1999,
      'metin ay': () => _valid()..['expMonth'] = '12',
      'yanlış tür favori': () => _valid()..['favorite'] = 'evet',
    };
    for (final MapEntry(key: name, value: build) in broken.entries) {
      test(name, () {
        expect(
          () => CardContent.fromJsonBytes(_json(build())),
          throwsA(isA<InvalidRecordContentException>()),
        );
      });
    }

    test('geçersiz JSON', () {
      expect(
        () => CardContent.fromJsonBytes(Uint8List.fromList([0x7b])),
        throwsA(isA<InvalidRecordContentException>()),
      );
    });

    test('hata mesajı numarayı içermez', () {
      final value = _valid()..['number'] = '41111111x';
      try {
        CardContent.fromJsonBytes(_json(value));
        fail('reddedilmeliydi');
      } on InvalidRecordContentException catch (error) {
        expect(error.toString(), isNot(contains('41111111')));
      }
    });
  });

  test('kurucu okunamayacak değeri reddeder', () {
    expect(() => CardContent(name: '', number: '41a'), throwsArgumentError);
    expect(
      () => CardContent(name: '', securityCode: '12345'),
      throwsArgumentError,
    );
    expect(() => CardContent(name: '', pin: '1' * 13), throwsArgumentError);
  });

  test('withTrashedAt ve withFavorite', () {
    expect(full.withTrashedAt(null).isTrashed, isFalse);
    expect(full.withTrashedAt(null).number, full.number);
    expect(full.withFavorite(favorite: false).favorite, isFalse);
  });

  test('copyWith klasörü ve son kullanmayı temizleyebilir', () {
    final cleared = full.copyWith(folder: null, expiry: null);
    expect(cleared.folder, isNull);
    expect(cleared.expiry, isNull);
    expect(full.copyWith(name: 'Yeni').folder, 'Banka');
  });
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/recovery_key.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  late SodiumSumo sodium;
  late RecoveryKeyCodec codec;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    codec = RecoveryKeyCodec(sodium);
  });

  Uint8List randomKey() => sodium.randombytes.buf(RecoveryKeyCodec.keyLength);

  // Sonuçlar rastlantıya bağlı olmasın diye sabit anahtar. Sağlama yalnızca 2
  // bayt olduğundan rastgele anahtarla çok düşük olasılıkla çakışabilirdi.
  Uint8List fixedKey() => Uint8List.fromList(
    List.generate(RecoveryKeyCodec.keyLength, (i) => (i + 1) * 7),
  );

  Matcher throwsInvalid() => throwsA(isA<InvalidRecoveryKeyException>());

  test('metin 5 karakterlik 11 gruptan oluşuyor', () {
    final text = codec.encode(randomKey());

    expect(
      text,
      matches(RegExp(r'^([0-9A-HJKMNP-TV-Z]{5}-){10}[0-9A-HJKMNP-TV-Z]{5}$')),
    );
  });

  test('kodlanan anahtar aynen geri okunuyor', () {
    for (var i = 0; i < 50; i++) {
      final key = randomKey();
      expect(codec.decode(codec.encode(key)), key);
    }
  });

  test('uç değerler aynen geri okunuyor', () {
    for (final value in [0x00, 0xFF]) {
      final key = Uint8List(RecoveryKeyCodec.keyLength)
        ..fillRange(0, RecoveryKeyCodec.keyLength, value);
      expect(codec.decode(codec.encode(key)), key);
    }
  });

  group('yazım kolaylığı', () {
    late Uint8List key;
    late String text;

    setUp(() {
      key = randomKey();
      text = codec.encode(key);
    });

    test('küçük harf, boşluk ve tiresiz yazım kabul ediliyor', () {
      expect(codec.decode(text.toLowerCase()), key);
      expect(codec.decode(text.replaceAll('-', ' ')), key);
      expect(codec.decode(text.replaceAll('-', '')), key);
    });

    test('0 ve 1 ile karışan harfler kabul ediliyor', () {
      expect(codec.decode(text.replaceAll('0', 'O')), key);
      expect(codec.decode(text.replaceAll('0', 'o')), key);
      for (final letter in ['I', 'i', 'L', 'l', 'ı', 'İ']) {
        expect(codec.decode(text.replaceAll('1', letter)), key);
      }
    });
  });

  group('hatalı metin reddediliyor', () {
    test('tek karakter yanlışsa', () {
      final text = codec.encode(fixedKey());
      final first = text[0];
      final wrong = '${first == 'A' ? 'B' : 'A'}${text.substring(1)}';

      expect(() => codec.decode(wrong), throwsInvalid());
    });

    test('yan yana iki karakter yer değiştirmişse', () {
      final text = codec.encode(fixedKey());
      expect(text[0], isNot(text[1]));
      final swapped = '${text[1]}${text[0]}${text.substring(2)}';

      expect(() => codec.decode(swapped), throwsInvalid());
    });

    test('eksik veya fazla karakter varsa', () {
      final text = codec.encode(randomKey());

      expect(() => codec.decode(text.substring(1)), throwsInvalid());
      expect(() => codec.decode('${text}A'), throwsInvalid());
      expect(() => codec.decode(''), throwsInvalid());
    });

    test('alfabede olmayan karakter varsa', () {
      final text = codec.encode(randomKey());

      for (final bad in ['U', 'ş', '!', '😀']) {
        expect(() => codec.decode('$bad${text.substring(1)}'), throwsInvalid());
      }
    });

    test('son kullanılmayan bitler sıfır değilse', () {
      final text = codec.encode(randomKey()).replaceAll('-', '');
      const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
      final last = alphabet.indexOf(text[text.length - 1]);
      final tampered =
          '${text.substring(0, text.length - 1)}${alphabet[last ^ 1]}';

      expect(() => codec.decode(tampered), throwsInvalid());
    });
  });

  test('yanlış uzunlukta anahtar kodlanamıyor', () {
    expect(() => codec.encode(Uint8List(31)), throwsArgumentError);
  });
}

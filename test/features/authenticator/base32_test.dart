import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/authenticator/data/base32.dart';

void main() {
  // RFC 4648 bölüm 10. Dolgu bizim biçimimizde yazılmadığı için atıldı.
  const vectors = {
    '': '',
    'f': 'MY',
    'fo': 'MZXQ',
    'foo': 'MZXW6',
    'foob': 'MZXW6YQ',
    'fooba': 'MZXW6YTB',
    'foobar': 'MZXW6YTBOI',
  };

  group('RFC 4648 vektörleri', () {
    vectors.forEach((plain, encoded) {
      test('"$plain"', () {
        expect(Base32.encode(ascii.encode(plain)), encoded);
        expect(Base32.decodeCanonical(encoded), ascii.encode(plain));
        expect(Base32.decodeLenient('$encoded======'), ascii.encode(plain));
      });
    });
  });

  test('her uzunlukta gidiş dönüş', () {
    for (var length = 0; length <= 64; length++) {
      final bytes = Uint8List.fromList(
        List.generate(length, (i) => (i * 37 + length) & 0xff),
      );
      final encoded = Base32.encode(bytes);
      expect(Base32.decodeCanonical(encoded), bytes, reason: '$length bayt');
      expect(Base32.decodeLenient(encoded.toLowerCase()), bytes);
    }
  });

  group('katı okuma', () {
    test('küçük harf, boşluk ve dolgu reddediliyor', () {
      for (final text in ['mzxw6', 'MZXW 6', 'MZXW6===', 'MZX-W6']) {
        expect(
          () => Base32.decodeCanonical(text),
          throwsFormatException,
          reason: text,
        );
      }
    });

    test('geçersiz uzunluk reddediliyor', () {
      for (final text in ['M', 'MZX', 'MZXW6Y']) {
        expect(
          () => Base32.decodeCanonical(text),
          throwsFormatException,
          reason: text,
        );
      }
    });

    test('artan bitleri sıfır olmayan metin reddediliyor', () {
      // "f" = MY; Y'nin son iki biti artan bittir. MZ aynı baytı verir ama
      // artan bitleri sıfır değildir.
      expect(Base32.decodeLenient('MZ'), ascii.encode('f'));
      expect(() => Base32.decodeCanonical('MZ'), throwsFormatException);
    });

    test('alfabe dışı karakter reddediliyor', () {
      for (final text in ['MZXW1', 'MZXW8', 'MZXW0', 'MZXWÇ', 'MZ😀']) {
        expect(
          () => Base32.decodeCanonical(text),
          throwsFormatException,
          reason: text,
        );
      }
    });
  });

  group('hoşgörülü okuma', () {
    test('elle yazılmış anahtar', () {
      expect(
        Base32.decodeLenient('jbsw y3dp-ehpk 3pxp'),
        Base32.decodeCanonical('JBSWY3DPEHPK3PXP'),
      );
    });

    test('Türkçe klavyedeki noktasız ı, I sayılıyor', () {
      expect(Base32.decodeLenient('ıııı'), Base32.decodeLenient('IIII'));
    });

    test('dolgu yalnızca sonda olabilir', () {
      expect(() => Base32.decodeLenient('MY==MY'), throwsFormatException);
    });

    test('alfabe dışı karakter yine reddediliyor', () {
      expect(() => Base32.decodeLenient('MZXW1'), throwsFormatException);
      expect(() => Base32.decodeLenient('MZXW.'), throwsFormatException);
    });

    test('bir bayta tamamlanmayan karakter boş sonuç veriyor', () {
      expect(Base32.decodeLenient('M'), isEmpty);
    });

    test('Türkçe klavyedeki noktalı büyük İ, I sayılıyor', () {
      expect(Base32.decodeLenient('İİİİ'), Base32.decodeLenient('IIII'));
    });
  });

  group('firstForeignCharacter', () {
    test('geçerli metinde null', () {
      expect(Base32.firstForeignCharacter('jbsw y3dp-ehpk 3pxp=='), isNull);
      expect(Base32.firstForeignCharacter('ıİ'), isNull);
      expect(Base32.firstForeignCharacter(''), isNull);
    });

    test('ilk yanlış karakteri olduğu gibi döndürüyor', () {
      expect(Base32.firstForeignCharacter('ABC0 18'), '0');
      expect(Base32.firstForeignCharacter('abc1'), '1');
      expect(Base32.firstForeignCharacter('ab.c'), '.');
      expect(Base32.firstForeignCharacter('abş'), 'ş');
    });

    test('decodeLenient ile aynı karakterleri kabul ediyor', () {
      for (final text in ['jbsw y3dp', 'MZXW1', 'ab.c', 'ıİi', 'MY==', '9']) {
        final accepted = Base32.firstForeignCharacter(text) == null;
        expect(
          () => Base32.decodeLenient(text),
          accepted ? returnsNormally : throwsFormatException,
          reason: text,
        );
      }
    });
  });
}

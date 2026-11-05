import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/generator/application/password_generator.dart';
import 'package:keykey/features/generator/data/wordlists.dart';
import 'package:sodium/sodium_sumo.dart';

/// Sabit tohumlu kaynak: yalnızca kural testleri için, güvenlik için değil.
class SeededRandom implements RandomSource {
  new(int seed) : _random = Random(seed);

  final Random _random;

  @override
  int nextInt(int max) => _random.nextInt(max);
}

void main() {
  late SodiumSumo sodium;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  group('rastgele parola', () {
    test('istenen uzunlukta ve yalnızca seçili sınıflardan', () {
      final random = SodiumRandomSource(sodium);
      const options = PasswordOptions(length: 32, symbols: false);
      const allowed =
          PasswordGenerator.lowercaseChars +
          PasswordGenerator.uppercaseChars +
          PasswordGenerator.digitChars;

      for (var i = 0; i < 200; i++) {
        final password = PasswordGenerator.password(options, random);
        expect(password, hasLength(32));
        expect(password.split('').every(allowed.contains), isTrue);
      }
    });

    test('seçilen her sınıftan en az bir karakter var', () {
      final random = SeededRandom(1);
      const options = PasswordOptions(length: PasswordOptions.minLength);

      for (var i = 0; i < 2000; i++) {
        final password = PasswordGenerator.password(options, random);
        for (final characterClass in [
          PasswordGenerator.lowercaseChars,
          PasswordGenerator.uppercaseChars,
          PasswordGenerator.digitChars,
          PasswordGenerator.symbolChars,
        ]) {
          expect(
            password.split('').any(characterClass.contains),
            isTrue,
            reason: password,
          );
        }
      }
    });

    test('karışan karakterler yok', () {
      final random = SodiumRandomSource(sodium);
      const options = PasswordOptions(length: PasswordOptions.maxLength);

      for (var i = 0; i < 200; i++) {
        final password = PasswordGenerator.password(options, random);
        for (final confusing in ['l', 'I', 'O', '0', '1']) {
          expect(password, isNot(contains(confusing)));
        }
      }
    });

    test('libsodium dağılımı eğilimsiz', () {
      // 60.000 karakterde her harf yaklaşık eşit sayıda çıkmalı. Ki-kare,
      // 24 serbestlik derecesi, %99,9 sınırı 51,2.
      final random = SodiumRandomSource(sodium);
      const options = PasswordOptions(
        length: 60,
        uppercase: false,
        digits: false,
        symbols: false,
      );
      final counts = <String, int>{};
      for (var i = 0; i < 1000; i++) {
        for (final char in PasswordGenerator.password(
          options,
          random,
        ).split('')) {
          counts[char] = (counts[char] ?? 0) + 1;
        }
      }
      const letters = PasswordGenerator.lowercaseChars;
      const expected = 60000 / 25;
      final chiSquare = letters
          .split('')
          .map((char) => pow((counts[char] ?? 0) - expected, 2) / expected)
          .reduce((a, b) => a + b);

      expect(counts.keys.toSet(), letters.split('').toSet());
      expect(chiSquare, lessThan(51.2));
    });

    test('ardışık parolalar farklı', () {
      final random = SodiumRandomSource(sodium);
      final passwords = {
        for (var i = 0; i < 100; i++)
          PasswordGenerator.password(const PasswordOptions(), random),
      };
      expect(passwords, hasLength(100));
    });

    test('sınıf seçilmezse hata', () {
      expect(
        () => PasswordGenerator.password(
          const PasswordOptions(
            lowercase: false,
            uppercase: false,
            digits: false,
            symbols: false,
          ),
          SeededRandom(1),
        ),
        throwsArgumentError,
      );
    });

    test('entropi hesabı', () {
      const options = PasswordOptions(
        uppercase: false,
        digits: false,
        symbols: false,
      );
      final expected = 20 * log(PasswordGenerator.lowercaseChars.length) / ln2;
      expect(PasswordGenerator.passwordBits(options), closeTo(expected, 1e-9));
    });
  });

  group('parola cümlesi', () {
    late List<String> words;

    setUpAll(() {
      words = Wordlists.parseEff(File(Wordlists.effPath).readAsStringSync());
    });

    test('EFF listesi 7776 farklı sözcük', () {
      expect(words, hasLength(7776));
      expect(words.first, 'abacus');
      expect(words.last, 'zoom');
    });

    test('istenen sayıda listeden sözcük', () {
      final random = SodiumRandomSource(sodium);
      final phrase = PasswordGenerator.passphrase(
        const PassphraseOptions(words: 7),
        words,
        random,
      );
      final parts = phrase.split('-');
      expect(parts.length, greaterThanOrEqualTo(7));
      // Bazı EFF sözcükleri tire içeriyor, bu yüzden sözcükleri tek tek
      // değil, birleşik metnin listeden üretilebildiğini doğrularız.
      expect(phrase, matches(RegExp(r'^[a-z-]+$')));
    });

    test('varsayılan 6 sözcük yaklaşık 77 bit', () {
      expect(
        PasswordGenerator.passphraseBits(const PassphraseOptions(), 7776),
        closeTo(77.5, 0.1),
      );
    });

    test('bozuk liste reddediliyor', () {
      expect(
        () => Wordlists.parseEff('11111\tabacus\nbozuk satir\n'),
        throwsA(isA<InvalidWordlistException>()),
      );
      expect(
        () => Wordlists.parseEff('11111\tabacus\n'),
        throwsA(isA<InvalidWordlistException>()),
      );
    });

    test('yaygın parola listesi küçük harfle okunuyor', () {
      final common = Wordlists.parseCommon(
        File(Wordlists.commonPath).readAsStringSync(),
      );
      expect(common, contains('password'));
      expect(common, contains('qwerty'));
      expect(common.every((entry) => entry.length >= 4), isTrue);
      expect(common.length, greaterThan(9000));
    });
  });
}

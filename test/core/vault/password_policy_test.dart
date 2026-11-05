import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/vault/password_policy.dart';

void main() {
  group('en kısa uzunluk', () {
    test('kod noktası olarak sayılıyor', () {
      expect(PasswordPolicy.isAcceptable('123456789'), isFalse);
      expect(PasswordPolicy.isAcceptable('1234567890'), isTrue);
      // Her emoji iki UTF-16 birimi ama tek kod noktasıdır.
      expect(PasswordPolicy.isAcceptable('😀😀😀😀😀'), isFalse);
      expect(PasswordPolicy.isAcceptable('😀😀😀😀😀😀😀😀😀😀'), isTrue);
    });
  });

  group('güç tahmini', () {
    PasswordStrength strength(String password) =>
        PasswordPolicy.strengthOf(password);

    test('kısa parola', () {
      expect(strength('kisa'), PasswordStrength.tooShort);
    });

    test('sık kullanılan parolalar zayıf', () {
      for (final password in [
        '1234567890',
        'password123',
        'Galatasaray1905',
        'şifre123456',
        'QWERTYUIOP',
      ]) {
        expect(strength(password), PasswordStrength.weak, reason: password);
      }
    });

    test('tekrar eden karakterler uzunlukla kurtulamıyor', () {
      expect(strength('aaaaaaaaaaaaaaaaaaaaaaaa'), PasswordStrength.weak);
      expect(strength('abababababababababab'), PasswordStrength.weak);
    });

    test('uzun ve çeşitli parola güçlü', () {
      expect(strength('kırmızı-Bisiklet-47-Deniz'), PasswordStrength.strong);
    });

    test('orta uzunlukta parola orta', () {
      expect(strength('bisikletdeniz'), PasswordStrength.fair);
    });

    test('desenler gücü düşürüyor', () {
      for (final password in [
        'qwertyuiop123',
        'asdfghjklzxcv',
        'abcdefghijkl',
        '0987654321ab',
        'Ahmet1990Ahmet',
        '01.01.1990abcd',
        'aaaaaaaaaaaaaaaaBBBB',
      ]) {
        expect(
          PasswordPolicy.strengthOf(password),
          PasswordStrength.weak,
          reason: password,
        );
      }
    });

    test('yaygın listede olanlar ve türevleri zayıf', () {
      const common = {'dragonball', 'sunflower'};
      for (final password in [
        'dragonball',
        'DragonBall',
        'dragonball123!',
        'dr4g0nb4ll',
        'sunfl0wer2024',
      ]) {
        expect(
          PasswordPolicy.strengthOf(password, common: common),
          PasswordStrength.weak,
          reason: password,
        );
      }
    });

    test('listeye girince başka türlü orta olan parola zayıf oluyor', () {
      const password = 'MountainBicycle';
      expect(PasswordPolicy.strengthOf(password), isNot(PasswordStrength.weak));
      expect(
        PasswordPolicy.strengthOf(password, common: const {'mountainbicycle'}),
        PasswordStrength.weak,
      );
    });

    test('rastgele ve uzun parolalar güçlü kalıyor', () {
      for (final password in [
        'kırmızı-Bisiklet-47-Deniz',
        'Tq8#mZ2!vR9pL@4w',
        'correct-horse-battery-staple',
      ]) {
        expect(
          PasswordPolicy.strengthOf(password),
          PasswordStrength.strong,
          reason: password,
        );
      }
    });

    test('kurala uyan zayıf parola yine de kabul ediliyor', () {
      expect(PasswordPolicy.isAcceptable('1234567890'), isTrue);
    });
  });
}

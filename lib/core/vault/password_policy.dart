import 'dart:math';

/// Ana parolanın kaba güç tahmini.
enum PasswordStrength { tooShort, weak, fair, strong }

/// Ana parola kuralı ve güç göstergesi.
///
/// Tahmin kabadır: uzunluk, karakter çeşitliliği ve kısa bir liste. Gerçek
/// gücü ölçmez, yalnızca belli hataları yakalar. Bkz. güvenlik tasarımı
/// belgesinin Kasa oluşturma bölümü.
abstract final class PasswordPolicy {
  /// En kısa ana parola, Unicode kod noktası olarak.
  static const minLength = 10;

  static const _fairBits = 45;
  static const _strongBits = 70;

  static const _common = {
    '1234567890',
    '12345678910',
    '0123456789',
    '1111111111',
    '1234512345',
    'qwertyuiop',
    'qwertyuiop1',
    'qazwsxedcrfv',
    'password123',
    'password1234',
    'passwordpassword',
    'administrator',
    'iloveyou123',
    'letmein1234',
    'welcome1234',
    'football123',
    'sifre12345',
    'sifre123456',
    'parola12345',
    'parola123456',
    'şifre12345',
    'şifre123456',
    'galatasaray',
    'galatasaray1905',
    'fenerbahce',
    'fenerbahce1907',
    'besiktas1903',
    'trabzonspor',
    'trabzonspor1967',
    'mustafakemal',
    'mustafakemalataturk',
    'kullaniciadi',
  };

  static bool isAcceptable(String password) =>
      password.runes.length >= minLength;

  static PasswordStrength strengthOf(String password) {
    if (!isAcceptable(password)) return PasswordStrength.tooShort;
    if (_looksCommon(password)) return PasswordStrength.weak;

    final bits = _estimateBits(password);
    if (bits >= _strongBits) return PasswordStrength.strong;
    if (bits >= _fairBits) return PasswordStrength.fair;
    return PasswordStrength.weak;
  }

  static bool _looksCommon(String password) {
    final lower = password.toLowerCase();
    return _common.contains(lower) || lower.runes.toSet().length <= 3;
  }

  /// Tekrar eden karakterler hesaba katılmaz, böylece `aaaaaaaaaaaa1` gibi
  /// metinler uzunluğu sayesinde güçlü görünmez.
  static double _estimateBits(String password) {
    var hasLower = false;
    var hasUpper = false;
    var hasDigit = false;
    var hasOther = false;
    for (final rune in password.runes) {
      if (rune >= 0x61 && rune <= 0x7A) {
        hasLower = true;
      } else if (rune >= 0x41 && rune <= 0x5A) {
        hasUpper = true;
      } else if (rune >= 0x30 && rune <= 0x39) {
        hasDigit = true;
      } else {
        hasOther = true;
      }
    }
    final alphabet =
        (hasLower ? 26 : 0) +
        (hasUpper ? 26 : 0) +
        (hasDigit ? 10 : 0) +
        (hasOther ? 33 : 0);
    final distinct = password.runes.toSet().length;
    final effective = min(password.runes.length, distinct * 2);
    return effective * (log(alphabet) / ln2);
  }
}

import 'dart:math';

/// Ana parolanın ve kayıt parolalarının kaba güç tahmini.
enum PasswordStrength { tooShort, weak, fair, strong }

/// Ana parola kuralı ve güç göstergesi.
///
/// Tahmin kabadır: uzunluk ve karakter çeşitliliğinden bir entropi hesaplanır,
/// yaygın parolalar, tekrarlar, ardışık karakterler, klavye dizileri ve
/// tarihler bunu düşürür. Gerçek gücü ölçmez, yalnızca belli hataları
/// yakalar. Bkz. güvenlik tasarımı belgesi.
abstract final class PasswordPolicy {
  /// En kısa ana parola, Unicode kod noktası olarak.
  static const minLength = 10;

  static const _fairBits = 45;
  static const _strongBits = 70;

  /// Yaygın listede olmasa da sık görülen Türkçe parolalar.
  static const _builtInCommon = {
    'sifre12345',
    'sifre123456',
    'parola12345',
    'parola123456',
    'galatasaray',
    'fenerbahce',
    'besiktas',
    'trabzonspor',
    'mustafakemal',
    'ataturk',
    'kullaniciadi',
    'istanbul',
    'ankara',
    'izmir',
    'turkiye',
  };

  static const _keyboardRows = [
    '1234567890',
    'qwertyuiop',
    'asdfghjkl',
    'zxcvbnm',
    'qwertyuıopğü',
    'asdfghjklşi',
    'zxcvbnmöç',
  ];

  static final _year = RegExp('(19|20)[0-9]{2}');
  static final _date = RegExp('[0-9]{1,2}[./-][0-9]{1,2}[./-][0-9]{2,4}');

  static bool isAcceptable(String password) =>
      password.runes.length >= minLength;

  /// [common] yaygın parolalardır, küçük harfle.
  static PasswordStrength strengthOf(
    String password, {
    Set<String> common = const {},
  }) {
    if (!isAcceptable(password)) return PasswordStrength.tooShort;
    if (_looksCommon(password, common)) return PasswordStrength.weak;

    final bits = estimateBits(password);
    if (bits >= _strongBits) return PasswordStrength.strong;
    if (bits >= _fairBits) return PasswordStrength.fair;
    return PasswordStrength.weak;
  }

  /// Desenler düşüldükten sonra kalan yaklaşık bit sayısı.
  static double estimateBits(String password) {
    final runes = password.runes.toList();
    if (runes.isEmpty) return 0;
    final effective = _effectiveLength(password);
    return effective * (log(_alphabetSize(runes)) / ln2);
  }

  static int _alphabetSize(List<int> runes) {
    var hasLower = false;
    var hasUpper = false;
    var hasDigit = false;
    var hasOther = false;
    for (final rune in runes) {
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
    final size =
        (hasLower ? 26 : 0) +
        (hasUpper ? 26 : 0) +
        (hasDigit ? 10 : 0) +
        (hasOther ? 33 : 0);
    return max(size, 2);
  }

  /// Her karakter, tahmin edilebilirliğine göre 0 ile 1 arasında sayılır.
  static double _effectiveLength(String password) {
    final lower = password.toLowerCase();
    final runes = lower.runes.toList();
    final repeated = _repeatedChunks(runes);
    var length = 0.0;
    for (var i = 0; i < runes.length; i++) {
      if (repeated[i]) {
        // Daha önce geçen bir parçanın tekrarı: ahmet1990ahmet.
      } else if (i == 0) {
        length += 1;
      } else if (runes[i] == runes[i - 1]) {
        // Tekrar: neredeyse bilgi taşımaz.
      } else if ((runes[i] - runes[i - 1]).abs() == 1) {
        length += 0.2; // abc, 123, cba
      } else if (_keyboardAdjacent(runes[i - 1], runes[i])) {
        length += 0.3; // qwer, asdf
      } else {
        length += 1;
      }
    }
    // Yıl ve tarih, rakam sayısının söylediğinden çok daha tahmin edilebilir.
    for (final match in _date.allMatches(lower)) {
      length -= max(0, match.group(0)!.length - 3);
    }
    for (final _ in _year.allMatches(lower)) {
      length -= 2;
    }
    // Az sayıda farklı karakter uzunlukla telafi edilemez.
    final distinct = runes.toSet().length;
    return max(0, min(length, distinct * 2.0));
  }

  /// En az 3 karakterlik ve daha önce geçmiş parçaları işaretler.
  static List<bool> _repeatedChunks(List<int> runes) {
    const minChunk = 3;
    final marked = List.filled(runes.length, false);
    for (var start = minChunk; start < runes.length; start++) {
      for (var earlier = 0; earlier + minChunk <= start; earlier++) {
        var length = 0;
        while (start + length < runes.length &&
            earlier + length < start &&
            runes[earlier + length] == runes[start + length]) {
          length++;
        }
        if (length >= minChunk) {
          for (var i = start; i < start + length; i++) {
            marked[i] = true;
          }
        }
      }
    }
    return marked;
  }

  static bool _keyboardAdjacent(int a, int b) {
    final pair = String.fromCharCodes([a, b]);
    final reversed = String.fromCharCodes([b, a]);
    return _keyboardRows.any(
      (row) => row.contains(pair) || row.contains(reversed),
    );
  }

  static bool _looksCommon(String password, Set<String> common) {
    final lower = password.toLowerCase();
    if (lower.runes.toSet().length <= 3) return true;
    // Sona eklenen rakam ve işaretler önce atılır: password123!, sunfl0wer2024.
    // Harf değişimi sonra yapılır, yoksa yıl da harfe dönüşür.
    final stripped = lower.replaceAll(RegExp(r'[0-9!@#$%^&*.?_-]+$'), '');
    final candidates = {lower, stripped, _unleet(lower), _unleet(stripped)};
    return candidates.any(
      (candidate) =>
          candidate.length >= 4 &&
          (common.contains(candidate) || _builtInCommon.contains(candidate)),
    );
  }

  static String _unleet(String text) => text
      .replaceAll('0', 'o')
      .replaceAll('1', 'i')
      .replaceAll('3', 'e')
      .replaceAll('4', 'a')
      .replaceAll('5', 's')
      .replaceAll('7', 't')
      .replaceAll('@', 'a')
      .replaceAll(r'$', 's');
}

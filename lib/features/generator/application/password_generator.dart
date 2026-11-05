import 'dart:math';

/// Eğilimsiz rastgele tam sayı kaynağı. Uygulamada libsodium'dur.
abstract interface class RandomSource {
  /// `0 <= sonuç < max`.
  int nextInt(int max);
}

/// Rastgele parola seçenekleri.
final class PasswordOptions {
  const new({
    this.length = 20,
    this.lowercase = true,
    this.uppercase = true,
    this.digits = true,
    this.symbols = true,
  });

  static const minLength = 8;
  static const maxLength = 64;

  final int length;
  final bool lowercase;
  final bool uppercase;
  final bool digits;
  final bool symbols;

  bool get hasAnyClass => lowercase || uppercase || digits || symbols;

  PasswordOptions copyWith({
    int? length,
    bool? lowercase,
    bool? uppercase,
    bool? digits,
    bool? symbols,
  }) {
    return PasswordOptions(
      length: length ?? this.length,
      lowercase: lowercase ?? this.lowercase,
      uppercase: uppercase ?? this.uppercase,
      digits: digits ?? this.digits,
      symbols: symbols ?? this.symbols,
    );
  }
}

/// Parola cümlesi seçenekleri.
final class PassphraseOptions {
  const new({this.words = 6, this.separator = '-'});

  static const minWords = 4;
  static const maxWords = 12;

  final int words;
  final String separator;
}

/// Parola ve parola cümlesi üretir.
///
/// Bütün seçimler [RandomSource] üzerinden yapılır, modülo eğilimi yoktur.
abstract final class PasswordGenerator {
  static const lowercaseChars = 'abcdefghijkmnopqrstuvwxyz';
  static const uppercaseChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const digitChars = '23456789';
  static const symbolChars = r'!#$%&*+-=?@^_~';

  // Karıştırılan karakterler (l, I, O, 0, 1) bilerek yok: kâğıda yazılan veya
  // elle girilen parolalarda hata yaptırıyorlar.

  static List<String> _classes(PasswordOptions options) => [
    if (options.lowercase) lowercaseChars,
    if (options.uppercase) uppercaseChars,
    if (options.digits) digitChars,
    if (options.symbols) symbolChars,
  ];

  /// Seçilen her sınıftan en az bir karakter içerir.
  static String password(PasswordOptions options, RandomSource random) {
    final classes = _classes(options);
    if (classes.isEmpty) throw ArgumentError('En az bir karakter sınıfı.');
    if (options.length < classes.length) {
      throw ArgumentError('Uzunluk sınıf sayısından kısa.');
    }
    final alphabet = classes.join();
    final chars = <String>[
      for (final characterClass in classes)
        characterClass[random.nextInt(characterClass.length)],
      for (var i = classes.length; i < options.length; i++)
        alphabet[random.nextInt(alphabet.length)],
    ];
    _shuffle(chars, random);
    return chars.join();
  }

  /// Yaklaşık entropi. "Her sınıftan en az bir" kuralının getirdiği küçük
  /// daralma göz ardı edilir.
  static double passwordBits(PasswordOptions options) {
    final size = _classes(options).join().length;
    return size == 0 ? 0 : options.length * log(size) / ln2;
  }

  static String passphrase(
    PassphraseOptions options,
    List<String> wordlist,
    RandomSource random,
  ) {
    if (wordlist.isEmpty) throw ArgumentError('Sözcük listesi boş.');
    return [
      for (var i = 0; i < options.words; i++)
        wordlist[random.nextInt(wordlist.length)],
    ].join(options.separator);
  }

  static double passphraseBits(PassphraseOptions options, int wordlistSize) =>
      wordlistSize < 2 ? 0 : options.words * log(wordlistSize) / ln2;

  /// Fisher-Yates.
  static void _shuffle(List<String> items, RandomSource random) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final swap = items[i];
      items[i] = items[j];
      items[j] = swap;
    }
  }
}

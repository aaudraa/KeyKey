import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/features/generator/application/password_generator.dart';
import 'package:sodium/sodium_sumo.dart';

/// Sözcük listesi beklenen biçimde değil. Uygulamanın paketi bozulmuş olabilir.
final class InvalidWordlistException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => 'InvalidWordlistException: $message';
}

abstract final class Wordlists {
  static const effPath = 'resources/assets/wordlists/eff_large_wordlist.txt';
  static const commonPath =
      'resources/assets/wordlists/common_passwords_10k.txt';
  static const effSize = 7776;

  static final _effLine = RegExp(r'^[1-6]{5}\t([a-z-]+)$');

  /// EFF listesini katı kurallarla okur: 7776 farklı sözcük.
  static List<String> parseEff(String text) {
    final words = <String>[];
    for (final line in text.split('\n')) {
      if (line.isEmpty) continue;
      final match = _effLine.firstMatch(line);
      if (match == null) {
        throw const InvalidWordlistException('Geçersiz satır.');
      }
      words.add(match.group(1)!);
    }
    if (words.length != effSize || words.toSet().length != effSize) {
      throw const InvalidWordlistException('Beklenmeyen sözcük sayısı.');
    }
    return List.unmodifiable(words);
  }

  /// Yaygın parolaları küçük harfle döndürür. Kısa olanlar zaten reddedilir.
  static Set<String> parseCommon(String text) {
    return Set.unmodifiable({
      for (final line in text.split('\n'))
        if (line.trim().length >= 4) line.trim().toLowerCase(),
    });
  }
}

final effWordlistProvider = FutureProvider<List<String>>((ref) async {
  return Wordlists.parseEff(await rootBundle.loadString(Wordlists.effPath));
});

final commonPasswordsProvider = FutureProvider<Set<String>>((ref) async {
  return Wordlists.parseCommon(
    await rootBundle.loadString(Wordlists.commonPath),
  );
});

/// Uygulamada libsodium'un eğilimsiz rastgele üreticisi.
final class SodiumRandomSource implements RandomSource {
  const new(this._sodium);

  final SodiumSumo _sodium;

  @override
  int nextInt(int max) => _sodium.randombytes.uniform(max);
}

/// `main` doldurur; testler kendi kaynaklarını verebilir.
final randomSourceProvider = Provider<RandomSource>(
  (ref) => throw UnimplementedError('Rastgele kaynak sağlanmadı.'),
);

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:keykey/core/network/pwned_passwords_client.dart';
import 'package:keykey/features/vault/application/login_search.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

/// Parolanın SHA-1 özeti: UTF-8 baytları, büyük harfli onaltılık, 40
/// karakter. Have I Been Pwned'ın verisi bu biçimdedir.
String pwnedHash(String password) =>
    sha1.convert(utf8.encode(password)).toString().toUpperCase();

final RegExp _rangeLine = RegExp(r'^([0-9A-F]{35}):([0-9]+)$');

/// Pwned Passwords yanıtını okur: sonek → görülme sayısı. Sayısı 0 olan
/// satırlar dolgudur ve atılır. Bir satır biçime uymazsa (örneğin bir
/// giriş sayfasının HTML'i) yanıtın tamamı geçersizdir: [FormatException].
Map<String, int> parsePwnedRange(String body) {
  final counts = <String, int>{};
  for (final raw in body.split('\n')) {
    final line = raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
    if (line.isEmpty) continue;
    final match = _rangeLine.firstMatch(line);
    final count = match == null ? null : int.tryParse(match[2]!);
    if (count == null) {
      throw const FormatException('Pwned Passwords yanıtı geçersiz');
    }
    if (count > 0) counts[match![1]!] = count;
  }
  return counts;
}

/// Bir denetimin sonucu. Yalnızca bellekte tutulur.
final class BreachResult {
  const new({required this.counts, required this.checked});

  /// Sızıntılarda görülen özetler → görülme sayısı (her zaman > 0).
  final Map<String, int> counts;

  /// Denetlenen bütün özetler.
  final Set<String> checked;

  /// [password] denetlenmediyse `null`, sızıntılarda görülmediyse 0.
  int? countFor(String password) {
    final hash = pwnedHash(password);
    if (!checked.contains(hash)) return null;
    return counts[hash] ?? 0;
  }
}

/// Denetim, kullanıcı ekrandan çıktığı ya da kasa kilitlendiği için
/// bırakıldı.
final class BreachCheckCancelled implements Exception {
  const new();
}

/// Kasadaki parolaları k-anonimlikle denetler: yalnızca özetin ilk 5
/// karakteri gider, sonekler telefonda karşılaştırılır.
final class BreachChecker {
  new(this.source, {this.concurrency = 4, Random? random})
    : _random = random ?? Random.secure();

  final PwnedRangeSource source;

  /// Aynı anda en çok bu kadar istek.
  final int concurrency;

  final Random _random;

  /// Çöp kutusunda olmayan, parolası boş olmayan kayıtları denetler.
  ///
  /// Önekler karışık sırayla sorulur. Her önek bir kez yeniden denenir;
  /// yine olmazsa denetimin tamamı hata verir ([PwnedPasswordsException]
  /// ya da [FormatException]) ve yarım sonuç dönmez. [isCancelled] true
  /// olunca yeni istek başlamaz, [BreachCheckCancelled] fırlar.
  Future<BreachResult> check(
    Iterable<LoginItem> items, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final hashes = {
      for (final item in items)
        if (!item.content.isTrashed && item.content.password.isNotEmpty)
          pwnedHash(item.content.password),
    };
    final suffixes = <String, Set<String>>{};
    for (final hash in hashes) {
      (suffixes[hash.substring(0, 5)] ??= {}).add(hash.substring(5));
    }
    final prefixes = suffixes.keys.toList()..shuffle(_random);
    final total = prefixes.length;
    final counts = <String, int>{};
    var next = 0;
    var done = 0;
    Object? failure;
    StackTrace? failureTrace;
    onProgress?.call(0, total);

    Future<void> worker() async {
      while (failure == null && next < total) {
        if (isCancelled?.call() ?? false) {
          failure ??= const BreachCheckCancelled();
          return;
        }
        final prefix = prefixes[next++];
        try {
          final range = parsePwnedRange(await _fetch(prefix, isCancelled));
          for (final suffix in suffixes[prefix]!) {
            final count = range[suffix];
            if (count != null) counts['$prefix$suffix'] = count;
          }
        } on Object catch (error, trace) {
          failure ??= error;
          failureTrace ??= trace;
          return;
        }
        done++;
        onProgress?.call(done, total);
      }
    }

    await Future.wait([
      for (var i = 0; i < min(concurrency, total); i++) worker(),
    ]);
    if (failure case final error?) {
      Error.throwWithStackTrace(error, failureTrace ?? StackTrace.current);
    }
    return BreachResult(counts: counts, checked: hashes);
  }

  Future<String> _fetch(String prefix, bool Function()? isCancelled) async {
    try {
      return await source.fetchRange(prefix);
    } on PwnedPasswordsException {
      if (isCancelled?.call() ?? false) throw const BreachCheckCancelled();
      return await source.fetchRange(prefix);
    }
  }
}

/// Sızıntılarda görülen etkin kayıtlar ve görülme sayıları: çok görülen
/// önce, eşitse ada göre. Denetimden sonra parolası değişen kayıt yeni
/// parolası denetlenmediği için listede yoktur.
List<(LoginItem, int)> leakedLogins(
  Iterable<LoginItem> items,
  BreachResult result,
) =>
    [
      for (final item in items)
        if (!item.content.isTrashed && item.content.password.isNotEmpty)
          if (result.countFor(item.content.password) case final count?
              when count > 0)
            (item, count),
    ]..sort((a, b) {
      final byCount = b.$2.compareTo(a.$2);
      return byCount != 0
          ? byCount
          : foldForSearch(a.$1.content.name)
                .compareTo(foldForSearch(b.$1.content.name));
    });

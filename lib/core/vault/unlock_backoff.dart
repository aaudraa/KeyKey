/// Hatalı parola beklemesi. Tablo güvenlik tasarımı belgesinin Kilit
/// bölümündedir.
///
/// Bu bir hız sınırıdır, kilit değildir: asıl koruma Argon2id ve parolanın
/// gücüdür.
abstract final class UnlockBackoff {
  /// [failedAttempts] hatalı denemeden sonra beklenecek süre.
  static Duration waitAfter(int failedAttempts) => switch (failedAttempts) {
    <= 3 => Duration.zero,
    4 => const Duration(seconds: 5),
    5 => const Duration(seconds: 15),
    6 => const Duration(seconds: 30),
    7 => const Duration(minutes: 1),
    8 => const Duration(minutes: 5),
    _ => const Duration(minutes: 15),
  };

  /// Şu an kalan bekleme. Süre dolduysa sıfır döner.
  ///
  /// Saat [lastFailedAt] öncesine alınmışsa bekleme baştan başlar, böylece
  /// saati geri almak süreyi kısaltmaz. Bu durumda son hata zamanı da şu ana
  /// çekilmelidir, bkz. [clockMovedBack].
  static Duration remaining({
    required int failedAttempts,
    required DateTime? lastFailedAt,
    required DateTime now,
  }) {
    if (lastFailedAt == null) return Duration.zero;
    final wait = waitAfter(failedAttempts);
    if (clockMovedBack(lastFailedAt: lastFailedAt, now: now)) return wait;
    final left = wait - now.difference(lastFailedAt);
    return left.isNegative ? Duration.zero : left;
  }

  static bool clockMovedBack({
    required DateTime lastFailedAt,
    required DateTime now,
  }) => now.isBefore(lastFailedAt);
}

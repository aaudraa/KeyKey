/// Otomatik yedek dosyalarının adı ve budama kuralı. Tasarım:
/// `resources/docs/otomatik-yedek.md`, "Budama".
abstract final class AutoBackupFiles {
  /// Arayüz diline göre önekler. Dil değişse de eski dosyalar tanınır.
  static const prefixes = {'keykey-otomatik', 'keykey-auto'};

  /// Bu kadar günün en yeni dosyası kalır.
  static const keepDays = 14;

  static const extension = '.keykey';

  static final _pattern = RegExp(
    r'^(keykey-otomatik|keykey-auto)-(\d{4})-(\d{2})-(\d{2})-(\d{2})(\d{2})(\d{2})\.keykey$',
  );

  /// `keykey-otomatik-2026-11-18-153012.keykey`; yerel saatle.
  static String nameFor(DateTime time, {required String prefix}) {
    String two(int value) => value.toString().padLeft(2, '0');
    final t = time.toLocal();
    return '$prefix-${t.year}-${two(t.month)}-${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}$extension';
  }

  /// Adı kalıba tam uyan dosyanın zamanı (yerel); uymuyorsa `null`.
  static DateTime? parse(String name) {
    final match = _pattern.firstMatch(name);
    if (match == null) return null;
    final [year, month, day, hour, minute, second] = [
      for (var group = 2; group <= 7; group++) int.parse(match.group(group)!),
    ];
    final time = DateTime(year, month, day, hour, minute, second);
    // DateTime taşan değerleri ileri kaydırır (13. ay, 30 Şubat); kaydıysa ad
    // geçersizdir.
    final valid =
        time.year == year &&
        time.month == month &&
        time.day == day &&
        time.hour == hour &&
        time.minute == minute &&
        time.second == second;
    return valid ? time : null;
  }

  /// Silinecek otomatik yedekler: her günün en yenisi ve en yeni [keepDays]
  /// gün kalır. Kalıba uymayan adlar hiçbir zaman listeye girmez.
  static List<String> toDelete(Iterable<String> names) {
    final dated =
        [
          for (final name in names)
            if (parse(name) case final time?) (name: name, time: time),
        ]..sort((a, b) {
          final byTime = b.time.compareTo(a.time);
          return byTime != 0 ? byTime : b.name.compareTo(a.name);
        });
    final keptDays = <DateTime>{};
    final deleted = <String>[];
    for (final file in dated) {
      final day = DateTime(file.time.year, file.time.month, file.time.day);
      if (keptDays.length < keepDays && keptDays.add(day)) continue;
      deleted.add(file.name);
    }
    return deleted;
  }
}

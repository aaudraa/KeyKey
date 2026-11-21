/// Otomatik yedek dosyalarının adı ve budama kuralı. Tasarım:
/// `resources/docs/otomatik-yedek.md`, "Budama".
///
/// Ad: `keykey-otomatik-2026-11-18-153012-a1b2c3.keykey`. Sondaki altı
/// karakter bu kurulumun cihaz kimliğidir; aynı klasörü kullanan iki kurulum
/// (iki telefon, ya da eski ve yeni telefon) birbirinin yedeğini budamaz.
abstract final class AutoBackupFiles {
  /// Arayüz diline göre önekler. Dil değişse de eski dosyalar tanınır.
  static const prefixes = {'keykey-otomatik', 'keykey-auto'};

  /// Bu kadar günün en yeni dosyası kalır.
  static const keepDays = 14;

  /// Günü ne olursa olsun en yeni bu kadar dosya kalır: aynı gün içinde
  /// yanlışlıkla yapılan bir düzenlemeden önceki hal hemen budanmasın.
  static const keepRecent = 5;

  static const extension = '.keykey';

  /// Yazılırken kullanılan ara dosyanın eki; Kotlin'deki `PART_SUFFIX` ile
  /// aynı olmalı. Dosya doğrulanınca son ada çevrilir. Süreç yazarken ölürse
  /// yarım dosya bu adla kalır, kalıba uymadığı için yedek sayılmaz ve bir
  /// sonraki budamada silinir.
  static const partSuffix = '.part';

  static String partName(String name) => '$name$partSuffix';

  static final _pattern = RegExp(
    r'^(keykey-otomatik|keykey-auto)-(\d{4})-(\d{2})-(\d{2})-'
    r'(\d{2})(\d{2})(\d{2})-([0-9a-f]{6})\.keykey$',
  );

  static final _device = RegExp(r'^[0-9a-f]{6}$');

  /// Cihaz kimliği altı küçük onaltılık karakterdir.
  static bool isDevice(String value) => _device.hasMatch(value);

  /// Yerel saatle ad; [device] [isDevice]'a uymalı.
  static String nameFor(
    DateTime time, {
    required String prefix,
    required String device,
  }) {
    assert(isDevice(device), 'geçersiz cihaz kimliği: $device');
    String two(int value) => value.toString().padLeft(2, '0');
    final t = time.toLocal();
    return '$prefix-${t.year}-${two(t.month)}-${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}-$device$extension';
  }

  /// Adı kalıba tam uyan dosyanın zamanı (yerel) ve cihazı; uymuyorsa
  /// `null`.
  static ({DateTime time, String device})? parse(String name) {
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
    return valid ? (time: time, device: match.group(8)!) : null;
  }

  /// Silinecek dosyalar. Yalnızca [device]'ın dosyaları sayılır: en yeni
  /// [keepRecent] dosya ve en yeni [keepDays] günün her birinin en yenisi
  /// kalır, gerisi silinir. Bu cihazın yarım kalmış ara dosyaları da silinir;
  /// yazmalar sırayla yapıldığı için budama sırasında var olan ara dosya
  /// eskidir. Kalıba uymayan adlar ve başka cihazların dosyaları hiçbir zaman
  /// listeye girmez.
  static List<String> toDelete(
    Iterable<String> names, {
    required String device,
  }) {
    final parts = <String>[];
    final dated = <({String name, DateTime time})>[];
    for (final name in names) {
      final isPart = name.endsWith(partSuffix);
      final parsed = parse(
        isPart ? name.substring(0, name.length - partSuffix.length) : name,
      );
      if (parsed == null || parsed.device != device) continue;
      if (isPart) {
        parts.add(name);
      } else {
        dated.add((name: name, time: parsed.time));
      }
    }
    dated.sort((a, b) {
      final byTime = b.time.compareTo(a.time);
      return byTime != 0 ? byTime : b.name.compareTo(a.name);
    });
    final keptDays = <DateTime>{};
    final deleted = <String>[];
    for (final (index, file) in dated.indexed) {
      final day = DateTime(file.time.year, file.time.month, file.time.day);
      final newestOfDay = keptDays.length < keepDays && keptDays.add(day);
      if (index < keepRecent || newestOfDay) continue;
      deleted.add(file.name);
    }
    return [...deleted, ...parts];
  }
}

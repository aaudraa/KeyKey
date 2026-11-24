/// KeePass dosyası açılamadı. KDBX okuyucusu yalnızca bu türün alt türlerini
/// fırlatır; ekran her birine ayrı bir mesaj gösterir.
sealed class KdbxException implements Exception {
  const new();
}

/// Parola ya da anahtar dosyası yanlış (ya da dosya YubiKey veya Windows
/// hesabıyla korunuyor; dosya bunu ayırt ettirmez).
final class KdbxWrongKey extends KdbxException {
  const new();
}

/// Dosya, KeyKey'in okumadığı bir biçim ya da ayar kullanıyor.
final class KdbxUnsupported extends KdbxException {
  const new(this.what, {this.innerStream = false});

  /// Kullanıcıya gösterilebilecek, dile bağlı olmayan kısa ad: `KeePass 1`,
  /// `KDBX 5`, `Argon2 0x11` ya da bir UUID.
  final String what;

  /// [what] iç akış şifresinin kimliği; ekran "iç akış" sözünü kendi dilinde
  /// ekler.
  final bool innerStream;

  @override
  String toString() => 'KdbxUnsupported(${innerStream ? 'iç akış ' : ''}$what)';
}

/// Anahtar türetmesi ya da boyutu telefon için sınırların üstünde.
final class KdbxTooHeavy extends KdbxException {
  const new();
}

/// Argon2 için bellek ayrılamadı.
final class KdbxOutOfMemory extends KdbxException {
  const new();
}

/// Telefonun yerel kodu çalışamadı: kütüphane yüklenemedi, Java belleği
/// yetmedi ya da Argon2 iş parçacığı açamadı. Dosyayla ilgisi yoktur.
final class KdbxDeviceFailure extends KdbxException {
  const new();
}

/// Dosya bozuk ya da değiştirilmiş.
final class KdbxCorrupt extends KdbxException {
  const new();
}

/// Anahtar dosyası bozuk (XML 2.0 anahtar dosyasının özeti tutmuyor).
final class KdbxKeyFileCorrupt extends KdbxException {
  const new();
}

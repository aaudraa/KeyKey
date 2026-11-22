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
  const new(this.what);

  /// Kullanıcıya gösterilebilecek kısa ad, ör. `KeePass 1` ya da bir UUID.
  final String what;

  @override
  String toString() => 'KdbxUnsupported($what)';
}

/// Anahtar türetmesi ya da boyutu telefon için sınırların üstünde.
final class KdbxTooHeavy extends KdbxException {
  const new();
}

/// Argon2 için bellek ayrılamadı.
final class KdbxOutOfMemory extends KdbxException {
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

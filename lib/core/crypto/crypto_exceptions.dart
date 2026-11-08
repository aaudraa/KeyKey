/// Kripto katmanının hataları. Mesajlarda parola, anahtar veya düz metin
/// bulunmaz.
sealed class CryptoException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => 'CryptoException: $message';
}

/// Parola veya kurtarma anahtarı yanlış ya da üst bilgi değiştirilmiş.
/// Bu iki durum kriptografik olarak ayırt edilemez.
final class WrongSecretException extends CryptoException {
  const new() : super('Kasa bu bilgiyle açılamadı.');
}

/// Kurtarma anahtarı metni geçerli bir biçimde değil.
final class InvalidRecoveryKeyException extends CryptoException {
  const new(super.message);
}

/// Kasa üst bilgisi okunamadı veya desteklenmeyen bir sürümde.
final class InvalidVaultHeaderException extends CryptoException {
  const new(super.message);
}

/// Dosya bir KeyKey yedeği değil, desteklenmeyen bir sürümde veya yapısı
/// bozuk. Parola sorulmadan önce anlaşılır.
final class InvalidBackupException extends CryptoException {
  const new(super.message);
}

/// Kayıt bozulmuş, değiştirilmiş veya yanlış bağlamda açılmaya çalışılmış.
final class CorruptedDataException extends CryptoException {
  const new() : super('Şifreli veri doğrulanamadı.');
}

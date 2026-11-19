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
base class InvalidBackupException extends CryptoException {
  const new(super.message);
}

/// Yedek bu uygulamanın bilmediği, daha yeni bir dosya ya da içerik
/// sürümünde. Kullanıcıya uygulamayı güncellemesi söylenir.
final class NewerBackupException extends InvalidBackupException {
  const new(super.message);
}

/// Yazılacak yedek dosyası boyut sınırını aşıyor; dosya yazılmaz.
final class BackupTooLargeException implements Exception {
  const new();

  @override
  String toString() => 'BackupTooLargeException';
}

/// Kayıt bozulmuş, değiştirilmiş veya yanlış bağlamda açılmaya çalışılmış.
final class CorruptedDataException extends CryptoException {
  const new() : super('Şifreli veri doğrulanamadı.');
}

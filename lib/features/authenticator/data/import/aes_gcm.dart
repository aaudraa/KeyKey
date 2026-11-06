import 'dart:typed_data';

/// Şifreli dışa aktarma dosyalarını açan AES-256-GCM.
///
/// Uygulamada Android'in `javax.crypto` kitaplığı kullanılır. Testler bilinen
/// değerleri karşılaştıran sahte bir uygulama verir; gerçek AES-GCM cihaz
/// testinde aynı örnek dosyalarla sınanır.
abstract interface class AesGcmDecrypter {
  /// 128 bitlik etiket [cipherTextWithTag]'in sonundadır. Etiket
  /// doğrulanmazsa, yani anahtar yanlışsa veya veri değiştirildiyse, `null`.
  Future<Uint8List?> decrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List cipherTextWithTag,
  });
}

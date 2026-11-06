import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/platform/platform_api.g.dart';
import 'package:keykey/features/authenticator/data/import/aes_gcm.dart';
import 'package:keykey/features/authenticator/data/import/import_result.dart';

/// Android'in `javax.crypto` AES-GCM'i, Pigeon köprüsüyle.
final class PlatformAesGcm implements AesGcmDecrypter {
  new([ImportCryptoApi? api]) : _api = api ?? ImportCryptoApi();

  final ImportCryptoApi _api;

  @override
  Future<Uint8List?> decrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List cipherTextWithTag,
  }) async {
    try {
      final plain = await _api.aesGcmDecrypt(key, nonce, cipherTextWithTag);
      // Pigeon değiştirilemez bir görünüm verir; çağıran işi bitince düz metni
      // sıfırlayabilsin diye kopyalanır.
      return plain == null ? null : Uint8List.fromList(plain);
    } on PlatformException {
      // Örneğin geçersiz nonce: dosya bozuk.
      throw const InvalidImportException('Şifre çözülemedi.');
    }
  }
}

/// `main` doldurur, testler bilinen vektörlerle çalışan bir sahte verir.
final aesGcmProvider = Provider<AesGcmDecrypter>(
  (ref) => throw UnimplementedError('AES-GCM sağlanmadı.'),
);

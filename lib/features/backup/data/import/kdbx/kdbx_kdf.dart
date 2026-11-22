import 'dart:typed_data';

/// KDBX 4'ün desteklenen Argon2 türleri.
enum Argon2Type { d, id }

/// KeePass dosyasının anahtar türetmesi.
///
/// İki işlem de bilerek yavaştır; uygulamada telefonun yerel koduyla
/// çalışır (`PlatformKdbxKdf`): AES-KDF Android'in donanım hızlandırmalı
/// AES'iyle, Argon2 kendi başvuru uygulamasıyla. Kurallar KeePass içe
/// aktarma tasarımında.
abstract interface class KdbxKdf {
  /// KeePass AES-KDF: 32 baytlık [key], [seed] anahtarıyla AES-256-ECB'den
  /// [rounds] kez geçer; dönen 32 bayt sonucun SHA-256'sıdır.
  Future<Uint8List> aesKdf({
    required Uint8List key,
    required Uint8List seed,
    required int rounds,
  });

  /// 32 baytlık Argon2 çıktısı. Bellek ayrılamazsa `KdbxOutOfMemory`.
  Future<Uint8List> argon2({
    required Argon2Type type,
    required Uint8List password,
    required Uint8List salt,
    required int iterations,
    required int memoryKiB,
    required int parallelism,
    required int version,
    Uint8List? secret,
    Uint8List? associatedData,
  });
}

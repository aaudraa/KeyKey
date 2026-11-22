import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/platform/platform_api.g.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_exception.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_kdf.dart';

/// Telefonun yerel koduyla anahtar türetme, Pigeon köprüsüyle: AES-KDF
/// `javax.crypto` ile, Argon2 başvuru uygulamasıyla (C). İkisi de arka plan
/// iş parçacığında çalışır.
final class PlatformKdbxKdf implements KdbxKdf {
  new([ImportCryptoApi? api]) : _api = api ?? ImportCryptoApi();

  final ImportCryptoApi _api;

  @override
  Future<Uint8List> aesKdf({
    required Uint8List key,
    required Uint8List seed,
    required int rounds,
  }) => _call(() => _api.kdbxAesKdf(key, seed, rounds));

  @override
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
  }) => _call(
    () => _api.kdbxArgon2(
      type == Argon2Type.d ? 0 : 2,
      password,
      salt,
      iterations,
      memoryKiB,
      parallelism,
      version,
      secret,
      associatedData,
    ),
  );

  static Future<Uint8List> _call(Future<Uint8List> Function() call) async {
    try {
      // Pigeon değiştirilemez bir görünüm verir; çağıran sıfırlayabilsin
      // diye kopyalanır.
      return Uint8List.fromList(await call());
    } on PlatformException catch (error) {
      if (error.code == 'out-of-memory') throw const KdbxOutOfMemory();
      throw const KdbxCorrupt();
    }
  }
}

/// `main` doldurur; testler `pointycastle` ile çalışan bir uygulama verir.
final kdbxKdfProvider = Provider<KdbxKdf>(
  (ref) => throw UnimplementedError('KDBX anahtar türetmesi sağlanmadı.'),
);

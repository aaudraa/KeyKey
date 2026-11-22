import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_kdf.dart';
import 'package:pointycastle/export.dart';

/// Bilgisayardaki testler için `pointycastle` ile çalışan anahtar türetme.
/// Uygulamaya girmez; telefondaki uygulama aynı değerlerle cihaz testinde
/// sınanır.
final class DartKdbxKdf implements KdbxKdf {
  const new();

  @override
  Future<Uint8List> aesKdf({
    required Uint8List key,
    required Uint8List seed,
    required int rounds,
  }) async {
    final aes = AESEngine()..init(true, KeyParameter(seed));
    final block = Uint8List.fromList(key);
    for (var i = 0; i < rounds; i++) {
      aes
        ..processBlock(block, 0, block, 0)
        ..processBlock(block, 16, block, 16);
    }
    return Uint8List.fromList(sha256.convert(block).bytes);
  }

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
  }) async {
    final generator = Argon2BytesGenerator()
      ..init(
        Argon2Parameters(
          type == Argon2Type.d
              ? Argon2Parameters.ARGON2_d
              : Argon2Parameters.ARGON2_id,
          salt,
          desiredKeyLength: 32,
          iterations: iterations,
          memory: memoryKiB,
          lanes: parallelism,
          version: version,
          secret: secret,
          additional: associatedData,
        ),
      );
    final out = Uint8List(32);
    generator.deriveKey(password, 0, out, 0);
    return out;
  }
}

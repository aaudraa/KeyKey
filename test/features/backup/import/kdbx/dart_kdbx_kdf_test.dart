import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_kdf.dart';

import '../../../../support/dart_kdbx_kdf.dart';
import '../../../../support/hex.dart';

void main() {
  // RFC 9106 §5.1 ve §5.3.
  Future<String> rfc9106(Argon2Type type) async => toHex(
    await const DartKdbxKdf().argon2(
      type: type,
      password: Uint8List(32)..fillRange(0, 32, 1),
      salt: Uint8List(16)..fillRange(0, 16, 2),
      iterations: 3,
      memoryKiB: 32,
      parallelism: 4,
      version: 0x13,
      secret: Uint8List(8)..fillRange(0, 8, 3),
      associatedData: Uint8List(12)..fillRange(0, 12, 4),
    ),
  );

  test('Argon2d RFC 9106 vektörünü verir', () async {
    expect(
      await rfc9106(Argon2Type.d),
      '512b391b6f1162975371d30919734294f868e3be3984f3c1a13a4db9fabe4acb',
    );
  });

  test('Argon2id RFC 9106 vektörünü verir', () async {
    expect(
      await rfc9106(Argon2Type.id),
      '0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659',
    );
  });

  test('AES-KDF bilinen değeri verir', () async {
    // pycryptodome ile: AES-256-ECB(tohum) üç kez, sonra SHA-256.
    expect(
      toHex(
        await const DartKdbxKdf().aesKdf(
          key: Uint8List.fromList(List.generate(32, (i) => i)),
          seed: Uint8List.fromList(List.generate(32, (i) => 32 + i)),
          rounds: 3,
        ),
      ),
      '315ae03c84686e1d4973e71725947d22c0e4c8f08ade5b93678febadc1cebeac',
    );
  });
}

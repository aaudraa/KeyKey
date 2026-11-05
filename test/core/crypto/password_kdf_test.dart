import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/kdf_params.dart';
import 'package:keykey/core/crypto/password_kdf.dart';
import 'package:sodium/sodium_sumo.dart';

import 'hex.dart';
import 'vectors.dart';

void main() {
  late SodiumSumo sodium;
  late PasswordKdf kdf;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    kdf = PasswordKdf(sodium);
  });

  Uint8List bytesOf(SecureKey key) {
    addTearDown(key.dispose);
    return key.extractBytes();
  }

  KdfParams params({Uint8List? salt, int opsLimit = KdfParams.minOpsLimit}) =>
      KdfParams(
        opsLimit: opsLimit,
        memLimit: KdfParams.minMemLimit,
        salt: salt ?? Uint8List(KdfParams.saltLength),
      );

  group('bağımsız doğrulama', () {
    test('libsodium Argon2id test vektörleri', () {
      for (final vector in argon2idVectors) {
        final key = sodium.crypto.pwhash.callRaw(
          outLen: vector.outLen,
          password: vector.password,
          salt: vector.salt,
          opsLimit: vector.opsLimit,
          memLimit: vector.memLimit,
          alg: CryptoPwhashAlgorithm.argon2id13,
        );
        expect(bytesOf(key), vector.expected);
      }
    });

    // Node.js crypto.argon2Sync (OpenSSL) ile ayrı hesaplandı: Bizim taban
    // parametrelerimizin doğru aktarıldığını ve Türkçe karakterleri gösterir.
    test('taban parametreleri başka bir Argon2id ile aynı', () async {
      final key = await kdf.deriveKey(
        PasswordKdf.encodePassword('deneme-parolası'),
        params(salt: fromHex('000102030405060708090a0b0c0d0e0f')),
      );

      expect(
        bytesOf(key),
        fromHex(
          'b3a6b740df8714adb65ba71dd9654f3c'
          'ee90e8c9187a7b52b459574ef8eb7151',
        ),
      );
    });
  });

  group('deriveKey', () {
    test('aynı girdi aynı, farklı girdi farklı anahtar üretiyor', () async {
      final salt = sodium.randombytes.buf(KdfParams.saltLength);
      Future<Uint8List> derive(
        String password,
        Uint8List salt,
        int ops,
      ) async => bytesOf(
        await kdf.deriveKey(
          PasswordKdf.encodePassword(password),
          params(salt: salt, opsLimit: ops),
        ),
      );

      final base = await derive('parola', salt, 3);

      expect(await derive('parola', salt, 3), base);
      expect(await derive('parolA', salt, 3), isNot(base));
      expect(
        await derive('parola', sodium.randombytes.buf(16), 3),
        isNot(base),
      );
      expect(await derive('parola', salt, 4), isNot(base));
    });

    test('anahtar 32 bayt', () async {
      final key = await kdf.deriveKey(
        PasswordKdf.encodePassword('parola'),
        params(),
      );
      expect(bytesOf(key), hasLength(32));
    });
  });

  test('parola UTF-8 olarak kodlanıyor', () {
    expect(
      PasswordKdf.encodePassword('ış').buffer.asUint8List(),
      utf8.encode('ış'),
    );
  });

  group('KdfParams sınırları', () {
    final salt = Uint8List(KdfParams.saltLength);

    KdfParams build({
      int opsLimit = KdfParams.minOpsLimit,
      int memLimit = KdfParams.minMemLimit,
      Uint8List? customSalt,
    }) => KdfParams(
      opsLimit: opsLimit,
      memLimit: memLimit,
      salt: customSalt ?? salt,
    );

    test('taban ve tavan kabul ediliyor', () {
      expect(build, returnsNormally);
      expect(
        () => build(
          opsLimit: KdfParams.maxOpsLimit,
          memLimit: KdfParams.maxMemLimit,
        ),
        returnsNormally,
      );
    });

    test('sınır dışı değerler reddediliyor', () {
      final invalid = <void Function()>[
        () => build(opsLimit: KdfParams.minOpsLimit - 1),
        () => build(opsLimit: KdfParams.maxOpsLimit + 1),
        () => build(memLimit: KdfParams.minMemLimit - 1),
        () => build(memLimit: KdfParams.maxMemLimit + 1),
        () => build(customSalt: Uint8List(15)),
        () => build(customSalt: Uint8List(17)),
      ];
      for (final call in invalid) {
        expect(call, throwsA(isA<InvalidVaultHeaderException>()));
      }
    });

    test('tuz dışarıdan değiştirilemiyor', () {
      final mutable = Uint8List(KdfParams.saltLength);
      final built = build(customSalt: mutable);
      mutable[0] = 1;
      expect(built.salt[0], 0);
    });
  });

  group('kalibrasyon', () {
    int ops(int milliseconds) => PasswordKdf.opsLimitForMeasurement(
      Duration(milliseconds: milliseconds),
    );

    test('yavaş cihazda taban korunuyor', () {
      expect(ops(1000), KdfParams.minOpsLimit);
      expect(ops(5000), KdfParams.minOpsLimit);
    });

    test('hızlı cihazda geçiş sayısı artıyor', () {
      expect(ops(500), 6);
      expect(ops(250), 12);
    });

    test('tavan aşılmıyor', () {
      expect(ops(1), PasswordKdf.maxCalibratedOpsLimit);
    });

    test('geçersiz ölçümde tabana düşüyor', () {
      expect(
        PasswordKdf.opsLimitForMeasurement(Duration.zero),
        KdfParams.minOpsLimit,
      );
    });

    test('gerçek ölçüm geçerli aralıkta sonuç veriyor', () async {
      final result = await kdf.calibrateOpsLimit();
      expect(
        result,
        inInclusiveRange(
          KdfParams.minOpsLimit,
          PasswordKdf.maxCalibratedOpsLimit,
        ),
      );
    });
  });
}

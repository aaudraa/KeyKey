import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/kdf_params.dart';
import 'package:keykey/core/crypto/password_kdf.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/crypto/vault_crypto.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test/core/crypto/hex.dart';
import '../test/core/crypto/vectors.dart';
import 'vault_v1_fixture.dart';

// Kripto katmanını gerçek Android ortamında (ARM veya x86) doğrular.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SodiumSumo sodium;
  late VaultCrypto crypto;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    crypto = VaultCrypto(sodium);
  });

  test('libsodium test vektörleri', () {
    for (final vector in argon2idVectors) {
      final key = sodium.crypto.pwhash.callRaw(
        outLen: vector.outLen,
        password: vector.password,
        salt: vector.salt,
        opsLimit: vector.opsLimit,
        memLimit: vector.memLimit,
        alg: CryptoPwhashAlgorithm.argon2id13,
      );
      addTearDown(key.dispose);
      expect(key.extractBytes(), vector.expected);
    }

    final key = sodium.secureCopy(fromHex(xchachaKeyHex));
    addTearDown(key.dispose);
    expect(
      sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
        message: Uint8List.fromList(utf8.encode(xchachaMessage)),
        nonce: fromHex(xchachaNonceHex),
        key: key,
        additionalData: fromHex(xchachaAdHex),
      ),
      fromHex(xchachaCipherTextHex),
    );
  });

  test('başka cihazda üretilmiş v1 kasası açılıyor', () async {
    final header = VaultHeader.fromJsonString(fixtureHeaderJson);
    final expected = base64.decode(fixtureVaultKey);

    final byPassword = await crypto.unlockWithPassword(header, fixturePassword);
    addTearDown(byPassword.dispose);
    expect(byPassword.extractBytes(), expected);

    final byRecovery = crypto.unlockWithRecoveryKey(header, fixtureRecoveryKey);
    addTearDown(byRecovery.dispose);
    expect(byRecovery.extractBytes(), expected);

    final cipher = RecordCipher(sodium, byPassword, header.vaultId);
    addTearDown(cipher.dispose);
    expect(
      utf8.decode(
        cipher.decrypt(
          recordId: base64.decode(fixtureRecordId),
          type: fixtureRecordType,
          blob: base64.decode(fixtureRecordBlob),
        ),
      ),
      fixtureRecordPlainText,
    );
  });

  test('kasa uçtan uca çalışıyor', () async {
    const password = 'cihaz-parolası-ığüşöç';
    final vault = await crypto.createVault(password);
    addTearDown(vault.vaultKey.dispose);

    final restored = VaultHeader.fromJsonString(vault.header.toJsonString());
    await expectLater(
      crypto.unlockWithPassword(restored, 'yanlış'),
      throwsA(isA<WrongSecretException>()),
    );

    final key = await crypto.unlockWithPassword(restored, password);
    addTearDown(key.dispose);
    final cipher = RecordCipher(sodium, key, restored.vaultId);
    addTearDown(cipher.dispose);

    final recordId = sodium.randombytes.buf(RecordCipher.recordIdLength);
    final plain = Uint8List.fromList(utf8.encode('{"parola":"gizli"}'));
    final blob = cipher.encrypt(
      recordId: recordId,
      type: 'login',
      plainText: plain,
    );
    expect(
      cipher.decrypt(recordId: recordId, type: 'login', blob: blob),
      plain,
    );
    expect(
      () => cipher.decrypt(
        recordId: sodium.randombytes.buf(RecordCipher.recordIdLength),
        type: 'login',
        blob: blob,
      ),
      throwsA(isA<CorruptedDataException>()),
    );
  });

  test('Argon2id süre ölçümü', () async {
    final kdf = PasswordKdf(sodium);
    final samples = <int>[];
    for (var i = 0; i < 3; i++) {
      final stopwatch = Stopwatch()..start();
      final key = await kdf.deriveKey(
        PasswordKdf.encodePassword('ölçüm-parolası'),
        kdf.newParams(),
      );
      stopwatch.stop();
      key.dispose();
      samples.add(stopwatch.elapsedMilliseconds);
    }
    final opsLimit = await kdf.calibrateOpsLimit();

    // Bu satır ölçüm betiği tarafından okunuyor.
    // ignore: avoid_print
    print('KKOLCUM ms=${samples.join(",")} kalibrasyon_ops=$opsLimit');
    expect(
      opsLimit,
      inInclusiveRange(
        KdfParams.minOpsLimit,
        PasswordKdf.maxCalibratedOpsLimit,
      ),
    );
  });
}

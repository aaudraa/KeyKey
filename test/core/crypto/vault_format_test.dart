import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/kdf_params.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/crypto/vault_crypto.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  late SodiumSumo sodium;
  late VaultCrypto crypto;
  late Map<String, dynamic> fixture;
  late String headerJson;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    crypto = VaultCrypto(sodium);
    final file = File('test/fixtures/crypto/vault-v1.json');
    fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    headerJson = jsonEncode(fixture['header']);
  });

  Map<String, dynamic> editableHeader() =>
      jsonDecode(headerJson) as Map<String, dynamic>;

  Map<String, dynamic> part(Map<String, dynamic> map, String key) =>
      map[key] as Map<String, dynamic>;

  void expectInvalid(Object? value) => expect(
    () =>
        VaultHeader.fromJsonString(value is String ? value : jsonEncode(value)),
    throwsA(isA<InvalidVaultHeaderException>()),
  );

  group('biçim uyumluluğu (v1)', () {
    // Bu dosya bir kez üretildi ve değiştirilmemeli. Bu testler kırılırsa
    // eski kasalar açılamıyor demektir: Biçim sürümü artırılmalı ve göç
    // yazılmalıdır.
    late VaultHeader header;
    late Uint8List expectedKey;

    setUpAll(() {
      header = VaultHeader.fromJsonString(headerJson);
      expectedKey = base64.decode(fixture['vaultKey'] as String);
    });

    test('dosya sabit parametrelerle yazılmış', () {
      expect(header.kdf.opsLimit, 3);
      expect(header.kdf.memLimit, 67108864);
    });

    test('kaydedilen parola kasayı açıyor', () async {
      final key = await crypto.unlockWithPassword(
        header,
        fixture['password'] as String,
      );
      addTearDown(key.dispose);

      expect(key.extractBytes(), expectedKey);
    });

    test('kaydedilen kurtarma anahtarı kasayı açıyor', () {
      final key = crypto.unlockWithRecoveryKey(
        header,
        fixture['recoveryKey'] as String,
      );
      addTearDown(key.dispose);

      expect(key.extractBytes(), expectedKey);
    });

    test('kaydedilen kayıtlar açılıyor', () {
      final vaultKey = sodium.secureCopy(expectedKey);
      addTearDown(vaultKey.dispose);
      final cipher = RecordCipher(sodium, vaultKey, header.vaultId);
      addTearDown(cipher.dispose);

      final records = fixture['records'] as List<dynamic>;
      expect(records, hasLength(2));
      for (final record in records.cast<Map<String, dynamic>>()) {
        final plain = cipher.decrypt(
          recordId: base64.decode(fixture['recordId'] as String),
          type: record['type'] as String,
          blob: base64.decode(record['blob'] as String),
        );
        expect(utf8.decode(plain), record['plainText']);
      }
    });

    test('yazılan üst bilgi aynı metni üretiyor', () {
      expect(header.toJsonString(), headerJson);
    });
  });

  test('yeni kasa yazılıp okunduktan sonra açılıyor', () async {
    const password = 'ığüşöç-parola';
    final vault = await crypto.createVault(password);
    addTearDown(vault.vaultKey.dispose);

    final restored = VaultHeader.fromJsonString(vault.header.toJsonString());
    final key = await crypto.unlockWithPassword(restored, password);
    addTearDown(key.dispose);

    expect(key.extractBytes(), vault.vaultKey.extractBytes());
  });

  group('JSON içinde değiştirilen parametre kasayı açmıyor', () {
    Future<void> expectRejected(void Function(Map<String, dynamic>) edit) {
      final map = editableHeader();
      edit(part(map, 'kdf'));
      return expectLater(
        crypto.unlockWithPassword(
          VaultHeader.fromJsonString(jsonEncode(map)),
          fixture['password'] as String,
        ),
        throwsA(isA<WrongSecretException>()),
      );
    }

    test('geçiş sayısı', () => expectRejected((kdf) => kdf['opsLimit'] = 4));

    test(
      'bellek',
      () => expectRejected((kdf) => kdf['memLimit'] = 128 * 1024 * 1024),
    );

    test('tuz', () {
      return expectRejected((kdf) {
        final salt = base64.decode(kdf['salt'] as String)..[0] ^= 1;
        kdf['salt'] = base64.encode(salt);
      });
    });
  });

  group('geçersiz üst bilgi temiz hata veriyor', () {
    test('JSON değil', () {
      expectInvalid('');
      expectInvalid('{');
      expectInvalid('[]');
      expectInvalid('null');
      expectInvalid('"metin"');
    });

    test('desteklenmeyen sürüm', () {
      for (final version in [0, 2, '1', 1.5, null]) {
        expectInvalid(editableHeader()..['version'] = version);
      }
    });

    test('desteklenmeyen algoritma', () {
      for (final algorithm in ['argon2i13', 'scrypt', '', null]) {
        final map = editableHeader();
        part(map, 'kdf')['algorithm'] = algorithm;
        expectInvalid(map);
      }
    });

    test('eksik alanlar', () {
      for (final key in ['version', 'vaultId', 'kdf', 'slots']) {
        expectInvalid(editableHeader()..remove(key));
      }
      for (final key in ['algorithm', 'opsLimit', 'memLimit', 'salt']) {
        final map = editableHeader();
        part(map, 'kdf').remove(key);
        expectInvalid(map);
      }
      for (final key in ['password', 'recovery']) {
        final map = editableHeader();
        part(map, 'slots').remove(key);
        expectInvalid(map);
      }
      final map = editableHeader();
      part(part(map, 'slots'), 'password').remove('nonce');
      expectInvalid(map);
    });

    test('fazla alanlar', () {
      expectInvalid(editableHeader()..['ek'] = 1);
      final kdf = editableHeader();
      part(kdf, 'kdf')['ek'] = 1;
      expectInvalid(kdf);
      final slots = editableHeader();
      part(slots, 'slots')['biometric'] = <String, String>{};
      expectInvalid(slots);
      final slot = editableHeader();
      part(part(slot, 'slots'), 'recovery')['ek'] = 1;
      expectInvalid(slot);
    });

    test('Argon2id sınırları dışında değerler', () {
      for (final (key, value) in [
        ('opsLimit', KdfParams.minOpsLimit - 1),
        ('opsLimit', KdfParams.maxOpsLimit + 1),
        ('memLimit', KdfParams.minMemLimit - 1),
        ('memLimit', KdfParams.maxMemLimit + 1),
        ('opsLimit', '3'),
        ('memLimit', 67108864.5),
      ]) {
        final map = editableHeader();
        part(map, 'kdf')[key] = value;
        expectInvalid(map);
      }
    });

    test('yanlış uzunlukta ikili alanlar', () {
      String bytes(int length) => base64.encode(Uint8List(length));

      expectInvalid(editableHeader()..['vaultId'] = bytes(15));
      final salt = editableHeader();
      part(salt, 'kdf')['salt'] = bytes(17);
      expectInvalid(salt);
      final nonce = editableHeader();
      part(part(nonce, 'slots'), 'password')['nonce'] = bytes(23);
      expectInvalid(nonce);
      final cipherText = editableHeader();
      part(part(cipherText, 'slots'), 'recovery')['cipherText'] = bytes(47);
      expectInvalid(cipherText);
    });

    test('geçersiz veya kanonik olmayan Base64', () {
      final id = editableHeader()['vaultId'] as String;

      for (final value in [
        '%%%%',
        id.replaceAll('=', ''),
        id.replaceAll('+', '-').replaceAll('/', '_').padRight(25, 'A'),
        5,
        null,
      ]) {
        expectInvalid(editableHeader()..['vaultId'] = value);
      }
      final urlSafe = base64Url.encode(List.filled(16, 0xFB));
      expectInvalid(editableHeader()..['vaultId'] = urlSafe);
    });
  });
}

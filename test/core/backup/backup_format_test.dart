import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/crypto/vault_crypto.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:sodium/sodium_sumo.dart';

/// Sabit yedek dosyasının her sürümde açıldığını denetler.
///
/// Dosya bir kez üretildi ve değiştirilmemeli. Bu testler kırılırsa eski
/// yedekler açılamıyor demektir: biçim sürümü artırılmalı ve eski sürümü
/// okuyan kod korunmalıdır.
///
/// Yeniden üretmek gerekirse (yalnızca biçim sürümü değişince):
/// `KEYKEY_YEDEK_URET=1 flutter test test/core/backup/backup_format_test.dart`
void main() {
  const fixtureDir = 'test/fixtures/backup';
  const backupPath = '$fixtureDir/backup-v1.keykey';
  const metaPath = '$fixtureDir/backup-v1.json';

  late SodiumSumo sodium;
  late BackupCodec codec;
  late VaultCrypto crypto;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    codec = BackupCodec(sodium);
    crypto = VaultCrypto(sodium);
  });

  test(
    'örnek yedeği üret',
    () async {
      final vault = jsonDecode(
        File('test/fixtures/crypto/vault-v1.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final header = VaultHeader.fromJsonString(jsonEncode(vault['header']));
      final vaultKey = sodium.secureCopy(
        base64.decode(vault['vaultKey'] as String),
      );
      final cipher = RecordCipher(sodium, vaultKey, header.vaultId);
      final plain = [
        (
          id: '000102030405060708090a0b0c0d0e0f',
          type: 'login',
          text: _compactJson('test/fixtures/vault/login-v2.json'),
        ),
        (
          id: '101112131415161718191a1b1c1d1e1f',
          type: 'otp',
          text: _compactJson('test/fixtures/vault/otp-v1.json'),
        ),
        (
          id: '00000000000000000000000000000000',
          type: 'settings',
          text: '{"version":2,"otpRequireAuth":false,"autofillCopyOtp":true}',
        ),
      ];
      final records = [
        for (final (i, p) in plain.indexed)
          StoredRecord(
            id: _hex(p.id),
            type: p.type,
            blob: cipher.encrypt(
              recordId: _hex(p.id),
              type: p.type,
              plainText: Uint8List.fromList(utf8.encode(p.text)),
            ),
            createdAt: DateTime.utc(2026, 11, 1, i),
            updatedAt: DateTime.utc(2026, 11, 2, i),
          ),
      ];
      final bytes = await codec.encode(
        header: header,
        vaultKey: vaultKey,
        records: records,
        createdAt: DateTime.utc(2026, 11, 7, 12),
      );
      cipher.dispose();
      vaultKey.dispose();
      Directory(fixtureDir).createSync(recursive: true);
      File(backupPath).writeAsBytesSync(bytes);
      final meta = {
        'note':
            'Yalnızca deneme verisi. Biçim uyumluluğu testi için üretildi, '
            'değiştirilmemeli.',
        'password': vault['password'],
        'recoveryKey': vault['recoveryKey'],
        'createdAt': DateTime.utc(2026, 11, 7, 12).millisecondsSinceEpoch,
        'records': [
          for (final (i, p) in plain.indexed)
            {
              'id': p.id,
              'type': p.type,
              'createdAt': records[i].createdAt.millisecondsSinceEpoch,
              'updatedAt': records[i].updatedAt.millisecondsSinceEpoch,
              'plainText': p.text,
            },
        ],
      };
      File(metaPath).writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(meta)}\n',
      );
    },
    skip: Platform.environment['KEYKEY_YEDEK_URET'] == '1'
        ? false
        : 'Yalnızca KEYKEY_YEDEK_URET=1 ile çalışır.',
  );

  group('biçim uyumluluğu (v1)', () {
    late Uint8List bytes;
    late Map<String, dynamic> meta;
    late BackupFile file;

    setUpAll(() {
      bytes = File(backupPath).readAsBytesSync();
      meta =
          jsonDecode(File(metaPath).readAsStringSync()) as Map<String, dynamic>;
      file = codec.parse(bytes);
    });

    Future<void> expectContents(SecureKey vaultKey) async {
      final contents = await codec.open(file, vaultKey);
      expect(contents.createdAt.millisecondsSinceEpoch, meta['createdAt']);
      final expected = meta['records'] as List<dynamic>;
      expect(contents.records, hasLength(expected.length));
      final cipher = RecordCipher(sodium, vaultKey, file.header.vaultId);
      try {
        for (final (i, e) in expected.cast<Map<String, dynamic>>().indexed) {
          final record = contents.records[i];
          expect(_toHex(record.id), e['id']);
          expect(record.type, e['type']);
          expect(record.createdAt.millisecondsSinceEpoch, e['createdAt']);
          expect(record.updatedAt.millisecondsSinceEpoch, e['updatedAt']);
          final plain = cipher.decrypt(
            recordId: record.id,
            type: record.type,
            blob: record.blob,
          );
          expect(utf8.decode(plain), e['plainText']);
        }
      } finally {
        cipher.dispose();
      }
    }

    test('kaydedilen ana parolayla açılıyor', () async {
      final key = await crypto.unlockWithPassword(
        file.header,
        meta['password'] as String,
      );
      try {
        await expectContents(key);
      } finally {
        key.dispose();
      }
    });

    test('kaydedilen kurtarma anahtarıyla açılıyor', () async {
      final key = crypto.unlockWithRecoveryKey(
        file.header,
        meta['recoveryKey'] as String,
      );
      try {
        await expectContents(key);
      } finally {
        key.dispose();
      }
    });

    test('yanlış parola açmıyor', () async {
      await expectLater(
        crypto.unlockWithPassword(file.header, 'yanlis-parola-1234'),
        throwsA(isA<WrongSecretException>()),
      );
    });
  });
}

String _compactJson(String path) =>
    jsonEncode(jsonDecode(File(path).readAsStringSync()));

Uint8List _hex(String text) => Uint8List.fromList([
  for (var i = 0; i < text.length; i += 2)
    int.parse(text.substring(i, i + 2), radix: 16),
]);

String _toHex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

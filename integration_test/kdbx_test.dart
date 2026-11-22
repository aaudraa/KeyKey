import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_exception.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_header.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_kdf.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_key.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_payload.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_reader.dart';
import 'package:keykey/features/backup/data/import/kdbx/platform_kdbx_kdf.dart';
import 'package:keykey/features/backup/data/import/login_import.dart';

import 'kdbx_fixtures.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List _file(String path) => base64.decode(kdbxFixtureFiles[path]!);

const _aes100003 =
    'b9240b3c9f6bf854bfc96109bc60d593fdc874d438de6e98a19363726d438efa';

/// Telefondaki anahtar türetmeyi (Kotlin AES-KDF, C Argon2) sınar. Beklenen
/// değerler RFC 9106'dan ve pykeepass'tan; ikisi de KeyKey'den bağımsız.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final kdf = PlatformKdbxKdf();

  Future<String> rfc9106(Argon2Type type) async => _hex(
    await kdf.argon2(
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

  testWidgets('Argon2d ve Argon2id RFC 9106 vektörleri', (tester) async {
    expect(
      await rfc9106(Argon2Type.d),
      '512b391b6f1162975371d30919734294f868e3be3984f3c1a13a4db9fabe4acb',
    );
    expect(
      await rfc9106(Argon2Type.id),
      '0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659',
    );
  });

  testWidgets('AES-KDF çok turda da bilinen değer', (tester) async {
    // pycryptodome ile: AES-256-ECB(tohum) 100.003 kez, sonra SHA-256.
    // Tur sayısı parça boyunun katı değil; parça sınırları da sınanır.
    final result = await kdf.aesKdf(
      key: Uint8List.fromList(List.generate(32, (i) => i)),
      seed: Uint8List.fromList(List.generate(32, (i) => 32 + i)),
      rounds: 100003,
    );
    expect(_hex(result), _aes100003);
  });

  testWidgets('AES-KDF sıfır tur yalnızca SHA-256', (tester) async {
    final result = await kdf.aesKdf(
      key: Uint8List(32),
      seed: Uint8List(32),
      rounds: 0,
    );
    expect(
      _hex(result),
      '66687aadf862bd776c8fc18b8e9f8e20089714856ee233b3902a591d0d5f2925',
    );
  });

  testWidgets('AES-KDF bilinen değer', (tester) async {
    final result = await kdf.aesKdf(
      key: Uint8List.fromList(List.generate(32, (i) => i)),
      seed: Uint8List.fromList(List.generate(32, (i) => 32 + i)),
      rounds: 3,
    );
    expect(
      _hex(result),
      '315ae03c84686e1d4973e71725947d22c0e4c8f08ade5b93678febadc1cebeac',
    );
  });

  testWidgets('dönüştürülmüş anahtarlar pykeepass ile aynı', (tester) async {
    for (final MapEntry(key: path, value: c) in kdbxDeviceCases.entries) {
      if (c.transformed == null) continue;
      final header = KdbxHeader.parse(_file(path));
      final composite = compositeKey(
        password: c.password,
        keyFileKey: c.keyFile == null ? null : keyFileKey(_file(c.keyFile!)),
      );
      expect(
        _hex(await transformKey(header, composite, kdf)),
        c.transformed,
        reason: path,
      );
    }
  });

  testWidgets('her dosya telefonda açılır', (tester) async {
    for (final MapEntry(key: path, value: c) in kdbxDeviceCases.entries) {
      final export = await KdbxReader.open(
        _file(path),
        kdf: kdf,
        password: c.password == '' ? null : c.password,
        keyFileKey: c.keyFile == null ? null : keyFileKey(_file(c.keyFile!)),
      );
      expect(export.source, LoginExportSource.keepassKdbx, reason: path);
    }
  });

  testWidgets('yanlış parola', (tester) async {
    await expectLater(
      KdbxReader.open(
        _file('keepassxc/Format400.kdbx'),
        kdf: kdf,
        password: 'yanlış',
      ),
      throwsA(isA<KdbxWrongKey>()),
    );
  });

  testWidgets('KeePassXC varsayılanına yakın Argon2d süresi', (tester) async {
    // KeePassXC 2.7 varsayılanı: Argon2d, 64 MiB, 2 şerit; geçiş sayısı
    // bilgisayarda 1 saniyeye göre ayarlanıyor. 10 geçiş ölçülür.
    final watch = Stopwatch()..start();
    await kdf.argon2(
      type: Argon2Type.d,
      password: Uint8List(32),
      salt: Uint8List(32),
      iterations: 10,
      memoryKiB: 64 * 1024,
      parallelism: 2,
      version: 0x13,
    );
    // Süre ölçüm sonucu olarak test günlüğüne yazılır.
    // ignore: avoid_print
    print('Argon2d 64 MiB, 10 geçiş, 2 şerit: ${watch.elapsedMilliseconds} ms');
    watch
      ..reset()
      ..start();
    await kdf.aesKdf(key: Uint8List(32), seed: Uint8List(32), rounds: 10000000);
    // Süre ölçüm sonucu olarak test günlüğüne yazılır.
    // ignore: avoid_print
    print('AES-KDF 10.000.000 tur: ${watch.elapsedMilliseconds} ms');
    // KeePass'ın "1 saniye" ayarı on milyonlarca tur verebiliyor.
    expect(watch.elapsedMilliseconds, lessThan(5000));
  });
}

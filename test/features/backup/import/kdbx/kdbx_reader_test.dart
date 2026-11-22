import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_exception.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_kdf.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_key.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_reader.dart';
import 'package:keykey/features/backup/data/import/login_import.dart';

import '../../../../support/dart_kdbx_kdf.dart';
import '../../../../support/kdbx_fixtures.dart';

Future<LoginExport> _open(
  String path, {
  String? password,
  String? keyFile,
  KdbxKdf kdf = const DartKdbxKdf(),
  Uint8List? file,
}) => KdbxReader.open(
  file ?? kdbxFixture(path),
  password: password,
  keyFileKey: keyFile == null ? null : keyFileKey(kdbxFixture(keyFile)),
  kdf: kdf,
);

/// Gerçek anahtar türetmeyi bir kez yapıp sonucunu hatırlar; parametreler
/// değişince (bozulmuş başlık) hızlıca rastgele bir anahtar verir. Bozulma
/// testinde her bayt için Argon2'yi yeniden çalıştırmamak için.
final class _RecordingKdf implements KdbxKdf {
  final _known = <String, Uint8List>{};
  bool recording = true;

  String _id(List<Object?> parts) =>
      sha256.convert(parts.join('|').codeUnits).toString();

  Future<Uint8List> _lookup(
    String id,
    Future<Uint8List> Function() real,
  ) async {
    if (recording) return _known[id] = await real();
    return _known[id] ?? Uint8List.fromList(sha256.convert(id.codeUnits).bytes);
  }

  @override
  Future<Uint8List> aesKdf({
    required Uint8List key,
    required Uint8List seed,
    required int rounds,
  }) => _lookup(
    _id(['aes', key, seed, rounds]),
    () => const DartKdbxKdf().aesKdf(key: key, seed: seed, rounds: rounds),
  );

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
  }) => _lookup(
    _id([
      type,
      password,
      salt,
      iterations,
      memoryKiB,
      parallelism,
      version,
      secret,
      associatedData,
    ]),
    () => const DartKdbxKdf().argon2(
      type: type,
      password: password,
      salt: salt,
      iterations: iterations,
      memoryKiB: memoryKiB,
      parallelism: parallelism,
      version: version,
      secret: secret,
      associatedData: associatedData,
    ),
  );
}

void main() {
  group('her desteklenen dosya açılır', () {
    for (final MapEntry(key: path, value: key) in kdbxFixtureKeys.entries) {
      test(path, () async {
        // Kutu boşsa parola `null` verilir; okuyucu boş parolayı kendisi dener.
        final password = key.password == '' ? null : key.password;
        final export = await _open(
          path,
          password: password,
          keyFile: key.keyFile,
        );
        expect(export.source, LoginExportSource.keepassKdbx);
        expect(
          export.logins.length + export.notes.length + export.skipped,
          greaterThanOrEqualTo(0),
        );
      });
    }
  });

  test(
    'test4_blankpass: kutu boş, anahtar dosyası var, ikinci deneme açar',
    () async {
      var attempts = 0;
      final kdf = _CountingKdf(() => attempts++);
      await _open(
        'pykeepass/test4_blankpass.kdbx',
        keyFile: 'pykeepass/test4.key',
        kdf: kdf,
      );
      expect(attempts, 2);
    },
  );

  test('Compressed: kutu boş, anahtar dosyası yok, boş parola açar', () async {
    final export = await _open('keepassxc/Compressed.kdbx');
    expect(export.source, LoginExportSource.keepassKdbx);
  });

  test('yanlış parola', () {
    expect(
      _open('keepassxc/Format300.kdbx', password: 'b'),
      throwsA(isA<KdbxWrongKey>()),
    );
  });

  test('anahtar dosyası eksik', () {
    expect(
      _open('pykeepass/test4_hex.kdbx', password: 'password'),
      throwsA(isA<KdbxWrongKey>()),
    );
  });

  test('64 MiB üstü dosya ağır sayılır', () {
    final file = Uint8List(64 * 1024 * 1024 + 1)
      ..setAll(0, kdbxFixture('keepassxc/Format300.kdbx'));
    expect(_open('', password: 'a', file: file), throwsA(isA<KdbxTooHeavy>()));
  });

  test('KeePass 1 dosyası desteklenmez', () {
    final file = Uint8List.fromList([
      0x03,
      0xD9,
      0xA2,
      0x9A,
      0x65,
      0xFB,
      0x4B,
      0xB5,
      ...List.filled(200, 0),
    ]);
    expect(
      _open('', password: 'a', file: file),
      throwsA(isA<KdbxUnsupported>()),
    );
  });

  group('bozulma', () {
    const paths = [
      'keepassxc/Format200.kdbx',
      'keepassxc/ProtectedStrings.kdbx',
      'keepassxc/Format400.kdbx',
      'pykeepass/test4_aes_uncompressed.kdbx',
    ];
    for (final path in paths) {
      test('$path: her bayt bozulunca yalnızca KdbxException', () async {
        final key = kdbxFixtureKeys[path]!;
        final kdf = _RecordingKdf();
        await _open(path, password: key.password, kdf: kdf);
        kdf.recording = false;
        final original = kdbxFixture(path);
        for (var i = 0; i < original.length; i++) {
          final file = Uint8List.fromList(original)..[i] ^= 0xFF;
          try {
            await _open(path, password: key.password, kdf: kdf, file: file);
          } on KdbxException {
            // Beklenen.
          }
        }
      }, timeout: const Timeout(Duration(minutes: 5)));
    }

    test('imzalı rastgele dosyalar yalnızca KdbxException', () async {
      final random = Random(177);
      final kdf = _RecordingKdf()..recording = false;
      for (var i = 0; i < 200; i++) {
        final file = Uint8List(12 + random.nextInt(600));
        for (var j = 0; j < file.length; j++) {
          file[j] = random.nextInt(256);
        }
        file.setAll(0, [0x03, 0xD9, 0xA2, 0x9A, 0x67, 0xFB, 0x4B, 0xB5]);
        file[10] = 2 + random.nextInt(3);
        file[11] = 0;
        await expectLater(
          _open('', password: 'a', kdf: kdf, file: file),
          throwsA(isA<KdbxException>()),
        );
      }
    });
  });
}

final class _CountingKdf implements KdbxKdf {
  new(this._onCall);

  final void Function() _onCall;

  @override
  Future<Uint8List> aesKdf({
    required Uint8List key,
    required Uint8List seed,
    required int rounds,
  }) {
    _onCall();
    return const DartKdbxKdf().aesKdf(key: key, seed: seed, rounds: rounds);
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
  }) {
    _onCall();
    return const DartKdbxKdf().argon2(
      type: type,
      password: password,
      salt: salt,
      iterations: iterations,
      memoryKiB: memoryKiB,
      parallelism: parallelism,
      version: version,
      secret: secret,
      associatedData: associatedData,
    );
  }
}

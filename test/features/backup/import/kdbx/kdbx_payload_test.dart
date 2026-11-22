import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_exception.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_header.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_key.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_payload.dart';

import '../../../../support/dart_kdbx_kdf.dart';
import '../../../../support/hex.dart';
import '../../../../support/kdbx_fixtures.dart';

Future<Uint8List> _transformed(String path, {Uint8List? composite}) {
  final header = KdbxHeader.parse(kdbxFixture(path));
  return transformKey(
    header,
    composite ?? kdbxFixtureComposite(path),
    const DartKdbxKdf(),
  );
}

Future<KdbxPayload> _open(String path, {Uint8List? file}) async {
  final bytes = file ?? kdbxFixture(path);
  final header = KdbxHeader.parse(bytes);
  return decryptPayload(bytes, header, await _transformed(path));
}

void main() {
  group('dönüştürülmüş anahtar pykeepass ile aynı', () {
    final expected = {
      'keepassxc/NewDatabase.kdbx':
          'babcefd380208fa1e4d39b5e085047a9ad808bf27dc6c10c63ccf88f811b7581',
      'keepassxc/RecycleBinWithData.kdbx':
          '108beef7db5c8c48772e319ff848416715b5b4596922bfe4e36d0034915f3b89',
      'pykeepass/test4.kdbx':
          '06e36d85bdb14fb2c7471e4fe2e9791cd82994c77bf101d25486ebbc104e675b',
    };
    for (final MapEntry(key: path, value: key) in expected.entries) {
      test(path, () async => expect(toHex(await _transformed(path)), key));
    }
  });

  group("her dosya XML'e açılır", () {
    for (final path in kdbxFixtureKeys.keys) {
      test(path, () async {
        final payload = await _open(path);
        expect(
          utf8.decode(payload.xml.sublist(0, 200), allowMalformed: true),
          contains('<KeePassFile>'),
        );
        expect([0, 2, 3], contains(payload.innerStreamId));
      });
    }
  });

  test('KDBX 4 iç başlığındaki ekler sayılır', () async {
    // keykey_ornek.kdbx'te bir ek var.
    expect((await _open('keykey/keykey_ornek.kdbx')).binaryCount, 1);
    expect((await _open('pykeepass/test4_aes.kdbx')).binaryCount, 0);
  });

  test('wipe çözülmüş baytları sıfırlar', () async {
    final payload = await _open('keepassxc/Format400.kdbx');
    final xml = payload.xml;
    payload.wipe();
    expect(xml.every((b) => b == 0), isTrue);
  });

  group('yanlış anahtar', () {
    for (final path in kdbxFixtureKeys.keys) {
      test(path, () async {
        final file = kdbxFixture(path);
        final header = KdbxHeader.parse(file);
        final wrong = await transformKey(
          header,
          compositeKey(password: 'yanlış'),
          const DartKdbxKdf(),
        );
        expect(
          () => decryptPayload(file, header, wrong),
          throwsA(isA<KdbxWrongKey>()),
        );
      });
    }
  });

  group('KDBX 4 bütünlüğü', () {
    const path = 'pykeepass/test4_aes.kdbx';

    test('başlık özeti tutmazsa bozuk', () async {
      final file = kdbxFixture(path);
      final end = KdbxHeader.parse(file).bytes.length;
      file[end] ^= 1;
      expect(() => _open(path, file: file), throwsA(isA<KdbxCorrupt>()));
    });

    test('şifreli veride bir bit değişince bozuk', () async {
      final file = kdbxFixture(path);
      file[file.length - 40] ^= 1;
      expect(() => _open(path, file: file), throwsA(isA<KdbxCorrupt>()));
    });

    test('son blok kesilirse bozuk', () async {
      final file = kdbxFixture(path);
      expect(
        () =>
            _open(path, file: Uint8List.sublistView(file, 0, file.length - 36)),
        throwsA(isA<KdbxCorrupt>()),
      );
    });
  });

  group('KDBX 3 blok akışı', () {
    Uint8List block(int index, List<int> data, {List<int>? hash}) =>
        (BytesBuilder()
              ..add(u32(index))
              ..add(
                hash ??
                    (data.isEmpty ? Uint8List(32) : sha256.convert(data).bytes),
              )
              ..add(u32(data.length))
              ..add(data))
            .toBytes();

    test('bloklar birleşir', () {
      final stream = BytesBuilder()
        ..add(block(0, [1, 2]))
        ..add(block(1, [3]))
        ..add(block(2, []));
      expect(readHashedBlocks(stream.toBytes()), [1, 2, 3]);
    });

    test('özet tutmazsa bozuk', () {
      final stream = BytesBuilder()
        ..add(block(0, [1, 2], hash: Uint8List(32)))
        ..add(block(1, []));
      expect(
        () => readHashedBlocks(stream.toBytes()),
        throwsA(isA<KdbxCorrupt>()),
      );
    });

    test('sıra numarası atlanırsa bozuk', () {
      final stream = BytesBuilder()
        ..add(block(1, [1]))
        ..add(block(2, []));
      expect(
        () => readHashedBlocks(stream.toBytes()),
        throwsA(isA<KdbxCorrupt>()),
      );
    });

    test('son blok yoksa bozuk', () {
      expect(
        () => readHashedBlocks(block(0, [1])),
        throwsA(isA<KdbxCorrupt>()),
      );
    });
  });

  group('gzip', () {
    test('sınır içinde açılır', () {
      final data = List.filled(1000, 7);
      expect(kdbxGunzip(Uint8List.fromList(gzip.encode(data))), data);
    });

    test('sınırı aşan açılmış veri ağır sayılır', () {
      // 64 MiB'tan büyük sıfır, birkaç yüz kilobayta sıkışır.
      final bomb = gzip.encode(Uint8List(64 * 1024 * 1024 + 1));
      expect(
        () => kdbxGunzip(Uint8List.fromList(bomb)),
        throwsA(isA<KdbxTooHeavy>()),
      );
    });

    test('bozuk gzip bozuk sayılır', () {
      expect(
        () => kdbxGunzip(Uint8List.fromList([0x1f, 0x8b, 8, 0, 1, 2, 3])),
        throwsA(isA<KdbxCorrupt>()),
      );
    });
  });
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_exception.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_header.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_kdf.dart';

import '../../../../support/hex.dart';
import '../../../../support/kdbx_fixtures.dart';

const _aes = '31c1f2e6bf714350be5805216afc5aff';
const _aesKdf = 'c9d9f39a628a4460bf740d08c18a4fea';
const _argon2d = 'ef636ddf8c29444b91f7a9a403e30a0c';

Map<String, (int, List<int>)> _argon({
  int memory = 64 * 1024 * 1024,
  int iterations = 2,
  int parallelism = 2,
}) => {
  r'$UUID': (0x42, fromHex(_argon2d)),
  'S': (0x42, Uint8List(32)),
  'P': (0x04, u32(parallelism)),
  'M': (0x05, u64(memory)),
  'I': (0x05, u64(iterations)),
  'V': (0x04, u32(0x13)),
};

/// Geçerli bir KDBX 4 başlığı; [kdf] sözlüğü ve şifre değiştirilebilir.
Uint8List _v4({Map<String, (int, List<int>)>? kdf, List<int>? cipher}) {
  final builder = KdbxHeaderBuilder(4, minor: 0)
    ..field(2, cipher ?? fromHex(_aes))
    ..field(3, u32(1))
    ..field(4, Uint8List(32))
    ..field(7, Uint8List(16))
    ..field(11, variantDictionary(kdf ?? _argon()))
    ..field(0, [13, 10, 13, 10]);
  return builder.build();
}

/// Geçerli bir KDBX 3.1 başlığı; iç akış ve tur sayısı değiştirilebilir.
Uint8List _v3({int innerStream = 2, int rounds = 6000}) {
  final builder = KdbxHeaderBuilder(3)
    ..field(2, fromHex(_aes))
    ..field(3, u32(1))
    ..field(4, Uint8List(32))
    ..field(5, Uint8List(32))
    ..field(6, u64(rounds))
    ..field(7, Uint8List(16))
    ..field(8, Uint8List(32))
    ..field(9, Uint8List(32))
    ..field(10, u32(innerStream))
    ..field(0, [13, 10, 13, 10]);
  return builder.build();
}

void main() {
  group('gerçek dosyalar', () {
    final cases = <String, (int, int, KdbxCipher, Type)>{
      'pykeepass/test3.kdbx': (3, 1, KdbxCipher.aes256, AesKdfParams),
      'pykeepass/test4.kdbx': (4, 0, KdbxCipher.chaCha20, Argon2Params),
      'pykeepass/test4_twofish.kdbx': (4, 0, KdbxCipher.twofish, Argon2Params),
      'pykeepass/test4_aeskdf.kdbx': (4, 0, KdbxCipher.aes256, AesKdfParams),
      'keepassxc/FileKeyBinary.kdbx': (2, 4, KdbxCipher.aes256, AesKdfParams),
      'keepassxc/Format200.kdbx': (2, 0, KdbxCipher.aes256, AesKdfParams),
    };
    for (final MapEntry(key: path, value: (major, minor, cipher, kdf))
        in cases.entries) {
      test(path, () {
        final header = KdbxHeader.parse(kdbxFixture(path));
        expect(header.majorVersion, major);
        expect(header.minorVersion, minor);
        expect(header.cipher, cipher);
        expect(header.kdf.runtimeType, kdf);
      });
    }

    test('Argon2id ve parametreleri okunur', () {
      final header = KdbxHeader.parse(
        kdbxFixture('pykeepass/test4_argon2id.kdbx'),
      );
      final kdf = header.kdf as Argon2Params;
      expect(kdf.type, Argon2Type.id);
      expect(kdf.memoryKiB, greaterThan(0));
      expect(kdf.parallelism, greaterThan(0));
      expect(kdf.version, anyOf(0x10, 0x13));
    });

    test('başlık baytları başlık sonunda biter', () {
      final file = kdbxFixture('pykeepass/test3.kdbx');
      final header = KdbxHeader.parse(file);
      expect(header.bytes, file.sublist(0, header.bytes.length));
      expect(header.streamStartBytes, hasLength(32));
      expect(header.innerStreamId, 2);
    });
  });

  test('elle kurulan KDBX 4 başlığı okunur', () {
    final header = KdbxHeader.parse(_v4());
    final kdf = header.kdf as Argon2Params;
    expect(kdf.type, Argon2Type.d);
    expect(kdf.memoryKiB, 64 * 1024);
    expect(kdf.iterations, 2);
    expect(kdf.parallelism, 2);
    expect(header.compression, KdbxCompression.gzip);
  });

  test('isKdbx yalnızca imzaya bakar', () {
    expect(KdbxHeader.isKdbx(_v4()), isTrue);
    expect(
      KdbxHeader.isKdbx(Uint8List.fromList('name,url'.codeUnits)),
      isFalse,
    );
    expect(KdbxHeader.isKdbx(Uint8List(3)), isFalse);
  });

  test('KeePass 1 dosyası eski biçimdir', () {
    final kdb = (KdbxHeaderBuilder(
      3,
    )..field(0, [])).build(signature2: [0x65, 0xFB, 0x4B, 0xB5]);
    expect(KdbxHeader.isKdb(kdb), isTrue);
    expect(KdbxHeader.isKdbx(kdb), isFalse);
    expect(() => KdbxHeader.parse(kdb), throwsA(isA<KdbxUnsupported>()));
  });

  test('bilinmeyen ana sürüm desteklenmez', () {
    for (final major in [1, 5]) {
      final file = _v4();
      ByteData.sublistView(file).setUint16(10, major, Endian.little);
      expect(() => KdbxHeader.parse(file), throwsA(isA<KdbxUnsupported>()));
    }
  });

  test('bilinmeyen şifre desteklenmez', () {
    expect(
      () => KdbxHeader.parse(_v4(cipher: Uint8List(16))),
      throwsA(isA<KdbxUnsupported>()),
    );
  });

  test('ArcFour iç akışı desteklenmez', () {
    expect(
      () => KdbxHeader.parse(_v3(innerStream: 1)),
      throwsA(isA<KdbxUnsupported>()),
    );
  });

  group('ağır anahtar türetme', () {
    test('1 GiB üstü bellek', () {
      expect(
        () => KdbxHeader.parse(_v4(kdf: _argon(memory: 2 << 30))),
        throwsA(isA<KdbxTooHeavy>()),
      );
    });

    test('1000 üstü geçiş', () {
      expect(
        () => KdbxHeader.parse(_v4(kdf: _argon(iterations: 1001))),
        throwsA(isA<KdbxTooHeavy>()),
      );
    });

    test('64 üstü paralellik', () {
      expect(
        () => KdbxHeader.parse(_v4(kdf: _argon(parallelism: 65))),
        throwsA(isA<KdbxTooHeavy>()),
      );
    });

    test('1 GiB tam sınırda kabul edilir', () {
      expect(
        KdbxHeader.parse(_v4(kdf: _argon(memory: 1 << 30))).kdf,
        isA<Argon2Params>(),
      );
    });

    test('milyarı aşan AES-KDF turu', () {
      expect(
        () => KdbxHeader.parse(_v3(rounds: 1000000001)),
        throwsA(isA<KdbxTooHeavy>()),
      );
      expect(
        () => KdbxHeader.parse(
          _v4(
            kdf: {
              r'$UUID': (0x42, fromHex(_aesKdf)),
              'S': (0x42, Uint8List(32)),
              'R': (0x05, u64(1000000001)),
            },
          ),
        ),
        throwsA(isA<KdbxTooHeavy>()),
      );
    });

    test('1024 bayta bölünmeyen Argon2 belleği bozuktur', () {
      expect(
        () => KdbxHeader.parse(_v4(kdf: _argon(memory: 1000))),
        throwsA(isA<KdbxCorrupt>()),
      );
    });
  });

  test('1 MiB üstü alan uzunluğu bozuktur', () {
    final file = _v4();
    // İlk alanın (şifre) uzunluğu 2 MiB.
    ByteData.sublistView(file).setUint32(13, 2 << 20, Endian.little);
    expect(() => KdbxHeader.parse(file), throwsA(isA<KdbxCorrupt>()));
  });

  test('kesilmiş başlık yalnızca KdbxException fırlatır', () {
    for (final path in ['pykeepass/test3.kdbx', 'pykeepass/test4.kdbx']) {
      final file = kdbxFixture(path);
      final end = KdbxHeader.parse(file).bytes.length;
      for (var length = 0; length < end; length++) {
        expect(
          () => KdbxHeader.parse(Uint8List.sublistView(file, 0, length)),
          throwsA(isA<KdbxException>()),
          reason: '$path, $length bayt',
        );
      }
    }
  });
}

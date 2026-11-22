import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_exception.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_key.dart';

import '../../../../support/hex.dart';
import '../../../../support/kdbx_fixtures.dart';

/// Beklenen değerler pykeepass 4.2.0'ın `compute_key_composite` işleviyle.
String _composite({String? password, String? keyFile}) => toHex(
  compositeKey(
    password: password,
    keyFileKey: keyFile == null ? null : keyFileKey(kdbxFixture(keyFile)),
  ),
);

void main() {
  group('anahtar dosyası türleri', () {
    final cases = {
      'keepassxc/FileKeyBinary.key':
          'fe9f5fd9d5f6d37eecd342e21dcd7bf12fbe489018905d06e2085666069b867d',
      'keepassxc/FileKeyHex.key':
          '8cc498b5fc1381eb67906e51f9c8369b2a5fc166a598d9d775030c71d71ac328',
      'keepassxc/FileKeyHashed.key':
          '76386d84554ae6ec030d82c3f7aea311000e634c6a4a482a56330a3fb582501b',
      'keepassxc/FileKeyXml.key':
          'd47ae816f8d20164da957b896a346e753501c8c067f66cb3afe357c89d767434',
      'keepassxc/FileKeyXmlV2.keyx':
          'fe2949b83209abdbd99f049b6a0231282b5854214b0b58f5135148f905ad5a95',
    };
    for (final MapEntry(key: file, value: expected) in cases.entries) {
      test(file, () => expect(_composite(keyFile: file), expected));
    }
  });

  test('parola ve anahtar dosyası birlikte', () {
    expect(
      _composite(password: 'password', keyFile: 'pykeepass/test4_keyx.keyx'),
      '585b1523f7fbd36652fb22bf235ab03dcde9befdbc6476d4ed370ce50e592f53',
    );
    expect(
      _composite(password: 'password', keyFile: 'pykeepass/test4_hex.key'),
      'a6678ac483005fec38a574aeab4f95034376ec8183ee6ea794043a0b264cb029',
    );
    expect(
      _composite(password: 'password', keyFile: 'pykeepass/test3.key'),
      'e2a3f329430dc089d2a9ca4055b84c8b65ddca06afc192d0a79189ee6d647bc9',
    );
  });

  test('yalnızca parola', () {
    expect(
      _composite(password: 'a'),
      'bf5d3affb73efd2ec6c36ad3112dd933efed63c4e1cbffcfa88e2759c144f2d8',
    );
  });

  test('boş parola bir bileşendir, parola yokluğu değildir', () {
    expect(
      _composite(password: ''),
      '5df6e0e2761359d30a8275058e299fcc0381534545f55cf43e41983f5d4c9456',
    );
    expect(
      _composite(password: '', keyFile: 'pykeepass/test4.key'),
      'eef88f7a9ed13a34c9a6c36985ec216214c768ede37f0ff8311dfb6094eaf62b',
    );
    expect(
      _composite(keyFile: 'pykeepass/test4.key'),
      isNot(_composite(password: '', keyFile: 'pykeepass/test4.key')),
    );
  });

  test('ikisi de yoksa hata', () {
    expect(compositeKey, throwsArgumentError);
  });

  test('2.0 anahtar dosyasının özeti tutmazsa bozuk', () {
    expect(
      () => keyFileKey(kdbxFixture('keepassxc/FileKeyXmlV2HashFail.keyx')),
      throwsA(isA<KdbxKeyFileCorrupt>()),
    );
  });

  test('bilinmeyen XML anahtar dosyası sürümü bozuk', () {
    final file = utf8.encode(
      '<?xml version="1.0" encoding="utf-8"?><KeyFile><Meta> '
      '<Version>3.0</Version></Meta><Key><Data>AAAA</Data></Key></KeyFile>',
    );
    expect(
      () => keyFileKey(Uint8List.fromList(file)),
      throwsA(isA<KdbxKeyFileCorrupt>()),
    );
  });

  test('KeyFile olmayan XML dosyanın özetidir', () {
    final file = Uint8List.fromList(utf8.encode('<?xml version="1.0"?><a/>'));
    expect(keyFileKey(file), sha256.convert(file).bytes);
  });

  test('64 karakter ama onaltılık olmayan dosya özettir', () {
    final file = Uint8List.fromList(List.filled(64, 0x7A));
    expect(keyFileKey(file), sha256.convert(file).bytes);
  });

  test('16 MiB üstü anahtar dosyası bozuk', () {
    expect(
      () => keyFileKey(Uint8List(16 * 1024 * 1024 + 1)),
      throwsA(isA<KdbxCorrupt>()),
    );
  });
}

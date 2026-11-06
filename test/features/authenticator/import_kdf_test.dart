import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/authenticator/data/import/import_kdf.dart';

import '../../core/crypto/hex.dart';

Uint8List _hex(String spaced) => fromHex(spaced.replaceAll(RegExp(r'\s'), ''));

void main() {
  group('RFC 7914', () {
    test('Salsa20/8 çekirdeği (bölüm 8)', () {
      final input = _hex('''
        7e 87 9a 21 4f 3e c9 86 7c a9 40 e6 41 71 8f 26
        ba ee 55 5b 8c 61 c1 b5 0d f8 46 11 6d cd 3b 1d
        ee 24 f3 19 df 9b 3d 85 14 12 1e 4b 5a c5 aa 32
        76 02 1d 29 09 c7 48 29 ed eb c6 8d b8 b8 c2 5e''');
      final expected = _hex('''
        a4 1f 85 9c 66 08 cc 99 3b 81 ca cb 02 0c ef 05
        04 4b 21 81 a2 fd 33 7d fd 7b 1c 63 96 68 2f 29
        b4 39 31 68 e3 c9 e6 bc fe 6b c5 b7 a0 6d 96 ba
        e4 24 cc 10 2c 91 74 5c 24 ad 67 3d c7 61 8f 81''');
      final words = Uint32List.fromList(
        List.generate(
          16,
          (i) => ByteData.sublistView(input).getUint32(i * 4, Endian.little),
        ),
      );

      ImportKdf.salsa20_8(words);

      final out = Uint8List(64);
      for (var i = 0; i < 16; i++) {
        ByteData.sublistView(out).setUint32(i * 4, words[i], Endian.little);
      }
      expect(out, expected);
    });

    test('PBKDF2-HMAC-SHA256, c=1 (bölüm 11)', () {
      expect(
        ImportKdf.pbkdf2Sha256(
          password: ascii.encode('passwd'),
          salt: ascii.encode('salt'),
          iterations: 1,
          length: 64,
        ),
        _hex('''
          55 ac 04 6e 56 e3 08 9f ec 16 91 c2 25 44 b6 05
          f9 41 85 21 6d de 04 65 e6 8b 9d 57 c2 0d ac bc
          49 ca 9c cc f1 79 b6 45 99 16 64 b3 9d 77 ef 31
          7c 71 b8 45 b1 e3 0b d5 09 11 20 41 d3 a1 97 83'''),
      );
    });

    test('PBKDF2-HMAC-SHA256, c=80000 (bölüm 11)', () {
      expect(
        ImportKdf.pbkdf2Sha256(
          password: ascii.encode('Password'),
          salt: ascii.encode('NaCl'),
          iterations: 80000,
          length: 64,
        ),
        _hex('''
          4d dc d8 f6 0b 98 be 21 83 0c ee 5e f2 27 01 f9
          64 1a 44 18 d0 4c 04 14 ae ff 08 87 6b 34 ab 56
          a1 d4 25 a1 22 58 33 54 9a db 84 1b 51 c9 b3 17
          6a 27 2b de bb a1 d0 78 47 8f 62 b3 97 f3 3c 8d'''),
      );
    });

    test('scrypt, N=16 (bölüm 12)', () {
      expect(
        ImportKdf.scrypt(
          password: const [],
          salt: const [],
          n: 16,
          r: 1,
          p: 1,
          length: 64,
        ),
        _hex('''
          77 d6 57 62 38 65 7b 20 3b 19 ca 42 c1 8a 04 97
          f1 6b 48 44 e3 07 4a e8 df df fa 3f ed e2 14 42
          fc d0 06 9d ed 09 48 f8 32 6a 75 3a 0f c8 1f 17
          e8 d3 e0 fb 2e 0d 36 28 cf 35 e2 0c 38 d1 89 06'''),
      );
    });

    test('scrypt, N=1024, r=8, p=16 (bölüm 12)', () {
      expect(
        ImportKdf.scrypt(
          password: ascii.encode('password'),
          salt: ascii.encode('NaCl'),
          n: 1024,
          r: 8,
          p: 16,
          length: 64,
        ),
        _hex('''
          fd ba be 1c 9d 34 72 00 78 56 e7 19 0d 01 e9 fe
          7c 6a d7 cb c8 23 78 30 e7 73 76 63 4b 37 31 62
          2e af 30 d9 2e 22 a3 88 6f f1 09 27 9d 98 30 da
          c7 27 af b9 4a 83 ee 6d 83 60 cb df a2 cc 06 40'''),
      );
    });

    test('scrypt, N=16384, r=8, p=1 (bölüm 12)', () {
      expect(
        ImportKdf.scrypt(
          password: ascii.encode('pleaseletmein'),
          salt: ascii.encode('SodiumChloride'),
          n: 16384,
          r: 8,
          p: 1,
          length: 64,
        ),
        _hex('''
          70 23 bd cb 3a fd 73 48 46 1c 06 cd 81 fd 38 eb
          fd a8 fb ba 90 4f 8e 3e a9 b5 43 f6 54 5d a1 f2
          d5 43 29 55 61 3f 0f cf 62 d4 97 05 24 2a 9a f9
          e6 1e 85 dc 0d 65 1e 40 df cf 01 7b 45 57 58 87'''),
      );
    });
  });

  group('sınırlar', () {
    test('kötü niyetli parametreler reddediliyor', () {
      Uint8List run(int n, int r, int p) => ImportKdf.scrypt(
        password: const [1],
        salt: const [2],
        n: n,
        r: r,
        p: p,
        length: 32,
      );
      expect(() => run(1000, 8, 1), throwsArgumentError, reason: '2^k değil');
      expect(() => run(1, 8, 1), throwsArgumentError);
      expect(() => run(1 << 20, 8, 1), throwsArgumentError, reason: '1 GiB');
      expect(() => run(16, 0, 1), throwsArgumentError);
      expect(() => run(16, 1, 17), throwsArgumentError);
      expect(
        () => ImportKdf.pbkdf2Sha256(
          password: const [1],
          salt: const [2],
          iterations: 0,
          length: 32,
        ),
        throwsArgumentError,
      );
    });
  });
}

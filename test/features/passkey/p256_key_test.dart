import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/passkey/domain/p256_key.dart';
import 'package:keykey/features/vault/data/login_passkey.dart';

import '../../support/passkey_test_keys.dart';

void main() {
  final p256 = base64UrlDecodeNoPad(p256Pkcs8B64Url);

  group('isP256Pkcs8', () {
    test('P-256 PKCS#8 kabul ediliyor', () {
      expect(isP256Pkcs8(p256), isTrue);
    });

    test('P-384 reddediliyor', () {
      expect(isP256Pkcs8(base64.decode(p384Pkcs8B64)), isFalse);
    });

    test('içteki EC anahtarı denetleniyor', () {
      // Dış yapı doğru, içi [inner] olan PKCS#8.
      List<int> pkcs8(List<int> inner) {
        final body = [
          0x02, 0x01, 0x00, //
          ...p256.sublist(6, 27), // P-256 algoritması
          0x04, inner.length, ...inner,
        ];
        return [0x30, body.length, ...body];
      }

      List<int> ecKey(int version, List<int> d) {
        final body = [0x02, 0x01, version, 0x04, d.length, ...d];
        return [0x30, body.length, ...body];
      }

      final d = List.generate(32, (i) => i + 1);
      expect(isP256Pkcs8(pkcs8(ecKey(1, d))), isTrue);
      expect(isP256Pkcs8(pkcs8(const [1, 2, 3])), isFalse);
      expect(isP256Pkcs8(pkcs8(ecKey(2, d))), isFalse);
      expect(isP256Pkcs8(pkcs8(ecKey(1, d.sublist(1)))), isFalse);
      expect(isP256Pkcs8(pkcs8(ecKey(1, List.filled(32, 0)))), isFalse);
    });

    test('kesik ya da sonu fazla bayt reddediliyor', () {
      expect(isP256Pkcs8(p256.sublist(0, p256.length - 1)), isFalse);
      expect(isP256Pkcs8([...p256, 0]), isFalse);
      expect(isP256Pkcs8(const []), isFalse);
      expect(isP256Pkcs8(const [0x30, 0x81]), isFalse);
    });
  });

  group('p256Pkcs8FromPem', () {
    test('PEM gövdesi DER olarak çıkıyor', () {
      expect(p256Pkcs8FromPem(p256Pem), p256);
    });

    test('CRLF ve boşluklar sorun değil', () {
      expect(p256Pkcs8FromPem(p256Pem.replaceAll('\n', '\r\n  ')), p256);
    });

    test('başka etiket, bozuk base64 ya da başka eğri null', () {
      expect(
        p256Pkcs8FromPem(p256Pem.replaceAll('PRIVATE KEY', 'PUBLIC KEY')),
        isNull,
      );
      expect(
        p256Pkcs8FromPem(
          '-----BEGIN PRIVATE KEY-----\n!!!\n-----END PRIVATE KEY-----',
        ),
        isNull,
      );
      expect(
        p256Pkcs8FromPem(
          '-----BEGIN PRIVATE KEY-----\n$p384Pkcs8B64\n'
          '-----END PRIVATE KEY-----',
        ),
        isNull,
      );
      expect(p256Pkcs8FromPem(''), isNull);
    });
  });
}

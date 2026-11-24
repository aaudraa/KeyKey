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

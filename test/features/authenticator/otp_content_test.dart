import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';

void main() {
  final secret = Base32.decodeCanonical('JBSWY3DPEHPK3PXP');
  final loginId = Uint8List.fromList(List.generate(16, (i) => i));

  final full = OtpContent(
    parameters: OtpParameters.totp(
      secret: secret,
      algorithm: OtpAlgorithm.sha512,
      digits: 7,
      period: 45,
    ),
    issuer: 'Örnek Servis',
    account: 'kullanıcı@example.com',
    loginId: loginId,
    notes: 'Bir not',
    favorite: true,
    trashedAt: DateTime.utc(2026, 11, 6, 9),
  );

  Map<String, Object?> json(OtpContent content) =>
      jsonDecode(utf8.decode(content.toJsonBytes())) as Map<String, Object?>;

  Uint8List bytes(Map<String, Object?> map) =>
      Uint8List.fromList(utf8.encode(jsonEncode(map)));

  void expectSame(OtpContent actual, OtpContent expected) {
    expect(actual.parameters, expected.parameters);
    expect(actual.issuer, expected.issuer);
    expect(actual.account, expected.account);
    expect(actual.loginId, expected.loginId);
    expect(actual.notes, expected.notes);
    expect(actual.favorite, expected.favorite);
    expect(actual.trashedAt, expected.trashedAt);
  }

  group('biçim', () {
    test('yazılan aynen okunuyor', () {
      expectSame(OtpContent.fromJsonBytes(full.toJsonBytes()), full);
    });

    test('HOTP aynen okunuyor', () {
      final hotp = OtpContent(
        parameters: OtpParameters.hotp(secret: secret, counter: 12),
      );
      final read = OtpContent.fromJsonBytes(hotp.toJsonBytes());
      expectSame(read, hotp);
      expect(json(hotp)['period'], isNull);
      expect(json(hotp)['counter'], 12);
    });

    test('sabit örnek dosya açılıyor', () {
      // Bu dosya değişmez: eski kasalar her sürümde açılmalı.
      final fixture = File('test/fixtures/vault/otp-v1.json').readAsBytesSync();

      final content = OtpContent.fromJsonBytes(fixture);

      expect(
        content.parameters,
        OtpParameters.totp(
          secret: secret,
          algorithm: OtpAlgorithm.sha256,
          digits: 8,
          period: 60,
        ),
      );
      expect(content.issuer, 'Örnek');
      expect(content.account, 'kullanici@example.com');
      expect(content.loginId, loginId);
      expect(content.notes, 'Not');
      expect(content.favorite, isTrue);
      expect(content.trashedAt, isNull);
    });

    test('yazılan JSON belgedeki biçimde', () {
      final map = json(full);
      expect(map.keys.toSet(), {
        'version',
        'kind',
        'issuer',
        'account',
        'secret',
        'algorithm',
        'digits',
        'period',
        'counter',
        'loginId',
        'notes',
        'favorite',
        'trashedAt',
      });
      expect(map['version'], 1);
      expect(map['kind'], 'totp');
      expect(map['secret'], 'JBSWY3DPEHPK3PXP');
      expect(map['algorithm'], 'SHA512');
      expect(map['loginId'], '000102030405060708090a0b0c0d0e0f');
      expect(
        map['trashedAt'],
        DateTime.utc(2026, 11, 6, 9).millisecondsSinceEpoch,
      );
    });
  });

  group('katı okuma', () {
    late Map<String, Object?> valid;

    setUp(() => valid = json(full));

    void rejects(Map<String, Object?> map, String reason) {
      expect(
        () => OtpContent.fromJsonBytes(bytes(map)),
        throwsA(isA<InvalidOtpContentException>()),
        reason: reason,
      );
    }

    test('geçerli örnek okunuyor', () {
      expect(OtpContent.fromJsonBytes(bytes(valid)).issuer, 'Örnek Servis');
    });

    test('JSON olmayan ve nesne olmayan içerik', () {
      for (final text in ['', '{', '[]', '"metin"', 'null']) {
        expect(
          () => OtpContent.fromJsonBytes(Uint8List.fromList(utf8.encode(text))),
          throwsA(isA<InvalidOtpContentException>()),
          reason: text,
        );
      }
      expect(
        () => OtpContent.fromJsonBytes(Uint8List.fromList([0xff, 0xfe])),
        throwsA(isA<InvalidOtpContentException>()),
      );
    });

    test('eksik ve fazla alan', () {
      for (final key in valid.keys) {
        rejects({...valid}..remove(key), 'eksik $key');
      }
      rejects({...valid, 'image': 'https://example.com/logo.png'}, 'fazla');
    });

    test('bilinmeyen sürüm', () {
      rejects({...valid, 'version': 2}, 'sürüm 2');
      rejects({...valid, 'version': '1'}, 'metin sürüm');
    });

    test('yanlış türler', () {
      const wrong = <String, Object?>{
        'kind': 'steam',
        'issuer': 1,
        'account': null,
        'algorithm': 'MD5',
        'digits': '6',
        'period': 30.5,
        'loginId': 5,
        'notes': false,
        'favorite': 'true',
        'trashedAt': '2026',
      };
      wrong.forEach((key, value) => rejects({...valid, key: value}, key));
    });

    test('anahtar yalnızca bizim yazdığımız Base32 biçiminde', () {
      for (final value in [
        'jbswy3dpehpk3pxp',
        'JBSWY3DPEHPK3PXP====',
        'JBSW Y3DP',
        'JBSWY3DPEHPK3PX1',
        '',
        'MZ',
      ]) {
        rejects({...valid, 'secret': value}, value);
      }
      rejects({...valid, 'secret': Base32.encode(List.filled(257, 1))}, 'uzun');
    });

    test('sınır dışı değerler', () {
      rejects({...valid, 'digits': 5}, 'digits 5');
      rejects({...valid, 'digits': 9}, 'digits 9');
      rejects({...valid, 'period': 0}, 'period 0');
      rejects({...valid, 'period': 3601}, 'period 3601');
      rejects({...valid, 'trashedAt': 8640000000000001}, 'tarih taşması');
    });

    test('türe ait olmayan alan dolu olamaz', () {
      rejects({...valid, 'counter': 0}, 'TOTP sayacı');
      rejects({...valid, 'period': null}, 'TOTP süresiz');
      final hotp = {...valid, 'kind': 'hotp', 'period': null, 'counter': 3};
      expect(OtpContent.fromJsonBytes(bytes(hotp)).parameters.counter, 3);
      rejects({...hotp, 'period': 30}, 'HOTP süresi');
      rejects({...hotp, 'counter': null}, 'HOTP sayaçsız');
      rejects({...hotp, 'counter': -1}, 'eksi sayaç');
    });

    test('parola kaydı kimliği 32 küçük harf onaltılık', () {
      for (final value in [
        '000102030405060708090A0B0C0D0E0F',
        '000102030405060708090a0b0c0d0e',
        '000102030405060708090a0b0c0d0e0f00',
        '000102030405060708090a0b0c0d0e0g',
      ]) {
        rejects({...valid, 'loginId': value}, value);
      }
    });

    test('hata mesajı anahtarı içermiyor', () {
      try {
        OtpContent.fromJsonBytes(bytes({...valid, 'secret': 'GİZLİ1'}));
        fail('Hata bekleniyordu');
      } on InvalidOtpContentException catch (error) {
        expect(error.toString(), isNot(contains('GİZLİ1')));
      }
    });
  });

  group('copyWith', () {
    test('kimlik ve çöp kutusu verilmezse korunuyor, null temizliyor', () {
      final same = full.copyWith(notes: 'yeni');
      expect(same.loginId, loginId);
      expect(same.trashedAt, full.trashedAt);
      expect(same.notes, 'yeni');

      final cleared = full.copyWith(loginId: null, trashedAt: null);
      expect(cleared.loginId, isNull);
      expect(cleared.isTrashed, isFalse);
    });

    test('kimlik kopyalanıyor ve uzunluğu denetleniyor', () {
      final source = Uint8List.fromList(loginId);
      final content = OtpContent(parameters: full.parameters, loginId: source);
      source[0] = 99;
      expect(content.loginId![0], 0);
      expect(
        () => OtpContent(parameters: full.parameters, loginId: Uint8List(15)),
        throwsArgumentError,
      );
    });
  });
}

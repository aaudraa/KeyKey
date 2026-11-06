import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/data/otpauth_uri.dart';

void main() {
  const secret = 'JBSWY3DPEHPK3PXP';
  final secretBytes = Base32.decodeCanonical(secret);

  Matcher failsWith(OtpauthError error) => throwsA(
    isA<InvalidOtpauthUriException>().having((e) => e.error, 'error', error),
  );

  group('geçerli bağlantılar', () {
    test("Key Uri Format'ın örneği", () {
      final account = OtpauthUri.parse(
        'otpauth://totp/Example:alice@google.com?secret=$secret&issuer=Example',
      );
      expect(account.issuer, 'Example');
      expect(account.account, 'alice@google.com');
      expect(account.parameters, OtpParameters.totp(secret: secretBytes));
    });

    test('bütün parametreler', () {
      final account = OtpauthUri.parse(
        'otpauth://totp/ACME%20Co:john.doe@email.com?'
        'secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME%20Co'
        '&algorithm=SHA256&digits=8&period=60',
      );
      expect(account.issuer, 'ACME Co');
      expect(account.account, 'john.doe@email.com');
      expect(account.parameters.algorithm, OtpAlgorithm.sha256);
      expect(account.parameters.digits, 8);
      expect(account.parameters.period, 60);
    });

    test('HOTP', () {
      final account = OtpauthUri.parse(
        'otpauth://hotp/Servis:hesap?secret=$secret&counter=7',
      );
      expect(account.parameters.kind, OtpKind.hotp);
      expect(account.parameters.counter, 7);
      expect(account.parameters.period, isNull);
    });

    test('şema ve tür büyük küçük harf ayırmıyor, boşluklar atılıyor', () {
      final account = OtpauthUri.parse(
        '  OTPAUTH://TOTP/Servis:hesap?secret=$secret \n',
      );
      expect(account.parameters.kind, OtpKind.totp);
    });

    test('anahtarda küçük harf, boşluk ve dolgu kabul ediliyor', () {
      final account = OtpauthUri.parse(
        'otpauth://totp/x?secret=jbsw%20y3dp-ehpk3pxp%3D%3D%3D',
      );
      expect(account.parameters.secret, secretBytes);
    });

    test('issuer parametresi etiketteki önekten önce geliyor', () {
      final account = OtpauthUri.parse(
        'otpauth://totp/Eski:hesap?secret=$secret&issuer=Yeni',
      );
      expect(account.issuer, 'Yeni');
      expect(account.account, 'hesap');
    });

    test('etiket öneki, kodlanmış iki nokta ve boşluk', () {
      final account = OtpauthUri.parse(
        'otpauth://totp/Servis%3A%20%20hesap?secret=$secret',
      );
      expect(account.issuer, 'Servis');
      expect(account.account, 'hesap');
    });

    test('etiketsiz ve öneksiz', () {
      expect(OtpauthUri.parse('otpauth://totp?secret=$secret').account, '');
      final plain = OtpauthUri.parse('otpauth://totp/hesap?secret=$secret');
      expect(plain.issuer, '');
      expect(plain.account, 'hesap');
    });

    test('boş issuer parametresi yok sayılıyor', () {
      final account = OtpauthUri.parse(
        'otpauth://totp/Servis:hesap?secret=$secret&issuer=',
      );
      expect(account.issuer, 'Servis');
    });

    test('sorgudaki artı boşluk, yoldaki artı artı', () {
      final account = OtpauthUri.parse(
        'otpauth://totp/A+B:c?secret=$secret&issuer=Foo+Bar',
      );
      expect(account.issuer, 'Foo Bar');
      expect(
        OtpauthUri.parse('otpauth://totp/A+B:c?secret=$secret').issuer,
        'A+B',
      );
    });

    test('Türkçe karakterler', () {
      final account = OtpauthUri.parse(
        'otpauth://totp/%C4%B0%C5%9F%20Bankas%C4%B1:%C3%A7a%C4%9Flar'
        '?secret=$secret',
      );
      expect(account.issuer, 'İş Bankası');
      expect(account.account, 'çağlar');
    });

    test('bilinmeyen parametreler ve parça yok sayılıyor', () {
      final account = OtpauthUri.parse(
        'otpauth://totp/x?secret=$secret&image=https%3A%2F%2Fexample.com'
        '&image=ikinci&&foo#parca',
      );
      expect(account.parameters.secret, secretBytes);
    });

    test('parametre adları büyük küçük harf ayırmıyor', () {
      final account = OtpauthUri.parse(
        'otpauth://totp/x?Secret=$secret&Digits=8&ALGORITHM=sha512',
      );
      expect(account.parameters.digits, 8);
      expect(account.parameters.algorithm, OtpAlgorithm.sha512);
    });

    test('algoritma adında tire kabul ediliyor', () {
      expect(
        OtpauthUri.parse('otpauth://totp/x?secret=$secret&algorithm=SHA-256')
            .parameters
            .algorithm,
        OtpAlgorithm.sha256,
      );
    });

    test('TOTP sayaç, HOTP süre parametresini yok sayıyor', () {
      expect(
        OtpauthUri.parse('otpauth://totp/x?secret=$secret&counter=abc')
            .parameters
            .counter,
        isNull,
      );
      expect(
        OtpauthUri.parse('otpauth://hotp/x?secret=$secret&counter=1&period=0')
            .parameters
            .period,
        isNull,
      );
    });

    test('yön değiştiren ve denetim karakterleri atılıyor', () {
      final account = OtpauthUri.parse(
        'otpauth://totp/%E2%80%AEelgoog%E2%80%AC:a%0Ab?secret=$secret',
      );
      expect(account.issuer, 'elgoog');
      expect(account.account, 'ab');
    });
  });

  group('reddedilen bağlantılar', () {
    final cases = <String, OtpauthError>{
      'https://example.com': OtpauthError.notOtpauth,
      'otpauth:/totp/x?secret=$secret': OtpauthError.notOtpauth,
      '': OtpauthError.notOtpauth,
      'otpauth://steam/x?secret=$secret': OtpauthError.unsupportedType,
      'otpauth://motp/x?secret=$secret': OtpauthError.unsupportedType,
      'otpauth:///x?secret=$secret': OtpauthError.unsupportedType,
      'otpauth-migration://offline?data=abc': OtpauthError.notOtpauth,
      'otpauth://totp/x': OtpauthError.missingSecret,
      'otpauth://totp/x?secret=': OtpauthError.missingSecret,
      'otpauth://totp/x?secret=%20': OtpauthError.missingSecret,
      'otpauth://totp/x?secret=ABC1': OtpauthError.invalidSecret,
      'otpauth://totp/x?secret=M': OtpauthError.invalidSecret,
      'otpauth://totp/x?secret=MY%3D%3DMY': OtpauthError.invalidSecret,
      'otpauth://totp/x?secret=$secret&secret=$secret':
          OtpauthError.duplicateParameter,
      'otpauth://totp/x?secret=$secret&Digits=6&digits=6':
          OtpauthError.duplicateParameter,
      'otpauth://totp/x?secret=$secret&algorithm=MD5':
          OtpauthError.invalidAlgorithm,
      'otpauth://totp/x?secret=$secret&algorithm=':
          OtpauthError.invalidAlgorithm,
      'otpauth://totp/x?secret=$secret&digits=5': OtpauthError.invalidDigits,
      'otpauth://totp/x?secret=$secret&digits=9': OtpauthError.invalidDigits,
      'otpauth://totp/x?secret=$secret&digits=%2B6': OtpauthError.invalidDigits,
      'otpauth://totp/x?secret=$secret&digits=6.0': OtpauthError.invalidDigits,
      'otpauth://totp/x?secret=$secret&digits=': OtpauthError.invalidDigits,
      'otpauth://totp/x?secret=$secret&period=0': OtpauthError.invalidPeriod,
      'otpauth://totp/x?secret=$secret&period=-30': OtpauthError.invalidPeriod,
      'otpauth://totp/x?secret=$secret&period=3601': OtpauthError.invalidPeriod,
      'otpauth://totp/x?secret=$secret&period=99999999999999999999':
          OtpauthError.invalidPeriod,
      'otpauth://hotp/x?secret=$secret': OtpauthError.missingCounter,
      'otpauth://hotp/x?secret=$secret&counter=-1': OtpauthError.invalidCounter,
      'otpauth://hotp/x?secret=$secret&counter=9223372036854775808':
          OtpauthError.invalidCounter,
      'otpauth://totp/a%ZZb?secret=$secret': OtpauthError.invalidEncoding,
      'otpauth://totp/a%FFb?secret=$secret': OtpauthError.invalidEncoding,
      'otpauth://totp/x?secret=$secret&issuer=%E2':
          OtpauthError.invalidEncoding,
    };
    for (final MapEntry(key: uri, value: error) in cases.entries) {
      test(uri.isEmpty ? '(boş)' : uri, () {
        expect(() => OtpauthUri.parse(uri), failsWith(error));
      });
    }

    test('çok uzun metin', () {
      final long = 'otpauth://totp/${'a' * 4096}?secret=$secret';
      expect(() => OtpauthUri.parse(long), failsWith(OtpauthError.tooLong));
    });

    test('çok uzun anahtar', () {
      final longSecret = Base32.encode(List.filled(257, 7));
      expect(
        () => OtpauthUri.parse('otpauth://totp/x?secret=$longSecret'),
        failsWith(OtpauthError.invalidSecret),
      );
    });

    test('hata mesajı girdiyi içermiyor', () {
      try {
        OtpauthUri.parse('otpauth://totp/x?secret=GIZLI1ANAHTAR');
        fail('Hata bekleniyordu');
      } on InvalidOtpauthUriException catch (error) {
        expect(error.toString(), isNot(contains('GIZLI')));
      }
    });
  });

  group('yazma', () {
    test('yazılan bağlantı aynı hesabı veriyor', () {
      final cases = [
        (
          OtpParameters.totp(
            secret: secretBytes,
            algorithm: OtpAlgorithm.sha512,
            digits: 8,
            period: 45,
          ),
          'İş: Bankası & Co?',
          'ayşe+test@example.com',
        ),
        (OtpParameters.hotp(secret: secretBytes, counter: 99), '', 'yalnız'),
        (OtpParameters.totp(secret: secretBytes), 'Servis', ''),
        (OtpParameters.totp(secret: secretBytes), '', 'iki:nokta'),
        (OtpParameters.totp(secret: secretBytes), 'a:b', 'c:d'),
      ];
      for (final (parameters, issuer, account) in cases) {
        final uri = OtpauthUri.format(
          parameters: parameters,
          issuer: issuer,
          account: account,
        );
        final read = OtpauthUri.parse(uri);
        expect(read.parameters, parameters, reason: uri);
        expect(read.issuer, issuer, reason: uri);
        expect(read.account, account, reason: uri);
      }
    });

    test('biçim', () {
      expect(
        OtpauthUri.format(
          parameters: OtpParameters.totp(secret: secretBytes),
          issuer: 'Example',
          account: 'alice@google.com',
        ),
        'otpauth://totp/Example:alice%40google.com?secret=$secret'
        '&issuer=Example&algorithm=SHA1&digits=6&period=30',
      );
    });
  });

  group('rastgele girdi', () {
    void parsesOrRejects(String text) {
      try {
        OtpauthUri.parse(text);
      } on InvalidOtpauthUriException {
        // Beklenen tek hata türü.
      }
    }

    test('rastgele metinler yalnızca kendi hatamızı fırlatıyor', () {
      final random = Random(5);
      const alphabet =
          'otpauth://tohp/?&=:%#+-ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
          'abcdefghijklmnopqrstuvwxyz0123456789 İıçğöşü\u202e\u0000';
      for (var i = 0; i < 20000; i++) {
        final length = random.nextInt(80);
        final text = String.fromCharCodes(
          List.generate(
            length,
            (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length)),
          ),
        );
        parsesOrRejects(i.isEven ? 'otpauth://$text' : text);
      }
    });

    test('geçerli bağlantının bozulmuş halleri', () {
      final random = Random(7);
      const valid =
          'otpauth://hotp/%C4%B0%C5%9F:hesap?secret=$secret&issuer=Servis'
          '&algorithm=SHA256&digits=8&counter=12';
      for (var i = 0; i < 20000; i++) {
        final units = valid.codeUnits.toList();
        for (var j = 0; j < 1 + random.nextInt(4); j++) {
          final position = random.nextInt(units.length);
          switch (random.nextInt(3)) {
            case 0:
              units[position] = random.nextInt(0x10000);
            case 1:
              units.removeAt(position);
            default:
              units.insert(position, random.nextInt(0x80));
          }
        }
        parsesOrRejects(String.fromCharCodes(units));
      }
    });
  });
}

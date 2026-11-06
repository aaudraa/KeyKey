import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/authenticator/application/otp_generator.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';

import '../../core/crypto/hex.dart';

DateTime _at(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

void main() {
  // RFC 4226, Ek D. Anahtar ASCII "12345678901234567890".
  final rfc4226Secret = ascii.encode('12345678901234567890');

  group('HOTP, RFC 4226 Ek D', () {
    const expected = [
      '755224',
      '287082',
      '359152',
      '969429',
      '338314',
      '254676',
      '287922',
      '162583',
      '399871',
      '520489',
    ];
    for (var count = 0; count < expected.length; count++) {
      test('sayaç $count', () {
        expect(
          OtpGenerator.hotp(secret: rfc4226Secret, counter: count),
          expected[count],
        );
      });
    }

    // Tablo 2'deki kesilmiş ondalık değerlerin son 7 ve 8 hanesi. Bu,
    // kesmenin 6 haneden bağımsız doğru olduğunu gösterir.
    const truncated = [
      1284755224,
      1094287082,
      137359152,
      1726969429,
      1640338314,
      868254676,
      1918287922,
      82162583,
      673399871,
      645520489,
    ];
    for (final digits in [7, 8]) {
      test('$digits hane', () {
        final modulus = digits == 7 ? 10000000 : 100000000;
        for (var count = 0; count < truncated.length; count++) {
          expect(
            OtpGenerator.hotp(
              secret: rfc4226Secret,
              counter: count,
              digits: digits,
            ),
            (truncated[count] % modulus).toString().padLeft(digits, '0'),
          );
        }
      });
    }
  });

  group('TOTP, RFC 6238 Ek B', () {
    // RFC metni her algoritma için 20 baytlık anahtar yazıyor, ama tablodaki
    // değerler Ek A'daki örnek koddan geliyor ve o kod SHA-256 için 32,
    // SHA-512 için 64 baytlık anahtar kullanıyor (bilinen RFC hatası).
    final seeds = {
      OtpAlgorithm.sha1: fromHex('3132333435363738393031323334353637383930'),
      OtpAlgorithm.sha256: fromHex(
        '3132333435363738393031323334353637383930'
        '313233343536373839303132',
      ),
      OtpAlgorithm.sha512: fromHex(
        '3132333435363738393031323334353637383930'
        '3132333435363738393031323334353637383930'
        '3132333435363738393031323334353637383930'
        '31323334',
      ),
    };
    const vectors = <(int, int, OtpAlgorithm, String)>[
      (59, 0x0000000000000001, OtpAlgorithm.sha1, '94287082'),
      (59, 0x0000000000000001, OtpAlgorithm.sha256, '46119246'),
      (59, 0x0000000000000001, OtpAlgorithm.sha512, '90693936'),
      (1111111109, 0x00000000023523EC, OtpAlgorithm.sha1, '07081804'),
      (1111111109, 0x00000000023523EC, OtpAlgorithm.sha256, '68084774'),
      (1111111109, 0x00000000023523EC, OtpAlgorithm.sha512, '25091201'),
      (1111111111, 0x00000000023523ED, OtpAlgorithm.sha1, '14050471'),
      (1111111111, 0x00000000023523ED, OtpAlgorithm.sha256, '67062674'),
      (1111111111, 0x00000000023523ED, OtpAlgorithm.sha512, '99943326'),
      (1234567890, 0x000000000273EF07, OtpAlgorithm.sha1, '89005924'),
      (1234567890, 0x000000000273EF07, OtpAlgorithm.sha256, '91819424'),
      (1234567890, 0x000000000273EF07, OtpAlgorithm.sha512, '93441116'),
      (2000000000, 0x0000000003F940AA, OtpAlgorithm.sha1, '69279037'),
      (2000000000, 0x0000000003F940AA, OtpAlgorithm.sha256, '90698825'),
      (2000000000, 0x0000000003F940AA, OtpAlgorithm.sha512, '38618901'),
      (20000000000, 0x0000000027BC86AA, OtpAlgorithm.sha1, '65353130'),
      (20000000000, 0x0000000027BC86AA, OtpAlgorithm.sha256, '77737706'),
      (20000000000, 0x0000000027BC86AA, OtpAlgorithm.sha512, '47863826'),
    ];
    for (final (seconds, counter, algorithm, code) in vectors) {
      test('${algorithm.label}, $seconds sn', () {
        expect(OtpGenerator.totpCounter(_at(seconds), 30), counter);
        expect(
          OtpGenerator.totp(
            secret: seeds[algorithm]!,
            time: _at(seconds),
            algorithm: algorithm,
            digits: 8,
          ),
          code,
        );
      });
    }
  });

  group('süre', () {
    test('sayaç süre sınırında değişiyor', () {
      expect(OtpGenerator.totpCounter(_at(29), 30), 0);
      expect(OtpGenerator.totpCounter(_at(30), 30), 1);
      expect(
        OtpGenerator.totpCounter(
          DateTime.fromMillisecondsSinceEpoch(59999, isUtc: true),
          60,
        ),
        0,
      );
    });

    test('kalan süre', () {
      expect(OtpGenerator.remaining(_at(0), 30), const Duration(seconds: 30));
      expect(OtpGenerator.remaining(_at(29), 30), const Duration(seconds: 1));
      expect(
        OtpGenerator.remaining(
          DateTime.fromMillisecondsSinceEpoch(29500, isUtc: true),
          30,
        ),
        const Duration(milliseconds: 500),
      );
      expect(OtpGenerator.remaining(_at(30), 30), const Duration(seconds: 30));
    });

    test('saat dilimi sonucu değiştirmiyor', () {
      final utc = _at(1234567890);
      expect(
        OtpGenerator.totpCounter(utc.toLocal(), 30),
        OtpGenerator.totpCounter(utc, 30),
      );
    });

    test("1970'ten önceki saat düşürmüyor", () {
      final before = _at(-1);
      expect(OtpGenerator.totpCounter(before, 30), -1);
      expect(OtpGenerator.remaining(before, 30), const Duration(seconds: 1));
      expect(
        OtpGenerator.totp(secret: rfc4226Secret, time: before),
        hasLength(6),
      );
    });

    test('sıradaki kod bir sonraki sürenin kodu', () {
      final parameters = OtpParameters.totp(secret: rfc4226Secret, digits: 8);
      expect(OtpGenerator.nextTotp(parameters, _at(29)), '94287082');
      expect(OtpGenerator.codeFor(parameters, _at(59)), '94287082');
    });

    test('özel süre', () {
      final parameters = OtpParameters.totp(secret: rfc4226Secret, period: 60);
      // 60 saniyelik sürede 119. saniye sayaç 1'dir.
      expect(OtpGenerator.codeFor(parameters, _at(119)), '287082');
    });
  });

  test('HOTP parametresi kayıttaki sayacı kullanıyor', () {
    final parameters = OtpParameters.hotp(secret: rfc4226Secret, counter: 3);
    expect(OtpGenerator.codeFor(parameters, _at(0)), '969429');
    expect(
      OtpGenerator.codeFor(parameters.withNextCounter(), _at(0)),
      '338314',
    );
    expect(() => OtpGenerator.nextTotp(parameters, _at(0)), throwsStateError);
  });

  test('geçersiz girdi programlama hatası sayılıyor', () {
    expect(
      () => OtpGenerator.hotp(secret: const [], counter: 0),
      throwsArgumentError,
    );
    for (final digits in [5, 9]) {
      expect(
        () => OtpGenerator.hotp(
          secret: rfc4226Secret,
          counter: 0,
          digits: digits,
        ),
        throwsArgumentError,
      );
    }
    expect(() => OtpGenerator.totpCounter(_at(0), 0), throwsArgumentError);
    expect(() => OtpGenerator.remaining(_at(0), 3601), throwsArgumentError);
  });
}

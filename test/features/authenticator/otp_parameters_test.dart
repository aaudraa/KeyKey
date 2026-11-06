import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';

void main() {
  final secret = List<int>.generate(20, (i) => i);

  test('varsayılanlar Key Uri Format ile aynı', () {
    final totp = OtpParameters.totp(secret: secret);
    expect(totp.kind, OtpKind.totp);
    expect(totp.algorithm, OtpAlgorithm.sha1);
    expect(totp.digits, 6);
    expect(totp.period, 30);
    expect(totp.counter, isNull);

    final hotp = OtpParameters.hotp(secret: secret);
    expect(hotp.kind, OtpKind.hotp);
    expect(hotp.counter, 0);
    expect(hotp.period, isNull);
  });

  test('anahtar kopyalanıyor ve değiştirilemiyor', () {
    final source = List<int>.of(secret);
    final parameters = OtpParameters.totp(secret: source);
    source[0] = 99;
    expect(parameters.secret[0], 0);
    expect(() => parameters.secret[0] = 1, throwsUnsupportedError);
  });

  test('sınırlar', () {
    expect(() => OtpParameters.totp(secret: const []), throwsArgumentError);
    expect(
      () => OtpParameters.totp(secret: List.filled(257, 1)),
      throwsArgumentError,
    );
    expect(
      OtpParameters.totp(secret: List.filled(256, 1)).secret,
      hasLength(256),
    );
    for (final digits in [5, 9]) {
      expect(
        () => OtpParameters.totp(secret: secret, digits: digits),
        throwsArgumentError,
      );
    }
    for (final period in [0, -30, 3601]) {
      expect(
        () => OtpParameters.totp(secret: secret, period: period),
        throwsArgumentError,
      );
    }
    expect(
      () => OtpParameters.hotp(secret: secret, counter: -1),
      throwsArgumentError,
    );
  });

  test('HOTP sayacı artıyor, en büyük değerde taşmıyor', () {
    final hotp = OtpParameters.hotp(secret: secret, counter: 41);
    expect(hotp.withNextCounter().counter, 42);
    expect(hotp.counter, 41);

    final last = OtpParameters.hotp(
      secret: secret,
      counter: 0x7fffffffffffffff,
    );
    expect(last.withNextCounter, throwsStateError);
    expect(
      OtpParameters.totp(secret: secret).withNextCounter,
      throwsStateError,
    );
  });

  test('eşitlik anahtar baytlarına bakıyor', () {
    expect(
      OtpParameters.totp(secret: secret),
      OtpParameters.totp(secret: List.of(secret)),
    );
    expect(
      OtpParameters.totp(secret: secret).hashCode,
      OtpParameters.totp(secret: List.of(secret)).hashCode,
    );
    expect(
      OtpParameters.totp(secret: secret),
      isNot(OtpParameters.totp(secret: [...secret.take(19), 99])),
    );
    expect(
      OtpParameters.totp(secret: secret),
      isNot(OtpParameters.hotp(secret: secret)),
    );
  });

  test('metin hali anahtarı içermiyor', () {
    final text = OtpParameters.totp(secret: secret).toString();
    expect(text, isNot(contains('[')));
    expect(text, contains('SHA1'));
  });

  test('adlar', () {
    expect(OtpKind.byLabel('totp'), OtpKind.totp);
    expect(OtpKind.byLabel('TOTP'), isNull);
    expect(OtpAlgorithm.byLabel('SHA512'), OtpAlgorithm.sha512);
    expect(OtpAlgorithm.byLabel('MD5'), isNull);
  });
}

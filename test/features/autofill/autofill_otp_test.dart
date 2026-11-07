import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/authenticator/application/otp_generator.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/autofill/application/autofill_otp.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/data/login_content.dart';

import '../../support/fake_vault_service.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 9);
  final loginId = FakeLoginRepository.item(
    const LoginContent(name: ''),
    id: 3,
  ).id;
  final otherId = FakeLoginRepository.item(
    const LoginContent(name: ''),
    id: 4,
  ).id;
  final totp = OtpParameters.totp(secret: utf8.encode('birinci-anahtar'));
  final totp2 = OtpParameters.totp(secret: utf8.encode('ikinci-anahtar'));
  final hotp = OtpParameters.hotp(secret: utf8.encode('sayacli-anahtar'));

  Future<String?> codeFor(
    List<OtpContent> contents, {
    AppSettings settings = AppSettings.defaults,
  }) => linkedOtpCodeForFill(
    settings: FakeSettingsRepository(settings),
    otps: FakeOtpRepository(
      items: [
        for (final (index, content) in contents.indexed)
          FakeOtpRepository.item(content, id: index),
      ],
    ),
    loginId: loginId,
    now: now,
  );

  test('kayda bağlı TOTP hesabının güncel kodu', () async {
    expect(
      await codeFor([
        OtpContent(parameters: totp2, loginId: otherId),
        OtpContent(parameters: totp, loginId: loginId),
      ]),
      OtpGenerator.codeFor(totp, now),
    );
  });

  test('ayar kapalıysa ve ayar okunamadıysa kod yok', () async {
    final contents = [OtpContent(parameters: totp, loginId: loginId)];
    expect(
      await codeFor(
        contents,
        settings: const AppSettings(
          otpRequireAuth: false,
          autofillCopyOtp: false,
        ),
      ),
      isNull,
    );
    expect(await codeFor(contents, settings: AppSettings.requireAuth), isNull);
  });

  test('HOTP sayacı ilerletilmesin diye kopyalanmıyor', () async {
    expect(
      await codeFor([OtpContent(parameters: hotp, loginId: loginId)]),
      isNull,
    );
  });

  test('çöp kutusundaki hesap kullanılmıyor', () async {
    expect(
      await codeFor([
        OtpContent(parameters: totp, loginId: loginId, trashedAt: now),
      ]),
      isNull,
    );
  });
}

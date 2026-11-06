import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/vault/biometric_bridge.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  // RFC 4226 Ek D anahtarı: 30. saniyede TOTP kodu 287082.
  final rfcSecret = ascii.encode('12345678901234567890');

  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeOtpRepository otps;
  late FakeLoginRepository logins;
  late FakeSettingsRepository settings;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);

  setUp(() {
    service = FakeVaultService(sodium);
    settings = FakeSettingsRepository(AppSettings.requireAuth);
    logins = FakeLoginRepository(
      items: [
        FakeLoginRepository.item(const LoginContent(name: 'GitHub'), id: 1),
      ],
    );
    otps = FakeOtpRepository(
      items: [
        FakeOtpRepository.item(
          OtpContent(
            parameters: OtpParameters.totp(secret: rfcSecret),
            issuer: 'GitHub',
            loginId: logins.items.single.id,
          ),
          id: 1,
        ),
      ],
    );
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpApp(WidgetTester tester) => pumpKeyKey(
    tester,
    status: VaultOpen(service.newSession()),
    service: service,
    otps: otps,
    logins: logins,
    settings: settings,
    clock: () => DateTime.fromMillisecondsSinceEpoch(30000, isUtc: true),
  );

  Future<void> openAuthenticator(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.shield_outlined));
    await settle(tester);
  }

  Future<void> enterPassword(WidgetTester tester, String password) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      password,
    );
    await tester.tap(find.text('Doğrula'));
    await settle(tester);
  }

  testWidgets('ayar kapalıyken kodlar doğrudan görünüyor', (tester) async {
    settings.settings = AppSettings.defaults;
    await openAuthenticator(tester);

    expect(find.text('287 082'), findsOneWidget);
    expect(find.text('Kodlar gizli'), findsNothing);
  });

  testWidgets('ayar açıkken kodlar ana parolayla açılıyor', (tester) async {
    await openAuthenticator(tester);

    expect(find.text('Kodlar gizli'), findsOneWidget);
    expect(find.text('287 082'), findsNothing);
    expect(find.text('GitHub'), findsNothing);

    await tester.tap(find.text('Kodları göster'));
    await settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);

    await enterPassword(tester, 'yanlis-parola');
    expect(find.text('Parola yanlış.'), findsOneWidget);
    expect(find.text('287 082'), findsNothing);

    await enterPassword(tester, FakeVaultService.correctPassword);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('287 082'), findsOneWidget);
  });

  testWidgets('vazgeçilince kodlar gizli kalıyor', (tester) async {
    await openAuthenticator(tester);

    await tester.tap(find.text('Kodları göster'));
    await settle(tester);
    await tester.tap(find.text('Vazgeç'));
    await settle(tester);

    expect(find.text('Kodlar gizli'), findsOneWidget);
  });

  testWidgets('parmak iziyle açılıyor', (tester) async {
    service
      ..biometricSupportValue = BiometricSupport.available
      ..biometricEnabled = true
      ..nextBiometric = const BiometricSuccess(null);
    await openAuthenticator(tester);

    await tester.tap(find.text('Kodları göster'));
    await settle(tester);

    expect(service.biometricPrompts, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('287 082'), findsOneWidget);
  });

  testWidgets('parmak izinden vazgeçilince ana parola soruluyor', (
    tester,
  ) async {
    service
      ..biometricSupportValue = BiometricSupport.available
      ..biometricEnabled = true;
    await openAuthenticator(tester);

    await tester.tap(find.text('Kodları göster'));
    await settle(tester);

    expect(service.biometricPrompts, 1);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('hatalı denemeler kilit beklemesine ekleniyor', (tester) async {
    service.waitAfterReject = const Duration(seconds: 30);
    await openAuthenticator(tester);

    await tester.tap(find.text('Kodları göster'));
    await settle(tester);
    await enterPassword(tester, 'yanlis-parola');

    expect(find.textContaining('Çok fazla hatalı deneme'), findsOneWidget);
  });

  testWidgets('kilitlenince kodlar yeniden gizleniyor', (tester) async {
    await openAuthenticator(tester);
    await tester.tap(find.text('Kodları göster'));
    await settle(tester);
    await enterPassword(tester, FakeVaultService.correctPassword);
    expect(find.text('287 082'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    container.read(vaultControllerProvider.notifier).lock();
    await settle(tester);
    await container
        .read(vaultControllerProvider.notifier)
        .unlockWithPassword(FakeVaultService.correctPassword);
    await settle(tester);
    await tester.tap(find.byIcon(Icons.shield_outlined));
    await settle(tester);

    expect(find.text('Kodlar gizli'), findsOneWidget);
  });

  testWidgets('parola ayrıntısındaki kod da gizleniyor', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('GitHub'));
    await settle(tester);

    expect(find.text('2FA kodu'), findsOneWidget);
    expect(find.text('287 082'), findsNothing);

    await tester.tap(find.text('Kodları göster'));
    await settle(tester);
    await enterPassword(tester, FakeVaultService.correctPassword);

    expect(find.text('287 082'), findsOneWidget);
  });

  group('ayar', () {
    Future<void> openSettings(WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await settle(tester);
    }

    Finder toggle() => find.widgetWithText(
      SwitchListTile,
      '2FA kodlarını göstermeden önce doğrula',
    );

    testWidgets('açmak doğrulama istemiyor', (tester) async {
      settings.settings = AppSettings.defaults;
      await openSettings(tester);

      await tester.tap(toggle());
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(settings.settings.otpRequireAuth, isTrue);
      expect(tester.widget<SwitchListTile>(toggle()).value, isTrue);
    });

    testWidgets('kapatmak doğrulama istiyor', (tester) async {
      await openSettings(tester);

      await tester.tap(toggle());
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await settle(tester);
      expect(settings.settings.otpRequireAuth, isTrue);

      await tester.tap(toggle());
      await settle(tester);
      await enterPassword(tester, FakeVaultService.correctPassword);

      expect(settings.settings.otpRequireAuth, isFalse);
      expect(tester.widget<SwitchListTile>(toggle()).value, isFalse);
    });
  });
}

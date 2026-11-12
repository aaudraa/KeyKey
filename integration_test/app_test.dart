import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/app/app.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test/support/fake_vault_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SodiumSumo sharedSodium;

  setUpAll(() async {
    sharedSodium = await SodiumSumoInit.init();
  });

  /// Kasası açık uygulama. Kasa akışı `vault_flow_test.dart` içinde.
  Widget openApp() {
    final service = FakeVaultService(sharedSodium);
    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        ambientMotionProvider.overrideWithValue(false),
        vaultServiceProvider.overrideWithValue(service),
        loginRepositoryFactoryProvider.overrideWithValue(
          (_) => FakeLoginRepository(),
        ),
        otpRepositoryFactoryProvider.overrideWithValue(
          (_) => FakeOtpRepository(),
        ),
        settingsRepositoryFactoryProvider.overrideWithValue(
          (_) => FakeSettingsRepository(),
        ),
        initialVaultStatusProvider.overrideWithValue(
          VaultOpen(service.newSession()),
        ),
      ],
      child: const KeyKeyApp(),
    );
  }

  testWidgets('uygulama açılıyor ve ekranlar arasında geçiliyor', (
    tester,
  ) async {
    await tester.pumpWidget(openApp());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock), findsOneWidget);

    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.shield), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('tema sistem ayarını izliyor', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    for (final brightness in Brightness.values) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      await tester.pumpWidget(openApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(GlassNavBar));
      expect(Theme.of(context).brightness, brightness);
    }
  });

  testWidgets('dil cihaz diline göre seçiliyor', (tester) async {
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    const cases = [
      (Locale('tr', 'TR'), 'Ayarlar'),
      (Locale('en', 'US'), 'Settings'),
      (Locale('de', 'DE'), 'Settings'),
    ];
    for (final (locale, label) in cases) {
      tester.platformDispatcher.localesTestValue = [locale];
      await tester.pumpWidget(openApp());
      await tester.pumpAndSettle();

      // Menüde yazı yok; sekme adı ekran okuyucu etiketinde.
      expect(find.bySemanticsLabel(RegExp('^$label\n')), findsOneWidget);
    }
  });

  testWidgets('libsodium bu Android sürümünde çalışıyor', (tester) async {
    final sodium = await SodiumSumoInit.init();
    final salt = sodium.randombytes.buf(sodium.crypto.pwhash.saltBytes);
    final password = Int8List.fromList(utf8.encode('deneme-parolasi'));

    final key = await sodium.runIsolated(
      (_, _) => sodium.crypto.pwhash.callRaw(
        outLen: 32,
        password: password,
        salt: salt,
        opsLimit: 3,
        memLimit: 64 * 1024 * 1024,
        alg: CryptoPwhashAlgorithm.argon2id13,
      ),
    );
    addTearDown(key.dispose);

    final aead = sodium.crypto.aeadXChaCha20Poly1305IETF;
    final nonce = sodium.randombytes.buf(aead.nonceBytes);
    final message = Uint8List.fromList(utf8.encode('gizli kayıt'));
    final cipherText = aead.encrypt(message: message, nonce: nonce, key: key);

    expect(
      aead.decrypt(cipherText: cipherText, nonce: nonce, key: key),
      message,
    );
  });
}

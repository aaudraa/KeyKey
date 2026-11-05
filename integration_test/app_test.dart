import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/app/app.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('uygulama açılıyor ve ekranlar arasında geçiliyor', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: KeyKeyApp()));
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
      await tester.pumpWidget(const ProviderScope(child: KeyKeyApp()));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(NavigationBar));
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
      await tester.pumpWidget(const ProviderScope(child: KeyKeyApp()));
      await tester.pumpAndSettle();

      expect(find.text(label), findsOneWidget);
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

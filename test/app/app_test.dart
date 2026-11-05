import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:sodium/sodium_sumo.dart';

import '../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
  });

  Future<void> pumpApp(WidgetTester tester, {Locale? locale}) => pumpKeyKey(
    tester,
    status: VaultOpen(service.newSession()),
    service: service,
    locale: locale ?? const Locale('tr'),
  );

  testWidgets('kasa açıkken uygulama kasa ekranıyla açılıyor', (tester) async {
    await pumpApp(tester, locale: const Locale('tr'));

    expect(find.text('Parolaların yakında burada olacak.'), findsOneWidget);
  });

  testWidgets('alt menüden ekranlar arasında geçiliyor', (tester) async {
    await pumpApp(tester, locale: const Locale('tr'));

    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pumpAndSettle();
    expect(
      find.text('Doğrulama kodların yakında burada olacak.'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Şimdi kilitle'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.lock_outline).last);
    await tester.pumpAndSettle();
  });

  group('tema sistem ayarını izliyor', () {
    Brightness currentBrightness(WidgetTester tester) {
      final context = tester.element(find.byType(Scaffold).first);
      return Theme.of(context).brightness;
    }

    testWidgets('açık tema', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await pumpApp(tester);

      expect(currentBrightness(tester), Brightness.light);
    });

    testWidgets('koyu tema', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await pumpApp(tester);

      expect(currentBrightness(tester), Brightness.dark);
    });
  });

  group('dil cihaz diline göre seçiliyor', () {
    testWidgets('Türkçe', (tester) async {
      await pumpApp(tester, locale: const Locale('tr', 'TR'));

      expect(find.text('Kasa'), findsWidgets);
    });

    testWidgets('İngilizce', (tester) async {
      await pumpApp(tester, locale: const Locale('en', 'US'));

      expect(find.text('Vault'), findsWidgets);
    });

    testWidgets('desteklenmeyen dilde İngilizceye düşüyor', (tester) async {
      await pumpApp(tester, locale: const Locale('de', 'DE'));

      expect(find.text('Vault'), findsWidgets);
    });
  });
}

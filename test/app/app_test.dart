import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/app.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, {Locale? locale}) async {
    if (locale != null) {
      tester.platformDispatcher.localesTestValue = [locale];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    }
    await tester.pumpWidget(const ProviderScope(child: KeyKeyApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('uygulama kasa ekranıyla açılıyor', (tester) async {
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
    expect(find.text('Ayarlar yakında burada olacak.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    expect(find.text('Parolaların yakında burada olacak.'), findsOneWidget);
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
      expect(find.text('Parolaların yakında burada olacak.'), findsOneWidget);
    });

    testWidgets('İngilizce', (tester) async {
      await pumpApp(tester, locale: const Locale('en', 'US'));

      expect(find.text('Vault'), findsWidgets);
      expect(find.text('Your passwords will be here soon.'), findsOneWidget);
    });

    testWidgets('desteklenmeyen dilde İngilizceye düşüyor', (tester) async {
      await pumpApp(tester, locale: const Locale('de', 'DE'));

      expect(find.text('Your passwords will be here soon.'), findsOneWidget);
    });
  });
}

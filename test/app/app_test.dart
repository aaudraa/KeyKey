import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/app.dart';
import 'package:keykey/app/ui/kk_snack.dart';
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

    expect(
      find.text('Henüz parola yok. Eklemek için alttaki + düğmesine dokun.'),
      findsOneWidget,
    );
  });

  testWidgets('kilitlenince açık bildirim kapanır', (tester) async {
    await pumpApp(tester, locale: const Locale('tr'));
    final context = tester.element(find.byType(KeyKeyApp));
    showKkSnack(tester.element(find.text('PAROLALAR').first), 'Çöpe taşındı');
    await tester.pumpAndSettle();
    expect(find.byType(KkSnack), findsOneWidget);

    ProviderScope.containerOf(context)
        .read(vaultControllerProvider.notifier)
        .lock();
    await tester.pumpAndSettle();
    expect(find.byType(KkSnack), findsNothing);
  });

  testWidgets('alt menüden ekranlar arasında geçiliyor', (tester) async {
    await pumpApp(tester, locale: const Locale('tr'));

    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Henüz 2FA hesabı yok. İlkini kurmak için alttaki + düğmesine dokun.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Ana parolayı değiştir'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.credit_card_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('Henüz kart yok'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.sticky_note_2_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('Henüz not yok'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.key_outlined).last);
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
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, locale: const Locale('tr', 'TR'));

      // Sekme adı görünmez (#163); ekran okuyucu etiketi dili gösterir.
      expect(find.bySemanticsLabel(RegExp(r'^Parolalar\n')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('İngilizce', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, locale: const Locale('en', 'US'));

      // Sekme adı görünmez (#163); ekran okuyucu etiketi dili gösterir.
      expect(find.bySemanticsLabel(RegExp(r'^Passwords\n')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('desteklenmeyen dilde İngilizceye düşüyor', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, locale: const Locale('de', 'DE'));

      // Sekme adı görünmez (#163); ekran okuyucu etiketi dili gösterir.
      expect(find.bySemanticsLabel(RegExp(r'^Passwords\n')), findsOneWidget);
      semantics.dispose();
    });
  });
}

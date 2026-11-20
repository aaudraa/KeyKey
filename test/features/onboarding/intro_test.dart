import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/onboarding/presentation/intro_art.dart';
import 'package:keykey/features/onboarding/presentation/intro_screen.dart';
import 'package:keykey/features/onboarding/presentation/onboarding_screen.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
  });

  const titles = [
    'KeyKey',
    'Verilerin sende',
    'Nerede ne var',
    'Otomatik doldurma',
    'Başka uygulamalardan geç',
    'Yedeğin sende',
  ];

  Future<void> pumpFresh(WidgetTester tester) =>
      pumpKeyKey(tester, status: const VaultNotSetUp(), service: service);

  /// Satır listenin sonunda, yüzen menünün altında kalmasın diye biraz
  /// daha kaydırılır.
  Future<void> openIntroFromSettings(WidgetTester tester, Finder row) async {
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(row, 200);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'İleri'));
    await tester.pumpAndSettle();
  }

  group('yönlendirme', () {
    test('kasa yokken tanıtıma gidilir, kurulum ve geri yükleme serbest', () {
      expect(
        vaultRedirect(const VaultNotSetUp(), AppRoutes.vault),
        AppRoutes.intro,
      );
      expect(vaultRedirect(const VaultNotSetUp(), AppRoutes.intro), isNull);
      expect(vaultRedirect(const VaultNotSetUp(), AppRoutes.setup), isNull);
      expect(vaultRedirect(const VaultNotSetUp(), AppRoutes.restore), isNull);
    });

    test('kasa açıkken tanıtım yeniden izlenebilir', () {
      expect(
        vaultRedirect(VaultOpen(service.newSession()), AppRoutes.intro),
        isNull,
      );
    });
  });

  testWidgets('ilk açılışta tanıtımın ilk sayfası gelir', (tester) async {
    await pumpFresh(tester);
    expect(find.byType(IntroScreen), findsOneWidget);
    expect(find.text(titles.first), findsOneWidget);
    expect(find.text('Atla'), findsOneWidget);
  });

  testWidgets('İleri sayfaları sırayla gezer, sonda Kasamı oluştur', (
    tester,
  ) async {
    await pumpFresh(tester);
    for (final title in titles.skip(1)) {
      await next(tester);
      expect(find.text(title), findsOneWidget);
    }
    expect(find.widgetWithText(FilledButton, 'İleri'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Kasamı oluştur'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('Atla kuruluma götürür', (tester) async {
    await pumpFresh(tester);
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Yedekten geri yükle'), findsOneWidget);
  });

  testWidgets('sayfa noktaları seçili sayfayı söyler', (tester) async {
    await pumpFresh(tester);
    expect(find.bySemanticsLabel('Sayfa 1 / 6'), findsOneWidget);
    await next(tester);
    expect(find.bySemanticsLabel('Sayfa 2 / 6'), findsOneWidget);
  });

  testWidgets("Ayarlar'dan yeniden izlenir, Bitti Ayarlar'a döner", (
    tester,
  ) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
    );
    final row = find.widgetWithText(ListTile, 'Tanıtımı yeniden göster');
    await openIntroFromSettings(tester, row);
    expect(find.byType(IntroScreen), findsOneWidget);
    for (var i = 1; i < titles.length; i++) {
      await next(tester);
    }
    expect(find.widgetWithText(FilledButton, 'Kasamı oluştur'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Bitti'));
    await tester.pumpAndSettle();
    expect(find.byType(IntroScreen), findsNothing);
    expect(row, findsOneWidget);
  });

  testWidgets("Ayarlar'dan açılınca Atla da Ayarlar'a döner", (tester) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
    );
    final row = find.widgetWithText(ListTile, 'Tanıtımı yeniden göster');
    await openIntroFromSettings(tester, row);
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(find.byType(IntroScreen), findsNothing);
    expect(row, findsOneWidget);
  });

  group('çizimler', () {
    Future<void> goToPage(WidgetTester tester, int index) async {
      await pumpFresh(tester);
      for (var i = 0; i < index; i++) {
        await next(tester);
      }
    }

    Finder inArt(Finder finder) =>
        find.descendant(of: find.byType(IntroArt), matching: finder);

    testWidgets('Nerede ne var: menünün simgeleri ve ne oldukları', (
      tester,
    ) async {
      await goToPage(tester, 2);
      for (final icon in [
        Icons.key_outlined,
        Icons.credit_card_outlined,
        Icons.sticky_note_2_outlined,
        Icons.shield_outlined,
        Icons.settings_outlined,
        Icons.add_rounded,
      ]) {
        expect(inArt(find.byIcon(icon)), findsWidgets);
      }
      // Sekme adları açıklamalardan büyük ve kalın.
      for (final name in [
        'Parolalar',
        'Kartlar',
        'Notlar',
        '2FA',
        'Ayarlar',
        'Ekle',
      ]) {
        final style = tester.widget<Text>(inArt(find.text(name))).style;
        expect(style?.fontSize, 18, reason: name);
        expect(style?.fontWeight, FontWeight.w800, reason: name);
      }
      for (final caption in [
        'Site ve uygulama girişlerin',
        'Banka kartların',
        'Güvenli notların',
        'Doğrulama kodların',
        'Yedek, doldurma ve tema',
        'Yeni parola, kart, not ya da 2FA kodu',
      ]) {
        expect(inArt(find.text(caption)), findsOneWidget);
      }
    });

    // Proje sahibinin isteği (2026-11-16): rozetlerin hepsi aynı, logo yok.
    testWidgets('Geçiş: uygulama adları aynı rozetlerde, logo yok', (
      tester,
    ) async {
      await goToPage(tester, 4);
      expect(inArt(find.byType(Image)), findsNothing);
      for (final name in [
        'Bitwarden',
        'Chrome',
        'Firefox',
        'KeePassXC',
        'Google Authenticator',
        'Aegis',
        '2FAS',
      ]) {
        expect(inArt(find.text(name)), findsOneWidget);
      }
    });

    testWidgets('Otomatik doldurma: örnek kullanıcı adı furkan.keykey', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpFresh(tester);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.widgetWithText(FilledButton, 'İleri'));
        await tester.pump();
        await tester.pump();
      }
      expect(inArt(find.text('furkan.keykey')), findsOneWidget);
    });

    testWidgets('animasyonlar kapalıyken çizimler hemen son hallerinde', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpFresh(tester);
      for (var page = 0; page < titles.length; page++) {
        // Sayfa geçişinin birkaç karesinden sonra hiçbir şey dönmüyor.
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(tester.binding.hasScheduledFrame, isFalse, reason: '$page');
        if (page < titles.length - 1) {
          await tester.tap(find.widgetWithText(FilledButton, 'İleri'));
          await tester.pump();
        }
      }
      // Son sayfanın çizimi gizli ya da yarım kalmamış.
      final opacities = tester.widgetList<Opacity>(inArt(find.byType(Opacity)));
      expect(opacities.every((o) => o.opacity == 1), isTrue);
    });

    testWidgets('%200 yazıda hiçbir sayfa taşmaz', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpFresh(tester);
      for (var page = 0; page < titles.length; page++) {
        expect(tester.takeException(), isNull, reason: '$page');
        if (page < titles.length - 1) await next(tester);
      }
    });
  });
}

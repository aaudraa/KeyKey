import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_section.dart';
import 'package:keykey/app/ui/kk_switch.dart';
import 'package:keykey/core/vault/biometric_bridge.dart';
import 'package:keykey/features/autofill/application/autofill_setup.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/presentation/settings_screen.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  const newPassword = 'yepyeni-Ana-Parola-58';

  late SodiumSumo sodium;
  late FakeVaultService service;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
  }

  Future<void> openChangePassword(WidgetTester tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Ana parolayı değiştir'));
    await tester.pumpAndSettle();
  }

  Future<void> submitChange(
    WidgetTester tester, {
    required String current,
    String next = newPassword,
  }) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), current);
    await tester.enterText(fields.at(1), next);
    await tester.enterText(fields.at(2), next);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Parolayı değiştir'));
    await tester.pumpAndSettle();
  }

  // Ayarlarda birden çok anahtar var, parmak izi anahtarı adıyla bulunur.
  final biometricSwitch = find.widgetWithText(KkSwitchTile, 'Parmak iziyle aç');

  group('düzen', () {
    // Telefon denemesi 5: başlık üst çubukta sabit, kaydırınca değişmez.
    testWidgets('başlık çubukta sabit durur', (tester) async {
      await pumpSettings(tester);
      final screen = find.byType(SettingsScreen);
      final bar = find.descendant(
        of: find.descendant(of: screen, matching: find.byType(AppBar)),
        matching: find.text('Ayarlar'),
      );
      expect(bar, findsOneWidget);
      final before = tester.getRect(bar);

      await tester.drag(
        find.descendant(of: screen, matching: find.byType(Scrollable)).first,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(bar), before);
    });

    testWidgets('ayarlar dört grup başlığını gösterir', (tester) async {
      await pumpSettings(tester);

      for (final title in [
        'Güvenlik',
        'Yedek ve aktarım',
        'Otomatik doldurma',
        'Hakkında',
      ]) {
        final header = find.text(title);
        await tester.scrollUntilVisible(header, 200);
        expect(header, findsOneWidget);
        expect(
          tester.getSemantics(header).flagsCollection.isHeader,
          isTrue,
          reason: title,
        );
      }
    });

    testWidgets('parmak izi satırında açıklama satırda değil, (i) ile '
        'açılan pencerede', (tester) async {
      service.biometricSupportValue = BiometricSupport.available;
      await pumpSettings(tester);
      const hint =
          'Telefona yeni parmak izi eklenirse bu kapanır ve ana parola '
          'istenir.';

      expect(find.text(hint), findsNothing);
      await tester.tap(
        find.descendant(
          of: biometricSwitch,
          matching: find.byTooltip('Açıklama'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(hint), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets("sürüm satırı sahte API'nin döndürdüğü sürümü gösterir", (
      tester,
    ) async {
      await pumpKeyKey(
        tester,
        status: VaultOpen(service.newSession()),
        service: service,
        packages: FakeAppPackages(version: '1.2.3'),
      );
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('1.2.3'), 200);
      expect(find.text('1.2.3'), findsOneWidget);
      expect(find.text('Sürüm'), findsOneWidget);
    });

    for (final (name, inset) in [
      ('hareketle gezinme', 24.0),
      ('üç düğmeli gezinme', 48.0),
    ]) {
      testWidgets('$name: son satır yüzen menünün üstünde kalıyor', (
        tester,
      ) async {
        // Android 15+ uygulamayı kenardan kenara çizer; sistem çubuğu kadar
        // boşluk alttan gelir.
        tester.view.padding = FakeViewPadding(
          bottom: inset * tester.view.devicePixelRatio,
        );
        addTearDown(tester.view.reset);
        await pumpSettings(tester);

        await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
        await tester.pumpAndSettle();

        final last = tester.getRect(
          find.ancestor(
            of: find.text('Lisanslar'),
            matching: find.byType(ListTile),
          ),
        );
        final pill = tester.getRect(find.byKey(GlassNavBar.pillKey));
        expect(last.bottom, lessThanOrEqualTo(pill.top));
      });
    }

    testWidgets('satırlarda simge kutusu, açılan satırlarda ok var', (
      tester,
    ) async {
      await pumpSettings(tester);
      Finder row(String text) =>
          find.ancestor(of: find.text(text), matching: find.byType(ListTile));
      for (final text in ['Ana parolayı değiştir', 'Şimdi kilitle']) {
        expect(
          find.descendant(of: row(text), matching: find.byType(KkIconBox)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(
        find.descendant(
          of: row('Ana parolayı değiştir'),
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('lisanslar sayfasının zemini saydam değil', (tester) async {
      await pumpSettings(tester);
      // Son satır; menünün altında kalmasın diye liste sonuna kaydırılır.
      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lisanslar'));
      await tester.pumpAndSettle();

      final page = find.byType(LicensePage);
      expect(page, findsOneWidget);
      final scaffold = find
          .descendant(of: page, matching: find.byType(Scaffold))
          .first;
      final background = Theme.of(tester.element(scaffold))
          .scaffoldBackgroundColor;
      expect(background.a, 1);
      // Kendi sayfası; alttaki menü görünmüyor.
      expect(find.byKey(GlassNavBar.pillKey), findsNothing);
    });

    testWidgets('satırlar aynı boyda', (tester) async {
      service.biometricSupportValue = BiometricSupport.available;
      await pumpSettings(tester);

      final heights = <double>{
        for (final text in [
          'Ana parolayı değiştir',
          'Parmak iziyle aç',
          'Şimdi kilitle',
        ])
          tester
              .getSize(
                find.ancestor(
                  of: find.text(text),
                  matching: find.byType(ListTile),
                ),
              )
              .height,
      };
      expect(heights, hasLength(1));
    });
  });

  group('parmak izi', () {
    testWidgets('cihazda yoksa ayar görünmüyor', (tester) async {
      service.biometricSupportValue = BiometricSupport.noHardware;
      await pumpSettings(tester);

      expect(find.text('Parmak iziyle aç'), findsNothing);
    });

    testWidgets('parmak izi kayıtlı değilse yönlendirme çıkıyor', (
      tester,
    ) async {
      service.biometricSupportValue = BiometricSupport.notEnrolled;
      await pumpSettings(tester);

      expect(find.textContaining('parmak izi ekle'), findsOneWidget);
      expect(biometricSwitch, findsNothing);
    });

    testWidgets('açılıp kapatılabiliyor', (tester) async {
      service
        ..biometricSupportValue = BiometricSupport.available
        ..nextBiometric = const BiometricSuccess(null);
      await pumpSettings(tester);

      await tester.tap(biometricSwitch);
      await tester.pumpAndSettle();
      expect(service.biometricEnabled, isTrue);
      expect(tester.widget<KkSwitchTile>(biometricSwitch).value, isTrue);

      await tester.tap(biometricSwitch);
      await tester.pumpAndSettle();
      expect(service.biometricEnabled, isFalse);
    });

    testWidgets('vazgeçilirse kapalı kalıyor', (tester) async {
      service.biometricSupportValue = BiometricSupport.available;
      await pumpSettings(tester);

      await tester.tap(biometricSwitch);
      await tester.pumpAndSettle();

      expect(service.biometricPrompts, 1);
      expect(tester.widget<KkSwitchTile>(biometricSwitch).value, isFalse);
    });

    testWidgets('etkinleşmezse mesaj çıkıyor', (tester) async {
      service
        ..biometricSupportValue = BiometricSupport.available
        ..nextBiometric = const BiometricFailed();
      await pumpSettings(tester);

      await tester.tap(biometricSwitch);
      await tester.pumpAndSettle();

      expect(
        find.text('Parmak iziyle açma etkinleştirilemedi.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('şimdi kilitle kasayı kilitliyor', (tester) async {
    await pumpSettings(tester);

    await tester.scrollUntilVisible(find.text('Şimdi kilitle'), 100);
    await tester.ensureVisible(find.text('Şimdi kilitle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Şimdi kilitle'));
    await tester.pumpAndSettle();

    expect(find.text('KeyKey kilitli'), findsOneWidget);
  });

  testWidgets('doğru mevcut parolayla parola değişiyor', (tester) async {
    await openChangePassword(tester);

    await submitChange(tester, current: FakeVaultService.correctPassword);

    expect(service.changedPassword, newPassword);
    expect(find.text('Ana parola değiştirildi.'), findsOneWidget);
    // Ayarlar ekranına dönüldü.
    expect(find.text('Ana parolayı değiştir'), findsOneWidget);
  });

  testWidgets('mevcut parola yanlışsa değişmiyor', (tester) async {
    await openChangePassword(tester);

    await submitChange(tester, current: 'yanlis-parola-99');

    expect(service.changedPassword, isNull);
    expect(find.text('Parola yanlış.'), findsOneWidget);
    expect(find.text('Ana parolayı değiştir'), findsOneWidget);
  });

  testWidgets('kısa yeni parolayla düğme kapalı', (tester) async {
    await openChangePassword(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), FakeVaultService.correctPassword);
    await tester.enterText(fields.at(1), 'kisa');
    await tester.enterText(fields.at(2), 'kisa');
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Parolayı değiştir'),
    );
    expect(button.onPressed, isNull);
  });

  group('otomatik doldurma kurulumu', () {
    Future<FakeAutofillSetup> pumpWith(
      WidgetTester tester,
      AutofillSetupState state,
    ) async {
      final setup = FakeAutofillSetup(state);
      await pumpKeyKey(
        tester,
        status: VaultOpen(service.newSession()),
        service: service,
        autofillSetup: setup,
      );
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      // Bölüm yedekleme girişlerinin altında; ekrana kaydırılır.
      await tester.scrollUntilVisible(find.text('Doldurma servisi'), 300);
      await tester.pumpAndSettle();
      return setup;
    }

    testWidgets('kapalıysa söylüyor ve sistem ayarını açıyor', (tester) async {
      final setup = await pumpWith(
        tester,
        const AutofillSetupState(supported: true, enabled: false),
      );

      expect(find.text("Kapalı. Dokun ve KeyKey'i seç."), findsOneWidget);
      expect(find.text("Chrome'da otomatik doldurma"), findsNothing);
      await tester.tap(find.text('Doldurma servisi'));
      await tester.pump();
      expect(setup.opened, ['autofill']);
    });

    testWidgets('KeyKey seçiliyse ve Chrome yeniyse Chrome bağlantısı var', (
      tester,
    ) async {
      final setup = await pumpWith(
        tester,
        const AutofillSetupState(
          supported: true,
          enabled: true,
          chromeMajorVersion: 145,
        ),
      );

      expect(find.text('KeyKey seçili.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text("Chrome'da otomatik doldurma"),
        100,
      );
      expect(find.textContaining('yeniden başlat'), findsOneWidget);
      await tester.tap(find.text("Chrome'da otomatik doldurma"));
      await tester.pump();
      expect(setup.opened, ['chrome']);
    });

    testWidgets('Chrome eskiyse güncellemesi söyleniyor, bağlantı yok', (
      tester,
    ) async {
      final setup = await pumpWith(
        tester,
        const AutofillSetupState(
          supported: true,
          enabled: true,
          chromeMajorVersion: 133,
        ),
      );

      await tester.scrollUntilVisible(
        find.textContaining("Chrome'u güncelle"),
        100,
      );
      expect(find.textContaining('sürüm 133'), findsOneWidget);
      await tester.tap(find.text("Chrome'da otomatik doldurma"));
      await tester.pump();
      expect(setup.opened, isEmpty);
    });

    testWidgets('ayar açılamazsa söylüyor', (tester) async {
      final setup = FakeAutofillSetup()..canOpen = false;
      await pumpKeyKey(
        tester,
        status: VaultOpen(service.newSession()),
        service: service,
        autofillSetup: setup,
      );
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Doldurma servisi'), 300);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Doldurma servisi'));
      await tester.pump();
      expect(find.text('Ayar açılamadı.'), findsOneWidget);
    });

    testWidgets('desteklenmiyorsa bunu söylüyor', (tester) async {
      await pumpWith(
        tester,
        const AutofillSetupState(supported: false, enabled: false),
      );

      expect(
        find.text('Bu cihaz otomatik doldurmayı desteklemiyor.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('2FA kodu kopyalama ayarı kapatılıp açılabiliyor', (
    tester,
  ) async {
    final settings = FakeSettingsRepository();
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      settings: settings,
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    final copySwitch = find.widgetWithText(
      KkSwitchTile,
      'Doldurduktan sonra 2FA kodunu kopyala',
    );
    await tester.scrollUntilVisible(copySwitch, 100);
    await tester.ensureVisible(copySwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<KkSwitchTile>(copySwitch).value, isTrue);
    await tester.tap(copySwitch);
    await tester.pumpAndSettle();
    expect(settings.settings.autofillCopyOtp, isFalse);
    expect(tester.widget<KkSwitchTile>(copySwitch).value, isFalse);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/vault/biometric_bridge.dart';
import 'package:keykey/features/autofill/application/autofill_setup.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
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
  final biometricSwitch = find.widgetWithText(
    SwitchListTile,
    'Parmak iziyle aç',
  );

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
      expect(tester.widget<SwitchListTile>(biometricSwitch).value, isTrue);

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
      expect(tester.widget<SwitchListTile>(biometricSwitch).value, isFalse);
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
    expect(find.text('Şimdi kilitle'), findsOneWidget);
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
      return setup;
    }

    testWidgets('kapalıysa söylüyor ve sistem ayarını açıyor', (tester) async {
      final setup = await pumpWith(
        tester,
        const AutofillSetupState(supported: true, enabled: false),
      );

      expect(find.text("Kapalı. Dokun ve KeyKey'i seç."), findsOneWidget);
      expect(find.text("Chrome'da otomatik doldurma"), findsNothing);
      await tester.tap(find.text('Otomatik doldurma'));
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

      await tester.tap(find.text('Otomatik doldurma'));
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
      SwitchListTile,
      'Doldurduktan sonra 2FA kodunu kopyala',
    );
    await tester.scrollUntilVisible(copySwitch, 100);
    expect(tester.widget<SwitchListTile>(copySwitch).value, isTrue);
    await tester.tap(copySwitch);
    await tester.pumpAndSettle();
    expect(settings.settings.autofillCopyOtp, isFalse);
    expect(tester.widget<SwitchListTile>(copySwitch).value, isFalse);
  });
}

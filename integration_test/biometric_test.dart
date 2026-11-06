import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/app/app.dart';
import 'package:keykey/core/platform/pigeon_biometric_bridge.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/biometric_bridge.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium_sumo.dart';

/// Gerçek Keystore ve gerçek parmak izi penceresiyle çalışır.
///
/// Parmak izini `resources/scripts/biometric-device-test.sh` dokundurur, tek
/// başına çalıştırılırsa pencerede bekleyip zaman aşımına düşer.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'dogru-Ana-Parola-47';
  const texts = BiometricTexts(title: 'KeyKey testi', negativeButton: 'Vazgeç');
  const vaultText = "Henüz parola yok. İlkini kaydetmek için Ekle'ye dokun.";
  const testTimeout = Timeout(Duration(minutes: 3));

  // Betik olmadan pencerede boşuna beklememek için yalnızca betikle çalışır.
  const skip = !bool.fromEnvironment('KK_BIOMETRIC');

  late SodiumSumo sodium;
  late Directory support;
  late Directory directory;
  late VaultDatabase database;
  late VaultStore store;
  late VaultService service;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    support = await getApplicationSupportDirectory();
  });

  setUp(() {
    directory = support.createTempSync('parmak_izi_');
    database = VaultDatabase.openFile(File('${directory.path}/keykey.db'));
    store = VaultStore(database);
    service = VaultService(
      sodium: sodium,
      store: store,
      biometric: PigeonBiometricBridge(),
    );
  });

  tearDown(() async {
    await database.close();
    directory.deleteSync(recursive: true);
  });

  Future<VaultSession> createVault() async {
    final pending = await service.prepareVault(password);
    return await service.confirmRecoveryKey(pending, pending.recoveryKeyText);
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition,
    String what,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (DateTime.now().isBefore(deadline)) {
      await tester
          .pump(const Duration(milliseconds: 200))
          .timeout(const Duration(seconds: 10));
      if (condition()) return;
    }
    final visible = find
        .byType(Text)
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .join(' / ');
    fail('Olmadı: $what | Ekranda: $visible');
  }

  testWidgets(
    'Keystore kasa anahtarını sarıyor ve açıyor',
    (tester) async {
      expect(await service.biometricSupport(), BiometricSupport.available);
      final session = await createVault();
      addTearDown(session.dispose);
      final recordId = sodium.randombytes.buf(16);
      final plain = Uint8List.fromList(utf8.encode('gizli içerik'));
      final blob = session.records.encrypt(
        recordId: recordId,
        type: 'login',
        plainText: plain,
      );

      final enabled = await service.enableBiometric(session, texts);
      expect(enabled, isA<BiometricSuccess<void>>());

      final slot = await store.readBiometricSlot();
      expect(slot!.iv, hasLength(12));
      expect(slot.cipherText, hasLength(48));
      final key = session.vaultKey.extractBytes();
      addTearDown(() => key.fillRange(0, key.length, 0));
      expect(slot.cipherText.sublist(0, 32), isNot(key));

      final outcome = await service.unlockWithBiometric(session.header, texts);
      final opened = (outcome as BiometricSuccess<VaultSession>).value;
      addTearDown(opened.dispose);
      expect(opened.vaultKey.extractBytes(), key);
      expect(
        opened.records.decrypt(recordId: recordId, type: 'login', blob: blob),
        plain,
      );

      await service.disableBiometric();
      expect(await service.isBiometricEnabled(), isFalse);
    },
    timeout: testTimeout,
    skip: skip,
  );

  testWidgets(
    'değiştirilmiş yuva açılmıyor',
    (tester) async {
      final session = await createVault();
      addTearDown(session.dispose);
      await service.enableBiometric(session, texts);
      final slot = (await store.readBiometricSlot())!;

      final tampered = Uint8List.fromList(slot.cipherText);
      tampered[0] ^= 1;
      await store.writeBiometricSlot(
        StoredBiometricSlot(iv: slot.iv, cipherText: tampered),
      );

      final outcome = await service.unlockWithBiometric(session.header, texts);
      expect(outcome, isA<BiometricFailed<VaultSession>>());
      expect(await service.isBiometricEnabled(), isTrue);

      await service.disableBiometric();
    },
    timeout: testTimeout,
    skip: skip,
  );

  testWidgets(
    'ayarlardan açılıyor, kilit ekranı parmak iziyle açılıyor',
    (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('tr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final session = await createVault();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultServiceProvider.overrideWithValue(service),
            loginRepositoryFactoryProvider.overrideWithValue(
              (session) => LoginRepository(
                store: store,
                session: session,
                sodium: sodium,
              ),
            ),
            settingsRepositoryFactoryProvider.overrideWithValue(
              (session) => SettingsRepository(store: store, session: session),
            ),
            otpRepositoryFactoryProvider.overrideWithValue(
              (session) =>
                  OtpRepository(store: store, session: session, sodium: sodium),
            ),
            initialVaultStatusProvider.overrideWithValue(VaultOpen(session)),
          ],
          child: const KeyKeyApp(),
        ),
      );
      await pumpUntil(
        tester,
        () => find.text(vaultText).evaluate().isNotEmpty,
        'kasa ekranı',
      );

      await tester.tap(find.byIcon(Icons.settings_outlined));
      // Ayarlarda birden çok anahtar var, parmak izi anahtarı adıyla bulunur.
      final biometricSwitch = find.widgetWithText(
        SwitchListTile,
        'Parmak iziyle aç',
      );
      await pumpUntil(
        tester,
        () => biometricSwitch.evaluate().isNotEmpty,
        'parmak izi ayarı',
      );
      await tester.tap(biometricSwitch);
      await tester.pump();

      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (!await service.isBiometricEnabled()) {
        if (DateTime.now().isAfter(deadline)) fail('Yuva yazılmadı');
        await tester
            .pump(const Duration(milliseconds: 200))
            .timeout(const Duration(seconds: 10));
      }
      expect(
        session.isDisposed,
        isFalse,
        reason: 'Pencere kasayı kilitlememeli',
      );
      await tester.pump(const Duration(seconds: 1));

      // Ek onay açıkken 2FA kodları parmak iziyle açılıyor. Doğrulama
      // Keystore anahtarının kasa anahtarını açmasıyla yapılır.
      await OtpRepository(store: store, session: session, sodium: sodium).add(
        OtpContent(
          parameters: OtpParameters.totp(
            secret: utf8.encode('parmak-anahtari'),
          ),
          issuer: 'Parmak hesabı',
        ),
      );
      await tester.tap(find.text('2FA kodlarını göstermeden önce doğrula'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(_otpTab());
      await pumpUntil(
        tester,
        () => find.text('Kodlar gizli').evaluate().isNotEmpty,
        'gizli kodlar',
      );
      await tester.tap(find.text('Kodları göster'));
      await tester.pump();
      // Betik parmağı dokundurur.
      await pumpUntil(
        tester,
        () => find.text('Parmak hesabı').evaluate().isNotEmpty,
        'parmak iziyle açılan kodlar',
      );
      expect(session.isDisposed, isFalse, reason: 'Kasa açık kalmalı');
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Şimdi kilitle'));
      await tester.pump();
      expect(session.isDisposed, isTrue);

      // Kilit ekranı pencereyi kendiliğinden açar, betik parmağı dokundurur.
      await pumpUntil(
        tester,
        () => find.text(vaultText).evaluate().isNotEmpty,
        'parmak iziyle açılan kasa',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await service.disableBiometric();
    },
    timeout: testTimeout,
    skip: skip,
  );

  testWidgets(
    'yeni parmak izi eklenince anahtar geçersiz oluyor',
    (tester) async {
      final session = await createVault();
      addTearDown(session.dispose);
      await service.enableBiometric(session, texts);
      expect(await service.isBiometricEnabled(), isTrue);

      // Betik bu satırı görünce ayarlardan ikinci parmak izini kaydeder.
      final signal = File('${support.path}/kk_parmak_eklendi');
      if (signal.existsSync()) signal.deleteSync();
      // Betik standart çıktıdan okuyor.
      // ignore: avoid_print
      print('KKPARMAK_EKLE');
      final deadline = DateTime.now().add(const Duration(seconds: 120));
      while (!signal.existsSync()) {
        if (DateTime.now().isAfter(deadline)) {
          fail('İkinci parmak izi eklenmedi');
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }

      final outcome = await service.unlockWithBiometric(session.header, texts);
      expect(outcome, isA<BiometricInvalidated<VaultSession>>());
      expect(await service.isBiometricEnabled(), isFalse);

      final byPassword = await service.unlockWithPassword(
        session.header,
        password,
      );
      addTearDown(byPassword.session!.dispose);
      expect(byPassword.attempt, isA<PasswordAccepted>());

      // Yeni anahtarla yeniden etkinleştirilebiliyor.
      final again = await service.enableBiometric(session, texts);
      expect(again, isA<BiometricSuccess<void>>());
      final reopened = await service.unlockWithBiometric(session.header, texts);
      addTearDown((reopened as BiometricSuccess<VaultSession>).value.dispose);

      await service.disableBiometric();
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: skip,
  );
}

/// Alt çubuktaki 2FA sekmesi. Ayarlardaki ek onay satırı da aynı simgeyi
/// kullandığı için yalnızca simgeyle aramak iki sonuç verir.
Finder _otpTab() => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.byIcon(Icons.shield_outlined),
);

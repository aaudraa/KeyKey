import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/app/app.dart';
import 'package:keykey/core/platform/sensitive_clipboard.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/features/authenticator/application/otp_generator.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/authenticator/presentation/otp_display.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium_sumo.dart';

/// 2FA'yı gerçek şifreleme, gerçek dosya ve gerçek panoyla uçtan uca sınar.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'yeşil-Fener-83-Liman';
  const secretText = 'JBSWY3DPEHPK3PXP';
  final secret = Base32.decodeCanonical(secretText);

  /// Argon2id ayrı isolate'te çalışıyor ve geri sayım her karede kare
  /// istiyor; `pumpAndSettle` ikisinde de işe yaramaz.
  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      await tester
          .pump(const Duration(milliseconds: 100))
          .timeout(const Duration(seconds: 10));
      if (finder.evaluate().isNotEmpty) return;
    }
    final visible = find
        .byType(Text)
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .join(' / ');
    fail('Bulunamadı: $finder | Ekranda: $visible');
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text);
    await tester.ensureVisible(target.first);
    await tester.pump();
    await tester.tap(target.first);
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Şu anki, bir önceki ve bir sonraki sürenin kodları; ölçüm sırasında
  /// süre dolabilir.
  Set<String> currentCodes() {
    final now = DateTime.now();
    return {
      for (final offset in [-30, 0, 30])
        OtpGenerator.totp(
          secret: secret,
          time: now.add(Duration(seconds: offset)),
        ),
    };
  }

  Finder anyCurrentCode() => find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        currentCodes().map(formatOtpCode).contains(widget.data),
  );

  Future<void> lockAndUnlock(WidgetTester tester) async {
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpUntilFound(tester, find.text('KeyKey kilitli'));
    await tester.enterText(find.byType(TextField), password);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Aç'));
    await pumpUntilFound(tester, find.byIcon(Icons.shield_outlined));
  }

  testWidgets('2FA hesabının yaşam döngüsü', (tester) async {
    tester.platformDispatcher.localesTestValue = [const Locale('tr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final support = await getApplicationSupportDirectory();
    final directory = support.createTempSync('2fa_akisi_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final database = VaultDatabase.openFile(
      File('${directory.path}/keykey.db'),
    );
    addTearDown(database.close);
    final store = VaultStore(database);
    final sodium = await SodiumSumoInit.init();
    final service = VaultService(sodium: sodium, store: store);
    final pending = await service.prepareVault(password);
    final session = await service.confirmRecoveryKey(
      pending,
      pending.recoveryKeyText,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultServiceProvider.overrideWithValue(service),
          sensitiveClipboardProvider.overrideWithValue(
            PigeonSensitiveClipboard(),
          ),
          loginRepositoryFactoryProvider.overrideWithValue(
            (session) =>
                LoginRepository(store: store, session: session, sodium: sodium),
          ),
          otpRepositoryFactoryProvider.overrideWithValue(
            (session) =>
                OtpRepository(store: store, session: session, sodium: sodium),
          ),
          settingsRepositoryFactoryProvider.overrideWithValue(
            (session) => SettingsRepository(store: store, session: session),
          ),
          initialVaultStatusProvider.overrideWithValue(VaultOpen(session)),
        ],
        child: const KeyKeyApp(),
      ),
    );
    await pumpUntilFound(tester, find.byIcon(Icons.shield_outlined));

    debugPrint('KKADIM Hesap elle ekleniyor.');
    await tester.tap(_otpTab());
    await pumpUntilFound(tester, find.textContaining('Henüz 2FA hesabı yok'));
    await tapText(tester, 'Ekle');
    await pumpUntilFound(tester, find.text('Anahtarı elle gir'));
    await tapText(tester, 'Anahtarı elle gir');
    await pumpUntilFound(tester, find.text('Yeni 2FA hesabı'));
    await tester.enterText(find.widgetWithText(TextField, 'Servis'), 'Deneme');
    await tester.enterText(
      find.widgetWithText(TextField, 'Gizli anahtar'),
      secretText.toLowerCase(),
    );
    await tester.pump();
    await tapText(tester, 'Kaydet');
    await pumpUntilFound(tester, find.text('Deneme'));

    debugPrint('KKADIM Kod motorla eşleşiyor ve kopyalanıyor.');
    await pumpUntilFound(tester, anyCurrentCode());
    await tester.tap(anyCurrentCode());
    await tester.pump(const Duration(milliseconds: 500));
    final copied = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    expect(currentCodes(), contains(copied));

    debugPrint('KKADIM Kilitleyip açınca hesap duruyor.');
    await lockAndUnlock(tester);
    await tester.tap(_otpTab());
    await pumpUntilFound(tester, find.text('Deneme'));
    await pumpUntilFound(tester, anyCurrentCode());

    debugPrint('KKADIM Ek onay ana parolayla açılıyor.');
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await pumpUntilFound(
      tester,
      find.text('2FA kodlarını göstermeden önce doğrula'),
    );
    await tapText(tester, '2FA kodlarını göstermeden önce doğrula');
    await tester.tap(_otpTab());
    await pumpUntilFound(tester, find.text('Kodlar gizli'));
    expect(anyCurrentCode(), findsNothing);
    await tapText(tester, 'Kodları göster');
    await pumpUntilFound(tester, find.byType(AlertDialog));
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      password,
    );
    await tester.pump();
    await tapText(tester, 'Doğrula');
    await pumpUntilFound(tester, anyCurrentCode());

    debugPrint('KKADIM Kilitten sonra kodlar yeniden gizli.');
    await lockAndUnlock(tester);
    await tester.tap(_otpTab());
    await pumpUntilFound(tester, find.text('Kodlar gizli'));
    expect(anyCurrentCode(), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

/// Alt çubuktaki 2FA sekmesi. Ayarlardaki ek onay satırı da aynı simgeyi
/// kullandığı için yalnızca simgeyle aramak iki sonuç verir.
Finder _otpTab() => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.byIcon(Icons.shield_outlined),
);

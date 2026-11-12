import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/app/app.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium_sumo.dart';

/// Gerçek şifreleme ve gerçek dosyayla, kullanıcının yaptığı gibi uçtan uca.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const firstPassword = 'kırmızı-Bisiklet-47-Deniz';
  const secondPassword = 'mavi-Tren-58-Orman-Yolu';
  const thirdPassword = 'sarı-Kalem-69-Dağ-Evi';
  const vaultText = "Henüz parola yok. İlkini kaydetmek için Ekle'ye dokun.";
  const lockedTitle = 'KeyKey kilitli';

  /// Argon2id ayrı isolate'te çalıştığı için `pumpAndSettle` beklemez.
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

  /// Ayarlar listesi uzun ve tembel kurulur; kilit düğmesi aşağıdadır.
  Future<void> tapLockNow(WidgetTester tester) async {
    final lockNow = find.text('Şimdi kilitle');
    await tester.scrollUntilVisible(
      lockNow,
      300,
      scrollable: find
          .ancestor(
            of: find.text('Ana parolayı değiştir'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    // Öğe alt çubuğun altında kalmasın.
    await tester.ensureVisible(lockNow);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(lockNow);
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final button = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
  }

  Future<void> background(WidgetTester tester) async {
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump().timeout(const Duration(seconds: 10));
  }

  Future<void> unlock(
    WidgetTester tester,
    String password, {
    required Finder expecting,
  }) async {
    await tester.enterText(find.byType(TextField), password);
    await tester.pump();
    await tapButton(tester, 'Aç');
    await pumpUntilFound(tester, expecting);
  }

  testWidgets('kasanın tüm yaşam döngüsü', (tester) async {
    tester.platformDispatcher.localesTestValue = [const Locale('tr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final support = await getApplicationSupportDirectory();
    final directory = support.createTempSync('kasa_akisi_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/keykey.db');
    final sodium = await SodiumSumoInit.init();

    Future<(VaultDatabase, ProviderScope)> openApp() async {
      final database = VaultDatabase.openFile(file);
      final service = VaultService(sodium: sodium, store: VaultStore(database));
      final header = await service.readHeader();
      return (
        database,
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            ambientMotionProvider.overrideWithValue(false),
            vaultServiceProvider.overrideWithValue(service),
            settingsRepositoryFactoryProvider.overrideWithValue(
              (session) => SettingsRepository(
                store: VaultStore(database),
                session: session,
              ),
            ),
            otpRepositoryFactoryProvider.overrideWithValue(
              (session) => OtpRepository(
                store: VaultStore(database),
                session: session,
                sodium: sodium,
              ),
            ),
            loginRepositoryFactoryProvider.overrideWithValue(
              (session) => LoginRepository(
                store: VaultStore(database),
                session: session,
                sodium: sodium,
              ),
            ),
            initialVaultStatusProvider.overrideWithValue(
              header == null ? const VaultNotSetUp() : VaultLocked(header),
            ),
          ],
          child: const KeyKeyApp(),
        ),
      );
    }

    // Kasa oluşturma.
    debugPrint('KKADIM Kasa oluşturma.');
    var (database, app) = await openApp();
    addTearDown(() => database.close());
    await tester.pumpWidget(app);
    await pumpUntilFound(tester, find.text('Kasa oluştur'));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), firstPassword);
    await tester.enterText(fields.at(1), firstPassword);
    await tester.pump();
    await tapButton(tester, 'Kasayı oluştur');

    final recoveryKeyFinder = find.byWidgetPredicate(
      (widget) => widget is Text && widget.style?.fontFamily == 'monospace',
    );
    await pumpUntilFound(tester, recoveryKeyFinder);
    final recoveryKey = tester.widget<Text>(recoveryKeyFinder).data!;
    expect(recoveryKey.replaceAll('-', '').length, 55);

    // Doğrulanmadan önce dosyada kasa yok.
    debugPrint('KKADIM Doğrulanmadan önce dosyada kasa yok.');
    expect(
      await VaultStore(database).readHeader(),
      isNull,
      reason: 'Kurtarma anahtarı doğrulanmadan kasa diske yazılmamalı',
    );

    await tapButton(tester, 'Yazdım');
    await pumpUntilFound(tester, find.text('Doğrula ve kasayı aç'));
    await tester.enterText(find.byType(TextField), recoveryKey);
    await tester.pump();
    await tapButton(tester, 'Doğrula ve kasayı aç');
    await pumpUntilFound(tester, find.text(vaultText));
    expect(await VaultStore(database).readHeader(), isNotNull);

    // Arka plana geçince kilitleniyor, yanlış parola içeri almıyor.
    debugPrint(
      'KKADIM Arka plana geçince kilitleniyor, yanlış parola içeri almıyor.',
    );
    await background(tester);
    await pumpUntilFound(tester, find.text(lockedTitle));
    expect(find.text(vaultText), findsNothing);

    await unlock(
      tester,
      'bu-yanlis-bir-parola-99',
      expecting: find.text('Parola yanlış.'),
    );
    expect(find.text(vaultText), findsNothing);
    await unlock(tester, firstPassword, expecting: find.text(vaultText));

    // Parola değiştirme.
    debugPrint('KKADIM Parola değiştirme.');
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await pumpUntilFound(tester, find.text('Ana parolayı değiştir'));
    await tester.tap(find.text('Ana parolayı değiştir'));
    await pumpUntilFound(tester, find.text('Mevcut ana parola'));
    final changeFields = find.byType(TextField);
    await tester.enterText(changeFields.at(0), firstPassword);
    await tester.enterText(changeFields.at(1), secondPassword);
    await tester.enterText(changeFields.at(2), secondPassword);
    await tester.pump();
    await tapButton(tester, 'Parolayı değiştir');
    // Ekranın başlığı da "Ana parolayı değiştir"; Argon2id bitene kadar
    // onay mesajı beklenir.
    await pumpUntilFound(tester, find.text('Ana parola değiştirildi.'));
    await pumpUntilFound(tester, find.text('Ana parolayı değiştir'));

    // Eski parola artık çalışmıyor, yenisi çalışıyor.
    debugPrint('KKADIM Eski parola artık çalışmıyor, yenisi çalışıyor.');
    await tapLockNow(tester);
    await pumpUntilFound(tester, find.text(lockedTitle));
    await unlock(tester, firstPassword, expecting: find.text('Parola yanlış.'));
    await unlock(tester, secondPassword, expecting: find.text(vaultText));

    // Parola unutuldu: kurtarma anahtarıyla yeni parola.
    debugPrint('KKADIM Parola unutuldu: kurtarma anahtarıyla yeni parola.');
    await background(tester);
    await pumpUntilFound(tester, find.text(lockedTitle));
    await tester.tap(find.text('Parolamı unuttum'));
    await pumpUntilFound(tester, find.text('Devam et'));
    await tester.enterText(find.byType(TextField), recoveryKey);
    await tester.pump();
    await tapButton(tester, 'Devam et');
    await pumpUntilFound(tester, find.text('Kaydet ve kasayı aç'));
    expect(find.text(vaultText), findsNothing);
    final newFields = find.byType(TextField);
    await tester.enterText(newFields.at(0), thirdPassword);
    await tester.enterText(newFields.at(1), thirdPassword);
    await tester.pump();
    await tapButton(tester, 'Kaydet ve kasayı aç');
    await pumpUntilFound(tester, find.text(vaultText));

    // Uygulama yeniden başlıyor: kasa kilitli açılıyor, son parola geçerli.
    debugPrint(
      'KKADIM Uygulama yeniden başlıyor: kasa kilitli, son parola geçerli.',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await database.close();

    (database, app) = await openApp();
    addTearDown(() => database.close());
    await tester.pumpWidget(app);
    await pumpUntilFound(tester, find.text(lockedTitle));
    expect(find.text(vaultText), findsNothing);
    await unlock(tester, thirdPassword, expecting: find.text(vaultText));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }, timeout: const Timeout(Duration(minutes: 4)));
}

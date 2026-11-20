import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/app/app.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/core/platform/sensitive_clipboard.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/backup/application/backup_service.dart';
import 'package:keykey/features/backup/application/restore_service.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/application/records_controller.dart';
import 'package:keykey/features/vault/data/card_number.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/data/vault_record_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium_sumo.dart';

/// Kart ve güvenli notu gerçek şifreleme, gerçek dosya ve gerçek panoyla,
/// kullanıcının yaptığı gibi ekler; sonra yedekten başka bir kasaya alır.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'yeşil-Kart-82-Not-Defteri';

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester
          .pump(const Duration(milliseconds: 100))
          .timeout(const Duration(seconds: 10));
    }
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      await tester
          .pump(const Duration(milliseconds: 100))
          .timeout(const Duration(seconds: 10));
      if (finder.evaluate().isNotEmpty) {
        await settle(tester);
        return;
      }
    }
    final visible = find
        .byType(Text)
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .join(' / ');
    fail('Bulunamadı: $finder | Ekranda: $visible');
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await settle(tester);
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> save(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Kaydet');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    // Kaydetme onay işaretini çizip formu kapatır.
    await pumpUntilFound(tester, find.byKey(GlassNavBar.addKey));
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  testWidgets('kart ve not eklenir, çöpten döner, yedekle taşınır', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = [const Locale('tr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final support = await getApplicationSupportDirectory();
    final directory = support.createTempSync('kart_not_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final sodium = await SodiumSumoInit.init();

    final database = VaultDatabase.openFile(File('${directory.path}/a.db'));
    addTearDown(database.close);
    final store = VaultStore(database);
    final service = VaultService(sodium: sodium, store: store);
    final pending = await service.prepareVault(password);
    final session = await service.confirmRecoveryKey(
      pending,
      pending.recoveryKeyText,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ambientMotionProvider.overrideWithValue(false),
          vaultServiceProvider.overrideWithValue(service),
          settingsRepositoryFactoryProvider.overrideWithValue(
            (session) => SettingsRepository(store: store, session: session),
          ),
          loginRepositoryFactoryProvider.overrideWithValue(
            (session) =>
                LoginRepository(store: store, session: session, sodium: sodium),
          ),
          otpRepositoryFactoryProvider.overrideWithValue(
            (session) =>
                OtpRepository(store: store, session: session, sodium: sodium),
          ),
          cardRepositoryFactoryProvider.overrideWithValue(
            (session) =>
                cardRepository(store: store, session: session, sodium: sodium),
          ),
          noteRepositoryFactoryProvider.overrideWithValue(
            (session) =>
                noteRepository(store: store, session: session, sodium: sodium),
          ),
          sensitiveClipboardProvider.overrideWithValue(
            PigeonSensitiveClipboard(),
          ),
          initialVaultStatusProvider.overrideWithValue(VaultOpen(session)),
        ],
        child: const KeyKeyApp(),
      ),
    );
    await pumpUntilFound(tester, find.byKey(GlassNavBar.addKey));

    // Kart ekleme: numara boşluk ve tireyle yapıştırılmış gibi.
    debugPrint('KKADIM Kart ekleme.');
    await tester.tap(find.byKey(GlassNavBar.addKey));
    await pumpUntilFound(tester, find.text('Kart'));
    await tapText(tester, 'Kart');
    await pumpUntilFound(tester, field('Kart numarası'));
    await tester.enterText(field('Ad'), 'Maaş kartı');
    await tester.enterText(field('Kart numarası'), '4111-1111 1111 1111');
    await tester.enterText(field('Son kullanma (AA/YY)'), '0930');
    await tester.enterText(field('Güvenlik kodu'), '987');
    await tester.pump();
    await save(tester);

    // Listede yalnızca son dört hane.
    debugPrint('KKADIM Listede son dört hane.');
    await pumpUntilFound(tester, find.text('Visa •••• 1111 · 09/30'));
    expect(find.textContaining('4111 1111'), findsNothing);

    // Ayrıntıda numarayı kopyala: gerçek panoya gruplanmadan gider.
    debugPrint('KKADIM Ayrıntıda numarayı kopyala.');
    await tapText(tester, 'Maaş kartı');
    final copyNumber = find.byTooltip('Kopyala: Kart numarası');
    await pumpUntilFound(tester, copyNumber);
    await tester.ensureVisible(copyNumber);
    await tester.pump();
    await tester.tap(copyNumber);
    await settle(tester);
    expect(
      (await Clipboard.getData(Clipboard.kTextPlain))?.text,
      '4111111111111111',
    );
    await back(tester);

    // Not ekleme.
    debugPrint('KKADIM Not ekleme.');
    await tester.tap(find.byKey(GlassNavBar.addKey));
    await pumpUntilFound(tester, find.text('Güvenli not'));
    await tapText(tester, 'Güvenli not');
    await pumpUntilFound(tester, field('Metin'));
    await tester.enterText(field('Ad'), 'Ev Wi-Fi');
    await tester.enterText(field('Metin'), 'ağ: Ev\nparola: kirmizi-kapi');
    await tester.pump();
    await save(tester);
    // Not, Notlar sekmesinde açıldı; kart orada görünmez.
    await pumpUntilFound(tester, find.text('Ev Wi-Fi'));
    expect(find.textContaining('kirmizi-kapi'), findsNothing);
    expect(find.text('Maaş kartı'), findsNothing);

    // Her biri kendi sekmesinde çöpe atılır, kendi çöp kutusundan geri
    // alınır.
    debugPrint('KKADIM Çöpe at ve geri al.');
    for (final (icon, name) in [
      (Icons.sticky_note_2_outlined, 'Ev Wi-Fi'),
      (Icons.credit_card_outlined, 'Maaş kartı'),
    ]) {
      await tester.tap(find.byIcon(icon));
      await pumpUntilFound(tester, find.text(name));
      await tapText(tester, name);
      await pumpUntilFound(tester, find.byTooltip('Diğer işlemler'));
      await tester.tap(find.byTooltip('Diğer işlemler'));
      await pumpUntilFound(tester, find.text('Çöp kutusuna taşı'));
      await tapText(tester, 'Çöp kutusuna taşı');
      await pumpUntilFound(tester, find.byKey(GlassNavBar.addKey));
      expect(find.text(name), findsNothing);
    }

    // Kartlar sekmesindeyiz; önce Notlar'a geçilir ki dokunulan simge
    // seçili olmayan sekmenin simgesi olsun.
    for (final (icon, name, other) in [
      (Icons.sticky_note_2_outlined, 'Ev Wi-Fi', 'Maaş kartı'),
      (Icons.credit_card_outlined, 'Maaş kartı', 'Ev Wi-Fi'),
    ]) {
      await tester.tap(find.byIcon(icon));
      await pumpUntilFound(tester, find.byTooltip('Diğer işlemler'));
      await tester.tap(find.byTooltip('Diğer işlemler'));
      await pumpUntilFound(tester, find.text('Çöp kutusu'));
      await tapText(tester, 'Çöp kutusu');
      await pumpUntilFound(tester, find.text(name));
      expect(find.text(other), findsNothing);
      await tester.tap(find.byTooltip('Diğer işlemler'));
      await pumpUntilFound(tester, find.text('Tümünü geri yükle'));
      await tapText(tester, 'Tümünü geri yükle');
      await pumpUntilFound(tester, find.text('Çöp kutusu boş.'));
      await back(tester);
      await pumpUntilFound(tester, find.text(name));
    }

    // Yedek al, yeni bir kasaya kur, kart ve not oradan okunur.
    debugPrint('KKADIM Yedekten yeni kasaya.');
    final bytes = await BackupService(
      sodium: sodium,
      store: store,
    ).create(session, DateTime.now());
    final targetDb = VaultDatabase.openFile(File('${directory.path}/b.db'));
    addTearDown(targetDb.close);
    final target = VaultStore(targetDb);
    final restore = RestoreService(sodium: sodium, store: target);
    final opened = await restore.openWithPassword(
      restore.parse(bytes),
      password,
    );
    expect(opened.cardCount, 1);
    expect(opened.noteCount, 1);
    await restore.replace(opened);
    opened.dispose();

    final targetService = VaultService(sodium: sodium, store: target);
    final header = (await targetService.readHeader())!;
    final restored = (await targetService.unlockWithPassword(
      header,
      password,
    )).session!;
    addTearDown(restored.dispose);
    final cards = await cardRepository(
      store: target,
      session: restored,
      sodium: sodium,
    ).loadAll();
    final notes = await noteRepository(
      store: target,
      session: restored,
      sodium: sodium,
    ).loadAll();
    final card = cards.items.single.content;
    expect(card.name, 'Maaş kartı');
    expect(card.number, '4111111111111111');
    expect(card.expiry, CardExpiry(month: 9, year: 2030));
    expect(card.securityCode, '987');
    expect(card.isTrashed, isFalse);
    final note = notes.items.single.content;
    expect(note.name, 'Ev Wi-Fi');
    expect(note.text, 'ağ: Ev\nparola: kirmizi-kapi');
    expect(cards.unreadableCount + notes.unreadableCount, 0);
  });
}

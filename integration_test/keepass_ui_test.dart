import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/app/app.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/backup/data/import/kdbx/platform_kdbx_kdf.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/application/records_controller.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/data/vault_record_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium_sumo.dart';

import 'kdbx_fixtures.dart';

/// Sistemin dosya seçicisi Flutter testinden sürülemez; yalnızca o
/// taklit edilir. Seçilen dosyanın baytları gerçek seçicideki gibi yeni
/// bir listedir.
class _PickedFile implements DocumentFiles {
  new(this.bytes);

  final Uint8List bytes;
  Uint8List? lastGiven;

  @override
  Future<DocumentOpenResult> open({
    required List<String> mimeTypes,
    required int maxBytes,
  }) async {
    lastGiven = Uint8List.fromList(bytes);
    return DocumentOpened(lastGiven!);
  }

  @override
  Future<DocumentSaveResult> save({
    required String suggestedName,
    required String mimeType,
    required Uint8List bytes,
  }) async => DocumentSaveResult.cancelled;
}

/// KeePass dosyasını kullanıcının yolundan açar: Ayarlar → İçe aktar →
/// yanlış parola → doğru parola → önizleme → ekle. Kasa, şifreleme ve
/// anahtar türetme (Kotlin ve C) gerçek.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester
          .pump(const Duration(milliseconds: 100))
          .timeout(const Duration(seconds: 10));
    }
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    final deadline = DateTime.now().add(const Duration(seconds: 60));
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

  testWidgets('KeePass dosyası açılır ve kasaya eklenir', (tester) async {
    tester.platformDispatcher.localesTestValue = [const Locale('tr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final support = await getApplicationSupportDirectory();
    final directory = support.createTempSync('keepass_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final sodium = await SodiumSumoInit.init();
    final database = VaultDatabase.openFile(File('${directory.path}/a.db'));
    addTearDown(database.close);
    final store = VaultStore(database);
    final service = VaultService(sodium: sodium, store: store);
    final pending = await service.prepareVault('mavi-Kale-41-Defter');
    final session = await service.confirmRecoveryKey(
      pending,
      pending.recoveryKeyText,
    );
    final picker = _PickedFile(
      base64.decode(kdbxFixtureFiles['keykey/keykey_ornek.kdbx']!),
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
          documentFilesProvider.overrideWithValue(picker),
          kdbxKdfProvider.overrideWithValue(PlatformKdbxKdf()),
          initialVaultStatusProvider.overrideWithValue(VaultOpen(session)),
        ],
        child: const KeyKeyApp(),
      ),
    );
    await pumpUntilFound(tester, find.byKey(GlassNavBar.addKey));

    debugPrint('KKADIM Ayarlar → İçe aktar.');
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await settle(tester);
    final tile = find.text('İçe aktar');
    await tester.scrollUntilVisible(tile, 200);
    await settle(tester);
    await tapText(tester, 'İçe aktar');
    await pumpUntilFound(tester, find.text('KeePass dosyasını aç'));

    debugPrint('KKADIM Yanlış parola.');
    await tester.enterText(find.byType(TextField).first, 'yanlış');
    await tester.pump();
    await tapText(tester, 'Aç');
    await pumpUntilFound(
      tester,
      find.textContaining('Parola ya da anahtar dosyası yanlış.'),
    );

    debugPrint('KKADIM Doğru parola.');
    await tester.enterText(find.byType(TextField).first, 'keykey');
    await tester.pump();
    await tapText(tester, 'Aç');
    await pumpUntilFound(
      tester,
      find.text('Çöp kutusundaki 1 kayıt alınmadı.'),
    );
    expect(
      find.text("1 kaydın ekleri alınmadı; KeyKey'de dosya eki yok."),
      findsOneWidget,
    );
    // Önizlemeye geçerken KeePass ekranı kapandı, dosya sıfırlandı.
    expect(picker.lastGiven!.every((b) => b == 0), isTrue);

    debugPrint('KKADIM Ekle.');
    final add = find.textContaining('kaydı ekle');
    await tester.ensureVisible(add);
    await tester.pump();
    await tester.tap(add);
    await pumpUntilFound(tester, find.textContaining('kayıt eklendi.'));
    expect(find.text('Kaynak dosyayı sil'), findsNothing);

    debugPrint('KKADIM Kasada.');
    final logins = await LoginRepository(
      store: store,
      session: session,
      sodium: sodium,
    ).loadAll();
    final github = logins.items.singleWhere((l) => l.content.name == 'GitHub');
    expect(github.content.username, 'furkan');
    expect(github.content.password, 'gizli-parola');
    expect(github.content.folder, 'E-posta/İş');
  });
}

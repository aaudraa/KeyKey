import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/core/platform/backup_folders.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/features/backup/application/auto_backup_files.dart';
import 'package:keykey/features/backup/application/backup_service.dart';
import 'package:keykey/features/backup/application/restore_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium_sumo.dart';

/// Otomatik yedek klasörünü gerçek Storage Access Framework ile sınar.
///
/// Klasör ve belge seçicileri sistem ekranıdır; testi
/// `resources/scripts/auto-backup-device-test.sh` başlatır ve seçicilere o
/// dokunur. Tek başına `flutter test integration_test` ile çalışırsa seçici
/// açılır ve test zaman aşımına uğrar, bu yüzden betik ortam değişkeni
/// vermedikçe test atlanır.
/// Betiğin alt klasörü koyduktan sonra bıraktığı dosya.
const _marker = 'kk-hazir.txt';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('KEYKEY_SAF_TEST');
  const password = 'otomatik-Yedek-58';
  late SodiumSumo sodium;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  test(
    'klasör seçiliyor, yedek yazılıyor, budanıyor, izin bırakılıyor',
    () async {
      final support = await getApplicationSupportDirectory();
      final directory = support.createTempSync('otomatik_yedek_');
      addTearDown(() => directory.deleteSync(recursive: true));
      final database = VaultDatabase.openFile(File('${directory.path}/a.db'));
      addTearDown(database.close);
      final store = VaultStore(database);
      final service = VaultService(sodium: sodium, store: store);
      final pending = await service.prepareVault(password);
      final session = await service.confirmRecoveryKey(
        pending,
        pending.recoveryKeyText,
      );
      addTearDown(session.dispose);
      final backups = BackupService(sodium: sodium, store: store);
      final folders = PigeonBackupFolders();

      debugPrint('KKADIM klasor-sec');
      final picked = await folders.pick();
      expect(picked, isA<FolderPicked>());
      picked as FolderPicked;
      debugPrint('KKSONUC klasor ${picked.name}');
      expect(await folders.hasAccess(picked.uri), isTrue);
      const device = 'a1b2c3';

      // Betik klasöre otomatik yedek adını taşıyan bir alt klasör ve bir
      // işaret dosyası koyar. Köprü klasörleri dosya saymaz, silmez.
      final subfolder = AutoBackupFiles.nameFor(
        DateTime(2026, 11, 2),
        prefix: 'keykey-otomatik',
        device: device,
      );
      debugPrint('KKADIM alt-klasor $subfolder');
      final ready = DateTime.now().add(const Duration(minutes: 1));
      while (!((await folders.list(picked.uri))?.contains(_marker) ?? false)) {
        if (DateTime.now().isAfter(ready)) fail('Betik alt klasörü koymadı.');
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      expect(await folders.list(picked.uri), isNot(contains(subfolder)));
      expect(await folders.delete(picked.uri, [subfolder]), 0);

      // Aynı günden iki yedek.
      final morning = DateTime(2026, 11, 18, 9);
      final evening = DateTime(2026, 11, 18, 21, 15, 30);
      final names = <String>[];
      for (final time in [morning, evening]) {
        final bytes = await backups.create(session, time);
        final copy = Uint8List.fromList(bytes);
        final name = AutoBackupFiles.nameFor(
          time,
          prefix: 'keykey-otomatik',
          device: device,
        );
        expect(await folders.write(picked.uri, name, bytes), isTrue);
        expect(bytes, everyElement(0));
        names.add(name);
        // Yazılan baytlar geri yükleme ekranının yoluyla parolayla açılıyor.
        final restore = RestoreService(sodium: sodium, store: store);
        (await restore.openWithPassword(
          restore.parse(copy),
          password,
        )).dispose();
      }
      // Aynı adla ikinci yazma: sağlayıcı "… (1)" diye adlandırır; köprü
      // bunu geri alır ve başarısız sayar, budanamayan kopya kalmaz.
      expect(
        await folders.write(
          picked.uri,
          names.last,
          await backups.create(session, evening),
        ),
        isFalse,
      );
      final listed = await folders.list(picked.uri);
      expect(listed, containsAll(names));
      expect(listed!.where((name) => name.contains('(')), isEmpty);
      // Ara dosyalar doğrulanınca son ada çevrildi; geride kalmadı.
      expect(
        listed.where((name) => name.endsWith(AutoBackupFiles.partSuffix)),
        isEmpty,
      );
      // İki dosya en yeni beşin içinde: budanacak bir şey yok.
      expect(AutoBackupFiles.toDelete(listed, device: device), isEmpty);
      expect(await folders.delete(picked.uri, [names.first]), 1);
      expect(await folders.list(picked.uri), isNot(contains(names.first)));
      debugPrint(
        'KKSONUC dosyalar ${(await folders.list(picked.uri))!.join(',')}',
      );

      // Elle yedek de aynı seçici yardımcısıyla çalışıyor.
      debugPrint('KKADIM belge-kaydet');
      final manual = await PigeonDocumentFiles().save(
        suggestedName: 'keykey-yedek-deneme.keykey',
        mimeType: BackupService.mimeType,
        bytes: await backups.create(session, evening),
      );
      expect(manual, DocumentSaveResult.saved);

      // Kalıcı izin kalkar. Seçiciden gelen geçici izin etkinlik kapanana
      // kadar sürdüğü için bu oturumda yazma yine geçebilir; denetleyici bu
      // yüzden yazmadan önce kalıcı izne bakar.
      await folders.release(picked.uri);
      expect(await folders.hasAccess(picked.uri), isFalse);
      debugPrint('KKADIM bitti');
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

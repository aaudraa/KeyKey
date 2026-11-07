import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/features/backup/application/backup_service.dart';
import 'package:keykey/features/backup/application/restore_service.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium_sumo.dart';

/// Yedeğin bu Android sürümünde gerçek libsodium ve SQLite dosyalarıyla
/// alınıp başka bir kasaya kurulabildiğini sınar.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'yedek-Parolasi-55';

  late SodiumSumo sodium;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  test('yedek alınıyor, başka kasaya kuruluyor ve açılıyor', () async {
    final support = await getApplicationSupportDirectory();
    final directory = support.createTempSync('yedek_testi_');
    addTearDown(() => directory.deleteSync(recursive: true));

    final sourceDb = VaultDatabase.openFile(File('${directory.path}/a.db'));
    addTearDown(sourceDb.close);
    final source = VaultStore(sourceDb);
    final service = VaultService(sodium: sodium, store: source);
    final pending = await service.prepareVault(password);
    final session = await service.confirmRecoveryKey(
      pending,
      pending.recoveryKeyText,
    );
    addTearDown(session.dispose);

    // Birden çok 64 KiB'lık parça oluşsun diye çok sayıda kayıt.
    final now = DateTime.utc(2026, 11, 7);
    Uint8List idOf(int n) => Uint8List(16)
      ..[14] = n >> 8
      ..[15] = n & 0xff;
    for (var n = 0; n < 400; n++) {
      final id = idOf(n);
      await source.putRecord(
        StoredRecord(
          id: id,
          type: 'login',
          blob: session.records.encrypt(
            recordId: id,
            type: 'login',
            plainText: LoginContent(
              name: 'Kayıt $n',
              password: 'deneme-$n',
              notes: 'ığüşöç ' * 40,
            ).toJsonBytes(),
          ),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final bytes = await BackupService(
      sodium: sodium,
      store: source,
    ).create(session, now);
    expect(bytes.length, greaterThan(2 * 64 * 1024));

    final targetDb = VaultDatabase.openFile(File('${directory.path}/b.db'));
    addTearDown(targetDb.close);
    final target = VaultStore(targetDb);
    final restore = RestoreService(sodium: sodium, store: target);
    final file = restore.parse(bytes);

    await expectLater(
      restore.openWithPassword(file, 'yanlis-parola-12'),
      throwsA(isA<WrongSecretException>()),
    );
    final damaged = Uint8List.fromList(bytes)..[bytes.length - 40] ^= 0xff;
    await expectLater(
      restore.openWithPassword(restore.parse(damaged), password),
      throwsA(isA<CorruptedDataException>()),
    );
    expect(await target.readHeader(), isNull);

    final opened = await restore.openWithPassword(file, password);
    expect(opened.loginCount, 400);
    await restore.replace(opened);
    opened.dispose();

    final targetService = VaultService(sodium: sodium, store: target);
    final header = (await targetService.readHeader())!;
    final outcome = await targetService.unlockWithPassword(header, password);
    final restored = outcome.session!;
    addTearDown(restored.dispose);
    final records = await target.allRecords();
    expect(records, hasLength(400));
    final last = records.singleWhere((r) => listEquals(r.id, idOf(399)));
    final content = LoginContent.fromJsonBytes(
      restored.records.decrypt(
        recordId: last.id,
        type: last.type,
        blob: last.blob,
      ),
    );
    expect(content.name, 'Kayıt 399');
    expect(content.password, 'deneme-399');
  });
}

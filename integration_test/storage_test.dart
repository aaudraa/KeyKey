import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'veritabanı bu Android sürümünde çalışıyor ve veriyi saklıyor',
    () async {
      final support = await getApplicationSupportDirectory();
      final directory = support.createTempSync('depolama_testi_');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/keykey.db');
      final now = DateTime.utc(2026, 11, 5);
      final id = Uint8List(16)..fillRange(0, 16, 5);

      final first = VaultDatabase.openFile(file);
      final store = VaultStore(first);
      await store.putRecord(
        StoredRecord(
          id: id,
          type: 'login',
          blob: Uint8List.fromList([1, 2, 3]),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await store.registerFailedAttempt(now);
      final secureDelete = await first
          .customSelect('PRAGMA secure_delete')
          .getSingle();
      final journalMode = await first
          .customSelect('PRAGMA journal_mode')
          .getSingle();
      await first.close();

      expect(secureDelete.data.values.single, 1);
      expect(journalMode.data.values.single, 'delete');

      final second = VaultDatabase.openFile(file);
      addTearDown(second.close);
      final reopened = VaultStore(second);

      final record = await reopened.getRecord(id);
      expect(record?.blob, [1, 2, 3]);
      final attempts = await reopened.readUnlockAttempts();
      expect(attempts.failedAttempts, 1);
    },
  );
}

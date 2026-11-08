import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/crypto/vault_crypto.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/backup/application/backup_service.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  const password = 'ilk-Ana-Parola-47';

  late SodiumSumo sodium;
  late VaultDatabase database;
  late VaultStore store;
  late VaultSession session;
  late String recoveryKey;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() async {
    database = VaultDatabase(NativeDatabase.memory());
    store = VaultStore(database);
    final service = VaultService(sodium: sodium, store: store);
    final pending = await service.prepareVault(password);
    recoveryKey = pending.recoveryKeyText;
    session = await service.confirmRecoveryKey(pending, recoveryKey);
  });

  tearDown(() async {
    session.dispose();
    await database.close();
  });

  Future<void> putLogin(int seed) {
    final id = Uint8List(16)..[0] = seed;
    return store.putRecord(
      StoredRecord(
        id: id,
        type: 'login',
        blob: session.records.encrypt(
          recordId: id,
          type: 'login',
          plainText: Uint8List.fromList(utf8.encode('{"deneme":$seed}')),
        ),
        createdAt: DateTime.utc(2026, 1, seed),
        updatedAt: DateTime.utc(2026, 2, seed),
      ),
    );
  }

  test(
    'yedek kasanın bütün kayıtlarını taşıyor ve parolayla açılıyor',
    () async {
      await putLogin(1);
      await putLogin(2);
      await SettingsRepository(
        store: store,
        session: session,
      ).save(AppSettings.requireAuth);

      final backups = BackupService(sodium: sodium, store: store);
      final bytes = await backups.create(session, DateTime.utc(2026, 11, 7));

      final codec = BackupCodec(sodium);
      final file = codec.parse(bytes);
      final key = await VaultCrypto(sodium)
          .unlockWithPassword(file.header, password);
      final contents = await codec.open(file, key);
      key.dispose();

      final stored = await store.allRecords();
      expect(contents.records, hasLength(stored.length));
      expect(
        contents.records.map((r) => r.type),
        containsAll(['login', 'settings']),
      );
      for (final record in stored) {
        final copy = contents.records.singleWhere(
          (r) => base64.encode(r.id) == base64.encode(record.id),
        );
        expect(copy.blob, record.blob);
        expect(copy.updatedAt, record.updatedAt);
      }
      expect(contents.createdAt, DateTime.utc(2026, 11, 7));
    },
  );

  test('kurtarma anahtarıyla da açılıyor', () async {
    await putLogin(1);
    final bytes = await BackupService(
      sodium: sodium,
      store: store,
    ).create(session, DateTime.utc(2026, 11, 7));
    final codec = BackupCodec(sodium);
    final file = codec.parse(bytes);
    final key = VaultCrypto(sodium)
        .unlockWithRecoveryKey(file.header, recoveryKey);
    expect((await codec.open(file, key)).records, hasLength(1));
    key.dispose();
  });

  test('son değişiklik ayar kaydını saymıyor', () async {
    final backups = BackupService(sodium: sodium, store: store);
    expect(await backups.latestChange(), isNull);

    await SettingsRepository(
      store: store,
      session: session,
      clock: () => DateTime.utc(2026, 12),
    ).save(AppSettings.defaults);
    expect(await backups.latestChange(), isNull);

    await putLogin(3);
    await putLogin(5);
    expect(await backups.latestChange(), DateTime.utc(2026, 2, 5));
  });

  test('önerilen dosya adı yerel tarihi taşıyor', () {
    expect(
      BackupService.fileNameFor(DateTime(2026, 3, 9, 23, 59)),
      'keykey-yedek-2026-03-09.keykey',
    );
  });
}

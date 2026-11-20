import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/backup/application/restore_service.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/sync/application/sync_join.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:sodium/sodium_sumo.dart';

final class _Vault {
  new(this.database, this.store, this.service, this.session, this.recoveryKey);

  final VaultDatabase database;
  final VaultStore store;
  final VaultService service;
  final VaultSession session;
  final String recoveryKey;
}

void main() {
  const passwordA = 'Ana-Parola-2026';
  const passwordB = 'Telefon-B-Parola-2026';
  final sync = SyncSettings(
    folder: Uri.parse('https://bulut.example.com/dav/KeyKey/'),
    username: 'ayse',
    appPassword: 'uygulama-parolasi',
  );
  final passwordAt = DateTime.utc(2026, 10, 3);
  final recoveryAt = DateTime.utc(2026, 10, 4);
  final lastBackup = DateTime.utc(2026, 11);

  late SodiumSumo sodium;
  final vaults = <_Vault>[];

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  tearDown(() async {
    for (final vault in vaults) {
      if (!vault.session.isDisposed) vault.session.dispose();
      await vault.database.close();
    }
    vaults.clear();
  });

  Uint8List id(int n) => Uint8List(16)..[15] = n;

  Future<_Vault> newVault(String password) async {
    final database = VaultDatabase(NativeDatabase.memory());
    final store = VaultStore(database);
    final service = VaultService(sodium: sodium, store: store);
    final pending = await service.prepareVault(password);
    final text = pending.recoveryKeyText;
    final session = await service.confirmRecoveryKey(pending, text);
    final vault = _Vault(database, store, service, session, text);
    vaults.add(vault);
    return vault;
  }

  Future<void> putLogin(
    _Vault vault,
    int n, {
    String name = 'Site',
    DateTime? at,
  }) => vault.store.putRecord(
    StoredRecord(
      id: id(n),
      type: 'login',
      blob: vault.session.records.encrypt(
        recordId: id(n),
        type: 'login',
        plainText: LoginContent(name: name).toJsonBytes(),
      ),
      createdAt: DateTime.utc(2026),
      updatedAt: at ?? DateTime.utc(2026, 6),
    ),
  );

  Future<BackupFile> syncFileOf(
    _Vault vault, {
    List<StoredTombstone> deleted = const [],
  }) async {
    final codec = BackupCodec(sodium);
    final bytes = await codec.encode(
      header: vault.session.header,
      vaultKey: vault.session.vaultKey,
      records: await vault.store.allRecords(),
      createdAt: DateTime.utc(2026, 11, 20),
      sync: SyncInfo(
        device: 'a1b2c3',
        passwordChangedAt: passwordAt,
        recoveryChangedAt: recoveryAt,
        deleted: deleted,
      ),
    );
    return codec.parse(bytes);
  }

  /// Bu telefon: kendi kasası, iki kaydı, ayarları, parmak izi yuvası ve
  /// bir silme kaydı.
  Future<_Vault> phoneB() async {
    final b = await newVault(passwordB);
    await putLogin(b, 1);
    await putLogin(b, 3, name: 'B', at: DateTime.utc(2026, 8));
    final settingsId = SettingsRepository.recordId;
    await b.store.putRecord(
      StoredRecord(
        id: settingsId,
        type: SettingsRepository.recordType,
        blob: b.session.records.encrypt(
          recordId: settingsId,
          type: SettingsRepository.recordType,
          plainText: AppSettings.defaults
              .copyWith(lastBackupAt: lastBackup)
              .toJsonBytes(),
        ),
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    await b.store.writeBiometricSlot(
      StoredBiometricSlot(iv: Uint8List(12), cipherText: Uint8List(48)),
    );
    await putLogin(b, 8);
    await b.store.deleteRecord(id(8), deletedAt: DateTime.utc(2026, 7));
    return b;
  }

  SyncJoin joinFor(_Vault vault) => SyncJoin(
    restore: RestoreService(sodium: sodium, store: vault.store),
    vaults: vault.service,
  );

  String plain(VaultSession session, StoredRecord record) =>
      String.fromCharCodes(
        session.records.decrypt(
          recordId: record.id,
          type: record.type,
          blob: record.blob,
        ),
      );

  Future<List<int>> loginIds(_Vault vault) async => [
    for (final r in await vault.store.allRecords())
      if (r.type == 'login') r.id[15],
  ]..sort();

  test('katılınca kayıtlar korunuyor, uzak parola geçerli', () async {
    final a = await newVault(passwordA);
    await putLogin(a, 2);
    await putLogin(a, 3, name: 'A', at: DateTime.utc(2026, 7));
    final remote = await syncFileOf(
      a,
      deleted: [StoredTombstone(id: id(9), deletedAt: DateTime.utc(2026, 9))],
    );
    final b = await phoneB();

    final session = await joinFor(b).join(
      current: b.session,
      remote: remote,
      secret: passwordA,
      isRecoveryKey: false,
      settings: sync,
    );
    addTearDown(session.dispose);

    final header = (await b.store.readHeader())!;
    expect(header.toJsonString(), a.session.header.toJsonString());
    expect(session.header.toJsonString(), a.session.header.toJsonString());
    expect(await loginIds(b), [1, 2, 3]);

    // Bütün kayıtlar yeni anahtarla açılıyor; aynı kimlikte yeni olan kaldı.
    final records = await b.store.allRecords();
    for (final record in records) {
      expect(() => plain(session, record), returnsNormally);
    }
    final three = records.singleWhere((r) => r.id[15] == 3);
    expect(plain(session, three), contains('"B"'));

    // Bu telefonun ayarları, senkron eklenmiş.
    final settingsRecord = records.singleWhere(
      (r) => r.type == SettingsRepository.recordType,
    );
    final settings = AppSettings.tryParse(
      session.records.decrypt(
        recordId: settingsRecord.id,
        type: settingsRecord.type,
        blob: settingsRecord.blob,
      ),
    )!;
    expect(settings.sync!.folder, sync.folder);
    expect(settings.lastBackupAt, lastBackup);

    // Eski silme kayıtları gitti, dosyanınkiler geldi; zamanlar dosyadan.
    expect([for (final t in await b.store.allTombstones()) t.id[15]], [9]);
    final times = await b.store.readHeaderTimes();
    expect(times.passwordChangedAt, passwordAt);
    expect(times.recoveryChangedAt, recoveryAt);

    expect(await b.store.readBiometricSlot(), isNull);
    final rejected = await b.service.unlockWithPassword(header, passwordB);
    expect(rejected.attempt, isA<PasswordRejected>());
    final accepted = await b.service.unlockWithPassword(header, passwordA);
    expect(accepted.attempt, isA<PasswordAccepted>());
    accepted.session?.dispose();
  });

  test('kurtarma anahtarıyla da katılıyor', () async {
    final a = await newVault(passwordA);
    await putLogin(a, 2);
    final remote = await syncFileOf(a);
    final b = await phoneB();

    final session = await joinFor(b).join(
      current: b.session,
      remote: remote,
      secret: a.recoveryKey,
      isRecoveryKey: true,
      settings: sync,
    );
    addTearDown(session.dispose);
    expect(await loginIds(b), [1, 2, 3]);
  });

  test(
    'silme kaydıyla çatışan kayıt zamana göre kalıyor ya da gidiyor',
    () async {
      final a = await newVault(passwordA);
      final remote = await syncFileOf(
        a,
        deleted: [
          StoredTombstone(id: id(1), deletedAt: DateTime.utc(2026, 7)),
          StoredTombstone(id: id(3), deletedAt: DateTime.utc(2026, 7)),
        ],
      );
      // 1 silmeden önce değişti (gider), 3 sonra değişti (kalır).
      final b = await phoneB();

      final session = await joinFor(b).join(
        current: b.session,
        remote: remote,
        secret: passwordA,
        isRecoveryKey: false,
        settings: sync,
      );
      addTearDown(session.dispose);
      expect(await loginIds(b), [3]);
      expect([for (final t in await b.store.allTombstones()) t.id[15]], [1]);
    },
  );

  group('olmazsa kasa ve oturum eski halinde', () {
    Future<void> expectUnchanged(_Vault b, String headerJson) async {
      expect((await b.store.readHeader())!.toJsonString(), headerJson);
      expect(await b.store.readBiometricSlot(), isNotNull);
      expect(b.session.isDisposed, isFalse);
      final one = (await b.store.getRecord(id(1)))!;
      expect(plain(b.session, one), contains('"Site"'));
      expect([for (final t in await b.store.allTombstones()) t.id[15]], [8]);
    }

    test('yanlış parola', () async {
      final a = await newVault(passwordA);
      await putLogin(a, 2);
      final remote = await syncFileOf(a);
      final b = await phoneB();
      final before = b.session.header.toJsonString();

      await expectLater(
        joinFor(b).join(
          current: b.session,
          remote: remote,
          secret: passwordB,
          isRecoveryKey: false,
          settings: sync,
        ),
        throwsA(isA<WrongSecretException>()),
      );
      await expectUnchanged(b, before);
      expect(await loginIds(b), [1, 3]);
    });

    test('bu telefonda açılmayan bir kayıt', () async {
      final a = await newVault(passwordA);
      await putLogin(a, 2);
      final remote = await syncFileOf(a);
      final b = await phoneB();
      await b.store.putRecord(
        StoredRecord(
          id: id(7),
          type: 'login',
          blob: Uint8List(64),
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      final before = b.session.header.toJsonString();

      await expectLater(
        joinFor(b).join(
          current: b.session,
          remote: remote,
          secret: passwordA,
          isRecoveryKey: false,
          settings: sync,
        ),
        throwsA(isA<CryptoException>()),
      );
      await expectUnchanged(b, before);
      expect(await loginIds(b), [1, 3, 7]);
    });
  });
}

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/network/sync_transport.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/backup/application/backup_service.dart';
import 'package:keykey/features/backup/application/restore_service.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/sync/application/sync_merger.dart';
import 'package:keykey/features/sync/application/sync_service.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:sodium/sodium_sumo.dart';

/// Bellekte bir senkron klasörü. Her yazma yeni bir ETag verir.
final class FakeSyncTransport implements SyncTransport {
  final files = <String, ({Uint8List bytes, String etag, DateTime at})>{};
  int reads = 0;
  int writes = 0;
  bool failReads = false;
  bool failWrites = false;
  var _counter = 0;
  DateTime clock = DateTime.utc(2026, 11, 20, 12);

  void put(String name, Uint8List bytes) {
    files[name] = (bytes: bytes, etag: '"${++_counter}"', at: clock);
  }

  @override
  Future<void> ensureFolder() async {}

  @override
  Future<List<RemoteFile>> list() async => [
    for (final e in files.entries)
      RemoteFile(
        name: e.key,
        etag: e.value.etag,
        size: e.value.bytes.length,
        modified: e.value.at,
      ),
  ];

  @override
  Future<Uint8List> read(String name) async {
    if (failReads) {
      throw const SyncTransportException(SyncFailureKind.offline);
    }
    reads++;
    return files[name]!.bytes;
  }

  @override
  Future<void> write(String name, Uint8List bytes) async {
    if (failWrites) {
      throw const SyncTransportException(SyncFailureKind.server);
    }
    writes++;
    put(name, bytes);
  }

  @override
  Future<void> delete(String name) async {
    files.remove(name);
  }
}

/// Aynı kasayı taşıyan bir telefon: kendi SQLite'ı ve oturumu.
final class _Phone {
  new(this.device, this.database, this.store, this.session, this.service);

  final String device;
  final VaultDatabase database;
  final VaultStore store;
  final VaultSession session;
  final SyncService service;
  final cache = SyncCache();
  late SyncSettings settings = SyncSettings(
    folder: Uri.parse('https://bulut.example.com/dav/KeyKey/'),
    username: 'ayse',
    appPassword: 'uygulama-parolasi',
  );

  Future<SyncResult> sync() async {
    final result = await service.sync(session, settings, cache: cache);
    settings = settings.withLastSync(result.at, result.digest);
    return result;
  }

  Future<void> close() async {
    session.dispose();
    await database.close();
  }
}

void main() {
  late SodiumSumo sodium;
  late FakeSyncTransport folder;
  final phones = <_Phone>[];
  var now = DateTime.utc(2026, 11, 20, 12);

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    folder = FakeSyncTransport();
    now = DateTime.utc(2026, 11, 20, 12);
  });

  tearDown(() async {
    for (final phone in phones) {
      await phone.close();
    }
    phones.clear();
  });

  SyncService service(VaultStore store, String device) => SyncService(
    store: store,
    codec: BackupCodec(sodium),
    sodium: sodium,
    transport: (_) => folder,
    device: device,
    deviceName: () async => 'Telefon $device',
    now: () => now,
  );

  /// Yeni bir kasa kurar.
  Future<_Phone> first(String device) async {
    final database = VaultDatabase(NativeDatabase.memory());
    final store = VaultStore(database);
    final vaults = VaultService(sodium: sodium, store: store);
    final pending = await vaults.prepareVault('Ana-Parola-2026');
    final session = await vaults.confirmRecoveryKey(
      pending,
      pending.recoveryKeyText,
    );
    final phone = _Phone(
      device,
      database,
      store,
      session,
      service(store, device),
    );
    phones.add(phone);
    return phone;
  }

  /// [other] ile aynı kasayı taşıyan ikinci telefon.
  Future<_Phone> second(_Phone other, String device) async {
    final database = VaultDatabase(NativeDatabase.memory());
    final store = VaultStore(database);
    await store.createVault(other.session.header);
    final key = sodium.secureCopy(other.session.vaultKey.extractBytes());
    final session = VaultService(
      sodium: sodium,
      store: store,
    ).openRestoredSession(other.session.header, key);
    final phone = _Phone(
      device,
      database,
      store,
      session,
      service(store, device),
    );
    phones.add(phone);
    return phone;
  }

  Uint8List id(int n) => Uint8List(16)..[15] = n;

  Future<void> addLogin(_Phone phone, int n, {String name = 'Site'}) =>
      phone.store.putRecord(
        StoredRecord(
          id: id(n),
          type: 'login',
          blob: phone.session.records.encrypt(
            recordId: id(n),
            type: 'login',
            plainText: LoginContent(name: name).toJsonBytes(),
          ),
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<void> addSettings(_Phone phone) => phone.store.putRecord(
    StoredRecord(
      id: Uint8List(16),
      type: 'settings',
      blob: phone.session.records.encrypt(
        recordId: Uint8List(16),
        type: 'settings',
        plainText: AppSettings.defaults.toJsonBytes(),
      ),
      createdAt: now,
      updatedAt: now,
    ),
  );

  Future<List<int>> loginIds(_Phone phone) async => [
    for (final r in await phone.store.allRecords())
      if (r.type == 'login') r.id[15],
  ]..sort();

  group('çöp kutusunun süresi', () {
    test('eşitlenmemiş telefonun süresi dolan çöpü, ötekinde çöpten '
        'çıkarılan kaydı silmiyor', () async {
      LoginRepository logins(_Phone phone) => LoginRepository(
        store: phone.store,
        session: phone.session,
        sodium: sodium,
        clock: () => now,
      );
      final a = await first('a1b2c3');
      final added = await logins(a).add(const LoginContent(name: 'Site'));
      await logins(a)
          .updateMetadata(added, added.content.copyWith(trashedAt: now));
      await a.sync();
      final b = await second(a, 'b2c3d4');
      await b.sync();

      // 29. gün: B kaydı çöpten çıkarıyor; A o arada eşitlenmiyor.
      now = now.add(const Duration(days: 29));
      final onB = (await logins(b).loadAll()).items.single;
      await logins(b)
          .updateMetadata(onB, onB.content.copyWith(trashedAt: null));
      await b.sync();

      // 31. gün: A açılıyor; liste yüklenince süresi dolan çöp siliniyor.
      now = now.add(const Duration(days: 2));
      await logins(a).purgeExpiredTrash((await logins(a).loadAll()).items);
      expect(await a.store.getRecord(added.id), isNull);
      await a.sync();
      await b.sync();
      await a.sync();

      for (final phone in [a, b]) {
        final items = (await logins(phone).loadAll()).items;
        expect(items.single.content.isTrashed, isFalse);
      }
    });
  });

  group('ana parola değişince', () {
    Future<String> uploadedHeader(String device) async =>
        BackupCodec(sodium)
            .parse(folder.files['keykey-sync-$device.keykey']!.bytes)
            .header
            .toJsonString();

    for (final fresh in [false, true]) {
      test('yüklenen dosya yeni yuvayı taşıyor'
          '${fresh ? ' (önbelleksiz)' : ''}', () async {
        final a = await first('a1b2c3');
        await addLogin(a, 1);
        await a.sync();
        final b = await second(a, 'b2c3d4');
        await b.sync();
        await a.sync();
        await b.sync();
        final before = await uploadedHeader('b2c3d4');

        now = now.add(const Duration(minutes: 5));
        final attempt =
            await VaultService(
              sodium: sodium,
              store: b.store,
              clock: () => now,
            ).changePassword(
              b.session,
              currentPassword: 'Ana-Parola-2026',
              newPassword: 'Yeni-Ana-Parola-2027',
            );
        expect(attempt, isA<PasswordAccepted>());
        expect(b.session.header.toJsonString(), isNot(before));

        if (fresh) {
          await b.service.sync(b.session, b.settings, cache: SyncCache());
        } else {
          await b.sync();
        }
        expect(await uploadedHeader('b2c3d4'), b.session.header.toJsonString());
      });
    }
  });

  group('senkron açıkken geri yükleme', () {
    const password = 'Ana-Parola-2026';

    Future<BackupFile> backupOf(_Phone phone) async {
      final bytes = await BackupService(
        sodium: sodium,
        store: phone.store,
      ).create(phone.session, now);
      return RestoreService(sodium: sodium, store: phone.store).parse(bytes);
    }

    Future<OpenedBackup> open(_Phone phone, BackupFile file) => RestoreService(
      sodium: sodium,
      store: phone.store,
    ).openWithPassword(file, password);

    Future<StoredRecord> record(_Phone phone, int n) async =>
        (await phone.store.getRecord(id(n)))!;

    Future<String> nameOf(_Phone phone, int n) async {
      final stored = await record(phone, n);
      return LoginContent.fromJsonBytes(
        phone.session.records.decrypt(
          recordId: stored.id,
          type: stored.type,
          blob: stored.blob,
        ),
      ).name;
    }

    Future<AppSettings> settingsOf(_Phone phone, {_Phone? keyOf}) async {
      final stored = (await phone.store.allRecords()).singleWhere(
        (r) => r.type == 'settings',
      );
      return AppSettings.tryParse(
        (keyOf ?? phone).session.records.decrypt(
          recordId: stored.id,
          type: stored.type,
          blob: stored.blob,
        ),
      )!;
    }

    test('kalıcı silinen kayıt birleştirerek geri gelir, öteki telefonun '
        'silmesi onu yeniden silmez', () async {
      final a = await first('a1b2c3');
      await addLogin(a, 1);
      final backup = await backupOf(a);
      final b = await second(a, 'b2c3d4');
      await a.sync();
      await b.sync();
      expect(await loginIds(b), [1]);

      now = now.add(const Duration(hours: 1));
      await b.store.deleteRecord(id(1), deletedAt: now);
      await b.sync();
      await a.sync();
      expect(await loginIds(a), isEmpty);

      now = now.add(const Duration(hours: 1));
      final opened = await open(a, backup);
      final counts = await RestoreService(
        sodium: sodium,
        store: a.store,
      ).merge(opened, a.session, stampAt: now);
      opened.dispose();
      expect(counts.added, 1);
      expect((await record(a, 1)).updatedAt, now);
      expect(await a.store.allTombstones(), isEmpty);

      await a.sync();
      await b.sync();
      await a.sync();
      expect(await loginIds(a), [1]);
      expect(await loginIds(b), [1]);
    });

    test('senkron kapalıyken birleştirme zamanları değiştirmiyor ama silme '
        'kaydını kaldırıyor', () async {
      final a = await first('a1b2c3');
      await addLogin(a, 1);
      final createdAt = now;
      final backup = await backupOf(a);
      await a.store.deleteRecord(id(1), deletedAt: now);

      final opened = await open(a, backup);
      await RestoreService(
        sodium: sodium,
        store: a.store,
      ).merge(opened, a.session);
      opened.dispose();
      expect((await record(a, 1)).updatedAt, createdAt);
      expect(await a.store.allTombstones(), isEmpty);
    });

    test('aynı kasada değiştirme senkronu açık tutuyor, yedekte olmayanlar '
        'geri geliyor', () async {
      final a = await first('a1b2c3');
      await addLogin(a, 1, name: 'Eski');
      final backup = await backupOf(a);

      now = now.add(const Duration(hours: 1));
      await addLogin(a, 1, name: 'Yeni');
      await addLogin(a, 2);
      await a.sync();
      final b = await second(a, 'b2c3d4');
      await addLogin(b, 3);
      await b.sync();
      expect(await nameOf(b, 1), 'Yeni');

      now = now.add(const Duration(hours: 1));
      final opened = await open(a, backup);
      await RestoreService(
        sodium: sodium,
        store: a.store,
      ).replace(opened, sync: a.settings, stampAt: now);
      opened.dispose();
      expect(await loginIds(a), [1]);
      expect((await record(a, 1)).updatedAt, now);
      final settings = await settingsOf(a);
      expect(settings.sync!.folder, a.settings.folder);

      // Kasa kilitlenip açılınca önbellek boş başlar.
      await a.service.sync(a.session, settings.sync!, cache: SyncCache());
      expect(await loginIds(a), [1, 2, 3]);
      expect(await nameOf(a, 1), 'Eski');
      await b.sync();
      expect(await loginIds(b), [1, 2, 3]);
      expect(await nameOf(b, 1), 'Eski');
    });

    test('başka kasada değiştirme senkronu kapatıyor, zamanlar '
        'değişmiyor', () async {
      final a = await first('a1b2c3');
      await addLogin(a, 1);
      final c = await first('c0c0c0');
      await addLogin(c, 5);
      final createdAt = now;
      final backup = await backupOf(c);

      now = now.add(const Duration(hours: 1));
      final opened = await RestoreService(
        sodium: sodium,
        store: a.store,
      ).openWithPassword(backup, password);
      await RestoreService(
        sodium: sodium,
        store: a.store,
      ).replace(opened, sync: a.settings, stampAt: now);
      opened.dispose();

      expect(await loginIds(a), [5]);
      expect((await record(a, 5)).updatedAt, createdAt);
      expect((await settingsOf(a, keyOf: c)).sync, isNull);
    });
  });

  test('boş klasöre bu telefonun dosyası yükleniyor', () async {
    final a = await first('a1b2c3');
    await addLogin(a, 1);
    await addSettings(a);

    final result = await a.sync();

    expect(result.uploaded, isTrue);
    expect(result.changedLocal, isFalse);
    expect(folder.files.keys, ['keykey-sync-a1b2c3.keykey']);
    final codec = BackupCodec(sodium);
    final file = codec.parse(folder.files.values.single.bytes);
    final contents = await codec.open(file, a.session.vaultKey);
    expect(contents.version, 4);
    expect(contents.sync!.device, 'a1b2c3');
    expect(contents.sync!.deviceName, 'Telefon a1b2c3');
    expect([for (final r in contents.records) r.type], ['login']);
    expect(result.devices.single.device, 'a1b2c3');
    expect(result.devices.single.self, isTrue);
    expect(result.digest, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('iki telefon eklemeyi ve silmeyi birbirine taşıyor', () async {
    final a = await first('a1b2c3');
    final b = await second(a, 'b2c3d4');
    await addLogin(a, 1);
    await a.sync();

    final onB = await b.sync();
    expect(onB.changedLocal, isTrue);
    expect(await loginIds(b), [1]);

    now = now.add(const Duration(minutes: 1));
    await b.store.deleteRecord(id(1), deletedAt: now);
    await b.sync();
    final onA = await a.sync();
    expect(onA.changedLocal, isTrue);
    expect(await loginIds(a), isEmpty);
    expect((await a.store.allTombstones()).single.deletedAt, now);

    // Değişiklik yoksa yeniden yüklenmez.
    final again = await a.sync();
    expect(again.uploaded, isFalse);
    expect(again.changedLocal, isFalse);
    expect([for (final d in again.devices) d.device]..sort(), [
      'a1b2c3',
      'b2c3d4',
    ]);
  });

  test('değişmeyen dosya yeniden indirilmiyor', () async {
    final a = await first('a1b2c3');
    final b = await second(a, 'b2c3d4');
    await addLogin(a, 1);
    await a.sync();
    await b.sync();

    var before = folder.reads;
    await a.sync();
    // Yalnızca B'nin dosyası; A kendi yüklediğini indirmez.
    expect(folder.reads - before, 1);

    before = folder.reads;
    await a.sync();
    expect(folder.reads - before, 0);
  });

  test('kendi dosyası yerelde olmayan kaydı geri getiriyor', () async {
    final a = await first('a1b2c3');
    await addLogin(a, 1);
    await a.sync();

    await a.store.replaceVault(a.session.header, const []);
    final fresh = _Phone(a.device, a.database, a.store, a.session, a.service)
      ..settings = a.settings;

    final result = await fresh.sync();
    expect(result.changedLocal, isTrue);
    expect(await loginIds(a), [1]);
  });

  group('başka kasa', () {
    test('eşitleme hiçbir şey yazmadan duruyor', () async {
      final a = await first('a1b2c3');
      final c = await first('c0c0c0');
      await addLogin(c, 5);
      await c.sync();
      await addLogin(a, 1);

      await expectLater(a.sync(), throwsA(isA<OtherVaultException>()));

      expect(await loginIds(a), [1]);
      expect(folder.files.keys, ['keykey-sync-c0c0c0.keykey']);
    });

    test('klasörün durumu dört türe ayrılıyor', () async {
      final a = await first('a1b2c3');
      final c = await first('c0c0c0');
      final vaultId = a.session.header.vaultId;
      Future<FolderState> inspect() => a.service.inspect(a.settings, vaultId);

      expect(await inspect(), isA<FolderEmpty>());

      await a.sync();
      expect(await inspect(), isA<FolderSameVault>());

      final mine = folder.files.remove('keykey-sync-a1b2c3.keykey')!;
      await c.sync();
      folder.clock = folder.clock.add(const Duration(hours: 1));
      final d = await second(c, 'd0d0d0');
      await addLogin(d, 9);
      await d.sync();
      final other = await inspect();
      expect(other, isA<FolderOtherVault>());
      // En yeni dosya d0d0d0'nınki.
      final newest = (other as FolderOtherVault).newest;
      final contents = await BackupCodec(sodium)
          .open(newest, c.session.vaultKey);
      expect(contents.sync!.device, 'd0d0d0');

      folder.files['keykey-sync-a1b2c3.keykey'] = mine;
      expect(await inspect(), isA<FolderMixedVaults>());
    });

    test('kasa yokken tek kasanın en yeni dosyası dönüyor', () async {
      final a = await first('a1b2c3');
      final c = await first('c0c0c0');
      Future<FolderState> inspect() => c.service.inspect(c.settings, null);

      expect(await inspect(), isA<FolderEmpty>());
      await a.sync();
      final others = folder.files.remove('keykey-sync-a1b2c3.keykey')!;
      await c.sync();
      folder.clock = folder.clock.add(const Duration(hours: 1));
      final d = await second(c, 'd0d0d0');
      await d.sync();

      final state = await inspect();
      final newest = (state as FolderOtherVault).newest;
      final contents = await BackupCodec(sodium)
          .open(newest, c.session.vaultKey);
      expect(contents.sync!.device, 'd0d0d0');

      folder.files['keykey-sync-a1b2c3.keykey'] = others;
      expect(await inspect(), isA<FolderMixedVaults>());
    });
  });

  test('bozuk ve daha yeni dosyalar düşüyor, ötekiler birleşiyor', () async {
    final a = await first('a1b2c3');
    final b = await second(a, 'b2c3d4');
    await addLogin(b, 2);
    await b.sync();
    final good = folder.files['keykey-sync-b2c3d4.keykey']!.bytes;
    final newer = Uint8List.fromList(good)..[8] = 2;
    folder
      ..put('keykey-sync-e5e5e5.keykey', newer)
      ..put('keykey-sync-f6f6f6.keykey', Uint8List.fromList([1, 2, 3]));

    final result = await a.sync();

    expect(await loginIds(a), [2]);
    expect(
      result.issues,
      containsAll([
        isA<NewerApp>().having((i) => i.device, 'device', 'e5e5e5'),
        isA<UnreadableDevice>().having((i) => i.device, 'device', 'f6f6f6'),
      ]),
    );
  });

  group('hata', () {
    test('indirme yarıda kalınca kasa değişmiyor', () async {
      final a = await first('a1b2c3');
      final b = await second(a, 'b2c3d4');
      await addLogin(b, 2);
      await b.sync();
      folder.failReads = true;

      await expectLater(a.sync(), throwsA(isA<SyncTransportException>()));
      expect(await loginIds(a), isEmpty);
    });

    test('yükleme yarıda kalınca birleşme kalıyor, sonra yükleniyor', () async {
      final a = await first('a1b2c3');
      final b = await second(a, 'b2c3d4');
      await addLogin(b, 2);
      await b.sync();
      folder.failWrites = true;
      final digestBefore = a.settings.lastDigest;

      await expectLater(a.sync(), throwsA(isA<SyncTransportException>()));
      expect(await loginIds(a), [2]);
      expect(a.settings.lastDigest, digestBefore);

      folder.failWrites = false;
      final retry = await a.sync();
      expect(retry.uploaded, isTrue);
      expect(folder.files.keys, contains('keykey-sync-a1b2c3.keykey'));
    });
  });

  test('telefon klasörden kaldırılıyor', () async {
    final a = await first('a1b2c3');
    final b = await second(a, 'b2c3d4');
    await a.sync();
    await b.sync();

    await a.service.removeDevice(a.settings, 'b2c3d4');

    expect(folder.files.keys, ['keykey-sync-a1b2c3.keykey']);
    await expectLater(
      a.service.removeDevice(a.settings, '../x'),
      throwsArgumentError,
    );
  });
}

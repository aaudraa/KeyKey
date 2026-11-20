import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/backup/application/backup_service.dart';
import 'package:keykey/features/backup/application/restore_service.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:keykey/features/vault/data/vault_record_repository.dart';
import 'package:sodium/sodium_sumo.dart';

/// İki ayrı kasa: biri yedeği alan, öbürü yedeği alan telefon.
final class _Vault {
  new(this.database, this.store, this.service, this.session, this.recovery);

  final VaultDatabase database;
  final VaultStore store;
  final VaultService service;
  final VaultSession session;
  final String recovery;

  Future<void> close() async {
    session.dispose();
    await database.close();
  }
}

void main() {
  const passwordA = 'yedek-Alan-Parola-61';
  const passwordB = 'yeni-Telefon-Parola-73';

  late SodiumSumo sodium;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  Future<_Vault> newVault(String password) async {
    final database = VaultDatabase(NativeDatabase.memory());
    final store = VaultStore(database);
    final service = VaultService(sodium: sodium, store: store);
    final pending = await service.prepareVault(password);
    final recovery = pending.recoveryKeyText;
    final session = await service.confirmRecoveryKey(pending, recovery);
    return _Vault(database, store, service, session, recovery);
  }

  Uint8List id(int n) => Uint8List(16)..[15] = n;

  final loginJson = jsonEncode(
    jsonDecode(File('test/fixtures/vault/login-v2.json').readAsStringSync()),
  );
  final otpJson = jsonEncode(
    jsonDecode(File('test/fixtures/vault/otp-v1.json').readAsStringSync()),
  );
  final cardJson = utf8.decode(
    CardContent(name: 'Maaş', number: '4111111111111111').toJsonBytes(),
  );
  final noteJson = utf8.decode(
    NoteContent(name: 'Wi-Fi', text: 'gizli').toJsonBytes(),
  );

  Future<void> put(
    _Vault vault,
    int n, {
    String type = 'login',
    String? json,
    DateTime? updatedAt,
  }) {
    final plain =
        json ??
        switch (type) {
          'otp' => otpJson,
          'card' => cardJson,
          'note' => noteJson,
          _ => loginJson,
        };
    return vault.store.putRecord(
      StoredRecord(
        id: id(n),
        type: type,
        blob: vault.session.records.encrypt(
          recordId: id(n),
          type: type,
          plainText: Uint8List.fromList(utf8.encode(plain)),
        ),
        createdAt: DateTime.utc(2026),
        updatedAt: updatedAt ?? DateTime.utc(2026, 6),
      ),
    );
  }

  String readPlain(_Vault vault, StoredRecord record) => utf8.decode(
    vault.session.records.decrypt(
      recordId: record.id,
      type: record.type,
      blob: record.blob,
    ),
  );

  Future<BackupFile> backupOf(_Vault vault) async {
    final bytes = await BackupService(
      sodium: sodium,
      store: vault.store,
    ).create(vault.session, DateTime.utc(2026, 11, 7));
    return RestoreService(sodium: sodium, store: vault.store).parse(bytes);
  }

  group('açma ve doğrulama', () {
    late _Vault a;
    late RestoreService restore;

    setUp(() async {
      a = await newVault(passwordA);
      restore = RestoreService(sodium: sodium, store: a.store);
    });

    tearDown(() => a.close());

    test('parolayla açılıyor, sayılar doğru', () async {
      await put(a, 1);
      await put(a, 2);
      await put(a, 3, type: 'otp');
      await SettingsRepository(
        store: a.store,
        session: a.session,
      ).save(AppSettings.defaults);

      final opened = await restore.openWithPassword(
        await backupOf(a),
        passwordA,
      );
      expect(opened.loginCount, 2);
      expect(opened.otpCount, 1);
      expect(opened.records, hasLength(4));
      expect(opened.createdAt, DateTime.utc(2026, 11, 7));
      opened.dispose();
    });

    test('senkron dosyası yedek gibi açılıyor', () async {
      await put(a, 1);
      await put(a, 2, type: 'otp');
      final records = await a.store.allRecords();
      final bytes = await BackupCodec(sodium).encode(
        header: a.session.header,
        vaultKey: a.session.vaultKey,
        records: records,
        createdAt: DateTime.utc(2026, 11, 7),
        sync: SyncInfo(
          device: 'a1b2c3',
          deleted: [
            StoredTombstone(id: id(9), deletedAt: DateTime.utc(2026, 7)),
          ],
        ),
      );

      final opened = await restore.openWithPassword(
        restore.parse(bytes),
        passwordA,
      );
      expect(opened.loginCount, 1);
      expect(opened.otpCount, 1);
      expect(opened.records, hasLength(2));
      opened.dispose();
    });

    test('kart ve notlar sayılıyor', () async {
      await put(a, 1);
      await put(a, 2, type: 'card');
      await put(a, 3, type: 'card');
      await put(a, 4, type: 'note');

      final opened = await restore.openWithPassword(
        await backupOf(a),
        passwordA,
      );
      expect(opened.loginCount, 1);
      expect(opened.cardCount, 2);
      expect(opened.noteCount, 1);
      opened.dispose();
    });

    test('biçime uymayan kart ya da not içeren yedek reddediliyor', () async {
      await put(a, 1, type: 'card', json: '{"version":99}');
      await expectLater(
        restore.openWithPassword(await backupOf(a), passwordA),
        throwsA(isA<InvalidBackupException>()),
      );
      await put(a, 1, type: 'card');
      await put(a, 2, type: 'note', json: '{"version":1}');
      await expectLater(
        restore.openWithPassword(await backupOf(a), passwordA),
        throwsA(isA<InvalidBackupException>()),
      );
    });

    test('kurtarma anahtarıyla açılıyor', () async {
      await put(a, 1);
      final opened = await restore.openWithRecoveryKey(
        await backupOf(a),
        a.recovery,
      );
      expect(opened.loginCount, 1);
      opened.dispose();
    });

    test('yanlış parola ve başka kasanın anahtarı açmıyor', () async {
      final file = await backupOf(a);
      await expectLater(
        restore.openWithPassword(file, 'yanlis-Parola-1234'),
        throwsA(isA<WrongSecretException>()),
      );
      final other = await newVault(passwordB);
      await expectLater(
        restore.openWithRecoveryKey(file, other.recovery),
        throwsA(isA<WrongSecretException>()),
      );
      await other.close();
    });

    test('içinde açılmayan bir kayıt olan yedek reddediliyor', () async {
      await put(a, 1);
      // Kayıt başka bir kimlikle şifrelenmiş gibi: AD tutmaz.
      final good = (await a.store.getRecord(id(1)))!;
      await a.store.putRecord(
        StoredRecord(
          id: id(2),
          type: 'login',
          blob: good.blob,
          createdAt: good.createdAt,
          updatedAt: good.updatedAt,
        ),
      );
      await expectLater(
        restore.openWithPassword(await backupOf(a), passwordA),
        throwsA(isA<CorruptedDataException>()),
      );
    });

    test('biçime uymayan kayıt içeren yedek reddediliyor', () async {
      await put(a, 1, json: '{"version":99}');
      await expectLater(
        restore.openWithPassword(await backupOf(a), passwordA),
        throwsA(isA<InvalidBackupException>()),
      );
      await put(a, 1);
      await put(a, 2, type: 'otp', json: '{"kind":"totp"}');
      await expectLater(
        restore.openWithPassword(await backupOf(a), passwordA),
        throwsA(isA<InvalidBackupException>()),
      );
    });
  });

  group('kasaya alma', () {
    late _Vault a;
    late _Vault b;

    setUp(() async {
      a = await newVault(passwordA);
      b = await newVault(passwordB);
    });

    tearDown(() async {
      await a.close();
      await b.close();
    });

    Future<OpenedBackup> openA() async {
      final file = await backupOf(a);
      return await RestoreService(
        sodium: sodium,
        store: b.store,
      ).openWithPassword(file, passwordA);
    }

    test('boş telefona kurulan kasa yedeğin parolasıyla açılıyor', () async {
      await put(a, 1);
      await put(a, 2, type: 'otp');
      final opened = await openA();

      final database = VaultDatabase(NativeDatabase.memory());
      final store = VaultStore(database);
      await RestoreService(sodium: sodium, store: store).replace(opened);
      opened.dispose();

      final service = VaultService(sodium: sodium, store: store);
      final header = (await service.readHeader())!;
      expect(header.toJsonString(), a.session.header.toJsonString());
      final outcome = await service.unlockWithPassword(header, passwordA);
      expect(outcome.attempt, isA<PasswordAccepted>());
      final records = await store.allRecords();
      // Yedekte ayar kaydı yoktu; son yedek zamanı için biri eklendi.
      expect(
        records.map((r) => r.type),
        unorderedEquals(<String>[
          'login',
          'otp',
          SettingsRepository.recordType,
        ]),
      );
      final login = records.singleWhere((r) => r.type == 'login');
      expect(
        utf8.decode(
          outcome.session!.records.decrypt(
            recordId: login.id,
            type: login.type,
            blob: login.blob,
          ),
        ),
        loginJson,
      );
      outcome.session!.dispose();
      await database.close();
    });

    test(
      'değiştirme eski kayıtları, parmak izi yuvasını ve sayacı siliyor',
      () async {
        await put(a, 1);
        await put(b, 7);
        await b.store.writeBiometricSlot(
          StoredBiometricSlot(iv: Uint8List(12), cipherText: Uint8List(48)),
        );
        await b.store.registerFailedAttempt(DateTime.utc(2026));
        final opened = await openA();

        await RestoreService(sodium: sodium, store: b.store).replace(opened);
        opened.dispose();

        expect(
          (await b.store.readHeader())!.toJsonString(),
          a.session.header.toJsonString(),
        );
        final records = await b.store.allRecords();
        // 0: yeni eklenen ayar kaydı.
        expect(records.map((r) => r.id.last), unorderedEquals(<int>[0, 1]));
        expect(await b.store.readBiometricSlot(), isNull);
        expect((await b.store.readUnlockAttempts()).failedAttempts, 0);
      },
    );

    test('geri yüklenen kasada son yedek zamanı yedeğin zamanı', () async {
      // Yedek dosyası kaydedildikten sonra yazılan zaman yedeğin içinde
      // eski kalır; geri yüklenince hatırlatıcı "hiç yedek yok" dememeli.
      await SettingsRepository(store: a.store, session: a.session).save(
        AppSettings.requireAuth.copyWith(lastBackupAt: DateTime.utc(2026, 10)),
      );
      final opened = await openA();
      await RestoreService(sodium: sodium, store: b.store).replace(opened);
      opened.dispose();

      final settings = await SettingsRepository(
        store: b.store,
        session: a.session,
      ).load();
      expect(settings.lastBackupAt, DateTime.utc(2026, 11, 7));
      // Diğer ayarlar olduğu gibi kaldı.
      expect(settings.otpRequireAuth, isTrue);
    });

    test('ayar kaydı olmayan yedekte son yedek zamanı yazılıyor', () async {
      // Ayarları hiç değiştirilmemiş kasanın ilk yedeği: ayar kaydı yok.
      // Telefonda Drive'dan geri yüklemede bulundu.
      await put(a, 1);
      final opened = await openA();
      expect(
        opened.records.where((r) => r.type == SettingsRepository.recordType),
        isEmpty,
      );
      await RestoreService(sodium: sodium, store: b.store).replace(opened);
      opened.dispose();

      final settings = await SettingsRepository(
        store: b.store,
        session: a.session,
      ).load();
      expect(settings.lastBackupAt, DateTime.utc(2026, 11, 7));
      expect(settings.otpRequireAuth, AppSettings.defaults.otpRequireAuth);
      expect(settings.autofillCopyOtp, AppSettings.defaults.autofillCopyOtp);
    });

    test('daha yeni son yedek zamanı korunuyor', () async {
      final later = DateTime.utc(2026, 12);
      await SettingsRepository(
        store: a.store,
        session: a.session,
      ).save(AppSettings.defaults.copyWith(lastBackupAt: later));
      final opened = await openA();
      await RestoreService(sodium: sodium, store: b.store).replace(opened);
      opened.dispose();

      final settings = await SettingsRepository(
        store: b.store,
        session: a.session,
      ).load();
      expect(settings.lastBackupAt, later);
    });

    group('otomatik yedek klasörü cihaza bağlı', () {
      const here = AutoBackupFolder(
        uri: 'content://x/tree/primary%3ABuTelefon',
        name: 'BuTelefon',
      );
      const there = AutoBackupFolder(
        uri: 'content://x/tree/primary%3AEskiTelefon',
        name: 'EskiTelefon',
      );

      Future<AppSettings> replaceWith({
        AppSettings? saved,
        AutoBackupFolder? keep,
      }) async {
        if (saved != null) {
          await SettingsRepository(
            store: a.store,
            session: a.session,
          ).save(saved);
        } else {
          await put(a, 1);
        }
        final opened = await openA();
        await RestoreService(
          sodium: sodium,
          store: b.store,
        ).replace(opened, autoBackupFolder: keep);
        opened.dispose();
        return await SettingsRepository(
          store: b.store,
          session: a.session,
        ).load();
      }

      test('bu cihazın klasörü yedektekinin yerine geçiyor', () async {
        final settings = await replaceWith(
          saved: AppSettings.requireAuth.withAutoBackupFolder(there),
          keep: here,
        );
        expect(settings.autoBackupFolder?.uri, here.uri);
        expect(settings.otpRequireAuth, isTrue);
      });

      test('klasörsüz eski yedekte de bu cihazın klasörü kalıyor', () async {
        final later = DateTime.utc(2026, 12);
        final settings = await replaceWith(
          saved: AppSettings.defaults.copyWith(lastBackupAt: later),
          keep: here,
        );
        expect(settings.autoBackupFolder?.uri, here.uri);
        expect(settings.lastBackupAt, later);
      });

      test(
        'ayar kaydı olmayan yedekte de bu cihazın klasörü kalıyor',
        () async {
          final settings = await replaceWith(keep: here);
          expect(settings.autoBackupFolder?.uri, here.uri);
          expect(settings.lastBackupAt, DateTime.utc(2026, 11, 7));
        },
      );

      test('bu cihazda klasör yoksa yedekteki kalıyor', () async {
        final settings = await replaceWith(
          saved: AppSettings.defaults.withAutoBackupFolder(there),
        );
        expect(settings.autoBackupFolder?.uri, there.uri);
      });
    });

    test('birleştirme kayıtları açık kasanın anahtarıyla yazıyor', () async {
      await put(a, 1);
      await put(a, 2, type: 'otp');
      await SettingsRepository(
        store: a.store,
        session: a.session,
      ).save(AppSettings.requireAuth);
      await put(b, 9);
      final opened = await openA();

      final counts = await RestoreService(
        sodium: sodium,
        store: b.store,
      ).merge(opened, b.session);
      opened.dispose();

      expect(counts.added, 2);
      expect(counts.updated, 0);
      final records = await b.store.allRecords();
      // Ayar kaydı alınmadı; B'nin kendi kaydı duruyor.
      expect(records.map((r) => r.type), isNot(contains('settings')));
      expect(records, hasLength(3));
      for (final record in records) {
        expect(
          () => readPlain(b, record),
          returnsNormally,
          reason: 'B kasası kendi anahtarıyla açabilmeli',
        );
      }
      expect(readPlain(b, records.singleWhere((r) => r.id.last == 2)), otpJson);
    });

    test(
      'birleştirilen kart ve not açık kasanın deposundan okunuyor',
      () async {
        await put(a, 1, type: 'card');
        await put(a, 2, type: 'note');
        final opened = await openA();

        await RestoreService(
          sodium: sodium,
          store: b.store,
        ).merge(opened, b.session);
        opened.dispose();

        final cards = await cardRepository(
          store: b.store,
          session: b.session,
          sodium: sodium,
        ).loadAll();
        final notes = await noteRepository(
          store: b.store,
          session: b.session,
          sodium: sodium,
        ).loadAll();
        expect(cards.items.single.content.number, '4111111111111111');
        expect(cards.unreadableCount, 0);
        expect(notes.items.single.content.text, 'gizli');
      },
    );

    test('aynı kimlikte yeni olan kalıyor', () async {
      // A'da 1 yeni, 2 eski; B'de 1 eski, 2 yeni.
      await put(a, 1, updatedAt: DateTime.utc(2026, 9));
      await put(a, 2, updatedAt: DateTime.utc(2026, 3));
      await put(b, 1, json: '{"eski":true}', updatedAt: DateTime.utc(2026, 5));
      await put(b, 2, json: '{"yeni":true}', updatedAt: DateTime.utc(2026, 8));
      final opened = await openA();

      final counts = await RestoreService(
        sodium: sodium,
        store: b.store,
      ).merge(opened, b.session);
      opened.dispose();

      expect(counts.updated, 1);
      expect(counts.kept, 1);
      expect(counts.added, 0);
      expect(readPlain(b, (await b.store.getRecord(id(1)))!), loginJson);
      expect(readPlain(b, (await b.store.getRecord(id(2)))!), '{"yeni":true}');
    });

    test('aynı kimlikte farklı türdeki kayda dokunulmuyor', () async {
      await put(a, 1, type: 'otp', updatedAt: DateTime.utc(2026, 12));
      await put(b, 1, json: '{"b":1}');
      final opened = await openA();
      final counts = await RestoreService(
        sodium: sodium,
        store: b.store,
      ).merge(opened, b.session);
      opened.dispose();
      expect(counts.kept, 1);
      expect((await b.store.getRecord(id(1)))!.type, 'login');
    });
  });

  test(
    'aynı kasanın yedeği kendine birleşince hiçbir şey değişmiyor',
    () async {
      final a = await newVault(passwordA);
      await put(a, 1);
      await put(a, 2, type: 'otp');
      final before = await a.store.allRecords();
      final opened = await RestoreService(
        sodium: sodium,
        store: a.store,
      ).openWithPassword(await backupOf(a), passwordA);
      final counts = await RestoreService(
        sodium: sodium,
        store: a.store,
      ).merge(opened, a.session);
      opened.dispose();
      expect(counts.added + counts.updated, 0);
      final after = await a.store.allRecords();
      for (final (i, record) in before.indexed) {
        expect(after[i].blob, record.blob);
      }
      await a.close();
    },
  );
}

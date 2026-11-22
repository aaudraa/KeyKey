import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/generator/application/generator_preferences.dart';
import 'package:keykey/features/generator/application/password_generator.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/application/login_search.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  late SodiumSumo sodium;
  late VaultDatabase database;
  late VaultStore store;
  late VaultSession session;
  late SettingsRepository repository;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() async {
    database = VaultDatabase(NativeDatabase.memory());
    store = VaultStore(database);
    final service = VaultService(sodium: sodium, store: store);
    final pending = await service.prepareVault('ilk-Ana-Parola-47');
    session = await service.confirmRecoveryKey(
      pending,
      pending.recoveryKeyText,
    );
    repository = SettingsRepository(store: store, session: session);
  });

  tearDown(() async {
    session.dispose();
    await database.close();
  });

  Future<void> putRaw(Uint8List blob, {String type = 'settings'}) =>
      store.putRecord(
        StoredRecord(
          id: SettingsRepository.recordId,
          type: type,
          blob: blob,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );

  Uint8List encrypt(String json) => session.records.encrypt(
    recordId: SettingsRepository.recordId,
    type: SettingsRepository.recordType,
    plainText: Uint8List.fromList(utf8.encode(json)),
  );

  test('kayıt yoksa varsayılanlar: ek onay kapalı', () async {
    expect((await repository.load()).otpRequireAuth, isFalse);
  });

  test('yazılan aynen okunuyor', () async {
    await repository.save(AppSettings.requireAuth);
    expect((await repository.load()).otpRequireAuth, isTrue);

    await repository.save(AppSettings.defaults);
    expect((await repository.load()).otpRequireAuth, isFalse);
    expect(await store.allRecords(), hasLength(1));
  });

  test(
    'okunamayan kayıtta ek onay açık sayılıyor, kayda dokunulmuyor',
    () async {
      await repository.save(AppSettings.defaults);
      final stored = (await store.getRecord(SettingsRepository.recordId))!;
      final tampered = Uint8List.fromList(stored.blob);
      tampered[tampered.length - 1] ^= 1;
      await putRaw(tampered);

      expect((await repository.load()).otpRequireAuth, isTrue);
      expect(
        (await store.getRecord(SettingsRepository.recordId))!.blob,
        tampered,
      );
    },
  );

  test('biçime uymayan içerik okunamaz sayılıyor', () async {
    for (final json in [
      '{"version":1}',
      '{"version":2,"otpRequireAuth":false}',
      '{"version":1,"otpRequireAuth":"false"}',
      '{"version":1,"otpRequireAuth":false,"fazla":1}',
      '[]',
      'bozuk',
    ]) {
      await putRaw(encrypt(json));
      expect((await repository.load()).otpRequireAuth, isTrue, reason: json);
    }
  });

  test('sürüm 1 kaydı okunuyor, kod kopyalama açık sayılıyor', () async {
    await putRaw(encrypt('{"version":1,"otpRequireAuth":true}'));
    final settings = await repository.load();
    expect(settings.otpRequireAuth, isTrue);
    expect(settings.autofillCopyOtp, isTrue);
  });

  test('kod kopyalama ayarı yazılıp okunuyor', () async {
    expect((await repository.load()).autofillCopyOtp, isTrue);
    await repository.save(
      AppSettings.defaults.copyWith(autofillCopyOtp: false),
    );
    final settings = await repository.load();
    expect(settings.autofillCopyOtp, isFalse);
    expect(settings.otpRequireAuth, isFalse);
  });

  test('okunamayan kayıtta kod kopyalama kapalı sayılıyor', () async {
    for (final json in [
      '{"version":2,"otpRequireAuth":false,"autofillCopyOtp":"evet"}',
      '{"version":3,"otpRequireAuth":false,"autofillCopyOtp":true}',
      '{"version":1,"otpRequireAuth":false,"autofillCopyOtp":true}',
    ]) {
      await putRaw(encrypt(json));
      final settings = await repository.load();
      expect(settings.autofillCopyOtp, isFalse, reason: json);
      expect(settings.otpRequireAuth, isTrue, reason: json);
    }
  });

  group('yedek bilgileri (sürüm 3)', () {
    test('sürüm 2 kaydı okunuyor, yedek bilgisi yok sayılıyor', () async {
      await putRaw(
        encrypt('{"version":2,"otpRequireAuth":false,"autofillCopyOtp":false}'),
      );
      final settings = await repository.load();
      expect(settings.autofillCopyOtp, isFalse);
      expect(settings.otpRequireAuth, isFalse);
      expect(settings.lastBackupAt, isNull);
      expect(settings.backupReminderSnoozedUntil, isNull);
    });

    test('yedek zamanları yazılıp okunuyor', () async {
      final backup = DateTime.utc(2026, 11, 7, 18, 30);
      final snooze = DateTime.utc(2026, 11, 14);
      await repository.save(
        AppSettings.defaults.copyWith(
          lastBackupAt: backup,
          backupReminderSnoozedUntil: snooze,
        ),
      );
      final settings = await repository.load();
      expect(settings.lastBackupAt, backup);
      expect(settings.backupReminderSnoozedUntil, snooze);
      expect(settings.autofillCopyOtp, isTrue);
    });

    test('copyWith yedek zamanını silmiyor', () {
      final backup = DateTime.utc(2026, 11, 7);
      final settings = AppSettings.defaults
          .copyWith(lastBackupAt: backup)
          .copyWith(otpRequireAuth: true);
      expect(settings.lastBackupAt, backup);
    });

    test('geçersiz zaman kaydı okunamaz yapıyor', () async {
      const head = '"version":3,"otpRequireAuth":false,"autofillCopyOtp":true';
      for (final json in [
        '{$head,"lastBackupAt":-1,"backupReminderSnoozedUntil":null}',
        '{$head,"lastBackupAt":"dün","backupReminderSnoozedUntil":null}',
        '{$head,"lastBackupAt":null,"backupReminderSnoozedUntil":1.5}',
        '{$head,"lastBackupAt":null}',
      ]) {
        await putRaw(encrypt(json));
        final settings = await repository.load();
        expect(settings.otpRequireAuth, isTrue, reason: json);
        expect(settings.lastBackupAt, isNull, reason: json);
      }
    });
  });

  group('sürüm 4: sıralama ve üretici', () {
    const v3 =
        '{"version":3,"otpRequireAuth":false,"autofillCopyOtp":true,'
        '"lastBackupAt":null,"backupReminderSnoozedUntil":null}';
    String v4(String sort, String generator) =>
        '{"version":4,"otpRequireAuth":false,"autofillCopyOtp":true,'
        '"lastBackupAt":null,"backupReminderSnoozedUntil":null,'
        '"vaultSort":$sort,"generator":$generator}';
    const generator =
        '{"passphrase":false,"length":20,"lowercase":true,'
        '"uppercase":true,"digits":true,"symbols":true,"words":6}';

    test(
      'sürüm 3 kaydı okunuyor, ada göre sıralama ve varsayılan üretici',
      () async {
        await putRaw(encrypt(v3));
        final settings = await repository.load();
        expect(settings.otpRequireAuth, isFalse);
        expect(settings.vaultSort, LoginSort.name);
        expect(settings.generator.passphrase, isFalse);
        expect(settings.generator.password.length, 20);
        expect(settings.generator.passphraseOptions.words, 6);
      },
    );

    test('sıralama ve üretici seçenekleri yazılıp okunuyor', () async {
      await repository.save(
        AppSettings.defaults.copyWith(
          vaultSort: LoginSort.recentlyUpdated,
          generator: const GeneratorPreferences(
            passphrase: true,
            password: PasswordOptions(length: 32, symbols: false),
            passphraseOptions: PassphraseOptions(words: 8),
          ),
        ),
      );
      final settings = await repository.load();
      expect(settings.vaultSort, LoginSort.recentlyUpdated);
      expect(settings.generator.passphrase, isTrue);
      expect(settings.generator.password.length, 32);
      expect(settings.generator.password.symbols, isFalse);
      expect(settings.generator.password.digits, isTrue);
      expect(settings.generator.passphraseOptions.words, 8);
      expect(settings.otpRequireAuth, isFalse);
    });

    test('copyWith sıralamayı ve üreticiyi koruyor', () {
      final settings = AppSettings.defaults
          .copyWith(vaultSort: LoginSort.recentlyUpdated)
          .copyWith(otpRequireAuth: true);
      expect(settings.vaultSort, LoginSort.recentlyUpdated);
    });

    test('geçersiz sıralama ya da üretici kaydı okunamaz yapıyor', () async {
      for (final json in [
        v4('"tarih"', generator),
        v4('null', generator),
        v4('"name"', generator.replaceFirst('"length":20', '"length":7')),
        v4('"name"', generator.replaceFirst('"length":20', '"length":65')),
        v4('"name"', generator.replaceFirst('"words":6', '"words":3')),
        v4('"name"', generator.replaceFirst('"words":6', '"words":13')),
        v4('"name"', generator.replaceFirst('"digits":true', '"digits":1')),
        v4(
          '"name"',
          '{"passphrase":false,"length":20,"lowercase":false,'
              '"uppercase":false,"digits":false,"symbols":false,"words":6}',
        ),
        v4('"name"', generator.replaceFirst('"words":6', '"words":6,"x":1')),
        v4('"name"', generator.replaceFirst(',"words":6', '')),
        v4('"name"', '[]'),
        v3.replaceFirst('"version":3', '"version":4'),
      ]) {
        await putRaw(encrypt(json));
        expect((await repository.load()).otpRequireAuth, isTrue, reason: json);
      }
    });
  });

  group('sürüm 5: otomatik yedek klasörü', () {
    const v4 =
        '{"version":4,"otpRequireAuth":false,"autofillCopyOtp":true,'
        '"lastBackupAt":null,"backupReminderSnoozedUntil":null,'
        '"vaultSort":"name","generator":{"passphrase":false,"length":20,'
        '"lowercase":true,"uppercase":true,"digits":true,"symbols":true,'
        '"words":6}}';
    String v5(String folder) => v4
        .replaceFirst('"version":4', '"version":5')
        .replaceFirst('"vaultSort"', '"autoBackupFolder":$folder,"vaultSort"');
    const folder = AutoBackupFolder(
      uri: 'content://com.android.externalstorage.documents/tree/primary%3ADocuments%2FKeyKey',
      name: 'KeyKey',
    );

    test('sürüm 4 kaydı okunuyor, otomatik yedek kapalı', () async {
      await putRaw(encrypt(v4));
      final settings = await repository.load();
      expect(settings.otpRequireAuth, isFalse);
      expect(settings.autoBackupFolder, isNull);
    });

    test('klasör yazılıp okunuyor', () async {
      await repository.save(AppSettings.defaults.withAutoBackupFolder(folder));
      final settings = await repository.load();
      expect(settings.autoBackupFolder?.uri, folder.uri);
      expect(settings.autoBackupFolder?.name, 'KeyKey');
      expect(settings.otpRequireAuth, isFalse);
    });

    test('klasörsüz sürüm 5 kaydı okunuyor', () async {
      await putRaw(encrypt(v5('null')));
      final settings = await repository.load();
      expect(settings.otpRequireAuth, isFalse);
      expect(settings.autoBackupFolder, isNull);
    });

    test('withAutoBackupFolder(null) klasörü siliyor, gerisini koruyor', () {
      final settings = AppSettings.defaults
          .copyWith(otpRequireAuth: true, vaultSort: LoginSort.recentlyUpdated)
          .withAutoBackupFolder(folder)
          .withAutoBackupFolder(null);
      expect(settings.autoBackupFolder, isNull);
      expect(settings.otpRequireAuth, isTrue);
      expect(settings.vaultSort, LoginSort.recentlyUpdated);
    });

    test('copyWith klasörü koruyor', () {
      final settings = AppSettings.defaults
          .withAutoBackupFolder(folder)
          .copyWith(otpRequireAuth: true);
      expect(settings.autoBackupFolder?.uri, folder.uri);
    });

    test('geçersiz klasör alanı kaydı okunamaz yapıyor', () async {
      for (final json in [
        v5('1'),
        v5('"content://x/tree/1"'),
        v5('{"uri":"content://x/tree/1"}'),
        v5('{"uri":"content://x/tree/1","name":""}'),
        v5('{"uri":"","name":"KeyKey"}'),
        v5('{"uri":"file:///sdcard/KeyKey","name":"KeyKey"}'),
        v5('{"uri":"content://x/tree/1","name":1}'),
        v5('{"uri":"content://x/tree/1","name":"KeyKey","x":1}'),
        v4.replaceFirst('"version":4', '"version":5'),
      ]) {
        await putRaw(encrypt(json));
        expect((await repository.load()).otpRequireAuth, isTrue, reason: json);
      }
    });
  });

  group('sürüm 6: arka plan kilidi ve klavye', () {
    const v5 =
        '{"version":5,"otpRequireAuth":false,"autofillCopyOtp":true,'
        '"lastBackupAt":null,"backupReminderSnoozedUntil":null,'
        '"vaultSort":"name","generator":{"passphrase":false,"length":20,'
        '"lowercase":true,"uppercase":true,"digits":true,"symbols":true,'
        '"words":6},"autoBackupFolder":null}';
    String v6(String seconds, String plain) => v5
        .replaceFirst('"version":5', '"version":6')
        .replaceFirst(
          '"autoBackupFolder"',
          '"backgroundLockSeconds":$seconds,"plainKeyboard":$plain,'
              '"autoBackupFolder"',
        );

    test('varsayılanlar: hemen kilit, gizli klavye', () {
      expect(AppSettings.defaults.backgroundLock, BackgroundLock.immediately);
      expect(AppSettings.defaults.plainKeyboard, isFalse);
      expect(
        AppSettings.requireAuth.backgroundLock,
        BackgroundLock.immediately,
      );
      expect(AppSettings.requireAuth.plainKeyboard, isFalse);
    });

    test('süreler: hemen 0, 30 saniye, 1 dakika', () {
      expect(BackgroundLock.immediately.delay, Duration.zero);
      expect(BackgroundLock.seconds30.delay, const Duration(seconds: 30));
      expect(BackgroundLock.minute1.delay, const Duration(minutes: 1));
    });

    test('sürüm 5 kaydı okunuyor, hemen kilit ve gizli klavye', () async {
      await putRaw(encrypt(v5));
      final settings = await repository.load();
      expect(settings.otpRequireAuth, isFalse);
      expect(settings.backgroundLock, BackgroundLock.immediately);
      expect(settings.plainKeyboard, isFalse);
    });

    test('yazılan sürüm 6 kaydı aynen okunuyor', () async {
      await repository.save(
        AppSettings.defaults.copyWith(
          backgroundLock: BackgroundLock.minute1,
          plainKeyboard: true,
        ),
      );
      final settings = await repository.load();
      expect(settings.backgroundLock, BackgroundLock.minute1);
      expect(settings.plainKeyboard, isTrue);
      expect(settings.otpRequireAuth, isFalse);
      final json = jsonDecode(
        utf8.decode(settings.toJsonBytes()),
      ) as Map<String, Object?>;
      expect(json['version'], AppSettings.currentVersion);
      expect(json['backgroundLockSeconds'], 60);
      expect(json['plainKeyboard'], isTrue);
    });

    test('elle yazılmış sürüm 6 kaydı okunuyor', () async {
      await putRaw(encrypt(v6('30', 'true')));
      final settings = await repository.load();
      expect(settings.backgroundLock, BackgroundLock.seconds30);
      expect(settings.plainKeyboard, isTrue);
    });

    test('copyWith ve withAutoBackupFolder yeni alanları koruyor', () {
      final settings = AppSettings.defaults
          .copyWith(
            backgroundLock: BackgroundLock.seconds30,
            plainKeyboard: true,
          )
          .withAutoBackupFolder(null)
          .copyWith(otpRequireAuth: true);
      expect(settings.backgroundLock, BackgroundLock.seconds30);
      expect(settings.plainKeyboard, isTrue);
    });

    test('geçersiz süre ya da klavye alanı kaydı okunamaz yapıyor', () async {
      for (final json in [
        v6('45', 'false'),
        v6('-30', 'false'),
        v6('"30"', 'false'),
        v6('30.0', 'false'),
        v6('null', 'false'),
        v6('30', '1'),
        v6('30', 'null'),
        v6('30', '"true"'),
        v5.replaceFirst('"version":5', '"version":6'),
      ]) {
        await putRaw(encrypt(json));
        final settings = await repository.load();
        expect(settings.otpRequireAuth, isTrue, reason: json);
        expect(settings.backgroundLock, BackgroundLock.immediately);
        expect(settings.plainKeyboard, isFalse);
      }
    });
  });

  group('sürüm 7: senkron', () {
    const v6 =
        '{"version":6,"otpRequireAuth":false,"autofillCopyOtp":true,'
        '"lastBackupAt":null,"backupReminderSnoozedUntil":null,'
        '"vaultSort":"name","generator":{"passphrase":false,"length":20,'
        '"lowercase":true,"uppercase":true,"digits":true,"symbols":true,'
        '"words":6},"autoBackupFolder":null,"backgroundLockSeconds":30,'
        '"plainKeyboard":true}';
    final digest = 'ab' * 32;
    final sync = SyncSettings(
      folder: Uri.parse(
        'https://bulut.example.com/remote.php/dav/files/ayse/KeyKey',
      ),
      username: 'ayse',
      appPassword: 'uygulama-parolasi-123',
      lastSyncAt: DateTime.utc(2026, 11, 20, 18),
      lastDigest: digest,
    );

    String v7(String syncJson) => v6
        .replaceFirst('"version":6', '"version":7')
        .replaceFirst(
          '"plainKeyboard":true}',
          '"plainKeyboard":true,'
              '"sync":$syncJson}',
        );

    String syncJson({
      String folder = '"https://bulut.example.com/KeyKey"',
      String username = '"ayse"',
      String appPassword = '"parola"',
      String lastSyncAt = 'null',
      String lastDigest = 'null',
      String extra = '',
    }) =>
        '{"folder":$folder,"username":$username,"appPassword":$appPassword,'
        '"lastSyncAt":$lastSyncAt,"lastDigest":$lastDigest$extra}';

    test('sürüm 6 kaydı okunuyor, senkron kapalı', () async {
      await putRaw(encrypt(v6));
      final settings = await repository.load();
      expect(settings.sync, isNull);
      expect(settings.backgroundLock, BackgroundLock.seconds30);
      expect(settings.plainKeyboard, isTrue);
    });

    test('senkron bilgileri yazılıp okunuyor', () async {
      await repository.save(AppSettings.defaults.withSync(sync));

      final settings = await repository.load();
      expect(settings.sync?.folder, sync.folder);
      expect(settings.sync?.username, 'ayse');
      expect(settings.sync?.appPassword, 'uygulama-parolasi-123');
      expect(settings.sync?.lastSyncAt, DateTime.utc(2026, 11, 20, 18));
      expect(settings.sync?.lastDigest, digest);
      final json = jsonDecode(
        utf8.decode(settings.toJsonBytes()),
      ) as Map<String, Object?>;
      expect(json['version'], AppSettings.currentVersion);
      expect((json['sync']! as Map).keys, {
        'folder',
        'username',
        'appPassword',
        'lastSyncAt',
        'lastDigest',
      });
    });

    test('elle yazılmış sürüm 7 kaydı okunuyor', () async {
      await putRaw(encrypt(v7(syncJson(lastSyncAt: '5'))));
      final settings = await repository.load();
      expect(settings.sync?.username, 'ayse');
      expect(
        settings.sync?.lastSyncAt,
        DateTime.fromMillisecondsSinceEpoch(5, isUtc: true),
      );
      await putRaw(encrypt(v7('null')));
      expect((await repository.load()).sync, isNull);
    });

    test('withSync değiştiriyor, öteki yollar koruyor', () {
      final settings = AppSettings.defaults
          .withSync(sync)
          .copyWith(otpRequireAuth: true)
          .withAutoBackupFolder(null);
      expect(settings.sync?.username, 'ayse');
      expect(settings.otpRequireAuth, isTrue);
      expect(settings.withSync(null).sync, isNull);
      expect(settings.withSync(null).otpRequireAuth, isTrue);
    });

    test('uygulama parolası metne dökülmüyor', () {
      expect('$sync', isNot(contains('uygulama-parolasi-123')));
      expect('$sync', isNot(contains('ayse')));
    });

    test('yerel adreste şifresiz bağlantıya izin var', () async {
      for (final folder in [
        '"http://127.0.0.1:8080/keykey"',
        '"http://localhost/keykey"',
        '"http://[::1]:8080/keykey"',
      ]) {
        await putRaw(encrypt(v7(syncJson(folder: folder))));
        expect((await repository.load()).sync, isNotNull, reason: folder);
      }
    });

    test('geçersiz senkron alanı kaydı okunamaz yapıyor', () async {
      for (final json in [
        v7(syncJson(folder: '"http://bulut.example.com/KeyKey"')),
        v7(syncJson(folder: '"https://ayse:parola@bulut.example.com/K"')),
        v7(syncJson(folder: '"https://bulut.example.com/K?a=1"')),
        v7(syncJson(folder: '"https://bulut.example.com/K#a"')),
        v7(syncJson(folder: '"ftp://bulut.example.com/K"')),
        v7(syncJson(folder: '"https:///K"')),
        v7(syncJson(folder: '3')),
        v7(syncJson(username: '""')),
        v7(syncJson(appPassword: '""')),
        v7(syncJson(appPassword: 'null')),
        v7(syncJson(lastSyncAt: '-1')),
        v7(syncJson(lastDigest: '"abc"')),
        v7(syncJson(lastDigest: '"${'AB' * 32}"')),
        v7(syncJson(extra: ',"ek":1')),
        v7('{"folder":"https://bulut.example.com/K"}'),
        v6.replaceFirst('"version":6', '"version":7'),
      ]) {
        await putRaw(encrypt(json));
        final settings = await repository.load();
        expect(settings.otpRequireAuth, isTrue, reason: json);
        expect(settings.sync, isNull, reason: json);
      }
    });
  });

  group('sürüm 8: uygulamanın sitesini doğrulama', () {
    const v7 =
        '{"version":7,"otpRequireAuth":false,"autofillCopyOtp":true,'
        '"lastBackupAt":null,"backupReminderSnoozedUntil":null,'
        '"vaultSort":"name","generator":{"passphrase":false,"length":20,'
        '"lowercase":true,"uppercase":true,"digits":true,"symbols":true,'
        '"words":6},"autoBackupFolder":null,"backgroundLockSeconds":30,'
        '"plainKeyboard":true,"sync":null}';

    String v8(String value) => v7
        .replaceFirst('"version":7', '"version":8')
        .replaceFirst(
          '"sync":null}',
          '"sync":null,"autofillVerifySites":$value}',
        );

    test('varsayılan kapalı, ek onayda da kapalı', () {
      expect(AppSettings.defaults.autofillVerifySites, isFalse);
      expect(AppSettings.requireAuth.autofillVerifySites, isFalse);
    });

    test('sürüm 7 kaydı okunuyor, ayar kapalı', () async {
      await putRaw(encrypt(v7));
      final settings = await repository.load();
      expect(settings.otpRequireAuth, isFalse);
      expect(settings.autofillVerifySites, isFalse);
      expect(settings.plainKeyboard, isTrue);
    });

    test('yazılıp okunuyor, sürüm 8', () async {
      await repository.save(
        AppSettings.defaults.copyWith(autofillVerifySites: true),
      );
      final settings = await repository.load();
      expect(settings.autofillVerifySites, isTrue);
      final json = jsonDecode(
        utf8.decode(settings.toJsonBytes()),
      ) as Map<String, Object?>;
      expect(json['version'], 8);
      expect(json['autofillVerifySites'], isTrue);
    });

    test('elle yazılmış sürüm 8 kaydı okunuyor', () async {
      await putRaw(encrypt(v8('true')));
      expect((await repository.load()).autofillVerifySites, isTrue);
    });

    test('öteki yollar ayarı koruyor', () {
      final settings = AppSettings.defaults
          .copyWith(autofillVerifySites: true)
          .withAutoBackupFolder(null)
          .withSync(null)
          .withoutBackupHistory()
          .copyWith(otpRequireAuth: true);
      expect(settings.autofillVerifySites, isTrue);
    });

    test('geçersiz değer kaydı okunamaz yapıyor', () async {
      for (final json in [
        v8('1'),
        v8('null'),
        v8('"true"'),
        v7.replaceFirst('"version":7', '"version":8'),
      ]) {
        await putRaw(encrypt(json));
        final settings = await repository.load();
        expect(settings.otpRequireAuth, isTrue, reason: json);
        expect(settings.autofillVerifySites, isFalse, reason: json);
      }
    });
  });

  test('aynı kimlikte başka türden kayıt okunamaz sayılıyor', () async {
    await putRaw(Uint8List(64), type: 'login');
    expect((await repository.load()).otpRequireAuth, isTrue);
  });

  test('ayar kaydı parola ve 2FA listelerine karışmıyor', () async {
    await repository.save(AppSettings.requireAuth);

    final logins = LoginRepository(
      store: store,
      session: session,
      sodium: sodium,
    );
    final otps = OtpRepository(store: store, session: session, sodium: sodium);
    expect((await logins.loadAll()).unreadableCount, 0);
    expect((await otps.loadAll()).unreadableCount, 0);
  });

  test('kimlik her seferinde yeni bir dizi', () {
    final first = SettingsRepository.recordId..[0] = 9;
    expect(first[0], 9);
    expect(SettingsRepository.recordId[0], 0);
  });
}

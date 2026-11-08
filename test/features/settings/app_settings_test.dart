import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
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

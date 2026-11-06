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

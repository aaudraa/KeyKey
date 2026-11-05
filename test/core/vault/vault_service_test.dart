import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  const password = 'ilk-Ana-Parola-47';
  const newPassword = 'ikinci-Ana-Parola-58';

  late SodiumSumo sodium;
  late VaultDatabase database;
  late VaultStore store;
  late VaultService service;
  late DateTime now;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    database = VaultDatabase(NativeDatabase.memory());
    store = VaultStore(database);
    now = DateTime.utc(2026, 11, 5, 12);
    service = VaultService(sodium: sodium, store: store, clock: () => now);
  });

  tearDown(() => database.close());

  /// Kasayı kurar. Sonuç oturumu ve kurtarma anahtarı metni.
  Future<(VaultSession, String)> createVault() async {
    final pending = await service.prepareVault(password);
    final text = pending.recoveryKeyText;
    final session = await service.confirmRecoveryKey(pending, text);
    addTearDown(session.dispose);
    return (session, text);
  }

  group('kasa oluşturma', () {
    test('doğrulama olmadan diske bir şey yazılmıyor', () async {
      final pending = await service.prepareVault(password);
      addTearDown(pending.dispose);

      expect(await service.readHeader(), isNull);
    });

    test('kurtarma anahtarı yazılınca kasa kuruluyor ve açılıyor', () async {
      final (session, _) = await createVault();

      final stored = await service.readHeader();
      expect(stored?.toJsonString(), session.header.toJsonString());
    });

    test('yanlış biçimli anahtar diske yazdırmıyor', () async {
      final pending = await service.prepareVault(password);
      addTearDown(pending.dispose);

      await expectLater(
        service.confirmRecoveryKey(pending, 'bu-bir-anahtar-degil'),
        throwsA(isA<InvalidRecoveryKeyException>()),
      );
      expect(await service.readHeader(), isNull);
    });

    test('başka kasanın anahtarı diske yazdırmıyor', () async {
      final other = await service.prepareVault(password);
      addTearDown(other.dispose);
      final pending = await service.prepareVault(password);
      addTearDown(pending.dispose);

      await expectLater(
        service.confirmRecoveryKey(pending, other.recoveryKeyText),
        throwsA(isA<WrongSecretException>()),
      );
      expect(await service.readHeader(), isNull);
    });

    test('kısa parola reddediliyor', () {
      expect(service.prepareVault('kisa'), throwsArgumentError);
    });
  });

  group('parolayla açma', () {
    test('doğru parola kasayı açıyor ve kayıtlar okunuyor', () async {
      final (session, _) = await createVault();
      final recordId = sodium.randombytes.buf(16);
      final plain = Uint8List.fromList(utf8.encode('gizli içerik'));
      final blob = session.records.encrypt(
        recordId: recordId,
        type: 'login',
        plainText: plain,
      );

      final outcome = await service.unlockWithPassword(
        session.header,
        password,
      );
      addTearDown(outcome.session!.dispose);

      expect(outcome.attempt, isA<PasswordAccepted>());
      expect(
        outcome.session!.records.decrypt(
          recordId: recordId,
          type: 'login',
          blob: blob,
        ),
        plain,
      );
    });

    test('yanlış parola açmıyor ve sayacı artırıyor', () async {
      final (session, _) = await createVault();

      final outcome = await service.unlockWithPassword(
        session.header,
        'yanlis-parola-99',
      );

      expect(outcome.attempt, isA<PasswordRejected>());
      expect(outcome.session, isNull);
      final attempts = await store.readUnlockAttempts();
      expect(attempts.failedAttempts, 1);
    });

    test('doğru parola sayacı sıfırlıyor', () async {
      final (session, _) = await createVault();
      await service.unlockWithPassword(session.header, 'yanlis-parola-99');

      final outcome = await service.unlockWithPassword(
        session.header,
        password,
      );
      addTearDown(outcome.session!.dispose);

      final attempts = await store.readUnlockAttempts();
      expect(attempts.failedAttempts, 0);
    });

    test('bekleme sürerken parola hiç denenmiyor', () async {
      final (session, _) = await createVault();
      for (var i = 0; i < 4; i++) {
        await store.registerFailedAttempt(now);
      }

      final outcome = await service.unlockWithPassword(
        session.header,
        password,
      );

      expect(outcome.session, isNull);
      expect(
        outcome.attempt,
        isA<PasswordMustWait>().having(
          (attempt) => attempt.wait,
          'wait',
          const Duration(seconds: 5),
        ),
      );
      // Denenmeyen parola sayacı artırmaz.
      final attempts = await store.readUnlockAttempts();
      expect(attempts.failedAttempts, 4);
    });

    test('bekleme bitince doğru parola açıyor', () async {
      final (session, _) = await createVault();
      for (var i = 0; i < 4; i++) {
        await store.registerFailedAttempt(now);
      }
      now = now.add(const Duration(seconds: 6));

      final outcome = await service.unlockWithPassword(
        session.header,
        password,
      );
      addTearDown(outcome.session!.dispose);

      expect(outcome.attempt, isA<PasswordAccepted>());
    });

    test('yanlış parola sonrası kalan bekleme bildiriliyor', () async {
      final (session, _) = await createVault();
      for (var i = 0; i < 3; i++) {
        await store.registerFailedAttempt(
          now.subtract(const Duration(hours: 1)),
        );
      }

      final outcome = await service.unlockWithPassword(
        session.header,
        'yanlis-parola-99',
      );

      expect(
        outcome.attempt,
        isA<PasswordRejected>().having(
          (attempt) => attempt.wait,
          'wait',
          const Duration(seconds: 5),
        ),
      );
    });

    test('saat geri alınınca bekleme atlanamıyor', () async {
      final (session, _) = await createVault();
      for (var i = 0; i < 8; i++) {
        await store.registerFailedAttempt(now);
      }

      now = now.subtract(const Duration(days: 30));
      final outcome = await service.unlockWithPassword(
        session.header,
        password,
      );

      expect(
        outcome.attempt,
        isA<PasswordMustWait>().having(
          (attempt) => attempt.wait,
          'wait',
          const Duration(minutes: 5),
        ),
      );
      // Süre geçmiş saate göre yeniden işliyor.
      final attempts = await store.readUnlockAttempts();
      expect(attempts.lastFailedAt, now);

      now = now.add(const Duration(minutes: 1));
      expect(await service.remainingWait(), const Duration(minutes: 4));
    });

    test('sayaç yeniden açılan veritabanında korunuyor', () async {
      final (session, _) = await createVault();
      await service.unlockWithPassword(session.header, 'yanlis-parola-99');

      final restarted = VaultService(
        sodium: sodium,
        store: VaultStore(database),
        clock: () => now,
      );
      await restarted.unlockWithPassword(session.header, 'yanlis-parola-99');

      final attempts = await store.readUnlockAttempts();
      expect(attempts.failedAttempts, 2);
    });
  });

  group('ana parola değiştirme', () {
    test('kayıtlar okunabilir kalıyor, eski parola çalışmıyor', () async {
      final (session, text) = await createVault();
      final recordId = sodium.randombytes.buf(16);
      final plain = Uint8List.fromList(utf8.encode('gizli içerik'));
      final blob = session.records.encrypt(
        recordId: recordId,
        type: 'login',
        plainText: plain,
      );

      final attempt = await service.changePassword(
        session,
        currentPassword: password,
        newPassword: newPassword,
      );
      expect(attempt, isA<PasswordAccepted>());

      final stored = (await service.readHeader())!;
      expect(stored.toJsonString(), session.header.toJsonString());

      final old = await service.unlockWithPassword(stored, password);
      expect(old.attempt, isA<PasswordRejected>());

      final fresh = await service.unlockWithPassword(stored, newPassword);
      addTearDown(fresh.session!.dispose);
      expect(
        fresh.session!.records.decrypt(
          recordId: recordId,
          type: 'login',
          blob: blob,
        ),
        plain,
      );

      final recovered = service.unlockWithRecoveryKey(stored, text);
      addTearDown(recovered.dispose);
      expect(
        recovered.records.decrypt(
          recordId: recordId,
          type: 'login',
          blob: blob,
        ),
        plain,
      );
    });

    test('mevcut parola yanlışsa hiçbir şey değişmiyor', () async {
      final (session, _) = await createVault();
      final before = session.header.toJsonString();

      final attempt = await service.changePassword(
        session,
        currentPassword: 'yanlis-parola-99',
        newPassword: newPassword,
      );

      expect(attempt, isA<PasswordRejected>());
      expect(session.header.toJsonString(), before);
      final stored = await service.readHeader();
      expect(stored?.toJsonString(), before);
    });

    test('kısa yeni parola reddediliyor', () async {
      final (session, _) = await createVault();

      expect(
        service.changePassword(
          session,
          currentPassword: password,
          newPassword: 'kisa',
        ),
        throwsArgumentError,
      );
    });
  });

  group('kurtarma anahtarıyla erişim', () {
    test('doğru anahtar açıyor, yeni parola belirlenebiliyor', () async {
      final (session, text) = await createVault();
      await service.unlockWithPassword(session.header, 'yanlis-parola-99');

      final recovered = service.unlockWithRecoveryKey(session.header, text);
      addTearDown(recovered.dispose);
      await service.setNewPassword(recovered, newPassword);

      final attempts = await store.readUnlockAttempts();
      expect(attempts.failedAttempts, 0);

      final stored = (await service.readHeader())!;
      final fresh = await service.unlockWithPassword(stored, newPassword);
      addTearDown(fresh.session!.dispose);
      expect(fresh.attempt, isA<PasswordAccepted>());

      final old = await service.unlockWithPassword(stored, password);
      expect(old.attempt, isA<PasswordRejected>());
    });

    test('geçersiz metin temiz hata veriyor', () async {
      final (session, _) = await createVault();

      expect(
        () => service.unlockWithRecoveryKey(session.header, 'gecersiz'),
        throwsA(isA<InvalidRecoveryKeyException>()),
      );
    });
  });
}

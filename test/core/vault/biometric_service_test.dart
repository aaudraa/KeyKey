import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/biometric_bridge.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:sodium/sodium_sumo.dart';

/// Keystore'u taklit eder: AD yanlışsa açmaz, [next] verilirse onu döndürür.
class FakeBridge implements BiometricBridge {
  BiometricSupport supportValue = BiometricSupport.available;
  Object? next;
  bool keyDeleted = false;
  Uint8List? wrapAd;
  Uint8List? receivedPlain;
  Uint8List? lastUnwrapped;

  static const _tag = 16;

  @override
  Future<BiometricSupport> support() async => supportValue;

  @override
  Future<BiometricOutcome<StoredBiometricSlot>> wrap(
    Uint8List plainText,
    Uint8List associatedData,
    BiometricTexts texts,
  ) async {
    final forced = next;
    if (forced is BiometricOutcome<StoredBiometricSlot>) return forced;
    wrapAd = associatedData;
    receivedPlain = Uint8List.fromList(plainText);
    // Gerçek şifreleme değil, yalnızca yuva uzunluğunu doğru üretir.
    final cipherText = Uint8List(plainText.length + _tag)
      ..setRange(0, plainText.length, plainText.map((byte) => byte ^ 0x5A));
    return BiometricSuccess(
      StoredBiometricSlot(iv: Uint8List(12), cipherText: cipherText),
    );
  }

  @override
  Future<BiometricOutcome<Uint8List>> unwrap(
    StoredBiometricSlot slot,
    Uint8List associatedData,
    BiometricTexts texts,
  ) async {
    final forced = next;
    if (forced is BiometricOutcome<Uint8List>) return forced;
    if (!listEquals(wrapAd, associatedData)) return const BiometricFailed();
    final plain = Uint8List.fromList(
      slot.cipherText
          .sublist(0, slot.cipherText.length - _tag)
          .map((byte) => byte ^ 0x5A)
          .toList(),
    );
    lastUnwrapped = plain;
    return BiometricSuccess(plain);
  }

  @override
  Future<void> deleteKey() async {
    keyDeleted = true;
  }
}

void main() {
  const password = 'ilk-Ana-Parola-47';
  const texts = BiometricTexts(title: 'Başlık', negativeButton: 'Vazgeç');

  late SodiumSumo sodium;
  late VaultDatabase database;
  late VaultStore store;
  late FakeBridge bridge;
  late VaultService service;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    database = VaultDatabase(NativeDatabase.memory());
    store = VaultStore(database);
    bridge = FakeBridge();
    service = VaultService(sodium: sodium, store: store, biometric: bridge);
  });

  tearDown(() => database.close());

  Future<VaultSession> createVault() async {
    final pending = await service.prepareVault(password);
    final session = await service.confirmRecoveryKey(
      pending,
      pending.recoveryKeyText,
    );
    addTearDown(session.dispose);
    return session;
  }

  group('etkinleştirme', () {
    test('yuvayı yazıyor, kasa kimliğine bağlı AD kullanıyor', () async {
      final session = await createVault();

      final outcome = await service.enableBiometric(session, texts);

      expect(outcome, isA<BiometricSuccess<void>>());
      expect(await service.isBiometricEnabled(), isTrue);
      expect(await store.readBiometricSlot(), isNotNull);
      expect(bridge.receivedPlain, session.vaultKey.extractBytes());
      expect(
        utf8.decode(bridge.wrapAd!, allowMalformed: true),
        contains('biometric'),
      );
    });

    test('vazgeçilirse yuva yazılmıyor', () async {
      final session = await createVault();
      bridge.next = const BiometricCancelled<StoredBiometricSlot>();

      final outcome = await service.enableBiometric(session, texts);

      expect(outcome, isA<BiometricCancelled<void>>());
      expect(await service.isBiometricEnabled(), isFalse);
    });

    test('üst bilgi değişmiyor, biçim v1 korunuyor', () async {
      final session = await createVault();
      final before = (await service.readHeader())!.toJsonString();

      await service.enableBiometric(session, texts);

      expect((await service.readHeader())!.toJsonString(), before);
    });

    test('köprü yoksa yuva yazılmıyor', () async {
      final session = await createVault();
      final noBridge = VaultService(sodium: sodium, store: store);

      final outcome = await noBridge.enableBiometric(session, texts);

      expect(outcome, isA<BiometricFailed<void>>());
      expect(await noBridge.biometricSupport(), BiometricSupport.unavailable);
    });
  });

  group('parmak iziyle açma', () {
    test('aynı kasa anahtarını açıyor, kayıtlar okunuyor', () async {
      final session = await createVault();
      await service.enableBiometric(session, texts);
      final recordId = sodium.randombytes.buf(16);
      final plain = Uint8List.fromList(utf8.encode('gizli içerik'));
      final blob = session.records.encrypt(
        recordId: recordId,
        type: 'login',
        plainText: plain,
      );

      final outcome = await service.unlockWithBiometric(session.header, texts);

      final opened = (outcome as BiometricSuccess<VaultSession>).value;
      addTearDown(opened.dispose);
      expect(
        opened.records.decrypt(recordId: recordId, type: 'login', blob: blob),
        plain,
      );
    });

    test("Keystore'dan gelen ham baytlar sıfırlanıyor", () async {
      final session = await createVault();
      await service.enableBiometric(session, texts);

      final outcome = await service.unlockWithBiometric(session.header, texts);
      addTearDown((outcome as BiometricSuccess<VaultSession>).value.dispose);

      expect(bridge.lastUnwrapped, everyElement(0));
    });

    test('başarılı açma hatalı deneme sayacını sıfırlıyor', () async {
      final session = await createVault();
      await service.enableBiometric(session, texts);
      await store.registerFailedAttempt(DateTime.utc(2026));

      final outcome = await service.unlockWithBiometric(session.header, texts);
      addTearDown((outcome as BiometricSuccess<VaultSession>).value.dispose);

      expect((await store.readUnlockAttempts()).failedAttempts, 0);
    });

    test('başka kasanın yuvası açılmıyor', () async {
      final session = await createVault();
      await service.enableBiometric(session, texts);
      bridge.wrapAd = Uint8List.fromList([1, 2, 3]);

      final outcome = await service.unlockWithBiometric(session.header, texts);

      expect(outcome, isA<BiometricFailed<VaultSession>>());
    });

    test('yanlış uzunlukta anahtar kabul edilmiyor', () async {
      final session = await createVault();
      await service.enableBiometric(session, texts);
      bridge.next = BiometricSuccess<Uint8List>(Uint8List(16));

      final outcome = await service.unlockWithBiometric(session.header, texts);

      expect(outcome, isA<BiometricFailed<VaultSession>>());
    });

    test('yuva yoksa açılmıyor', () async {
      final session = await createVault();

      final outcome = await service.unlockWithBiometric(session.header, texts);

      expect(outcome, isA<BiometricFailed<VaultSession>>());
    });

    test('parola değişince yuva çalışmaya devam ediyor', () async {
      final session = await createVault();
      await service.enableBiometric(session, texts);

      await service.changePassword(
        session,
        currentPassword: password,
        newPassword: 'ikinci-Ana-Parola-58',
      );

      final outcome = await service.unlockWithBiometric(session.header, texts);
      addTearDown((outcome as BiometricSuccess<VaultSession>).value.dispose);
      expect(await service.isBiometricEnabled(), isTrue);
    });
  });

  group('anahtar geçersiz olunca', () {
    test('yuva ve anahtar siliniyor, ana parola çalışıyor', () async {
      final session = await createVault();
      await service.enableBiometric(session, texts);
      bridge.next = const BiometricInvalidated<Uint8List>();

      final outcome = await service.unlockWithBiometric(session.header, texts);

      expect(outcome, isA<BiometricInvalidated<VaultSession>>());
      expect(await service.isBiometricEnabled(), isFalse);
      expect(bridge.keyDeleted, isTrue);

      final byPassword = await service.unlockWithPassword(
        session.header,
        password,
      );
      addTearDown(byPassword.session!.dispose);
      expect(byPassword.attempt, isA<PasswordAccepted>());
    });

    test('vazgeçmek ve kilitlenme yuvayı silmiyor', () async {
      final session = await createVault();
      await service.enableBiometric(session, texts);

      for (final outcome in const [
        BiometricCancelled<Uint8List>(),
        BiometricLockedOut<Uint8List>(),
        BiometricFailed<Uint8List>(),
      ]) {
        bridge.next = outcome;
        await service.unlockWithBiometric(session.header, texts);
        expect(await service.isBiometricEnabled(), isTrue);
      }
    });

    test('tüm parmak izleri silindiyse yuva da siliniyor', () async {
      final session = await createVault();
      await service.enableBiometric(session, texts);
      bridge.supportValue = BiometricSupport.notEnrolled;

      expect(await service.isBiometricUsable(), isFalse);
      expect(await service.isBiometricEnabled(), isFalse);
      expect(bridge.keyDeleted, isTrue);
    });

    test('donanım geçici yoksa yuva korunuyor', () async {
      final session = await createVault();
      await service.enableBiometric(session, texts);
      bridge.supportValue = BiometricSupport.noHardware;

      expect(await service.isBiometricUsable(), isFalse);
      expect(await service.isBiometricEnabled(), isTrue);
    });
  });

  group('kapatma', () {
    test('yuva ve anahtar siliniyor', () async {
      final session = await createVault();
      await service.enableBiometric(session, texts);

      await service.disableBiometric();

      expect(await service.isBiometricEnabled(), isFalse);
      expect(bridge.keyDeleted, isTrue);
    });
  });
}

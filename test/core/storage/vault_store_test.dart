import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/storage/storage_exceptions.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:sodium/sodium_sumo.dart';

import 'test_data.dart';

void main() {
  late VaultDatabase database;
  late VaultStore store;

  final now = DateTime.utc(2026, 11, 5, 12);
  final recordId = Uint8List(16)..fillRange(0, 16, 7);

  StoredRecord record({List<int> blob = const [1, 2, 3], DateTime? updatedAt}) {
    return StoredRecord(
      id: recordId,
      type: 'login',
      blob: Uint8List.fromList(blob),
      createdAt: now,
      updatedAt: updatedAt ?? now,
    );
  }

  setUp(() {
    database = VaultDatabase(NativeDatabase.memory());
    store = VaultStore(database);
  });

  tearDown(() => database.close());

  group('üst bilgi', () {
    test('kurulu değilse boş dönüyor', () async {
      expect(await store.readHeader(), isNull);
    });

    test('yazılan aynen okunuyor', () async {
      final header = sampleHeader();
      await store.createVault(header);

      final read = await store.readHeader();
      expect(read?.toJsonString(), header.toJsonString());
    });

    test('kurulu kasanın üzerine yeni kasa yazılamıyor', () async {
      await store.createVault(sampleHeader());

      await expectLater(
        store.createVault(sampleHeader(fill: 2)),
        throwsA(isA<VaultAlreadyExistsException>()),
      );
      final read = await store.readHeader();
      expect(read?.toJsonString(), sampleHeader().toJsonString());
    });

    test('güncelleme eskisinin yerine geçiyor', () async {
      await store.createVault(sampleHeader());
      final updated = sampleHeader(fill: 2);

      await store.updateHeader(updated);

      final read = await store.readHeader();
      expect(read?.toJsonString(), updated.toJsonString());
    });

    test('kurulu olmayan kasa güncellenemiyor', () {
      expect(
        store.updateHeader(sampleHeader()),
        throwsA(isA<VaultNotFoundException>()),
      );
    });

    test('bozuk üst bilgi temiz hata veriyor', () async {
      await database
          .into(database.vaultMeta)
          .insert(VaultMetaCompanion.insert(header: '{bozuk'));

      expect(store.readHeader(), throwsA(isA<InvalidVaultHeaderException>()));
    });
  });

  group('kayıtlar', () {
    test('yazılan aynen okunuyor', () async {
      await store.putRecord(record());

      final read = await store.getRecord(recordId);
      expect(read?.id, recordId);
      expect(read?.type, 'login');
      expect(read?.blob, [1, 2, 3]);
      expect(read?.createdAt, now);
      expect(read?.updatedAt, now);
    });

    test('olmayan kayıt boş dönüyor', () async {
      expect(await store.getRecord(recordId), isNull);
    });

    test('aynı kimlikle yazmak üzerine yazıyor', () async {
      await store.putRecord(record());
      final later = now.add(const Duration(minutes: 1));

      await store.putRecord(record(blob: [9], updatedAt: later));

      final all = await store.allRecords();
      expect(all, hasLength(1));
      expect(all.single.blob, [9]);
      expect(all.single.updatedAt, later);
    });

    test('silinen kayıt gidiyor', () async {
      await store.putRecord(record());

      await store.deleteRecord(recordId);

      expect(await store.allRecords(), isEmpty);
    });
  });

  group('parmak izi yuvası', () {
    final slot = StoredBiometricSlot(
      iv: Uint8List(12)..fillRange(0, 12, 3),
      cipherText: Uint8List(48)..fillRange(0, 48, 4),
    );

    test('yoksa boş dönüyor', () async {
      expect(await store.readBiometricSlot(), isNull);
    });

    test('yazılan okunuyor ve silinebiliyor', () async {
      await store.writeBiometricSlot(slot);

      final read = await store.readBiometricSlot();
      expect(read?.iv, slot.iv);
      expect(read?.cipherText, slot.cipherText);

      await store.deleteBiometricSlot();
      expect(await store.readBiometricSlot(), isNull);
    });

    test('yeniden yazmak eskisinin yerine geçiyor', () async {
      await store.writeBiometricSlot(slot);
      final other = StoredBiometricSlot(
        iv: Uint8List(12),
        cipherText: Uint8List(48),
      );

      await store.writeBiometricSlot(other);

      final read = await store.readBiometricSlot();
      expect(read?.iv, other.iv);
    });
  });

  group('hatalı denemeler', () {
    test('başta sıfır', () async {
      final attempts = await store.readUnlockAttempts();
      expect(attempts.failedAttempts, 0);
      expect(attempts.lastFailedAt, isNull);
    });

    test('her deneme sayacı bir artırıyor ve zamanı yazıyor', () async {
      await store.registerFailedAttempt(now);
      final later = now.add(const Duration(seconds: 5));

      final attempts = await store.registerFailedAttempt(later);

      expect(attempts.failedAttempts, 2);
      expect(attempts.lastFailedAt, later);
      final read = await store.readUnlockAttempts();
      expect(read.failedAttempts, 2);
      expect(read.lastFailedAt, later);
    });

    test('son hata zamanı değişince sayaç korunuyor', () async {
      await store.registerFailedAttempt(now);
      final earlier = now.subtract(const Duration(days: 1));

      await store.moveLastFailure(earlier);

      final read = await store.readUnlockAttempts();
      expect(read.failedAttempts, 1);
      expect(read.lastFailedAt, earlier);
    });

    test('sıfırlanınca başa dönüyor', () async {
      await store.registerFailedAttempt(now);

      await store.resetUnlockAttempts();

      final read = await store.readUnlockAttempts();
      expect(read.failedAttempts, 0);
      expect(read.lastFailedAt, isNull);
    });
  });

  group('dosya üzerinde', () {
    late Directory directory;
    late File file;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('keykey_store_');
      file = File('${directory.path}/keykey.db');
    });

    tearDown(() {
      directory.deleteSync(recursive: true);
    });

    /// Bayt dizisi dosyanın ham içeriğinde geçiyor mu?
    bool fileContains(List<int> needle) {
      final haystack = file.readAsBytesSync();
      for (var i = 0; i <= haystack.length - needle.length; i++) {
        var matched = true;
        for (var j = 0; j < needle.length; j++) {
          if (haystack[i + j] != needle[j]) {
            matched = false;
            break;
          }
        }
        if (matched) return true;
      }
      return false;
    }

    test('hatalı deneme sayacı yeniden açınca korunuyor', () async {
      final first = VaultDatabase.openFile(file);
      await VaultStore(first).registerFailedAttempt(now);
      await VaultStore(first).registerFailedAttempt(now);
      await first.close();

      final second = VaultDatabase.openFile(file);
      addTearDown(second.close);

      final read = await VaultStore(second).readUnlockAttempts();
      expect(read.failedAttempts, 2);
      expect(read.lastFailedAt, now);
    });

    test('kayıt içeriği dosyada düz metin olarak durmuyor', () async {
      final sodium = await SodiumSumoInit.init();
      final vaultKey = sodium.crypto.kdfHkdfSha256.keygen();
      addTearDown(vaultKey.dispose);
      final cipher = RecordCipher(sodium, vaultKey, sodium.randombytes.buf(16));
      addTearDown(cipher.dispose);

      const title = 'gizli-baslik.example.com';
      const user = 'gizli-kullanici@example.com';
      const url = 'https://gizli-adres.example.com/giris';
      final plain = Uint8List.fromList(
        utf8.encode('{"title":"$title","user":"$user","url":"$url"}'),
      );

      final fileDatabase = VaultDatabase.openFile(file);
      final fileStore = VaultStore(fileDatabase);
      await fileStore.createVault(sampleHeader());
      await fileStore.putRecord(
        StoredRecord(
          id: recordId,
          type: 'login',
          blob: cipher.encrypt(
            recordId: recordId,
            type: 'login',
            plainText: plain,
          ),
          createdAt: now,
          updatedAt: now,
        ),
      );
      final stored = await fileStore.getRecord(recordId);
      await fileDatabase.close();

      for (final secret in [title, user, url]) {
        expect(fileContains(utf8.encode(secret)), isFalse, reason: secret);
      }
      expect(
        cipher.decrypt(recordId: recordId, type: 'login', blob: stored!.blob),
        plain,
      );
    });

    test('değiştirilen üst bilgi dosyada kalmıyor', () async {
      final fileDatabase = VaultDatabase.openFile(file);
      final old = sampleHeader(fill: 0xAB);
      final oldCipherText = base64.encode(old.passwordSlot.cipherText);
      await VaultStore(fileDatabase).createVault(old);
      await fileDatabase.close();
      expect(fileContains(utf8.encode(oldCipherText)), isTrue);

      final reopened = VaultDatabase.openFile(file);
      await VaultStore(reopened).updateHeader(sampleHeader(fill: 0xCD));
      await reopened.close();

      expect(fileContains(utf8.encode(oldCipherText)), isFalse);
    });
  });
}

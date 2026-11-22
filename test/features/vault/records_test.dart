import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/application/records_controller.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:keykey/features/vault/data/vault_record_repository.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  const password = 'ilk-Ana-Parola-47';
  const secretNumber = '4111111111111111';

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
    service = VaultService(sodium: sodium, store: store);
    now = DateTime.utc(2026, 11, 19, 12);
  });

  tearDown(() => database.close());

  Future<VaultSession> createSession() async {
    final pending = await service.prepareVault(password);
    final session = await service.confirmRecoveryKey(
      pending,
      pending.recoveryKeyText,
    );
    addTearDown(session.dispose);
    return session;
  }

  VaultRecordRepository<CardContent> cardsFor(VaultSession session) =>
      cardRepository(
        store: store,
        session: session,
        sodium: sodium,
        clock: () => now,
      );

  VaultRecordRepository<NoteContent> notesFor(VaultSession session) =>
      noteRepository(
        store: store,
        session: session,
        sodium: sodium,
        clock: () => now,
      );

  group('depo', () {
    late VaultSession session;

    setUp(() async {
      session = await createSession();
    });

    test('eklenen kart yeniden okunuyor, düz metin diske gitmiyor', () async {
      final cards = cardsFor(session);
      final item = await cards.add(
        CardContent(name: 'Maaş', number: secretNumber),
      );

      final loaded = await cards.loadAll();

      expect(loaded.unreadableCount, 0);
      expect(loaded.items.single.id, item.id);
      expect(loaded.items.single.content.number, secretNumber);
      final stored = (await store.getRecord(item.id))!;
      expect(stored.type, 'card');
      expect(
        latin1.decode(stored.blob, allowInvalid: true),
        isNot(contains(secretNumber)),
      );
    });

    test('türler birbirine karışmıyor', () async {
      await cardsFor(session).add(CardContent(name: 'Kart'));
      await notesFor(session).add(NoteContent(name: 'Not'));

      final cards = await cardsFor(session).loadAll();
      final notes = await notesFor(session).loadAll();
      final logins = await LoginRepository(
        store: store,
        session: session,
        sodium: sodium,
      ).loadAll();

      expect(cards.items.single.content.name, 'Kart');
      expect(cards.unreadableCount, 0);
      expect(notes.items.single.content.name, 'Not');
      expect(notes.unreadableCount, 0);
      expect(logins.items, isEmpty);
      expect(logins.unreadableCount, 0);
    });

    test('bozuk kayıt sayılıyor, diğerleri yükleniyor', () async {
      final cards = cardsFor(session);
      await cards.add(CardContent(name: 'Sağlam'));
      final broken = await cards.add(CardContent(name: 'Bozuk'));
      final stored = (await store.getRecord(broken.id))!;
      final tampered = Uint8List.fromList(stored.blob);
      tampered[tampered.length - 1] ^= 1;
      await store.putRecord(
        StoredRecord(
          id: stored.id,
          type: stored.type,
          blob: tampered,
          createdAt: stored.createdAt,
          updatedAt: stored.updatedAt,
        ),
      );

      final loaded = await cards.loadAll();

      expect(loaded.items.single.content.name, 'Sağlam');
      expect(loaded.unreadableCount, 1);
    });

    test('bu sürümün okuyamadığı içerik sayılıyor', () async {
      final id = sodium.randombytes.buf(16);
      await store.putRecord(
        StoredRecord(
          id: id,
          type: 'note',
          blob: session.records.encrypt(
            recordId: id,
            type: 'note',
            plainText: Uint8List.fromList(utf8.encode('{"version":99}')),
          ),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final loaded = await notesFor(session).loadAll();

      expect(loaded.items, isEmpty);
      expect(loaded.unreadableCount, 1);
    });

    test('güncelleme içeriği ve zamanı değiştiriyor', () async {
      final notes = notesFor(session);
      final item = await notes.add(NoteContent(name: 'A', text: 'bir'));
      now = now.add(const Duration(minutes: 1));

      final updated = await notes.update(
        item,
        item.content.copyWith(text: 'iki'),
      );

      expect(updated.updatedAt, now);
      expect(updated.createdAt, item.createdAt);
      expect((await notes.loadAll()).items.single.content.text, 'iki');
    });

    test('süresi dolan çöp kutusu siliniyor, dolmayan kalıyor', () async {
      final cards = cardsFor(session);
      final old = await cards.add(
        CardContent(
          name: 'Eski',
          trashedAt: now.subtract(const Duration(days: 31)),
        ),
      );
      final recent = await cards.add(
        CardContent(
          name: 'Yeni',
          trashedAt: now.subtract(const Duration(days: 29)),
        ),
      );

      now = now.add(const Duration(hours: 1));

      final kept = await cards.purgeExpiredTrash([old, recent]);

      expect(kept.single.content.name, 'Yeni');
      expect(await store.getRecord(old.id), isNull);
      // Silme kaydı çöpe atılan sürümün zamanını taşıyor.
      expect((await store.allTombstones()).single.deletedAt, old.updatedAt);
    });
  });

  group('denetleyici', () {
    late ProviderContainer container;
    late VaultSession session;

    Future<RecordsLoaded<CardContent>> loaded() async {
      for (var i = 0; i < 200; i++) {
        final state = container.read(cardsControllerProvider);
        if (state is RecordsLoaded<CardContent>) return state;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      fail('Kartlar yüklenmedi');
    }

    setUp(() async {
      session = await createSession();
      container = ProviderContainer(
        overrides: [
          vaultServiceProvider.overrideWithValue(service),
          initialVaultStatusProvider.overrideWithValue(VaultOpen(session)),
          cardRepositoryFactoryProvider.overrideWithValue(cardsFor),
          noteRepositoryFactoryProvider.overrideWithValue(notesFor),
        ],
      );
      addTearDown(container.dispose);
    });

    RecordsController<CardContent> controller() =>
        container.read(cardsControllerProvider.notifier);

    test('ekleme, çöp, geri alma ve silme durumu güncelliyor', () async {
      await loaded();

      final item = await controller().add(CardContent(name: 'A'));
      expect((await loaded()).items.single.content.name, 'A');

      await controller().setFavorite(item, favorite: true);
      expect((await loaded()).items.single.content.favorite, isTrue);

      await controller().moveToTrash((await loaded()).items.single, now);
      expect((await loaded()).trashed, hasLength(1));

      await controller().restoreById(item.id);
      expect((await loaded()).trashed, isEmpty);

      await controller().deletePermanently((await loaded()).items.single);
      expect((await loaded()).items, isEmpty);
    });

    test('senkron yeniden kurarken yapılan değişiklik kaybolmuyor', () async {
      await loaded();
      final item = await controller().add(CardContent(name: 'A', pin: '1111'));
      // Süresi dolan çöp, okumanın içinde bir yazma daha yapar.
      final old = await controller().add(CardContent(name: 'Eski'));
      await controller().moveToTrash(old, now);
      now = now.add(const Duration(days: 31));

      // Senkron öteki telefonun değişikliğini getirince denetleyiciyi yeniden
      // kurar; kullanıcının kaydı tam o sırada biter.
      container.invalidate(cardsControllerProvider);
      await controller().update(item, item.content.copyWith(pin: '2222'));

      final shown = (await loaded()).items.single;
      expect(shown.content.pin, '2222');
    });

    test('addAll hepsini ekliyor', () async {
      await loaded();

      await controller().addAll([
        CardContent(name: 'A'),
        CardContent(name: 'B'),
      ]);

      expect((await loaded()).items, hasLength(2));
    });

    test('findRecord onaltılık kimlikle buluyor', () async {
      await loaded();
      final item = await controller().add(CardContent(name: 'A'));

      final state = container.read(cardsControllerProvider);

      expect(findRecord(state, loginIdHex(item.id))?.content.name, 'A');
      expect(findRecord(state, 'ff' * 16), isNull);
    });

    test('kilit çözülmüş kartları o anda siliyor', () async {
      await controller().add(CardContent(name: 'A', number: secretNumber));
      await loaded();

      container.read(vaultControllerProvider.notifier).lock();

      expect(
        container.read(cardsControllerProvider),
        isA<RecordsLoading<CardContent>>(),
      );
      expect(
        () => controller().add(CardContent(name: 'B')),
        throwsA(isA<VaultLockedException>()),
      );
    });

    test('yükleme sürerken kilitlenince kartlar geri gelmiyor', () async {
      await cardsFor(session).add(CardContent(name: 'A'));
      container.read(cardsControllerProvider);

      container.read(vaultControllerProvider.notifier).lock();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        container.read(cardsControllerProvider),
        isA<RecordsLoading<CardContent>>(),
      );
    });

    test('notlar ayrı denetleyicide', () async {
      await notesFor(session).add(NoteContent(name: 'Not'));

      for (var i = 0; i < 200; i++) {
        if (container.read(notesControllerProvider)
            is RecordsLoaded<NoteContent>) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final state = container.read(notesControllerProvider);
      expect(state, isA<RecordsLoaded<NoteContent>>());
      expect(
        (state as RecordsLoaded<NoteContent>).items.single.content.name,
        'Not',
      );
    });
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  const password = 'ilk-Ana-Parola-47';
  const secretName = 'gizli-site-adi';
  const secretPassword = 'gizli-parola-degeri';
  const secretFolder = 'gizli-klasor-adi';

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
    now = DateTime.utc(2026, 11, 5, 12);
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

  LoginRepository repositoryFor(VaultSession session) => LoginRepository(
    store: store,
    session: session,
    sodium: sodium,
    clock: () => now,
  );

  group('depo', () {
    late VaultSession session;
    late LoginRepository repository;

    setUp(() async {
      session = await createSession();
      repository = repositoryFor(session);
    });

    test('eklenen kayıt yeniden okunuyor', () async {
      final item = await repository.add(
        const LoginContent(name: secretName, password: secretPassword),
      );

      final loaded = await repository.loadAll();

      expect(loaded.unreadableCount, 0);
      expect(loaded.items, hasLength(1));
      expect(loaded.items.single.id, item.id);
      expect(loaded.items.single.content.name, secretName);
      expect(loaded.items.single.content.password, secretPassword);
      expect(loaded.items.single.createdAt, now);
    });

    test('kayıt kimlikleri farklı', () async {
      final first = await repository.add(const LoginContent(name: 'A'));
      final second = await repository.add(const LoginContent(name: 'A'));

      expect(first.id, isNot(second.id));
      expect(first.id, hasLength(16));
    });

    test('düzenleme eski parolayı geçmişe yazıyor', () async {
      final item = await repository.add(
        const LoginContent(name: 'A', password: 'eski'),
      );
      now = now.add(const Duration(days: 1));

      await repository.update(item, item.content.copyWith(password: 'yeni'));

      final read = (await repository.loadAll()).items.single;
      expect(read.content.password, 'yeni');
      expect(read.content.passwordHistory.single.password, 'eski');
      expect(read.content.passwordHistory.single.changedAt, now);
      expect(read.updatedAt, now);
      expect(read.createdAt, item.createdAt);
    });

    test('favori ve çöp kutusu geçmişe dokunmuyor', () async {
      final item = await repository.add(
        const LoginContent(name: 'A', password: 'eski'),
      );

      await repository.updateMetadata(
        item,
        item.content.copyWith(favorite: true, trashedAt: now),
      );

      final read = (await repository.loadAll()).items.single;
      expect(read.content.favorite, isTrue);
      expect(read.content.isTrashed, isTrue);
      expect(read.content.passwordHistory, isEmpty);
    });

    test('kalıcı silinen kayıt gidiyor', () async {
      final item = await repository.add(const LoginContent(name: 'A'));

      await repository.deletePermanently(item);

      expect((await repository.loadAll()).items, isEmpty);
      expect(await store.allRecords(), isEmpty);
    });

    test('kalıcı silme, deponun saatiyle silme kaydı bırakıyor', () async {
      final item = await repository.add(const LoginContent(name: 'A'));
      now = now.add(const Duration(hours: 3));

      await repository.deletePermanently(item);

      final tombstone = (await store.allTombstones()).single;
      expect(tombstone.id, item.id);
      expect(tombstone.deletedAt, now);
    });

    test('bozuk kayıt listeyi düşürmüyor, dokunulmuyor', () async {
      await repository.add(const LoginContent(name: 'Sağlam'));
      final broken = await repository.add(const LoginContent(name: 'Bozuk'));
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

      final loaded = await repository.loadAll();

      expect(loaded.items.single.content.name, 'Sağlam');
      expect(loaded.unreadableCount, 1);
      expect((await store.getRecord(broken.id))!.blob, tampered);
    });

    test('bu sürümün okuyamadığı içerik listeyi düşürmüyor', () async {
      final id = sodium.randombytes.buf(16);
      await store.putRecord(
        StoredRecord(
          id: id,
          type: LoginRepository.recordType,
          blob: session.records.encrypt(
            recordId: id,
            type: LoginRepository.recordType,
            plainText: Uint8List.fromList(utf8.encode('{"version":99}')),
          ),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final loaded = await repository.loadAll();

      expect(loaded.items, isEmpty);
      expect(loaded.unreadableCount, 1);
    });

    test('başka türden kayıtlar karışmıyor', () async {
      final id = sodium.randombytes.buf(16);
      await store.putRecord(
        StoredRecord(
          id: id,
          type: 'otp',
          blob: session.records.encrypt(
            recordId: id,
            type: 'otp',
            plainText: Uint8List.fromList([1]),
          ),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final loaded = await repository.loadAll();

      expect(loaded.items, isEmpty);
      expect(loaded.unreadableCount, 0);
    });

    test('süresi dolan çöp kutusu siliniyor, dolmayan kalıyor', () async {
      final old = await repository.updateMetadata(
        await repository.add(const LoginContent(name: 'Eski')),
        const LoginContent(name: 'Eski')
            .copyWith(trashedAt: now.subtract(const Duration(days: 30))),
      );
      final recent = await repository.updateMetadata(
        await repository.add(const LoginContent(name: 'Yeni')),
        const LoginContent(name: 'Yeni')
            .copyWith(trashedAt: now.subtract(const Duration(days: 29))),
      );
      final live = await repository.add(const LoginContent(name: 'Canlı'));
      now = now.add(const Duration(days: 2));

      final kept = await repository.purgeExpiredTrash([old, recent, live]);

      expect(kept.map((item) => item.content.name), ['Canlı']);
      expect(await store.getRecord(old.id), isNull);
      expect(await store.getRecord(live.id), isNotNull);
      // Silme kaydı çöpe atılan sürümün zamanını taşıyor: başka telefonda
      // daha sonra çöpten çıkarılan ya da değişen kayıt ona yeniliyor.
      expect(
        {for (final t in await store.allTombstones()) t.deletedAt},
        {old.updatedAt, recent.updatedAt},
      );
    });

    test('kilitlenince depo anahtara dokunamıyor, çökmüyor', () async {
      session.dispose();

      await expectLater(
        repository.add(const LoginContent(name: 'A')),
        throwsA(isA<VaultLockedException>()),
      );
    });
  });

  test('içerik dosyada düz metin olarak durmuyor', () async {
    final directory = Directory.systemTemp.createTempSync('keykey_login_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/keykey.db');
    final fileDatabase = VaultDatabase.openFile(file);
    final fileStore = VaultStore(fileDatabase);
    final fileService = VaultService(sodium: sodium, store: fileStore);
    final pending = await fileService.prepareVault(password);
    final session = await fileService.confirmRecoveryKey(
      pending,
      pending.recoveryKeyText,
    );
    addTearDown(session.dispose);
    final repository = LoginRepository(
      store: fileStore,
      session: session,
      sodium: sodium,
    );

    final item = await repository.add(
      const LoginContent(
        name: secretName,
        username: 'gizli-kullanici',
        password: secretPassword,
        urls: ['https://gizli-adres.example.com'],
        notes: 'gizli-not-metni',
        folder: secretFolder,
      ),
    );
    await repository.update(
      item,
      item.content.copyWith(password: 'gizli-yeni-parola'),
    );
    await fileDatabase.close();

    final raw = file.readAsBytesSync();
    bool contains(String text) {
      final needle = utf8.encode(text);
      for (var i = 0; i <= raw.length - needle.length; i++) {
        var matched = true;
        for (var j = 0; j < needle.length; j++) {
          if (raw[i + j] != needle[j]) {
            matched = false;
            break;
          }
        }
        if (matched) return true;
      }
      return false;
    }

    for (final text in [
      secretName,
      'gizli-kullanici',
      secretPassword,
      'gizli-yeni-parola',
      'gizli-adres',
      'gizli-not-metni',
      secretFolder,
    ]) {
      expect(contains(text), isFalse, reason: text);
    }
  });

  group('denetleyici', () {
    late ProviderContainer container;
    late VaultSession session;

    Future<LoginsLoaded> loaded() async {
      for (var i = 0; i < 200; i++) {
        final state = container.read(loginsControllerProvider);
        if (state is LoginsLoaded) return state;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      fail('Kayıtlar yüklenmedi');
    }

    setUp(() async {
      session = await createSession();
      container = ProviderContainer(
        overrides: [
          vaultServiceProvider.overrideWithValue(service),
          initialVaultStatusProvider.overrideWithValue(VaultOpen(session)),
          loginRepositoryFactoryProvider.overrideWithValue(repositoryFor),
        ],
      );
      addTearDown(container.dispose);
      // Kapanışta denetleyici oturumu siler, createSession'ın temizliği de
      // aynı oturumu siler; iki kez silmek zararsız.
    });

    LoginsController controller() =>
        container.read(loginsControllerProvider.notifier);

    test('kasa açılınca kayıtlar yükleniyor', () async {
      await repositoryFor(session).add(const LoginContent(name: 'A'));

      final state = await loaded();

      expect(state.items.single.content.name, 'A');
    });

    test('eski kopyayla yapılan yazmalar güncel kaydın üstüne', () async {
      await loaded();
      final stale = await controller().add(
        const LoginContent(name: 'A', password: 'eski'),
      );
      // Arka planda bekleme süresinde doldurma ekranı parolayı güncelledi;
      // dönüşte liste yeniden okundu.
      await repositoryFor(session)
          .update(stale, stale.content.copyWith(password: 'yeni'));
      await controller().reload();

      await controller().moveToFolder(stale, 'İş');
      await controller().setFavorite(stale, favorite: true);
      await controller().moveToTrash(stale, now);

      final saved = (await repositoryFor(session).loadAll()).items.single;
      expect(saved.content.password, 'yeni');
      expect(saved.content.passwordHistory.single.password, 'eski');
      expect(saved.content.folder, 'İş');
      expect(saved.content.favorite, isTrue);
      expect(saved.content.isTrashed, isTrue);
    });

    test('yeniden okuma sürerken yapılan değişiklik kaybolmuyor', () async {
      // Senkron bitip liste yeniden okunurken kullanıcı parolayı değiştirdi
      // ve bir kayıt ekledi; okuma eski hali getirse de ikisi de kalmalı.
      await loaded();
      final item = await controller().add(
        const LoginContent(name: 'A', password: 'eski'),
      );
      // Süresi dolan çöp, okumanın içinde bir yazma daha yapar; kullanıcının
      // yazması o arada biter.
      final old = await controller().add(const LoginContent(name: 'Eski'));
      await controller().moveToTrash(old, now);
      now = now.add(const Duration(days: 31));

      final reloading = controller().reload();
      await controller().update(item, item.content.copyWith(password: 'yeni'));
      await controller().add(const LoginContent(name: 'B'));
      await reloading;

      final state = container.read(loginsControllerProvider) as LoginsLoaded;
      final names = state.items.map((i) => i.content.name).toList()..sort();
      expect(names, ['A', 'B']);
      final shown = state.items.firstWhere((i) => i.content.name == 'A');
      expect(shown.content.password, 'yeni');

      // Eski kopya geri yazılmıyor.
      await controller().setFavorite(shown, favorite: true);
      final saved = (await repositoryFor(session).loadAll()).items;
      expect(
        saved.firstWhere((i) => i.content.name == 'A').content.password,
        'yeni',
      );
    });

    test('ekleme, düzenleme ve silme durumu güncelliyor', () async {
      await loaded();

      final item = await controller().add(const LoginContent(name: 'A'));
      expect((await loaded()).items.single.content.name, 'A');

      final updated = await controller().update(
        item,
        item.content.copyWith(name: 'B'),
      );
      expect((await loaded()).items.single.content.name, 'B');

      await controller().moveToTrash(updated, now);
      expect((await loaded()).trashed, hasLength(1));

      await controller().restore((await loaded()).trashed.single);
      expect((await loaded()).trashed, isEmpty);

      await controller().deletePermanently((await loaded()).items.single);
      expect((await loaded()).items, isEmpty);
    });

    test('kilit çözülmüş kayıtları o anda siliyor', () async {
      await controller().add(const LoginContent(name: secretName));
      await loaded();
      await controller().add(const LoginContent(name: 'İkinci'));

      LoginsState? last;
      container.listen(
        loginsControllerProvider,
        (_, next) => last = next,
        fireImmediately: true,
      );
      expect(last, isA<LoginsLoaded>());

      container.read(vaultControllerProvider.notifier).lock();

      // Araya await girmeden: arka planda kare çizilmediği için beklenemez.
      expect(last, isA<LoginsLoading>());
    });

    test('dinleyen olmasa da kilit kayıtları siliyor', () async {
      await repositoryFor(session).add(const LoginContent(name: secretName));
      await loaded();
      final notifier = controller();

      container.read(vaultControllerProvider.notifier).lock();

      expect(container.read(loginsControllerProvider), isA<LoginsLoading>());
      expect(
        () => notifier.add(const LoginContent(name: 'A')),
        throwsA(isA<VaultLockedException>()),
      );
    });

    test('yükleme sürerken kilitlenince kayıtlar geri gelmiyor', () async {
      await repositoryFor(session).add(const LoginContent(name: secretName));
      container.read(loginsControllerProvider);

      container.read(vaultControllerProvider.notifier).lock();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(container.read(loginsControllerProvider), isA<LoginsLoading>());
    });

    test('kilitten sonra yeniden açınca kayıtlar geliyor', () async {
      await repositoryFor(session).add(const LoginContent(name: 'A'));
      await loaded();

      final vault = container.read(vaultControllerProvider.notifier)..lock();
      await vault.unlockWithPassword(password);

      expect((await loaded()).items.single.content.name, 'A');
    });
  });
}

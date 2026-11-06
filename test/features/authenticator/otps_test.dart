import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/application/otp_generator.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  const password = 'ilk-Ana-Parola-47';
  const secretIssuer = 'gizli-servis-adi';
  const secretAccount = 'gizli-hesap-adi';
  // RFC 4226 Ek D anahtarı, HOTP kodları bilinsin diye.
  final rfcSecret = ascii.encode('12345678901234567890');

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
    now = DateTime.utc(2026, 11, 6, 12);
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

  OtpRepository repositoryFor(VaultSession session) => OtpRepository(
    store: store,
    session: session,
    sodium: sodium,
    clock: () => now,
  );

  OtpContent totp(String issuer) => OtpContent(
    parameters: OtpParameters.totp(secret: rfcSecret),
    issuer: issuer,
  );

  OtpContent hotp({int counter = 0}) => OtpContent(
    parameters: OtpParameters.hotp(secret: rfcSecret, counter: counter),
    issuer: 'HOTP',
  );

  group('depo', () {
    late VaultSession session;
    late OtpRepository repository;

    setUp(() async {
      session = await createSession();
      repository = repositoryFor(session);
    });

    test('eklenen kayıt yeniden okunuyor', () async {
      final item = await repository.add(totp('A'));

      final loaded = await repository.loadAll();

      expect(loaded.unreadableCount, 0);
      expect(loaded.items.single.id, item.id);
      expect(loaded.items.single.content.issuer, 'A');
      expect(loaded.items.single.content.parameters, item.content.parameters);
      expect(loaded.items.single.createdAt, now);
    });

    test('2FA alt anahtarıyla şifreleniyor', () async {
      final item = await repository.add(totp('A'));
      final stored = (await store.getRecord(item.id))!;

      expect(stored.type, RecordCipher.otpType);
      // Aynı veri parola türüyle, yani kayıt anahtarıyla açılamaz.
      expect(
        () => session.records.decrypt(
          recordId: item.id,
          type: LoginRepository.recordType,
          blob: stored.blob,
        ),
        throwsA(isA<CorruptedDataException>()),
      );
      expect(
        session.records.decrypt(
          recordId: item.id,
          type: RecordCipher.otpType,
          blob: stored.blob,
        ),
        isNotEmpty,
      );
    });

    test('bozuk kayıt listeyi düşürmüyor, dokunulmuyor', () async {
      await repository.add(totp('Sağlam'));
      final broken = await repository.add(totp('Bozuk'));
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

      expect(loaded.items.single.content.issuer, 'Sağlam');
      expect(loaded.unreadableCount, 1);
      expect((await store.getRecord(broken.id))!.blob, tampered);
    });

    test('bu sürümün okuyamadığı içerik listeyi düşürmüyor', () async {
      final id = sodium.randombytes.buf(16);
      await store.putRecord(
        StoredRecord(
          id: id,
          type: OtpRepository.recordType,
          blob: session.records.encrypt(
            recordId: id,
            type: OtpRepository.recordType,
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

    test('parola kayıtları karışmıyor', () async {
      final logins = LoginRepository(
        store: store,
        session: session,
        sodium: sodium,
      );
      await logins.add(const LoginContent(name: 'Parola'));

      final loaded = await repository.loadAll();

      expect(loaded.items, isEmpty);
      expect(loaded.unreadableCount, 0);
    });

    test('süresi dolan çöp kutusu siliniyor, dolmayan kalıyor', () async {
      final old = await repository.add(
        totp('Eski')
            .copyWith(trashedAt: now.subtract(const Duration(days: 30))),
      );
      final recent = await repository.add(
        totp('Yeni')
            .copyWith(trashedAt: now.subtract(const Duration(days: 29))),
      );

      final kept = await repository.purgeExpiredTrash(
        (await repository.loadAll()).items,
      );

      expect(kept.single.id, recent.id);
      expect(await store.getRecord(old.id), isNull);
    });

    test('kilitlenince depo anahtara dokunamıyor, çökmüyor', () async {
      session.dispose();

      await expectLater(
        repository.add(totp('A')),
        throwsA(isA<VaultLockedException>()),
      );
    });
  });

  test('içerik dosyada düz metin olarak durmuyor', () async {
    final directory = Directory.systemTemp.createTempSync('keykey_otp_');
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
    final repository = OtpRepository(
      store: fileStore,
      session: session,
      sodium: sodium,
    );
    final secret = ascii.encode('gizli-anahtar-baytlari');

    await repository.add(
      OtpContent(
        parameters: OtpParameters.totp(secret: secret),
        issuer: secretIssuer,
        account: secretAccount,
        notes: 'gizli-not-metni',
      ),
    );
    await fileDatabase.close();

    final raw = file.readAsBytesSync();
    bool contains(List<int> needle) {
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
      secretIssuer,
      secretAccount,
      'gizli-not-metni',
      Base32.encode(secret),
    ]) {
      expect(contains(utf8.encode(text)), isFalse, reason: text);
    }
    expect(contains(secret), isFalse, reason: 'ham anahtar');
  });

  group('denetleyici', () {
    late ProviderContainer container;
    late VaultSession session;

    Future<OtpsLoaded> loaded() async {
      for (var i = 0; i < 200; i++) {
        final state = container.read(otpsControllerProvider);
        if (state is OtpsLoaded) return state;
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
          otpRepositoryFactoryProvider.overrideWithValue(repositoryFor),
        ],
      );
      addTearDown(container.dispose);
    });

    OtpsController controller() =>
        container.read(otpsControllerProvider.notifier);

    test('kasa açılınca kayıtlar yükleniyor', () async {
      await repositoryFor(session).add(totp('A'));

      final state = await loaded();

      expect(state.items.single.content.issuer, 'A');
    });

    test('ekleme, düzenleme, favori ve silme durumu güncelliyor', () async {
      await loaded();

      final item = await controller().add(totp('A'));
      expect((await loaded()).items.single.content.issuer, 'A');

      final updated = await controller().update(
        item,
        item.content.copyWith(issuer: 'B'),
      );
      expect((await loaded()).items.single.content.issuer, 'B');

      await controller().setFavorite(updated, favorite: true);
      expect((await loaded()).items.single.content.favorite, isTrue);

      await controller().moveToTrash(updated, now);
      expect((await loaded()).trashed, hasLength(1));
      expect((await loaded()).active, isEmpty);
      // Eski kopyayla yapılan çöp kutusu işlemi favoriyi geri almadı.
      expect((await loaded()).trashed.single.content.favorite, isTrue);

      await controller().restoreById(updated.id);
      expect((await loaded()).trashed, isEmpty);

      await controller().deletePermanently((await loaded()).items.single);
      expect((await loaded()).items, isEmpty);
      expect(await store.allRecords(), isEmpty);
    });

    group('HOTP', () {
      test(
        'kod eski sayaçla hesaplanıyor, sayaç önce diske yazılıyor',
        () async {
          final item = await repositoryFor(session).add(hotp());
          await loaded();

          final first = await controller().nextHotpCode(item);
          final second = await controller().nextHotpCode(item);

          // RFC 4226 Ek D, sayaç 0 ve 1.
          expect(first, '755224');
          expect(second, '287082');
          final stored = (await repositoryFor(session).loadAll()).items.single;
          expect(stored.content.parameters.counter, 2);
          expect((await loaded()).items.single.content.parameters.counter, 2);
        },
      );

      test('aynı anda iki istek aynı kodu üretmiyor', () async {
        final item = await repositoryFor(session).add(hotp(counter: 5));
        await loaded();

        final codes = await Future.wait([
          controller().nextHotpCode(item),
          controller().nextHotpCode(item),
          controller().nextHotpCode(item),
        ]);

        expect(codes, ['254676', '287922', '162583']);
        expect((await loaded()).items.single.content.parameters.counter, 8);
      });

      test('eski kopyayla yapılan düzenleme sayacı geri almıyor', () async {
        final stale = await repositoryFor(session).add(hotp());
        await loaded();
        await controller().nextHotpCode(stale);
        await controller().nextHotpCode(stale);

        await controller().update(
          stale,
          stale.content.copyWith(issuer: 'Yeni ad'),
        );
        await controller().setFavorite(stale, favorite: true);

        final current = (await loaded()).items.single.content;
        expect(current.issuer, 'Yeni ad');
        expect(current.favorite, isTrue);
        expect(current.parameters.counter, 2);
        expect(
          (await repositoryFor(
            session,
          ).loadAll()).items.single.content.parameters.counter,
          2,
        );
      });

      test('kullanıcının bilerek değiştirdiği sayaç korunuyor', () async {
        final item = await repositoryFor(session).add(hotp(counter: 10));
        await loaded();

        await controller().update(
          item,
          item.content.copyWith(
            parameters: item.content.parameters.withCounter(3),
          ),
        );

        expect((await loaded()).items.single.content.parameters.counter, 3);
        expect(
          OtpGenerator.codeFor(
            (await loaded()).items.single.content.parameters,
            now,
          ),
          '969429',
        );
      });
    });

    test('kilit çözülmüş kayıtları o anda siliyor', () async {
      await controller().add(totp(secretIssuer));
      await loaded();

      OtpsState? last;
      container.listen(
        otpsControllerProvider,
        (_, next) => last = next,
        fireImmediately: true,
      );
      expect(last, isA<OtpsLoaded>());

      container.read(vaultControllerProvider.notifier).lock();

      // Araya await girmeden: arka planda kare çizilmediği için beklenemez.
      expect(last, isA<OtpsLoading>());
    });

    test('dinleyen olmasa da kilit kayıtları siliyor', () async {
      final item = await repositoryFor(session).add(hotp());
      await loaded();
      final notifier = controller();

      container.read(vaultControllerProvider.notifier).lock();

      expect(container.read(otpsControllerProvider), isA<OtpsLoading>());
      await expectLater(
        notifier.add(totp('A')),
        throwsA(isA<VaultLockedException>()),
      );
      await expectLater(
        notifier.nextHotpCode(item),
        throwsA(isA<VaultLockedException>()),
      );
    });

    test('yükleme sürerken kilitlenince kayıtlar geri gelmiyor', () async {
      await repositoryFor(session).add(totp(secretIssuer));
      container.read(otpsControllerProvider);

      container.read(vaultControllerProvider.notifier).lock();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(container.read(otpsControllerProvider), isA<OtpsLoading>());
    });

    test('kilitten sonra yeniden açınca kayıtlar geliyor', () async {
      await repositoryFor(session).add(totp('A'));
      await loaded();

      final vault = container.read(vaultControllerProvider.notifier)..lock();
      await vault.unlockWithPassword(password);

      expect((await loaded()).items.single.content.issuer, 'A');
    });
  });
}

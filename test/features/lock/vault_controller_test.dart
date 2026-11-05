import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  const password = 'ilk-Ana-Parola-47';
  const newPassword = 'ikinci-Ana-Parola-58';

  late SodiumSumo sodium;
  late VaultDatabase database;
  late VaultService service;
  late ProviderContainer container;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    database = VaultDatabase(NativeDatabase.memory());
    service = VaultService(sodium: sodium, store: VaultStore(database));
    container = ProviderContainer(
      overrides: [
        vaultServiceProvider.overrideWithValue(service),
        initialVaultStatusProvider.overrideWithValue(const VaultNotSetUp()),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() => database.close());

  VaultController controller() =>
      container.read(vaultControllerProvider.notifier);

  VaultStatus status() => container.read(vaultControllerProvider);

  /// Kurulu ve kilitli bir kasa hazırlar, kurtarma anahtarını döndürür.
  Future<String> setUpLockedVault() async {
    final text = await controller().prepareVault(password);
    await controller().confirmSetup(text);
    controller().lock();
    return text;
  }

  group('kurulum', () {
    test('doğrulanınca kasa açılıyor', () async {
      final text = await controller().prepareVault(password);
      expect(status(), isA<VaultNotSetUp>());
      expect(await service.readHeader(), isNull);

      await controller().confirmSetup(text);

      expect(status(), isA<VaultOpen>());
      expect(await service.readHeader(), isNotNull);
    });

    test(
      'yanlış anahtarda oluşturulan kasa bekliyor, yeniden denenebiliyor',
      () async {
        final text = await controller().prepareVault(password);

        await expectLater(controller().confirmSetup('hatali'), throwsException);
        expect(status(), isA<VaultNotSetUp>());
        expect(await service.readHeader(), isNull);

        await controller().confirmSetup(text);
        expect(status(), isA<VaultOpen>());
      },
    );

    test('vazgeçince diskte bir şey kalmıyor', () async {
      await controller().prepareVault(password);

      controller().cancelSetup();

      expect(await service.readHeader(), isNull);
      expect(controller().confirmSetup('x'), throwsStateError);
    });
  });

  group('kilit', () {
    test('anahtarları siliyor ve üst bilgiyi koruyor', () async {
      final text = await controller().prepareVault(password);
      await controller().confirmSetup(text);
      final session = (status() as VaultOpen).session;

      controller().lock();

      final locked = status();
      expect(locked, isA<VaultLocked>());
      expect(
        (locked as VaultLocked).header.toJsonString(),
        session.header.toJsonString(),
      );
      expect(session.isDisposed, isTrue);
      expect(() => session.vaultKey, throwsStateError);
      expect(() => session.records, throwsStateError);
    });

    test('kilitliyken yeniden kilitlemek zararsız', () async {
      await setUpLockedVault();

      controller().lock();

      expect(status(), isA<VaultLocked>());
    });

    test('Argon2id sürerken kilitlenirse kasa açılmıyor', () async {
      await setUpLockedVault();

      final pending = controller().unlockWithPassword(password);
      controller().lock();
      final attempt = await pending;

      expect(attempt, isA<PasswordAccepted>());
      expect(status(), isA<VaultLocked>());
    });

    test('kilitten sonra parolayla yeniden açılıyor', () async {
      await setUpLockedVault();

      final attempt = await controller().unlockWithPassword(password);

      expect(attempt, isA<PasswordAccepted>());
      expect(status(), isA<VaultOpen>());
    });

    test('yanlış parola kilitli bırakıyor', () async {
      await setUpLockedVault();

      final attempt = await controller().unlockWithPassword('yanlis-parola-9');

      expect(attempt, isA<PasswordRejected>());
      expect(status(), isA<VaultLocked>());
    });

    test('parola değişince kilit yeni üst bilgiyi kullanıyor', () async {
      final text = await controller().prepareVault(password);
      await controller().confirmSetup(text);

      await controller().changePassword(
        currentPassword: password,
        newPassword: newPassword,
      );
      controller().lock();

      final old = await controller().unlockWithPassword(password);
      expect(old, isA<PasswordRejected>());
      final fresh = await controller().unlockWithPassword(newPassword);
      expect(fresh, isA<PasswordAccepted>());
    });
  });

  group('parola değişirken kilitlenirse', () {
    /// Kilit, işlemin farklı anlarına denk gelsin diye [delay] sonra çağrılır.
    /// Hangi anda gelirse gelsin çökmemeli, yeni parola geçerli olmalı ve
    /// bellekteki üst bilgi diskteki ile aynı kalmalı.
    Future<void> changeThenLock(Duration delay) async {
      final text = await controller().prepareVault(password);
      await controller().confirmSetup(text);

      final pending = controller().changePassword(
        currentPassword: password,
        newPassword: newPassword,
      );
      await Future<void>.delayed(delay);
      controller().lock();
      expect(await pending, isA<PasswordAccepted>());

      final locked = status();
      expect(locked, isA<VaultLocked>());
      final stored = await service.readHeader();
      expect(
        (locked as VaultLocked).header.toJsonString(),
        stored?.toJsonString(),
      );

      final old = await controller().unlockWithPassword(password);
      expect(old, isA<PasswordRejected>());
      final fresh = await controller().unlockWithPassword(newPassword);
      expect(fresh, isA<PasswordAccepted>());
    }

    for (final milliseconds in [0, 1, 20, 150, 400]) {
      test('$milliseconds ms sonra kilit: tutarlı ve çökmüyor', () async {
        await changeThenLock(Duration(milliseconds: milliseconds));
      });
    }

    test(
      'üst bilgi yazıldıktan hemen sonra kilit: yeni parola geçerli',
      () async {
        final text = await controller().prepareVault(password);
        await controller().confirmSetup(text);
        final before = (await service.readHeader())!.toJsonString();

        final pending = controller().changePassword(
          currentPassword: password,
          newPassword: newPassword,
        );
        while ((await service.readHeader())!.toJsonString() == before) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        controller().lock();
        await pending;

        final attempt = await controller().unlockWithPassword(newPassword);
        expect(attempt, isA<PasswordAccepted>());
      },
    );
  });

  group('kurtarma', () {
    test('yeni parola belirlenmeden kasa açık sayılmıyor', () async {
      final text = await setUpLockedVault();

      controller().unlockWithRecoveryKey(text);
      expect(status(), isA<VaultRecovering>());

      await controller().setNewPassword(newPassword);
      expect(status(), isA<VaultOpen>());

      controller().lock();
      final attempt = await controller().unlockWithPassword(newPassword);
      expect(attempt, isA<PasswordAccepted>());
    });

    test('kurtarma sırasında kilitlenince anahtar siliniyor', () async {
      final text = await setUpLockedVault();
      controller().unlockWithRecoveryKey(text);
      final session = (status() as VaultRecovering).session;

      controller().lock();

      expect(status(), isA<VaultLocked>());
      expect(session.isDisposed, isTrue);
    });

    test('yeni parola yazılırken kilitlenince yeni parola geçerli', () async {
      final text = await setUpLockedVault();
      controller().unlockWithRecoveryKey(text);

      final pending = controller().setNewPassword(newPassword);
      controller().lock();
      await pending;

      expect(status(), isA<VaultLocked>());
      final attempt = await controller().unlockWithPassword(newPassword);
      expect(attempt, isA<PasswordAccepted>());
    });

    test('yanlış anahtar kilitli bırakıyor', () async {
      await setUpLockedVault();

      expect(
        () => controller().unlockWithRecoveryKey('gecersiz'),
        throwsException,
      );
      expect(status(), isA<VaultLocked>());
    });
  });
}

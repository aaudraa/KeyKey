import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/platform/backup_folders.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/backup/application/auto_backup_controller.dart';
import 'package:keykey/features/backup/application/auto_backup_files.dart';
import 'package:keykey/features/backup/application/backup_service.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

/// Yedek üretirken beklenmeyen bir hata atan servis.
class _BrokenBackups extends FakeBackupService {
  @override
  Future<Uint8List> create(VaultSession session, DateTime now) async =>
      throw const FileSystemException('disk dolu');
}

/// Yazmayı testin istediği an bitiren klasör.
class _SlowFolders extends FakeBackupFolders {
  Completer<void>? gate;

  @override
  Future<bool> write(String uri, String name, Uint8List bytes) async {
    await gate?.future;
    return await super.write(uri, name, bytes);
  }
}

void main() {
  late SodiumSumo sodium;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  const folder = AutoBackupFolder(
    uri: 'content://x/tree/KeyKey',
    name: 'KeyKey',
  );
  final now = DateTime(2026, 11, 18, 15, 30, 12);
  const device = 'a1b2c3';
  String autoName(DateTime time) =>
      AutoBackupFiles.nameFor(time, prefix: 'keykey-otomatik', device: device);
  final nowName = autoName(now);

  late FakeBackupFolders folders;
  late FakeBackupService backups;
  late FakeSettingsRepository settings;

  setUp(() {
    folders = FakeBackupFolders()..granted.add(folder.uri);
    backups = FakeBackupService();
    settings = FakeSettingsRepository(
      AppSettings.defaults.withAutoBackupFolder(folder),
    );
  });

  /// Kasası açık bir uygulama; otomatik yedek denetleyicisi dinleniyor.
  ProviderContainer open() {
    final service = FakeVaultService(sodium);
    final container = ProviderContainer(
      overrides: [
        vaultServiceProvider.overrideWithValue(service),
        initialVaultStatusProvider.overrideWithValue(
          VaultOpen(service.newSession()),
        ),
        settingsRepositoryFactoryProvider.overrideWithValue((_) => settings),
        loginRepositoryFactoryProvider.overrideWithValue(
          (_) => FakeLoginRepository(),
        ),
        otpRepositoryFactoryProvider.overrideWithValue(
          (_) => FakeOtpRepository(),
        ),
        backupFoldersProvider.overrideWithValue(folders),
        backupServiceProvider.overrideWithValue(backups),
        backupClockProvider.overrideWithValue(() => now),
        autoBackupPrefixProvider.overrideWithValue('keykey-otomatik'),
        autoBackupDeviceProvider.overrideWithValue(device),
      ],
    );
    addTearDown(container.dispose);
    container.listen(autoBackupControllerProvider, (_, _) {});
    return container;
  }

  Map<String, Uint8List> files() => folders.files[folder.uri] ?? {};

  test('klasör seçilmemişse yazılmaz', () {
    fakeAsync((async) {
      settings.settings = AppSettings.defaults;
      backups.latest = now.subtract(const Duration(hours: 1));
      open();
      async.elapse(const Duration(seconds: 10));
      expect(folders.writes, 0);
    });
  });

  test('kasa açılınca, değişiklik son yedekten yeniyse 5 sn sonra yazılır', () {
    fakeAsync((async) {
      backups.latest = now.subtract(const Duration(hours: 1));
      final container = open();
      async.elapse(const Duration(seconds: 4));
      expect(folders.writes, 0);
      async.elapse(const Duration(seconds: 2));
      expect(folders.writes, 1);
      expect(files().keys, [nowName]);
      expect(files()[nowName], backups.bytes);
      expect(settings.settings.lastBackupAt, now);
      expect(container.read(autoBackupControllerProvider).problem, isNull);
    });
  });

  test('son değişim son yedekten eskiyse yazılmaz', () {
    fakeAsync((async) {
      settings.settings = settings.settings.copyWith(lastBackupAt: now);
      backups.latest = now.subtract(const Duration(hours: 1));
      open();
      async.elapse(const Duration(seconds: 10));
      expect(folders.writes, 0);
    });
  });

  test('boş kasada yazılmaz', () {
    fakeAsync((async) {
      open();
      async.elapse(const Duration(seconds: 10));
      expect(folders.writes, 0);
    });
  });

  test('5 sn içinde gelen üç değişiklik tek yazmaya iner', () {
    fakeAsync((async) {
      settings.settings = settings.settings.copyWith(
        lastBackupAt: now.subtract(const Duration(days: 1)),
      );
      backups.latest = now.subtract(const Duration(days: 2));
      final container = open();
      async.elapse(const Duration(seconds: 10));
      expect(folders.writes, 0);

      backups.latest = now.subtract(const Duration(minutes: 1));
      final logins = container.read(loginsControllerProvider.notifier);
      for (final name in ['A', 'B', 'C']) {
        unawaited(logins.add(LoginContent(name: name)));
        async.elapse(const Duration(seconds: 2));
      }
      expect(folders.writes, 0);
      async.elapse(const Duration(seconds: 4));
      expect(folders.writes, 1);
    });
  });

  test('2FA listesi değişince de yazılır', () {
    fakeAsync((async) {
      settings.settings = settings.settings.copyWith(lastBackupAt: now);
      backups.latest = now.subtract(const Duration(hours: 1));
      final container = open();
      async.elapse(const Duration(seconds: 10));
      expect(folders.writes, 0);

      backups.latest = now.add(const Duration(seconds: 1));
      container
        ..invalidate(otpsControllerProvider)
        ..read(otpsControllerProvider);
      async.elapse(const Duration(seconds: 6));
      expect(folders.writes, 1);
    });
  });

  test('klasöre erişim yoksa yedek üretilmez, durum noAccess', () {
    fakeAsync((async) {
      folders.granted.clear();
      backups.latest = now.subtract(const Duration(hours: 1));
      final container = open();
      async.elapse(const Duration(seconds: 6));
      expect(backups.creates, 0);
      expect(folders.writes, 0);
      expect(
        container.read(autoBackupControllerProvider).problem,
        AutoBackupProblem.noAccess,
      );
    });
  });

  test('yazılamazsa writeFailed; eski yedekler kalır, son yedek ilerlemez', () {
    fakeAsync((async) {
      final old = autoName(now.subtract(const Duration(hours: 3)));
      folders.files[folder.uri] = {
        old: Uint8List.fromList([9]),
      };
      folders.failWrites = true;
      backups.latest = now.subtract(const Duration(hours: 1));
      final container = open();
      async.elapse(const Duration(seconds: 6));
      expect(files().keys, [old]);
      expect(settings.settings.lastBackupAt, isNull);
      expect(
        container.read(autoBackupControllerProvider).problem,
        AutoBackupProblem.writeFailed,
      );
    });
  });

  test(
    'yazmadan sonra fazlası ve yarım ara dosya silinir, elle yedek kalır',
    () {
      fakeAsync((async) {
        final olds = [
          for (var hours = 1; hours <= 5; hours++)
            autoName(now.subtract(Duration(minutes: hours * 10))),
        ];
        final part = AutoBackupFiles.partName(
          autoName(now.subtract(const Duration(minutes: 5))),
        );
        const manual = 'keykey-yedek-2026-11-18.keykey';
        folders.files[folder.uri] = {
          for (final name in olds) name: Uint8List.fromList([9]),
          part: Uint8List.fromList([7]),
          manual: Uint8List.fromList([8]),
        };
        backups.latest = now.subtract(const Duration(hours: 1));
        open();
        async.elapse(const Duration(seconds: 6));
        expect(
          files().keys,
          unorderedEquals([manual, nowName, ...olds.take(4)]),
        );
      });
    },
  );

  test('zamanlayıcı beklerken kasa kilitlenirse yazılmaz', () {
    fakeAsync((async) {
      backups.latest = now.subtract(const Duration(hours: 1));
      final container = open();
      async.elapse(const Duration(seconds: 2));
      container.read(vaultControllerProvider.notifier).lock();
      async.elapse(const Duration(seconds: 10));
      expect(folders.writes, 0);
    });
  });

  test('yazarken kasa kilitlenirse iş hatasız biter', () {
    fakeAsync((async) {
      final slow = _SlowFolders()
        ..granted.add(folder.uri)
        ..gate = Completer<void>();
      folders = slow;
      backups.latest = now.subtract(const Duration(hours: 1));
      final container = open();
      async.elapse(const Duration(seconds: 6));
      container.read(vaultControllerProvider.notifier).lock();
      slow.gate!.complete();
      async.flushMicrotasks();
      expect(files().keys, [nowName]);
      expect(settings.settings.lastBackupAt, isNull);
      expect(container.read(autoBackupControllerProvider).problem, isNull);
    });
  });

  test('backUpNow değişiklik ölçütüne bakmadan yazar', () {
    fakeAsync((async) {
      settings.settings = settings.settings.copyWith(lastBackupAt: now);
      final container = open();
      async.elapse(const Duration(seconds: 6));
      expect(folders.writes, 0);
      bool? result;
      unawaited(
        container
            .read(autoBackupControllerProvider.notifier)
            .backUpNow()
            .then((value) => result = value),
      );
      async.flushMicrotasks();
      expect(result, isTrue);
      expect(files().keys, [nowName]);
    });
  });

  test('backUpNow kapalıyken false döner', () {
    fakeAsync((async) {
      settings.settings = AppSettings.defaults;
      final container = open();
      async.flushMicrotasks();
      bool? result;
      unawaited(
        container
            .read(autoBackupControllerProvider.notifier)
            .backUpNow()
            .then((value) => result = value),
      );
      async.flushMicrotasks();
      expect(result, isFalse);
      expect(folders.writes, 0);
    });
  });

  test('useFolder eski klasörü bırakır, yenisini yazar ve yedekler', () {
    fakeAsync((async) {
      settings.settings = settings.settings.copyWith(lastBackupAt: now);
      final container = open();
      async.flushMicrotasks();
      const next = FolderPicked(uri: 'content://x/tree/Yeni', name: 'Yeni');
      folders.granted.add(next.uri);
      unawaited(
        container.read(autoBackupControllerProvider.notifier).useFolder(next),
      );
      async.flushMicrotasks();
      expect(folders.released, [folder.uri]);
      expect(settings.settings.autoBackupFolder?.uri, next.uri);
      expect(settings.settings.autoBackupFolder?.name, 'Yeni');
      expect(folders.files[next.uri]?.keys, [nowName]);
    });
  });

  test('disable izni bırakır, ayarı temizler, dosyalara dokunmaz', () {
    fakeAsync((async) {
      final old = autoName(now.subtract(const Duration(days: 1)));
      folders.files[folder.uri] = {
        old: Uint8List.fromList([9]),
      };
      settings.settings = settings.settings.copyWith(lastBackupAt: now);
      final container = open();
      async.flushMicrotasks();
      unawaited(
        container.read(autoBackupControllerProvider.notifier).disable(),
      );
      async.flushMicrotasks();
      expect(folders.released, [folder.uri]);
      expect(settings.settings.autoBackupFolder, isNull);
      expect(files().keys, [old]);
      expect(
        container.read(settingsControllerProvider)?.autoBackupFolder,
        isNull,
      );
    });
  });

  test('aynı saniyedeki iki yedek ayrı adla yazılır', () {
    fakeAsync((async) {
      settings.settings = settings.settings.copyWith(lastBackupAt: now);
      final container = open();
      async.flushMicrotasks();
      final controller = container.read(autoBackupControllerProvider.notifier);
      final results = <bool>[];
      unawaited(controller.backUpNow().then(results.add));
      unawaited(controller.backUpNow().then(results.add));
      async.flushMicrotasks();
      expect(results, [true, true]);
      expect(folders.writes, 2);
      expect(
        files().keys,
        unorderedEquals([
          nowName,
          autoName(now.add(const Duration(seconds: 1))),
        ]),
      );
    });
  });

  test('beklenmeyen hata durum olarak görünür, iş çökmez', () {
    fakeAsync((async) {
      backups = _BrokenBackups()
        ..latest = now.subtract(const Duration(hours: 1));
      final container = open();
      async.elapse(const Duration(seconds: 6));
      expect(
        container.read(autoBackupControllerProvider).problem,
        AutoBackupProblem.writeFailed,
      );
      bool? result;
      unawaited(
        container
            .read(autoBackupControllerProvider.notifier)
            .backUpNow()
            .then((value) => result = value),
      );
      async.flushMicrotasks();
      expect(result, isFalse);
    });
  });

  test('kasa açılınca klasöre erişim yoksa değişiklik beklemeden söylenir', () {
    fakeAsync((async) {
      folders.granted.clear();
      settings.settings = settings.settings.copyWith(lastBackupAt: now);
      backups.latest = now.subtract(const Duration(hours: 1));
      final container = open();
      async.flushMicrotasks();
      expect(
        container.read(autoBackupControllerProvider).problem,
        AutoBackupProblem.noAccess,
      );
      expect(backups.creates, 0);
    });
  });

  test('klasör ayara yazılamazsa yeni klasörün izni bırakılır', () {
    fakeAsync((async) {
      final container = open();
      async.flushMicrotasks();
      const next = FolderPicked(uri: 'content://x/tree/Yeni', name: 'Yeni');
      folders.granted.add(next.uri);
      container.read(vaultControllerProvider.notifier).lock();
      Object? error;
      unawaited(
        container
            .read(autoBackupControllerProvider.notifier)
            .useFolder(next)
            .then((_) {}, onError: (Object e) => error = e),
      );
      async.flushMicrotasks();
      expect(error, isA<VaultLockedException>());
      expect(folders.released, [next.uri]);
    });
  });

  test(
    'kilit ve yeniden açılıştan sonra eski iş son yedek zamanını yazmaz',
    () {
      fakeAsync((async) {
        final slow = _SlowFolders()
          ..granted.add(folder.uri)
          ..gate = Completer<void>();
        folders = slow;
        backups.latest = now.subtract(const Duration(hours: 1));
        final container = open();
        async.elapse(const Duration(seconds: 6));
        final vault = container.read(vaultControllerProvider.notifier)..lock();
        unawaited(vault.unlockWithPassword(FakeVaultService.correctPassword));
        async.flushMicrotasks();
        expect(container.read(vaultControllerProvider), isA<VaultOpen>());
        slow.gate!.complete();
        async.flushMicrotasks();
        expect(settings.settings.lastBackupAt, isNull);
      });
    },
  );

  test('kurtarma anahtarıyla yeni parola belirlenince hemen yazılır', () {
    fakeAsync((async) {
      settings.settings = settings.settings.copyWith(lastBackupAt: now);
      backups.latest = now.subtract(const Duration(hours: 1));
      final container = open();
      async.elapse(const Duration(seconds: 10));
      expect(folders.writes, 0);

      final vault = container.read(vaultControllerProvider.notifier)
        ..lock()
        ..unlockWithRecoveryKey(FakeVaultService.recoveryKey);
      unawaited(vault.setNewPassword('yeni-Ana-Parola-58'));
      // Değişiklik zamanlayıcısından (5 sn) önce.
      async.elapse(const Duration(seconds: 1));

      expect(container.read(vaultControllerProvider), isA<VaultOpen>());
      expect(folders.writes, 1);
    });
  });
}

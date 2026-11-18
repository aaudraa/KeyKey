import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/platform/backup_folders.dart';
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
  final nowName = AutoBackupFiles.nameFor(now, prefix: 'keykey-otomatik');

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
      final old = AutoBackupFiles.nameFor(
        now.subtract(const Duration(hours: 3)),
        prefix: 'keykey-otomatik',
      );
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
    'başarılı yazmadan sonra aynı günün eskisi silinir, elle yedek kalır',
    () {
      fakeAsync((async) {
        final old = AutoBackupFiles.nameFor(
          now.subtract(const Duration(hours: 3)),
          prefix: 'keykey-otomatik',
        );
        const manual = 'keykey-yedek-2026-11-18.keykey';
        folders.files[folder.uri] = {
          old: Uint8List.fromList([9]),
          manual: Uint8List.fromList([8]),
        };
        backups.latest = now.subtract(const Duration(hours: 1));
        open();
        async.elapse(const Duration(seconds: 6));
        expect(files().keys, unorderedEquals([manual, nowName]));
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
      final old = AutoBackupFiles.nameFor(
        now.subtract(const Duration(days: 1)),
        prefix: 'keykey-otomatik',
      );
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
}

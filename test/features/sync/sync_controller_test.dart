import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/network/sync_transport.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/sync/application/sync_controller.dart';
import 'package:keykey/features/sync/application/sync_merger.dart';
import 'package:keykey/features/sync/application/sync_service.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/application/records_controller.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../core/storage/test_data.dart';
import '../../support/fake_sync_service.dart';
import '../../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;
  late FakeSyncService sync;
  late FakeSettingsRepository settings;
  late DateTime clock;

  final syncSettings = SyncSettings(
    folder: Uri.parse('https://bulut.example.com/dav/KeyKey/'),
    username: 'ayse',
    appPassword: 'uygulama-parolasi',
  );

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    sync = FakeSyncService();
    settings = FakeSettingsRepository(
      AppSettings.defaults.withSync(syncSettings),
    );
    clock = DateTime.utc(2026, 11, 20, 12);
  });

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
        cardRepositoryFactoryProvider.overrideWithValue(
          (_) => FakeRecordRepository<CardContent>(),
        ),
        noteRepositoryFactoryProvider.overrideWithValue(
          (_) => FakeRecordRepository<NoteContent>(),
        ),
        syncServiceProvider.overrideWithValue(sync),
        syncClockProvider.overrideWithValue(() => clock),
      ],
    );
    addTearDown(container.dispose);
    container.listen(syncControllerProvider, (_, _) {});
    return container;
  }

  SyncController controller(ProviderContainer c) =>
      c.read(syncControllerProvider.notifier);

  test('kasa açılınca bir eşitleme, sonuç ayarlara yazılıyor', () {
    fakeAsync((async) {
      final container = open();
      async.elapse(const Duration(seconds: 1));
      expect(sync.calls, 1);
      expect(settings.settings.sync!.lastDigest, FakeSyncService.digest);
      expect(settings.settings.sync!.lastSyncAt, sync.at);
      final status = container.read(syncControllerProvider);
      expect(status.enabled, isTrue);
      expect(status.running, isFalse);
      expect(status.lastSyncAt, sync.at);
      expect(status.devices.single.self, isTrue);

      async.elapse(const Duration(seconds: 30));
      expect(sync.calls, 1);
    });
  });

  test('peş peşe üç değişiklik 5 sn sonra tek eşitleme', () {
    fakeAsync((async) {
      final container = open();
      async.elapse(const Duration(seconds: 1));
      expect(sync.calls, 1);

      final logins = container.read(loginsControllerProvider.notifier);
      unawaited(logins.add(const LoginContent(name: 'A')));
      async.elapse(const Duration(seconds: 2));
      controller(container).onRecordsChanged();
      async.elapse(const Duration(seconds: 2));
      controller(container).onRecordsChanged();
      async.elapse(const Duration(seconds: 4));
      expect(sync.calls, 1);
      async.elapse(const Duration(seconds: 2));
      expect(sync.calls, 2);
    });
  });

  test('öne gelince son eşitlemeden 60 sn geçtiyse eşitleniyor', () {
    fakeAsync((async) {
      final container = open();
      async.elapse(const Duration(seconds: 1));
      expect(sync.calls, 1);

      clock = clock.add(const Duration(seconds: 59));
      controller(container).onResumed();
      async.elapse(const Duration(seconds: 1));
      expect(sync.calls, 1);

      clock = clock.add(const Duration(seconds: 1));
      controller(container).onResumed();
      async.elapse(const Duration(seconds: 1));
      expect(sync.calls, 2);
    });
  });

  test('sürerken gelen istekler bittikten sonra tek eşitleme', () {
    fakeAsync((async) {
      sync.gate = Completer();
      final container = open();
      async.elapse(const Duration(seconds: 1));
      expect(sync.calls, 1);
      expect(container.read(syncControllerProvider).running, isTrue);

      SyncStatus? first;
      unawaited(controller(container).syncNow().then((s) => first = s));
      unawaited(controller(container).syncNow());
      async.elapse(const Duration(seconds: 1));
      expect(sync.calls, 1);

      sync.gate!.complete();
      async.elapse(const Duration(seconds: 1));
      expect(sync.calls, 2);
      expect(first?.lastSyncAt, sync.at);
      expect(container.read(syncControllerProvider).running, isFalse);
      async.elapse(const Duration(seconds: 30));
      expect(sync.calls, 2);
    });
  });

  test('sürerken kilitlenirse sonuç atılıyor', () {
    fakeAsync((async) {
      sync.gate = Completer();
      final container = open();
      async.elapse(const Duration(seconds: 1));
      expect(sync.calls, 1);

      container.read(vaultControllerProvider.notifier).lock();
      sync.gate!.complete();
      async.elapse(const Duration(seconds: 1));

      expect(settings.settings.sync!.lastDigest, isNull);
      final status = container.read(syncControllerProvider);
      expect(status.lastSyncAt, isNull);
      expect(status.enabled, isFalse);
    });
  });

  test('sürerken kilitlenirse kilit ekranı diskteki üst bilgiyi alıyor', () {
    fakeAsync((async) {
      sync.gate = Completer();
      final container = open();
      async.elapse(const Duration(seconds: 1));
      expect(sync.calls, 1);
      final service = container.read(vaultServiceProvider) as FakeVaultService;

      container.read(vaultControllerProvider.notifier).lock();
      // Kilitten hemen önce başlamış eşitleme yuvaları değiştirip yazdı.
      final written = service.header.withRecoverySlot(
        sampleHeader(fill: 2).recoverySlot,
      );
      service.storedHeader = written;
      sync.gate!.complete();
      async.elapse(const Duration(seconds: 1));

      final status = container.read(vaultControllerProvider);
      expect(status, isA<VaultLocked>());
      expect((status as VaultLocked).header, same(written));
    });
  });

  test('kilitten sonra bellek yenileniyor', () {
    fakeAsync((async) {
      final container = open();
      async.elapse(const Duration(seconds: 1));
      final vault = container.read(vaultControllerProvider.notifier)..lock();
      async.elapse(const Duration(seconds: 1));
      unawaited(vault.unlockWithPassword(FakeVaultService.correctPassword));
      async.elapse(const Duration(seconds: 1));
      expect(sync.calls, 2);
      expect(sync.caches[0], isNot(same(sync.caches[1])));
    });
  });

  test('ana parola ya da kurtarma anahtarı değişince hemen eşitleniyor', () {
    fakeAsync((async) {
      final container = open();
      async.elapse(const Duration(seconds: 1));
      expect(sync.calls, 1);
      final vault = container.read(vaultControllerProvider.notifier);

      // Eski parolayla açılan dosya sunucuda beklemesin.
      unawaited(
        vault.changePassword(
          currentPassword: FakeVaultService.correctPassword,
          newPassword: 'yepyeni-Ana-Parola-58',
        ),
      );
      async.elapse(const Duration(seconds: 1));
      expect(sync.calls, 2);

      // Yanlış parolada üst bilgi değişmez.
      unawaited(
        vault.changePassword(
          currentPassword: 'yanlis-Ana-Parola-1',
          newPassword: 'yepyeni-Ana-Parola-58',
        ),
      );
      async.elapse(const Duration(seconds: 1));
      expect(sync.calls, 2);

      PendingRecoveryKey? pending;
      unawaited(
        vault
            .prepareNewRecoveryKey(FakeVaultService.correctPassword)
            .then((result) => pending = result.$2),
      );
      async.elapse(const Duration(seconds: 1));
      // Hazırlamak diske yazmaz.
      expect(sync.calls, 2);
      unawaited(
        vault.confirmNewRecoveryKey(pending!, FakeVaultService.newRecoveryKey),
      );
      async.elapse(const Duration(seconds: 1));
      expect(sync.calls, 3);
    });
  });

  test('senkron kapalıyken hiçbir tetik eşitlemiyor', () {
    fakeAsync((async) {
      settings.settings = AppSettings.defaults;
      final container = open();
      async.elapse(const Duration(seconds: 1));
      unawaited(
        container
            .read(vaultControllerProvider.notifier)
            .changePassword(
              currentPassword: FakeVaultService.correctPassword,
              newPassword: 'yepyeni-Ana-Parola-58',
            ),
      );
      controller(container)
        ..onRecordsChanged()
        ..onResumed();
      SyncStatus? status;
      unawaited(controller(container).syncNow().then((s) => status = s));
      async.elapse(const Duration(seconds: 10));
      expect(sync.calls, 0);
      expect(status?.enabled, isFalse);
    });
  });

  test('hata türü durumda, başarı onu temizliyor', () {
    fakeAsync((async) {
      sync.error = const SyncTransportException(SyncFailureKind.unauthorized);
      final container = open();
      async.elapse(const Duration(seconds: 1));
      expect(
        container.read(syncControllerProvider).failure,
        SyncFailureKind.unauthorized,
      );
      expect(settings.settings.sync!.lastDigest, isNull);

      sync.error = const OtherVaultException();
      unawaited(controller(container).syncNow());
      async.elapse(const Duration(seconds: 1));
      expect(container.read(syncControllerProvider).otherVault, isTrue);

      sync.error = null;
      unawaited(controller(container).syncNow());
      async.elapse(const Duration(seconds: 1));
      final status = container.read(syncControllerProvider);
      expect(status.failure, isNull);
      expect(status.otherVault, isFalse);
    });
  });

  test('parola ya da kurtarma değişikliği bir kez bildiriliyor', () {
    fakeAsync((async) {
      sync.issues = const [PasswordAdopted(), ClockAhead('b2c3d4')];
      final container = open();
      async.elapse(const Duration(seconds: 1));
      final status = container.read(syncControllerProvider);
      expect(status.issues, hasLength(2));
      expect(controller(container).consumeNotice(), isA<PasswordAdopted>());
      expect(controller(container).consumeNotice(), isNull);
    });
  });

  test('kasa değişince listeler yeniden okunuyor', () {
    fakeAsync((async) {
      sync
        ..changedLocal = true
        ..gate = Completer();
      final container = open();
      final states = <OtpsState>[];
      container.listen(otpsControllerProvider, (_, next) => states.add(next));
      async.elapse(const Duration(seconds: 1));
      expect(container.read(otpsControllerProvider), isA<OtpsLoaded>());
      states.clear();

      sync.gate!.complete();
      async.elapse(const Duration(seconds: 1));
      expect(sync.calls, 1);
      expect(states.first, isA<OtpsLoading>());
      expect(states.last, isA<OtpsLoaded>());
    });
  });
}

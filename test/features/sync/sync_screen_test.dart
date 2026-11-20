import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/kk_snack.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/network/sync_transport.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/sync/application/sync_controller.dart';
import 'package:keykey/features/sync/application/sync_join.dart';
import 'package:keykey/features/sync/application/sync_merger.dart';
import 'package:keykey/features/sync/application/sync_service.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_sync_service.dart';
import '../../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;
  late FakeSyncService sync;
  late FakeSettingsRepository settings;
  late FakeSyncJoin join;

  final enabled = SyncSettings(
    folder: Uri.parse('https://bulut.example.com/dav/KeyKey/'),
    username: 'ayse',
    appPassword: 'uygulama-parolasi',
  );

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    sync = FakeSyncService();
    settings = FakeSettingsRepository();
    join = FakeSyncJoin();
  });

  Future<FakeVaultService> openSync(
    WidgetTester tester, {
    String route = AppRoutes.sync,
  }) async {
    final service = FakeVaultService(sodium);
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      settings: settings,
      extraOverrides: [
        syncServiceProvider.overrideWithValue(sync),
        syncJoinProvider.overrideWithValue(join),
        syncClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 11, 20, 12, 2),
        ),
      ],
    );
    join.next = service.newSession;
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(route);
    await tester.pumpAndSettle();
    return service;
  }

  Future<void> fill(
    WidgetTester tester, {
    String folder = 'https://bulut.example.com/dav/KeyKey/',
  }) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'Klasörün adresi'),
      folder,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Kullanıcı adı'),
      'ayse',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Uygulama parolası'),
      'uygulama-parolasi',
    );
    await tester.pump();
  }

  Future<void> connect(WidgetTester tester) async {
    await tester.tap(find.text('Bağlan'));
    await tester.pumpAndSettle();
  }

  group('açma', () {
    testWidgets('ayarlarda kapalı görünüyor, satır ekrana götürüyor', (
      tester,
    ) async {
      await openSync(tester, route: AppRoutes.settings);
      await tester.scrollUntilVisible(find.text('Senkron'), 200);
      expect(
        find.text(
          'Kapalı. Kasayı kendi WebDAV sunucun üzerinden telefonların '
          'arasında eşitler.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Senkron'));
      await tester.pumpAndSettle();
      expect(find.text('Bağlan'), findsOneWidget);
    });

    testWidgets('boş klasör: pencere, açılır ve eşitlenir', (tester) async {
      await openSync(tester);
      await fill(tester);
      await connect(tester);

      expect(sync.inspected.single.folder, enabled.folder);
      expect(find.text('Senkron açılsın mı?'), findsOneWidget);
      expect(settings.settings.sync, isNull);
      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();

      final saved = settings.settings.sync!;
      expect(saved.folder, enabled.folder);
      expect(saved.username, 'ayse');
      expect(saved.appPassword, 'uygulama-parolasi');
      expect(saved.lastDigest, FakeSyncService.digest);
      expect(sync.calls, 1);
      expect(find.text('Şimdi eşitle'), findsOneWidget);
      expect(find.text('Bu telefon'), findsOneWidget);
    });

    testWidgets('vazgeçilince bir şey yazılmıyor', (tester) async {
      sync.folder = const FolderSameVault();
      await openSync(tester);
      await fill(tester);
      await connect(tester);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(settings.settings.sync, isNull);
      expect(sync.calls, 0);
    });

    testWidgets('yanlış kimlikte söyleniyor, ayar yazılmıyor', (tester) async {
      sync.inspectError = const SyncTransportException(
        SyncFailureKind.unauthorized,
      );
      await openSync(tester);
      await fill(tester);
      await connect(tester);
      expect(
        find.text('Kullanıcı adı ya da uygulama parolası yanlış.'),
        findsOneWidget,
      );
      expect(find.text('Senkron açılsın mı?'), findsNothing);
      expect(settings.settings.sync, isNull);
    });

    testWidgets('https olmayan adres sunucuya sorulmuyor', (tester) async {
      await openSync(tester);
      await fill(tester, folder: 'http://bulut.example.com/dav/');
      await connect(tester);
      expect(find.text('Adres https:// ile başlamalı.'), findsOneWidget);
      expect(sync.inspected, isEmpty);
    });

    testWidgets('başka kasanın klasörü açılmıyor', (tester) async {
      final service = FakeVaultService(sodium);
      final codec = BackupCodec(sodium);
      final key = sodium.secureRandom(32);
      final bytes = await tester.runAsync(
        () => codec.encode(
          header: service.header,
          vaultKey: key,
          records: const [],
          createdAt: DateTime.utc(2026),
        ),
      );
      key.dispose();
      sync.folder = FolderOtherVault(codec.parse(bytes!));
      await openSync(tester);
      await fill(tester);
      await connect(tester);
      expect(
        find.text('Bu klasörde başka bir KeyKey kasası var.'),
        findsOneWidget,
      );
      expect(find.text('Aç'), findsNothing);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(settings.settings.sync, isNull);
    });

    testWidgets('karışık klasörde açma düğmesi yok', (tester) async {
      sync.folder = const FolderMixedVaults();
      await openSync(tester);
      await fill(tester);
      await connect(tester);
      expect(find.text('Bu klasörde birden çok kasa var.'), findsOneWidget);
      expect(find.text('Boş bir klasör seç.'), findsOneWidget);
      expect(find.text('Aç'), findsNothing);
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      expect(settings.settings.sync, isNull);
    });
  });

  group('başka kasaya katılma', () {
    const warning =
        'Bu telefonun ana parolası ve kurtarma anahtarı artık geçmez; '
        'senkron kasasınınkiler geçer.';

    Future<void> toJoin(WidgetTester tester) async {
      final codec = BackupCodec(sodium);
      final key = sodium.secureRandom(32);
      final bytes = await tester.runAsync(
        () => codec.encode(
          header: FakeVaultService(sodium).header,
          vaultKey: key,
          records: const [],
          createdAt: DateTime.utc(2026),
          sync: const SyncInfo(device: 'd4e5f6'),
        ),
      );
      key.dispose();
      sync.folder = FolderOtherVault(codec.parse(bytes!));
      await openSync(tester);
      await fill(tester);
      await connect(tester);
      await tester.tap(find.text('Bu telefonu o kasaya kat'));
      await tester.pumpAndSettle();
    }

    Future<void> submit(WidgetTester tester, String secret) async {
      await tester.enterText(find.byType(TextField), secret);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Kasaya katıl'));
      await tester.pumpAndSettle();
    }

    testWidgets('uyarıdan sonra o kasanın parolasıyla katılıyor', (
      tester,
    ) async {
      join.onJoin = () =>
          settings.settings = AppSettings.defaults.withSync(enabled);
      await toJoin(tester);
      expect(find.text(warning), findsOneWidget);
      await tester.tap(find.text('Kat'));
      await tester.pumpAndSettle();

      await submit(tester, 'O-Kasanin-Parolasi-1');

      expect(join.joins, 1);
      expect(join.secret, 'O-Kasanin-Parolasi-1');
      expect(join.isRecoveryKey, isFalse);
      expect(join.settings!.folder, enabled.folder);
      expect(
        find.text(
          'Bu telefonda artık senkron kasasının ana parolası geçerli. '
          'Parmak iziyle açmayı yeniden aç.',
        ),
        findsOneWidget,
      );
      expect(find.text('Şimdi eşitle'), findsOneWidget);
      expect(sync.calls, greaterThanOrEqualTo(1));
    });

    testWidgets('yanlış parola söyleniyor, bir şey değişmiyor', (tester) async {
      join.error = const WrongSecretException();
      await toJoin(tester);
      await tester.tap(find.text('Kat'));
      await tester.pumpAndSettle();
      await submit(tester, 'yanlis-Parola-99');

      expect(find.text('Bu parola o kasayı açmadı.'), findsOneWidget);
      expect(join.joins, 0);
      expect(settings.settings.sync, isNull);
    });

    testWidgets('uyarıda vazgeçilince katılmıyor', (tester) async {
      await toJoin(tester);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(find.text('Kasaya katıl'), findsNothing);
      expect(find.text('Bağlan'), findsOneWidget);
      expect(join.joins, 0);
    });
  });

  group('açıkken', () {
    setUp(() {
      settings = FakeSettingsRepository(AppSettings.defaults.withSync(enabled));
      sync.devices = [
        const SyncDevice(device: 'a1b2c3', name: 'SM-G780G', self: true),
        SyncDevice(
          device: 'd4e5f6',
          name: 'Pixel 8',
          modified: DateTime.utc(2026, 11, 17, 12),
        ),
      ];
    });

    testWidgets('durum ve cihazlar görünüyor', (tester) async {
      await openSync(tester);
      expect(sync.calls, 1);
      expect(find.text('Şimdi eşitle'), findsOneWidget);
      expect(find.text('Bu telefon · SM-G780G'), findsOneWidget);
      expect(find.text('Pixel 8 · d4e5f6'), findsOneWidget);
      expect(find.text('3 gün önce'), findsOneWidget);
      // Kendi satırında kaldırma yok.
      expect(find.text('Kaldır'), findsOneWidget);

      await tester.tap(find.text('Şimdi eşitle'));
      await tester.pumpAndSettle();
      expect(sync.calls, 2);
      expect(find.text('Eşitlendi'), findsOneWidget);
    });

    testWidgets('hata satırda yazıyor', (tester) async {
      sync.error = const SyncTransportException(SyncFailureKind.notFound);
      await openSync(tester);
      expect(find.text('Klasör bulunamadı; adresi denetle.'), findsOneWidget);
    });

    testWidgets('sorunlar telefon adıyla yazıyor', (tester) async {
      sync.issues = const [ClockAhead('d4e5f6'), UnreadableDevice('0f0f0f')];
      await openSync(tester);
      expect(
        find.text('Pixel 8 telefonunun saati ileride; dosyası alınmadı.'),
        findsOneWidget,
      );
      expect(
        find.text('0f0f0f telefonunun dosyası okunamadı.'),
        findsOneWidget,
      );
    });

    testWidgets('Kaldır o telefonun dosyasını siliyor', (tester) async {
      await openSync(tester);
      await tester.tap(find.text('Kaldır'));
      await tester.pumpAndSettle();
      expect(find.text('Pixel 8 kaldırılsın mı?'), findsOneWidget);
      await tester.tap(find.text('Kaldır').last);
      await tester.pumpAndSettle();
      expect(sync.removed, ['d4e5f6']);
      expect(find.text('Telefon kaldırıldı'), findsOneWidget);
    });

    testWidgets('kapatınca kendi dosyası da siliniyor', (tester) async {
      await openSync(tester);
      await tester.scrollUntilVisible(find.text('Senkronu kapat'), 200);
      await tester.tap(find.text('Senkronu kapat'));
      await tester.pumpAndSettle();
      final box = tester.widget<CheckboxListTile>(
        find.widgetWithText(
          CheckboxListTile,
          'Bu telefonun sunucudaki dosyasını da sil',
        ),
      );
      expect(box.value, isTrue);
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      expect(sync.removed, ['a1b2c3']);
      expect(settings.settings.sync, isNull);
      expect(find.text('Bağlan'), findsOneWidget);
    });

    testWidgets('kutu kaldırılınca dosya kalıyor', (tester) async {
      await openSync(tester);
      await tester.scrollUntilVisible(find.text('Senkronu kapat'), 200);
      await tester.tap(find.text('Senkronu kapat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bu telefonun sunucudaki dosyasını da sil'));
      await tester.pump();
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      expect(sync.removed, isEmpty);
      expect(settings.settings.sync, isNull);
    });

    testWidgets('parola değişikliği bir kez bildiriliyor', (tester) async {
      sync.issues = const [PasswordAdopted()];
      await openSync(tester, route: AppRoutes.vault);
      const notice =
          'Ana parola başka bir telefonda değiştirildi. Kasayı bir sonraki '
          'açışında yeni parolayı kullan.';
      expect(find.text(notice), findsOneWidget);
      hideKkSnack();
      await tester.pumpAndSettle();

      sync.issues = const [];
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go(AppRoutes.sync);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Şimdi eşitle'));
      await tester.pumpAndSettle();
      expect(find.text(notice), findsNothing);
    });
  });

  for (final on in [false, true]) {
    testWidgets(
      'dar ekranda ve büyük yazıda taşma yok (${on ? 'açık' : 'kapalı'})',
      (tester) async {
        if (on) {
          settings = FakeSettingsRepository(
            AppSettings.defaults.withSync(enabled),
          );
          sync
            ..devices = const [
              SyncDevice(device: 'a1b2c3', name: 'SM-G780G', self: true),
              SyncDevice(device: 'd4e5f6', name: 'Galaxy Tab S9 FE Plus 5G'),
            ]
            ..issues = const [SlotsDiffer('d4e5f6')];
        }
        await openSync(tester);
        // Yalnızca bu ekran ölçülür: alttaki sekmeler sahne dışında kalır.
        tester.view
          ..physicalSize = const Size(320, 640)
          ..devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(on ? 'Şimdi eşitle' : 'Bağlan'), findsOneWidget);
      },
    );
  }
}

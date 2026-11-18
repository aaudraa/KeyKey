import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/platform/backup_folders.dart';
import 'package:keykey/features/backup/application/auto_backup_files.dart';
import 'package:keykey/features/backup/presentation/backup_status_card.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeBackupFolders folders;
  late FakeBackupService backups;
  late FakeSettingsRepository settings;

  const folder = AutoBackupFolder(
    uri: 'content://x/tree/KeyKey',
    name: 'KeyKey',
  );
  final now = DateTime(2026, 11, 18, 15, 30, 12);

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
    folders = FakeBackupFolders();
    backups = FakeBackupService();
    settings = FakeSettingsRepository(
      AppSettings.defaults.copyWith(lastBackupAt: now),
    );
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      folders: folders,
      backups: backups,
      settings: settings,
      clock: () => now,
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('Yedekle')),
    );
    folders.readGate = () => container.read(externalActivityGateProvider);
    await tester.scrollUntilVisible(find.text('Otomatik yedek'), 200);
    await tester.pumpAndSettle();
  }

  Map<String, Uint8List> files(String uri) => folders.files[uri] ?? {};

  testWidgets('kapalıyken ne yaptığını söylüyor', (tester) async {
    await pumpSettings(tester);
    expect(find.textContaining('Kapalı. Kasa değişince'), findsOneWidget);
    expect(find.text('Klasörü değiştir'), findsNothing);
  });

  testWidgets('açmak: açıklama, klasör seçme, ilk yedek', (tester) async {
    folders.nextPick = FolderPicked(uri: folder.uri, name: folder.name);
    await pumpSettings(tester);
    await tester.tap(find.text('Otomatik yedek'));
    await tester.pumpAndSettle();
    expect(find.textContaining('eşitleme uygulamasının'), findsOneWidget);

    await tester.tap(find.text('Klasör seç'));
    await tester.pumpAndSettle();
    expect(folders.picks, 1);
    expect(folders.gateWasActive, isTrue);
    expect(settings.settings.autoBackupFolder?.uri, folder.uri);
    expect(files(folder.uri).keys, [
      AutoBackupFiles.nameFor(now, prefix: 'keykey-otomatik'),
    ]);
    expect(find.text('Otomatik yedek açıldı'), findsOneWidget);
    expect(find.text('KeyKey klasörüne yazıyor'), findsOneWidget);
  });

  testWidgets('seçiciden vazgeçilirse kapalı kalıyor', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Otomatik yedek'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Klasör seç'));
    await tester.pumpAndSettle();
    expect(settings.settings.autoBackupFolder, isNull);
    expect(folders.writes, 0);
    expect(find.textContaining('Kapalı. Kasa değişince'), findsOneWidget);
  });

  testWidgets('açıklamada vazgeçilirse seçici açılmıyor', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Otomatik yedek'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(folders.picks, 0);
  });

  group('açıkken', () {
    setUp(() {
      settings.settings = settings.settings.withAutoBackupFolder(folder);
      folders
        ..granted.add(folder.uri)
        ..files[folder.uri] = {};
    });

    testWidgets('kapatmak izni bırakıyor, dosyalar kalıyor', (tester) async {
      folders.files[folder.uri] = {'eski.keykey': Uint8List(1)};
      await pumpSettings(tester);
      await tester.tap(find.text('Otomatik yedek'));
      await tester.pumpAndSettle();
      expect(settings.settings.autoBackupFolder, isNull);
      expect(folders.released, [folder.uri]);
      expect(files(folder.uri).keys, ['eski.keykey']);
      expect(find.textContaining('Otomatik yedek kapatıldı'), findsOneWidget);
    });

    testWidgets('"Şimdi yedekle" klasöre yazıyor', (tester) async {
      await pumpSettings(tester);
      await tester.scrollUntilVisible(find.text('Şimdi yedekle'), 200);
      await tester.tap(find.text('Şimdi yedekle'));
      await tester.pumpAndSettle();
      expect(files(folder.uri), hasLength(1));
      expect(find.text('Yedek klasöre yazıldı'), findsOneWidget);
    });

    testWidgets('"Klasörü değiştir" yeni klasöre geçiyor', (tester) async {
      const next = FolderPicked(uri: 'content://x/tree/Yeni', name: 'Yeni');
      folders.nextPick = next;
      await pumpSettings(tester);
      await tester.scrollUntilVisible(find.text('Klasörü değiştir'), 200);
      await tester.tap(find.text('Klasörü değiştir'));
      await tester.pumpAndSettle();
      expect(settings.settings.autoBackupFolder?.uri, next.uri);
      expect(folders.released, [folder.uri]);
      expect(files(next.uri), hasLength(1));
      expect(find.text('Yeni klasörüne yazıyor'), findsOneWidget);
    });

    testWidgets('klasöre erişim yoksa satır ve kart söylüyor', (tester) async {
      folders.granted.clear();
      await pumpSettings(tester);
      await tester.scrollUntilVisible(find.text('Şimdi yedekle'), 200);
      await tester.tap(find.text('Şimdi yedekle'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Klasöre erişilemiyor'), findsOneWidget);
      await tester.scrollUntilVisible(find.byType(BackupStatusCard), -200);
      expect(
        find.descendant(
          of: find.byType(BackupStatusCard),
          matching: find.text('Otomatik yedek yazılamadı'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('yedek kartı klasörün adını gösteriyor', (tester) async {
      await pumpSettings(tester);
      await tester.scrollUntilVisible(find.byType(BackupStatusCard), -200);
      expect(
        find.descendant(
          of: find.byType(BackupStatusCard),
          matching: find.text('Otomatik: KeyKey'),
        ),
        findsOneWidget,
      );
    });
  });
}

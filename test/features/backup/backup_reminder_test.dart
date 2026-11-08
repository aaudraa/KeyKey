import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/backup/application/backup_reminder.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  group('kural', () {
    final now = DateTime.utc(2026, 11, 20, 12);

    BackupReminder? due({
      DateTime? latestChange,
      DateTime? lastBackupAt,
      DateTime? snoozedUntil,
    }) => BackupReminderRule.due(
      now: now,
      latestChange: latestChange,
      lastBackupAt: lastBackupAt,
      snoozedUntil: snoozedUntil,
    );

    test('boş kasada hatırlatma yok', () {
      expect(due(), isNull);
    });

    test('hiç yedek yoksa ve kayıt varsa hatırlatılıyor', () {
      expect(due(latestChange: DateTime.utc(2026, 11)), BackupReminder.never);
    });

    test('son yedekten sonra değişiklik yoksa hatırlatma yok', () {
      expect(
        due(
          latestChange: DateTime.utc(2026, 10),
          lastBackupAt: DateTime.utc(2026, 10, 2),
        ),
        isNull,
      );
    });

    test('değişiklik var ama yedek 14 günden yeni', () {
      expect(
        due(
          latestChange: DateTime.utc(2026, 11, 19),
          lastBackupAt: now.subtract(const Duration(days: 13, hours: 23)),
        ),
        isNull,
      );
    });

    test('değişiklik var ve yedek 14 günü geçmiş', () {
      expect(
        due(
          latestChange: DateTime.utc(2026, 11, 19),
          lastBackupAt: now.subtract(const Duration(days: 14)),
        ),
        BackupReminder.stale,
      );
    });

    test('susturma süresi bitene kadar gösterilmiyor', () {
      expect(
        due(
          latestChange: DateTime.utc(2026, 11),
          snoozedUntil: now.add(const Duration(minutes: 1)),
        ),
        isNull,
      );
      expect(
        due(latestChange: DateTime.utc(2026, 11), snoozedUntil: now),
        BackupReminder.never,
      );
    });
  });

  group('kasa ekranı', () {
    late SodiumSumo sodium;
    late FakeVaultService service;
    late FakeBackupService backups;
    late FakeDocumentFiles documents;
    late FakeSettingsRepository settings;
    final now = DateTime(2026, 11, 20, 12);

    const neverText =
        'Henüz yedek almadın. Bu telefon kaybolursa kasandaki her şey de '
        'kaybolur.';
    const staleText =
        'Son yedeğinden sonra kasanda değişiklik var ve o yedek iki haftadan '
        'eski.';

    setUpAll(() async {
      sodium = await SodiumSumoInit.init();
    });

    setUp(() {
      service = FakeVaultService(sodium);
      backups = FakeBackupService();
      documents = FakeDocumentFiles();
      settings = FakeSettingsRepository();
    });

    Future<void> pump(WidgetTester tester) => pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      backups: backups,
      documents: documents,
      settings: settings,
      clock: () => now,
    );

    testWidgets('boş kasada görünmüyor', (tester) async {
      await pump(tester);
      expect(find.text(neverText), findsNothing);
    });

    testWidgets('hiç yedek yoksa görünüyor, sonra denince susuyor', (
      tester,
    ) async {
      backups.latest = DateTime(2026, 11, 19);
      await pump(tester);
      expect(find.text(neverText), findsOneWidget);

      await tester.tap(find.text('Sonra'));
      await tester.pumpAndSettle();

      expect(
        settings.settings.backupReminderSnoozedUntil,
        now.add(const Duration(days: 7)),
      );
      expect(find.text(neverText), findsNothing);
    });

    testWidgets('eskimiş yedekte görünüyor, yedek alınca kayboluyor', (
      tester,
    ) async {
      backups.latest = DateTime(2026, 11, 19);
      settings = FakeSettingsRepository(
        AppSettings.defaults.copyWith(lastBackupAt: DateTime(2026, 11, 2)),
      );
      await pump(tester);
      expect(find.text(staleText), findsOneWidget);

      await tester.tap(find.text('Yedek al'));
      await tester.pumpAndSettle();

      expect(documents.saves, 1);
      expect(settings.settings.lastBackupAt, now);
      expect(find.text(staleText), findsNothing);
    });

    testWidgets('yeni yedekte görünmüyor', (tester) async {
      backups.latest = DateTime(2026, 11, 19);
      settings = FakeSettingsRepository(
        AppSettings.defaults.copyWith(lastBackupAt: DateTime(2026, 11, 15)),
      );
      await pump(tester);
      expect(find.byIcon(Icons.backup_outlined), findsNothing);
    });
  });
}

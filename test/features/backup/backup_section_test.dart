import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeDocumentFiles documents;
  late FakeBackupService backups;
  late FakeSettingsRepository settings;

  final now = DateTime(2026, 11, 7, 18, 30);

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
    documents = FakeDocumentFiles();
    backups = FakeBackupService();
    settings = FakeSettingsRepository();
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      documents: documents,
      backups: backups,
      settings: settings,
      clock: () => now,
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('Yedek al')),
    );
    documents.readGate = () => container.read(externalActivityGateProvider);
  }

  testWidgets('hiç yedek yoksa söyleniyor', (tester) async {
    await pumpSettings(tester);
    expect(find.text('Henüz yedek alınmadı.'), findsOneWidget);
  });

  testWidgets('yedek kaydediliyor ve zamanı yazılıyor', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Yedek al'));
    await tester.pumpAndSettle();

    expect(backups.creates, 1);
    expect(documents.saves, 1);
    expect(documents.savedName, 'keykey-yedek-2026-11-07.keykey');
    expect(documents.savedBytes, [1, 2, 3]);
    // Seçici açıkken arka plana geçmek kasayı kilitlememeli.
    expect(documents.gateWasActive, isTrue);
    expect(settings.settings.lastBackupAt, now);
    expect(find.text('Yedek kaydedildi.'), findsOneWidget);
    expect(find.textContaining('Son yedek: '), findsOneWidget);
  });

  testWidgets('vazgeçilirse hiçbir şey değişmiyor', (tester) async {
    documents.nextSave = DocumentSaveResult.cancelled;
    await pumpSettings(tester);

    await tester.tap(find.text('Yedek al'));
    await tester.pumpAndSettle();

    expect(documents.saves, 1);
    expect(settings.settings.lastBackupAt, isNull);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('yazılamazsa hata gösteriliyor, zaman yazılmıyor', (
    tester,
  ) async {
    documents.nextSave = DocumentSaveResult.failed;
    await pumpSettings(tester);

    await tester.tap(find.text('Yedek al'));
    await tester.pumpAndSettle();

    expect(settings.settings.lastBackupAt, isNull);
    expect(
      find.text('Yedek kaydedilemedi. Başka bir konum dene.'),
      findsOneWidget,
    );
  });

  testWidgets('son yedeğin zamanı gösteriliyor', (tester) async {
    settings = FakeSettingsRepository(
      AppSettings.defaults.copyWith(lastBackupAt: DateTime(2026, 11, 1, 9)),
    );
    await pumpSettings(tester);
    expect(find.textContaining('Son yedek: '), findsOneWidget);
    expect(find.textContaining('2026'), findsWidgets);
  });
}

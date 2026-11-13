import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/ui/kk_done_mark.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/features/backup/presentation/backup_status_card.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

/// Ayarları testin istediği an veren depo: "ayarlar yükleniyor" anı.
class _GatedSettingsRepository extends FakeSettingsRepository {
  new(super.settings);

  final gate = Completer<void>();

  @override
  Future<AppSettings> load() async {
    await gate.future;
    return settings;
  }
}

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
      tester.element(find.text('Yedekle')),
    );
    documents.readGate = () => container.read(externalActivityGateProvider);
  }

  testWidgets('hiç yedek yoksa söyleniyor', (tester) async {
    await pumpSettings(tester);
    expect(find.text('Henüz yedek yok'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
  });

  testWidgets('kart en üstte, grupta "Yedek al" satırı yok', (tester) async {
    await pumpSettings(tester);
    final card = tester.getRect(find.byType(BackupStatusCard));
    expect(card.top, lessThan(tester.getRect(find.text('Güvenlik')).top));
    expect(find.text('Yedek al'), findsNothing);
    for (final row in [
      'Yedekten geri yükle',
      'Parolaları içe aktar',
      '2FA hesaplarını içe aktar',
      'Şifresiz dışa aktar',
    ]) {
      final finder = find.text(row);
      await tester.scrollUntilVisible(finder, 200);
      expect(finder, findsOneWidget, reason: row);
    }
  });

  testWidgets('(i) yedeğin açıklamasını pencerede açıyor', (tester) async {
    await pumpSettings(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(BackupStatusCard),
        matching: find.byTooltip('Açıklama'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Yedek dosyası şifrelidir'), findsOneWidget);
  });

  /// Ayarlara girişten sonraki 1,5 sn içinde kartın en büyük ölçeği.
  Future<double> maxPulse(WidgetTester tester) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      settings: settings,
      clock: () => now,
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    var most = 1.0;
    for (var i = 0; i < 75; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      final pulse = find.descendant(
        of: find.byKey(BackupStatusCard.pulseKey),
        matching: find.byType(Transform),
      );
      if (pulse.evaluate().isEmpty) continue;
      final scale = tester.widget<Transform>(pulse.first).transform.storage[0];
      if (scale > most) most = scale;
    }
    await tester.pumpAndSettle();
    return most;
  }

  testWidgets('yedek hiç yoksa ayarlara girişte kart bir kez hafifçe atar', (
    tester,
  ) async {
    final most = await maxPulse(tester);
    expect(most, greaterThan(1.02));
    expect(most, lessThanOrEqualTo(BackupStatusCard.pulseScale + 0.001));
  });

  testWidgets('yeni yedekte kart atmaz', (tester) async {
    settings = FakeSettingsRepository(
      AppSettings.defaults.copyWith(lastBackupAt: DateTime(2026, 11, 7, 9)),
    );
    expect(await maxPulse(tester), 1);
  });

  testWidgets('yedek bitince düğmede onay işareti çizilir, sonra yazı döner', (
    tester,
  ) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Yedekle'));
    var sawDone = false;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(KkDoneMark).evaluate().isNotEmpty) sawDone = true;
    }
    await tester.pumpAndSettle();
    expect(sawDone, isTrue);
    expect(find.byType(KkDoneMark), findsNothing);
    expect(find.text('Yedekle'), findsOneWidget);
  });

  /// Ayarlar yüklenmeden ayarlara girilir, sonra ayarlar gelir; kartın en
  /// büyük ölçeği.
  Future<double> maxPulseLoadingLate(
    WidgetTester tester,
    AppSettings stored,
  ) async {
    final gated = _GatedSettingsRepository(stored);
    settings = gated;
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      settings: settings,
      clock: () => now,
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.settings_outlined));
    var most = 1.0;
    for (var i = 0; i < 100; i++) {
      if (i == 10) gated.gate.complete();
      await tester.pump(const Duration(milliseconds: 20));
      final pulse = find.descendant(
        of: find.byKey(BackupStatusCard.pulseKey),
        matching: find.byType(Transform),
      );
      if (pulse.evaluate().isEmpty) continue;
      final scale = tester.widget<Transform>(pulse.first).transform.storage[0];
      if (scale > most) most = scale;
    }
    await tester.pumpAndSettle();
    return most;
  }

  testWidgets('ayarlar geç yüklenirse yeni yedekte kart boşuna atmaz', (
    tester,
  ) async {
    final most = await maxPulseLoadingLate(
      tester,
      AppSettings.defaults.copyWith(lastBackupAt: DateTime(2026, 11, 7, 9)),
    );
    expect(most, 1);
  });

  testWidgets('ayarlar geç yüklenince hiç yedek yoksa kart yine atar', (
    tester,
  ) async {
    final most = await maxPulseLoadingLate(tester, AppSettings.defaults);
    expect(most, greaterThan(1.02));
  });

  testWidgets('yedek kaydediliyor ve zamanı yazılıyor', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Yedekle'));
    await tester.pumpAndSettle();

    expect(backups.creates, 1);
    expect(documents.saves, 1);
    expect(documents.savedName, 'keykey-yedek-2026-11-07.keykey');
    expect(documents.savedBytes, [1, 2, 3]);
    // Seçici açıkken arka plana geçmek kasayı kilitlememeli.
    expect(documents.gateWasActive, isTrue);
    expect(settings.settings.lastBackupAt, now);
    expect(find.text('Yedek kaydedildi.'), findsOneWidget);
    expect(find.text('Son yedek bugün'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
  });

  testWidgets('vazgeçilirse hiçbir şey değişmiyor', (tester) async {
    documents.nextSave = DocumentSaveResult.cancelled;
    await pumpSettings(tester);

    await tester.tap(find.text('Yedekle'));
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

    await tester.tap(find.text('Yedekle'));
    await tester.pumpAndSettle();

    expect(settings.settings.lastBackupAt, isNull);
    expect(
      find.text('Yedek kaydedilemedi. Başka bir konum dene.'),
      findsOneWidget,
    );
  });

  testWidgets('12 gün önceki yedek gün olarak yazılıyor', (tester) async {
    settings = FakeSettingsRepository(
      AppSettings.defaults.copyWith(lastBackupAt: DateTime(2026, 10, 26, 23)),
    );
    await pumpSettings(tester);
    expect(find.text('Son yedek 12 gün önce'), findsOneWidget);
  });

  testWidgets('bugünkü yedek "bugün" diye yazılıyor', (tester) async {
    settings = FakeSettingsRepository(
      AppSettings.defaults.copyWith(lastBackupAt: DateTime(2026, 11, 7, 0, 5)),
    );
    await pumpSettings(tester);
    expect(find.text('Son yedek bugün'), findsOneWidget);
  });
}

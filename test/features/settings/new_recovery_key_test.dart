import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeDocumentFiles documents;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
    documents = FakeDocumentFiles();
  });

  final title = find.text('Yeni kurtarma anahtarı');
  final continueButton = find.widgetWithText(FilledButton, 'Devam');
  final saveButton = find.widgetWithText(FilledButton, 'Doğrula ve kaydet');

  Future<void> open(
    WidgetTester tester, {
    FakeSettingsRepository? settings,
    FakeBackupFolders? folders,
  }) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      documents: documents,
      settings: settings,
      folders: folders,
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(title, 100);
    await tester.tap(title);
    await tester.pumpAndSettle();
  }

  Future<void> enterPassword(WidgetTester tester, String password) async {
    await tester.enterText(find.byType(TextField), password);
    await tester.pump();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
  }

  Future<void> typeKey(WidgetTester tester, String key) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydettim'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), key);
    await tester.pump();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
  }

  testWidgets('yanlış parola anahtarı göstermiyor', (tester) async {
    await open(tester);
    expect(
      find.textContaining('eski kurtarma anahtarın bu kasayı artık açmaz'),
      findsOneWidget,
    );

    await enterPassword(tester, 'yanlis-parola-99');

    expect(find.text('Parola yanlış.'), findsOneWidget);
    expect(find.text(FakeVaultService.newRecoveryKey), findsNothing);
  });

  testWidgets(
    'doğru parola yeni anahtarı gösteriyor, doğrulayınca kaydediyor',
    (tester) async {
      await open(tester);
      await enterPassword(tester, FakeVaultService.correctPassword);
      expect(find.text(FakeVaultService.newRecoveryKey), findsOneWidget);
      expect(service.confirmedRecoveryKey, isNull);

      await typeKey(tester, FakeVaultService.newRecoveryKey);

      expect(service.confirmedRecoveryKey, FakeVaultService.newRecoveryKey);
      expect(find.text('Yeni kurtarma anahtarı kaydedildi'), findsOneWidget);
      await tester.tap(find.text('Sonra'));
      await tester.pumpAndSettle();
      expect(find.text('Ana parolayı değiştir'), findsOneWidget);
    },
  );

  testWidgets('yanlış yazılan anahtar kaydedilmiyor, grup söyleniyor', (
    tester,
  ) async {
    await open(tester);
    await enterPassword(tester, FakeVaultService.correctPassword);

    await typeKey(tester, FakeVaultService.recoveryKey);

    expect(service.confirmedRecoveryKey, isNull);
    expect(find.textContaining('1. grupta yazım hatası var'), findsOneWidget);
  });

  testWidgets('anahtar gösterildikten sonra çıkılırsa hiçbir şey değişmiyor', (
    tester,
  ) async {
    await open(tester);
    await enterPassword(tester, FakeVaultService.correctPassword);

    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();

    expect(service.confirmedRecoveryKey, isNull);
    expect(find.text('Ana parolayı değiştir'), findsOneWidget);
  });

  testWidgets('dosyaya kaydederken arka plan kilidi beklemede', (tester) async {
    await open(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TextField)),
    );
    documents.readGate = () => container.read(externalActivityGateProvider);
    await enterPassword(tester, FakeVaultService.correctPassword);

    await tester.tap(find.text('Dosyaya kaydet'));
    await tester.pumpAndSettle();

    expect(documents.saves, 1);
    expect(documents.gateWasActive, isTrue);
  });

  testWidgets('otomatik yedek açıksa yeni üst bilgiyle hemen yazılıyor', (
    tester,
  ) async {
    const folder = AutoBackupFolder(uri: 'content://x/tree/K', name: 'K');
    final folders = FakeBackupFolders()..granted.add(folder.uri);
    await open(
      tester,
      folders: folders,
      settings: FakeSettingsRepository(
        AppSettings.defaults.withAutoBackupFolder(folder),
      ),
    );
    await enterPassword(tester, FakeVaultService.correctPassword);

    await typeKey(tester, FakeVaultService.newRecoveryKey);

    expect(folders.files[folder.uri], hasLength(1));
  });
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeDocumentFiles documents;
  late FakeRestoreService restores;
  late Uint8List backup;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() async {
    service = FakeVaultService(sodium);
    documents = FakeDocumentFiles();
    restores = FakeRestoreService(sodium);
    backup = await restores.backupBytes(service.header);
    documents.nextOpen = DocumentOpened(Uint8List.fromList(backup));
  });

  Future<void> pump(WidgetTester tester, VaultStatus status) => pumpKeyKey(
    tester,
    status: status,
    service: service,
    documents: documents,
    restores: restores,
  );

  Future<void> typeSecret(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Yedeği aç'));
    await tester.pumpAndSettle();
  }

  group('yeni telefonda', () {
    Future<void> openFromSetup(WidgetTester tester) async {
      await pump(tester, const VaultNotSetUp());
      // Düğme kurulum ekranının altında; ekrana kaydırılır.
      await tester.ensureVisible(find.text('Yedekten geri yükle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yedekten geri yükle'));
      await tester.pumpAndSettle();
    }

    testWidgets('kurulum ekranında seçenek var', (tester) async {
      await pump(tester, const VaultNotSetUp());
      expect(find.text('Yedekten geri yükle'), findsOneWidget);
    });

    testWidgets('yedek olmayan dosya söyleniyor', (tester) async {
      documents.nextOpen = DocumentOpened(Uint8List.fromList([1, 2, 3]));
      await openFromSetup(tester);
      expect(
        find.text('Bu dosya bir KeyKey yedeği değil ya da bozuk.'),
        findsOneWidget,
      );
      expect(find.text('Yedeği aç'), findsNothing);
    });

    testWidgets('çok büyük dosya söyleniyor', (tester) async {
      documents.nextOpen = const DocumentTooLarge();
      await openFromSetup(tester);
      expect(
        find.text('Bu dosya bir KeyKey yedeği olamayacak kadar büyük.'),
        findsOneWidget,
      );
    });

    testWidgets('yanlış parola söyleniyor, doğrusu özeti gösteriyor', (
      tester,
    ) async {
      await openFromSetup(tester);
      expect(
        find.text(
          'Yedek, onu aldığın andaki ana parolanla ya da kurtarma '
          'anahtarınla açılır.',
        ),
        findsOneWidget,
      );

      await typeSecret(tester, 'yanlis-Parola-99');
      expect(
        find.text(
          'Bu parola yedeği açmadı. Yedeği aldığın andaki ana parolayı dene.',
        ),
        findsOneWidget,
      );

      await typeSecret(tester, FakeRestoreService.password);
      expect(find.textContaining('3 parola ve 2 2FA hesabı'), findsOneWidget);
      expect(find.text('Kasamla birleştir'), findsNothing);
    });

    testWidgets('geri yükleyince kasa açılıyor', (tester) async {
      await openFromSetup(tester);
      await typeSecret(tester, FakeRestoreService.password);

      await tester.tap(find.widgetWithText(FilledButton, 'Geri yükle'));
      await tester.pumpAndSettle();

      expect(restores.replaces, 1);
      expect(find.text('Yedek geri yüklendi.'), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('kurtarma anahtarıyla da açılıyor', (tester) async {
      await openFromSetup(tester);
      await tester.tap(find.text('Kurtarma anahtarıyla aç'));
      await tester.pumpAndSettle();

      await typeSecret(tester, 'AAAAA-BBBBB-CCCCC');
      expect(
        find.text('Bu kurtarma anahtarı bu yedekteki kasaya ait değil.'),
        findsOneWidget,
      );

      await typeSecret(tester, FakeVaultService.recoveryKey);
      expect(find.textContaining('3 parola ve 2 2FA hesabı'), findsOneWidget);
    });

    testWidgets('bozuk yedek söyleniyor', (tester) async {
      restores.corrupted = true;
      await openFromSetup(tester);
      await typeSecret(tester, FakeRestoreService.password);
      expect(
        find.text(
          'Yedek bozuk ya da değiştirilmiş. Hiçbir şey geri yüklenmedi.',
        ),
        findsOneWidget,
      );
      expect(restores.replaces, 0);
    });
  });

  group('açık kasada', () {
    Future<void> openFromSettings(WidgetTester tester) async {
      await pump(tester, VaultOpen(service.newSession()));
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.text('Yedekten geri yükle')),
      );
      documents.readGate = () => container.read(externalActivityGateProvider);
      await tester.tap(find.text('Yedekten geri yükle'));
      await tester.pumpAndSettle();
      await typeSecret(tester, FakeRestoreService.password);
    }

    testWidgets('seçici açıkken kasa kilitlenmiyor', (tester) async {
      await openFromSettings(tester);
      expect(documents.gateWasActive, isTrue);
    });

    testWidgets('birleştirme sayıları söylüyor ve geri dönüyor', (
      tester,
    ) async {
      await openFromSettings(tester);
      expect(find.text('Geri yükle'), findsNothing);

      await tester.tap(find.text('Kasamla birleştir'));
      await tester.pumpAndSettle();

      expect(restores.merges, 1);
      expect(
        find.text('2 kayıt eklendi, 1 kayıt güncellendi.'),
        findsOneWidget,
      );
      expect(find.text('Yedekle'), findsOneWidget);
    });

    testWidgets('değiştirme onay istiyor, vazgeçilirse bir şey olmuyor', (
      tester,
    ) async {
      await openFromSettings(tester);
      await tester.tap(find.text('Kasamı yedekle değiştir'));
      await tester.pumpAndSettle();
      expect(find.text('Kasan değiştirilsin mi?'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);

      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(restores.replaces, 0);
      expect(find.text('Kasamla birleştir'), findsOneWidget);
    });

    testWidgets('değiştirince parmak izi kapanıyor ve kasa kilitleniyor', (
      tester,
    ) async {
      service.biometricEnabled = true;
      await openFromSettings(tester);
      await tester.tap(find.text('Kasamı yedekle değiştir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Değiştir'));
      await tester.pumpAndSettle();

      expect(restores.replaces, 1);
      expect(service.biometricEnabled, isFalse);
      expect(find.text('KeyKey kilitli'), findsOneWidget);
    });
  });
}

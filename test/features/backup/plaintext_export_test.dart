import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/features/backup/presentation/plaintext_export.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeDocumentFiles documents;
  late FakeLoginRepository logins;

  final now = DateTime(2026, 11, 7, 18, 30);

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
    documents = FakeDocumentFiles();
    logins = FakeLoginRepository(
      items: [
        FakeLoginRepository.item(
          const LoginContent(
            name: 'Forum',
            username: 'ali',
            password: 'deneme-Forum-3',
            urls: ['https://forum.example.com'],
          ),
        ),
      ],
    );
  });

  Future<void> openExport(WidgetTester tester) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      logins: logins,
      documents: documents,
      clock: () => now,
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('Yedek al')),
    );
    documents.readGate = () => container.read(externalActivityGateProvider);
    final tile = find.text('Şifresiz dışa aktar');
    await tester.scrollUntilVisible(tile, 200);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  Future<void> enterPassword(WidgetTester tester, String password) async {
    await tester.enterText(find.byType(TextField).last, password);
    await tester.tap(find.text('Doğrula'));
    await tester.pumpAndSettle();
  }

  testWidgets('uyarı, parola ve kayıt', (tester) async {
    await openExport(tester);
    expect(find.text('Bu dosya şifresiz'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.tap(find.text('Devam et'));
    await tester.pumpAndSettle();
    // Parola penceresi dışa aktarma başlığıyla açılıyor.
    expect(find.widgetWithText(BottomSheet, 'Şifresiz dışa aktar'), findsOne);
    expect(documents.saves, 0);

    await enterPassword(tester, FakeVaultService.correctPassword);

    expect(documents.saves, 1);
    expect(documents.gateWasActive, isTrue);
    expect(documents.savedName, 'keykey-disa-aktarma-2026-11-07.csv');
    final csv = utf8.decode(documents.savedBytes!);
    expect(csv, startsWith('folder,favorite,type,name,'));
    expect(
      csv,
      contains(
        ',,login,Forum,,,0,https://forum.example.com,ali,deneme-Forum-3,\r\n',
      ),
    );
    expect(
      find.text('Dışa aktarma kaydedildi. İçe aktardıktan sonra dosyayı sil.'),
      findsOneWidget,
    );
  });

  testWidgets('uyarıda vazgeçince hiçbir şey yazılmıyor', (tester) async {
    await openExport(tester);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.text('Bu dosya şifresiz'), findsNothing);
    expect(find.text('Doğrula'), findsNothing);
    expect(documents.saves, 0);
  });

  testWidgets('yanlış parolayla dosya yazılmıyor', (tester) async {
    await openExport(tester);
    await tester.tap(find.text('Devam et'));
    await tester.pumpAndSettle();
    await enterPassword(tester, 'yanlis-parola');
    expect(find.text('Parola yanlış.'), findsOneWidget);
    expect(documents.saves, 0);
  });

  testWidgets('kaydedilemezse söyleniyor', (tester) async {
    documents.nextSave = DocumentSaveResult.failed;
    await openExport(tester);
    await tester.tap(find.text('Devam et'));
    await tester.pumpAndSettle();
    await enterPassword(tester, FakeVaultService.correctPassword);
    expect(find.text('Dosya kaydedilemedi.'), findsOneWidget);
  });

  test('dosya adı yerel tarihle', () {
    expect(
      plaintextExportFileName(DateTime(2026, 1, 5, 23)),
      'keykey-disa-aktarma-2026-01-05.csv',
    );
  });
}

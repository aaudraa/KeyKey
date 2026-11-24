import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/features/backup/presentation/plaintext_export.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_passkey.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';
import '../../support/passkey_test_keys.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeDocumentFiles documents;
  late FakeLoginRepository logins;
  late FakeRecordRepository<CardContent> cards;

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
    cards = FakeRecordRepository<CardContent>();
  });

  /// Ayarlardan dışa aktarmayı başlatır; biçim penceresi açık kalır.
  Future<void> openFormats(WidgetTester tester) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      logins: logins,
      cards: cards,
      documents: documents,
      clock: () => now,
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('Yedekle')),
    );
    documents.readGate = () => container.read(externalActivityGateProvider);
    final tile = find.text('Şifresiz dışa aktar');
    await tester.scrollUntilVisible(tile, 200);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  Future<void> openExport(WidgetTester tester, {String format = 'CSV'}) async {
    await openFormats(tester);
    await tester.tap(find.text(format));
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
    expect(documents.savedMimeType, 'text/csv');
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

  testWidgets('biçim penceresi açılır, kartsız kasada uyarı yok, vazgeçilir', (
    tester,
  ) async {
    await openFormats(tester);
    expect(find.text('Biçim seç'), findsOneWidget);
    expect(find.text('Kartlar bu biçimde yazılmaz.'), findsNothing);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.text('Bu dosya şifresiz'), findsNothing);
    expect(documents.saves, 0);
  });

  testWidgets('kartlı kasada CSV uyarısı görünür', (tester) async {
    cards.items.add(
      FakeRecordRepository.item(
        CardContent(name: 'Maaş', number: '4111111111111111'),
      ),
    );
    await openFormats(tester);
    expect(find.text('Kartlar bu biçimde yazılmaz.'), findsOneWidget);
  });

  testWidgets('JSON seçilince .json dosyası kaydedilir, kart içinde', (
    tester,
  ) async {
    cards.items.add(
      FakeRecordRepository.item(
        CardContent(name: 'Maaş', number: '4111111111111111'),
      ),
    );
    await openExport(tester, format: 'JSON');
    await tester.tap(find.text('Devam et'));
    await tester.pumpAndSettle();
    await enterPassword(tester, FakeVaultService.correctPassword);

    expect(documents.savedName, 'keykey-disa-aktarma-2026-11-07.json');
    expect(documents.savedMimeType, 'application/json');
    final json = utf8.decode(documents.savedBytes!);
    expect(json, startsWith('{'));
    expect(json, contains('4111111111111111'));
    expect(json, contains('deneme-Forum-3'));
  });

  group("passkey'ler", () {
    const note = "Passkey'ler bu dosyaya yazılmaz.";

    testWidgets('passkey yoksa uyarıda not yok', (tester) async {
      await openExport(tester);
      expect(find.textContaining(note), findsNothing);
    });

    testWidgets('passkey varsa uyarı söylüyor, dosyaya yazılmıyor', (
      tester,
    ) async {
      final key = base64UrlDecodeNoPad(p256Pkcs8B64Url);
      logins.items[0] = FakeLoginRepository.item(
        logins.items[0].content.copyWith(
          passkeys: [
            LoginPasskey(
              credentialId: Uint8List.fromList([1, 2, 3]),
              rpId: 'forum.example.com',
              userHandle: Uint8List.fromList([9]),
              userName: 'ali',
              userDisplayName: '',
              privateKey: key,
              createdAt: DateTime.utc(2026),
            ),
          ],
        ),
      );
      await openExport(tester, format: 'JSON');
      expect(find.textContaining(note), findsOneWidget);

      await tester.tap(find.text('Devam et'));
      await tester.pumpAndSettle();
      await enterPassword(tester, FakeVaultService.correctPassword);

      final json = utf8.decode(documents.savedBytes!);
      expect(json, contains('deneme-Forum-3'));
      expect(json, isNot(contains(base64.encode(key).substring(0, 40))));
      expect(json, isNot(contains(p256Pkcs8B64Url.substring(0, 40))));
      expect(json, isNot(contains('fido2')));
    });
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
    expect(
      plaintextExportFileName(
        DateTime(2026, 1, 5, 23),
        prefix: 'keykey-export',
      ),
      'keykey-export-2026-01-05.csv',
    );
    expect(
      plaintextExportFileName(DateTime(2026, 1, 5), extension: 'json'),
      'keykey-disa-aktarma-2026-01-05.json',
    );
  });
}

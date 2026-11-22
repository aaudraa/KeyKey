import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';
import '../../support/kdbx_fixtures.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeDocumentFiles documents;
  late FakeLoginRepository logins;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
    documents = FakeDocumentFiles();
    logins = FakeLoginRepository();
  });

  /// Ayarlar → İçe aktar; seçicinin vereceği dosya önceden kurulur.
  Future<void> pickFile(WidgetTester tester) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      logins: logins,
      otps: FakeOtpRepository(),
      cards: FakeRecordRepository<CardContent>(),
      notes: FakeRecordRepository<NoteContent>(),
      documents: documents,
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('Yedekle')),
    );
    documents.readGate = () => container.read(externalActivityGateProvider);
    final tile = find.text('İçe aktar');
    await tester.scrollUntilVisible(tile, 200);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  /// Açma ayrı bir isolate'te sürdüğü için gerçek zamanla beklenir.
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(finder, findsOneWidget);
  }

  Future<void> enterPassword(WidgetTester tester, String password) async {
    await tester.enterText(find.byType(TextField).first, password);
    await tester.pump();
  }

  testWidgets('parolayla açılır, önizleme gelir', (tester) async {
    documents.nextOpen = DocumentOpened(
      kdbxFixture('keepassxc/ProtectedStrings.kdbx'),
    );
    await pickFile(tester);
    expect(documents.lastMaxBytes, 64 * 1024 * 1024);
    expect(find.text('KeePass dosyasını aç'), findsOneWidget);

    await enterPassword(tester, 'masterpw');
    await tester.tap(find.text('Aç'));
    await tester.pump();
    await waitFor(
      tester,
      find.text('KeePass (KDBX) dosyasından 1 kayıt okundu.'),
    );
    expect(find.text('Sample Entry'), findsOneWidget);
  });

  testWidgets('yanlış parolada ekranda kalınır', (tester) async {
    documents.nextOpen = DocumentOpened(
      kdbxFixture('keepassxc/ProtectedStrings.kdbx'),
    );
    await pickFile(tester);
    await enterPassword(tester, 'yanlış');
    await tester.tap(find.text('Aç'));
    await tester.pump();
    await waitFor(
      tester,
      find.textContaining('Parola ya da anahtar dosyası yanlış.'),
    );
    expect(find.text('KeePass dosyasını aç'), findsOneWidget);
  });

  testWidgets('anahtar dosyası seçilir, kaldırılır ve yalnız onunla açılır', (
    tester,
  ) async {
    final keyFile = kdbxFixture('keepassxc/FileKeyXmlV2.keyx');
    documents.queuedOpens.addAll([
      DocumentOpened(kdbxFixture('keepassxc/FileKeyXmlV2.kdbx')),
      DocumentOpened(keyFile),
      DocumentOpened(
        Uint8List.fromList(kdbxFixture('keepassxc/FileKeyXmlV2.keyx')),
      ),
    ]);
    await pickFile(tester);

    await tester.tap(find.text('Anahtar dosyası seç'));
    await tester.pumpAndSettle();
    expect(find.text('Anahtar dosyası seçildi'), findsOneWidget);
    // Anahtar dosyasının baytları özeti alınınca sıfırlandı.
    expect(keyFile.every((b) => b == 0), isTrue);

    await tester.tap(find.byTooltip('Anahtar dosyasını kaldır'));
    await tester.pumpAndSettle();
    expect(find.text('Anahtar dosyası seç'), findsOneWidget);

    await tester.tap(find.text('Anahtar dosyası seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aç'));
    await tester.pump();
    await waitFor(tester, find.textContaining('KeePass (KDBX) dosyasından'));
  });

  testWidgets('bozuk anahtar dosyası söylenir', (tester) async {
    documents.queuedOpens.addAll([
      DocumentOpened(kdbxFixture('keepassxc/FileKeyXmlV2HashFail.kdbx')),
      DocumentOpened(kdbxFixture('keepassxc/FileKeyXmlV2HashFail.keyx')),
    ]);
    await pickFile(tester);
    await tester.tap(find.text('Anahtar dosyası seç'));
    await tester.pumpAndSettle();
    expect(find.text('Anahtar dosyası bozuk.'), findsOneWidget);
    expect(find.text('Anahtar dosyası seçildi'), findsNothing);
  });

  testWidgets('ekrandan çıkınca dosyanın baytları sıfırlanır', (tester) async {
    final file = kdbxFixture('keepassxc/ProtectedStrings.kdbx');
    documents.nextOpen = DocumentOpened(file);
    await pickFile(tester);
    expect(file.any((b) => b != 0), isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(file.every((b) => b == 0), isTrue);
  });

  testWidgets('çöp kutusu ve ek bilgisi; silme hatırlatması yok', (
    tester,
  ) async {
    documents.nextOpen = DocumentOpened(
      kdbxFixture('keepassxc/RecycleBinWithData.kdbx'),
    );
    await pickFile(tester);
    await enterPassword(tester, '123');
    await tester.tap(find.text('Aç'));
    await tester.pump();
    await waitFor(tester, find.text('Çöp kutusundaki 6 kayıt alınmadı.'));

    await tester.tap(find.text('5 kaydı ekle'));
    await tester.pumpAndSettle();
    expect(logins.items, hasLength(5));
    // Dosya şifreli; düz metin dosyasını silme hatırlatması gösterilmez.
    expect(find.text('Kaynak dosyayı sil'), findsNothing);
  });

  testWidgets('KeePass 1 dosyası eski biçim mesajı verir', (tester) async {
    final kdb = Uint8List.fromList([
      0x03, 0xD9, 0xA2, 0x9A, 0x65, 0xFB, 0x4B, 0xB5, //
      ...List.filled(100, 0),
    ]);
    documents.nextOpen = DocumentOpened(kdb);
    await pickFile(tester);
    expect(find.textContaining('eski bir KeePass biçimi'), findsOneWidget);
    expect(find.text('KeePass dosyasını aç'), findsNothing);
    expect(kdb.every((b) => b == 0), isTrue);
  });

  testWidgets('10 MiB üstü CSV hâlâ çok büyük sayılır', (tester) async {
    final big = Uint8List(10 * 1024 * 1024 + 1)..fillRange(0, 10, 0x61);
    documents.nextOpen = DocumentOpened(big);
    await pickFile(tester);
    expect(find.text('Dosya çok büyük.'), findsOneWidget);
    expect(big.every((b) => b == 0), isTrue);
  });
}

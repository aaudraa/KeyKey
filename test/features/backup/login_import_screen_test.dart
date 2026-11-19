import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeDocumentFiles documents;
  late FakeLoginRepository logins;
  late FakeOtpRepository otps;
  late FakeRecordRepository<CardContent> cards;
  late FakeRecordRepository<NoteContent> notes;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
    documents = FakeDocumentFiles();
    logins = FakeLoginRepository();
    otps = FakeOtpRepository();
    cards = FakeRecordRepository<CardContent>();
    notes = FakeRecordRepository<NoteContent>();
  });

  Uint8List fixture(String name) =>
      File('test/fixtures/import/logins/$name').readAsBytesSync();

  Future<void> openImport(WidgetTester tester) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      logins: logins,
      otps: otps,
      cards: cards,
      notes: notes,
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

  testWidgets('kayıtlar seçilip ekleniyor, 2FA bağlanıyor', (tester) async {
    final bytes = fixture('bitwarden.json');
    documents.nextOpen = DocumentOpened(bytes);
    await openImport(tester);

    expect(documents.gateWasActive, isTrue);
    // Okunan dosya bellekte bırakılmadı.
    expect(bytes.every((byte) => byte == 0), isTrue);
    expect(
      find.text('Bitwarden (JSON) dosyasından 4 kayıt okundu.'),
      findsOneWidget,
    );
    expect(
      find.text('1 satır desteklenmediği ya da bozuk olduğu için atlandı.'),
      findsOneWidget,
    );
    expect(find.text('Şirket'), findsOneWidget);
    expect(find.text('veli · sirket.example.com · 2FA ile'), findsOneWidget);
    expect(logins.items, isEmpty);

    await tester.tap(find.text('4 kaydı ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Kaynak dosyayı sil'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.textContaining('KeyKey bu dosyayı silemez'), findsOneWidget);
    expect(find.text('4 kayıt eklendi.'), findsOneWidget);
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(find.text('İçe aktar'), findsOneWidget);
    expect(cards.items.single.content.number, '4111111111111111');
    expect(notes.items.single.content.name, 'Not');

    expect(logins.items.map((item) => item.content.name), ['Şirket', 'Basit']);
    final company = logins.items.first;
    expect(company.content.folder, 'İş');
    final otp = otps.items.single;
    expect(otp.content.issuer, 'Sirket');
    expect(otp.content.parameters.digits, 8);
    expect(listEquals(otp.content.loginId, company.id), isTrue);
  });

  testWidgets('kasada olan kayıt seçilmemiş geliyor', (tester) async {
    logins.items.add(
      FakeLoginRepository.item(
        const LoginContent(
          name: 'Eski',
          username: 'veli',
          password: 'deneme-Sirket-5',
          urls: ['https://sirket.example.com/'],
        ),
      ),
    );
    documents.nextOpen = DocumentOpened(fixture('bitwarden.json'));
    await openImport(tester);

    expect(find.text('Kasanda zaten olan kayıtlar seçilmedi.'), findsOneWidget);
    expect(
      find.text('veli · sirket.example.com · 2FA ile · Kasanda var'),
      findsOneWidget,
    );
    await tester.tap(find.text('3 kaydı ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();

    expect(logins.items.map((item) => item.content.name), ['Eski', 'Basit']);
    expect(otps.items, isEmpty);
  });

  testWidgets('kart ve not kendi simgeleriyle listede', (tester) async {
    documents.nextOpen = DocumentOpened(fixture('bitwarden.json'));
    await openImport(tester);

    final cardTile = find.ancestor(
      of: find.text('Kart'),
      matching: find.byType(CheckboxListTile),
    );
    expect(
      find.descendant(
        of: cardTile,
        matching: find.byIcon(Icons.credit_card_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: cardTile,
        matching: find.text('Visa •••• 1111 · 01/28'),
      ),
      findsOneWidget,
    );
    final noteTile = find.ancestor(
      of: find.text('Not'),
      matching: find.byType(CheckboxListTile),
    );
    expect(
      find.descendant(
        of: noteTile,
        matching: find.byIcon(Icons.sticky_note_2_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('nota taşınan değer söyleniyor, kasadaki kart seçilmiyor', (
    tester,
  ) async {
    cards.items.add(
      FakeRecordRepository.item(
        CardContent(name: 'Kart', number: '4111111111111111'),
      ),
    );
    documents.nextOpen = DocumentOpened(
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'encrypted': false,
            'items': [
              {
                'type': 3,
                'name': 'Kart',
                'card': {'number': '4111111111111111'},
              },
              {
                'type': 3,
                'name': 'Bozuk',
                'card': {'number': 'abc'},
              },
            ],
          }),
        ),
      ),
    );
    await openImport(tester);

    expect(find.text('Visa •••• 1111 · Kasanda var'), findsOneWidget);
    expect(find.text('Bazı değerler kartın notuna taşındı'), findsOneWidget);
    await tester.tap(find.text('1 kaydı ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();

    expect(cards.items.map((item) => item.content.name), ['Kart', 'Bozuk']);
    expect(cards.items.last.content.notes, 'Kart numarası: abc');
  });

  testWidgets('seçim kaldırılınca düğme kapanıyor', (tester) async {
    documents.nextOpen = DocumentOpened(fixture('chrome_simple.csv'));
    await openImport(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Ekle'),
    );
    expect(button.onPressed, isNull);
  });

  group('okunamayan dosya söyleniyor', () {
    Future<void> expectMessage(
      WidgetTester tester,
      DocumentOpenResult result,
      String message,
    ) async {
      documents.nextOpen = result;
      await openImport(tester);
      expect(find.text(message), findsOneWidget);
      expect(find.text('Kaynak dosyayı sil'), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
    }

    testWidgets('şifreli Bitwarden', (tester) async {
      await expectMessage(
        tester,
        DocumentOpened(fixture('bitwarden_password_protected.json')),
        'Bu Bitwarden dosyası parolayla şifrelenmiş ve KeyKey onu açamıyor. '
        "Bitwarden'dan şifresiz bir .json ya da .csv dışa aktarması al.",
      );
    });

    testWidgets('tanınmayan', (tester) async {
      await expectMessage(
        tester,
        DocumentOpened(Uint8List.fromList([1, 2, 3])),
        'Bu dosya tanınmadı. Bitwarden (JSON veya CSV), Chrome (CSV), '
        'Firefox (CSV) ya da KeePassXC (CSV) dışa aktarması seç.',
      );
    });

    testWidgets('çok büyük', (tester) async {
      await expectMessage(tester, const DocumentTooLarge(), 'Dosya çok büyük.');
    });
  });
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/platform/document_files.dart';
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
  late FakeOtpRepository otps;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
    documents = FakeDocumentFiles();
    logins = FakeLoginRepository();
    otps = FakeOtpRepository();
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
      documents: documents,
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('Yedekle')),
    );
    documents.readGate = () => container.read(externalActivityGateProvider);
    final tile = find.text('Parolaları içe aktar');
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
      find.text('Bitwarden (JSON) dosyasından 2 kayıt okundu.'),
      findsOneWidget,
    );
    expect(
      find.text('2 satır desteklenmediği ya da bozuk olduğu için atlandı.'),
      findsOneWidget,
    );
    expect(find.text('Şirket'), findsOneWidget);
    expect(find.text('veli · sirket.example.com · 2FA ile'), findsOneWidget);
    expect(logins.items, isEmpty);

    await tester.tap(find.text('2 kaydı ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Kaynak dosyayı sil'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.textContaining('KeyKey bu dosyayı silemez'), findsOneWidget);
    expect(find.text('2 kayıt eklendi.'), findsOneWidget);
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(find.text('Parolaları içe aktar'), findsOneWidget);

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
    await tester.tap(find.text('1 kaydı ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();

    expect(logins.items.map((item) => item.content.name), ['Eski', 'Basit']);
    expect(otps.items, isEmpty);
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

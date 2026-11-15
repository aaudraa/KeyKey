import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/platform/export_file_picker.dart';
import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/data/otpauth_uri.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/add_flow.dart';
import '../../support/fake_vault_service.dart';
import '../../support/vector_aes_gcm.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeOtpRepository otps;
  late FakeExportFilePicker files;
  late FakeQrCamera camera;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);

  setUp(() {
    service = FakeVaultService(sodium);
    otps = FakeOtpRepository();
    files = FakeExportFilePicker();
    camera = FakeQrCamera();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> chooseAddOption(WidgetTester tester, String option) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      otps: otps,
      files: files,
      camera: camera,
      clock: () => DateTime.fromMillisecondsSinceEpoch(30000, isUtc: true),
    );
    await tester.tap(find.byIcon(Icons.shield_outlined));
    await settle(tester);
    await openAddOtp(tester, option, settle: () => settle(tester));
  }

  Future<void> importFile(WidgetTester tester, String fixture) async {
    files.next = ExportFileRead(importFixture(fixture));
    await chooseAddOption(tester, 'Başka uygulamadan aktar');
  }

  /// Şifre çözme ayrı isolate'te çalışır, sahte saatli testte bitmesi için
  /// gerçek zaman geçmeli.
  Future<void> waitForIsolate(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
  }

  testWidgets('şifresiz Aegis dosyası içe aktarılıyor', (tester) async {
    await importFile(tester, 'aegis_plain.json');

    expect(find.text('İçe aktar'), findsOneWidget);
    // Liste tembel kurulur, satır saymak yerine seçili sayıya bakılır.
    expect(find.text('6 hesabı ekle'), findsOneWidget);
    expect(
      find.textContaining('1 hesap KeyKey desteklemediği için'),
      findsOneWidget,
    );
    expect(otps.items, isEmpty);

    await tester.tap(find.text('6 hesabı ekle'));
    await settle(tester);

    expect(otps.items, hasLength(6));
    expect(find.text('6 hesap eklendi.'), findsOneWidget);
    expect(find.text('İçe aktar'), findsNothing);
    final deno = otps.items.firstWhere((item) => item.content.issuer == 'Deno');
    expect(deno.content.account, 'Mason');
  });

  testWidgets('zaten ekli hesap işaretleniyor ve seçilemiyor', (tester) async {
    otps.items.add(
      FakeOtpRepository.item(
        OtpContent(
          parameters: OtpParameters.totp(
            secret: Base32.decodeCanonical('4SJHB4GSD43FZBAI7C2HLRJGPQ'),
          ),
          issuer: 'Eski ad',
        ),
        id: 1,
      ),
    );
    await importFile(tester, 'aegis_plain.json');

    expect(find.textContaining('Zaten ekli'), findsOneWidget);
    final duplicate = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.textContaining('Zaten ekli'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    expect(duplicate.value, isFalse);
    expect(duplicate.onChanged, isNull);

    await tester.tap(find.text('5 hesabı ekle'));
    await settle(tester);
    expect(otps.items, hasLength(6));
  });

  testWidgets('seçim kaldırılınca sayı değişiyor', (tester) async {
    await importFile(tester, 'aegis_plain.json');

    await tester.tap(find.text('Deno'));
    await settle(tester);

    expect(find.text('5 hesabı ekle'), findsOneWidget);
  });

  testWidgets('şifreli 2FAS dosyası parolayla açılıyor', (tester) async {
    await importFile(tester, '2fas_encrypted_v4.2fas');
    expect(find.text('Dışa aktarma parolası'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Dışa aktarma parolası'),
      'yanlis',
    );
    await tester.tap(find.text('Aç'));
    await waitForIsolate(tester);
    expect(find.text('Parola yanlış.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Dışa aktarma parolası'),
      'test',
    );
    await tester.tap(find.text('Aç'));
    await waitForIsolate(tester);

    expect(find.text('4 hesabı ekle'), findsOneWidget);
    await tester.tap(find.text('4 hesabı ekle'));
    await settle(tester);
    expect(otps.items, hasLength(4));
  });

  testWidgets('tanınmayan dosya söyleniyor', (tester) async {
    files.next = ExportFileRead(utf8.encode('{"hesaplar": []}'));
    await chooseAddOption(tester, 'Başka uygulamadan aktar');

    expect(
      find.text('Bu dosya bir Aegis veya 2FAS dışa aktarması değil.'),
      findsOneWidget,
    );
    expect(find.text('İçe aktar'), findsNothing);
  });

  testWidgets('dosya seçilmezse sessizce dönülüyor', (tester) async {
    await chooseAddOption(tester, 'Başka uygulamadan aktar');

    expect(files.calls, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets("Google Authenticator QR'ı içe aktarma ekranını açıyor", (
    tester,
  ) async {
    // Tek hesaplık dışa aktarma: anahtar "12345678901234567890", GitHub:ali.
    final account = utf8.encode('12345678901234567890');
    final otpParameters = [
      0x0a, account.length, ...account, //
      0x12, 0x0a, ...utf8.encode('GitHub:ali'),
      0x1a, 0x06, ...utf8.encode('GitHub'),
      0x20, 0x01, 0x28, 0x01, 0x30, 0x02,
    ];
    final payload = [
      0x0a, otpParameters.length, ...otpParameters, //
      0x18, 0x02, // batch_size: 2
    ];
    final uri =
        'otpauth-migration://offline?data='
        '${Uri.encodeQueryComponent(base64.encode(payload))}';
    await chooseAddOption(tester, 'QR kodu tara');

    camera.scan(uri);
    await settle(tester);

    expect(find.text('İçe aktar'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('ali'), findsOneWidget);
    expect(find.textContaining('Her birini ayrı tara'), findsOneWidget);

    await tester.tap(find.text('1 hesabı ekle'));
    await settle(tester);
    expect(
      otps.items.single.content.parameters,
      OtpauthUri.parse('otpauth://totp/x?secret=${Base32.encode(account)}')
          .parameters,
    );
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/presentation/otp_display.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  // RFC 4226 Ek D anahtarı: 30. saniyede TOTP sayacı 1 → 287082.
  final rfcSecret = ascii.encode('12345678901234567890');

  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeLoginRepository logins;
  late FakeOtpRepository otps;
  late RecordingClipboard clipboard;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);

  Uint8List loginId(int id) =>
      FakeLoginRepository.item(const LoginContent(name: ''), id: id).id;

  setUp(() {
    service = FakeVaultService(sodium);
    clipboard = RecordingClipboard();
    logins = FakeLoginRepository(
      items: [
        FakeLoginRepository.item(
          const LoginContent(name: 'GitHub', username: 'ali'),
          id: 1,
        ),
        FakeLoginRepository.item(const LoginContent(name: 'Posta'), id: 2),
      ],
    );
    otps = FakeOtpRepository(
      items: [
        FakeOtpRepository.item(
          OtpContent(
            parameters: OtpParameters.totp(secret: rfcSecret),
            issuer: 'GitHub',
          ),
          id: 1,
        ),
      ],
    );
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpApp(WidgetTester tester) => pumpKeyKey(
    tester,
    status: VaultOpen(service.newSession()),
    service: service,
    logins: logins,
    otps: otps,
    clipboard: clipboard,
    clock: () => DateTime.fromMillisecondsSinceEpoch(30000, isUtc: true),
  );

  Future<void> openOtpEdit(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.shield_outlined));
    await settle(tester);
    await tester.longPress(find.byKey(ValueKey(otpIdHex(otps.items.single))));
    await settle(tester);
    await tester.tap(find.text('Düzenle'));
    await settle(tester);
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await settle(tester);
    await tester.tap(finder);
    await settle(tester);
  }

  /// Eşleşmesi olmayan hesapta "Daha fazla seçenek" → "Parola kaydı".
  Future<void> openPicker(WidgetTester tester) async {
    await tapVisible(tester, find.text('Daha fazla seçenek'));
    await tapVisible(tester, find.widgetWithText(ActionChip, 'Parola kaydı'));
  }

  testWidgets('formdan parola kaydı seçilip kaydediliyor', (tester) async {
    await openOtpEdit(tester);
    // Eşleşme yokken alan görünmez; yongadan seçilir.
    expect(find.text('Eşleştirilmedi'), findsNothing);

    await openPicker(tester);
    expect(find.text('Parola kaydıyla eşleştir'), findsOneWidget);
    expect(find.text('Eşleştirmeyi kaldır'), findsNothing);
    await tester.tap(find.text('GitHub').last);
    await settle(tester);

    expect(find.text('Eşleştirilmedi'), findsNothing);
    await tester.tap(find.text('Kaydet'));
    await settle(tester);

    expect(otps.items.single.content.loginId, loginId(1));
  });

  testWidgets('seçici aranabiliyor', (tester) async {
    await openOtpEdit(tester);
    await openPicker(tester);

    await tester.enterText(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      ),
      'post',
    );
    await settle(tester);

    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('GitHub'),
      ),
      findsNothing,
    );
    expect(find.text('Posta'), findsOneWidget);
  });

  group('eşleşmiş hesap', () {
    setUp(() {
      otps.items[0] = FakeOtpRepository.item(
        otps.items[0].content.copyWith(loginId: loginId(1)),
        id: 1,
      );
    });

    testWidgets('parola ayrıntısında kod görünüyor ve kopyalanıyor', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('GitHub'));
      await settle(tester);

      expect(find.text('2FA kodu'), findsOneWidget);
      expect(find.text('287 082'), findsOneWidget);

      await tester.tap(find.text('287 082'));
      await settle(tester);
      expect(clipboard.copied, ['287082']);
    });

    testWidgets('eşleşmeyen kayıtta kod yok', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Posta'));
      await settle(tester);

      expect(find.text('2FA kodu'), findsNothing);
    });

    testWidgets('çöp kutusundaki 2FA hesabının kodu gösterilmiyor', (
      tester,
    ) async {
      otps.items[0] = FakeOtpRepository.item(
        otps.items[0].content.copyWith(trashedAt: DateTime.utc(2026, 11)),
        id: 1,
      );
      await pumpApp(tester);
      await tester.tap(find.text('GitHub'));
      await settle(tester);

      expect(find.text('2FA kodu'), findsNothing);
    });

    testWidgets('eşleştirme kaldırılıyor', (tester) async {
      await openOtpEdit(tester);
      expect(find.text('Eşleştirilmedi'), findsNothing);

      await tapVisible(tester, find.text('Parola kaydı'));
      await tester.tap(find.text('Eşleştirmeyi kaldır'));
      await settle(tester);
      // Eşleşme kalkınca alan da gizlenir.
      expect(find.widgetWithText(ListTile, 'Parola kaydı'), findsNothing);
      await tester.tap(find.text('Kaydet'));
      await settle(tester);

      expect(otps.items.single.content.loginId, isNull);
    });

    testWidgets('silinmiş parola kaydına eşleşme kaydedilince kalkıyor', (
      tester,
    ) async {
      logins.items.removeAt(0);
      await openOtpEdit(tester);

      expect(find.text('Eşleştirilmedi'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'GitHub'), 'Git');
      await tester.tap(find.text('Kaydet'));
      await settle(tester);

      expect(otps.items.single.content.loginId, isNull);
    });
  });
}

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/platform/qr_image_reader.dart';
import 'package:keykey/features/authenticator/application/scanned_code.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/data/otpauth_uri.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/add_flow.dart';
import '../../support/fake_vault_service.dart';

void main() {
  const link =
      'otpauth://totp/GitHub:ali@example.com?secret=JBSWY3DPEHPK3PXP'
      '&issuer=GitHub';

  group('taranan metnin sınıflandırılması', () {
    test('hesap', () {
      final scanned = ScannedCode.classify('  $link\n');
      expect(scanned, isA<OtpauthCode>());
      expect((scanned as OtpauthCode).account.issuer, 'GitHub');
    });

    test('okunamayan ve desteklenmeyen bağlantı', () {
      expect(
        ScannedCode.classify('otpauth://totp/x?secret=1'),
        isA<InvalidOtpauthCode>().having(
          (code) => code.error,
          'error',
          OtpauthError.invalidSecret,
        ),
      );
      expect(
        ScannedCode.classify('OTPAUTH://steam/x?secret=JBSWY3DP'),
        isA<InvalidOtpauthCode>().having(
          (code) => code.error,
          'error',
          OtpauthError.unsupportedType,
        ),
      );
    });

    test('Google Authenticator dışa aktarması', () {
      expect(
        ScannedCode.classify('otpauth-migration://offline?data=CjEKCkhlbGxv'),
        isA<MigrationCode>(),
      );
    });

    test('ilgisiz ve boş metin', () {
      for (final text in [null, '', '   ', 'https://example.com', 'WIFI:S:x']) {
        expect(ScannedCode.classify(text), isA<UnrelatedCode>(), reason: text);
      }
    });

    test('rastgele metin hata fırlatmıyor', () {
      final random = Random(11);
      for (var i = 0; i < 5000; i++) {
        final text = String.fromCharCodes(
          List.generate(random.nextInt(60), (_) => random.nextInt(0x3000)),
        );
        ScannedCode.classify(i.isEven ? 'otpauth://$text' : text);
      }
    });
  });

  group('ekranlar', () {
    late SodiumSumo sodium;
    late FakeVaultService service;
    late FakeOtpRepository otps;
    late FakeQrImageReader images;
    late FakeQrCamera camera;

    setUpAll(() async {
      sodium = await SodiumSumoInit.init();
      WidgetController.hitTestWarningShouldBeFatal = true;
    });

    tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);

    setUp(() {
      service = FakeVaultService(sodium);
      otps = FakeOtpRepository();
      images = FakeQrImageReader();
      camera = FakeQrCamera();
    });

    /// Hesap ekleyince geri sayım başlar ve pumpAndSettle bitmez.
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
        qrImages: images,
        camera: camera,
        clock: () => DateTime.fromMillisecondsSinceEpoch(30000, isUtc: true),
      );
      await tester.tap(find.byIcon(Icons.shield_outlined));
      await settle(tester);
      await openAddOtp(tester, option, settle: () => settle(tester));
    }

    testWidgets('kamerayla okunan hesap onaydan sonra kaydediliyor', (
      tester,
    ) async {
      await chooseAddOption(tester, 'QR kodu tara');
      expect(camera.isShown, isTrue);

      camera.scan(link);
      await settle(tester);

      // Kaydedilmeden önce gösteriliyor.
      expect(otps.items, isEmpty);
      expect(find.text('Yeni 2FA hesabı'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'GitHub'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'ali@example.com'), findsOneWidget);

      await tester.tap(find.text('Kaydet'));
      await settle(tester);

      expect(otps.items.single.content.issuer, 'GitHub');
      expect(otps.items.single.content.parameters.kind, OtpKind.totp);
      // Tarama ekranı onay ekranıyla değişti, kaydedince listeye dönülüyor.
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('QR kodu tara'), findsNothing);
    });

    testWidgets('onaydan vazgeçilince hiçbir şey kaydedilmiyor', (
      tester,
    ) async {
      await chooseAddOption(tester, 'QR kodu tara');
      camera.scan(link);
      await settle(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(otps.items, isEmpty);
      expect(find.textContaining('Henüz 2FA hesabı yok'), findsOneWidget);
    });

    testWidgets('ilgisiz QR uyarı veriyor, tarama sürüyor', (tester) async {
      await chooseAddOption(tester, 'QR kodu tara');

      camera.scan('https://example.com');
      await settle(tester);
      expect(find.text('Bu QR kodu bir 2FA hesabı değil.'), findsOneWidget);

      camera.scan('otpauth://totp/x?secret=1');
      await settle(tester);
      expect(find.text('Bu otpauth bağlantısı okunamadı.'), findsOneWidget);

      camera.scan(link);
      await settle(tester);
      expect(find.text('Yeni 2FA hesabı'), findsOneWidget);
    });

    testWidgets('kamera kullanılamıyorsa görselden okuma öneriliyor', (
      tester,
    ) async {
      await chooseAddOption(tester, 'QR kodu tara');

      camera.fail();
      await settle(tester);
      expect(find.textContaining('Kamera kullanılamıyor'), findsOneWidget);

      images.next = const QrImageRead(link);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Görseldeki QR kodunu oku'),
      );
      await settle(tester);

      expect(images.calls, 1);
      expect(find.widgetWithText(TextField, 'GitHub'), findsOneWidget);
    });

    testWidgets('görselden okunan hesap formu dolduruyor', (tester) async {
      images.next = const QrImageRead(link);
      await chooseAddOption(tester, 'Görseldeki QR kodunu oku');

      expect(camera.isShown, isFalse);
      expect(find.widgetWithText(TextField, 'GitHub'), findsOneWidget);

      await tester.tap(find.text('Kaydet'));
      await settle(tester);
      expect(otps.items.single.content.account, 'ali@example.com');
    });

    testWidgets('görselde QR yoksa söyleniyor', (tester) async {
      images.next = const QrImageNotFound();
      await chooseAddOption(tester, 'Görseldeki QR kodunu oku');

      expect(find.text('Görselde QR kodu bulunamadı.'), findsOneWidget);
      expect(otps.items, isEmpty);
    });

    testWidgets('görsel seçilmezse sessizce dönülüyor', (tester) async {
      await chooseAddOption(tester, 'Görseldeki QR kodunu oku');

      expect(images.calls, 1);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining('Henüz 2FA hesabı yok'), findsOneWidget);
    });
  });
}

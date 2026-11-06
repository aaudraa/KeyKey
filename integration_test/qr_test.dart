import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/core/platform/qr_image_reader.dart';
import 'package:keykey/features/authenticator/presentation/qr_scan_screen.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';
import 'package:path_provider/path_provider.dart';

/// QR okumayı gerçek Android'de sınar.
///
/// Kamera testi iznin durumunu bilmek ister, onu betik ayarlar:
/// resources/scripts/camera-device-test.sh. Betik olmadan yalnızca görsel
/// testleri çalışır.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// `granted` veya `denied`. Boşsa kamera testi atlanır.
  const camera = String.fromEnvironment('KK_CAMERA');

  const link =
      'otpauth://totp/KeyKey:deneme@example.com?secret=JBSWY3DPEHPK3PXP'
      '&issuer=KeyKey';

  late Directory directory;

  setUp(() async {
    final cache = await getTemporaryDirectory();
    directory = cache.createTempSync('kk_qr_');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  /// Yerel kodlayıcıyla QR üretir ve PNG olarak yazar.
  Future<File> writeQrPng(String contents) async {
    final encoded = zx.encodeBarcode(
      contents: contents,
      params: EncodeParams(width: 600, height: 600, margin: 40),
    );
    expect(encoded.isValid, isTrue, reason: encoded.error);
    final width = encoded.width!;
    final height = encoded.height!;
    final gray = encoded.data!;
    final rgba = Uint8List(width * height * 4);
    for (var i = 0; i < width * height; i++) {
      rgba
        ..[i * 4] = gray[i]
        ..[i * 4 + 1] = gray[i]
        ..[i * 4 + 2] = gray[i]
        ..[i * 4 + 3] = 255;
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return File('${directory.path}/qr.png')
      ..writeAsBytesSync(png!.buffer.asUint8List());
  }

  group('görselden okuma', () {
    testWidgets('QR okunuyor ve görselin kopyası siliniyor', (tester) async {
      final file = await writeQrPng(link);

      final result = await ZxingQrImageReader().readFile(XFile(file.path));

      expect(result, isA<QrImageRead>().having((r) => r.text, 'text', link));
      expect(file.existsSync(), isFalse);
    });

    testWidgets('çok hesaplı büyük QR da okunuyor', (tester) async {
      // Google Authenticator 10 hesabı tek QR'a koyar, yaklaşık bu boyutta.
      final random = Random(3);
      final data = String.fromCharCodes(
        List.generate(
          900,
          (_) =>
              'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
                  .codeUnitAt(random.nextInt(62)),
        ),
      );
      final contents = 'otpauth-migration://offline?data=$data';
      final file = await writeQrPng(contents);

      final result = await ZxingQrImageReader().readFile(XFile(file.path));

      expect(
        result,
        isA<QrImageRead>().having((r) => r.text, 'text', contents),
      );
    });

    testWidgets('bozuk görsel uygulamayı düşürmüyor', (tester) async {
      final random = Random(9);
      final file = File('${directory.path}/bozuk.png')
        ..writeAsBytesSync([
          0x89, 0x50, 0x4e, 0x47, // PNG imzasıyla başlayıp bozuluyor.
          for (var i = 0; i < 5000; i++) random.nextInt(256),
        ]);

      final result = await ZxingQrImageReader().readFile(XFile(file.path));

      expect(result, isA<QrImageNotFound>());
      expect(file.existsSync(), isFalse);
    });

    testWidgets('QR olmayan görsel', (tester) async {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        Uint8List(200 * 200 * 4)..fillRange(0, 200 * 200 * 4, 255),
        200,
        200,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      final image = await completer.future;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('${directory.path}/bos.png')
        ..writeAsBytesSync(png!.buffer.asUint8List());

      final result = await ZxingQrImageReader().readFile(XFile(file.path));

      expect(result, isA<QrImageNotFound>());
    });
  });

  testWidgets('kamera izni: $camera', skip: camera.isEmpty, (tester) async {
    // flutter test uygulamayı her çalıştırmada yeniden kurar ve sonunda
    // kaldırır. İzin ancak uygulama kuruluyken ayarlanabildiği için betik bu
    // satırı görünce izni ayarlar ve işaret dosyasını oluşturur.
    final support = await getApplicationSupportDirectory();
    final signal = File('${support.path}/kk_kamera_hazir');
    if (signal.existsSync()) signal.deleteSync();
    // Betik çıktıyı okuyor, logger burada işe yaramaz.
    // ignore: avoid_print
    print('KKKAMERA_IZIN');
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (!signal.existsSync()) {
      if (DateTime.now().isAfter(deadline)) fail('Betik izni ayarlamadı');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
    }

    final l10n = lookupAppLocalizations(const Locale('tr'));
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('tr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: QrScanScreen(),
        ),
      ),
    );

    // Kamera açılırken ekran birkaç saniye bekleyebilir.
    final unavailable = find.text(l10n.otpCameraUnavailable);
    final preview = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'CameraPreview',
    );
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (unavailable.evaluate().isNotEmpty || preview.evaluate().isNotEmpty) {
        break;
      }
    }

    if (camera == 'granted') {
      expect(preview, findsOneWidget);
      expect(unavailable, findsNothing);
    } else {
      expect(unavailable, findsOneWidget);
      expect(preview, findsNothing);
    }
    // Kamerayı bırakması için ekranı kapat.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

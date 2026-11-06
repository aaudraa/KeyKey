import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:keykey/features/authenticator/application/scanned_code.dart';
import 'package:keykey/features/authenticator/presentation/scanned_code_handler.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Kamera görüntüsünü gösterir ve okunan her QR metnini [onText]'e verir.
/// Kamera açılamazsa, örneğin izin reddedilirse, [onUnavailable] çağrılır.
typedef QrCameraBuilder = Widget Function({
  required ValueChanged<String> onText,
  required VoidCallback onUnavailable,
});

/// `flutter_zxing` kamerası. Testler kendi kamerasını verir.
final qrCameraProvider = Provider<QrCameraBuilder>(
  (ref) =>
      ({required onText, required onUnavailable}) =>
          _ZxingCamera(onText: onText, onUnavailable: onUnavailable),
);

/// Önce cihazdaki kameraları sorar. `ReaderWidget` kamera bulamayınca hata
/// bildirmiyor, ekran sonsuza dek yükleniyor gibi kalıyor.
class _ZxingCamera extends StatefulWidget {
  const new({required this.onText, required this.onUnavailable});

  final ValueChanged<String> onText;
  final VoidCallback onUnavailable;

  @override
  State<_ZxingCamera> createState() => _ZxingCameraState();
}

class _ZxingCameraState extends State<_ZxingCamera> {
  bool _hasCamera = false;

  @override
  void initState() {
    super.initState();
    unawaited(_checkCameras());
  }

  Future<void> _checkCameras() async {
    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException {
      cameras = const [];
    }
    if (!mounted) return;
    if (cameras.isEmpty) {
      widget.onUnavailable();
    } else {
      setState(() => _hasCamera = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasCamera) return const Center(child: CircularProgressIndicator());
    return ReaderWidget(
      codeFormat: Format.qrCode,
      tryInverted: true,
      // Gerçek telefonda bilgisayar ekranındaki QR, paketin varsayılanlarıyla
      // (saniyede bir kare, görüntünün ortadaki yarısı, 720p) ancak 15 saniye
      // uğraşınca okunabildi. Daha sık, daha geniş alanda ve daha dikkatli
      // taranıyor; uzaktaki küçük QR için çözünürlük de artırıldı.
      tryHarder: true,
      cropPercent: 0.8,
      scanDelay: const Duration(milliseconds: 250),
      resolution: ResolutionPreset.veryHigh,
      showGallery: false,
      showToggleCamera: false,
      onScan: (code) {
        final text = code.text;
        if (code.isValid && text != null) widget.onText(text);
      },
      onControllerCreated: (controller, error) {
        if (error != null) widget.onUnavailable();
      },
    );
  }
}

/// Kamerayla QR okur. Kamera izni bu ekran açılınca istenir.
///
/// Görüntü yalnızca bellekte çözülür, hiçbir yere kaydedilmez. Okunan hesap
/// hemen kaydedilmez, kullanıcı onay ekranında görür.
class QrScanScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  bool _unavailable = false;
  bool _handled = false;

  /// Aynı ilgisiz QR her karede okununca uyarı tekrar tekrar çıkmasın.
  String? _lastRejected;

  Future<void> _onText(String text) async {
    if (_handled || text == _lastRejected) return;
    // Kamera her saniye okumaya devam ediyor; işlenirken yenisi beklesin.
    _handled = true;
    final opened = await handleScannedCode(
      context,
      ScannedCode.classify(text),
      replace: true,
    );
    if (!opened) {
      _handled = false;
      _lastRejected = text;
    }
  }

  Future<void> _readImageInstead() async {
    await readQrFromImage(context, ref, replace: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final camera = ref.watch(qrCameraProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.otpAddScan),
        actions: [
          IconButton(
            tooltip: l10n.otpAddImage,
            icon: const Icon(Icons.image_outlined),
            onPressed: _readImageInstead,
          ),
        ],
      ),
      body: _unavailable
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      l10n.otpCameraUnavailable,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _readImageInstead,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(l10n.otpAddImage),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: camera(
                    onText: _onText,
                    onUnavailable: () {
                      if (mounted) setState(() => _unavailable = true);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.otpScanHint, textAlign: TextAlign.center),
                ),
              ],
            ),
    );
  }
}

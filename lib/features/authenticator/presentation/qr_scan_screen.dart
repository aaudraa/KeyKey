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
final qrCameraProvider = Provider<QrCameraBuilder>((ref) => _zxingCamera);

Widget _zxingCamera({
  required ValueChanged<String> onText,
  required VoidCallback onUnavailable,
}) {
  return ReaderWidget(
    codeFormat: Format.qrCode,
    tryInverted: true,
    showGallery: false,
    showToggleCamera: false,
    onScan: (code) {
      final text = code.text;
      if (code.isValid && text != null) onText(text);
    },
    onControllerCreated: (controller, error) {
      if (error != null) onUnavailable();
    },
  );
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
    final scanned = ScannedCode.classify(text);
    if (scanned is OtpauthCode) {
      _handled = true;
    } else {
      _lastRejected = text;
    }
    await handleScannedCode(context, scanned, replace: true);
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

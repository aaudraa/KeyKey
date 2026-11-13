import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:keykey/app/ui/kk_ambient.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_motion.dart';
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

  /// Tarama çerçevesi (testler için) ve kod okununca kapandığı ölçek
  /// (madde 4.8).
  static const Key frameKey = ValueKey('kk-qr-frame');
  static const double closedScale = 0.9;

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
    // Çerçeve okunan kodun üstüne kapanır (madde 4.8).
    setState(() => _handled = true);
    // Kapanış görünsün diye form, çerçeve kapanınca açılır.
    await Future<void>.delayed(KkMotion.of(context, KkMotion.base));
    // Bu arada geri dönüldüyse ekran kapanıyor; form, açan ekranın yerine
    // geçmesin.
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    final opened = await handleScannedCode(
      context,
      ScannedCode.classify(text),
      replace: true,
    );
    if (!opened && mounted) {
      setState(() => _handled = false);
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
    return KkScaffold(
      appBar: kkAppBar(
        context,
        title: l10n.otpAddScan,
        actions: [
          KkCircleButton(
            icon: Icons.image_rounded,
            tooltip: l10n.otpAddImage,
            onPressed: _readImageInstead,
          ),
        ],
      ),
      body: _unavailable
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GlassSurface(
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
              ),
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: camera(
                    onText: _onText,
                    onUnavailable: () {
                      if (mounted) setState(() => _unavailable = true);
                    },
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(child: _ScanFrame(closed: _handled)),
                  ),
                ),
                // Açıklama kamera görüntüsünün üstünde, güçlü camda.
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    top: false,
                    child: GlassSurface(
                      strong: true,
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.otpScanHint,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Kameranın üstündeki tarama çerçevesi (madde 4.8): köşeleri süren hareket
/// açıkken yavaşça nefes alır; kod okununca [KkMotion.base] boyunca
/// [QrScanScreen.closedScale]'e kapanır.
class _ScanFrame extends StatefulWidget {
  const new({required this.closed});

  static const double size = 240;
  static const double breathDepth = 0.03;

  final bool closed;

  @override
  State<_ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<_ScanFrame> with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: KkMotion.breath,
  );
  late final AnimationController _close = AnimationController(
    vsync: this,
    duration: KkMotion.base,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (KkAmbient.of(context)) {
      if (!_breath.isAnimating) _breath.repeat();
    } else {
      _breath.stop();
    }
  }

  @override
  void didUpdateWidget(_ScanFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.closed == oldWidget.closed) return;
    _close.duration = KkMotion.of(context, KkMotion.base);
    if (widget.closed) {
      _breath.stop();
      _close.forward();
    } else {
      _close.reverse();
      // Kod reddedildi, tarama sürüyor: çerçeve yeniden nefes alır.
      if (KkAmbient.of(context)) _breath.repeat();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _close.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: QrScanScreen.frameKey,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breath, _close]),
        builder: (context, child) {
          final breathing = _breath.isAnimating
              ? _ScanFrame.breathDepth *
                    (0.5 - 0.5 * math.cos(_breath.value * 2 * math.pi))
              : 0.0;
          final closing = KkMotion.standard.transform(_close.value);
          final scale =
              (1 + breathing) * (1 - (1 - QrScanScreen.closedScale) * closing);
          return Transform.scale(scale: scale, child: child);
        },
        child: const SizedBox.square(
          dimension: _ScanFrame.size,
          child: CustomPaint(painter: _CornersPainter()),
        ),
      ),
    );
  }
}

/// Çerçevenin dört köşesi.
class _CornersPainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 32.0;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    for (final (corner, dx, dy) in [
      (Offset.zero, 1.0, 1.0),
      (Offset(w, 0), -1.0, 1.0),
      (Offset(0, h), 1.0, -1.0),
      (Offset(w, h), -1.0, -1.0),
    ]) {
      canvas
        ..drawLine(corner, corner + Offset(arm * dx, 0), paint)
        ..drawLine(corner, corner + Offset(0, arm * dy), paint);
    }
  }

  @override
  bool shouldRepaint(_CornersPainter old) => false;
}

import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_glass.dart';

/// Ekranların renkli zemini: düz renk ve üstünde üç büyük, yumuşak kenarlı
/// leke. Lekeler içerikle birlikte kaymaz. Bulanıklaştırma yerine yumuşak
/// geçişli boyamayla çizilir (ucuzdur).
class KkBackdrop extends StatelessWidget {
  const new({this.drifting = false, super.key});

  /// Lekeler çok yavaş yer değiştirir (yalnızca kilit ekranı).
  final bool drifting;

  @override
  Widget build(BuildContext context) {
    final glass = KkGlass.of(context);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BlobPainter(glass.ground, glass.blobs, glass.blobAlpha),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  new(this.ground, this.blobs, this.alpha);

  final Color ground;
  final List<Color> blobs;
  final double alpha;

  /// Merkezler ekranın oranı olarak, yarıçaplar genişliğin katı olarak.
  static const _centers = [
    Offset(0.10, 0.08),
    Offset(1, 0.45),
    Offset(0.05, 0.95),
  ];
  static const _radii = [0.75, 0.70, 0.70];

  /// Merkezden kenara (1 - t)² ile sönen görünürlük.
  static const _stops = [0.0, 0.25, 0.5, 0.75, 1.0];
  static const _falloff = [1.0, 0.5625, 0.25, 0.0625, 0.0];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = ground);
    for (var i = 0; i < blobs.length && i < _centers.length; i++) {
      final center = Offset(
        _centers[i].dx * size.width,
        _centers[i].dy * size.height,
      );
      final radius = _radii[i] * size.width;
      final shader = RadialGradient(
        colors: [
          for (final f in _falloff) blobs[i].withValues(alpha: alpha * f),
        ],
        stops: _stops,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawRect(rect, Paint()..shader = shader);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) =>
      old.ground != ground || old.alpha != alpha || old.blobs != blobs;
}

/// Zeminini kendisi çizen iskelet. Bütün ekranlar bunu kullanır; içindeki
/// `Scaffold` saydamdır.
class KkScaffold extends StatelessWidget {
  const new({
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.extendBody = false,
    this.resizeToAvoidBottomInset,
    this.driftingBackdrop = false,
    super.key,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final bool extendBody;
  final bool? resizeToAvoidBottomInset;
  final bool driftingBackdrop;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: KkBackdrop(drifting: driftingBackdrop)),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar,
          body: body,
          bottomNavigationBar: bottomNavigationBar,
          extendBody: extendBody,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        ),
      ],
    );
  }
}

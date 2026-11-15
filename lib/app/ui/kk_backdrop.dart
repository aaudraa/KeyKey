import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_ambient.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_motion.dart';

/// Ekranların zemini: düz renk ve üstünde üç büyük, yumuşak kenarlı
/// leke. Lekeler içerikle birlikte kaymaz. Bulanıklaştırma yerine yumuşak
/// geçişli boyamayla çizilir (ucuzdur).
///
/// Süren hareket açıkken ([KkAmbient]) lekeler çok yavaş yer değiştirir.
/// Animasyonlar kapalıyken, ekran görünmüyorken (`TickerMode`) ve liste
/// kayarken ([KkScrollState]) durur.
class KkBackdrop extends StatefulWidget {
  const new({this.lively = false, super.key});

  /// Kilit ekranındaki kayma döngüsü.
  static const Duration driftPeriod = KkMotion.drift;

  /// Lekenin merkezinden en çok kayacağı yol, genişliğin oranı olarak.
  static const double driftAmount = 0.06;

  /// Kilit ekranında daha canlı ([KkMotion.drift]), diğer ekranlarda daha
  /// sakin ([KkMotion.calmDrift]) döngü.
  final bool lively;

  @override
  State<KkBackdrop> createState() => KkBackdropState();
}

// Animasyon ayarı değişince denetleyici yeniden kurulur; bu yüzden tek
// zamanlayıcılı karışım yetmez.
class KkBackdropState extends State<KkBackdrop> with TickerProviderStateMixin {
  AnimationController? _drift;
  ValueListenable<bool>? _scrolling;

  /// Lekeler şu an kayıyor mu (testler için).
  bool get isDrifting => _drift?.isAnimating ?? false;

  /// Kayma döngüsünün süresi.
  Duration get period => widget.lively ? KkMotion.drift : KkMotion.calmDrift;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrolling = KkScrollState.maybeOf(context)?.scrolling;
    if (scrolling != _scrolling) {
      _scrolling?.removeListener(_onScroll);
      _scrolling = scrolling?..addListener(_onScroll);
    }
    _sync();
  }

  @override
  void didUpdateWidget(KkBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final moving = KkAmbient.of(context);
    if (moving && _drift == null) {
      _drift = AnimationController(vsync: this, duration: period);
      _onScroll();
    } else if (!moving && _drift != null) {
      _drift!.dispose();
      _drift = null;
    }
    _drift?.duration = period;
  }

  /// Liste kayarken zemin durur, bırakınca kaldığı yerden sürer.
  void _onScroll() {
    final drift = _drift;
    if (drift == null) return;
    if (_scrolling?.value ?? false) {
      drift.stop();
    } else if (!drift.isAnimating) {
      drift.repeat();
    }
  }

  @override
  void dispose() {
    _scrolling?.removeListener(_onScroll);
    _drift?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glass = KkGlass.of(context);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BlobPainter(
          glass.ground,
          glass.blobs,
          glass.blobAlpha,
          drift: _drift,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  new(this.ground, this.blobs, this.alpha, {this.drift})
    : super(repaint: drift);

  final Color ground;
  final List<Color> blobs;
  final double alpha;

  /// 0..1 arası döngü; `null` ise lekeler yerinde durur.
  final Animation<double>? drift;

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
    final turn = (drift?.value ?? 0) * 2 * math.pi;
    final reach = KkBackdrop.driftAmount * size.width;
    for (var i = 0; i < blobs.length && i < _centers.length; i++) {
      // Her leke kendi evresinde küçük bir elips çizer.
      final phase = turn + i * 2 * math.pi / 3;
      final shift = drift == null
          ? Offset.zero
          : Offset(math.cos(phase) * reach, math.sin(phase) * reach * 0.8);
      final center =
          Offset(_centers[i].dx * size.width, _centers[i].dy * size.height) +
          shift;
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
      old.ground != ground ||
      old.alpha != alpha ||
      old.blobs != blobs ||
      old.drift != drift;
}

/// Ekrandaki ana listenin kaydırma durumu: konum (küçülen başlık için) ve
/// kayıp kaymadığı (zemin kayarken durur). [KkScaffold] kurar.
class KkScrollState extends InheritedWidget {
  const new({
    required this.offset,
    required this.scrolling,
    required super.child,
    super.key,
  });

  final ValueListenable<double> offset;
  final ValueListenable<bool> scrolling;

  static KkScrollState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KkScrollState>();

  @override
  bool updateShouldNotify(KkScrollState old) =>
      old.offset != offset || old.scrolling != scrolling;
}

/// Zeminini kendisi çizen iskelet. Bütün ekranlar bunu kullanır; içindeki
/// `Scaffold` saydamdır. Gövdedeki dikey listenin kaydırmasını
/// [KkScrollState] ile paylaşır.
class KkScaffold extends StatefulWidget {
  const new({
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.extendBody = false,
    this.resizeToAvoidBottomInset,
    this.livelyBackdrop = false,
    super.key,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final bool extendBody;
  final bool? resizeToAvoidBottomInset;

  /// Kilit ekranının daha canlı kayan zemini.
  final bool livelyBackdrop;

  @override
  State<KkScaffold> createState() => _KkScaffoldState();
}

class _KkScaffoldState extends State<KkScaffold> {
  final _offset = ValueNotifier<double>(0);
  final _scrolling = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _offset.dispose();
    _scrolling.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    // Yalnızca gövdenin kendi dikey listesi; iç içe yatay şeritler sayılmaz.
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    _offset.value = n.metrics.pixels;
    if (n is ScrollStartNotification) {
      _scrolling.value = true;
    } else if (n is ScrollEndNotification) {
      _scrolling.value = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return KkScrollState(
      offset: _offset,
      scrolling: _scrolling,
      child: Stack(
        children: [
          Positioned.fill(child: KkBackdrop(lively: widget.livelyBackdrop)),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: widget.appBar,
            body: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: widget.body,
            ),
            bottomNavigationBar: widget.bottomNavigationBar,
            extendBody: widget.extendBody,
            resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
          ),
        ],
      ),
    );
  }
}

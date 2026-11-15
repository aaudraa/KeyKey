import 'dart:async';

import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_motion.dart';

/// Kaydedildi işareti (madde 2.2): onay çizgisi soldan sağa çizilerek
/// belirir. İşaret [KkMotion.emphasis]'in ilk yarısında çizilir, kalanında
/// görünür kalır; süre bitince [onDone] bir kez çağrılır (ekran o zaman
/// kapanır). "Animasyonları kaldır" açıkken işaret hemen tam görünür.
class KkDoneMark extends StatefulWidget {
  const new({
    this.size = 22,
    this.color,
    this.semanticLabel,
    this.onDone,
    super.key,
  });

  final double size;

  /// Verilmezse çevredeki yazı rengi.
  final Color? color;
  final String? semanticLabel;
  final VoidCallback? onDone;

  @override
  State<KkDoneMark> createState() => _KkDoneMarkState();
}

class _KkDoneMarkState extends State<KkDoneMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this);
  late final Animation<double> _draw = CurvedAnimation(
    parent: _motion,
    curve: const Interval(0, 0.5, curve: Curves.easeOutCubic),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _motion.duration = KkMotion.of(context, KkMotion.emphasis);
    // Süre sıfırsa bile onDone kare kurulurken değil, ardından çağrılır.
    unawaited(
      _motion.forward().orCancel.then(
        (_) => widget.onDone?.call(),
        onError: (Object _) {},
      ),
    );
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.color ??
        DefaultTextStyle.of(context).style.color ??
        IconTheme.of(context).color!;
    return Semantics(
      label: widget.semanticLabel,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _draw,
          builder: (context, _) => CustomPaint(
            painter: KkDoneMarkPainter(progress: _draw.value, color: color),
          ),
        ),
      ),
    );
  }
}

/// Onay çizgisinin [progress] kadarını çizer (0: hiç, 1: tamamı).
class KkDoneMarkPainter extends CustomPainter {
  const new({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.18, h * 0.54)
      ..lineTo(w * 0.42, h * 0.76)
      ..lineTo(w * 0.84, h * 0.28);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final drawn = Path();
    for (final metric in path.computeMetrics()) {
      drawn.addPath(
        metric.extractPath(0, metric.length * progress),
        Offset.zero,
      );
    }
    canvas.drawPath(drawn, paint);
  }

  @override
  bool shouldRepaint(KkDoneMarkPainter old) =>
      old.progress != progress || old.color != color;
}

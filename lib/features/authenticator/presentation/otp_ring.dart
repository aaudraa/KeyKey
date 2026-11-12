import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// TOTP kodunun kalan süresi: süreyle azalan halka, ortasında saniye. Son
/// beş saniyede uyarı rengine döner.
///
/// İlerleme çubuğu rolü verilmez: TalkBack değeri değişen ilerleme çubuğunu
/// her saniye okur. Kalan süre etikette durur, odaklanınca okunur.
class OtpRing extends StatelessWidget {
  const new({
    required this.remaining,
    required this.period,
    this.size = 34,
    super.key,
  });

  /// Kalan süre bundan azsa halka uyarı rengine döner.
  static const warningThreshold = Duration(seconds: 5);

  final Duration remaining;
  final int period;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final glass = KkGlass.of(context);
    final seconds = (remaining.inMilliseconds / 1000).ceil();
    final warning = remaining <= warningThreshold;
    final color = warning ? theme.colorScheme.error : glass.accent;
    final fraction = (remaining.inMilliseconds / (period * 1000)).clamp(
      0.0,
      1.0,
    );
    return Semantics(
      label: l10n.otpSecondsLeft(seconds),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(
            fraction: fraction,
            color: color,
            track: theme.colorScheme.onSurface.withValues(alpha: 0.12),
          ),
          child: Center(
            child: Text(
              '$seconds',
              textScaler: TextScaler.noScaling,
              style: theme.textTheme.labelSmall?.copyWith(
                color: warning
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  new({required this.fraction, required this.color, required this.track});

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas
      ..drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      )
      ..drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * fraction,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}

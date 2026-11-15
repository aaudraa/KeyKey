import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_motion.dart';

/// Değişince kayan metin (madde 3.4): değişen her karakter yukarı kayıp
/// solar, yenisi alttan gelir; karakterler arası [stagger]. Aynı kalan
/// karakter kıpırdamaz. Dururken tek bir [Text]'tir; kayarken ekran
/// okuyucu yalnızca yeni metni okur.
class KkRollingText extends StatefulWidget {
  const new({required this.text, this.style, super.key});

  static const Duration stagger = KkMotion.rollStagger;

  final String text;
  final TextStyle? style;

  @override
  State<KkRollingText> createState() => _KkRollingTextState();
}

class _KkRollingTextState extends State<KkRollingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _previous = null);
      }
    });

  /// Kayarken eski metin; dururken `null`.
  String? _previous;

  @override
  void didUpdateWidget(KkRollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text == oldWidget.text) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _previous = null;
      _motion.stop();
      return;
    }
    _previous = oldWidget.text;
    final length = math.max(widget.text.length, oldWidget.text.length);
    _motion
      ..duration =
          KkMotion.base + KkRollingText.stagger * math.max(0, length - 1)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previous = _previous;
    if (previous == null) return Text(widget.text, style: widget.style);
    final next = widget.text;
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    // Karakterlerin yeri, tam metnin kendi dizilişinden ölçülür; böylece
    // kayarken metin bir an bile başka türlü dizilmez (genişlik sabit).
    final painter = TextPainter(
      text: TextSpan(text: next, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final slots = <(int, double, double)>[];
    for (var i = 0; i < next.length; i++) {
      final before = i < previous.length ? previous[i] : '';
      if (before == next[i]) continue;
      final left = painter.getOffsetForCaret(TextPosition(offset: i), .zero).dx;
      final right = i + 1 < next.length
          ? painter.getOffsetForCaret(TextPosition(offset: i + 1), .zero).dx
          : painter.width;
      slots.add((i, left, right - left));
    }
    final height = painter.height;
    painter.dispose();
    final total = _motion.duration!.inMicroseconds;
    return Semantics(
      label: next,
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Değişen karakterler yerinde saydam durur; üstlerinde kayarlar.
          Text.rich(
            TextSpan(
              children: [
                for (var i = 0; i < next.length; i++)
                  TextSpan(
                    text: next[i],
                    style: slots.any((slot) => slot.$1 == i)
                        ? const TextStyle(color: Colors.transparent)
                        : null,
                  ),
              ],
            ),
            style: widget.style,
          ),
          for (final (i, left, width) in slots)
            Positioned(
              left: left,
              top: 0,
              width: width,
              height: height,
              child: AnimatedBuilder(
                animation: _motion,
                builder: (context, _) => _slot(
                  before: i < previous.length ? previous[i] : '',
                  after: next[i],
                  t: Interval(
                    (KkRollingText.stagger * i).inMicroseconds / total,
                    (KkRollingText.stagger * i + KkMotion.base).inMicroseconds /
                        total,
                    curve: KkMotion.standard,
                  ).transform(_motion.value),
                  travel: (style.fontSize ?? 14) * 0.8,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _slot({
    required String before,
    required String after,
    required double t,
    required double travel,
  }) {
    return ClipRect(
      child: Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          if (before.isNotEmpty)
            Opacity(
              opacity: 1 - t,
              child: Transform.translate(
                offset: Offset(0, -travel * t),
                child: Text(before, style: widget.style, softWrap: false),
              ),
            ),
          Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, travel * (1 - t)),
              child: Text(after, style: widget.style, softWrap: false),
            ),
          ),
        ],
      ),
    );
  }
}

/// Yeni değerde kısa süre karışan metin (madde 3.2, üretici): [duration]
/// boyunca gerçek değerle aynı uzunlukta rastgele süs karakterler görünür,
/// sonra gerçek değer. Süs karakterler gerçek parola değildir; ekran
/// okuyucuya gitmez, ekran okuyucu hep gerçek değeri okur. İlk kurulumda ve
/// animasyonlar kapalıyken karışmaz.
///
/// Yalnızca [trigger] değişince ve [enabled] önce de sonra da açıkken
/// karışır; böylece gizle/göster gibi aynı değerin yeniden çizilmesi
/// karıştırmaz. [trigger] verilmezse metnin kendisidir.
class KkScrambleText extends StatefulWidget {
  const new({
    required this.text,
    this.style,
    this.textKey,
    this.trigger,
    this.enabled = true,
    super.key,
  });

  static const Duration duration = KkMotion.scramble;

  final String text;
  final TextStyle? style;

  /// İçteki [Text]'in anahtarı (testler için).
  final Key? textKey;

  /// Değişince karışma başlar (ör. üretilen parola).
  final Object? trigger;

  /// Kapalıyken (ör. değer gizliyken) karışmaz.
  final bool enabled;

  @override
  State<KkScrambleText> createState() => _KkScrambleTextState();
}

class _KkScrambleTextState extends State<KkScrambleText>
    with SingleTickerProviderStateMixin {
  static const _decoys =
      'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#%&*?';

  // Yalnızca süs için; parola üretimi güvenli kaynağı kullanır.
  final _random = math.Random();
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: KkScrambleText.duration,
  );

  @override
  void didUpdateWidget(KkScrambleText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final trigger = widget.trigger ?? widget.text;
    final oldTrigger = oldWidget.trigger ?? oldWidget.text;
    if (trigger == oldTrigger && widget.enabled == oldWidget.enabled) return;
    if (trigger == oldTrigger ||
        !widget.enabled ||
        !oldWidget.enabled ||
        widget.text.isEmpty ||
        MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      return;
    }
    _motion.forward(from: 0);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  String _decoy() => String.fromCharCodes([
    for (final unit in widget.text.runes)
      // Boşluk ve ayraçlar yerinde kalır; sözcük parolası şeklini korur.
      if (unit == 0x20 || unit == 0x2D)
        unit
      else
        _decoys.codeUnitAt(_random.nextInt(_decoys.length)),
  ]);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) => Text(
          _motion.isAnimating ? _decoy() : widget.text,
          key: widget.textKey,
          style: widget.style,
        ),
      ),
    );
  }
}

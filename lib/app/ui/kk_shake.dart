import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keykey/app/ui/kk_motion.dart';

/// [KkShake]'leri tetikler: hatalı alanlar ve yanlış ana parola. Telefon
/// her tetiklemede bir kez hafifçe titreşir (madde 2.5), kaç alan titrerse
/// titresin.
class KkShakeController extends ChangeNotifier {
  /// Bağlı ve etkin bütün [KkShake]'ler titrer.
  void shake() {
    unawaited(HapticFeedback.mediumImpact());
    notifyListeners();
  }
}

/// Hatada kutunun titremesi (madde 2.4): üç kısa salınım, ±8 dp'den sıfıra,
/// [KkMotion.shake] boyunca. "Animasyonları kaldır" açıkken kutu kıpırdamaz;
/// titreşim denetleyiciden gelir ve kalır.
/// [enabled] yanlışsa (alanda hata yoksa) hiçbir şey olmaz.
class KkShake extends StatefulWidget {
  const new({
    required this.controller,
    required this.child,
    this.enabled = true,
    super.key,
  });

  /// En büyük sapma.
  static const double amplitude = 8;

  final KkShakeController controller;
  final bool enabled;
  final Widget child;

  @override
  State<KkShake> createState() => _KkShakeState();
}

class _KkShakeState extends State<KkShake> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: KkMotion.shake,
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onShake);
  }

  @override
  void didUpdateWidget(KkShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onShake);
      widget.controller.addListener(_onShake);
    }
  }

  void _onShake() {
    if (!widget.enabled || !mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _motion.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onShake);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _motion,
      // Sönen bir sinüs: üç salınım, 8 dp'den sıfıra.
      builder: (context, child) {
        final t = _motion.value;
        final dx = t == 0 || t == 1
            ? 0.0
            : math.sin(t * math.pi * 6) * KkShake.amplitude * (1 - t);
        return Transform(
          transform: Matrix4.translationValues(dx, 0, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

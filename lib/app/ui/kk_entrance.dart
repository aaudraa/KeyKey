import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_motion.dart';

/// Ekran ilk açıldığında görünen öğelerin kısa bir sırayla belirmesini
/// sağlayan kapsam. Kapsamın ilk karesinde kurulan [KkEntrance]'lar belirir;
/// sonradan kurulanlar (kaydırınca gelenler) hareketsizdir.
class KkEntranceScope extends StatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  State<KkEntranceScope> createState() => _KkEntranceScopeState();
}

class _KkEntranceScopeState extends State<KkEntranceScope> {
  final _gate = _EntranceGate();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _gate.open = false);
  }

  @override
  Widget build(BuildContext context) =>
      _EntranceInherited(gate: _gate, child: widget.child);
}

class _EntranceGate {
  bool open = true;
}

class _EntranceInherited extends InheritedWidget {
  const new({required this.gate, required super.child});

  final _EntranceGate gate;

  @override
  bool updateShouldNotify(_EntranceInherited old) => false;
}

/// Liste öğesi: saydamlık 0'dan 1'e ve 12 dp aşağıdan yerine. İlk karede
/// kurulan bütün öğeler hareket eder; sıradaki her öğe 40 ms sonra başlar,
/// gecikme sekizinci öğede durur (sonrakiler onunla birlikte gelir).
class KkEntrance extends StatefulWidget {
  const new({required this.index, required this.child, super.key});

  /// Gecikmenin büyüdüğü öğe sayısı.
  static const int maxStaggered = 8;
  static const Duration step = Duration(milliseconds: 40);

  final int index;
  final Widget child;

  @override
  State<KkEntrance> createState() => _KkEntranceState();
}

class _KkEntranceState extends State<KkEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _progress;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final gate = context
        .getInheritedWidgetOfExactType<_EntranceInherited>()
        ?.gate;
    final animate =
        gate != null && gate.open && !MediaQuery.disableAnimationsOf(context);
    final delay =
        KkEntrance.step * math.min(widget.index, KkEntrance.maxStaggered);
    final total = delay + KkMotion.base;
    final controller = AnimationController(
      vsync: this,
      duration: total,
      value: animate ? 0 : 1,
    );
    _controller = controller;
    _progress = CurvedAnimation(
      parent: controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
    );
    if (animate) controller.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _progress,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 12 * (1 - _progress.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

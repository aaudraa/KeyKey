import 'dart:async';

import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/app/ui/kk_pressable.dart';

/// Kopyala düğmesi (madde 2.1): kopyalanınca simge ölçek ve solmayla onay
/// işaretine döner, [hold] sonra geri gelir. Onay görünürken yeniden basmak
/// yeniden kopyalar ve süreyi baştan başlatır.
class KkCopyIcon extends StatefulWidget {
  const new({
    required this.tooltip,
    required this.onCopy,
    this.color,
    super.key,
  });

  /// Onay işaretinin ekranda kalma süresi.
  static const Duration hold = KkMotion.copyHold;

  final String tooltip;

  /// Kopyalar; kopyalandıysa `true` (kasa kilitliyse `false`).
  final Future<bool> Function()? onCopy;
  final Color? color;

  @override
  State<KkCopyIcon> createState() => _KkCopyIconState();
}

class _KkCopyIconState extends State<KkCopyIcon> {
  bool _done = false;
  Timer? _timer;

  Future<void> _copy() async {
    final copied = await widget.onCopy!();
    if (!mounted || !copied) return;
    _timer?.cancel();
    setState(() => _done = true);
    _timer = Timer(KkCopyIcon.hold, () {
      if (mounted) setState(() => _done = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KkPressable(
      pressedScale: KkPressable.smallScale,
      child: IconButton(
        tooltip: widget.tooltip,
        onPressed: widget.onCopy == null ? null : () => unawaited(_copy()),
        icon: AnimatedSwitcher(
          duration: KkMotion.of(context, KkMotion.fast),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: Icon(
            _done ? Icons.check_rounded : Icons.copy_rounded,
            key: ValueKey(_done),
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

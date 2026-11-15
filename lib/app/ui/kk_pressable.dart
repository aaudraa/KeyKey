import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:keykey/app/ui/kk_motion.dart';

/// Basınca esneyen sarmalayıcı (madde 1.3): parmak değince içerik
/// [pressedScale]'e küçülür, kalkınca yaylanarak döner. Dokunuşu yutmaz;
/// içteki düğme ya da `InkWell` çalışmaya devam eder. Parmak kaydırma
/// mesafesini aşınca (liste kayıyor) esneme bırakılır.
class KkPressable extends StatefulWidget {
  const new({required this.child, this.pressedScale = cardScale, super.key});

  /// Kart ve satırlar.
  static const double cardScale = 0.965;

  /// Küçük düğme ve simgeler.
  static const double smallScale = 0.88;

  final Widget child;
  final double pressedScale;

  @override
  State<KkPressable> createState() => _KkPressableState();
}

class _KkPressableState extends State<KkPressable> {
  bool _pressed = false;
  Offset? _down;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        _down = e.position;
        _set(true);
      },
      onPointerMove: (e) {
        final down = _down;
        if (down != null && (e.position - down).distance > kTouchSlop) {
          _set(false);
        }
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: KkMotion.of(context, KkMotion.fast),
        curve: KkMotion.spring,
        child: widget.child,
      ),
    );
  }
}

/// Ekran açılırken alttan [rise] dp yaylanarak yerine gelen öğe (madde 1.2:
/// alt menü ve alttaki ana düğme). Yalnızca ilk kurulumda oynar.
class KkRiseIn extends StatefulWidget {
  const new({
    required this.child,
    this.rise = defaultRise,
    this.fade = false,
    super.key,
  });

  static const double defaultRise = 24;

  /// Başlangıçta ne kadar aşağıda.
  final double rise;

  /// `true` ise yükselirken saydamdan belirir de.
  final bool fade;

  final Widget child;

  @override
  State<KkRiseIn> createState() => _KkRiseInState();
}

class _KkRiseInState extends State<KkRiseIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: KkMotion.enter,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final moved = Transform(
          transform: Matrix4.translationValues(
            0,
            widget.rise * (1 - KkMotion.spring.transform(_controller.value)),
            0,
          ),
          child: child,
        );
        return widget.fade
            ? Opacity(
                opacity: KkMotion.standard.transform(_controller.value),
                child: moved,
              )
            : moved;
      },
      child: widget.child,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:keykey/app/ui/keykey_logo.dart';
import 'package:keykey/app/ui/kk_motion.dart';

/// Kilit açılışı (madde 4.3): kasa altta hazır çizilir ve dokunulabilir;
/// üstünde kilit ekranının K logosu [KkMotion.emphasis] boyunca yukarı
/// çekilip küçülür ve solar, sonra katman ağaçtan kalkar. Kartlar kendi
/// giriş hareketleriyle alttan yükselir. Animasyonlar kapalıyken hiç
/// çizilmez.
class KkUnlockReveal extends StatefulWidget {
  const new({this.contentKey, super.key});

  /// Logo katmanının anahtarı (testler için).
  final Key? contentKey;

  /// Logonun yukarı çekilme payı ve son ölçeği.
  static const double lift = 48;
  static const double endScale = 0.7;

  @override
  State<KkUnlockReveal> createState() => _KkUnlockRevealState();
}

class _KkUnlockRevealState extends State<KkUnlockReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion =
      AnimationController(vsync: this, duration: KkMotion.emphasis)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) setState(() {});
        });
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
    } else {
      _motion.forward();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_motion.isCompleted) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          key: widget.contentKey,
          animation: _motion,
          builder: (context, child) {
            final t = KkMotion.standard.transform(_motion.value);
            return Opacity(
              opacity: 1 - t,
              child: Transform.translate(
                offset: Offset(0, -KkUnlockReveal.lift * t),
                child: Transform.scale(
                  scale: 1 - (1 - KkUnlockReveal.endScale) * t,
                  child: child,
                ),
              ),
            );
          },
          child: const Center(child: KeyKeyLogo(size: 88)),
        ),
      ),
    );
  }
}

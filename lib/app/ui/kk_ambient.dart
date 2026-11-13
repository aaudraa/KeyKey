import 'package:flutter/widgets.dart';

/// Süren hareketlerin (kayan zemin, süzülen logo, nabız) açık olup
/// olmadığı. Uygulama bunu `ambientMotionProvider`'dan kurar; atada yoksa
/// kapalıdır, böylece testler ve otomatik doldurma penceresi kare
/// beklemeden biter.
class KkAmbient extends InheritedWidget {
  const new({required this.enabled, required super.child, super.key});

  final bool enabled;

  /// Süren hareket açık mı? "Animasyonları kaldır" açıkken her zaman kapalı.
  static bool of(BuildContext context) {
    final enabled =
        context.dependOnInheritedWidgetOfExactType<KkAmbient>()?.enabled ??
        false;
    return enabled && !MediaQuery.disableAnimationsOf(context);
  }

  @override
  bool updateShouldNotify(KkAmbient old) => old.enabled != enabled;
}

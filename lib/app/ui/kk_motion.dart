import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hareketlerin ortak süreleri ve eğrisi (`resources/docs/tasarim-cam.md`,
/// "Hareket").
abstract final class KkMotion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 250);
  static const panelOpen = Duration(milliseconds: 400);
  static const panelClose = Duration(milliseconds: 200);

  /// Hafifçe hedefi geçip yerine oturan yay eğrisi.
  static const Curve spring = Cubic(0.2, 1.35, 0.4, 1);

  /// Telefonda "animasyonları kaldır" açıksa sıfır, değilse [duration].
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// Sürekli hareketleri (kilit ekranındaki kayan lekeler, süzülen simge)
/// açar. Testler kare beklemeden bitsin diye `false` verir.
final ambientMotionProvider = Provider<bool>((_) => true);

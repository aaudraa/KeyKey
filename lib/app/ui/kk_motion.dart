import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hareketlerin ortak süreleri ve eğrileri
/// (`resources/docs/tasarim-siyah-beyaz.md`, "Ortak değerler"). Ekranlar
/// süre ya da eğri yazmaz; bir tarama testi bunu denetler.
abstract final class KkMotion {
  /// Basma, simge değişimi.
  static const fast = Duration(milliseconds: 150);

  /// Solma, kayma, anahtar.
  static const base = Duration(milliseconds: 250);

  /// Öğe girişi, ekran geçişi.
  static const enter = Duration(milliseconds: 350);

  /// Kutu ve pencerelerin açılışı ve kapanışı.
  static const panelOpen = Duration(milliseconds: 400);
  static const panelClose = Duration(milliseconds: 200);

  /// Kilit açılışı, kaydetme onayı.
  static const emphasis = Duration(milliseconds: 450);

  /// Sıradaki öğeler arası gecikme; gecikme [staggerMax]. öğede durur.
  static const stagger = Duration(milliseconds: 40);
  static const staggerMax = 8;

  /// Kopyala simgesinin onay işareti olarak kaldığı süre.
  static const copyHold = Duration(seconds: 1);

  /// Son kaydedilen kartın parlamak için beklediği en uzun süre; kart bu
  /// sürede ekrana gelmezse parlamaz.
  static const savedFlashWindow = Duration(seconds: 3);

  /// Hatada kutunun titremesi (üç salınım).
  static const shake = Duration(milliseconds: 300);

  /// Parola göster/gizle: karakter başına adım, toplamda en çok
  /// [secretMax] (madde 3.1).
  static const secretPerChar = Duration(milliseconds: 12);
  static const secretMax = Duration(milliseconds: 300);

  /// Üretilen parolanın süs karakterlerle karışma süresi (madde 3.2).
  static const scramble = Duration(milliseconds: 250);

  /// 2FA kodunda değişen rakamlar arası gecikme (madde 3.4).
  static const rollStagger = Duration(milliseconds: 20);

  /// Süren hareketler: kilit ekranında lekelerin ve logonun döngüsü,
  /// diğer ekranlarda daha sakin kayan zemin.
  static const drift = Duration(seconds: 24);
  static const calmDrift = Duration(seconds: 36);
  static const float = Duration(seconds: 3);

  /// Kilit ekranında parmak izi simgesinin bir nefesi (madde 4.2).
  static const breath = Duration(milliseconds: 2400);

  /// Hafifçe hedefi geçip yerine oturan yay eğrisi.
  static const Curve spring = Cubic(0.2, 1.35, 0.4, 1);

  /// Kayma ve solma.
  static const Curve standard = Curves.easeOutCubic;

  /// Çıkışlar.
  static const Curve exit = Curves.easeInCubic;

  /// Telefonda "animasyonları kaldır" açıksa sıfır, değilse [duration].
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// Sürekli hareketleri (kilit ekranındaki kayan lekeler, süzülen simge)
/// açar. Testler kare beklemeden bitsin diye `false` verir.
final ambientMotionProvider = Provider<bool>((_) => true);

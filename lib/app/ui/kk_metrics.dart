/// Siyah-beyaz tasarımın ölçüleri (dp ve sp). Değerler
/// `resources/docs/tasarim-siyah-beyaz.md` belgesinin "Ölçüler" tablosunda.
/// Küçülen görünüştür; dokunma alanı hiçbir yerde [minTouch]'ın altına inmez.
abstract final class KkMetrics {
  /// Sekmelerin kök ekran başlığı ("Kasa").
  static const double rootTitle = 22;

  /// Alt ekranların başlığı.
  static const double subTitle = 17;

  /// Sekmelerin listeyle birlikte kayan büyük başlığı.
  static const double largeTitle = 26;

  /// Listelerdeki kartın normal yazıdaki boyu. Telefon denemesi 4'te küçük
  /// kartlar okunaksız geldi; cam turundaki boylara dönüldü.
  static const double cardHeight = 64;
  static const double cardTitle = 15;
  static const double cardSubtitle = 12.5;

  /// Ayar satırının normal yazıdaki boyu.
  static const double rowHeight = 56;
  static const double rowTitle = 14.5;
  static const double rowSubtitle = 12.5;

  /// Form alanının boyu. Etiket kutunun içinde durduğu için (telefon
  /// denemesi 5) belgedeki 52-54'ten büyük.
  static const double fieldHeight = 60;

  /// Ana düğmenin görünen boyu ve köşesi.
  static const double buttonHeight = 44;
  static const double buttonRadius = 14;

  /// Kart, ayar grubu ve form alanının köşesi.
  static const double cardRadius = 16;

  /// Alt menünün boyu, sekme kapsülünün boyu ve "+" dairesi.
  static const double navHeight = 52;
  static const double navTab = 40;
  static const double addSize = 40;

  /// Kayıt simgesi.
  static const double avatar = 40;

  /// Geri oku gibi cam daire düğmeler.
  static const double circleButton = 40;

  /// En küçük dokunma alanı.
  static const double minTouch = 48;

  /// En küçük yazı.
  static const double minFont = 11;
}

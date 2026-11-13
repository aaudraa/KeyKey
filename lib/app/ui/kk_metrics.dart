/// Siyah-beyaz tasarımın ölçüleri (dp ve sp). Değerler
/// `resources/docs/tasarim-siyah-beyaz.md` belgesinin "Ölçüler" tablosunda.
/// Küçülen görünüştür; dokunma alanı hiçbir yerde [minTouch]'ın altına inmez.
abstract final class KkMetrics {
  /// Sekmelerin kök ekran başlığı ("Kasa").
  static const double rootTitle = 22;

  /// Alt ekranların başlığı.
  static const double subTitle = 17;

  /// Listelerdeki kartın normal yazıdaki boyu.
  static const double cardHeight = 54;
  static const double cardTitle = 13.5;
  static const double cardSubtitle = 11.5;

  /// Ayar satırının normal yazıdaki boyu.
  /// Belgede 46; satırın kendisi dokunma alanı olduğu için 48 dp kuralına
  /// uyar.
  static const double rowHeight = 48;
  static const double rowTitle = 13;
  static const double rowSubtitle = 11.5;

  /// Form alanının boyu.
  static const double fieldHeight = 52;

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
  static const double avatar = 34;

  /// Geri oku gibi cam daire düğmeler.
  static const double circleButton = 40;

  /// En küçük dokunma alanı.
  static const double minTouch = 48;

  /// En küçük yazı.
  static const double minFont = 11;
}

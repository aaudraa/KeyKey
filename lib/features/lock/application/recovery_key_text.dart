import 'package:keykey/core/crypto/recovery_key.dart';

/// Kurtarma anahtarı metninin ekranlarda gereken biçim kuralları: sembol
/// sayma, grup uzunluğu ve karakter düzeltme. Ekranlar kripto katmanına
/// doğrudan bağlanmasın diye [RecoveryKeyCodec]'e buradan ulaşılır.
abstract final class RecoveryKeyText {
  /// Anahtarın tireler olmadan sembol sayısı.
  static const int textLength = RecoveryKeyCodec.textLength;

  /// Bir gruptaki sembol sayısı.
  static const int groupLength = RecoveryKeyCodec.groupLength;

  /// Metindeki geçerli semboller, düzeltilmiş ve büyük harfli.
  static String symbolsOf(String text) => RecoveryKeyCodec.symbolsOf(text);

  /// Tek bir karakterin düzeltilmiş hali (benzer görünen harfler).
  static String normalize(String character) =>
      RecoveryKeyCodec.normalize(character);
}

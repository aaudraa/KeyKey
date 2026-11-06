import 'package:keykey/app/grouped_text_formatter.dart';

/// 2FA gizli anahtarını yazarken büyük harfe çevirir ve dörderli gruplar.
///
/// Servisler anahtarı çoğunlukla `abcd efgh ...` diye gösterir; aynı düzen,
/// elle yazarken atlanan veya fazla yazılan karakteri görmeyi kolaylaştırır.
/// Boşluk ve tire yok sayılır, `Base32.decodeLenient` de onları atar.
/// Türkçe klavyenin ı ve İ harfleri I olarak yazılır.
///
/// Metinde harf, rakam, boşluk, tire ve `=` dışında karakter varsa metne
/// dokunulmaz. Böylece yapıştırılan `otpauth://` bağlantısı bozulmaz.
class SecretKeyFormatter extends GroupedTextFormatter {
  new()
    : super(
        groupLength: 4,
        separator: ' ',
        allowed: RegExp(r'^[A-Za-z0-9ıİ \t=-]*$'),
        normalize: _normalize,
      );

  /// [text]'i gruplanmış biçimde döndürür. Bağlantı gibi anahtar olmayan
  /// metni olduğu gibi bırakır.
  static String group(String text) => SecretKeyFormatter().format(text);

  // Türkçe klavyenin ı ve İ harfleri anahtardaki I harfidir.
  static String _normalize(String character) =>
      character == 'ı' || character == 'İ' ? 'I' : character.toUpperCase();
}

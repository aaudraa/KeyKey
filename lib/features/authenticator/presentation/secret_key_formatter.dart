import 'package:flutter/services.dart';

/// 2FA gizli anahtarını yazarken büyük harfe çevirir ve dörderli gruplar.
///
/// Servisler anahtarı çoğunlukla `abcd efgh ...` diye gösterir; aynı düzen,
/// elle yazarken atlanan veya fazla yazılan karakteri görmeyi kolaylaştırır.
/// Boşluk ve tire yok sayılır, `Base32.decodeLenient` de onları atar.
/// Türkçe klavyenin ı ve İ harfleri I olarak yazılır.
///
/// Metinde harf, rakam, boşluk, tire ve `=` dışında karakter varsa metne
/// dokunulmaz. Böylece yapıştırılan `otpauth://` bağlantısı bozulmaz.
class SecretKeyFormatter extends TextInputFormatter {
  static final _plain = RegExp(r'^[A-Za-z0-9ıİ \t=-]*$');

  /// [text]'i gruplanmış biçimde döndürür. Bağlantı gibi anahtar olmayan
  /// metni olduğu gibi bırakır.
  static String group(String text) =>
      _plain.hasMatch(text) ? _format(text, text.length).$1 : text;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (!_plain.hasMatch(text)) return newValue;
    final cursor = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, text.length)
        : text.length;
    final (formatted, offset) = _format(text, cursor);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  /// Gruplanmış metni ve [cursor]'ın yeni yerini döndürür.
  static (String, int) _format(String text, int cursor) {
    final out = StringBuffer();
    var count = 0;
    var before = 0;
    for (var i = 0; i < text.length; i++) {
      final character = text[i];
      if (character == ' ' || character == '\t' || character == '-') continue;
      if (count > 0 && count % 4 == 0) out.write(' ');
      // Türkçe klavyenin ı ve İ harfleri anahtardaki I harfidir.
      out.write(
        character == 'ı' || character == 'İ' ? 'I' : character.toUpperCase(),
      );
      count++;
      if (i < cursor) before++;
    }
    // İmleç, önündeki anlamlı karakter sayısı korunarak yerleşir.
    final offset = before == 0 ? 0 : before + (before - 1) ~/ 4;
    return (out.toString(), offset);
  }
}

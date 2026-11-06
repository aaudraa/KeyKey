import 'package:flutter/services.dart';

/// Elle yazılan uzun anahtarları gruplar halinde gösterir.
///
/// Boşluk, sekme ve tire yok sayılır; kalan karakterler [normalize] ile
/// çevrilir ve her [groupLength] karakterde bir [separator] konur. İmleç,
/// önündeki anlamlı karakter sayısı korunarak yerleşir.
///
/// Metin [allowed] ile eşleşmiyorsa dokunulmaz. Böylece yapıştırılan bağlantı
/// gibi başka bir metin bozulmaz.
class GroupedTextFormatter extends TextInputFormatter {
  const new({
    required this.groupLength,
    required this.separator,
    required this.allowed,
    required this.normalize,
  });

  final int groupLength;
  final String separator;
  final RegExp allowed;
  final String Function(String character) normalize;

  /// [text]'i gruplanmış biçimde döndürür, eşleşmeyen metni olduğu gibi.
  String format(String text) =>
      allowed.hasMatch(text) ? _format(text, text.length).$1 : text;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (!allowed.hasMatch(text)) return newValue;
    final cursor = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, text.length)
        : text.length;
    final (formatted, offset) = _format(text, cursor);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  (String, int) _format(String text, int cursor) {
    final out = StringBuffer();
    var count = 0;
    var before = 0;
    for (var i = 0; i < text.length; i++) {
      final character = text[i];
      if (character == ' ' || character == '\t' || character == '-') continue;
      if (count > 0 && count % groupLength == 0) out.write(separator);
      out.write(normalize(character));
      count++;
      if (i < cursor) before++;
    }
    final offset = before == 0
        ? 0
        : before + (before - 1) ~/ groupLength * separator.length;
    return (out.toString(), offset);
  }
}

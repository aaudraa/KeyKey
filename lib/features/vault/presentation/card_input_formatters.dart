import 'package:flutter/services.dart';
import 'package:keykey/features/vault/data/card_number.dart';

/// Rakamları ve imleçten önceki rakam sayısını çıkarır.
(String, int) _digitsBefore(TextEditingValue value, int max) {
  final text = value.text;
  final cursor = value.selection.isValid
      ? value.selection.extentOffset.clamp(0, text.length)
      : text.length;
  final digits = StringBuffer();
  var before = 0;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit < 0x30 || unit > 0x39) continue;
    if (digits.length == max) break;
    digits.writeCharCode(unit);
    if (i < cursor) before++;
  }
  return (digits.toString(), before);
}

/// İmleci, önündeki [digits] rakamdan sonraya koyar.
int _offsetAfterDigits(String formatted, int digits) {
  if (digits == 0) return 0;
  var seen = 0;
  for (var i = 0; i < formatted.length; i++) {
    final unit = formatted.codeUnitAt(i);
    if (unit >= 0x30 && unit <= 0x39) {
      seen++;
      if (seen == digits) return i + 1;
    }
  }
  return formatted.length;
}

/// Kart numarasını yazarken markasına göre gruplar.
///
/// Rakam dışı her şey atılır, en çok 19 rakam kalır; yapıştırılan boşluklu
/// ya da tireli numara da gruplanır.
class CardNumberInputFormatter extends TextInputFormatter {
  const new();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final (digits, before) = _digitsBefore(newValue, maxCardNumberDigits);
    final formatted = groupCardNumber(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: _offsetAfterDigits(formatted, before),
      ),
    );
  }
}

/// Son kullanmayı `AA/YY` biçiminde yazar: en çok dört rakam, ikinci
/// rakamdan sonra eğik çizgi.
class ExpiryInputFormatter extends TextInputFormatter {
  const new();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final (digits, before) = _digitsBefore(newValue, 4);
    final formatted = digits.length > 2
        ? '${digits.substring(0, 2)}/${digits.substring(2)}'
        : digits;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: _offsetAfterDigits(formatted, before),
      ),
    );
  }
}

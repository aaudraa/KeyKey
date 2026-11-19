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

int _digitCount(String text) {
  var count = 0;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit >= 0x30 && unit <= 0x39) count++;
  }
  return count;
}

/// Kutu zaten doluyken araya yazılan rakam reddedilir; yoksa sondaki rakam
/// sessizce silinirdi. Bir seçimin yerine yapıştırma boş kutudaki gibi
/// işlenir.
bool _overflowsFull(
  TextEditingValue oldValue,
  TextEditingValue newValue,
  int max,
) =>
    oldValue.selection.isCollapsed &&
    _digitCount(newValue.text) > max &&
    _digitCount(oldValue.text) >= max;

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
    if (_overflowsFull(oldValue, newValue, maxCardNumberDigits)) {
      return oldValue;
    }
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
/// rakamdan sonra eğik çizgi. Dört haneli yılla yapıştırılan tarih
/// ("12/2030") kısaltılır.
class ExpiryInputFormatter extends TextInputFormatter {
  const new();

  static final _fullYear = RegExp(r'^\s*([0-9]{1,2})\s*/\s*([0-9]{4})\s*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final pasted = _fullYear.firstMatch(newValue.text);
    if (pasted != null) {
      final text =
          '${pasted.group(1)!.padLeft(2, '0')}/${pasted.group(2)!.substring(2)}';
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    if (_overflowsFull(oldValue, newValue, 4)) return oldValue;
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

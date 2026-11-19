import 'package:flutter/foundation.dart' show immutable;

/// Kart markası. Saklanmaz, her gösterimde numaranın ilk hanelerinden
/// çıkarılır.
enum CardBrand {
  visa('Visa'),
  mastercard('Mastercard'),
  amex('American Express'),
  troy('Troy'),
  discover('Discover'),
  jcb('JCB'),
  unionPay('UnionPay'),
  maestro('Maestro'),
  diners('Diners Club');

  new(this.label);

  /// Arayüzde gösterilen ad. Logo kullanılmaz.
  final String label;
}

/// Önek aralığı: numaranın ilk `length` hanesi `from` ile `to` arasında.
typedef _Range = ({int length, int from, int to, CardBrand brand});

_Range _r(int from, int to, CardBrand brand) =>
    (length: from.toString().length, from: from, to: to, brand: brand);

/// En uzun önek önce denenir: Discover'ın 622126-622925 aralığı UnionPay'in
/// 62'sinden, Troy'un 9792'si ve Maestro'nun dörtlüleri diğerlerinden önce.
final List<_Range> _ranges = [
  _r(622126, 622925, CardBrand.discover),
  _r(9792, 9792, CardBrand.troy),
  _r(6011, 6011, CardBrand.discover),
  for (final prefix in [5018, 5020, 5038, 5893, 6304, 6759, 6761, 6762, 6763])
    _r(prefix, prefix, CardBrand.maestro),
  _r(2221, 2720, CardBrand.mastercard),
  _r(3528, 3589, CardBrand.jcb),
  _r(3095, 3095, CardBrand.diners),
  _r(644, 649, CardBrand.discover),
  _r(300, 305, CardBrand.diners),
  _r(65, 65, CardBrand.discover),
  _r(62, 62, CardBrand.unionPay),
  _r(81, 81, CardBrand.unionPay),
  _r(51, 55, CardBrand.mastercard),
  _r(34, 34, CardBrand.amex),
  _r(37, 37, CardBrand.amex),
  _r(36, 36, CardBrand.diners),
  _r(38, 39, CardBrand.diners),
  _r(4, 4, CardBrand.visa),
]..sort((a, b) => b.length.compareTo(a.length));

/// [digits] yalnızca rakamdan oluşan numaradır; tanınmazsa `null`.
CardBrand? detectCardBrand(String digits) {
  for (final range in _ranges) {
    if (digits.length < range.length) continue;
    final prefix = int.tryParse(digits.substring(0, range.length));
    if (prefix != null && prefix >= range.from && prefix <= range.to) {
      return range.brand;
    }
  }
  return null;
}

/// Luhn denetimi. Boş numara geçmez.
bool passesLuhn(String digits) {
  if (digits.isEmpty) return false;
  var sum = 0;
  var doubled = false;
  for (var i = digits.length - 1; i >= 0; i--) {
    final digit = digits.codeUnitAt(i) - 0x30;
    if (digit < 0 || digit > 9) return false;
    var value = digit;
    if (doubled) {
      value *= 2;
      if (value > 9) value -= 9;
    }
    sum += value;
    doubled = !doubled;
  }
  return sum % 10 == 0;
}

/// Numarayı markasına göre gruplar: American Express 4-6-5, 14 haneli
/// Diners 4-6-4, diğerleri dörtlü.
String groupCardNumber(String digits) {
  final brand = detectCardBrand(digits);
  final sizes = switch (brand) {
    CardBrand.amex => const [4, 6, 5],
    CardBrand.diners when digits.length <= 14 => const [4, 6, 4],
    _ => const <int>[],
  };
  final groups = <String>[];
  var start = 0;
  var index = 0;
  while (start < digits.length) {
    final size = index < sizes.length ? sizes[index] : 4;
    final end = (start + size).clamp(0, digits.length);
    groups.add(digits.substring(start, end));
    start = end;
    index++;
  }
  return groups.join(' ');
}

/// Son dört hane; numara daha kısaysa tamamı.
String lastFour(String digits) =>
    digits.length <= 4 ? digits : digits.substring(digits.length - 4);

/// En çok bu kadar hane saklanır.
const int maxCardNumberDigits = 19;

final _numberChars = RegExp(r'^[0-9 \-]*$');

/// Boşluk ve tireyi atar. Başka bir karakter varsa ya da 19 haneyi aşarsa
/// `null`.
String? normalizeCardNumber(String raw) {
  if (!_numberChars.hasMatch(raw)) return null;
  final digits = raw.replaceAll(RegExp('[ -]'), '');
  return digits.length > maxCardNumberDigits ? null : digits;
}

/// Kartın son kullanma ayı. Ayın sonunda geçer.
@immutable
final class CardExpiry {
  new({required this.month, required this.year}) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month');
    }
    if (year < minYear || year > maxYear) {
      throw ArgumentError.value(year, 'year');
    }
  }

  static const minYear = 2000;
  static const maxYear = 2099;

  final int month;
  final int year;

  static final _pattern = RegExp(r'^(\d{2})/(\d{2})$');

  /// `AA/YY` biçimindeki metni okur; yıl 2000'li yıllara çevrilir.
  static CardExpiry? tryParse(String text) {
    final match = _pattern.firstMatch(text.trim());
    if (match == null) return null;
    final month = int.parse(match.group(1)!);
    if (month < 1 || month > 12) return null;
    return CardExpiry(month: month, year: 2000 + int.parse(match.group(2)!));
  }

  /// [now] ayın son gününden sonraysa `true`.
  bool isExpiredAt(DateTime now) => !now.isBefore(DateTime(year, month + 1));

  /// `AA/YY`.
  String format() =>
      '${month.toString().padLeft(2, '0')}/'
      '${(year % 100).toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is CardExpiry && other.month == month && other.year == year;

  @override
  int get hashCode => Object.hash(month, year);
}

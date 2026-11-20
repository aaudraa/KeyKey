import 'dart:convert';
import 'dart:typed_data';

import 'package:keykey/features/vault/data/card_number.dart';
import 'package:keykey/features/vault/data/record_content.dart';

/// Kart kaydının şifreli içeriği. Biçim güvenlik tasarımı belgesinde.
final class CardContent implements VaultItemContent<CardContent> {
  /// Kurala uymayan numara, güvenlik kodu veya PIN [ArgumentError] fırlatır:
  /// okunamayacak bir kayıt yazılamaz.
  new({
    required this.name,
    this.cardholder = '',
    this.number = '',
    this.expiry,
    this.securityCode = '',
    this.pin = '',
    this.notes = '',
    this.favorite = false,
    this.folder,
    this.trashedAt,
  }) {
    if (!isValidNumber(number)) {
      throw ArgumentError('Geçersiz kart numarası.');
    }
    if (!isValidSecurityCode(securityCode)) {
      throw ArgumentError('Geçersiz güvenlik kodu.');
    }
    if (!isValidPin(pin)) throw ArgumentError('Geçersiz PIN.');
  }

  /// JSON baytlarını katı kurallarla okur.
  ///
  /// Bilinmeyen sürüm, eksik veya fazla alan, yanlış tür ya da kurala uymayan
  /// değer [InvalidRecordContentException] fırlatır.
  factory fromJsonBytes(Uint8List bytes) {
    final decoded = StrictJson.decode(bytes);
    final version = decoded is Map<String, Object?> ? decoded['version'] : null;
    if (version != currentVersion) {
      throw const InvalidRecordContentException('Desteklenmeyen sürüm.');
    }
    final root = StrictJson.object(decoded, _keys);
    final number = StrictJson.string(root['number'], 'number');
    final securityCode = StrictJson.string(
      root['securityCode'],
      'securityCode',
    );
    final pin = StrictJson.string(root['pin'], 'pin');
    if (!isValidNumber(number)) {
      throw const InvalidRecordContentException('Geçersiz alan: number');
    }
    if (!isValidSecurityCode(securityCode)) {
      throw const InvalidRecordContentException('Geçersiz alan: securityCode');
    }
    if (!isValidPin(pin)) {
      throw const InvalidRecordContentException('Geçersiz alan: pin');
    }
    return CardContent(
      name: StrictJson.string(root['name'], 'name'),
      cardholder: StrictJson.string(root['cardholder'], 'cardholder'),
      number: number,
      expiry: _expiry(root['expMonth'], root['expYear']),
      securityCode: securityCode,
      pin: pin,
      notes: StrictJson.string(root['notes'], 'notes'),
      favorite: StrictJson.boolean(root['favorite'], 'favorite'),
      folder: StrictJson.nullableString(root['folder'], 'folder'),
      trashedAt: StrictJson.nullableTime(root['trashedAt'], 'trashedAt'),
    );
  }

  static const currentVersion = 1;
  static const int maxNumberDigits = maxCardNumberDigits;
  static const maxSecurityCodeDigits = 4;
  static const maxPinDigits = 12;

  static const _keys = {
    'version',
    'name',
    'cardholder',
    'number',
    'expMonth',
    'expYear',
    'securityCode',
    'pin',
    'notes',
    'favorite',
    'folder',
    'trashedAt',
  };

  static final _digits = RegExp(r'^[0-9]*$');

  static bool _isDigits(String value, int max) =>
      value.length <= max && _digits.hasMatch(value);

  static bool isValidNumber(String value) => _isDigits(value, maxNumberDigits);

  static bool isValidSecurityCode(String value) =>
      _isDigits(value, maxSecurityCodeDigits);

  static bool isValidPin(String value) => _isDigits(value, maxPinDigits);

  @override
  final String name;
  final String cardholder;

  /// Yalnızca rakam, gruplanmadan.
  final String number;
  final CardExpiry? expiry;
  final String securityCode;
  final String pin;
  final String notes;
  @override
  final bool favorite;
  @override
  final String? folder;
  @override
  final DateTime? trashedAt;

  /// Numaradan çıkarılır, saklanmaz.
  CardBrand? get cardBrand => detectCardBrand(number);

  /// Listede görünen ad: ad boşsa marka ve son dört hane ("Visa •••• 4242"),
  /// numara da yoksa boş.
  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (number.isEmpty) return '';
    return [?cardBrand?.label, '•••• ${lastFour(number)}'].join(' ');
  }

  @override
  bool get isTrashed => trashedAt != null;

  @override
  Uint8List toJsonBytes() => utf8.encode(
    jsonEncode({
      'version': currentVersion,
      'name': name,
      'cardholder': cardholder,
      'number': number,
      'expMonth': expiry?.month,
      'expYear': expiry?.year,
      'securityCode': securityCode,
      'pin': pin,
      'notes': notes,
      'favorite': favorite,
      'folder': folder,
      'trashedAt': trashedAt?.millisecondsSinceEpoch,
    }),
  );

  /// [expiry], [folder] ve [trashedAt] verilmezse korunur, `null` verilirse
  /// temizlenir.
  CardContent copyWith({
    String? name,
    String? cardholder,
    String? number,
    Object? expiry = keepValue,
    String? securityCode,
    String? pin,
    String? notes,
    bool? favorite,
    Object? folder = keepValue,
    Object? trashedAt = keepValue,
  }) {
    return CardContent(
      name: name ?? this.name,
      cardholder: cardholder ?? this.cardholder,
      number: number ?? this.number,
      expiry: identical(expiry, keepValue)
          ? this.expiry
          : expiry as CardExpiry?,
      securityCode: securityCode ?? this.securityCode,
      pin: pin ?? this.pin,
      notes: notes ?? this.notes,
      favorite: favorite ?? this.favorite,
      folder: identical(folder, keepValue) ? this.folder : folder as String?,
      trashedAt: identical(trashedAt, keepValue)
          ? this.trashedAt
          : trashedAt as DateTime?,
    );
  }

  @override
  CardContent withFavorite({required bool favorite}) =>
      copyWith(favorite: favorite);

  @override
  CardContent withTrashedAt(DateTime? trashedAt) =>
      copyWith(trashedAt: trashedAt);

  @override
  CardContent withFolder(String? folder) => copyWith(folder: folder);

  static CardExpiry? _expiry(Object? month, Object? year) {
    final m = StrictJson.nullableInt(month, 'expMonth');
    final y = StrictJson.nullableInt(year, 'expYear');
    if (m == null && y == null) return null;
    if (m == null || y == null) {
      throw const InvalidRecordContentException('Geçersiz alan: expMonth');
    }
    if (m < 1 || m > 12 || y < CardExpiry.minYear || y > CardExpiry.maxYear) {
      throw const InvalidRecordContentException('Geçersiz alan: expMonth');
    }
    return CardExpiry(month: m, year: y);
  }
}

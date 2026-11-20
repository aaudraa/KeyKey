import 'dart:convert';
import 'dart:typed_data';

/// Kart ya da not kaydının içeriği bu sürümün okuyabileceği biçimde değil.
///
/// Mesajda alan değeri bulunmaz, yalnızca alan adı bulunabilir.
final class InvalidRecordContentException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => 'InvalidRecordContentException: $message';
}

/// Kasa listesinde parola kaydının yanında duran kayıt içerikleri (kart, not).
///
/// Favori, klasör ve çöp kutusu bilgisi de şifreli içeriktedir.
abstract interface class VaultItemContent<Self extends VaultItemContent<Self>> {
  String get name;
  bool get favorite;
  String? get folder;
  DateTime? get trashedAt;
  bool get isTrashed;

  /// Şifrelenecek JSON baytları.
  Uint8List toJsonBytes();

  Self withFavorite({required bool favorite});

  /// `null` kaydı çöp kutusundan çıkarır.
  Self withTrashedAt(DateTime? trashedAt);

  /// `null` kaydı klasörden çıkarır.
  Self withFolder(String? folder);
}

/// `copyWith` içinde "verilmedi" ile `null`'ı ayırmak için.
const Object keepValue = Object();

/// Kayıt içeriklerinin katı JSON okuyucusu.
///
/// Bilinmeyen, eksik veya yanlış türde alan [InvalidRecordContentException]
/// fırlatır. Kurallar parola kaydındakiyle aynıdır.
abstract final class StrictJson {
  static Object? decode(Uint8List bytes) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const InvalidRecordContentException('Geçersiz JSON.');
    }
  }

  /// Alanları tam olarak [keys] olan bir nesne bekler.
  static Map<String, Object?> object(Object? value, Set<String> keys) {
    if (value is! Map<String, Object?>) {
      throw const InvalidRecordContentException('Nesne bekleniyordu.');
    }
    if (value.length != keys.length || !keys.containsAll(value.keys)) {
      throw const InvalidRecordContentException('Eksik veya fazla alan.');
    }
    return value;
  }

  static String string(Object? value, String field) {
    if (value is String) return value;
    throw InvalidRecordContentException('Geçersiz alan: $field');
  }

  static String? nullableString(Object? value, String field) =>
      value == null ? null : string(value, field);

  static bool boolean(Object? value, String field) {
    if (value is bool) return value;
    throw InvalidRecordContentException('Geçersiz alan: $field');
  }

  static int? nullableInt(Object? value, String field) {
    if (value == null || value is int) return value as int?;
    throw InvalidRecordContentException('Geçersiz alan: $field');
  }

  static DateTime? nullableTime(Object? value, String field) {
    if (value == null) return null;
    // DateTime bu aralığın dışında RangeError fırlatır.
    if (value is int && value.abs() <= _maxMilliseconds) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    throw InvalidRecordContentException('Geçersiz alan: $field');
  }

  static const _maxMilliseconds = 8640000000000000;
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/authenticator/data/import/import_result.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';

/// Başka uygulamaların JSON dosyalarını okurken ortak yardımcılar.
///
/// Bu dosyalar bizim biçimimiz değil, sürümden sürüme alan ekleyebilirler.
/// Bu yüzden bilinmeyen alanlar yok sayılır; ama tür yanlışsa veya değer
/// kurallara uymuyorsa o hesap atlanır.
abstract final class ImportJson {
  /// Dışa aktarma dosyası bundan büyükse okunmaz.
  static const int maxFileSize = 10 * 1024 * 1024;

  static Map<String, Object?> decodeObject(Uint8List bytes) {
    if (bytes.length > maxFileSize) {
      throw const InvalidImportException('Dosya çok büyük.');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const InvalidImportException('Geçersiz JSON.');
    }
    if (decoded is! Map<String, Object?>) {
      throw const InvalidImportException('Nesne bekleniyordu.');
    }
    return decoded;
  }

  static Object? decode(Uint8List bytes) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const InvalidImportException('Geçersiz JSON.');
    }
  }

  static String string(Object? value) => value is String ? value : '';

  static int? integer(Object? value) => value is int ? value : null;

  static Map<String, Object?>? object(Object? value) =>
      value is Map<String, Object?> ? value : null;

  static Uint8List hex(Object? value) {
    // `int.tryParse` "+1" ve "-1" gibi değerleri de kabul ederdi.
    if (value is! String ||
        value.length.isOdd ||
        !RegExp(r'^[0-9a-fA-F]*$').hasMatch(value)) {
      throw const InvalidImportException('Geçersiz onaltılık değer.');
    }
    final bytes = Uint8List(value.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(value.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  static Uint8List base64Value(Object? value) {
    if (value is! String) {
      throw const InvalidImportException('Geçersiz Base64.');
    }
    try {
      return base64.decode(value.trim());
    } on FormatException {
      throw const InvalidImportException('Geçersiz Base64.');
    }
  }

  /// Hesabın kod bilgilerinden [OtpParameters] kurar. Desteklenmeyen veya
  /// bozuk değerde `null` döner, hesap atlanır.
  static OtpParameters? parameters({
    required String type,
    required Object? secret,
    required Object? algorithm,
    required Object? digits,
    required Object? period,
    required Object? counter,
  }) {
    if (secret is! String) return null;
    final Uint8List secretBytes;
    try {
      secretBytes = Base32.decodeLenient(secret);
    } on FormatException {
      return null;
    }
    if (!OtpParameters.isValidSecretLength(secretBytes.length)) return null;

    final algorithmValue = algorithm == null
        ? OtpAlgorithm.sha1
        : algorithm is String
        ? OtpAlgorithm.byLabel(algorithm.replaceAll('-', '').toUpperCase())
        : null;
    if (algorithmValue == null) return null;

    final digitsValue = digits == null
        ? OtpParameters.defaultDigits
        : integer(digits);
    if (digitsValue == null || !OtpParameters.isValidDigits(digitsValue)) {
      return null;
    }

    switch (type.toLowerCase()) {
      case 'totp':
        final periodValue = period == null
            ? OtpParameters.defaultPeriod
            : integer(period);
        if (periodValue == null || !OtpParameters.isValidPeriod(periodValue)) {
          return null;
        }
        return OtpParameters.totp(
          secret: secretBytes,
          algorithm: algorithmValue,
          digits: digitsValue,
          period: periodValue,
        );
      case 'hotp':
        final counterValue = counter == null ? 0 : integer(counter);
        if (counterValue == null ||
            !OtpParameters.isValidCounter(counterValue)) {
          return null;
        }
        return OtpParameters.hotp(
          secret: secretBytes,
          algorithm: algorithmValue,
          digits: digitsValue,
          counter: counterValue,
        );
      default:
        return null;
    }
  }
}

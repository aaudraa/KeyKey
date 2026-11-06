import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;

/// Zamana (TOTP, RFC 6238) veya sayaca (HOTP, RFC 4226) dayalı kod.
enum OtpKind {
  totp('totp'),
  hotp('hotp');

  new(this.label);

  /// Kayıtta ve `otpauth://` bağlantısında geçen ad.
  final String label;

  static OtpKind? byLabel(String label) {
    for (final kind in values) {
      if (kind.label == label) return kind;
    }
    return null;
  }
}

enum OtpAlgorithm {
  sha1('SHA1'),
  sha256('SHA256'),
  sha512('SHA512');

  new(this.label);

  /// Kayıtta ve `otpauth://` bağlantısında geçen ad.
  final String label;

  static OtpAlgorithm? byLabel(String label) {
    for (final algorithm in values) {
      if (algorithm.label == label) return algorithm;
    }
    return null;
  }
}

/// Bir 2FA hesabının kod üretmek için gereken bilgileri.
///
/// Kurucular değerleri denetler. Dışarıdan gelen veriyi okuyan katmanlar
/// önce [isValidSecretLength], [isValidDigits], [isValidPeriod] ve
/// [isValidCounter] ile kendi hatalarını üretmelidir; buradaki
/// [ArgumentError] bir programlama hatasını gösterir.
@immutable
final class OtpParameters {
  new totp({
    required List<int> secret,
    this.algorithm = OtpAlgorithm.sha1,
    this.digits = defaultDigits,
    int period = defaultPeriod,
  }) : kind = OtpKind.totp,
       period = _checked(period, isValidPeriod, 'period'),
       counter = null,
       secret = _copySecret(secret) {
    _checkCommon();
  }

  new hotp({
    required List<int> secret,
    this.algorithm = OtpAlgorithm.sha1,
    this.digits = defaultDigits,
    int counter = 0,
  }) : kind = OtpKind.hotp,
       period = null,
       counter = _checked(counter, isValidCounter, 'counter'),
       secret = _copySecret(secret) {
    _checkCommon();
  }

  static const defaultDigits = 6;
  static const defaultPeriod = 30;
  static const minDigits = 6;
  static const maxDigits = 8;
  static const maxPeriod = 3600;
  static const maxSecretLength = 256;

  final OtpKind kind;

  /// Değiştirilemez bir kopya.
  final Uint8List secret;
  final OtpAlgorithm algorithm;
  final int digits;

  /// Yalnızca TOTP'de var, saniye cinsinden.
  final int? period;

  /// Yalnızca HOTP'de var: sıradaki kodu üretecek sayaç değeri.
  final int? counter;

  static bool isValidSecretLength(int length) =>
      length >= 1 && length <= maxSecretLength;

  static bool isValidDigits(int digits) =>
      digits >= minDigits && digits <= maxDigits;

  static bool isValidPeriod(int period) => period >= 1 && period <= maxPeriod;

  static bool isValidCounter(int counter) => counter >= 0;

  /// HOTP sayacı bir artırılmış hali. TOTP'de çağrılamaz.
  OtpParameters withNextCounter() {
    final current = counter;
    if (current == null) throw StateError('TOTP sayacı yok.');
    // Dart'ta tamsayı 64 bittir; en büyük değerde artırmak eksiye taşar.
    if (current == _maxInt) throw StateError('HOTP sayacı tükendi.');
    return withCounter(current + 1);
  }

  /// Sayacı [value] olan HOTP. TOTP'de çağrılamaz.
  OtpParameters withCounter(int value) {
    if (kind != OtpKind.hotp) throw StateError('TOTP sayacı yok.');
    return OtpParameters.hotp(
      secret: secret,
      algorithm: algorithm,
      digits: digits,
      counter: value,
    );
  }

  void _checkCommon() {
    if (!isValidSecretLength(secret.length)) {
      throw ArgumentError.value(
        secret.length,
        'secret',
        'Geçersiz anahtar uzunluğu',
      );
    }
    if (!isValidDigits(digits)) {
      throw ArgumentError.value(digits, 'digits', 'Geçersiz hane sayısı');
    }
  }

  static const _maxInt = 0x7fffffffffffffff;

  static int _checked(int value, bool Function(int) isValid, String name) {
    if (!isValid(value)) throw ArgumentError.value(value, name);
    return value;
  }

  static Uint8List _copySecret(List<int> secret) =>
      Uint8List.fromList(secret).asUnmodifiableView();

  @override
  bool operator ==(Object other) =>
      other is OtpParameters &&
      other.kind == kind &&
      other.algorithm == algorithm &&
      other.digits == digits &&
      other.period == period &&
      other.counter == counter &&
      _sameBytes(other.secret, secret);

  @override
  int get hashCode => Object.hash(
    kind,
    algorithm,
    digits,
    period,
    counter,
    Object.hashAll(secret),
  );

  /// Anahtarı yazmaz.
  @override
  String toString() =>
      'OtpParameters(${kind.label}, ${algorithm.label}, $digits hane)';

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

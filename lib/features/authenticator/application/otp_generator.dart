import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';

/// HOTP (RFC 4226), TOTP (RFC 6238) ve Steam Guard kodlarını hesaplar.
///
/// Saat her zaman dışarıdan verilir, böylece testler gerçek saate bağlı
/// kalmaz. Ayrıntılar güvenlik tasarımı belgesinin 2FA bölümünde.
abstract final class OtpGenerator {
  /// [counter] için kodu, önüne sıfır eklenmiş [digits] hane olarak döndürür.
  static String hotp({
    required List<int> secret,
    required int counter,
    OtpAlgorithm algorithm = OtpAlgorithm.sha1,
    int digits = OtpParameters.defaultDigits,
  }) {
    if (!OtpParameters.isValidDigits(digits)) {
      throw ArgumentError.value(digits, 'digits', 'Geçersiz hane sayısı');
    }
    final code = _truncated(secret, counter, algorithm) % _powersOfTen[digits];
    return code.toString().padLeft(digits, '0');
  }

  /// Steam Guard kodu: [time] anının TOTP sayısı (SHA1, 30 saniye) Steam'in
  /// 26 karakterlik alfabesiyle 5 karaktere çevrilir.
  static String steam({required List<int> secret, required DateTime time}) {
    var value = _truncated(
      secret,
      totpCounter(time, OtpParameters.defaultPeriod),
      OtpAlgorithm.sha1,
    );
    final code = StringBuffer();
    for (var i = 0; i < OtpParameters.steamDigits; i++) {
      code.write(_steamAlphabet[value % _steamAlphabet.length]);
      value ~/= _steamAlphabet.length;
    }
    return code.toString();
  }

  static const _steamAlphabet = '23456789BCDFGHJKMNPQRTVWXY';

  /// HMAC'in dinamik kesmesi: son baytın düşük 4 biti konumu verir, o
  /// konumdaki 4 bayttan işaret biti atılır. Bütün algoritmalar için aynıdır.
  static int _truncated(List<int> secret, int counter, OtpAlgorithm algorithm) {
    if (secret.isEmpty) {
      throw ArgumentError.value(secret.length, 'secret', 'Boş anahtar');
    }
    final message = Uint8List(8);
    ByteData.sublistView(message).setInt64(0, counter);
    final hash = Hmac(_hashFor(algorithm), secret).convert(message).bytes;
    final offset = hash[hash.length - 1] & 0x0f;
    return ((hash[offset] & 0x7f) << 24) |
        (hash[offset + 1] << 16) |
        (hash[offset + 2] << 8) |
        hash[offset + 3];
  }

  /// [time] anındaki TOTP sayacı: `floor(unix saniyesi / period)`.
  ///
  /// 1970'ten önceki saatler eksi sayaç verir; kodlar yanlış olur ama
  /// uygulama düşmez.
  static int totpCounter(DateTime time, int period) {
    _checkPeriod(period);
    final seconds = _floorDiv(time.millisecondsSinceEpoch, 1000);
    return _floorDiv(seconds, period);
  }

  static String totp({
    required List<int> secret,
    required DateTime time,
    int period = OtpParameters.defaultPeriod,
    OtpAlgorithm algorithm = OtpAlgorithm.sha1,
    int digits = OtpParameters.defaultDigits,
  }) => hotp(
    secret: secret,
    counter: totpCounter(time, period),
    algorithm: algorithm,
    digits: digits,
  );

  /// [time] anında geçerli kodun bitmesine kalan süre. Hiçbir zaman sıfır
  /// değildir: tam sınırda yeni kodun bütün süresi kalır.
  static Duration remaining(DateTime time, int period) {
    _checkPeriod(period);
    final periodMs = period * 1000;
    final elapsed = time.millisecondsSinceEpoch % periodMs;
    return Duration(milliseconds: periodMs - elapsed);
  }

  /// [parameters] için [time] anındaki kod. HOTP'de kayıttaki sayaç
  /// kullanılır, sayacı artırmak çağıranın işidir.
  static String codeFor(OtpParameters parameters, DateTime time) {
    return switch (parameters.kind) {
      OtpKind.totp => totp(
        secret: parameters.secret,
        time: time,
        period: parameters.period!,
        algorithm: parameters.algorithm,
        digits: parameters.digits,
      ),
      OtpKind.hotp => hotp(
        secret: parameters.secret,
        counter: parameters.counter!,
        algorithm: parameters.algorithm,
        digits: parameters.digits,
      ),
      OtpKind.steam => steam(secret: parameters.secret, time: time),
    };
  }

  /// TOTP'de ve Steam'de bir sonraki sürenin kodu. HOTP'de anlamı yoktur.
  static String nextTotp(OtpParameters parameters, DateTime time) {
    final period = parameters.period;
    if (period == null) throw StateError('HOTP için sıradaki kod yok.');
    return codeFor(parameters, time.add(Duration(seconds: period)));
  }

  static const _powersOfTen = [
    1,
    10,
    100,
    1000,
    10000,
    100000,
    1000000,
    10000000,
    100000000,
  ];

  static Hash _hashFor(OtpAlgorithm algorithm) => switch (algorithm) {
    OtpAlgorithm.sha1 => sha1,
    OtpAlgorithm.sha256 => sha256,
    OtpAlgorithm.sha512 => sha512,
  };

  static void _checkPeriod(int period) {
    if (!OtpParameters.isValidPeriod(period)) {
      throw ArgumentError.value(period, 'period', 'Geçersiz süre');
    }
  }

  /// Eksi sayılarda da aşağı yuvarlayan tamsayı bölme. [b] artı olmalı.
  static int _floorDiv(int a, int b) => (a - a % b) ~/ b;
}

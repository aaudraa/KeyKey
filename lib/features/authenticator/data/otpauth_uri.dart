import 'dart:convert';
import 'dart:typed_data';

import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';

/// `otpauth://` bağlantısının bozduğu kural.
enum OtpauthError {
  tooLong,
  notOtpauth,
  unsupportedType,
  invalidEncoding,
  duplicateParameter,
  missingSecret,
  invalidSecret,
  invalidAlgorithm,
  invalidDigits,
  invalidPeriod,
  missingCounter,
  invalidCounter,
}

/// Bağlantı okunamadı. Mesaj hangi kuralın bozulduğunu söyler, girdiyi
/// içermez; girdide gizli anahtar olabilir.
final class InvalidOtpauthUriException implements Exception {
  const new(this.error);

  final OtpauthError error;

  @override
  String toString() => 'InvalidOtpauthUriException: ${error.name}';
}

/// Bağlantıdan okunan hesap.
final class OtpauthAccount {
  const new({
    required this.parameters,
    required this.issuer,
    required this.account,
  });

  final OtpParameters parameters;
  final String issuer;
  final String account;
}

/// Google Authenticator'ın Key Uri Format'ı. Kurallar güvenlik tasarımı
/// belgesinin 2FA bölümünde.
abstract final class OtpauthUri {
  static const maxLength = 4096;
  static const _scheme = 'otpauth://';

  /// [text]'i okur. Yalnızca [InvalidOtpauthUriException] fırlatır.
  static OtpauthAccount parse(String text) {
    final input = text.trim();
    if (input.length > maxLength) _fail(OtpauthError.tooLong);
    if (input.length < _scheme.length ||
        input.substring(0, _scheme.length).toLowerCase() != _scheme) {
      _fail(OtpauthError.notOtpauth);
    }

    var rest = input.substring(_scheme.length);
    final fragment = rest.indexOf('#');
    if (fragment >= 0) rest = rest.substring(0, fragment);
    final queryStart = rest.indexOf('?');
    final path = queryStart >= 0 ? rest.substring(0, queryStart) : rest;
    final query = queryStart >= 0 ? rest.substring(queryStart + 1) : '';

    final slash = path.indexOf('/');
    final typeText = slash >= 0 ? path.substring(0, slash) : path;
    final label = _decode(slash >= 0 ? path.substring(slash + 1) : '');
    final kind = OtpKind.byLabel(typeText.toLowerCase());
    if (kind == null) _fail(OtpauthError.unsupportedType);

    final parameters = _parameters(kind, _queryParameters(query));
    final issuerParameter = parameters.issuer;
    final (labelIssuer, account) = _splitLabel(label, issuerParameter);
    return OtpauthAccount(
      parameters: parameters.otp,
      issuer: _clean(
        issuerParameter != null && issuerParameter.trim().isNotEmpty
            ? issuerParameter
            : labelIssuer,
      ),
      account: _clean(account),
    );
  }

  /// Hesabı bağlantıya çevirir. Bütün parametreler açıkça yazılır.
  static String format({
    required OtpParameters parameters,
    String issuer = '',
    String account = '',
  }) {
    // Servis yoksa ama hesap adında iki nokta varsa, okuyan tarafın baş
    // kısmı servis sanmaması için etiket iki noktayla başlar.
    final label = issuer.isEmpty && !account.contains(':')
        ? Uri.encodeComponent(account)
        : '${Uri.encodeComponent(issuer)}:${Uri.encodeComponent(account)}';
    final query = [
      'secret=${Base32.encode(parameters.secret)}',
      if (issuer.isNotEmpty) 'issuer=${Uri.encodeComponent(issuer)}',
      'algorithm=${parameters.algorithm.label}',
      'digits=${parameters.digits}',
      switch (parameters.kind) {
        OtpKind.totp => 'period=${parameters.period}',
        OtpKind.hotp => 'counter=${parameters.counter}',
      },
    ].join('&');
    return '$_scheme${parameters.kind.label}/$label?$query';
  }

  static const _known = {
    'secret',
    'issuer',
    'algorithm',
    'digits',
    'period',
    'counter',
  };

  static Map<String, String> _queryParameters(String query) {
    final result = <String, String>{};
    for (final part in query.split('&')) {
      if (part.isEmpty) continue;
      final equals = part.indexOf('=');
      final name = _decodeQuery(equals >= 0 ? part.substring(0, equals) : part)
          .toLowerCase();
      if (!_known.contains(name)) continue;
      final value = _decodeQuery(equals >= 0 ? part.substring(equals + 1) : '');
      if (result.containsKey(name)) _fail(OtpauthError.duplicateParameter);
      result[name] = value;
    }
    return result;
  }

  static ({OtpParameters otp, String? issuer}) _parameters(
    OtpKind kind,
    Map<String, String> query,
  ) {
    final secretText = query['secret'];
    if (secretText == null || secretText.trim().isEmpty) {
      _fail(OtpauthError.missingSecret);
    }
    final Uint8List secret;
    try {
      secret = Base32.decodeLenient(secretText);
    } on FormatException {
      _fail(OtpauthError.invalidSecret);
    }
    if (!OtpParameters.isValidSecretLength(secret.length)) {
      _fail(OtpauthError.invalidSecret);
    }

    final algorithmText = query['algorithm'];
    final algorithm = algorithmText == null
        ? OtpAlgorithm.sha1
        : OtpAlgorithm.byLabel(algorithmText.replaceAll('-', '').toUpperCase());
    if (algorithm == null) _fail(OtpauthError.invalidAlgorithm);

    final digits =
        _number(query['digits'], OtpauthError.invalidDigits) ??
        OtpParameters.defaultDigits;
    if (!OtpParameters.isValidDigits(digits)) {
      _fail(OtpauthError.invalidDigits);
    }

    final OtpParameters otp;
    switch (kind) {
      case OtpKind.totp:
        final period =
            _number(query['period'], OtpauthError.invalidPeriod) ??
            OtpParameters.defaultPeriod;
        if (!OtpParameters.isValidPeriod(period)) {
          _fail(OtpauthError.invalidPeriod);
        }
        otp = OtpParameters.totp(
          secret: secret,
          algorithm: algorithm,
          digits: digits,
          period: period,
        );
      case OtpKind.hotp:
        final counter = _number(query['counter'], OtpauthError.invalidCounter);
        if (counter == null) _fail(OtpauthError.missingCounter);
        otp = OtpParameters.hotp(
          secret: secret,
          algorithm: algorithm,
          digits: digits,
          counter: counter,
        );
    }
    return (otp: otp, issuer: query['issuer']);
  }

  /// Yalnızca rakamlardan oluşan, 64 bite sığan sayı. Yoksa `null`.
  static int? _number(String? text, OtpauthError error) {
    if (text == null) return null;
    final value = text.trim();
    if (!RegExp(r'^[0-9]{1,19}$').hasMatch(value)) _fail(error);
    final number = int.tryParse(value);
    if (number == null) _fail(error);
    return number;
  }

  /// Etiket `Servis:hesap` biçimindedir. Servis adında da iki nokta
  /// olabileceği için `issuer` parametresi etiketin başındaysa oradan bölünür.
  static (String, String) _splitLabel(String label, String? issuer) {
    if (issuer != null && issuer.isNotEmpty && label.startsWith('$issuer:')) {
      return (issuer, label.substring(issuer.length + 1));
    }
    final colon = label.indexOf(':');
    if (colon < 0) return ('', label);
    return (label.substring(0, colon), label.substring(colon + 1));
  }

  /// Baştaki ve sondaki boşlukları, denetim karakterlerini ve metnin yönünü
  /// değiştirip adı başka bir servis gibi gösterebilecek karakterleri atar.
  static String _clean(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      final control = rune < 0x20 || (rune >= 0x7f && rune < 0xa0);
      final bidi =
          (rune >= 0x200e && rune <= 0x200f) ||
          (rune >= 0x202a && rune <= 0x202e) ||
          (rune >= 0x2066 && rune <= 0x2069) ||
          rune == 0x061c;
      if (!control && !bidi) out.writeCharCode(rune);
    }
    return out.toString().trim();
  }

  static String _decode(String text) =>
      _percentDecode(text, plusIsSpace: false);

  static String _decodeQuery(String text) =>
      _percentDecode(text, plusIsSpace: true);

  /// Yüzde kodlamasını çözer. `Uri.decodeComponent` bozuk kodlamada
  /// `ArgumentError` fırlattığı için kendi çözücümüz var.
  static String _percentDecode(String text, {required bool plusIsSpace}) {
    final bytes = <int>[];
    for (var i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      if (unit == 0x25) {
        final high = i + 1 < text.length
            ? _hexValue(text.codeUnitAt(i + 1))
            : -1;
        final low = i + 2 < text.length
            ? _hexValue(text.codeUnitAt(i + 2))
            : -1;
        if (high < 0 || low < 0) _fail(OtpauthError.invalidEncoding);
        bytes.add(high * 16 + low);
        i += 2;
      } else if (unit == 0x2b && plusIsSpace) {
        bytes.add(0x20);
      } else if (unit < 0x80) {
        bytes.add(unit);
      } else {
        // Kodlanmamış ASCII dışı karakter olduğu gibi UTF-8'e çevrilir.
        // Eşi olmayan vekil yarısı U+FFFD olur, hata vermez.
        var end = i + 1;
        if (unit >= 0xd800 &&
            unit <= 0xdbff &&
            end < text.length &&
            (text.codeUnitAt(end) & 0xfc00) == 0xdc00) {
          end++;
        }
        bytes.addAll(utf8.encode(text.substring(i, end)));
        i = end - 1;
      }
    }
    try {
      return utf8.decode(bytes);
    } on FormatException {
      _fail(OtpauthError.invalidEncoding);
    }
  }

  static int _hexValue(int unit) {
    if (unit >= 0x30 && unit <= 0x39) return unit - 0x30;
    if (unit >= 0x41 && unit <= 0x46) return unit - 0x41 + 10;
    if (unit >= 0x61 && unit <= 0x66) return unit - 0x61 + 10;
    return -1;
  }

  static Never _fail(OtpauthError error) =>
      throw InvalidOtpauthUriException(error);
}

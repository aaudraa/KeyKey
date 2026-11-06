import 'dart:convert';
import 'dart:typed_data';

import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';

/// 2FA kaydının içeriği bu sürümün okuyabileceği biçimde değil.
///
/// Mesajda alan değeri bulunmaz, yalnızca alan adı bulunabilir.
final class InvalidOtpContentException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => 'InvalidOtpContentException: $message';
}

const Object _keep = Object();

/// 2FA kaydının şifreli içeriği. Biçim güvenlik tasarımı belgesinde.
final class OtpContent {
  new({
    required this.parameters,
    this.issuer = '',
    this.account = '',
    Uint8List? loginId,
    this.notes = '',
    this.favorite = false,
    this.trashedAt,
  }) : loginId = loginId == null ? null : _checkedLoginId(loginId);

  /// JSON baytlarını katı kurallarla okur.
  ///
  /// Bilinmeyen sürüm, eksik veya fazla alan, yanlış tür ya da kurallara
  /// uymayan değer [InvalidOtpContentException] fırlatır.
  factory fromJsonBytes(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const InvalidOtpContentException('Geçersiz JSON.');
    }
    if (decoded is! Map<String, Object?>) {
      throw const InvalidOtpContentException('Nesne bekleniyordu.');
    }
    if (decoded.length != _keys.length || !_keys.containsAll(decoded.keys)) {
      throw const InvalidOtpContentException('Eksik veya fazla alan.');
    }
    if (decoded['version'] != currentVersion) {
      throw const InvalidOtpContentException('Desteklenmeyen sürüm.');
    }
    return OtpContent(
      parameters: _parameters(decoded),
      issuer: _string(decoded['issuer'], 'issuer'),
      account: _string(decoded['account'], 'account'),
      loginId: _loginId(decoded['loginId']),
      notes: _string(decoded['notes'], 'notes'),
      favorite: _bool(decoded['favorite'], 'favorite'),
      trashedAt: _nullableTime(decoded['trashedAt'], 'trashedAt'),
    );
  }

  static const currentVersion = 1;
  static const loginIdLength = 16;

  static const _keys = {
    'version',
    'kind',
    'issuer',
    'account',
    'secret',
    'algorithm',
    'digits',
    'period',
    'counter',
    'loginId',
    'notes',
    'favorite',
    'trashedAt',
  };

  final OtpParameters parameters;
  final String issuer;
  final String account;

  /// Eşleştirilen parola kaydının kimliği. Kayıt silinmişse yok sayılır.
  final Uint8List? loginId;
  final String notes;
  final bool favorite;
  final DateTime? trashedAt;

  bool get isTrashed => trashedAt != null;

  Uint8List toJsonBytes() {
    final id = loginId;
    return utf8.encode(
      jsonEncode({
        'version': currentVersion,
        'kind': parameters.kind.label,
        'issuer': issuer,
        'account': account,
        'secret': Base32.encode(parameters.secret),
        'algorithm': parameters.algorithm.label,
        'digits': parameters.digits,
        'period': parameters.period,
        'counter': parameters.counter,
        'loginId': id == null ? null : _hex(id),
        'notes': notes,
        'favorite': favorite,
        'trashedAt': trashedAt?.millisecondsSinceEpoch,
      }),
    );
  }

  /// [loginId] ve [trashedAt] verilmezse korunur, `null` verilirse temizlenir.
  OtpContent copyWith({
    OtpParameters? parameters,
    String? issuer,
    String? account,
    Object? loginId = _keep,
    String? notes,
    bool? favorite,
    Object? trashedAt = _keep,
  }) {
    return OtpContent(
      parameters: parameters ?? this.parameters,
      issuer: issuer ?? this.issuer,
      account: account ?? this.account,
      loginId: identical(loginId, _keep) ? this.loginId : loginId as Uint8List?,
      notes: notes ?? this.notes,
      favorite: favorite ?? this.favorite,
      trashedAt: identical(trashedAt, _keep)
          ? this.trashedAt
          : trashedAt as DateTime?,
    );
  }

  static OtpParameters _parameters(Map<String, Object?> root) {
    final kind = OtpKind.byLabel(_string(root['kind'], 'kind'));
    final algorithm = OtpAlgorithm.byLabel(
      _string(root['algorithm'], 'algorithm'),
    );
    if (kind == null) {
      throw const InvalidOtpContentException('Geçersiz alan: kind');
    }
    if (algorithm == null) {
      throw const InvalidOtpContentException('Geçersiz alan: algorithm');
    }

    final Uint8List secret;
    try {
      secret = Base32.decodeCanonical(_string(root['secret'], 'secret'));
    } on FormatException {
      throw const InvalidOtpContentException('Geçersiz alan: secret');
    }
    if (!OtpParameters.isValidSecretLength(secret.length)) {
      throw const InvalidOtpContentException('Geçersiz alan: secret');
    }

    final digits = _int(root['digits'], 'digits');
    if (!OtpParameters.isValidDigits(digits)) {
      throw const InvalidOtpContentException('Geçersiz alan: digits');
    }

    switch (kind) {
      case OtpKind.totp:
        final period = _int(root['period'], 'period');
        if (!OtpParameters.isValidPeriod(period) || root['counter'] != null) {
          throw const InvalidOtpContentException('Geçersiz alan: period');
        }
        return OtpParameters.totp(
          secret: secret,
          algorithm: algorithm,
          digits: digits,
          period: period,
        );
      case OtpKind.hotp:
        final counter = _int(root['counter'], 'counter');
        if (!OtpParameters.isValidCounter(counter) || root['period'] != null) {
          throw const InvalidOtpContentException('Geçersiz alan: counter');
        }
        return OtpParameters.hotp(
          secret: secret,
          algorithm: algorithm,
          digits: digits,
          counter: counter,
        );
    }
  }

  static Uint8List? _loginId(Object? value) {
    if (value == null) return null;
    if (value is String &&
        value.length == loginIdLength * 2 &&
        RegExp(r'^[0-9a-f]+$').hasMatch(value)) {
      final id = Uint8List(loginIdLength);
      for (var i = 0; i < loginIdLength; i++) {
        id[i] = int.parse(value.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return id;
    }
    throw const InvalidOtpContentException('Geçersiz alan: loginId');
  }

  static Uint8List _checkedLoginId(Uint8List id) {
    if (id.length != loginIdLength) {
      throw ArgumentError.value(id.length, 'loginId', 'Geçersiz uzunluk');
    }
    return Uint8List.fromList(id).asUnmodifiableView();
  }

  static String _hex(Uint8List bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  static String _string(Object? value, String field) {
    if (value is String) return value;
    throw InvalidOtpContentException('Geçersiz alan: $field');
  }

  static int _int(Object? value, String field) {
    if (value is int) return value;
    throw InvalidOtpContentException('Geçersiz alan: $field');
  }

  static bool _bool(Object? value, String field) {
    if (value is bool) return value;
    throw InvalidOtpContentException('Geçersiz alan: $field');
  }

  static DateTime? _nullableTime(Object? value, String field) {
    if (value == null) return null;
    // DateTime bu aralığın dışında RangeError fırlatır.
    if (value is int && value.abs() <= _maxMilliseconds) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    throw InvalidOtpContentException('Geçersiz alan: $field');
  }

  static const _maxMilliseconds = 8640000000000000;
}

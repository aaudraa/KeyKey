import 'dart:convert';
import 'dart:typed_data';

import 'package:keykey/features/authenticator/data/import/import_result.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';

/// Google Authenticator'ın dışa aktarma QR'ı:
/// `otpauth-migration://offline?data=<Base64 protobuf>`.
///
/// Protobuf şeması Google Authenticator'ın kaynak kodundaki
/// `MigrationPayload`'dur. Bilinmeyen alanlar atlanır, bozuk veri yalnızca
/// [InvalidImportException] fırlatır.
abstract final class GoogleMigration {
  static const maxLength = 16384;
  static const _prefix = 'otpauth-migration://offline?';

  static ImportBatch parse(String text) {
    final input = text.trim();
    if (input.length > maxLength) _fail('Çok uzun.');
    if (input.length < _prefix.length ||
        input.substring(0, _prefix.length).toLowerCase() != _prefix) {
      _fail('Google Authenticator dışa aktarması değil.');
    }
    String? data;
    for (final part in input.substring(_prefix.length).split('&')) {
      if (part.startsWith('data=')) {
        if (data != null) _fail('data iki kez geçiyor.');
        data = part.substring(5);
      }
    }
    if (data == null || data.isEmpty) _fail('data yok.');
    return _payload(_base64(data));
  }

  /// Yüzde kodlamasını çözer ve Base64'ü hoşgörüyle okur: URL'ye uygun
  /// alfabe, eksik dolgu ve `+` yerine boşluk kabul edilir.
  static Uint8List _base64(String text) {
    final decoded = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '%') {
        if (i + 2 >= text.length) _fail('Geçersiz kodlama.');
        final value = int.tryParse(text.substring(i + 1, i + 3), radix: 16);
        if (value == null) _fail('Geçersiz kodlama.');
        decoded.writeCharCode(value);
        i += 2;
      } else {
        decoded.write(char);
      }
    }
    var base64Text = decoded
        .toString()
        .replaceAll(' ', '+')
        .replaceAll('-', '+')
        .replaceAll('_', '/')
        .replaceAll('=', '');
    base64Text = base64Text.padRight((base64Text.length + 3) ~/ 4 * 4, '=');
    try {
      return base64.decode(base64Text);
    } on FormatException {
      _fail('Geçersiz Base64.');
    }
  }

  static ImportBatch _payload(Uint8List bytes) {
    final accounts = <ImportedAccount>[];
    var unsupported = 0;
    var batchSize = 1;
    final reader = _ProtoReader(bytes);
    while (!reader.isDone) {
      final (field, wireType) = reader.tag();
      if (field == 3 && wireType == _ProtoReader.wireVarint) {
        batchSize = reader.varint();
      } else if (field == 1 && wireType == _ProtoReader.wireLength) {
        final account = _otpParameters(reader.bytes());
        if (account == null) {
          unsupported++;
        } else {
          accounts.add(account);
        }
      } else {
        reader.skip(wireType);
      }
    }
    return ImportBatch(
      accounts: accounts,
      unsupported: unsupported,
      batchSize: batchSize < 1 ? 1 : batchSize,
    );
  }

  /// Desteklenmeyen hesapta `null` döner.
  static ImportedAccount? _otpParameters(Uint8List bytes) {
    Uint8List? secret;
    var name = '';
    var issuer = '';
    var algorithm = 0;
    var digits = 0;
    var type = 0;
    var counter = 0;
    final reader = _ProtoReader(bytes);
    while (!reader.isDone) {
      final (field, wireType) = reader.tag();
      switch ((field, wireType)) {
        case (1, _ProtoReader.wireLength):
          secret = reader.bytes();
        case (2, _ProtoReader.wireLength):
          name = reader.string();
        case (3, _ProtoReader.wireLength):
          issuer = reader.string();
        case (4, _ProtoReader.wireVarint):
          algorithm = reader.varint();
        case (5, _ProtoReader.wireVarint):
          digits = reader.varint();
        case (6, _ProtoReader.wireVarint):
          type = reader.varint();
        case (7, _ProtoReader.wireVarint):
          counter = reader.varint();
        default:
          reader.skip(wireType);
      }
    }

    // Belirtilmemiş değerler Google Authenticator'daki gibi varsayılanlara
    // döner. MD5 (4) ve bilinmeyen değerler desteklenmez.
    final otpAlgorithm = switch (algorithm) {
      0 || 1 => OtpAlgorithm.sha1,
      2 => OtpAlgorithm.sha256,
      3 => OtpAlgorithm.sha512,
      _ => null,
    };
    final otpDigits = switch (digits) {
      0 || 1 => 6,
      2 => 8,
      _ => null,
    };
    if (secret == null ||
        !OtpParameters.isValidSecretLength(secret.length) ||
        otpAlgorithm == null ||
        otpDigits == null) {
      return null;
    }
    final OtpParameters parameters;
    switch (type) {
      case 0 || 2:
        parameters = OtpParameters.totp(
          secret: secret,
          algorithm: otpAlgorithm,
          digits: otpDigits,
        );
      case 1:
        if (!OtpParameters.isValidCounter(counter)) return null;
        parameters = OtpParameters.hotp(
          secret: secret,
          algorithm: otpAlgorithm,
          digits: otpDigits,
          counter: counter,
        );
      default:
        return null;
    }

    // Ad çoğu zaman "Servis:hesap" biçimindedir, servis ayrıca da yazılır.
    var account = name;
    if (issuer.isNotEmpty && name.startsWith('$issuer:')) {
      account = name.substring(issuer.length + 1);
    } else if (issuer.isEmpty && name.contains(':')) {
      final colon = name.indexOf(':');
      issuer = name.substring(0, colon);
      account = name.substring(colon + 1);
    }
    return ImportedAccount(
      parameters: parameters,
      issuer: issuer.trim(),
      account: account.trim(),
    );
  }

  static Never _fail(String message) => throw InvalidImportException(message);
}

/// Protobuf'un yalnızca gerektiği kadarını okur. Her okuma sınırları denetler.
final class _ProtoReader {
  new(this._bytes);

  static const wireVarint = 0;
  static const wireFixed64 = 1;
  static const wireLength = 2;
  static const wireFixed32 = 5;

  final Uint8List _bytes;
  int _position = 0;

  bool get isDone => _position >= _bytes.length;

  (int, int) tag() {
    final key = varint();
    final field = key >> 3;
    if (field == 0) GoogleMigration._fail('Geçersiz alan numarası.');
    return (field, key & 0x7);
  }

  /// En fazla 64 bit. Daha uzunu veya eksi sayılar reddedilir.
  int varint() {
    var result = 0;
    for (var shift = 0; shift < 64; shift += 7) {
      if (isDone) GoogleMigration._fail('Yarım sayı.');
      final byte = _bytes[_position++];
      result |= (byte & 0x7f) << shift;
      if (byte & 0x80 == 0) {
        if (result < 0) GoogleMigration._fail('Eksi sayı.');
        return result;
      }
    }
    GoogleMigration._fail('Çok uzun sayı.');
  }

  Uint8List bytes() {
    final length = varint();
    if (length > _bytes.length - _position) {
      GoogleMigration._fail('Yarım alan.');
    }
    final value = Uint8List.sublistView(_bytes, _position, _position + length);
    _position += length;
    return value;
  }

  String string() {
    try {
      return utf8.decode(bytes());
    } on FormatException {
      GoogleMigration._fail('Geçersiz metin.');
    }
  }

  void skip(int wireType) {
    switch (wireType) {
      case wireVarint:
        varint();
      case wireFixed64:
        _advance(8);
      case wireLength:
        bytes();
      case wireFixed32:
        _advance(4);
      default:
        GoogleMigration._fail('Desteklenmeyen alan türü.');
    }
  }

  void _advance(int count) {
    if (count > _bytes.length - _position) {
      GoogleMigration._fail('Yarım alan.');
    }
    _position += count;
  }
}

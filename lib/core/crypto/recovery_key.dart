import 'dart:convert';
import 'dart:typed_data';

import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:sodium/sodium_sumo.dart';

/// Kurtarma anahtarının insanların yazabileceği metin biçimi.
///
/// Biçim: 32 bayt anahtar ve 2 bayt sağlama, Crockford Base32 ile kodlanmış ve
/// 5'erli gruplanmış. Ayrıntılar güvenlik tasarımı belgesinde.
final class RecoveryKeyCodec {
  const new(this._sodium);

  static const keyLength = 32;
  static const _checksumLength = 2;
  static const _textLength = 55;
  static const _groupLength = 5;
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const _checksumLabel = 'keykey/v1/recovery-checksum';

  final SodiumSumo _sodium;

  String encode(Uint8List key) {
    if (key.length != keyLength) {
      throw ArgumentError.value(key.length, 'key', 'Geçersiz uzunluk');
    }
    final payload = Uint8List(keyLength + _checksumLength)
      ..setAll(0, key)
      ..setAll(keyLength, _checksum(key));

    final text = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final byte in payload) {
      buffer = (buffer << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        text.write(_alphabet[(buffer >> bits) & 31]);
      }
      buffer &= (1 << bits) - 1;
    }
    if (bits > 0) text.write(_alphabet[(buffer << (5 - bits)) & 31]);

    final encoded = text.toString();
    return [
      for (var i = 0; i < encoded.length; i += _groupLength)
        encoded.substring(i, i + _groupLength),
    ].join('-');
  }

  Uint8List decode(String text) {
    final symbols = <int>[];
    for (final rune in text.runes) {
      final character = String.fromCharCode(rune);
      if (character == ' ' || character == '-') continue;
      final value = _alphabet.indexOf(_normalize(character));
      if (value < 0) {
        throw const InvalidRecoveryKeyException('Geçersiz karakter.');
      }
      symbols.add(value);
    }
    if (symbols.length != _textLength) {
      throw const InvalidRecoveryKeyException('Geçersiz uzunluk.');
    }

    final payload = Uint8List(keyLength + _checksumLength);
    var buffer = 0;
    var bits = 0;
    var index = 0;
    for (final symbol in symbols) {
      buffer = (buffer << 5) | symbol;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        payload[index++] = (buffer >> bits) & 255;
        buffer &= (1 << bits) - 1;
      }
    }
    // Kullanılmayan son bitler sıfır olmalı, aksi halde metin kanonik değildir.
    if (buffer != 0) {
      throw const InvalidRecoveryKeyException('Geçersiz metin.');
    }

    final key = Uint8List.sublistView(payload, 0, keyLength);
    final checksum = Uint8List.sublistView(payload, keyLength);
    if (!_sodium.memcmp(checksum, _checksum(key))) {
      throw const InvalidRecoveryKeyException('Sağlama tutmuyor.');
    }
    return Uint8List.fromList(key);
  }

  Uint8List _checksum(Uint8List key) {
    final hash = _sodium.crypto.genericHash(
      message: Uint8List.fromList([...utf8.encode(_checksumLabel), ...key]),
      outLen: 32,
    );
    return Uint8List.sublistView(hash, 0, _checksumLength);
  }

  // Dart'ın toUpperCase işlevi dil ayarından etkilenmez, ama Türkçe klavyeden
  // gelen ı ve İ harflerini ayrıca karşılamak gerekiyor.
  static String _normalize(String character) => switch (character) {
    'i' || 'I' || 'ı' || 'İ' || 'l' || 'L' => '1',
    'o' || 'O' => '0',
    _ => character.toUpperCase(),
  };
}

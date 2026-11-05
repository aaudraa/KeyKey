import 'dart:typed_data';

import 'package:keykey/core/crypto/associated_data.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:sodium/sodium_sumo.dart';

/// Kayıtları kasa anahtarından türetilen alt anahtarlarla şifreler.
///
/// Şifreli veri kasa kimliğine, kayıt kimliğine ve türe bağlıdır, yani başka
/// bir kaydın yerine konamaz. Alt anahtarlar korumalı bellekte tutulur, işi
/// bitince [dispose] çağrılmalıdır.
final class RecordCipher {
  factory(SodiumSumo sodium, SecureKey vaultKey, Uint8List vaultId) {
    SecureKey derive(String context) => sodium.crypto.kdfHkdfSha256.expand(
      masterKey: vaultKey,
      context: context,
      outLen: _keyLength,
    );
    return RecordCipher._(
      sodium,
      vaultId,
      derive(recordsContext),
      derive(otpContext),
    );
  }

  new _(this._sodium, this._vaultId, this._recordsKey, this._otpKey);

  static const recordIdLength = 16;
  static const otpType = 'otp';
  static const recordsContext = 'keykey/v1/records';
  static const otpContext = 'keykey/v1/otp';
  static const blockSize = 256;
  static const formatVersion = 1;

  static const _keyLength = 32;
  static const _label = 'keykey/v1/record';

  final SodiumSumo _sodium;
  final Uint8List _vaultId;
  final SecureKey _recordsKey;
  final SecureKey _otpKey;

  Aead get _aead => _sodium.crypto.aeadXChaCha20Poly1305IETF;

  Uint8List encrypt({
    required Uint8List recordId,
    required String type,
    required Uint8List plainText,
  }) {
    final padded = _sodium.pad(plainText, blockSize);
    try {
      final nonce = _sodium.randombytes.buf(_aead.nonceBytes);
      final cipherText = _aead.encrypt(
        message: padded,
        nonce: nonce,
        key: _keyFor(type),
        additionalData: _associatedData(recordId, type),
      );
      return Uint8List(1 + nonce.length + cipherText.length)
        ..[0] = formatVersion
        ..setAll(1, nonce)
        ..setAll(1 + nonce.length, cipherText);
    } finally {
      padded.fillRange(0, padded.length, 0);
    }
  }

  /// Veri bozulmuş, değiştirilmiş veya başka bir bağlama aitse
  /// [CorruptedDataException] fırlatır.
  Uint8List decrypt({
    required Uint8List recordId,
    required String type,
    required Uint8List blob,
  }) {
    final nonceEnd = 1 + _aead.nonceBytes;
    if (blob.length < nonceEnd + _aead.aBytes || blob[0] != formatVersion) {
      throw const CorruptedDataException();
    }
    final Uint8List padded;
    try {
      padded = _aead.decrypt(
        cipherText: Uint8List.sublistView(blob, nonceEnd),
        nonce: Uint8List.sublistView(blob, 1, nonceEnd),
        key: _keyFor(type),
        additionalData: _associatedData(recordId, type),
      );
    } on SodiumException {
      throw const CorruptedDataException();
    }
    try {
      return Uint8List.fromList(_sodium.unpad(padded, blockSize));
    } on SodiumException {
      throw const CorruptedDataException();
    } finally {
      padded.fillRange(0, padded.length, 0);
    }
  }

  void dispose() {
    _recordsKey.dispose();
    _otpKey.dispose();
  }

  SecureKey _keyFor(String type) => type == otpType ? _otpKey : _recordsKey;

  Uint8List _associatedData(Uint8List recordId, String type) {
    if (recordId.length != recordIdLength) {
      throw ArgumentError.value(
        recordId.length,
        'recordId',
        'Geçersiz uzunluk',
      );
    }
    if (type.isEmpty) {
      throw ArgumentError.value(type, 'type', 'Boş olamaz');
    }
    return buildAssociatedData([_label, _vaultId, recordId, type]);
  }
}

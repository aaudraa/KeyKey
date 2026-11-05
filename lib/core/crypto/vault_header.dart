import 'dart:convert';
import 'dart:typed_data';

import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/kdf_params.dart';

/// Sarılmış bir kasa anahtarı.
final class WrappedKey {
  const new({required this.nonce, required this.cipherText});

  static const nonceLength = 24;
  static const cipherTextLength = 48;

  final Uint8List nonce;
  final Uint8List cipherText;
}

/// Kasayı açmak için gereken, şifrelenmesi gerekmeyen bilgiler.
final class VaultHeader {
  const new({
    required this.vaultId,
    required this.kdf,
    required this.passwordSlot,
    required this.recoverySlot,
  });

  /// JSON metnini katı kurallarla okur.
  ///
  /// Bilinmeyen sürüm, eksik veya fazla alan, yanlış tür ya da uzunluk
  /// [InvalidVaultHeaderException] fırlatır.
  factory fromJsonString(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const InvalidVaultHeaderException('Geçersiz JSON.');
    }

    final root = _object(decoded, const {'version', 'vaultId', 'kdf', 'slots'});
    if (root['version'] != currentVersion) {
      throw const InvalidVaultHeaderException('Desteklenmeyen sürüm.');
    }

    final kdf = _object(root['kdf'], const {
      'algorithm',
      'opsLimit',
      'memLimit',
      'salt',
    });
    if (kdf['algorithm'] != KdfParams.algorithm) {
      throw const InvalidVaultHeaderException('Desteklenmeyen algoritma.');
    }
    final opsLimit = kdf['opsLimit'];
    final memLimit = kdf['memLimit'];
    if (opsLimit is! int || memLimit is! int) {
      throw const InvalidVaultHeaderException('Geçersiz sayı.');
    }

    final slots = _object(root['slots'], const {'password', 'recovery'});
    return VaultHeader(
      vaultId: _bytes(root['vaultId'], vaultIdLength),
      kdf: KdfParams(
        opsLimit: opsLimit,
        memLimit: memLimit,
        salt: _bytes(kdf['salt'], KdfParams.saltLength),
      ),
      passwordSlot: _slot(slots['password']),
      recoverySlot: _slot(slots['recovery']),
    );
  }

  static const currentVersion = 1;
  static const vaultIdLength = 16;

  final Uint8List vaultId;
  final KdfParams kdf;
  final WrappedKey passwordSlot;
  final WrappedKey recoverySlot;

  String toJsonString() => jsonEncode({
    'version': currentVersion,
    'vaultId': base64.encode(vaultId),
    'kdf': {
      'algorithm': KdfParams.algorithm,
      'opsLimit': kdf.opsLimit,
      'memLimit': kdf.memLimit,
      'salt': base64.encode(kdf.salt),
    },
    'slots': {
      'password': _slotToJson(passwordSlot),
      'recovery': _slotToJson(recoverySlot),
    },
  });

  static Map<String, String> _slotToJson(WrappedKey slot) => {
    'nonce': base64.encode(slot.nonce),
    'cipherText': base64.encode(slot.cipherText),
  };

  static WrappedKey _slot(Object? value) {
    final slot = _object(value, const {'nonce', 'cipherText'});
    return WrappedKey(
      nonce: _bytes(slot['nonce'], WrappedKey.nonceLength),
      cipherText: _bytes(slot['cipherText'], WrappedKey.cipherTextLength),
    );
  }

  static Map<String, Object?> _object(Object? value, Set<String> keys) {
    if (value is! Map<String, Object?> ||
        value.length != keys.length ||
        !value.keys.every(keys.contains)) {
      throw const InvalidVaultHeaderException('Geçersiz alanlar.');
    }
    return value;
  }

  static Uint8List _bytes(Object? value, int length) {
    if (value is! String) {
      throw const InvalidVaultHeaderException('Geçersiz ikili alan.');
    }
    final Uint8List bytes;
    try {
      bytes = base64.decode(value);
    } on FormatException {
      throw const InvalidVaultHeaderException('Geçersiz Base64.');
    }
    // base64.decode URL güvenli alfabeyi ve dolgusuz metni de kabul ediyor,
    // biçimin tek bir geçerli gösterimi olması için geri kodlayıp bakıyoruz.
    if (bytes.length != length || base64.encode(bytes) != value) {
      throw const InvalidVaultHeaderException('Geçersiz ikili alan.');
    }
    return bytes;
  }
}

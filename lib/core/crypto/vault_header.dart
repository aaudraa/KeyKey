import 'dart:typed_data';

import 'package:keykey/core/crypto/kdf_params.dart';

/// Sarılmış bir kasa anahtarı.
final class WrappedKey {
  const new({required this.nonce, required this.cipherText});

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

  static const currentVersion = 1;
  static const vaultIdLength = 16;

  final Uint8List vaultId;
  final KdfParams kdf;
  final WrappedKey passwordSlot;
  final WrappedKey recoverySlot;
}

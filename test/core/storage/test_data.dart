import 'dart:typed_data';

import 'package:keykey/core/crypto/kdf_params.dart';
import 'package:keykey/core/crypto/vault_header.dart';

/// Şifreleme yapılmayan testler için geçerli biçimde bir üst bilgi.
///
/// [fill] her alanı aynı baytla doldurur, böylece iki üst bilgi ayırt edilir.
VaultHeader sampleHeader({int fill = 1}) {
  Uint8List bytes(int length) => Uint8List(length)..fillRange(0, length, fill);

  WrappedKey slot() => WrappedKey(
    nonce: bytes(WrappedKey.nonceLength),
    cipherText: bytes(WrappedKey.cipherTextLength),
  );

  return VaultHeader(
    vaultId: bytes(VaultHeader.vaultIdLength),
    kdf: KdfParams(
      opsLimit: KdfParams.minOpsLimit,
      memLimit: KdfParams.minMemLimit,
      salt: bytes(KdfParams.saltLength),
    ),
    passwordSlot: slot(),
    recoverySlot: slot(),
  );
}

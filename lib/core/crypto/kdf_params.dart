import 'dart:typed_data';

import 'package:keykey/core/crypto/crypto_exceptions.dart';

/// Argon2id parametreleri. Sınırlar güvenlik tasarımı belgesinde açıklanıyor.
final class KdfParams {
  factory({
    required int opsLimit,
    required int memLimit,
    required Uint8List salt,
  }) {
    if (opsLimit < minOpsLimit || opsLimit > maxOpsLimit) {
      throw const InvalidVaultHeaderException(
        'Geçersiz Argon2id geçiş sayısı.',
      );
    }
    if (memLimit < minMemLimit || memLimit > maxMemLimit) {
      throw const InvalidVaultHeaderException(
        'Geçersiz Argon2id bellek değeri.',
      );
    }
    if (salt.length != saltLength) {
      throw const InvalidVaultHeaderException(
        'Geçersiz Argon2id tuz uzunluğu.',
      );
    }
    return KdfParams._(opsLimit, memLimit, Uint8List.fromList(salt));
  }

  const new _(this.opsLimit, this.memLimit, this.salt);

  static const algorithm = 'argon2id13';
  static const saltLength = 16;
  static const keyLength = 32;

  static const minOpsLimit = 3;
  static const maxOpsLimit = 32;
  static const int minMemLimit = 64 * 1024 * 1024;
  static const int maxMemLimit = 1024 * 1024 * 1024;

  final int opsLimit;
  final int memLimit;
  final Uint8List salt;
}

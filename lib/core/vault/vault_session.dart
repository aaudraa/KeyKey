import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/crypto/vault_crypto.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:sodium/sodium_sumo.dart';

/// Açık bir kasa. Anahtarlar korumalı bellektedir ve kilitlenince silinir.
final class VaultSession {
  new({required this.header, required this.vaultKey, required this.records});

  /// Parola değişince güncellenir.
  VaultHeader header;

  final SecureKey vaultKey;
  final RecordCipher records;

  void dispose() {
    records.dispose();
    vaultKey.dispose();
  }
}

/// Oluşturulmuş ama henüz diske yazılmamış kasa.
///
/// Kurtarma anahtarı doğrulanana kadar yalnızca bellekte durur. Kullanıcı
/// vazgeçerse [dispose] çağrılır ve diskte hiçbir şey kalmaz.
final class PendingVault {
  const new(this.created);

  final CreatedVault created;

  String get recoveryKeyText => created.recoveryKeyText;

  void dispose() => created.vaultKey.dispose();
}

import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/crypto/vault_crypto.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:sodium/sodium_sumo.dart';

/// Kasa kilitliyken anahtar gerektiren bir işlem istendi.
final class VaultLockedException implements Exception {
  const new();

  @override
  String toString() => 'VaultLockedException: Kasa kilitli.';
}

/// Açık bir kasa. Anahtarlar korumalı bellektedir ve kilitlenince silinir.
///
/// Silinmiş bir `SecureKey`'e dokunmak Dart hatası vermez, serbest bırakılmış
/// belleğe eriştiği için süreci düşürür. Bu yüzden anahtarlara kontrolden
/// geçerek ulaşılır, kilitten sonra erişim [VaultLockedException] fırlatır.
final class VaultSession {
  new({required this.header, required this._vaultKey, required this._records});

  /// Parola değişince güncellenir. Şifreli olmadığı için silinmez.
  VaultHeader header;

  final SecureKey _vaultKey;
  final RecordCipher _records;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  SecureKey get vaultKey {
    _ensureOpen();
    return _vaultKey;
  }

  RecordCipher get records {
    _ensureOpen();
    return _records;
  }

  /// Birden çok kez çağrılabilir.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _records.dispose();
    _vaultKey.dispose();
  }

  void _ensureOpen() {
    if (_disposed) throw const VaultLockedException();
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

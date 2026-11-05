import 'dart:typed_data';

import 'package:keykey/core/crypto/associated_data.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/kdf_params.dart';
import 'package:keykey/core/crypto/password_kdf.dart';
import 'package:keykey/core/crypto/recovery_key.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:sodium/sodium_sumo.dart';

/// Yeni oluşturulmuş bir kasa.
///
/// [vaultKey] korumalı bellektedir, işi bitince `dispose` edilmelidir.
/// [recoveryKeyText] yalnızca kullanıcıya bir kez gösterilir, saklanmaz.
final class CreatedVault {
  const new({
    required this.header,
    required this.vaultKey,
    required this.recoveryKeyText,
  });

  final VaultHeader header;
  final SecureKey vaultKey;
  final String recoveryKeyText;
}

/// Kasa anahtarını üretir, sarar ve açar.
final class VaultCrypto {
  new(this._sodium)
    : _kdf = PasswordKdf(_sodium),
      _recoveryCodec = RecoveryKeyCodec(_sodium);

  static const _vaultKeyLength = 32;
  static const _wrapLabel = 'keykey/v1/wrap';
  static const _recoveryKekContext = 'keykey/v1/kek/recovery';
  static const _passwordSlotName = 'password';
  static const _recoverySlotName = 'recovery';

  final SodiumSumo _sodium;
  final PasswordKdf _kdf;
  final RecoveryKeyCodec _recoveryCodec;

  Aead get _aead => _sodium.crypto.aeadXChaCha20Poly1305IETF;

  Future<CreatedVault> createVault(
    String password, {
    int opsLimit = KdfParams.minOpsLimit,
  }) async {
    final vaultId = _sodium.randombytes.buf(VaultHeader.vaultIdLength);
    final kdfParams = _kdf.newParams(opsLimit: opsLimit);
    final vaultKey = _sodium.secureRandom(_vaultKeyLength);
    final recoveryKey = _sodium.randombytes.buf(RecoveryKeyCodec.keyLength);
    try {
      final recoveryKeyText = _recoveryCodec.encode(recoveryKey);
      final passwordSlot = await _wrapWithPassword(
        vaultKey,
        password,
        vaultId,
        kdfParams,
      );
      final recoverySlot = _wrapWithRecoveryKey(vaultKey, recoveryKey, vaultId);
      return CreatedVault(
        header: VaultHeader(
          vaultId: vaultId,
          kdf: kdfParams,
          passwordSlot: passwordSlot,
          recoverySlot: recoverySlot,
        ),
        vaultKey: vaultKey,
        recoveryKeyText: recoveryKeyText,
      );
    } on Object {
      vaultKey.dispose();
      rethrow;
    } finally {
      recoveryKey.fillRange(0, recoveryKey.length, 0);
    }
  }

  /// Kasa anahtarını ana parolayla açar.
  ///
  /// Parola yanlışsa veya üst bilgi değiştirilmişse [WrongSecretException]
  /// fırlatır.
  Future<SecureKey> unlockWithPassword(
    VaultHeader header,
    String password,
  ) async {
    final kek = await _deriveKek(password, header.kdf);
    try {
      return _unwrap(
        kek,
        header.passwordSlot,
        _passwordAd(header.vaultId, header.kdf),
      );
    } finally {
      kek.dispose();
    }
  }

  /// Kasa anahtarını kurtarma anahtarı metniyle açar.
  ///
  /// Metin geçersizse [InvalidRecoveryKeyException], anahtar bu kasaya ait
  /// değilse [WrongSecretException] fırlatır.
  SecureKey unlockWithRecoveryKey(VaultHeader header, String recoveryKeyText) {
    final recoveryKey = _recoveryCodec.decode(recoveryKeyText);
    final kek = _deriveRecoveryKek(recoveryKey);
    try {
      return _unwrap(kek, header.recoverySlot, _recoveryAd(header.vaultId));
    } finally {
      kek.dispose();
      recoveryKey.fillRange(0, recoveryKey.length, 0);
    }
  }

  /// Ana parolayı değiştirir. Kasa anahtarı ve kurtarma yuvası aynı kalır, bu
  /// yüzden kayıtlar yeniden şifrelenmez. Her seferinde yeni tuz üretilir.
  Future<VaultHeader> changePassword(
    VaultHeader header,
    SecureKey vaultKey,
    String newPassword, {
    int? opsLimit,
  }) async {
    final kdfParams = _kdf.newParams(opsLimit: opsLimit ?? header.kdf.opsLimit);
    final passwordSlot = await _wrapWithPassword(
      vaultKey,
      newPassword,
      header.vaultId,
      kdfParams,
    );
    return VaultHeader(
      vaultId: header.vaultId,
      kdf: kdfParams,
      passwordSlot: passwordSlot,
      recoverySlot: header.recoverySlot,
    );
  }

  Future<WrappedKey> _wrapWithPassword(
    SecureKey vaultKey,
    String password,
    Uint8List vaultId,
    KdfParams params,
  ) async {
    final kek = await _deriveKek(password, params);
    try {
      return _wrap(kek, vaultKey, _passwordAd(vaultId, params));
    } finally {
      kek.dispose();
    }
  }

  WrappedKey _wrapWithRecoveryKey(
    SecureKey vaultKey,
    Uint8List recoveryKey,
    Uint8List vaultId,
  ) {
    final kek = _deriveRecoveryKek(recoveryKey);
    try {
      return _wrap(kek, vaultKey, _recoveryAd(vaultId));
    } finally {
      kek.dispose();
    }
  }

  Future<SecureKey> _deriveKek(String password, KdfParams params) async {
    final bytes = PasswordKdf.encodePassword(password);
    try {
      return await _kdf.deriveKey(bytes, params);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  SecureKey _deriveRecoveryKek(Uint8List recoveryKey) {
    final master = _sodium.secureCopy(recoveryKey);
    try {
      return _sodium.crypto.kdfHkdfSha256.expand(
        masterKey: master,
        context: _recoveryKekContext,
        outLen: _vaultKeyLength,
      );
    } finally {
      master.dispose();
    }
  }

  WrappedKey _wrap(SecureKey kek, SecureKey vaultKey, Uint8List ad) {
    final nonce = _sodium.randombytes.buf(_aead.nonceBytes);
    final cipherText = vaultKey.runUnlockedSync(
      (data) => _aead.encrypt(
        message: data,
        nonce: nonce,
        key: kek,
        additionalData: ad,
      ),
    );
    return WrappedKey(nonce: nonce, cipherText: cipherText);
  }

  SecureKey _unwrap(SecureKey kek, WrappedKey slot, Uint8List ad) {
    final Uint8List plain;
    try {
      plain = _aead.decrypt(
        cipherText: slot.cipherText,
        nonce: slot.nonce,
        key: kek,
        additionalData: ad,
      );
    } on SodiumException {
      throw const WrongSecretException();
    }
    try {
      return _sodium.secureCopy(plain);
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
  }

  static Uint8List _passwordAd(Uint8List vaultId, KdfParams params) =>
      buildAssociatedData([
        _wrapLabel,
        vaultId,
        _passwordSlotName,
        KdfParams.algorithm,
        params.opsLimit,
        params.memLimit,
        params.salt,
      ]);

  static Uint8List _recoveryAd(Uint8List vaultId) =>
      buildAssociatedData([_wrapLabel, vaultId, _recoverySlotName]);
}

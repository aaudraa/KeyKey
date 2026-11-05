import 'dart:typed_data';

import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/password_kdf.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/crypto/vault_crypto.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/biometric_bridge.dart';
import 'package:keykey/core/vault/password_policy.dart';
import 'package:keykey/core/vault/unlock_backoff.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:sodium/sodium_sumo.dart';

/// Parola denemesinin sonucu.
sealed class PasswordAttempt {
  const new();
}

/// Parola doğru.
final class PasswordAccepted extends PasswordAttempt {
  const new();
}

/// Parola yanlış. [wait] kadar sonra yeniden denenebilir.
final class PasswordRejected extends PasswordAttempt {
  const new(this.wait);

  final Duration wait;
}

/// Bekleme sürüyor, parola hiç denenmedi.
final class PasswordMustWait extends PasswordAttempt {
  const new(this.wait);

  final Duration wait;
}

/// İşlem sürerken kasa kilitlendi, sonuç önemsiz.
final class PasswordInterrupted extends PasswordAttempt {
  const new();
}

/// Parolayla açmanın sonucu.
final class UnlockOutcome {
  const new(this.attempt, [this.session]);

  final PasswordAttempt attempt;

  /// Yalnızca parola doğruysa vardır.
  final VaultSession? session;
}

/// Kasayı oluşturur, açar ve parolasını değiştirir. Ekranlardan bağımsızdır.
class VaultService {
  new({
    required SodiumSumo sodium,
    required this._store,
    this._biometric,
    DateTime Function()? clock,
  }) : _sodium = sodium,
       _crypto = VaultCrypto(sodium),
       _kdf = PasswordKdf(sodium),
       _clock = clock ?? DateTime.now;

  static const _vaultKeyLength = 32;

  final SodiumSumo _sodium;
  final VaultStore _store;
  final BiometricBridge? _biometric;
  final VaultCrypto _crypto;
  final PasswordKdf _kdf;
  final DateTime Function() _clock;

  /// Kurulu değilse `null` döner.
  ///
  /// Üst bilgi bozuksa [InvalidVaultHeaderException] fırlatır.
  Future<VaultHeader?> readHeader() => _store.readHeader();

  /// Kasayı yalnızca bellekte oluşturur. Diske [confirmRecoveryKey] yazar.
  Future<PendingVault> prepareVault(String password) async {
    _requireAcceptable(password);
    final opsLimit = await _kdf.calibrateOpsLimit();
    final created = await _crypto.createVault(password, opsLimit: opsLimit);
    return PendingVault(created);
  }

  /// Yazılan kurtarma anahtarı kasayı açıyorsa kasayı diske yazar ve açar.
  ///
  /// Karşılaştırma yerine yuva gerçekten açılır, böylece kullanıcının yazdığı
  /// anahtarın işe yaradığı kanıtlanır. Metin geçersizse
  /// [InvalidRecoveryKeyException], başka anahtarsa [WrongSecretException]
  /// fırlatır; bu durumda diske bir şey yazılmaz.
  Future<VaultSession> confirmRecoveryKey(
    PendingVault pending,
    String typedRecoveryKey,
  ) async {
    final header = pending.created.header;
    _crypto.unlockWithRecoveryKey(header, typedRecoveryKey).dispose();
    await _store.createVault(header);
    return _openSession(header, pending.created.vaultKey);
  }

  /// Şu an kalan bekleme. Saat geri alınmışsa bekleme baştan başlar.
  Future<Duration> remainingWait() async {
    final attempts = await _store.readUnlockAttempts();
    final lastFailedAt = attempts.lastFailedAt;
    final now = _clock();
    if (lastFailedAt != null &&
        UnlockBackoff.clockMovedBack(lastFailedAt: lastFailedAt, now: now)) {
      await _store.moveLastFailure(now);
    }
    return UnlockBackoff.remaining(
      failedAttempts: attempts.failedAttempts,
      lastFailedAt: lastFailedAt,
      now: now,
    );
  }

  /// Ana parolayla açar.
  ///
  /// Sayaç Argon2id'den önce artırılır ve yalnızca doğru parolada sıfırlanır,
  /// böylece işlemin ortasında uygulamayı öldürerek deneme kazanılamaz.
  Future<UnlockOutcome> unlockWithPassword(
    VaultHeader header,
    String password,
  ) async {
    final (attempt, key) = await _checkPassword(header, password);
    if (key == null) return UnlockOutcome(attempt);
    return UnlockOutcome(attempt, _openSession(header, key));
  }

  /// Kurtarma anahtarıyla açar. Ardından yeni parola belirlenmelidir.
  ///
  /// Metin geçersizse [InvalidRecoveryKeyException], bu kasaya ait değilse
  /// [WrongSecretException] fırlatır.
  VaultSession unlockWithRecoveryKey(VaultHeader header, String text) {
    return _openSession(header, _crypto.unlockWithRecoveryKey(header, text));
  }

  /// Mevcut parolayı doğrulayıp parolayı değiştirir.
  ///
  /// Sonuç [PasswordAccepted] değilse hiçbir şey değişmez.
  Future<PasswordAttempt> changePassword(
    VaultSession session, {
    required String currentPassword,
    required String newPassword,
  }) async {
    _requireAcceptable(newPassword);
    // Argon2id sürerken kasa kilitlenip oturumun anahtarı silinebilir. İşlem
    // kendi kopyasıyla çalışır, böylece yarım kalmadan tamamlanır.
    final vaultKey = session.vaultKey.copy();
    try {
      final (attempt, key) = await _checkPassword(
        session.header,
        currentPassword,
      );
      key?.dispose();
      if (attempt is PasswordAccepted) {
        await _rewrap(session, vaultKey, newPassword);
      }
      return attempt;
    } finally {
      vaultKey.dispose();
    }
  }

  /// Kurtarma anahtarıyla girildikten sonra yeni parolayı yazar.
  Future<void> setNewPassword(VaultSession session, String newPassword) async {
    _requireAcceptable(newPassword);
    final vaultKey = session.vaultKey.copy();
    try {
      await _rewrap(session, vaultKey, newPassword);
      await _store.resetUnlockAttempts();
    } finally {
      vaultKey.dispose();
    }
  }

  Future<BiometricSupport> biometricSupport() async {
    return await _biometric?.support() ?? BiometricSupport.unavailable;
  }

  Future<bool> isBiometricEnabled() async {
    return await _store.readBiometricSlot() != null;
  }

  /// Parmak iziyle açılabiliyorsa `true` döner.
  ///
  /// Tüm parmak izleri silindiyse anahtar zaten geçersizdir, yuva da silinir.
  Future<bool> isBiometricUsable() async {
    if (!await isBiometricEnabled()) return false;
    final support = await biometricSupport();
    if (support == BiometricSupport.notEnrolled) {
      await disableBiometric();
      return false;
    }
    return support == BiometricSupport.available;
  }

  /// Parmak iziyle açmayı etkinleştirir. Sarmalama da doğrulama gerektirir.
  Future<BiometricOutcome<void>> enableBiometric(
    VaultSession session,
    BiometricTexts texts,
  ) async {
    final bridge = _biometric;
    if (bridge == null) return const BiometricFailed();

    // Kasa anahtarının ham bayta döndüğü tek yer, bkz. tasarım belgesi.
    final plain = session.vaultKey.extractBytes();
    try {
      final outcome = await bridge.wrap(
        plain,
        VaultCrypto.biometricAssociatedData(session.header.vaultId),
        texts,
      );
      switch (outcome) {
        case BiometricSuccess(:final value):
          await _store.writeBiometricSlot(value);
          return const BiometricSuccess(null);
        case BiometricCancelled():
          return const BiometricCancelled();
        case BiometricLockedOut():
          return const BiometricLockedOut();
        case BiometricInvalidated():
          return const BiometricInvalidated();
        case BiometricFailed():
          return const BiometricFailed();
      }
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
  }

  /// Önce yuva silinir. Arada kesilirse kalan anahtar sarılmış bir şey açamaz.
  Future<void> disableBiometric() async {
    await _store.deleteBiometricSlot();
    await _biometric?.deleteKey();
  }

  /// Parmak iziyle açar. Anahtar geçersizse yuva silinir, ana parola gerekir.
  Future<BiometricOutcome<VaultSession>> unlockWithBiometric(
    VaultHeader header,
    BiometricTexts texts,
  ) async {
    final bridge = _biometric;
    final slot = await _store.readBiometricSlot();
    if (bridge == null || slot == null) return const BiometricFailed();

    final outcome = await bridge.unwrap(
      slot,
      VaultCrypto.biometricAssociatedData(header.vaultId),
      texts,
    );
    switch (outcome) {
      case BiometricSuccess(:final value):
        return await _sessionFromRawKey(header, value);
      case BiometricInvalidated():
        await disableBiometric();
        return const BiometricInvalidated();
      case BiometricCancelled():
        return const BiometricCancelled();
      case BiometricLockedOut():
        return const BiometricLockedOut();
      case BiometricFailed():
        return const BiometricFailed();
    }
  }

  Future<BiometricOutcome<VaultSession>> _sessionFromRawKey(
    VaultHeader header,
    Uint8List plain,
  ) async {
    try {
      if (plain.length != _vaultKeyLength) return const BiometricFailed();
      final session = _openSession(header, _sodium.secureCopy(plain));
      await _store.resetUnlockAttempts();
      return BiometricSuccess(session);
    } finally {
      _wipeIfPossible(plain);
    }
  }

  /// Platform kanalından gelen tampon değiştirilemez, o yüzden silinemez.
  /// Sınır güvenlik tasarımı belgesinin Biyometri bölümünde yazıyor.
  static void _wipeIfPossible(Uint8List bytes) {
    try {
      bytes.fillRange(0, bytes.length, 0);
      // Tek istisna bu: tamponun yazılamadığını başka türlü anlayamıyoruz.
      // ignore: avoid_catching_errors
    } on UnsupportedError {
      // Bu tampon yalnızca okunabilir.
    }
  }

  Future<(PasswordAttempt, SecureKey?)> _checkPassword(
    VaultHeader header,
    String password,
  ) async {
    final wait = await remainingWait();
    if (wait > Duration.zero) return (PasswordMustWait(wait), null);

    final attempts = await _store.registerFailedAttempt(_clock());
    try {
      final key = await _crypto.unlockWithPassword(header, password);
      await _store.resetUnlockAttempts();
      return (const PasswordAccepted(), key);
    } on WrongSecretException {
      return (
        PasswordRejected(UnlockBackoff.waitAfter(attempts.failedAttempts)),
        null,
      );
    }
  }

  Future<void> _rewrap(
    VaultSession session,
    SecureKey vaultKey,
    String newPassword,
  ) async {
    final opsLimit = await _kdf.calibrateOpsLimit();
    final header = await _crypto.changePassword(
      session.header,
      vaultKey,
      newPassword,
      opsLimit: opsLimit,
    );
    await _store.updateHeader(header);
    session.header = header;
  }

  VaultSession _openSession(VaultHeader header, SecureKey vaultKey) {
    return VaultSession(
      header: header,
      vaultKey: vaultKey,
      records: RecordCipher(_sodium, vaultKey, header.vaultId),
    );
  }

  static void _requireAcceptable(String password) {
    if (!PasswordPolicy.isAcceptable(password)) {
      throw ArgumentError(
        'Ana parola en az ${PasswordPolicy.minLength} '
        'karakter olmalı.',
      );
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:keykey/core/vault/biometric_bridge.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';

/// Kasanın uygulama içindeki durumu.
sealed class VaultStatus {
  const new();
}

/// Henüz kasa yok, kurulum gerekiyor.
final class VaultNotSetUp extends VaultStatus {
  const new();
}

/// Kasa var ama anahtarlar bellekte değil.
final class VaultLocked extends VaultStatus {
  const new(this.header);

  final VaultHeader header;
}

/// Kasa açık.
final class VaultOpen extends VaultStatus {
  const new(this.session);

  final VaultSession session;
}

/// Kurtarma anahtarıyla girildi, yeni parola belirlenmeden devam edilemez.
final class VaultRecovering extends VaultStatus {
  const new(this.session);

  final VaultSession session;
}

/// Kasa dosyası bozuk veya daha yeni bir sürüme ait. Dosyaya dokunulmaz.
final class VaultUnavailable extends VaultStatus {
  const new();
}

/// Uygulama başlarken `main` tarafından doldurulur.
final vaultServiceProvider = Provider<VaultService>(
  (ref) => throw UnimplementedError('VaultService sağlanmadı.'),
);

/// Uygulama başlarken `main` tarafından doldurulur.
final initialVaultStatusProvider = Provider<VaultStatus>(
  (ref) => throw UnimplementedError('Başlangıç durumu sağlanmadı.'),
);

final vaultControllerProvider = NotifierProvider<VaultController, VaultStatus>(
  VaultController.new,
);

/// Ekranların kasayla konuştuğu tek yer.
class VaultController extends Notifier<VaultStatus> {
  /// Her kilit isteğinde artar. Argon2id sürerken uygulama arka plana geçerse,
  /// işlem sonradan bitse bile kasa açılmasın diye karşılaştırılır.
  int _lockGeneration = 0;

  PendingVault? _pending;

  /// Açık oturum. `onDispose` içinde `state` okunamadığı için ayrıca tutulur.
  VaultSession? _session;

  VaultService get _service => ref.read(vaultServiceProvider);

  @override
  VaultStatus build() {
    final initial = ref.watch(initialVaultStatusProvider);
    _session = switch (initial) {
      VaultOpen(:final session) || VaultRecovering(:final session) => session,
      VaultNotSetUp() || VaultLocked() || VaultUnavailable() => null,
    };
    ref.onDispose(() {
      _session?.dispose();
      _session = null;
      cancelSetup();
    });
    return initial;
  }

  /// Kasayı bellekte oluşturur ve gösterilecek kurtarma anahtarını döndürür.
  Future<String> prepareVault(String password) async {
    cancelSetup();
    final pending = await _service.prepareVault(password);
    _pending = pending;
    return pending.recoveryKeyText;
  }

  /// Yazılan kurtarma anahtarı doğruysa kasayı kurar ve açar.
  ///
  /// Anahtar yanlışsa hata fırlatır, oluşturulan kasa beklemeye devam eder.
  Future<void> confirmSetup(String typedRecoveryKey) async {
    final pending = _pending;
    if (pending == null) throw StateError('Hazırlanmış kasa yok.');
    final generation = _lockGeneration;
    // İşlem sürerken ekran kapanırsa cancelSetup anahtarı silmesin.
    _pending = null;
    final VaultSession session;
    try {
      session = await _service.confirmRecoveryKey(pending, typedRecoveryKey);
    } on Object {
      _pending = pending;
      rethrow;
    }
    if (generation == _lockGeneration) {
      _session = session;
      state = VaultOpen(session);
    } else {
      // Kasa diske yazıldı ama uygulama bu sırada arka plana geçti.
      state = VaultLocked(session.header);
      session.dispose();
    }
  }

  /// Kullanıcı kurulumdan vazgeçti. Diskte zaten bir şey yok.
  void cancelSetup() {
    _pending?.dispose();
    _pending = null;
  }

  Future<Duration> remainingWait() => _service.remainingWait();

  Future<PasswordAttempt> unlockWithPassword(String password) async {
    final status = state;
    if (status is! VaultLocked) throw StateError('Kasa kilitli değil.');

    final generation = _lockGeneration;
    final outcome = await _service.unlockWithPassword(status.header, password);
    final session = outcome.session;
    if (session != null) {
      if (generation == _lockGeneration) {
        _session = session;
        state = VaultOpen(session);
      } else {
        session.dispose();
      }
    }
    return outcome.attempt;
  }

  /// Geçersizse hata fırlatır. Başarılıysa yeni parola belirlenmesi gerekir.
  void unlockWithRecoveryKey(String text) {
    final status = state;
    if (status is! VaultLocked) throw StateError('Kasa kilitli değil.');
    final session = _service.unlockWithRecoveryKey(status.header, text);
    _session = session;
    state = VaultRecovering(session);
  }

  /// Kurtarma anahtarıyla girdikten sonra yeni parolayı belirler.
  Future<void> setNewPassword(String password) async {
    final status = state;
    if (status is! VaultRecovering) throw StateError('Kurtarma sürmüyor.');
    final generation = _lockGeneration;
    try {
      await _service.setNewPassword(status.session, password);
    } on Object {
      // Kilit anahtarı işlem sürerken sildiyse sonuç önemsizdir: kasa kilitli.
      if (generation == _lockGeneration) rethrow;
    }
    if (generation == _lockGeneration) {
      state = VaultOpen(status.session);
    } else {
      _syncLockedHeader(status.session);
    }
  }

  Future<PasswordAttempt> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final status = state;
    if (status is! VaultOpen) throw StateError('Kasa açık değil.');
    final generation = _lockGeneration;
    try {
      return await _service.changePassword(
        status.session,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } on Object {
      if (generation == _lockGeneration) rethrow;
      return const PasswordInterrupted();
    } finally {
      if (generation != _lockGeneration) _syncLockedHeader(status.session);
    }
  }

  Future<BiometricSupport> biometricSupport() => _service.biometricSupport();

  Future<bool> isBiometricEnabled() => _service.isBiometricEnabled();

  Future<bool> isBiometricUsable() => _service.isBiometricUsable();

  Future<void> disableBiometric() => _service.disableBiometric();

  Future<BiometricOutcome<void>> enableBiometric(BiometricTexts texts) {
    final status = state;
    if (status is! VaultOpen) throw StateError('Kasa açık değil.');
    return _service.enableBiometric(status.session, texts);
  }

  Future<BiometricOutcome<void>> unlockWithBiometric(
    BiometricTexts texts,
  ) async {
    final status = state;
    if (status is! VaultLocked) throw StateError('Kasa kilitli değil.');

    final generation = _lockGeneration;
    final outcome = await _service.unlockWithBiometric(status.header, texts);
    switch (outcome) {
      case BiometricSuccess(value: final session):
        if (generation == _lockGeneration) {
          _session = session;
          state = VaultOpen(session);
        } else {
          session.dispose();
        }
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
  }

  /// Anahtarları bellekten siler. Kasa zaten kilitliyse de sürmekte olan bir
  /// açma işleminin sonucunu geçersiz kılar.
  void lock() {
    _lockGeneration++;
    final session = _session;
    if (session == null) return;
    _session = null;
    state = VaultLocked(session.header);
    session.dispose();
  }

  /// Parola yazılırken kilitlendiyse kilit durumu yeni üst bilgiyi tutmalı,
  /// yoksa uygulama yeniden başlayana kadar eski parola çalışmaya devam eder.
  void _syncLockedHeader(VaultSession session) {
    if (state is VaultLocked) state = VaultLocked(session.header);
  }
}

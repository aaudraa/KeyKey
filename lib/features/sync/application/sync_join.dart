import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/backup/application/restore_service.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';

/// Başka kasası olan telefonu senkron klasöründeki kasaya katar.
///
/// Tasarım: `resources/docs/senkron.md`, "Başka kasası olan telefonu
/// katmak". Klasördeki dosya o kasanın ana parolasıyla ya da kurtarma
/// anahtarıyla açılır; bu telefonun kayıtları yeni anahtarla şifrelenip
/// tek işlemde o kasaya katılır. Olmazsa hiçbir şey yazılmaz.
class SyncJoin {
  new({required this._restore, required this._vaults});

  final RestoreService _restore;
  final VaultService _vaults;

  /// Yeni kasanın oturumunu döndürür; [current]'ı kapatmak çağıranın işidir
  /// (bkz. [VaultController.replaceSession]). Yanlış parolada
  /// [WrongSecretException], geçersiz anahtar metninde
  /// [InvalidRecoveryKeyException]; bu telefonun bir kaydı açılmazsa
  /// [CryptoException]. Bu hallerde kasa değişmez.
  Future<VaultSession> join({
    required VaultSession current,
    required BackupFile remote,
    required String secret,
    required bool isRecoveryKey,
    required SyncSettings settings,
  }) async {
    final opened = isRecoveryKey
        ? await _restore.openWithRecoveryKey(remote, secret)
        : await _restore.openWithPassword(remote, secret);
    try {
      await _restore.join(opened, current, settings);
      // Yuva işlemde silindi; Keystore anahtarı kalsa da artık bir şey
      // açamaz. Silinemezse katılma geri alınmaz.
      try {
        await _vaults.disableBiometric();
      } on Exception {
        // Yok sayılır.
      }
      return _vaults.openRestoredSession(opened.header, opened.copyKey());
    } finally {
      opened.dispose();
    }
  }
}

final syncJoinProvider = Provider<SyncJoin>(
  (ref) => SyncJoin(
    restore: ref.watch(restoreServiceProvider),
    vaults: ref.watch(vaultServiceProvider),
  ),
);

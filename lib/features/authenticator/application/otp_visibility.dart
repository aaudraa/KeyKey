import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';

/// Kullanıcı bu oturumda kodları görmek için kimliğini doğruladı mı.
///
/// Kasa kilitlenince, yani uygulama arka plana geçince de, sıfırlanır.
final otpRevealProvider = NotifierProvider<OtpRevealController, bool>(
  OtpRevealController.new,
);

class OtpRevealController extends Notifier<bool> {
  @override
  bool build() {
    final vault = ref.read(vaultControllerProvider.notifier)
      ..addLockListener(_hide);
    ref.onDispose(() => vault.removeLockListener(_hide));
    return false;
  }

  void _hide() => state = false;

  void reveal() => state = true;
}

/// Kodlar şu an gösterilebilir mi. Ayarlar henüz okunmadıysa `null`: ek
/// onay açık olabileceği için kodlar o zaman da gösterilmez.
final otpCodesVisibleProvider = Provider<bool?>((ref) {
  final settings = ref.watch(settingsControllerProvider);
  if (settings == null) return null;
  return !settings.otpRequireAuth || ref.watch(otpRevealProvider);
});

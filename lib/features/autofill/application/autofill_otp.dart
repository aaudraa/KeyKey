import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/features/authenticator/application/otp_clock.dart';
import 'package:keykey/features/authenticator/application/otp_generator.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';

/// Açık kasada [linkedOtpCodeForFill]: doldurma ekranı depoları kendisi
/// kurmasın diye. Kasa açık değilse ya da okunamazsa `null`; hata
/// doldurmayı engellemez.
final linkedOtpCodeProvider = Provider<Future<String?> Function(Uint8List)>(
  (ref) => (loginId) async {
    final status = ref.read(vaultControllerProvider);
    if (status is! VaultOpen) return null;
    try {
      return await linkedOtpCodeForFill(
        settings: ref.read(settingsRepositoryFactoryProvider)(status.session),
        otps: ref.read(otpRepositoryFactoryProvider)(status.session),
        loginId: loginId,
        now: ref.read(otpClockProvider)(),
      );
    } on Exception {
      return null;
    }
  },
);

/// Doldurulan kayda bağlı 2FA hesabının panoya kopyalanacak kodu.
///
/// Ayar kapalıysa veya kayda bağlı, çöp kutusunda olmayan bir TOTP hesabı
/// yoksa `null` döner. HOTP'de kod üretmek sayacı ilerletir; bu yüzden
/// kendiliğinden yapılmaz. Birden çok hesap bağlıysa en eski olan seçilir.
/// Kurallar güvenlik tasarımı belgesinin "2FA kodu" bölümünde.
Future<String?> linkedOtpCodeForFill({
  required SettingsRepository settings,
  required OtpRepository otps,
  required Uint8List loginId,
  required DateTime now,
}) async {
  if (!(await settings.load()).autofillCopyOtp) return null;
  final loaded = await otps.loadAll();
  final linked = [
    for (final item in loaded.items)
      if (!item.content.isTrashed &&
          item.content.parameters.isTimeBased &&
          listEquals(item.content.loginId, loginId))
        item,
  ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  if (linked.isEmpty) return null;
  return OtpGenerator.codeFor(linked.first.content.parameters, now);
}

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:keykey/features/authenticator/application/otp_generator.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/settings/data/app_settings.dart';

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
          item.content.parameters.kind == OtpKind.totp &&
          listEquals(item.content.loginId, loginId))
        item,
  ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  if (linked.isEmpty) return null;
  return OtpGenerator.codeFor(linked.first.content.parameters, now);
}

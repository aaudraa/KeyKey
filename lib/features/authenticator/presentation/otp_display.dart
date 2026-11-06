import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Listede başlık: servis adı, yoksa hesap adı.
String otpTitle(OtpContent content, AppLocalizations l10n) {
  final issuer = content.issuer.trim();
  if (issuer.isNotEmpty) return issuer;
  final account = content.account.trim();
  return account.isNotEmpty ? account : l10n.otpUnnamed;
}

/// Başlığın altındaki hesap adı. Başlık zaten hesap adıysa `null`.
String? otpSubtitle(OtpContent content) {
  final account = content.account.trim();
  return content.issuer.trim().isEmpty || account.isEmpty ? null : account;
}

/// Kodu okunması kolay iki gruba böler: `123 456`, `1234 567`, `1234 5678`.
String formatOtpCode(String code) {
  final split = (code.length + 1) ~/ 2;
  return '${code.substring(0, split)} ${code.substring(split)}';
}

/// Hesap kimliğinin adres satırındaki hali.
String otpIdHex(OtpItem item) => loginIdHex(item.id);

/// Yüklenmiş hesaplarda kimliği arar. Hesap silinmişse `null` döner.
OtpItem? findOtp(OtpsState state, String idHex) {
  if (state is! OtpsLoaded) return null;
  for (final item in state.items) {
    if (otpIdHex(item) == idHex) return item;
  }
  return null;
}

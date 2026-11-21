import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/data/otpauth_uri.dart';

/// Bitwarden'ın `totp` alanına yazılan metin.
///
/// Bitwarden Steam hesabını yalnızca `steam://ANAHTAR` biçiminde tanır;
/// `otpauth://steam/…` bağlantısında 5 haneli sayı üretir, yani yanlış kod.
/// Öteki hesaplar ayarlarını taşıyan `otpauth://` bağlantısıyla yazılır.
String bitwardenTotp(OtpContent content) {
  final parameters = content.parameters;
  if (parameters.kind == OtpKind.steam) {
    return 'steam://${Base32.encode(parameters.secret)}';
  }
  return OtpauthUri.format(
    parameters: parameters,
    issuer: content.issuer,
    account: content.account,
  );
}

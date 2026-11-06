import 'package:keykey/features/authenticator/data/otpauth_uri.dart';

/// QR kodundan okunan metnin ne olduğu.
sealed class ScannedCode {
  const new();

  /// [text]'i sınıflandırır. Hiçbir zaman hata fırlatmaz: QR'daki metin
  /// güvenilmez veridir.
  static ScannedCode classify(String? text) {
    final trimmed = text?.trim() ?? '';
    final lower = trimmed.toLowerCase();
    if (lower.startsWith(migrationScheme)) return MigrationCode(trimmed);
    if (!lower.startsWith('otpauth://')) return const UnrelatedCode();
    try {
      return OtpauthCode(OtpauthUri.parse(trimmed));
    } on InvalidOtpauthUriException catch (error) {
      return InvalidOtpauthCode(error.error);
    }
  }

  /// Google Authenticator'ın dışa aktarma bağlantısı.
  static const migrationScheme = 'otpauth-migration://';
}

/// Tek bir 2FA hesabı.
final class OtpauthCode extends ScannedCode {
  const new(this.account);

  final OtpauthAccount account;
}

/// `otpauth://` ile başlıyor ama okunamadı.
final class InvalidOtpauthCode extends ScannedCode {
  const new(this.error);

  final OtpauthError error;
}

/// Google Authenticator dışa aktarması. İçe aktarma ekranı açar.
final class MigrationCode extends ScannedCode {
  const new(this.text);

  final String text;
}

/// 2FA ile ilgisi olmayan bir QR, örneğin bir web adresi.
final class UnrelatedCode extends ScannedCode {
  const new();
}

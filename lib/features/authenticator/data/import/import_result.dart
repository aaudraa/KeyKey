import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/data/otpauth_uri.dart';

/// Dosya veya QR bu sürümün okuyabileceği bir dışa aktarma değil.
///
/// Mesajda dosyadaki değerler bulunmaz; dosyada gizli anahtarlar olabilir.
final class InvalidImportException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => 'InvalidImportException: $message';
}

/// Şifreli dışa aktarmanın parolası yanlış veya dosya değiştirilmiş.
final class WrongImportPasswordException implements Exception {
  const new();

  @override
  String toString() => 'WrongImportPasswordException';
}

/// Başka bir uygulamadan okunan hesap. Henüz kaydedilmedi.
final class ImportedAccount {
  /// Servis ve hesap adı otpauth bağlantısındaki gibi temizlenir: denetim ve
  /// yön karakterleri bir servisi başkası gibi gösterebilir (#173, O4).
  new({
    required this.parameters,
    required String issuer,
    required String account,
    this.notes = '',
  }) : issuer = OtpauthUri.cleanName(issuer),
       account = OtpauthUri.cleanName(account);

  final OtpParameters parameters;
  final String issuer;
  final String account;
  final String notes;
}

/// Bir dosyadan veya QR'dan okunanlar.
final class ImportBatch {
  const new({
    required this.accounts,
    required this.unsupported,
    this.batchSize = 1,
  });

  final List<ImportedAccount> accounts;

  /// KeyKey'in desteklemediği için atlanan hesaplar, örneğin Yandex.
  final int unsupported;

  /// Google Authenticator büyük dışa aktarmayı bu kadar QR'a böler.
  final int batchSize;
}

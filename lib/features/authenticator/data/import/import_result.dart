import 'package:keykey/features/authenticator/data/otp_parameters.dart';

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
  const new({
    required this.parameters,
    required this.issuer,
    required this.account,
    this.notes = '',
  });

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

  /// KeyKey'in desteklemediği için atlanan hesaplar, örneğin Steam.
  final int unsupported;

  /// Google Authenticator büyük dışa aktarmayı bu kadar QR'a böler.
  final int batchSize;
}

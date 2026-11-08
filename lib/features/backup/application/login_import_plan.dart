import 'package:flutter/foundation.dart';
import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/authenticator/data/otpauth_uri.dart';
import 'package:keykey/features/backup/data/import/login_import.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

/// İçe aktarılabilecek bir kayıt.
final class LoginImportCandidate {
  const new({
    required this.content,
    required this.duplicate,
    this.otp,
    this.otpAlreadySaved = false,
  });

  final LoginContent content;

  /// Kasada adresi, kullanıcı adı ve parolası aynı bir kayıt var. Varsayılan
  /// olarak seçilmez.
  final bool duplicate;

  /// Kayda bağlanacak 2FA hesabı; kayıt eklenince bağlanır.
  final OtpContent? otp;

  /// Aynı gizli anahtar kasada zaten var; 2FA hesabı yeniden eklenmez.
  final bool otpAlreadySaved;
}

/// Dosyadan çıkarılan, kaydedilmeye hazır liste.
final class LoginImportPlan {
  const new({
    required this.source,
    required this.candidates,
    required this.skipped,
    required this.skippedOtps,
  });

  final LoginExportSource source;
  final List<LoginImportCandidate> candidates;

  /// Desteklenmeyen veya bozuk satırlar.
  final int skipped;

  /// Okunamayan veya desteklenmeyen (örneğin Steam) 2FA anahtarları. Kaydın
  /// kendisi yine eklenir.
  final int skippedOtps;
}

/// Okunan dosyayı kasadaki kayıtlarla karşılaştırıp listeyi hazırlar.
LoginImportPlan planLoginImport(
  LoginExport export, {
  required Iterable<LoginItem> existingLogins,
  required Iterable<OtpItem> existingOtps,
}) {
  final known = {for (final item in existingLogins) _fingerprint(item.content)};
  final secrets = {
    for (final item in existingOtps) _secretKey(item.content.parameters.secret),
  };
  final candidates = <LoginImportCandidate>[];
  var skippedOtps = 0;
  for (final login in export.logins) {
    final content = LoginContent(
      name: login.name,
      username: login.username,
      password: login.password,
      urls: login.urls,
      notes: login.notes,
      folder: login.folder,
      favorite: login.favorite,
      customFields: [
        for (final field in login.fields)
          LoginCustomField(
            name: field.name,
            value: field.value,
            hidden: field.hidden,
          ),
      ],
    );
    OtpContent? otp;
    final totp = login.totp;
    if (totp != null) {
      otp = otpFromImport(totp, issuer: login.name, account: login.username);
      if (otp == null) skippedOtps++;
    }
    // Aynı dosyada aynı anahtar ikinci kez geçerse o da eklenmez.
    final otpAlreadySaved =
        otp != null && !secrets.add(_secretKey(otp.parameters.secret));
    candidates.add(
      LoginImportCandidate(
        content: content,
        duplicate: known.any(
          (fingerprint) => fingerprint.matches(_fingerprint(content)),
        ),
        otp: otp,
        otpAlreadySaved: otpAlreadySaved,
      ),
    );
  }
  return LoginImportPlan(
    source: export.source,
    candidates: candidates,
    skipped: export.skipped,
    skippedOtps: skippedOtps,
  );
}

/// `otpauth://` bağlantısını veya çıplak Base32 anahtarı 2FA hesabına
/// çevirir. Okunamıyorsa veya desteklenmiyorsa (Steam) `null`.
@visibleForTesting
OtpContent? otpFromImport(
  String text, {
  required String issuer,
  required String account,
}) {
  final trimmed = text.trim();
  if (trimmed.toLowerCase().startsWith('otpauth://')) {
    try {
      final parsed = OtpauthUri.parse(trimmed);
      return OtpContent(
        parameters: parsed.parameters,
        issuer: parsed.issuer.isEmpty ? issuer : parsed.issuer,
        account: parsed.account.isEmpty ? account : parsed.account,
      );
    } on InvalidOtpauthUriException {
      return null;
    }
  }
  final List<int> secret;
  try {
    secret = Base32.decodeLenient(trimmed);
  } on FormatException {
    // steam:// ve diğer biçimler de buraya düşer.
    return null;
  }
  if (!OtpParameters.isValidSecretLength(secret.length)) return null;
  return OtpContent(
    parameters: OtpParameters.totp(secret: secret),
    issuer: issuer,
    account: account,
  );
}

String _secretKey(List<int> secret) => secret.join(',');

/// Yinelenen kayıt karşılaştırması: kullanıcı adı ve parola aynı, adreslerden
/// biri ortak ya da ikisinde de adres yok.
final class _Fingerprint {
  const new(this.username, this.password, this.urls);

  final String username;
  final String password;
  final Set<String> urls;

  bool matches(_Fingerprint other) =>
      username == other.username &&
      password == other.password &&
      (urls.isEmpty && other.urls.isEmpty || urls.any(other.urls.contains));
}

_Fingerprint _fingerprint(LoginContent content) => _Fingerprint(
  content.username.trim(),
  content.password,
  {for (final url in content.urls) _normalizeUrl(url)},
);

String _normalizeUrl(String url) {
  var value = url.trim().toLowerCase();
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

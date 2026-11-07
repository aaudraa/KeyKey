import 'package:flutter/foundation.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/authenticator/data/otpauth_uri.dart';
import 'package:keykey/features/backup/data/export/csv_writer.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

/// Kasayı Bitwarden'ın CSV biçiminde şifresiz dışa aktarır.
///
/// Kurallar güvenlik tasarımı belgesinin "Düz metin dışa aktarma"
/// bölümünde. Çöp kutusundakiler ve parola geçmişi yazılmaz. Bir kayda bağlı
/// 2FA hesabı o kaydın `login_totp` sütununa, bağlı olmayanlar ayrı satırlara
/// yazılır.
abstract final class BitwardenCsvExport {
  static const columns = [
    'folder',
    'favorite',
    'type',
    'name',
    'notes',
    'fields',
    'reprompt',
    'login_uri',
    'login_username',
    'login_password',
    'login_totp',
  ];

  static String build({
    required Iterable<LoginItem> logins,
    required Iterable<OtpItem> otps,
  }) {
    final liveLogins = [
      for (final item in logins)
        if (!item.content.isTrashed) item,
    ];
    final liveOtps = [
      for (final item in otps)
        if (!item.content.isTrashed) item,
    ];
    // Her kayda en fazla bir 2FA hesabı yazılabilir; fazlası ayrı satıra
    // düşer.
    final linked = <OtpItem>{};
    final rows = <List<String>>[columns];
    for (final login in liveLogins) {
      OtpItem? otp;
      for (final candidate in liveOtps) {
        if (!linked.contains(candidate) &&
            listEquals(candidate.content.loginId, login.id)) {
          otp = candidate;
          break;
        }
      }
      if (otp != null) linked.add(otp);
      final content = login.content;
      rows.add([
        content.folder ?? '',
        if (content.favorite) '1' else '',
        'login',
        content.name,
        content.notes,
        [
          for (final field in content.customFields)
            '${field.name}: ${field.value}',
        ].join('\n'),
        '0',
        _uris([
          ...content.urls,
          for (final app in content.apps) 'androidapp://${app.packageName}',
        ]),
        content.username,
        content.password,
        if (otp == null) '' else _otpauth(otp),
      ]);
    }
    for (final otp in liveOtps) {
      if (linked.contains(otp)) continue;
      final content = otp.content;
      rows.add([
        '',
        if (content.favorite) '1' else '',
        'login',
        if (content.issuer.isNotEmpty) content.issuer else content.account,
        content.notes,
        '',
        '0',
        '',
        content.account,
        '',
        _otpauth(otp),
      ]);
    }
    return CsvWriter.write(rows);
  }

  /// Birden çok adres, Bitwarden'ın yaptığı gibi alanın içinde ayrı bir CSV
  /// satırı olarak yazılır; okuyucu da öyle ayırır.
  static String _uris(List<String> uris) {
    if (uris.isEmpty) return '';
    final row = CsvWriter.write([uris]);
    return row.substring(0, row.length - 2);
  }

  static String _otpauth(OtpItem item) => OtpauthUri.format(
    parameters: item.content.parameters,
    issuer: item.content.issuer,
    account: item.content.account,
  );
}

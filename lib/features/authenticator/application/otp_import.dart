import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:keykey/features/authenticator/data/import/aegis_import.dart';
import 'package:keykey/features/authenticator/data/import/aes_gcm.dart';
import 'package:keykey/features/authenticator/data/import/google_migration.dart';
import 'package:keykey/features/authenticator/data/import/import_result.dart';
import 'package:keykey/features/authenticator/data/import/twofas_import.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';

/// Seçilen dosya tanınan bir dışa aktarma biçiminde değil.
final class UnknownImportFileException implements Exception {
  const new();

  @override
  String toString() => 'UnknownImportFileException';
}

/// İçe aktarma ekranının açtığı kaynak.
sealed class ImportSource {
  const new();

  /// Aegis veya 2FAS dosyasını tanır. İkisi de değilse
  /// [UnknownImportFileException].
  ///
  /// Biçim tanındıktan sonra içerik bozuksa [InvalidImportException]
  /// fırlatır; kullanıcıya "bu dosya değil" yerine "dosya bozuk" denir.
  static ImportSource fromFile(Uint8List bytes, AesGcmDecrypter aes) {
    final aegis = _tryParse(() => AegisFile.parse(bytes));
    if (aegis != null) {
      return aegis.isEncrypted
          ? EncryptedImport((password) => aegis.decrypt(password, aes))
          : ReadyImport(aegis.accounts());
    }
    final twofas = _tryParse(() => TwoFasFile.parse(bytes));
    if (twofas != null) {
      return twofas.isEncrypted
          ? EncryptedImport((password) => twofas.decrypt(password, aes))
          : ReadyImport(twofas.accounts());
    }
    throw const UnknownImportFileException();
  }

  static T? _tryParse<T>(T Function() parse) {
    try {
      return parse();
    } on InvalidImportException {
      return null;
    }
  }

  /// Google Authenticator'ın dışa aktarma QR'ı. Bozuksa
  /// [InvalidImportException].
  static ImportSource fromMigration(String text) =>
      ReadyImport(GoogleMigration.parse(text));
}

/// Hesaplar okundu.
final class ReadyImport extends ImportSource {
  const new(this.batch);

  final ImportBatch batch;
}

/// Dosya şifreli, önce parola gerekiyor.
final class EncryptedImport extends ImportSource {
  const new(this.decrypt);

  /// Parola yanlışsa [WrongImportPasswordException], içerik bozuksa
  /// [InvalidImportException].
  final Future<ImportBatch> Function(String password) decrypt;
}

/// [account]'un gizli anahtarı zaten kayıtlıysa, çöp kutusunda bile olsa,
/// tekrar eklenmez.
bool isAlreadyAdded(ImportedAccount account, Iterable<OtpItem> existing) {
  final secret = account.parameters.secret;
  for (final item in existing) {
    final parameters = item.content.parameters;
    if (parameters.kind == account.parameters.kind &&
        listEquals(parameters.secret, secret)) {
      return true;
    }
  }
  return false;
}

/// Kaydedilecek içerik.
OtpContent contentOf(ImportedAccount account) => OtpContent(
  parameters: account.parameters,
  issuer: account.issuer,
  account: account.account,
  notes: account.notes,
);

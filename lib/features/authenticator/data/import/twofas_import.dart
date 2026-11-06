import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:keykey/features/authenticator/data/import/aes_gcm.dart';
import 'package:keykey/features/authenticator/data/import/import_json.dart';
import 'package:keykey/features/authenticator/data/import/import_kdf.dart';
import 'package:keykey/features/authenticator/data/import/import_result.dart';

/// 2FAS'ın dışa aktardığı `.2fas` dosyası.
///
/// Parolalı dosyada hesaplar `servicesEncrypted` alanındadır:
/// `Base64(şifreli metin ve etiket):Base64(tuz):Base64(IV)`. Anahtar
/// PBKDF2-HMAC-SHA256 ile 10 000 turda türetilir, şifre AES-256-GCM'dir.
final class TwoFasFile {
  new _(this._root);

  /// Dosyayı okur. 2FAS dosyası değilse [InvalidImportException].
  factory parse(Uint8List bytes) {
    final root = ImportJson.decodeObject(bytes);
    if (ImportJson.integer(root['schemaVersion']) == null ||
        !(root['services'] is List<Object?> ||
            root['servicesEncrypted'] is String)) {
      throw const InvalidImportException('2FAS dosyası değil.');
    }
    return TwoFasFile._(root);
  }

  static const pbkdf2Iterations = 10000;

  final Map<String, Object?> _root;

  bool get isEncrypted => _root['servicesEncrypted'] is String;

  ImportBatch accounts() {
    final services = _root['services'];
    if (isEncrypted || services is! List<Object?>) {
      throw const InvalidImportException('Dosya şifreli.');
    }
    return _services(services);
  }

  /// Parolalı dosyayı açar. Parola yanlışsa [WrongImportPasswordException].
  Future<ImportBatch> decrypt(String password, AesGcmDecrypter aes) async {
    final parts = ImportJson.string(_root['servicesEncrypted']).split(':');
    if (parts.length < 3) {
      throw const InvalidImportException('Eksik şifreleme bilgisi.');
    }
    final cipherText = ImportJson.base64Value(parts[0]);
    final salt = ImportJson.base64Value(parts[1]);
    final nonce = ImportJson.base64Value(parts[2]);
    final passwordBytes = utf8.encode(password);
    final key = await Isolate.run(
      () => ImportKdf.pbkdf2Sha256(
        password: passwordBytes,
        salt: salt,
        iterations: pbkdf2Iterations,
        length: 32,
      ),
    );
    passwordBytes.fillRange(0, passwordBytes.length, 0);
    final Uint8List? plain;
    try {
      plain = await aes.decrypt(
        key: key,
        nonce: nonce,
        cipherTextWithTag: cipherText,
      );
    } finally {
      key.fillRange(0, key.length, 0);
    }
    if (plain == null) throw const WrongImportPasswordException();
    final services = ImportJson.decode(plain);
    plain.fillRange(0, plain.length, 0);
    if (services is! List<Object?>) {
      throw const InvalidImportException('Geçersiz hesap listesi.');
    }
    return _services(services);
  }

  static ImportBatch _services(List<Object?> services) {
    final accounts = <ImportedAccount>[];
    var unsupported = 0;
    for (final value in services) {
      final service = ImportJson.object(value);
      final otp = ImportJson.object(service?['otp']) ?? const {};
      final parameters = service == null
          ? null
          : ImportJson.parameters(
              type: switch (otp['tokenType']) {
                final String type => type,
                _ => 'TOTP',
              },
              secret: service['secret'],
              algorithm: otp['algorithm'],
              digits: otp['digits'],
              period: otp['period'],
              counter: otp['counter'],
            );
      if (service == null || parameters == null) {
        unsupported++;
        continue;
      }
      final issuer = ImportJson.string(otp['issuer']).trim();
      final account = ImportJson.string(otp['account']).trim();
      accounts.add(
        ImportedAccount(
          parameters: parameters,
          issuer: issuer.isNotEmpty
              ? issuer
              : ImportJson.string(service['name']).trim(),
          account: account.isNotEmpty
              ? account
              : ImportJson.string(otp['label']).trim(),
        ),
      );
    }
    return ImportBatch(accounts: accounts, unsupported: unsupported);
  }
}

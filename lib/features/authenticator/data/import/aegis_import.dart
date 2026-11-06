import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:keykey/features/authenticator/data/import/aes_gcm.dart';
import 'package:keykey/features/authenticator/data/import/import_json.dart';
import 'package:keykey/features/authenticator/data/import/import_kdf.dart';
import 'package:keykey/features/authenticator/data/import/import_result.dart';

/// Aegis'in dışa aktardığı JSON dosyası.
///
/// Biçim Aegis'in `docs/vault.md` belgesindedir. Şifreli dosyada her parola
/// yuvası scrypt ile türetilen anahtarla ana anahtarı sarar, kayıtlar ana
/// anahtarla AES-256-GCM ile şifrelidir.
final class AegisFile {
  new _(this._root);

  /// Dosyayı okur. Aegis dosyası değilse [InvalidImportException].
  factory parse(Uint8List bytes) {
    final root = ImportJson.decodeObject(bytes);
    final header = ImportJson.object(root['header']);
    if (root['version'] != 1 || header == null || !root.containsKey('db')) {
      throw const InvalidImportException('Aegis dosyası değil.');
    }
    return AegisFile._(root);
  }

  final Map<String, Object?> _root;

  bool get isEncrypted => _root['db'] is String;

  /// Şifresiz dosyanın hesapları.
  ImportBatch accounts() {
    final db = ImportJson.object(_root['db']);
    if (db == null) {
      throw const InvalidImportException('Dosya şifreli.');
    }
    return _entries(db);
  }

  /// Şifreli dosyayı [password] ile açar.
  ///
  /// Parola hiçbir yuvayı açmıyorsa [WrongImportPasswordException]. scrypt
  /// birkaç yüz milisaniye sürer, ayrı isolate'te çalışır.
  Future<ImportBatch> decrypt(String password, AesGcmDecrypter aes) async {
    final header = ImportJson.object(_root['header'])!;
    final params = ImportJson.object(header['params']);
    final slots = header['slots'];
    final db = _root['db'];
    if (params == null || slots is! List<Object?> || db is! String) {
      throw const InvalidImportException('Eksik şifreleme bilgisi.');
    }
    final passwordBytes = utf8.encode(password);
    try {
      Uint8List? masterKey;
      for (final slot in slots) {
        final map = ImportJson.object(slot);
        // Tür 1 parola yuvasıdır; parmak izi ve ham yuvalar bu cihazda açılmaz.
        if (map == null || map['type'] != 1) continue;
        masterKey = await _openSlot(map, passwordBytes, aes);
        if (masterKey != null) break;
      }
      if (masterKey == null) throw const WrongImportPasswordException();

      final plain = await aes.decrypt(
        key: masterKey,
        nonce: ImportJson.hex(params['nonce']),
        cipherTextWithTag: Uint8List.fromList([
          ...ImportJson.base64Value(db),
          ...ImportJson.hex(params['tag']),
        ]),
      );
      masterKey.fillRange(0, masterKey.length, 0);
      if (plain == null) throw const WrongImportPasswordException();
      final decoded = ImportJson.object(ImportJson.decode(plain));
      plain.fillRange(0, plain.length, 0);
      if (decoded == null) {
        throw const InvalidImportException('Geçersiz kasa içeriği.');
      }
      return _entries(decoded);
    } finally {
      passwordBytes.fillRange(0, passwordBytes.length, 0);
    }
  }

  static Future<Uint8List?> _openSlot(
    Map<String, Object?> slot,
    Uint8List password,
    AesGcmDecrypter aes,
  ) async {
    final n = ImportJson.integer(slot['n']);
    final r = ImportJson.integer(slot['r']);
    final p = ImportJson.integer(slot['p']);
    final keyParams = ImportJson.object(slot['key_params']);
    if (n == null || r == null || p == null || keyParams == null) {
      throw const InvalidImportException('Eksik yuva bilgisi.');
    }
    if (!ImportKdf.isValidScrypt(n: n, r: r, p: p)) {
      throw const InvalidImportException('Geçersiz scrypt parametreleri.');
    }
    final salt = ImportJson.hex(slot['salt']);
    final derived = await Isolate.run(
      () => ImportKdf.scrypt(
        password: password,
        salt: salt,
        n: n,
        r: r,
        p: p,
        length: 32,
      ),
    );
    try {
      return await aes.decrypt(
        key: derived,
        nonce: ImportJson.hex(keyParams['nonce']),
        cipherTextWithTag: Uint8List.fromList([
          ...ImportJson.hex(slot['key']),
          ...ImportJson.hex(keyParams['tag']),
        ]),
      );
    } finally {
      derived.fillRange(0, derived.length, 0);
    }
  }

  static ImportBatch _entries(Map<String, Object?> db) {
    final entries = db['entries'];
    if (entries is! List<Object?>) {
      throw const InvalidImportException('Kayıt listesi yok.');
    }
    final accounts = <ImportedAccount>[];
    var unsupported = 0;
    for (final value in entries) {
      final entry = ImportJson.object(value);
      final info = ImportJson.object(entry?['info']);
      final parameters = entry == null || info == null
          ? null
          : ImportJson.parameters(
              type: ImportJson.string(entry['type']),
              secret: info['secret'],
              algorithm: info['algo'],
              digits: info['digits'],
              period: info['period'],
              counter: info['counter'],
            );
      if (entry == null || parameters == null) {
        unsupported++;
        continue;
      }
      accounts.add(
        ImportedAccount(
          parameters: parameters,
          issuer: ImportJson.string(entry['issuer']).trim(),
          account: ImportJson.string(entry['name']).trim(),
          notes: ImportJson.string(entry['note']),
        ),
      );
    }
    return ImportBatch(accounts: accounts, unsupported: unsupported);
  }
}

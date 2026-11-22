import 'dart:isolate';
import 'dart:typed_data';

import 'package:keykey/features/backup/data/import/kdbx/kdbx_exception.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_header.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_import.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_kdf.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_key.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_payload.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_xml.dart';
import 'package:keykey/features/backup/data/import/login_import.dart';

/// KeePass (`.kdbx`) dosyasını açar ve kayıtlarını içe aktarma önizlemesinin
/// biçiminde verir.
///
/// Yalnızca [KdbxException] alt türlerini fırlatır. Anahtar türetme `kdf`
/// ile (uygulamada telefonun yerel kodu), şifre çözme ve XML ayrı bir
/// isolate'te yapılır; arayüz donmaz. Kurallar KeePass içe aktarma
/// tasarımında.
abstract final class KdbxReader {
  /// Seçilen dosya Kotlin'den Pigeon'la geçerken Java yığınında birkaç
  /// kopya olur; yığın sınırı 192 MB olan telefonlarda 64 MiB'lık dosya
  /// uygulamayı düşürebilir.
  static const int maxBytes = 32 * 1024 * 1024;

  /// [password] `null` ise kutu boştur: anahtar dosyası varsa önce yalnız
  /// onunla, tutmazsa boş parolayla da denenir; anahtar dosyası da yoksa
  /// boş parola kullanılır.
  static Future<LoginExport> open(
    Uint8List file, {
    required KdbxKdf kdf,
    String? password,
    Uint8List? keyFileKey,
  }) async {
    try {
      return await _open(
        file,
        kdf: kdf,
        password: password,
        keyFileKey: keyFileKey,
      );
    } on KdbxException {
      rethrow;
    } on Object {
      // Ekran yalnızca KdbxException bekler. Başka bir hata (ayrıştırıcıdaki
      // bir hata, isolate'te bellek yetmemesi) açılıyor ekranında takılı
      // bırakmasın. Ayrıntısı günlüğe yazılmaz; sır içerebilir.
      throw const KdbxCorrupt();
    }
  }

  static Future<LoginExport> _open(
    Uint8List file, {
    required KdbxKdf kdf,
    String? password,
    Uint8List? keyFileKey,
  }) async {
    if (file.length > maxBytes) throw const KdbxTooHeavy();
    final header = KdbxHeader.parse(file);
    final attempts = [
      if (password != null)
        (password: password, keyFile: keyFileKey)
      else if (keyFileKey != null) ...[
        (password: null, keyFile: keyFileKey),
        (password: '', keyFile: keyFileKey),
      ] else
        (password: '', keyFile: null),
    ];
    for (final (index, attempt) in attempts.indexed) {
      final composite = compositeKey(
        password: attempt.password,
        keyFileKey: attempt.keyFile,
      );
      final Uint8List transformed;
      try {
        transformed = await transformKey(header, composite, kdf);
      } finally {
        composite.fillRange(0, composite.length, 0);
      }
      try {
        return await Isolate.run(() => _decode(file, transformed));
      } on KdbxWrongKey {
        if (index == attempts.length - 1) rethrow;
      } finally {
        transformed.fillRange(0, transformed.length, 0);
      }
    }
    throw const KdbxWrongKey();
  }

  /// Ayrı isolate'te çalışır; [file] ve [transformedKey] buradaki
  /// kopyalardır ve işi bitince sıfırlanır.
  static LoginExport _decode(Uint8List file, Uint8List transformedKey) {
    try {
      final header = KdbxHeader.parse(file);
      final payload = decryptPayload(file, header, transformedKey);
      try {
        final db = parseKdbxXml(
          payload,
          headerBytes: header.bytes,
          majorVersion: header.majorVersion,
        );
        return kdbxToLoginExport(db);
      } finally {
        payload.wipe();
      }
    } finally {
      file.fillRange(0, file.length, 0);
      transformedKey.fillRange(0, transformedKey.length, 0);
    }
  }
}

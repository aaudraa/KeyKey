import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_bytes.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_exception.dart';
import 'package:xml/xml.dart';

/// Anahtar dosyasının okunacak en büyük boyutu.
const int maxKeyFileBytes = 16 * 1024 * 1024;

/// KeePass anahtar dosyasından 32 baytlık anahtar, KeePass'ın sırasıyla:
/// XML (`KeyFile`, sürüm 1.0 Base64, 2.0 onaltılık ve özet), tam 32 bayt,
/// tam 64 onaltılık karakter, başka her şey için dosyanın SHA-256'sı.
Uint8List keyFileKey(Uint8List file) {
  if (file.length > maxKeyFileBytes) throw const KdbxCorrupt();
  final xml = _xmlKey(file);
  if (xml != null) return xml;
  if (file.length == 32) return Uint8List.fromList(file);
  if (file.length == 64) {
    final hex = _hexDecode(String.fromCharCodes(file));
    if (hex != null) return hex;
  }
  return Uint8List.fromList(sha256.convert(file).bytes);
}

/// KeePass'ın bileşik anahtarı: `SHA-256(SHA-256(parola) ‖ anahtar dosyası)`.
/// Boş parola (`''`) bir bileşendir; `null` parola yok demektir.
Uint8List compositeKey({String? password, Uint8List? keyFileKey}) {
  if (password == null && keyFileKey == null) {
    throw ArgumentError('Parola ya da anahtar dosyası gerekir.');
  }
  final parts = BytesBuilder(copy: false);
  if (password != null) parts.add(sha256.convert(utf8.encode(password)).bytes);
  if (keyFileKey != null) parts.add(keyFileKey);
  final joined = parts.takeBytes();
  final result = Uint8List.fromList(sha256.convert(joined).bytes);
  joined.fillRange(0, joined.length, 0);
  return result;
}

/// XML anahtar dosyası değilse `null`; `KeyFile` ama okunamıyorsa
/// [KdbxKeyFileCorrupt].
Uint8List? _xmlKey(Uint8List file) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(utf8.decode(file));
  } on Object {
    // UTF-8 ya da XML değil.
    return null;
  }
  final root = document.rootElement;
  if (root.name.local != 'KeyFile') return null;
  final version = root
      .getElement('Meta')
      ?.getElement('Version')
      ?.innerText
      .trim();
  final data = root.getElement('Key')?.getElement('Data');
  if (data == null) throw const KdbxKeyFileCorrupt();
  final text = data.innerText.replaceAll(RegExp(r'\s'), '');
  switch (version) {
    case '1.0' || '1.00':
      final Uint8List key;
      try {
        key = base64.decode(text);
      } on FormatException {
        throw const KdbxKeyFileCorrupt();
      }
      if (key.length != 32) throw const KdbxKeyFileCorrupt();
      return key;
    case '2.0' || '2.00':
      final key = _hexDecode(text);
      if (key == null || key.length != 32) throw const KdbxKeyFileCorrupt();
      final hash = data.getAttribute('Hash');
      if (hash != null) {
        final expected = _hexDecode(hash);
        final actual = sha256.convert(key).bytes.sublist(0, 4);
        if (expected == null || !kdbxBytesEqual(expected, actual)) {
          throw const KdbxKeyFileCorrupt();
        }
      }
      return key;
    default:
      throw const KdbxKeyFileCorrupt();
  }
}

Uint8List? _hexDecode(String text) {
  if (text.length.isOdd || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(text)) {
    return null;
  }
  return Uint8List.fromList([
    for (var i = 0; i < text.length; i += 2)
      int.parse(text.substring(i, i + 2), radix: 16),
  ]);
}

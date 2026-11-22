import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_bytes.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_cipher.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_exception.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_payload.dart';
import 'package:xml/xml.dart';

/// KeePass kaydı, XML'den okunduğu gibi.
final class KdbxEntry {
  const new({
    required this.uuid,
    required this.groupPath,
    required this.strings,
    required this.attachments,
  });

  /// Büyük harf onaltılık, alan başvurularındaki biçimde.
  final String uuid;

  /// Kök grup hariç grup adları.
  final List<String> groupPath;

  /// Alan adı → değer; dosyadaki sırasıyla.
  final Map<String, ({String value, bool protected})> strings;

  final int attachments;
}

/// Çöp kutusu dışındaki kayıtlar.
final class KdbxDatabase {
  const new({required this.entries, required this.recycledEntries});

  final List<KdbxEntry> entries;
  final int recycledEntries;
}

/// Açılmış XML'i okur. Korumalı değerler belge sırasıyla iç akışla çözülür:
/// `Protected="True"` taşıyan her öğe, adına bakılmaksızın, kayıt
/// geçmişindekiler de akıştan pay alır. KDBX 2 ve 3'te `Meta/HeaderHash`
/// varsa başlıkla karşılaştırılır.
KdbxDatabase parseKdbxXml(
  KdbxPayload payload, {
  required Uint8List headerBytes,
  required int majorVersion,
}) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(utf8.decode(payload.xml));
  } on Object {
    // FormatException (UTF-8) ya da XmlException.
    throw const KdbxCorrupt();
  }
  final file = document.rootElement;
  if (file.name.local != 'KeePassFile') throw const KdbxCorrupt();
  final meta = file.getElement('Meta');

  if (majorVersion < 4) {
    final stored = meta?.getElement('HeaderHash')?.innerText.trim();
    if (stored != null && stored.isNotEmpty) {
      final hash = _base64(stored);
      if (!kdbxBytesEqual(hash, sha256.convert(headerBytes).bytes)) {
        throw const KdbxCorrupt();
      }
    }
  }

  final protectedValues = _decryptProtected(document, payload);

  final recycleBinEnabled =
      meta?.getElement('RecycleBinEnabled')?.innerText.trim().toLowerCase() ==
      'true';
  final recycleBin = recycleBinEnabled
      ? meta?.getElement('RecycleBinUUID')?.innerText.trim()
      : null;

  final root = file.getElement('Root')?.getElement('Group');
  if (root == null) throw const KdbxCorrupt();
  final entries = <KdbxEntry>[];
  var recycled = 0;

  void walk(XmlElement group, List<String> path, {required bool inBin}) {
    for (final child in group.childElements) {
      switch (child.name.local) {
        case 'Entry':
          if (inBin) {
            recycled++;
          } else {
            entries.add(_entry(child, path, protectedValues));
          }
        case 'Group':
          final uuid = child.getElement('UUID')?.innerText.trim();
          final name = child.getElement('Name')?.innerText ?? '';
          walk(child, [
            ...path,
            name,
          ], inBin: inBin || (recycleBin != null && uuid == recycleBin));
      }
    }
  }

  walk(root, const [], inBin: false);
  return KdbxDatabase(entries: entries, recycledEntries: recycled);
}

KdbxEntry _entry(
  XmlElement entry,
  List<String> path,
  Map<XmlElement, String> protectedValues,
) {
  final strings = <String, ({String value, bool protected})>{};
  var attachments = 0;
  for (final child in entry.childElements) {
    switch (child.name.local) {
      case 'String':
        final key = child.getElement('Key')?.innerText;
        final value = child.getElement('Value');
        if (key == null || value == null) continue;
        final decrypted = protectedValues[value];
        strings[key] = decrypted != null
            ? (value: decrypted, protected: true)
            : (value: value.innerText, protected: false);
      case 'Binary':
        attachments++;
    }
  }
  final uuid = entry.getElement('UUID')?.innerText.trim() ?? '';
  return KdbxEntry(
    uuid: kdbxHex(_base64(uuid)).toUpperCase(),
    groupPath: List.unmodifiable(path),
    strings: strings,
    attachments: attachments,
  );
}

/// Korumalı her öğenin çözülmüş metni; belge sırasıyla.
Map<XmlElement, String> _decryptProtected(
  XmlDocument document,
  KdbxPayload payload,
) {
  final stream = KdbxInnerStream(payload.innerStreamId, payload.innerStreamKey);
  final values = <XmlElement, String>{};
  for (final element in document.descendantElements) {
    if (element.getAttribute('Protected')?.toLowerCase() != 'true') continue;
    final plain = stream.apply(_base64(element.innerText.trim()));
    // Yalnızca metin alanları kullanılır; ekler akıştan pay alıp atılır.
    if (element.name.local == 'Value' &&
        element.parentElement?.name.local == 'String') {
      try {
        values[element] = utf8.decode(plain);
      } on FormatException {
        throw const KdbxCorrupt();
      }
    }
    plain.fillRange(0, plain.length, 0);
  }
  return values;
}

Uint8List _base64(String text) {
  try {
    return base64.decode(text);
  } on FormatException {
    throw const KdbxCorrupt();
  }
}

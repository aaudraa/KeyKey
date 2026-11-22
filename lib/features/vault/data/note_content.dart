import 'dart:convert';
import 'dart:typed_data';

import 'package:keykey/features/vault/data/record_content.dart';

/// Güvenli not kaydının şifreli içeriği. Biçim güvenlik tasarımı belgesinde.
final class NoteContent implements VaultItemContent<NoteContent> {
  /// [text] [maxTextBytes]'ı aşarsa [ArgumentError].
  new({
    required this.name,
    this.text = '',
    this.favorite = false,
    this.folder,
    this.trashedAt,
  }) {
    if (!fitsTextLimit(text)) throw ArgumentError('Not çok uzun.');
  }

  /// JSON baytlarını katı kurallarla okur.
  ///
  /// Bilinmeyen sürüm, eksik veya fazla alan, yanlış tür ya da sınırı aşan
  /// metin [InvalidRecordContentException] fırlatır.
  factory fromJsonBytes(Uint8List bytes) {
    final decoded = StrictJson.decode(bytes);
    final version = decoded is Map<String, Object?> ? decoded['version'] : null;
    if (version != currentVersion) {
      throw const InvalidRecordContentException('Desteklenmeyen sürüm.');
    }
    final root = StrictJson.object(decoded, _keys);
    final text = StrictJson.string(root['text'], 'text');
    if (!fitsTextLimit(text)) {
      throw const InvalidRecordContentException('Geçersiz alan: text');
    }
    return NoteContent(
      name: StrictJson.string(root['name'], 'name'),
      text: text,
      favorite: StrictJson.boolean(root['favorite'], 'favorite'),
      folder: StrictJson.nullableString(root['folder'], 'folder'),
      trashedAt: StrictJson.nullableTime(root['trashedAt'], 'trashedAt'),
    );
  }

  static const currentVersion = 1;

  /// Metnin UTF-8 olarak en büyük boyutu (64 KiB).
  static const maxTextBytes = 65536;

  static const _keys = {
    'version',
    'name',
    'text',
    'favorite',
    'folder',
    'trashedAt',
  };

  /// Sınır karakter değil bayt üzerindendir; Türkçe harfler iki bayttır.
  static bool fitsTextLimit(String text) =>
      // Her UTF-16 birimi en çok 3 bayt olur; kısa metinde kodlamaya gerek yok.
      text.length * 3 <= maxTextBytes ||
      utf8.encode(text).length <= maxTextBytes;

  @override
  final String name;
  final String text;
  @override
  final bool favorite;
  @override
  final String? folder;
  @override
  final DateTime? trashedAt;

  @override
  bool get isTrashed => trashedAt != null;

  @override
  Uint8List toJsonBytes() => utf8.encode(
    jsonEncode({
      'version': currentVersion,
      'name': name,
      'text': text,
      'favorite': favorite,
      'folder': folder,
      'trashedAt': trashedAt?.millisecondsSinceEpoch,
    }),
  );

  /// [folder] ve [trashedAt] verilmezse korunur, `null` verilirse temizlenir.
  NoteContent copyWith({
    String? name,
    String? text,
    bool? favorite,
    Object? folder = keepValue,
    Object? trashedAt = keepValue,
  }) {
    return NoteContent(
      name: name ?? this.name,
      text: text ?? this.text,
      favorite: favorite ?? this.favorite,
      folder: identical(folder, keepValue) ? this.folder : folder as String?,
      trashedAt: identical(trashedAt, keepValue)
          ? this.trashedAt
          : trashedAt as DateTime?,
    );
  }

  /// Düzenleme formunun içeriğini kaydın en son haline uygular: formda
  /// dokunulmayan alanlar [latest]'teki gibi kalır (form açıkken senkron
  /// değiştirmiş olabilir). Sık kullanılan ve çöp durumu hep [latest]'ten.
  NoteContent rebase({
    required NoteContent original,
    required NoteContent latest,
  }) => latest.copyWith(
    name: name == original.name ? latest.name : name,
    text: text == original.text ? latest.text : text,
    folder: folder == original.folder ? latest.folder : folder,
  );

  @override
  NoteContent withFavorite({required bool favorite}) =>
      copyWith(favorite: favorite);

  @override
  NoteContent withTrashedAt(DateTime? trashedAt) =>
      copyWith(trashedAt: trashedAt);

  @override
  NoteContent withFolder(String? folder) => copyWith(folder: folder);
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:keykey/features/backup/data/import/csv_reader.dart';

/// Dosya tanınan bir parola dışa aktarma biçiminde değil.
final class UnknownLoginExportException implements Exception {
  const new();
}

/// Bitwarden'ın parola korumalı veya hesaba bağlı şifreli dışa aktarması.
final class EncryptedBitwardenExportException implements Exception {
  const new();
}

/// Desteklenen kaynaklar.
enum LoginExportSource { bitwardenJson, bitwardenCsv, chromeCsv, keepassxcCsv }

/// Başka bir uygulamadan okunan bir giriş kaydı.
final class ImportedLogin {
  const new({
    required this.name,
    this.username = '',
    this.password = '',
    this.urls = const [],
    this.notes = '',
    this.folder,
    this.favorite = false,
    this.fields = const [],
    this.totp,
  });

  final String name;
  final String username;
  final String password;
  final List<String> urls;
  final String notes;
  final String? folder;
  final bool favorite;
  final List<({String name, String value, bool hidden})> fields;

  /// `otpauth://` bağlantısı veya çıplak Base32 anahtar; yoksa `null`.
  final String? totp;
}

/// Okunan dosyanın sonucu.
final class LoginExport {
  const new({
    required this.source,
    required this.logins,
    required this.skipped,
  });

  final LoginExportSource source;
  final List<ImportedLogin> logins;

  /// Desteklenmeyen (kart, not, kimlik) veya bozuk satırların sayısı.
  final int skipped;
}

/// Bitwarden (JSON, CSV), Chrome (CSV) ve KeePassXC (CSV) dışa aktarmalarını
/// okur.
///
/// Dosyalar güvenilmeyen veri sayılır: bilinmeyen alanlar yok sayılır,
/// bozuk satır atlanır, yalnızca bu dosyadaki hata türleri fırlatılır.
/// Kurallar güvenlik tasarımı belgesinin "Parola içe aktarma" bölümünde.
abstract final class LoginExportReader {
  static const int maxBytes = 10 * 1024 * 1024;

  static LoginExport read(Uint8List bytes) {
    if (bytes.length > maxBytes) throw const UnknownLoginExportException();
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const UnknownLoginExportException();
    }
    final trimmed = text.replaceFirst('﻿', '').trimLeft();
    if (trimmed.startsWith('{')) return _bitwardenJson(trimmed);
    final List<List<String>> rows;
    try {
      rows = CsvReader.read(text);
    } on CsvFormatException {
      throw const UnknownLoginExportException();
    }
    if (rows.isEmpty) throw const UnknownLoginExportException();
    final header = [for (final cell in rows.first) cell.trim().toLowerCase()];
    final columns = {for (final (i, name) in header.indexed) name: i};
    final body = rows.skip(1);
    if (columns.keys.toSet().containsAll(_bitwardenColumns)) {
      return _rows(LoginExportSource.bitwardenCsv, body, header, _bitwardenRow);
    }
    if (columns.keys.toSet().containsAll(_keepassColumns)) {
      return _rows(LoginExportSource.keepassxcCsv, body, header, _keepassRow);
    }
    if (columns.keys.toSet().containsAll(_chromeColumns)) {
      return _rows(LoginExportSource.chromeCsv, body, header, _chromeRow);
    }
    throw const UnknownLoginExportException();
  }

  static const _bitwardenColumns = {
    'type',
    'name',
    'login_uri',
    'login_username',
    'login_password',
  };
  // KeePassXC'in kendi dışa aktarması Group sütununu da yazar; eski
  // KeePassX dosyalarında olmayabilir.
  static const _keepassColumns = {'title', 'username', 'password', 'url'};
  static const _chromeColumns = {'name', 'url', 'username', 'password'};

  /// Satır işleyici: kayıt, atlanacaksa `null`.
  static LoginExport _rows(
    LoginExportSource source,
    Iterable<List<String>> rows,
    List<String> header,
    ImportedLogin? Function(Map<String, String> row) convert,
  ) {
    final logins = <ImportedLogin>[];
    var skipped = 0;
    for (final row in rows) {
      if (row.length != header.length) {
        skipped++;
        continue;
      }
      final login = convert({
        for (final (i, name) in header.indexed) name: row[i],
      });
      if (login == null) {
        skipped++;
      } else {
        logins.add(login);
      }
    }
    return LoginExport(source: source, logins: logins, skipped: skipped);
  }

  static ImportedLogin? _bitwardenRow(Map<String, String> row) {
    // Bitwarden CSV'si yalnızca giriş ve not içerir; notlar alınmaz.
    if (row['type']!.trim().toLowerCase() == 'note') return null;
    return _login(
      name: row['name']!,
      username: row['login_username']!,
      password: row['login_password']!,
      urls: _splitUris(row['login_uri']!),
      notes: row['notes'] ?? '',
      folder: row['folder'],
      favorite: (row['favorite'] ?? '').trim() == '1',
      fields: _bitwardenCsvFields(row['fields'] ?? ''),
      totp: row['login_totp'],
    );
  }

  static ImportedLogin? _keepassRow(Map<String, String> row) => _login(
    name: row['title']!,
    username: row['username']!,
    password: row['password']!,
    urls: [row['url']!],
    notes: row['notes'] ?? '',
    folder: _keepassFolder(row['group'] ?? ''),
    totp: row['totp'],
  );

  static ImportedLogin? _chromeRow(Map<String, String> row) => _login(
    name: row['name']!,
    username: row['username']!,
    password: row['password']!,
    urls: [row['url']!],
    notes: row['note'] ?? '',
  );

  static LoginExport _bitwardenJson(String text) {
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      throw const UnknownLoginExportException();
    }
    if (root is! Map<String, Object?>) {
      throw const UnknownLoginExportException();
    }
    if (root['encrypted'] == true) {
      throw const EncryptedBitwardenExportException();
    }
    final items = root['items'];
    if (items is! List<Object?>) throw const UnknownLoginExportException();
    final folders = <String, String>{
      if (root['folders'] case final List<Object?> list)
        for (final folder in list)
          if (folder case {'id': final String id, 'name': final String name})
            id: name,
    };
    final logins = <ImportedLogin>[];
    var skipped = 0;
    for (final item in items) {
      final login = _bitwardenItem(item, folders);
      if (login == null) {
        skipped++;
      } else {
        logins.add(login);
      }
    }
    return LoginExport(
      source: LoginExportSource.bitwardenJson,
      logins: logins,
      skipped: skipped,
    );
  }

  static ImportedLogin? _bitwardenItem(
    Object? item,
    Map<String, String> folders,
  ) {
    // Tür 1 giriş; 2 not, 3 kart, 4 kimlik, 5 SSH anahtarı desteklenmiyor.
    if (item is! Map<String, Object?> || item['type'] != 1) return null;
    final login = item['login'];
    if (login is! Map<String, Object?>) return null;
    final uris = <String>[
      if (login['uris'] case final List<Object?> list)
        for (final uri in list)
          if (uri case {'uri': final String value}) value,
    ];
    final fields = <({String name, String value, bool hidden})>[
      if (item['fields'] case final List<Object?> list)
        for (final field in list)
          // Tür 0 metin, 1 gizli; 2 onay kutusu ve 3 bağlı alan alınmaz.
          if (field
              case {
                'name': final String? name,
                'value': final String? value,
                'type': final int type,
              }
              when type == 0 || type == 1)
            (name: name ?? '', value: value ?? '', hidden: type == 1),
    ];
    final folderId = item['folderId'];
    return _login(
      name: _text(item['name']),
      username: _text(login['username']),
      password: _text(login['password']),
      urls: uris,
      notes: _text(item['notes']),
      folder: folderId is String ? folders[folderId] : null,
      favorite: item['favorite'] == true,
      fields: fields,
      totp: login['totp'] is String ? login['totp']! as String : null,
    );
  }

  /// Bitwarden `androidapp://`, Chrome `android://` yazıyor.
  static bool _isAppUri(String url) {
    final lower = url.toLowerCase();
    return lower.startsWith('androidapp://') || lower.startsWith('android://');
  }

  static String _text(Object? value) => value is String ? value : '';

  /// Ortak temizlik. Hiçbir bilgi yoksa satır atlanır.
  static ImportedLogin? _login({
    required String name,
    required String username,
    required String password,
    required List<String> urls,
    String notes = '',
    String? folder,
    bool favorite = false,
    List<({String name, String value, bool hidden})> fields = const [],
    String? totp,
  }) {
    // Uygulama adresleri alınmaz: KeyKey uygulamayı imzasıyla birlikte bağlar.
    final cleanUrls = [
      for (final url in urls)
        if (url.trim().isNotEmpty && !_isAppUri(url.trim())) url.trim(),
    ];
    final cleanTotp = totp?.trim();
    var cleanName = name.trim();
    if (cleanName.isEmpty) {
      cleanName = cleanUrls.isNotEmpty
          ? (Uri.tryParse(cleanUrls.first)?.host ?? '')
          : '';
    }
    if (cleanName.isEmpty) cleanName = username.trim();
    if (cleanName.isEmpty &&
        password.isEmpty &&
        cleanUrls.isEmpty &&
        (cleanTotp == null || cleanTotp.isEmpty)) {
      return null;
    }
    final cleanFolder = folder?.trim();
    return ImportedLogin(
      name: cleanName,
      username: username.trim(),
      password: password,
      urls: cleanUrls,
      notes: notes,
      folder: cleanFolder == null || cleanFolder.isEmpty ? null : cleanFolder,
      favorite: favorite,
      fields: fields,
      totp: cleanTotp == null || cleanTotp.isEmpty ? null : cleanTotp,
    );
  }

  /// Bitwarden CSV'de birden çok adres, alanın içinde ayrı bir CSV satırı
  /// olarak yazılır (Bitwarden'ın okuyucusu da böyle ayrıştırıyor).
  static List<String> _splitUris(String value) {
    try {
      final rows = CsvReader.read(value);
      return rows.isEmpty ? const [] : rows.first;
    } on CsvFormatException {
      return [value];
    }
  }

  /// Bitwarden CSV'deki özel alanlar: her satırda `ad: değer`.
  static List<({String name, String value, bool hidden})> _bitwardenCsvFields(
    String value,
  ) => [
    for (final line in const LineSplitter().convert(value))
      if (line.contains(': '))
        (
          name: line.substring(0, line.lastIndexOf(': ')),
          value: line.substring(line.lastIndexOf(': ') + 2),
          hidden: false,
        ),
  ];

  /// KeePassXC grubu `Root/E-posta` biçimindedir; kök grubun adı atılır.
  static String? _keepassFolder(String group) {
    final parts = group.split('/');
    if (parts.length <= 1) return null;
    return parts.skip(1).join('/');
  }
}

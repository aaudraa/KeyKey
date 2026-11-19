import 'dart:convert';
import 'dart:typed_data';

import 'package:keykey/features/backup/data/import/csv_reader.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/card_number.dart';
import 'package:keykey/features/vault/data/note_content.dart';

/// Dosya tanınan bir parola dışa aktarma biçiminde değil.
final class UnknownLoginExportException implements Exception {
  const new();
}

/// Bitwarden'ın parola korumalı veya hesaba bağlı şifreli dışa aktarması.
final class EncryptedBitwardenExportException implements Exception {
  const new();
}

/// Desteklenen kaynaklar.
enum LoginExportSource {
  bitwardenJson,
  bitwardenCsv,
  chromeCsv,
  firefoxCsv,
  keepassxcCsv,
}

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

/// Başka bir uygulamadan okunan kart.
final class ImportedCard {
  const new({required this.content, required this.adjusted});

  final CardContent content;

  /// Biçime uymayan bir değer alanından çıkarılıp kartın notuna yazıldı.
  final bool adjusted;
}

/// Biçime uymayan kart değerleri nota yazılırken başlarına konan etiketler.
/// Veri katmanı dil bilmez; ekran arayüz dilindekileri verir.
final class ImportLabels {
  const new({
    required this.cardNumber,
    required this.expiry,
    required this.securityCode,
  });

  static const english = ImportLabels(
    cardNumber: 'Card number',
    expiry: 'Expiry',
    securityCode: 'Security code',
  );

  final String cardNumber;
  final String expiry;
  final String securityCode;
}

/// Okunan dosyanın sonucu.
final class LoginExport {
  const new({
    required this.source,
    required this.logins,
    required this.skipped,
    this.cards = const [],
    this.notes = const [],
  });

  final LoginExportSource source;
  final List<ImportedLogin> logins;
  final List<ImportedCard> cards;
  final List<NoteContent> notes;

  /// Desteklenmeyen (kimlik, SSH anahtarı) veya bozuk satırların sayısı.
  final int skipped;
}

/// Bitwarden (JSON, CSV), Chrome (CSV), Firefox (CSV) ve KeePassXC (CSV) dışa
/// aktarmalarını okur.
///
/// Dosyalar güvenilmeyen veri sayılır: bilinmeyen alanlar yok sayılır,
/// bozuk satır atlanır, yalnızca bu dosyadaki hata türleri fırlatılır.
/// Kurallar güvenlik tasarımı belgesinin "Parola içe aktarma" bölümünde.
abstract final class LoginExportReader {
  static const int maxBytes = 10 * 1024 * 1024;

  static LoginExport read(
    Uint8List bytes, {
    ImportLabels labels = ImportLabels.english,
  }) {
    if (bytes.length > maxBytes) throw const UnknownLoginExportException();
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const UnknownLoginExportException();
    }
    final trimmed = text.replaceFirst('﻿', '').trimLeft();
    if (trimmed.startsWith('{')) return _bitwardenJson(trimmed, labels);
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
      return _bitwardenCsv(body, header);
    }
    if (columns.keys.toSet().containsAll(_keepassColumns)) {
      return _rows(LoginExportSource.keepassxcCsv, body, header, _keepassRow);
    }
    if (columns.keys.toSet().containsAll(_firefoxColumns)) {
      return _rows(LoginExportSource.firefoxCsv, body, header, _firefoxRow);
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
  // Firefox kayıt adı yazmaz; ad adresten gelir. Başlıklar küçük harfe
  // çevrilmiş olarak karşılaştırılır.
  static const _firefoxColumns = {
    'url',
    'username',
    'password',
    'httprealm',
    'formactionorigin',
  };

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

  /// Bitwarden CSV'si yalnızca giriş ve not taşır; kart yazmaz.
  static LoginExport _bitwardenCsv(
    Iterable<List<String>> rows,
    List<String> header,
  ) {
    final logins = <ImportedLogin>[];
    final notes = <NoteContent>[];
    var skipped = 0;
    for (final row in rows) {
      if (row.length != header.length) {
        skipped++;
        continue;
      }
      final cells = {for (final (i, name) in header.indexed) name: row[i]};
      if (cells['type']!.trim().toLowerCase() == 'note') {
        final note = _note(
          name: cells['name']!,
          text: cells['notes'] ?? '',
          fields: _bitwardenCsvFields(cells['fields'] ?? ''),
          folder: cells['folder'],
          favorite: (cells['favorite'] ?? '').trim() == '1',
        );
        if (note == null) {
          skipped++;
        } else {
          notes.add(note);
        }
        continue;
      }
      final login = _bitwardenRow(cells);
      if (login == null) {
        skipped++;
      } else {
        logins.add(login);
      }
    }
    return LoginExport(
      source: LoginExportSource.bitwardenCsv,
      logins: logins,
      notes: notes,
      skipped: skipped,
    );
  }

  static ImportedLogin? _bitwardenRow(Map<String, String> row) {
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

  static ImportedLogin? _firefoxRow(Map<String, String> row) => _login(
    name: '',
    username: row['username']!,
    password: row['password']!,
    urls: [row['url']!],
  );

  static LoginExport _bitwardenJson(String text, ImportLabels labels) {
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
    final cards = <ImportedCard>[];
    final notes = <NoteContent>[];
    var skipped = 0;
    for (final item in items) {
      // Tür 1 giriş, 2 güvenli not, 3 kart; 4 kimlik ve 5 SSH anahtarı
      // desteklenmiyor.
      final record = switch (item) {
        {'type': 1} => _bitwardenItem(item, folders),
        final Map<String, Object?> map when map['type'] == 2 => _bitwardenNote(
          map,
          folders,
        ),
        final Map<String, Object?> map when map['type'] == 3 => _bitwardenCard(
          map,
          folders,
          labels,
        ),
        _ => null,
      };
      switch (record) {
        case final ImportedLogin login:
          logins.add(login);
        case final ImportedCard card:
          cards.add(card);
        case final NoteContent note:
          notes.add(note);
        default:
          skipped++;
      }
    }
    return LoginExport(
      source: LoginExportSource.bitwardenJson,
      logins: logins,
      cards: cards,
      notes: notes,
      skipped: skipped,
    );
  }

  /// Kart ve notun özel alanları: tür 0 metin, 1 gizli, 2 onay kutusu. Tür 3
  /// bağlı alan değer taşımaz.
  static List<({String name, String value, bool hidden})> _bitwardenFields(
    Map<String, Object?> item,
  ) => [
    if (item['fields'] case final List<Object?> list)
      for (final field in list)
        if (field
            case {
              'name': final String? name,
              'value': final String? value,
              'type': final int type,
            }
            when type >= 0 && type <= 2)
          (name: name ?? '', value: value ?? '', hidden: type == 1),
  ];

  static String? _folderOf(Map<String, Object?> item, Map<String, String> ids) {
    final folderId = item['folderId'];
    return folderId is String ? ids[folderId] : null;
  }

  static NoteContent? _bitwardenNote(
    Map<String, Object?> item,
    Map<String, String> folders,
  ) => _note(
    name: _text(item['name']),
    text: _text(item['notes']),
    fields: _bitwardenFields(item),
    folder: _folderOf(item, folders),
    favorite: item['favorite'] == true,
  );

  /// Biçime uyan değerler alanlarına girer; uymayanlar etiketiyle kartın
  /// notuna yazılır, hiçbiri atılmaz.
  static ImportedCard? _bitwardenCard(
    Map<String, Object?> item,
    Map<String, String> folders,
    ImportLabels labels,
  ) {
    final card = item['card'];
    if (card is! Map<String, Object?>) return null;
    final moved = <String>[];

    final rawNumber = _scalar(card['number']);
    final number = normalizeCardNumber(rawNumber) ?? '';
    if (number.isEmpty && rawNumber.isNotEmpty) {
      moved.add('${labels.cardNumber}: $rawNumber');
    }

    final month = _scalar(card['expMonth']);
    final year = _scalar(card['expYear']);
    CardExpiry? expiry;
    if (month.isNotEmpty || year.isNotEmpty) {
      expiry = _expiry(month, year);
      if (expiry == null) moved.add('${labels.expiry}: $month/$year');
    }

    var code = _scalar(card['code']);
    if (!CardContent.isValidSecurityCode(code)) {
      moved.add('${labels.securityCode}: $code');
      code = '';
    }

    var pin = '';
    final extra = <String>[];
    for (final field in _bitwardenFields(item)) {
      final value = field.value.trim();
      if (pin.isEmpty &&
          field.name.trim().toLowerCase() == 'pin' &&
          value.isNotEmpty &&
          CardContent.isValidPin(value)) {
        pin = value;
      } else {
        extra.add('${field.name}: ${field.value}');
      }
    }

    final name = _text(item['name']).trim();
    final cardholder = _scalar(card['cardholderName']);
    final notes = [
      _lines(_text(item['notes'])),
      ...extra,
      ...moved,
    ].where((line) => line.isNotEmpty).join('\n');
    if (name.isEmpty &&
        cardholder.isEmpty &&
        number.isEmpty &&
        expiry == null &&
        code.isEmpty &&
        pin.isEmpty &&
        notes.isEmpty) {
      return null;
    }
    final folder = _folderOf(item, folders)?.trim();
    return ImportedCard(
      content: CardContent(
        name: name,
        cardholder: cardholder,
        number: number,
        expiry: expiry,
        securityCode: code,
        pin: pin,
        notes: notes,
        favorite: item['favorite'] == true,
        folder: folder == null || folder.isEmpty ? null : folder,
      ),
      adjusted: moved.isNotEmpty,
    );
  }

  /// Kart değerleri metin ya da sayı olabiliyor (Bitwarden ay ve yılı sayı
  /// yazabiliyor, başka araçlar numarayı da). Hiçbir değer atılmaz: metne
  /// çevrilir; alanına uymazsa çağıran onu nota taşır. Tam sayı olmayan ya da
  /// çok büyük sayılar olduğu gibi yazılır, rakamları uydurulmaz.
  static String _scalar(Object? value) => switch (value) {
    null => '',
    final String text => text.trim(),
    final int number => '$number',
    final double number
        when number.isFinite &&
            number == number.truncateToDouble() &&
            number.abs() <= _maxExactDouble =>
      '${number.toInt()}',
    _ => jsonEncode(value),
  };

  /// 2^53: bundan büyük double tam sayıları kesin tutamaz.
  static const _maxExactDouble = 9007199254740992.0;

  static final _expiryPart = RegExp(r'^[0-9]{1,4}$');

  static CardExpiry? _expiry(String month, String year) {
    if (!_expiryPart.hasMatch(month) || !_expiryPart.hasMatch(year)) {
      return null;
    }
    final m = int.parse(month);
    var y = int.parse(year);
    if (year.length <= 2) y += 2000;
    if (m < 1 || m > 12 || y < CardExpiry.minYear || y > CardExpiry.maxYear) {
      return null;
    }
    return CardExpiry(month: m, year: y);
  }

  /// Windows'ta alınan dışa aktarmalarda satır sonları CRLF gelir.
  static String _lines(String text) =>
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  /// Notun metni ve sonuna eklenen özel alanları. Hiçbir şey yoksa ya da
  /// metin sınırı aşıyorsa `null`.
  static NoteContent? _note({
    required String name,
    required String text,
    required List<({String name, String value, bool hidden})> fields,
    String? folder,
    bool favorite = false,
  }) {
    final body = [
      _lines(text),
      for (final field in fields) '${field.name}: ${field.value}',
    ].where((line) => line.isNotEmpty).join('\n');
    final cleanName = name.trim();
    if (cleanName.isEmpty && body.trim().isEmpty) return null;
    if (!NoteContent.fitsTextLimit(body)) return null;
    final cleanFolder = folder?.trim();
    return NoteContent(
      name: cleanName,
      text: body,
      folder: cleanFolder == null || cleanFolder.isEmpty ? null : cleanFolder,
      favorite: favorite,
    );
  }

  static ImportedLogin? _bitwardenItem(
    Object? item,
    Map<String, String> folders,
  ) {
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
      // Windows'ta alınan dışa aktarmalarda notlar CRLF ile gelir.
      notes: notes.replaceAll('\r\n', '\n').replaceAll('\r', '\n'),
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

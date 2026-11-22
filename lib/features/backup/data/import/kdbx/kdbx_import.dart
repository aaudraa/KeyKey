import 'dart:convert';

import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_xml.dart';
import 'package:keykey/features/backup/data/import/login_import.dart';
import 'package:keykey/features/vault/data/note_content.dart';

/// KeePass kayıtlarını içe aktarma önizlemesinin biçimine çevirir.
///
/// Kurallar KeePass içe aktarma tasarımının "Kayıtlar" bölümünde: grup yolu
/// klasör, TOTP alanları 2FA, ek adresler adres, kalan alanlar özel alan;
/// yalnızca notu olan kayıt güvenli not olur.
LoginExport kdbxToLoginExport(KdbxDatabase db) {
  final byUuid = {
    for (final entry in db.entries)
      entry.uuid: {
        for (final MapEntry(:key, :value) in entry.strings.entries)
          key: value.value,
      },
  };
  final logins = <ImportedLogin>[];
  final notes = <NoteContent>[];
  var skipped = 0;
  var withAttachments = 0;

  for (final entry in db.entries) {
    if (entry.attachments > 0) withAttachments++;
    String value(String key) =>
        resolveKdbxReferences(entry.strings[key]?.value ?? '', byUuid);

    final totp = _totp(entry, value);
    final consumed = {..._standardKeys, if (totp != null) ...totp.keys};
    final urls = [
      value('URL'),
      for (final key in _extraUrlKeys(entry)) value(key),
    ];
    final fields = [
      for (final MapEntry(:key, value: field) in entry.strings.entries)
        if (!consumed.contains(key) && !_isInternal(key))
          (name: key, value: value(key), hidden: field.protected),
    ];
    final folder = entry.groupPath.isEmpty ? null : entry.groupPath.join('/');
    final title = value('Title');
    final username = value('UserName');
    final password = value('Password');
    final text = value('Notes');

    final hasLoginData =
        username.trim().isNotEmpty ||
        password.isNotEmpty ||
        totp != null ||
        urls.any((url) => url.trim().isNotEmpty && !_isAppUrl(url));
    if (!hasLoginData && text.trim().isNotEmpty) {
      final note = LoginExportReader.cleanNote(
        name: title,
        text: text,
        fields: fields,
        folder: folder,
      );
      if (note == null) {
        skipped++;
      } else {
        notes.add(note);
      }
      continue;
    }

    final login = LoginExportReader.cleanLogin(
      name: title,
      username: username,
      password: password,
      urls: urls,
      notes: text,
      folder: folder,
      fields: fields,
      totp: totp?.uri,
    );
    if (login == null) {
      skipped++;
    } else {
      logins.add(login);
    }
  }

  return LoginExport(
    source: LoginExportSource.keepassKdbx,
    logins: logins,
    notes: notes,
    skipped: skipped,
    withAttachments: withAttachments,
    inRecycleBin: db.recycledEntries,
  );
}

const _standardKeys = {'Title', 'UserName', 'Password', 'URL', 'Notes'};

/// KeePassXC'in kendi iç alanları (passkey, şablon); kullanıcıya ait değil.
bool _isInternal(String key) =>
    key.startsWith('KPEX_') || key.startsWith('_etm_') || _isExtraUrl(key);

bool _isAppUrl(String url) {
  final lower = url.trim().toLowerCase();
  return lower.startsWith('androidapp://') || lower.startsWith('android://');
}

final _extraUrl = RegExp(r'^KP2A_URL(?:_(\d+))?$');

bool _isExtraUrl(String key) => _extraUrl.hasMatch(key);

/// `KP2A_URL`, `KP2A_URL_1`, `KP2A_URL_2` … sırasıyla.
List<String> _extraUrlKeys(KdbxEntry entry) {
  final keys = entry.strings.keys.where(_isExtraUrl).toList()
    ..sort((a, b) {
      int order(String key) =>
          int.tryParse(_extraUrl.firstMatch(key)!.group(1) ?? '') ?? -1;
      return order(a).compareTo(order(b));
    });
  return keys;
}

final _reference = RegExp(
  r'\{REF:([TUPAN])@I:([0-9A-F]{32})\}',
  caseSensitive: false,
);

const _referenceFields = {
  'T': 'Title',
  'U': 'UserName',
  'P': 'Password',
  'A': 'URL',
  'N': 'Notes',
};

/// `{REF:<alan>@I:<UUID>}` başvurularını aynı dosyadaki kaydın alanıyla
/// değiştirir. Başka arama türleri ve bulunamayan kayıt olduğu gibi kalır;
/// zincir en çok 10 adım izlenir.
String resolveKdbxReferences(
  String value,
  Map<String, Map<String, String>> byUuid, [
  int depth = 0,
]) {
  if (depth >= 10 || !value.contains('{')) return value;
  return value.replaceAllMapped(_reference, (match) {
    final target = byUuid[match.group(2)!.toUpperCase()];
    if (target == null) return match.group(0)!;
    final field = _referenceFields[match.group(1)!.toUpperCase()]!;
    return resolveKdbxReferences(target[field] ?? '', byUuid, depth + 1);
  });
}

/// Kayıttaki 2FA: bağlantı ve tüketilen alanlar.
typedef _Totp = ({String uri, Set<String> keys});

/// Bilinen her 2FA alanı, hangisi kullanılırsa kullanılsın, özel alana
/// geçmez: KeePassXC eski sürümlerde aynı anahtarı iki biçimde yazıyordu.
_Totp? _totp(KdbxEntry entry, String Function(String) value) {
  final keys = {
    for (final key in entry.strings.keys)
      if (key == 'otp' ||
          key == 'TOTP Seed' ||
          key == 'TOTP Settings' ||
          key.startsWith('TimeOtp-'))
        key,
  };
  final uri =
      _keepassXcOtp(value('otp')) ??
      _keePassTimeOtp(entry, value) ??
      _legacyTotp(value('TOTP Seed'), value('TOTP Settings'), entry, value);
  return uri == null ? null : (uri: uri, keys: keys);
}

String _label(KdbxEntry entry, String Function(String) value) {
  final user = value('UserName').trim();
  final title = value('Title').trim();
  return Uri.encodeComponent(
    user.isNotEmpty ? user : (title.isNotEmpty ? title : 'KeePass'),
  );
}

/// KeePassXC ve KeePassDX: `otpauth://` bağlantısı. KeeOtp eklentisinin
/// `key=…&step=…&size=…` biçimi de okunur.
String? _keepassXcOtp(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.toLowerCase().startsWith('otpauth://')) return trimmed;
  // Uri.splitQueryString bozuk kaçışta ArgumentError fırlatır; ayrıştırma
  // başarılıysa kaçışlar düzeltilmiş olur ve okuma hata vermez.
  final query = Uri.tryParse('?$trimmed')?.queryParameters;
  if (query == null) return null;
  final key = query['key'];
  if (key == null || (query['type'] ?? 'totp').toLowerCase() != 'totp') {
    return null;
  }
  return _otpauth(
    'KeePass',
    secret: key,
    algorithm: switch (query['otpHashMode']?.toLowerCase()) {
      'sha256' => 'SHA256',
      'sha512' => 'SHA512',
      _ => null,
    },
    digits: query['size'],
    period: query['step'],
  );
}

/// KeePass 2.47+: `TimeOtp-Secret-*`, `TimeOtp-Algorithm`, `-Length`,
/// `-Period`.
String? _keePassTimeOtp(KdbxEntry entry, String Function(String) value) {
  String? secret;
  final base32 = value('TimeOtp-Secret-Base32').replaceAll(' ', '');
  final hex = value('TimeOtp-Secret-Hex').replaceAll(' ', '');
  final base64Text = value('TimeOtp-Secret-Base64').trim();
  final plain = value('TimeOtp-Secret');
  if (base32.isNotEmpty) {
    secret = base32.toUpperCase();
  } else if (hex.isNotEmpty && RegExp(r'^([0-9a-fA-F]{2})+$').hasMatch(hex)) {
    secret = Base32.encode([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]);
  } else if (base64Text.isNotEmpty) {
    try {
      secret = Base32.encode(base64.decode(base64Text));
    } on FormatException {
      return null;
    }
  } else if (plain.isNotEmpty) {
    secret = Base32.encode(utf8.encode(plain));
  }
  if (secret == null) return null;
  return _otpauth(
    _label(entry, value),
    secret: secret,
    algorithm: switch (value('TimeOtp-Algorithm').trim().toUpperCase()) {
      'HMAC-SHA-256' => 'SHA256',
      'HMAC-SHA-512' => 'SHA512',
      'HMAC-SHA-1' => 'SHA1',
      _ => null,
    },
    digits: value('TimeOtp-Length').trim(),
    period: value('TimeOtp-Period').trim(),
  );
}

/// Eski KeePassXC: `TOTP Seed` ve `TOTP Settings` (`30;6`, Steam için
/// `30;S`).
String? _legacyTotp(
  String seed,
  String settings,
  KdbxEntry entry,
  String Function(String) value,
) {
  final secret = seed.replaceAll(' ', '');
  if (secret.isEmpty) return null;
  final parts = settings.split(';');
  final period = parts.isNotEmpty ? parts[0].trim() : '';
  final digits = parts.length > 1 ? parts[1].trim() : '';
  if (digits.toUpperCase() == 'S') return 'steam://$secret';
  return _otpauth(
    _label(entry, value),
    secret: secret,
    digits: digits,
    period: period,
  );
}

String _otpauth(
  String label, {
  required String secret,
  String? algorithm,
  String? digits,
  String? period,
}) {
  final query = {
    'secret': secret,
    'algorithm': ?algorithm,
    if (digits != null && digits.isNotEmpty) 'digits': digits,
    if (period != null && period.isNotEmpty) 'period': period,
  };
  return Uri(
    scheme: 'otpauth',
    host: 'totp',
    path: '/$label',
    queryParameters: query,
  ).toString();
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:keykey/features/vault/data/login_passkey.dart';

/// Parola kaydının içeriği bu sürümün okuyabileceği biçimde değil.
///
/// Mesajda alan değeri bulunmaz, yalnızca alan adı bulunabilir.
final class InvalidLoginContentException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => 'InvalidLoginContentException: $message';
}

/// Kullanıcının eklediği serbest alan.
@immutable
final class LoginCustomField {
  const new({required this.name, required this.value, this.hidden = false});

  final String name;
  final String value;

  /// `true` ise değer varsayılan olarak gizli gösterilir.
  final bool hidden;

  @override
  bool operator ==(Object other) =>
      other is LoginCustomField &&
      other.name == name &&
      other.value == value &&
      other.hidden == hidden;

  @override
  int get hashCode => Object.hash(name, value, hidden);
}

/// Parola geçmişindeki bir kayıt.
@immutable
final class PasswordHistoryEntry {
  const new({required this.password, required this.changedAt});

  final String password;
  final DateTime changedAt;

  @override
  bool operator ==(Object other) =>
      other is PasswordHistoryEntry &&
      other.password == password &&
      other.changedAt == changedAt;

  @override
  int get hashCode => Object.hash(password, changedAt);
}

/// Kaydın doldurulabileceği bir Android uygulaması.
///
/// Paket adı tek başına güvenilmez; aynı adı taşıyan başka bir uygulama
/// farklı bir anahtarla imzalanmış olabilir. Bu yüzden imza sertifikalarının
/// SHA-256 özetleri de tutulur ve eşleşme için hepsi tutmalıdır.
@immutable
final class LoginApp {
  new({required this.packageName, required List<String> certsSha256})
    : certsSha256 = List.unmodifiable(certsSha256) {
    if (!isValidPackageName(packageName)) {
      throw ArgumentError.value(packageName, 'packageName');
    }
    if (certsSha256.isEmpty || !certsSha256.every(isValidCertDigest)) {
      throw ArgumentError('Geçersiz imza özeti.');
    }
  }

  final String packageName;

  /// Küçük harf onaltılık, 64 hane.
  final List<String> certsSha256;

  static final _packagePattern = RegExp(
    r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$',
  );
  static final _digestPattern = RegExp(r'^[0-9a-f]{64}$');

  /// Android paket adı: en az iki parça, harfle başlar, en çok 255 karakter.
  static bool isValidPackageName(String value) =>
      value.length <= 255 && _packagePattern.hasMatch(value);

  static bool isValidCertDigest(String value) => _digestPattern.hasMatch(value);

  @override
  bool operator ==(Object other) =>
      other is LoginApp &&
      other.packageName == packageName &&
      listEquals(other.certsSha256, certsSha256);

  @override
  int get hashCode => Object.hash(packageName, Object.hashAll(certsSha256));
}

const Object _keep = Object();

/// Parola kaydının şifreli içeriği. Biçim güvenlik tasarımı belgesinde.
final class LoginContent {
  const new({
    required this.name,
    this.username = '',
    this.password = '',
    this.urls = const [],
    this.apps = const [],
    this.notes = '',
    this.customFields = const [],
    this.favorite = false,
    this.folder,
    this.trashedAt,
    this.passwordHistory = const [],
    this.passkeys = const [],
  });

  /// JSON baytlarını katı kurallarla okur.
  ///
  /// Bilinmeyen sürüm, eksik veya fazla alan ya da yanlış tür
  /// [InvalidLoginContentException] fırlatır.
  factory fromJsonBytes(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const InvalidLoginContentException('Geçersiz JSON.');
    }
    // Sürüm 1'de `apps`, sürüm 2'de `passkeys` yoktu; beklenen alanlar
    // sürüme göre seçilir.
    final version = decoded is Map<String, Object?> ? decoded['version'] : null;
    final root = switch (version) {
      1 => _object(decoded, _keysV1),
      2 => _object(decoded, const {..._keysV1, 'apps'}),
      currentVersion => _object(decoded, const {
        ..._keysV1,
        'apps',
        'passkeys',
      }),
      _ => throw const InvalidLoginContentException('Desteklenmeyen sürüm.'),
    };
    return LoginContent(
      name: _string(root['name'], 'name'),
      username: _string(root['username'], 'username'),
      password: _string(root['password'], 'password'),
      urls: _list(
        root['urls'],
        'urls',
      ).map((value) => _string(value, 'urls')).toList(growable: false),
      apps: version == 1
          ? const []
          : _list(root['apps'], 'apps').map(_app).toList(growable: false),
      notes: _string(root['notes'], 'notes'),
      customFields: _list(root['customFields'], 'customFields')
          .map((value) {
            final field = _object(value, const {'name', 'value', 'hidden'});
            return LoginCustomField(
              name: _string(field['name'], 'customFields.name'),
              value: _string(field['value'], 'customFields.value'),
              hidden: _bool(field['hidden'], 'customFields.hidden'),
            );
          })
          .toList(growable: false),
      favorite: _bool(root['favorite'], 'favorite'),
      folder: _nullableString(root['folder'], 'folder'),
      trashedAt: _nullableTime(root['trashedAt'], 'trashedAt'),
      passwordHistory: _list(root['passwordHistory'], 'passwordHistory')
          .map((value) {
            final entry = _object(value, const {'password', 'changedAt'});
            return PasswordHistoryEntry(
              password: _string(entry['password'], 'passwordHistory.password'),
              changedAt: _time(entry['changedAt'], 'passwordHistory.changedAt'),
            );
          })
          .toList(growable: false),
      passkeys: version == currentVersion
          ? _passkeys(root['passkeys'])
          : const [],
    );
  }

  /// Sürüm 2 `apps`, sürüm 3 `passkeys` alanını ekledi. Eski sürümler
  /// okunmaya devam eder.
  static const currentVersion = 3;

  /// Bir kayıttaki en fazla passkey.
  static const maxPasskeys = 20;

  static const _keysV1 = {
    'version',
    'name',
    'username',
    'password',
    'urls',
    'notes',
    'customFields',
    'favorite',
    'folder',
    'trashedAt',
    'passwordHistory',
  };

  /// Geçmişte tutulan en fazla eski parola.
  static const maxPasswordHistory = 10;

  final String name;
  final String username;
  final String password;
  final List<String> urls;

  /// Kaydın doldurulabileceği uygulamalar. Sürüm 1 kayıtlarda boştur.
  final List<LoginApp> apps;
  final String notes;
  final List<LoginCustomField> customFields;
  final bool favorite;
  final String? folder;
  final DateTime? trashedAt;
  final List<PasswordHistoryEntry> passwordHistory;

  /// Bu hesabın passkey'leri. Sürüm 1 ve 2 kayıtlarda boştur.
  final List<LoginPasskey> passkeys;

  bool get isTrashed => trashedAt != null;

  Uint8List toJsonBytes() => utf8.encode(
    jsonEncode({
      'version': currentVersion,
      'name': name,
      'username': username,
      'password': password,
      'urls': urls,
      'apps': [
        for (final app in apps)
          {'package': app.packageName, 'certsSha256': app.certsSha256},
      ],
      'notes': notes,
      'customFields': [
        for (final field in customFields)
          {'name': field.name, 'value': field.value, 'hidden': field.hidden},
      ],
      'favorite': favorite,
      'folder': folder,
      'trashedAt': trashedAt?.millisecondsSinceEpoch,
      'passwordHistory': [
        for (final entry in passwordHistory)
          {
            'password': entry.password,
            'changedAt': entry.changedAt.millisecondsSinceEpoch,
          },
      ],
      'passkeys': [for (final passkey in passkeys) passkey.toJson()],
    }),
  );

  /// [folder] ve [trashedAt] verilmezse korunur, `null` verilirse temizlenir.
  LoginContent copyWith({
    String? name,
    String? username,
    String? password,
    List<String>? urls,
    List<LoginApp>? apps,
    String? notes,
    List<LoginCustomField>? customFields,
    bool? favorite,
    Object? folder = _keep,
    Object? trashedAt = _keep,
    List<PasswordHistoryEntry>? passwordHistory,
    List<LoginPasskey>? passkeys,
  }) {
    return LoginContent(
      name: name ?? this.name,
      username: username ?? this.username,
      password: password ?? this.password,
      urls: urls ?? this.urls,
      apps: apps ?? this.apps,
      notes: notes ?? this.notes,
      customFields: customFields ?? this.customFields,
      favorite: favorite ?? this.favorite,
      folder: identical(folder, _keep) ? this.folder : folder as String?,
      trashedAt: identical(trashedAt, _keep)
          ? this.trashedAt
          : trashedAt as DateTime?,
      passwordHistory: passwordHistory ?? this.passwordHistory,
      passkeys: passkeys ?? this.passkeys,
    );
  }

  /// Düzenleme formu açıkken kayıt başka yerden değiştiyse, örneğin arka
  /// planda bekleme süresinde doldurma ekranı yeni parolayı kaydettiyse:
  /// formda [original]'e göre değişen alanlar [latest]'e yazılır, ötekiler
  /// [latest]'teki gibi kalır. Böylece kullanıcının dokunmadığı yeni parola
  /// eski formla ezilmez.
  LoginContent rebase({
    required LoginContent original,
    required LoginContent latest,
  }) => latest.copyWith(
    name: name == original.name ? latest.name : name,
    username: username == original.username ? latest.username : username,
    password: password == original.password ? latest.password : password,
    urls: listEquals(urls, original.urls) ? latest.urls : urls,
    apps: listEquals(apps, original.apps) ? latest.apps : apps,
    notes: notes == original.notes ? latest.notes : notes,
    folder: folder == original.folder ? latest.folder : folder,
    customFields: listEquals(customFields, original.customFields)
        ? latest.customFields
        : customFields,
  );

  /// [edited] içeriğini alır. Parola değiştiyse eskisini geçmişe ekler.
  /// Passkey'ler formda düzenlenmez; kayıttakiler korunur.
  LoginContent applyEdit(LoginContent edited, DateTime now) {
    if (edited.password == password || password.isEmpty) {
      return edited.copyWith(
        passwordHistory: passwordHistory,
        passkeys: passkeys,
      );
    }
    final history = [
      PasswordHistoryEntry(password: password, changedAt: now),
      ...passwordHistory,
    ];
    return edited.copyWith(
      passwordHistory: history.length > maxPasswordHistory
          ? history.sublist(0, maxPasswordHistory)
          : history,
      passkeys: passkeys,
    );
  }

  /// Senkronda kaybeden sürümün parolasını geçmişin başına ekler: iki
  /// telefonda aynı anda yapılan değişikliklerden kazanan bu içerik olunca
  /// öteki telefonun kaydettiği parola kaybolmasın. [password] boşsa, şimdiki
  /// parolaysa ya da geçmişte zaten varsa `null`.
  LoginContent? withRescuedPassword(String password, DateTime changedAt) {
    if (password.isEmpty ||
        password == this.password ||
        passwordHistory.any((entry) => entry.password == password)) {
      return null;
    }
    final history = [
      PasswordHistoryEntry(password: password, changedAt: changedAt),
      ...passwordHistory,
    ];
    return copyWith(
      passwordHistory: history.length > maxPasswordHistory
          ? history.sublist(0, maxPasswordHistory)
          : history,
    );
  }

  static LoginApp _app(Object? value) {
    final app = _object(value, const {'package', 'certsSha256'});
    final packageName = _string(app['package'], 'apps.package');
    final certs = _list(
      app['certsSha256'],
      'apps.certsSha256',
    ).map((value) => _string(value, 'apps.certsSha256')).toList();
    if (!LoginApp.isValidPackageName(packageName)) {
      throw const InvalidLoginContentException('Geçersiz alan: apps.package');
    }
    if (certs.isEmpty || !certs.every(LoginApp.isValidCertDigest)) {
      throw const InvalidLoginContentException(
        'Geçersiz alan: apps.certsSha256',
      );
    }
    return LoginApp(packageName: packageName, certsSha256: certs);
  }

  static List<LoginPasskey> _passkeys(Object? value) {
    final list = _list(value, 'passkeys');
    if (list.length > maxPasskeys) {
      throw const InvalidLoginContentException('Çok fazla passkey.');
    }
    return [
      for (final item in list)
        () {
          final entry = _object(item, LoginPasskey.keys);
          for (final key in const [
            'credentialId',
            'rpId',
            'userHandle',
            'userName',
            'userDisplayName',
            'privateKey',
          ]) {
            _string(entry[key], 'passkeys.$key');
          }
          _time(entry['createdAt'], 'passkeys.createdAt');
          return LoginPasskey.tryParse(entry) ??
              (throw const InvalidLoginContentException('Geçersiz passkey.'));
        }(),
    ];
  }

  static Map<String, Object?> _object(Object? value, Set<String> keys) {
    if (value is! Map<String, Object?>) {
      throw const InvalidLoginContentException('Nesne bekleniyordu.');
    }
    if (value.length != keys.length || !keys.containsAll(value.keys)) {
      throw const InvalidLoginContentException('Eksik veya fazla alan.');
    }
    return value;
  }

  static String _string(Object? value, String field) {
    if (value is String) return value;
    throw InvalidLoginContentException('Geçersiz alan: $field');
  }

  static String? _nullableString(Object? value, String field) =>
      value == null ? null : _string(value, field);

  static bool _bool(Object? value, String field) {
    if (value is bool) return value;
    throw InvalidLoginContentException('Geçersiz alan: $field');
  }

  static List<Object?> _list(Object? value, String field) {
    if (value is List<Object?>) return value;
    throw InvalidLoginContentException('Geçersiz alan: $field');
  }

  static DateTime _time(Object? value, String field) {
    // DateTime bu aralığın dışında RangeError fırlatır.
    if (value is int && value.abs() <= _maxMilliseconds) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    throw InvalidLoginContentException('Geçersiz alan: $field');
  }

  static const _maxMilliseconds = 8640000000000000;

  static DateTime? _nullableTime(Object? value, String field) =>
      value == null ? null : _time(value, field);
}

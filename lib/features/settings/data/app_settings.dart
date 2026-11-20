import 'dart:convert';
import 'dart:typed_data';

import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/network/secure_url.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/generator/application/generator_preferences.dart';
import 'package:keykey/features/vault/application/login_search.dart';

/// Otomatik yedeğin klasörü: Android'in klasör ağacı adresi ve gösterilen ad.
final class AutoBackupFolder {
  const new({required this.uri, required this.name});

  /// `content://…/tree/…`.
  final String uri;

  /// Ayarlarda gösterilen ad.
  final String name;

  Map<String, Object?> toJson() => {'uri': uri, 'name': name};

  /// Tam iki alan, ikisi de boş olmayan metin, adres `content://` ile başlar.
  /// Uymazsa `null`.
  static AutoBackupFolder? tryParse(Object? value) {
    if (value is! Map<String, Object?> ||
        value.length != 2 ||
        !value.keys.toSet().containsAll(const {'uri', 'name'})) {
      return null;
    }
    final uri = value['uri'];
    final name = value['name'];
    if (uri is! String || !uri.startsWith('content://')) return null;
    if (name is! String || name.isEmpty) return null;
    return AutoBackupFolder(uri: uri, name: name);
  }
}

/// Senkronun bu telefondaki bilgileri: WebDAV klasörü, kimlik bilgileri ve
/// son eşitlemenin izi. Ayar kaydıyla kasanın içinde şifreli durur; senkron
/// dosyasına girmez. Tasarım: `resources/docs/senkron.md`.
final class SyncSettings {
  const new({
    required this.folder,
    required this.username,
    required this.appPassword,
    this.lastSyncAt,
    this.lastDigest,
  });

  /// WebDAV klasörünün adresi ([isSecureServiceUrl]).
  final Uri folder;

  final String username;

  /// Sunucunun uygulama parolası (ya da hesap parolası).
  final String appPassword;

  /// Son başarılı eşitlemenin zamanı.
  final DateTime? lastSyncAt;

  /// Son yüklenen senkron dosyasının içerik özeti (64 küçük onaltılık
  /// karakter); değişmeyen durum yeniden yüklenmez.
  final String? lastDigest;

  /// Son eşitlemenin izini değiştirir; bağlantı bilgileri aynı kalır.
  SyncSettings withLastSync(DateTime at, String digest) => SyncSettings(
    folder: folder,
    username: username,
    appPassword: appPassword,
    lastSyncAt: at,
    lastDigest: digest,
  );

  Map<String, Object?> toJson() => {
    'folder': folder.toString(),
    'username': username,
    'appPassword': appPassword,
    'lastSyncAt': lastSyncAt?.millisecondsSinceEpoch,
    'lastDigest': lastDigest,
  };

  static final _digest = RegExp(r'^[0-9a-f]{64}$');

  /// Tam beş alan; adres kurala uyar, kullanıcı adı ve parola boş değil.
  /// Uymazsa `null`.
  static SyncSettings? tryParse(Object? value) {
    const keys = {
      'folder',
      'username',
      'appPassword',
      'lastSyncAt',
      'lastDigest',
    };
    if (value is! Map<String, Object?> ||
        value.length != keys.length ||
        !keys.containsAll(value.keys)) {
      return null;
    }
    final folder = value['folder'];
    final username = value['username'];
    final appPassword = value['appPassword'];
    final lastSyncAt = value['lastSyncAt'];
    final lastDigest = value['lastDigest'];
    if (folder is! String) return null;
    final uri = Uri.tryParse(folder);
    if (uri == null || !isSecureServiceUrl(uri)) return null;
    if (username is! String || username.isEmpty) return null;
    if (appPassword is! String || appPassword.isEmpty) return null;
    if (lastSyncAt != null && (lastSyncAt is! int || lastSyncAt < 0)) {
      return null;
    }
    if (lastDigest != null &&
        (lastDigest is! String || !_digest.hasMatch(lastDigest))) {
      return null;
    }
    return SyncSettings(
      folder: uri,
      username: username,
      appPassword: appPassword,
      lastSyncAt: lastSyncAt is int
          ? DateTime.fromMillisecondsSinceEpoch(lastSyncAt, isUtc: true)
          : null,
      lastDigest: lastDigest as String?,
    );
  }

  /// Kimlik bilgisi günlüğe ya da hata mesajına düşmesin.
  @override
  String toString() => 'SyncSettings(${folder.host})';
}

/// Uygulama arka plana geçince kasanın kilitlenmeden önce bekleyeceği süre.
///
/// Kurallar güvenlik tasarımı belgesinin Otomatik kilit bölümündedir.
enum BackgroundLock {
  immediately(0),
  seconds30(30),
  minute1(60);

  new(this.seconds);

  /// Kayıtta yazılan değer.
  final int seconds;

  Duration get delay => Duration(seconds: seconds);

  /// Kayıttaki değere karşılık gelen süre; tanınmazsa `null`.
  static BackgroundLock? bySeconds(Object? value) {
    for (final lock in values) {
      if (value is int && lock.seconds == value) return lock;
    }
    return null;
  }
}

/// Kasanın içinde, şifreli saklanan ayarlar.
///
/// Biçim güvenlik tasarımı belgesinde. Okurken doğrulama katıdır.
final class AppSettings {
  const new({
    required this.otpRequireAuth,
    required this.autofillCopyOtp,
    this.lastBackupAt,
    this.backupReminderSnoozedUntil,
    this.vaultSort = LoginSort.name,
    this.generator = GeneratorPreferences.defaults,
    this.autoBackupFolder,
    this.backgroundLock = BackgroundLock.immediately,
    this.plainKeyboard = false,
    this.sync,
  });

  static const defaults = AppSettings(
    otpRequireAuth: false,
    autofillCopyOtp: true,
  );

  /// Ek onay açık. Kayıt var ama okunamıyorsa da bu kullanılır: dosyayı
  /// değiştiren biri ayarı böyle kapatamasın; kullanıcı doğrulayıp kapatabilir.
  /// Kod kopyalama da kapalı sayılır.
  static const requireAuth = AppSettings(
    otpRequireAuth: true,
    autofillCopyOtp: false,
  );

  /// Sürüm 2 [autofillCopyOtp], sürüm 3 yedek bilgilerini ([lastBackupAt],
  /// [backupReminderSnoozedUntil]), sürüm 4 [vaultSort] ve [generator]
  /// alanlarını, sürüm 5 [autoBackupFolder] alanını, sürüm 6
  /// [backgroundLock] ve [plainKeyboard] alanlarını, sürüm 7 [sync] alanını
  /// ekledi. Eski sürümler okunmaya devam eder.
  static const currentVersion = 7;

  /// 2FA kodlarını göstermeden önce parmak izi veya ana parola istenir.
  final bool otpRequireAuth;

  /// Otomatik doldurmadan sonra kayda bağlı 2FA hesabının güncel kodu güvenli
  /// panoya kopyalanır.
  final bool autofillCopyOtp;

  /// Son başarılı yedeğin zamanı; hiç yedek alınmadıysa `null`.
  final DateTime? lastBackupAt;

  /// Yedek hatırlatıcısı bu zamana kadar gösterilmez.
  final DateTime? backupReminderSnoozedUntil;

  /// Kasa listesinin sıralaması.
  final LoginSort vaultSort;

  /// Parola üreticisinin son kullanılan seçenekleri.
  final GeneratorPreferences generator;

  /// Otomatik yedeğin klasörü; kapalıysa `null`.
  final AutoBackupFolder? autoBackupFolder;

  /// Arka plana geçince kilitlenmeden önceki bekleme.
  final BackgroundLock backgroundLock;

  /// Gizli olmayan kutularda (ad, site, klasör, arama) normal klavye.
  final bool plainKeyboard;

  /// Senkron bilgileri; kapalıysa `null`.
  final SyncSettings? sync;

  /// Yedek zamanları yalnızca ileri alınır, silinmez; bu yüzden `null`
  /// verilen alan olduğu gibi kalır.
  AppSettings copyWith({
    bool? otpRequireAuth,
    bool? autofillCopyOtp,
    DateTime? lastBackupAt,
    DateTime? backupReminderSnoozedUntil,
    LoginSort? vaultSort,
    GeneratorPreferences? generator,
    BackgroundLock? backgroundLock,
    bool? plainKeyboard,
  }) => AppSettings(
    otpRequireAuth: otpRequireAuth ?? this.otpRequireAuth,
    autofillCopyOtp: autofillCopyOtp ?? this.autofillCopyOtp,
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    backupReminderSnoozedUntil:
        backupReminderSnoozedUntil ?? this.backupReminderSnoozedUntil,
    vaultSort: vaultSort ?? this.vaultSort,
    generator: generator ?? this.generator,
    autoBackupFolder: autoBackupFolder,
    backgroundLock: backgroundLock ?? this.backgroundLock,
    plainKeyboard: plainKeyboard ?? this.plainKeyboard,
    sync: sync,
  );

  /// Otomatik yedeğin klasörünü değiştirir; `null` kapatır. [copyWith] bu
  /// alana dokunmaz.
  AppSettings withAutoBackupFolder(AutoBackupFolder? folder) => AppSettings(
    otpRequireAuth: otpRequireAuth,
    autofillCopyOtp: autofillCopyOtp,
    lastBackupAt: lastBackupAt,
    backupReminderSnoozedUntil: backupReminderSnoozedUntil,
    vaultSort: vaultSort,
    generator: generator,
    autoBackupFolder: folder,
    backgroundLock: backgroundLock,
    plainKeyboard: plainKeyboard,
    sync: sync,
  );

  /// Senkron bilgilerini değiştirir; `null` kapatır. [copyWith] bu alana
  /// dokunmaz.
  AppSettings withSync(SyncSettings? sync) => AppSettings(
    otpRequireAuth: otpRequireAuth,
    autofillCopyOtp: autofillCopyOtp,
    lastBackupAt: lastBackupAt,
    backupReminderSnoozedUntil: backupReminderSnoozedUntil,
    vaultSort: vaultSort,
    generator: generator,
    autoBackupFolder: autoBackupFolder,
    backgroundLock: backgroundLock,
    plainKeyboard: plainKeyboard,
    sync: sync,
  );

  Uint8List toJsonBytes() => utf8.encode(
    jsonEncode({
      'version': currentVersion,
      'otpRequireAuth': otpRequireAuth,
      'autofillCopyOtp': autofillCopyOtp,
      'lastBackupAt': lastBackupAt?.millisecondsSinceEpoch,
      'backupReminderSnoozedUntil':
          backupReminderSnoozedUntil?.millisecondsSinceEpoch,
      'vaultSort': _sortName(vaultSort),
      'generator': generator.toJson(),
      'autoBackupFolder': autoBackupFolder?.toJson(),
      'backgroundLockSeconds': backgroundLock.seconds,
      'plainKeyboard': plainKeyboard,
      'sync': sync?.toJson(),
    }),
  );

  /// Yeni bir sıralama eklenirse derleyici burada adını ister; yoksa kayıt
  /// `null` yazar ve bir sonraki açılışta okunamazdı.
  static String _sortName(LoginSort sort) => switch (sort) {
    LoginSort.name => 'name',
    LoginSort.recentlyUpdated => 'recent',
  };

  /// Biçime uymayan içerikte `null` döner.
  static AppSettings? tryParse(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;
    // Sürüm 1'de kod kopyalama yoktu; varsayılanı açık. Sürüm 3'ten önce
    // yedek bilgisi, sürüm 4'ten önce sıralama ve üretici, sürüm 5'ten önce
    // otomatik yedek, sürüm 6'dan önce arka plan kilidi süresi ve klavye
    // ayarı, sürüm 7'den önce senkron yoktu.
    const v3 = {
      'version',
      'otpRequireAuth',
      'autofillCopyOtp',
      'lastBackupAt',
      'backupReminderSnoozedUntil',
    };
    const v6 = {
      ...v3,
      'vaultSort',
      'generator',
      'autoBackupFolder',
      'backgroundLockSeconds',
      'plainKeyboard',
    };
    final version = decoded['version'];
    final keys = switch (version) {
      1 => const {'version', 'otpRequireAuth'},
      2 => const {'version', 'otpRequireAuth', 'autofillCopyOtp'},
      3 => v3,
      4 => const {...v3, 'vaultSort', 'generator'},
      5 => const {...v3, 'vaultSort', 'generator', 'autoBackupFolder'},
      6 => v6,
      currentVersion => const {...v6, 'sync'},
      _ => null,
    };
    if (keys == null ||
        decoded.length != keys.length ||
        !keys.containsAll(decoded.keys)) {
      return null;
    }
    final otpRequireAuth = decoded['otpRequireAuth'];
    final autofillCopyOtp =
        decoded['autofillCopyOtp'] ?? defaults.autofillCopyOtp;
    if (otpRequireAuth is! bool || autofillCopyOtp is! bool) return null;
    final lastBackupAt = decoded['lastBackupAt'];
    final snoozedUntil = decoded['backupReminderSnoozedUntil'];
    if (!_isTime(lastBackupAt) || !_isTime(snoozedUntil)) return null;
    var vaultSort = LoginSort.name;
    var generator = GeneratorPreferences.defaults;
    if (version case 4 || 5 || 6 || currentVersion) {
      final sortName = decoded['vaultSort'];
      final sort = LoginSort.values
          .where((s) => _sortName(s) == sortName)
          .firstOrNull;
      final parsed = GeneratorPreferences.tryParse(decoded['generator']);
      if (sort == null || parsed == null) return null;
      vaultSort = sort;
      generator = parsed;
    }
    AutoBackupFolder? autoBackupFolder;
    if (version case 5 || 6 || currentVersion) {
      final folder = decoded['autoBackupFolder'];
      if (folder != null) {
        autoBackupFolder = AutoBackupFolder.tryParse(folder);
        if (autoBackupFolder == null) return null;
      }
    }
    var backgroundLock = BackgroundLock.immediately;
    var plainKeyboard = false;
    if (version case 6 || currentVersion) {
      final lock = BackgroundLock.bySeconds(decoded['backgroundLockSeconds']);
      final plain = decoded['plainKeyboard'];
      if (lock == null || plain is! bool) return null;
      backgroundLock = lock;
      plainKeyboard = plain;
    }
    SyncSettings? sync;
    if (version == currentVersion && decoded['sync'] != null) {
      sync = SyncSettings.tryParse(decoded['sync']);
      if (sync == null) return null;
    }
    return AppSettings(
      otpRequireAuth: otpRequireAuth,
      autofillCopyOtp: autofillCopyOtp,
      lastBackupAt: _toTime(lastBackupAt),
      backupReminderSnoozedUntil: _toTime(snoozedUntil),
      vaultSort: vaultSort,
      generator: generator,
      autoBackupFolder: autoBackupFolder,
      backgroundLock: backgroundLock,
      plainKeyboard: plainKeyboard,
      sync: sync,
    );
  }

  /// Zaman alanı yok, `null` veya 1970'ten beri geçen milisaniye olabilir.
  static bool _isTime(Object? value) =>
      value == null || (value is int && value >= 0);

  static DateTime? _toTime(Object? value) => value is int
      ? DateTime.fromMillisecondsSinceEpoch(value, isUtc: true)
      : null;
}

/// Ayarları kayıt anahtarıyla şifreleyip tek bir kayıtta saklar.
class SettingsRepository {
  new({
    required this._store,
    required this._session,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const recordType = 'settings';

  /// Ayarlar tek kayıttır, kimliği sabittir. Tür ek doğrulama verisinde
  /// olduğu için başka bir kaydın yerine konamaz.
  static Uint8List get recordId => Uint8List(RecordCipher.recordIdLength);

  final VaultStore _store;
  final VaultSession _session;
  final DateTime Function() _clock;

  /// Kayıt yoksa [AppSettings.defaults], okunamazsa
  /// [AppSettings.requireAuth] döner. Okunamayan kayda dokunulmaz.
  Future<AppSettings> load() async {
    final stored = await _store.getRecord(recordId);
    if (stored == null) return AppSettings.defaults;
    if (stored.type != recordType) return AppSettings.requireAuth;
    final Uint8List plain;
    try {
      plain = _session.records.decrypt(
        recordId: recordId,
        type: recordType,
        blob: stored.blob,
      );
    } on CorruptedDataException {
      return AppSettings.requireAuth;
    }
    try {
      return AppSettings.tryParse(plain) ?? AppSettings.requireAuth;
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
  }

  Future<void> save(AppSettings settings) async {
    final plain = settings.toJsonBytes();
    try {
      final now = _clock();
      final existing = await _store.getRecord(recordId);
      await _store.putRecord(
        StoredRecord(
          id: recordId,
          type: recordType,
          blob: _session.records.encrypt(
            recordId: recordId,
            type: recordType,
            plainText: plain,
          ),
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_session.dart';

/// Kasanın içinde, şifreli saklanan ayarlar.
///
/// Biçim güvenlik tasarımı belgesinde. Okurken doğrulama katıdır.
final class AppSettings {
  const new({
    required this.otpRequireAuth,
    required this.autofillCopyOtp,
    this.lastBackupAt,
    this.backupReminderSnoozedUntil,
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
  /// [backupReminderSnoozedUntil]) ekledi. Eski sürümler okunmaya devam eder.
  static const currentVersion = 3;

  /// 2FA kodlarını göstermeden önce parmak izi veya ana parola istenir.
  final bool otpRequireAuth;

  /// Otomatik doldurmadan sonra kayda bağlı 2FA hesabının güncel kodu güvenli
  /// panoya kopyalanır.
  final bool autofillCopyOtp;

  /// Son başarılı yedeğin zamanı; hiç yedek alınmadıysa `null`.
  final DateTime? lastBackupAt;

  /// Yedek hatırlatıcısı bu zamana kadar gösterilmez.
  final DateTime? backupReminderSnoozedUntil;

  /// Yedek zamanları yalnızca ileri alınır, silinmez; bu yüzden `null`
  /// verilen alan olduğu gibi kalır.
  AppSettings copyWith({
    bool? otpRequireAuth,
    bool? autofillCopyOtp,
    DateTime? lastBackupAt,
    DateTime? backupReminderSnoozedUntil,
  }) => AppSettings(
    otpRequireAuth: otpRequireAuth ?? this.otpRequireAuth,
    autofillCopyOtp: autofillCopyOtp ?? this.autofillCopyOtp,
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    backupReminderSnoozedUntil:
        backupReminderSnoozedUntil ?? this.backupReminderSnoozedUntil,
  );

  Uint8List toJsonBytes() => utf8.encode(
    jsonEncode({
      'version': currentVersion,
      'otpRequireAuth': otpRequireAuth,
      'autofillCopyOtp': autofillCopyOtp,
      'lastBackupAt': lastBackupAt?.millisecondsSinceEpoch,
      'backupReminderSnoozedUntil':
          backupReminderSnoozedUntil?.millisecondsSinceEpoch,
    }),
  );

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
    // yedek bilgisi yoktu.
    final keys = switch (decoded['version']) {
      1 => const {'version', 'otpRequireAuth'},
      2 => const {'version', 'otpRequireAuth', 'autofillCopyOtp'},
      currentVersion => const {
        'version',
        'otpRequireAuth',
        'autofillCopyOtp',
        'lastBackupAt',
        'backupReminderSnoozedUntil',
      },
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
    return AppSettings(
      otpRequireAuth: otpRequireAuth,
      autofillCopyOtp: autofillCopyOtp,
      lastBackupAt: _toTime(lastBackupAt),
      backupReminderSnoozedUntil: _toTime(snoozedUntil),
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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/crypto/vault_crypto.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:sodium/sodium_sumo.dart';

/// Açılmış ve bütün kayıtları doğrulanmış bir yedek.
///
/// Kasa anahtarı korumalı bellektedir; işi bitince [dispose] çağrılmalıdır.
final class OpenedBackup {
  new _({
    required this.header,
    required this._vaultKey,
    required this.createdAt,
    required this.records,
    required this.loginCount,
    required this.otpCount,
  });

  /// Ekran testleri için; kayıt içermez.
  @visibleForTesting
  factory forTesting({
    required VaultHeader header,
    required SecureKey vaultKey,
    required DateTime createdAt,
    int loginCount = 0,
    int otpCount = 0,
  }) => OpenedBackup._(
    header: header,
    vaultKey: vaultKey,
    createdAt: createdAt,
    records: const [],
    loginCount: loginCount,
    otpCount: otpCount,
  );

  final VaultHeader header;
  final SecureKey _vaultKey;
  final DateTime createdAt;
  final List<StoredRecord> records;

  /// Çöp kutusundakiler dahil.
  final int loginCount;
  final int otpCount;

  bool _disposed = false;

  /// Kasa anahtarının bir kopyası; çağıran sahiplenir.
  SecureKey copyKey() {
    if (_disposed) throw const VaultLockedException();
    return _vaultKey.copy();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _vaultKey.dispose();
  }
}

/// Yedeği açar, doğrular ve kasaya alır.
///
/// Kurallar güvenlik tasarımı belgesinin "Geri yükleme" bölümünde: önce her
/// kayıt çözülüp biçimi doğrulanır, sonra tek SQLite işleminde yazılır.
class RestoreService {
  new({required this._sodium, required this._store})
    : _codec = BackupCodec(_sodium),
      _crypto = VaultCrypto(_sodium);

  final SodiumSumo _sodium;
  final VaultStore _store;
  final BackupCodec _codec;
  final VaultCrypto _crypto;

  /// Yedek değilse veya yapısı bozuksa [InvalidBackupException].
  BackupFile parse(Uint8List bytes) => _codec.parse(bytes);

  /// Yanlış parolada [WrongSecretException], bozuk içerikte
  /// [CorruptedDataException] veya [InvalidBackupException].
  Future<OpenedBackup> openWithPassword(
    BackupFile file,
    String password,
  ) async {
    final key = await _crypto.unlockWithPassword(file.header, password);
    return await _verify(file, key);
  }

  /// Geçersiz metinde [InvalidRecoveryKeyException], başka kasanın
  /// anahtarında [WrongSecretException].
  Future<OpenedBackup> openWithRecoveryKey(BackupFile file, String text) async {
    final key = _crypto.unlockWithRecoveryKey(file.header, text);
    return await _verify(file, key);
  }

  /// Kasayı yedekle değiştirir; kasa yoksa kurar.
  ///
  /// Son yedek zamanı yedeğin içinde değildir, çünkü dosya kaydedildikten
  /// sonra yazılır. Geri yüklenen kasa bu yedeğin kendisi olduğu için ayar
  /// kaydındaki zaman en az yedeğin alındığı an yapılır; yoksa hatırlatıcı
  /// "hiç yedek yok" derdi. Ayarları hiç değiştirilmemiş bir kasanın ayar
  /// kaydı yoktur; o zaman varsayılan ayarlarla yeni bir kayıt eklenir.
  Future<void> replace(OpenedBackup backup) async {
    final cipher = _cipherFor(backup);
    final List<StoredRecord> records;
    try {
      final settingsId = SettingsRepository.recordId;
      records = [
        for (final record in backup.records)
          if (record.type == SettingsRepository.recordType)
            _withBackupTime(record, cipher, backup.createdAt)
          else
            record,
        if (!backup.records.any((record) => listEquals(record.id, settingsId)))
          _settingsRecord(
            cipher,
            AppSettings.defaults.copyWith(lastBackupAt: backup.createdAt),
            id: settingsId,
            createdAt: backup.createdAt,
            updatedAt: backup.createdAt,
          ),
      ];
    } finally {
      cipher.dispose();
    }
    await _store.replaceVault(backup.header, records);
  }

  StoredRecord _withBackupTime(
    StoredRecord record,
    RecordCipher cipher,
    DateTime createdAt,
  ) {
    final plain = cipher.decrypt(
      recordId: record.id,
      type: record.type,
      blob: record.blob,
    );
    final AppSettings? settings;
    try {
      settings = AppSettings.tryParse(plain);
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
    // Ayar kaydı açılırken doğrulandı; yine de okunamazsa olduğu gibi kalır.
    if (settings == null) return record;
    final last = settings.lastBackupAt;
    if (last != null && !last.isBefore(createdAt)) return record;
    return _settingsRecord(
      cipher,
      settings.copyWith(lastBackupAt: createdAt),
      id: record.id,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
  }

  StoredRecord _settingsRecord(
    RecordCipher cipher,
    AppSettings settings, {
    required Uint8List id,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final plain = settings.toJsonBytes();
    try {
      return StoredRecord(
        id: id,
        type: SettingsRepository.recordType,
        blob: cipher.encrypt(
          recordId: id,
          type: SettingsRepository.recordType,
          plainText: plain,
        ),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
  }

  /// Yedeğin parola ve 2FA kayıtlarını açık kasaya ekler. Ayar kaydı alınmaz.
  ///
  /// Kayıtlar açık kasanın anahtarıyla yeniden şifrelenir, kimlikleri korunur.
  Future<MergeCounts> merge(OpenedBackup backup, VaultSession session) async {
    final source = _cipherFor(backup);
    final records = <StoredRecord>[];
    try {
      for (final record in backup.records) {
        if (record.type == SettingsRepository.recordType) continue;
        final plain = source.decrypt(
          recordId: record.id,
          type: record.type,
          blob: record.blob,
        );
        try {
          records.add(
            StoredRecord(
              id: record.id,
              type: record.type,
              blob: session.records.encrypt(
                recordId: record.id,
                type: record.type,
                plainText: plain,
              ),
              createdAt: record.createdAt,
              updatedAt: record.updatedAt,
            ),
          );
        } finally {
          plain.fillRange(0, plain.length, 0);
        }
      }
    } finally {
      source.dispose();
    }
    return await _store.mergeRecords(records);
  }

  RecordCipher _cipherFor(OpenedBackup backup) {
    final key = backup.copyKey();
    final cipher = RecordCipher(_sodium, key, backup.header.vaultId);
    // RecordCipher alt anahtarları türetip kendi tutar, ana anahtar gerekmez.
    key.dispose();
    return cipher;
  }

  /// İçeriği çözer ve her kaydı biçimine göre doğrular. Bir tanesi bile
  /// açılmazsa yedek bozuk sayılır.
  Future<OpenedBackup> _verify(BackupFile file, SecureKey key) async {
    try {
      final contents = await _codec.open(file, key);
      final cipher = RecordCipher(_sodium, key, file.header.vaultId);
      var logins = 0;
      var otps = 0;
      try {
        for (final record in contents.records) {
          final plain = cipher.decrypt(
            recordId: record.id,
            type: record.type,
            blob: record.blob,
          );
          try {
            switch (record.type) {
              case LoginRepository.recordType:
                LoginContent.fromJsonBytes(plain);
                logins++;
              case RecordCipher.otpType:
                OtpContent.fromJsonBytes(plain);
                otps++;
              case SettingsRepository.recordType:
                if (AppSettings.tryParse(plain) == null) {
                  throw const InvalidBackupException('Okunamayan ayar kaydı.');
                }
            }
          } on InvalidLoginContentException {
            throw const InvalidBackupException('Okunamayan parola kaydı.');
          } on InvalidOtpContentException {
            throw const InvalidBackupException('Okunamayan 2FA kaydı.');
          } finally {
            plain.fillRange(0, plain.length, 0);
          }
        }
      } finally {
        cipher.dispose();
      }
      return OpenedBackup._(
        header: file.header,
        vaultKey: key,
        createdAt: contents.createdAt,
        records: contents.records,
        loginCount: logins,
        otpCount: otps,
      );
    } on Object {
      key.dispose();
      rethrow;
    }
  }
}

/// `main` doldurur, testler kendi servisini verir.
final restoreServiceProvider = Provider<RestoreService>(
  (ref) => throw UnimplementedError('Geri yükleme servisi sağlanmadı.'),
);

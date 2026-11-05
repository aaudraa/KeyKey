import 'package:drift/drift.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:keykey/core/storage/storage_exceptions.dart';
import 'package:keykey/core/storage/vault_database.dart';

/// Veritabanındaki bir kayıt. [blob] şifrelidir, bu katman içini bilmez.
final class StoredRecord {
  const new({
    required this.id,
    required this.type,
    required this.blob,
    required this.createdAt,
    required this.updatedAt,
  });

  final Uint8List id;
  final String type;
  final Uint8List blob;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Keystore anahtarıyla sarılmış kasa anahtarı.
final class StoredBiometricSlot {
  const new({required this.iv, required this.cipherText});

  final Uint8List iv;
  final Uint8List cipherText;
}

/// Art arda yapılmış hatalı parola denemeleri.
final class UnlockAttempts {
  const new({required this.failedAttempts, required this.lastFailedAt});

  static const none = UnlockAttempts(failedAttempts: 0, lastFailedAt: null);

  final int failedAttempts;
  final DateTime? lastFailedAt;
}

/// Kasanın diskteki hali. Şifreleme yapmaz, yalnızca okur ve yazar.
final class VaultStore {
  const new(this._database);

  static const _singleRowId = 1;

  final VaultDatabase _database;

  /// Kurulu değilse `null` döner.
  ///
  /// Üst bilgi bozuksa `InvalidVaultHeaderException` fırlatır.
  Future<VaultHeader?> readHeader() async {
    final row = await _database.select(_database.vaultMeta).getSingleOrNull();
    return row == null ? null : VaultHeader.fromJsonString(row.header);
  }

  /// Kasayı kurar. Zaten kuruluysa [VaultAlreadyExistsException] fırlatır.
  Future<void> createVault(VaultHeader header) {
    return _database.transaction(() async {
      final existing = await _database
          .select(_database.vaultMeta)
          .getSingleOrNull();
      if (existing != null) throw const VaultAlreadyExistsException();
      await _database
          .into(_database.vaultMeta)
          .insert(
            VaultMetaCompanion.insert(
              id: const Value(_singleRowId),
              header: header.toJsonString(),
            ),
          );
    });
  }

  /// Üst bilgiyi tek işlemde değiştirir.
  ///
  /// Kurulu değilse [VaultNotFoundException] fırlatır.
  Future<void> updateHeader(VaultHeader header) async {
    final changed = await _database
        .update(_database.vaultMeta)
        .write(VaultMetaCompanion(header: Value(header.toJsonString())));
    if (changed == 0) throw const VaultNotFoundException();
  }

  /// Aynı kimlikte kayıt varsa üzerine yazar.
  Future<void> putRecord(StoredRecord record) {
    return _database
        .into(_database.records)
        .insertOnConflictUpdate(
          RecordsCompanion.insert(
            id: record.id,
            type: record.type,
            payload: record.blob,
            createdAt: record.createdAt.millisecondsSinceEpoch,
            updatedAt: record.updatedAt.millisecondsSinceEpoch,
          ),
        );
  }

  Future<StoredRecord?> getRecord(Uint8List id) async {
    final query = _database.select(_database.records)
      ..where((row) => row.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toRecord(row);
  }

  Future<List<StoredRecord>> allRecords() async {
    final rows = await _database.select(_database.records).get();
    return rows.map(_toRecord).toList();
  }

  Future<void> deleteRecord(Uint8List id) async {
    final query = _database.delete(_database.records)
      ..where((row) => row.id.equals(id));
    await query.go();
  }

  Future<StoredBiometricSlot?> readBiometricSlot() async {
    final row = await _database
        .select(_database.biometricSlot)
        .getSingleOrNull();
    return row == null
        ? null
        : StoredBiometricSlot(iv: row.iv, cipherText: row.cipherText);
  }

  Future<void> writeBiometricSlot(StoredBiometricSlot slot) {
    return _database
        .into(_database.biometricSlot)
        .insertOnConflictUpdate(
          BiometricSlotCompanion.insert(
            id: const Value(_singleRowId),
            iv: slot.iv,
            cipherText: slot.cipherText,
          ),
        );
  }

  Future<void> deleteBiometricSlot() async {
    await _database.delete(_database.biometricSlot).go();
  }

  Future<UnlockAttempts> readUnlockAttempts() async {
    final row = await _database.select(_database.unlockState).getSingleOrNull();
    return row == null ? UnlockAttempts.none : _toAttempts(row);
  }

  /// Sayacı tek işlemde bir artırır ve yeni halini döndürür.
  Future<UnlockAttempts> registerFailedAttempt(DateTime now) {
    return _database.transaction(() async {
      final current = await readUnlockAttempts();
      final next = UnlockAttempts(
        failedAttempts: current.failedAttempts + 1,
        lastFailedAt: now,
      );
      await _writeAttempts(next.failedAttempts, now);
      return next;
    });
  }

  /// Son hata zamanını değiştirir, sayaca dokunmaz.
  ///
  /// Saat geri alındığında beklemenin atlanamaması için kullanılır.
  Future<void> moveLastFailure(DateTime now) async {
    await _database
        .update(_database.unlockState)
        .write(
          UnlockStateCompanion(lastFailedAt: Value(now.millisecondsSinceEpoch)),
        );
  }

  Future<void> resetUnlockAttempts() async {
    await _database.delete(_database.unlockState).go();
  }

  Future<void> _writeAttempts(int failedAttempts, DateTime lastFailedAt) {
    return _database
        .into(_database.unlockState)
        .insertOnConflictUpdate(
          UnlockStateCompanion.insert(
            id: const Value(_singleRowId),
            failedAttempts: failedAttempts,
            lastFailedAt: lastFailedAt.millisecondsSinceEpoch,
          ),
        );
  }

  static StoredRecord _toRecord(RecordRow row) => StoredRecord(
    id: row.id,
    type: row.type,
    blob: row.payload,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
  );

  static UnlockAttempts _toAttempts(UnlockStateRow row) => UnlockAttempts(
    failedAttempts: row.failedAttempts,
    lastFailedAt: DateTime.fromMillisecondsSinceEpoch(
      row.lastFailedAt,
      isUtc: true,
    ),
  );
}

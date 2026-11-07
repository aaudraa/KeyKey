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

/// Birleştirmenin sonucu.
final class MergeCounts {
  const new({required this.added, required this.updated, required this.kept});

  /// Kasada olmayan, eklenen kayıtlar.
  final int added;

  /// Yedekteki daha yeni olduğu için güncellenen kayıtlar.
  final int updated;

  /// Kasadaki aynı veya daha yeni olduğu için dokunulmayanlar.
  final int kept;
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

  /// Kasayı tek işlemde [header] ve [records] ile değiştirir.
  ///
  /// Kasa yoksa kurar. Var olan bütün kayıtlar, parmak izi yuvası ve hatalı
  /// deneme sayacı silinir. Yarıda kalırsa hiçbir şey değişmez.
  Future<void> replaceVault(VaultHeader header, List<StoredRecord> records) {
    return _database.transaction(() async {
      await _database.delete(_database.records).go();
      await _database.delete(_database.biometricSlot).go();
      await _database.delete(_database.unlockState).go();
      await _database
          .into(_database.vaultMeta)
          .insertOnConflictUpdate(
            VaultMetaCompanion.insert(
              id: const Value(_singleRowId),
              header: header.toJsonString(),
            ),
          );
      for (final record in records) {
        await _database.into(_database.records).insert(_companion(record));
      }
    });
  }

  /// Kayıtları tek işlemde ekler. Aynı kimlikte kayıt varsa `updatedAt`
  /// değeri yeni olan kalır; türü farklıysa var olana dokunulmaz.
  Future<MergeCounts> mergeRecords(List<StoredRecord> records) {
    return _database.transaction(() async {
      var added = 0;
      var updated = 0;
      var kept = 0;
      for (final record in records) {
        final existing = await getRecord(record.id);
        if (existing == null) {
          await _database.into(_database.records).insert(_companion(record));
          added++;
        } else if (existing.type == record.type &&
            record.updatedAt.isAfter(existing.updatedAt)) {
          await putRecord(record);
          updated++;
        } else {
          kept++;
        }
      }
      return MergeCounts(added: added, updated: updated, kept: kept);
    });
  }

  /// Aynı kimlikte kayıt varsa üzerine yazar.
  Future<void> putRecord(StoredRecord record) {
    return _database
        .into(_database.records)
        .insertOnConflictUpdate(_companion(record));
  }

  static RecordsCompanion _companion(StoredRecord record) =>
      RecordsCompanion.insert(
        id: record.id,
        type: record.type,
        payload: record.blob,
        createdAt: record.createdAt.millisecondsSinceEpoch,
        updatedAt: record.updatedAt.millisecondsSinceEpoch,
      );

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

  Future<List<StoredRecord>> recordsOfType(String type) async {
    final query = _database.select(_database.records)
      ..where((row) => row.type.equals(type));
    final rows = await query.get();
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

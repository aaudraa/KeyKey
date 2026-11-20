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

/// Kalıcı silinen bir kaydın izi: kimlik ve silinme anı. İçerik ve tür
/// taşımaz. Senkronda başka telefonun dosyası silinen kaydı geri getirmesin
/// diye tutulur.
final class StoredTombstone {
  const new({required this.id, required this.deletedAt});

  final Uint8List id;
  final DateTime deletedAt;
}

/// Üst bilgideki yuvaların son değiştiği anlar; 1.8.0'dan beri
/// değişmediyse `null`. Senkron iki yuvayı bunlara bakarak ayrı ayrı
/// birleştirir.
final class HeaderTimes {
  const new({this.passwordChangedAt, this.recoveryChangedAt});

  final DateTime? passwordChangedAt;
  final DateTime? recoveryChangedAt;
}

/// Senkronun kasaya tek işlemde yazdığı değişiklikler.
final class StoreChanges {
  const new({
    this.put = const [],
    this.delete = const [],
    this.addTombstones = const [],
    this.removeTombstones = const [],
    this.header,
    this.times,
  });

  /// Yazılacak kayıtlar; aynı kimlikte kayıt varsa üzerine yazılır.
  final List<StoredRecord> put;

  /// Silinecek kayıtlar. Bu yolda ek silme kaydı yazılmaz; gerekenler
  /// [addTombstones]'ta gelir.
  final List<Uint8List> delete;

  /// Yazılacak silme kayıtları; aynı kimlikte daha yenisi varsa o kalır.
  final List<StoredTombstone> addTombstones;

  /// Kaldırılacak silme kayıtları (silindikten sonra yeniden değişen kayıt).
  final List<Uint8List> removeTombstones;

  /// Verilirse üst bilgi; [times] ile birlikte yazılır.
  final VaultHeader? header;
  final HeaderTimes? times;

  bool get isEmpty =>
      put.isEmpty &&
      delete.isEmpty &&
      addTombstones.isEmpty &&
      removeTombstones.isEmpty &&
      header == null &&
      times == null;
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

  /// Ayar kaydının türü (`SettingsRepository.recordType`). Ayar kaydı cihaza
  /// aittir, senkrona girmez; silinince silme kaydı yazılmaz.
  static const _settingsType = 'settings';

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

  /// Üst bilgiyi tek işlemde değiştirir. Verilen yuva zamanları aynı
  /// yazmada kaydedilir, verilmeyenlere dokunulmaz.
  ///
  /// Kurulu değilse [VaultNotFoundException] fırlatır.
  Future<void> updateHeader(
    VaultHeader header, {
    DateTime? passwordChangedAt,
    DateTime? recoveryChangedAt,
  }) async {
    final changed = await _database
        .update(_database.vaultMeta)
        .write(
          VaultMetaCompanion(
            header: Value(header.toJsonString()),
            passwordChangedAt: passwordChangedAt == null
                ? const Value.absent()
                : Value(passwordChangedAt.millisecondsSinceEpoch),
            recoveryChangedAt: recoveryChangedAt == null
                ? const Value.absent()
                : Value(recoveryChangedAt.millisecondsSinceEpoch),
          ),
        );
    if (changed == 0) throw const VaultNotFoundException();
  }

  /// Yuvaların son değiştiği anlar. Kasa kurulu değilse ikisi de `null`.
  Future<HeaderTimes> readHeaderTimes() async {
    final row = await _database.select(_database.vaultMeta).getSingleOrNull();
    return HeaderTimes(
      passwordChangedAt: _timeOrNull(row?.passwordChangedAt),
      recoveryChangedAt: _timeOrNull(row?.recoveryChangedAt),
    );
  }

  /// Kasayı tek işlemde [header] ve [records] ile değiştirir.
  ///
  /// Kasa yoksa kurar. Var olan bütün kayıtlar, silme kayıtları, parmak izi
  /// yuvası ve hatalı deneme sayacı silinir; [tombstones] ve [times] yazılır.
  /// Yarıda kalırsa hiçbir şey değişmez.
  Future<void> replaceVault(
    VaultHeader header,
    List<StoredRecord> records, {
    List<StoredTombstone> tombstones = const [],
    HeaderTimes times = const HeaderTimes(),
  }) {
    return _database.transaction(() async {
      await _database.delete(_database.records).go();
      await _database.delete(_database.tombstones).go();
      await _database.delete(_database.biometricSlot).go();
      await _database.delete(_database.unlockState).go();
      await _database
          .into(_database.vaultMeta)
          .insertOnConflictUpdate(
            VaultMetaCompanion.insert(
              id: const Value(_singleRowId),
              header: header.toJsonString(),
              passwordChangedAt: Value(
                times.passwordChangedAt?.millisecondsSinceEpoch,
              ),
              recoveryChangedAt: Value(
                times.recoveryChangedAt?.millisecondsSinceEpoch,
              ),
            ),
          );
      for (final record in records) {
        await _database.into(_database.records).insert(_companion(record));
      }
      for (final tombstone in tombstones) {
        await _putTombstone(tombstone);
      }
    });
  }

  /// Kayıtları tek işlemde ekler. Aynı kimlikte kayıt varsa `updatedAt`
  /// değeri yeni olan kalır; türü farklıysa var olana dokunulmaz.
  ///
  /// Eklenen ya da güncellenen kaydın silme kaydı kaldırılır: geri gelen
  /// kayıt senkronda yeniden silinmez. [stampAt] verilirse (senkron açık)
  /// bu kayıtların `updatedAt` değeri o an yapılır; karşılaştırma yine
  /// kaydın kendi zamanıyladır. Zaman şifreli içerikte değildir.
  Future<MergeCounts> mergeRecords(
    List<StoredRecord> records, {
    DateTime? stampAt,
  }) {
    return _database.transaction(() async {
      var added = 0;
      var updated = 0;
      var kept = 0;
      for (final record in records) {
        final existing = await getRecord(record.id);
        final stamped = stampAt == null
            ? record
            : StoredRecord(
                id: record.id,
                type: record.type,
                blob: record.blob,
                createdAt: record.createdAt,
                updatedAt: stampAt,
              );
        if (existing == null) {
          await _database.into(_database.records).insert(_companion(stamped));
          added++;
        } else if (existing.type == record.type &&
            record.updatedAt.isAfter(existing.updatedAt)) {
          await putRecord(stamped);
          updated++;
        } else {
          kept++;
          continue;
        }
        final query = _database.delete(_database.tombstones)
          ..where((row) => row.id.equals(record.id));
        await query.go();
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

  /// Verilen türlerdeki kayıtların en son değiştiği an; kayıt yoksa `null`.
  ///
  /// Zaman damgaları şifresiz olduğu için kasa anahtarı gerekmez.
  Future<DateTime?> latestUpdate(Set<String> types) async {
    final latest = _database.records.updatedAt.max();
    final query = _database.selectOnly(_database.records)
      ..addColumns([latest])
      ..where(_database.records.type.isIn(types));
    final value = await query.map((row) => row.read(latest)).getSingle();
    return value == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  /// Kaydı siler ve aynı işlemde silme kaydını yazar ([deletedAt] verilmezse
  /// şimdi). Aynı kimlikte silme kaydı varsa büyük zaman kalır. Ayar kaydı
  /// ve olmayan kayıt için silme kaydı yazılmaz.
  Future<void> deleteRecord(Uint8List id, {DateTime? deletedAt}) {
    return _database.transaction(() async {
      final existing = await getRecord(id);
      if (existing == null) return;
      final query = _database.delete(_database.records)
        ..where((row) => row.id.equals(id));
      await query.go();
      if (existing.type == _settingsType) return;
      await _putTombstone(
        StoredTombstone(id: id, deletedAt: deletedAt ?? DateTime.now()),
      );
    });
  }

  /// Senkronun değişikliklerini tek işlemde yazar. Yarıda kalırsa hiçbir şey
  /// değişmez.
  Future<void> applyChanges(StoreChanges changes) {
    return _database.transaction(() async {
      for (final record in changes.put) {
        await putRecord(record);
      }
      for (final id in changes.delete) {
        final query = _database.delete(_database.records)
          ..where((row) => row.id.equals(id));
        await query.go();
      }
      for (final tombstone in changes.addTombstones) {
        await _putTombstone(tombstone);
      }
      for (final id in changes.removeTombstones) {
        final query = _database.delete(_database.tombstones)
          ..where((row) => row.id.equals(id));
        await query.go();
      }
      final header = changes.header;
      final times = changes.times;
      if (header != null || times != null) {
        await _database
            .update(_database.vaultMeta)
            .write(
              VaultMetaCompanion(
                header: header == null
                    ? const Value.absent()
                    : Value(header.toJsonString()),
                passwordChangedAt: times == null
                    ? const Value.absent()
                    : Value(times.passwordChangedAt?.millisecondsSinceEpoch),
                recoveryChangedAt: times == null
                    ? const Value.absent()
                    : Value(times.recoveryChangedAt?.millisecondsSinceEpoch),
              ),
            );
      }
    });
  }

  /// Bütün silme kayıtları.
  Future<List<StoredTombstone>> allTombstones() async {
    final rows = await _database.select(_database.tombstones).get();
    return [
      for (final row in rows)
        StoredTombstone(
          id: row.id,
          deletedAt: DateTime.fromMillisecondsSinceEpoch(
            row.deletedAt,
            isUtc: true,
          ),
        ),
    ];
  }

  /// Silme kaydını yazar; aynı kimlikte daha yenisi varsa ona dokunmaz.
  Future<void> _putTombstone(StoredTombstone tombstone) async {
    final query = _database.select(_database.tombstones)
      ..where((row) => row.id.equals(tombstone.id));
    final existing = await query.getSingleOrNull();
    final at = tombstone.deletedAt.millisecondsSinceEpoch;
    if (existing != null && existing.deletedAt >= at) return;
    await _database
        .into(_database.tombstones)
        .insertOnConflictUpdate(
          TombstonesCompanion.insert(id: tombstone.id, deletedAt: at),
        );
  }

  static DateTime? _timeOrNull(int? value) => value == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);

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

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';

import 'test_data.dart';

void main() {
  late VaultDatabase database;
  late VaultStore store;

  final t1 = DateTime.utc(2026, 11);
  final t2 = DateTime.utc(2026, 11, 2);
  final t3 = DateTime.utc(2026, 11, 3);

  Uint8List id(int n) => Uint8List(16)..[15] = n;

  StoredRecord record(int n, DateTime at, [int blob = 1]) => StoredRecord(
    id: id(n),
    type: 'login',
    blob: Uint8List.fromList([blob]),
    createdAt: t1,
    updatedAt: at,
  );

  setUp(() async {
    database = VaultDatabase(NativeDatabase.memory());
    store = VaultStore(database);
    await store.createVault(sampleHeader());
  });

  tearDown(() => database.close());

  test('değişiklikler tek seferde uygulanıyor', () async {
    await store.putRecord(record(1, t1));
    await store.putRecord(record(2, t1));
    await store.putRecord(record(3, t1));
    await store.deleteRecord(id(4), deletedAt: t1);
    await store.putRecord(record(5, t1));
    await store.deleteRecord(id(5), deletedAt: t1);

    await store.applyChanges(
      StoreChanges(
        put: [record(1, t2, 9), record(6, t2)],
        delete: [id(2)],
        addTombstones: [
          StoredTombstone(id: id(2), deletedAt: t2),
          StoredTombstone(id: id(5), deletedAt: t3),
        ],
        removeTombstones: [id(4)],
        header: sampleHeader(fill: 2),
        times: HeaderTimes(passwordChangedAt: t3),
      ),
    );

    final records = {for (final r in await store.allRecords()) r.id[15]: r};
    expect(records.keys, unorderedEquals([1, 3, 6]));
    expect(records[1]!.blob, [9]);
    expect(records[1]!.updatedAt, t2);
    final tombstones = {
      for (final t in await store.allTombstones()) t.id[15]: t.deletedAt,
    };
    // Silinen 2 için yalnızca verilen silme kaydı var, ek bir tane yazılmadı.
    expect(tombstones, {2: t2, 5: t3});
    expect(
      (await store.readHeader())?.toJsonString(),
      sampleHeader(fill: 2).toJsonString(),
    );
    final times = await store.readHeaderTimes();
    expect(times.passwordChangedAt, t3);
    expect(times.recoveryChangedAt, isNull);
  });

  test('verilmeyen üst bilgiye ve zamanlara dokunulmuyor', () async {
    await store.updateHeader(sampleHeader(), passwordChangedAt: t1);

    await store.applyChanges(StoreChanges(put: [record(1, t2)]));

    expect(
      (await store.readHeader())?.toJsonString(),
      sampleHeader().toJsonString(),
    );
    expect((await store.readHeaderTimes()).passwordChangedAt, t1);
  });

  test('silme kaydı daha yenisinin üstüne yazılmıyor', () async {
    await store.putRecord(record(1, t1));
    await store.deleteRecord(id(1), deletedAt: t3);

    await store.applyChanges(
      StoreChanges(
        addTombstones: [StoredTombstone(id: id(1), deletedAt: t2)],
      ),
    );

    expect((await store.allTombstones()).single.deletedAt, t3);
  });

  test('ortada hata olursa hiçbir şey değişmiyor', () async {
    await store.putRecord(record(1, t1));
    final broken = StoredRecord(
      id: Uint8List(15),
      type: 'login',
      blob: Uint8List(1),
      createdAt: t1,
      updatedAt: t2,
    );

    await expectLater(
      store.applyChanges(
        StoreChanges(
          put: [record(1, t2, 9), broken],
          header: sampleHeader(fill: 2),
        ),
      ),
      throwsA(anything),
    );

    expect((await store.allRecords()).single.blob, [1]);
    expect(
      (await store.readHeader())?.toJsonString(),
      sampleHeader().toJsonString(),
    );
  });

  test('boş değişiklik boş sayılıyor', () {
    expect(const StoreChanges().isEmpty, isTrue);
    expect(StoreChanges(delete: [id(1)]).isEmpty, isFalse);
  });
}

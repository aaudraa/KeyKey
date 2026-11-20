import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/features/sync/application/sync_merger.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../core/storage/test_data.dart';

void main() {
  late SodiumSumo sodium;
  late RecordCipher cipher;
  late VaultHeader header;

  final now = DateTime.utc(2026, 11, 20, 12);
  final t1 = now.subtract(const Duration(days: 3));
  final t2 = now.subtract(const Duration(days: 2));
  final t3 = now.subtract(const Duration(days: 1));

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    header = sampleHeader();
    cipher = RecordCipher(
      sodium,
      sodium.secureCopy(Uint8List(32)..fillRange(0, 32, 5)),
      header.vaultId,
    );
  });

  tearDownAll(() => cipher.dispose());

  Uint8List id(int n) => Uint8List(16)..[15] = n;

  StoredRecord login(int n, DateTime at, {String name = 'A'}) => StoredRecord(
    id: id(n),
    type: 'login',
    blob: cipher.encrypt(
      recordId: id(n),
      type: 'login',
      plainText: LoginContent(name: name).toJsonBytes(),
    ),
    createdAt: t1,
    updatedAt: at,
  );

  StoredRecord note(int n, DateTime at) => StoredRecord(
    id: id(n),
    type: 'note',
    blob: cipher.encrypt(
      recordId: id(n),
      type: 'note',
      plainText: NoteContent(name: 'N', text: 'metin').toJsonBytes(),
    ),
    createdAt: t1,
    updatedAt: at,
  );

  StoredTombstone gone(int n, DateTime at) =>
      StoredTombstone(id: id(n), deletedAt: at);

  SyncSource source(
    String device,
    List<StoredRecord> records, {
    List<StoredTombstone> deleted = const [],
  }) => SyncSource(
    device: device,
    header: header,
    contents: BackupContents(
      createdAt: now,
      records: records,
      version: BackupCodec.payloadVersion,
      sync: SyncInfo(device: device, deleted: deleted),
    ),
  );

  LocalState local(
    List<StoredRecord> records, {
    List<StoredTombstone> tombstones = const [],
  }) => LocalState(
    records: records,
    tombstones: tombstones,
    header: header,
    times: const HeaderTimes(),
  );

  SyncPlan merge(LocalState state, List<SyncSource> sources) =>
      SyncMerger(cipher: cipher, now: now).merge(state, sources);

  String name(StoredRecord record) => LoginContent.fromJsonBytes(
    cipher.decrypt(recordId: record.id, type: record.type, blob: record.blob),
  ).name;

  List<int> ids(List<Uint8List> list) => [for (final i in list) i[15]];

  group('kayıtlar', () {
    test('yeni olan kazanıyor', () {
      final plan = merge(local([login(1, t1, name: 'Eski')]), [
        source('b00001', [login(1, t2, name: 'Yeni')]),
      ]);
      expect(name(plan.changes.put.single), 'Yeni');
      expect(plan.changes.put.single.updatedAt, t2);
      expect(plan.changes.delete, isEmpty);

      final reverse = merge(local([login(1, t2, name: 'Yeni')]), [
        source('b00001', [login(1, t1, name: 'Eski')]),
      ]);
      expect(reverse.isEmpty, isTrue);
    });

    test('eşit zamanda bayt sırası her sırada aynı sonucu veriyor', () {
      final x = login(1, t2, name: 'X');
      final y = login(1, t2, name: 'Y');
      final first = merge(local([]), [
        source('b00001', [x]),
        source('c00001', [y]),
      ]);
      final second = merge(local([]), [
        source('c00001', [y]),
        source('b00001', [x]),
      ]);
      expect(first.changes.put.single.blob, second.changes.put.single.blob);

      // Küçük olanı tutan telefon büyüğü alır, büyüğü tutan bir şey almaz.
      final larger = first.changes.put.single;
      final smaller = identical(larger.blob, x.blob) ? y : x;
      expect(
        merge(local([smaller]), [
          source('b00001', [larger]),
        ]).changes.put.single.blob,
        larger.blob,
      );
      expect(
        merge(local([larger]), [
          source('b00001', [smaller]),
        ]).isEmpty,
        isTrue,
      );
    });

    test('aynı durum boş plan veriyor', () {
      final record = login(1, t2);
      final plan = merge(local([record], tombstones: [gone(2, t1)]), [
        source('b00001', [record], deleted: [gone(2, t1)]),
      ]);
      expect(plan.isEmpty, isTrue);
      expect(plan.issues, isEmpty);
    });
  });

  group('silme kayıtları', () {
    test('silme kaydı eski değişikliği siliyor', () {
      final plan = merge(local([login(1, t1)]), [
        source('b00001', const [], deleted: [gone(1, t2)]),
      ]);
      expect(ids(plan.changes.delete), [1]);
      expect(plan.changes.addTombstones.single.deletedAt, t2);
      expect(plan.changes.put, isEmpty);
    });

    test('daha yeni değişiklik silmeyi yeniyor, silme kaydı kalkıyor', () {
      final plan = merge(local(const [], tombstones: [gone(1, t1)]), [
        source('b00001', [login(1, t2, name: 'Geri')]),
      ]);
      expect(name(plan.changes.put.single), 'Geri');
      expect(ids(plan.changes.removeTombstones), [1]);
    });

    test('eşit zamanda silme kazanıyor', () {
      final plan = merge(local([login(1, t2)]), [
        source('b00001', const [], deleted: [gone(1, t2)]),
      ]);
      expect(ids(plan.changes.delete), [1]);
    });

    test('kaydı hiç görülmemiş silme kaydı da yazılıyor', () {
      final plan = merge(local(const []), [
        source('b00001', const [], deleted: [gone(9, t1)]),
      ]);
      expect(ids(plan.changes.addTombstones.map((t) => t.id).toList()), [9]);
      expect(plan.changes.delete, isEmpty);
    });

    test('yereldeki daha yeni silme kaydına dokunulmuyor', () {
      final plan = merge(local(const [], tombstones: [gone(1, t3)]), [
        source('b00001', const [], deleted: [gone(1, t1)]),
      ]);
      expect(plan.isEmpty, isTrue);
    });

    test('aylarca kapalı kalan telefonun dosyası geri getirmiyor', () {
      // A: 1 kalıcı silindi (t3), 2 değişti (t3). B aynı durumda.
      // C aylar önceki halinde: 1 ve 2'nin eski sürümleri.
      final edited = login(2, t3, name: 'Yeni');
      final state = local([edited], tombstones: [gone(1, t3)]);
      final plan = merge(state, [
        source('b00001', [edited], deleted: [gone(1, t3)]),
        source('c00001', [login(1, t1), login(2, t1, name: 'Eski')]),
      ]);
      expect(plan.isEmpty, isTrue);
    });
  });

  group('bozuk kaynak', () {
    test('açılmayan kayıt o kaynağı bütünüyle düşürüyor', () {
      final broken = StoredRecord(
        id: id(1),
        type: 'login',
        blob: Uint8List.fromList(List.filled(80, 7)),
        createdAt: t1,
        updatedAt: t2,
      );
      final plan = merge(local(const []), [
        source('b00001', [broken, login(2, t2)], deleted: [gone(3, t1)]),
        source('c00001', [login(4, t2)]),
      ]);
      expect(ids([for (final r in plan.changes.put) r.id]), [4]);
      expect(plan.changes.addTombstones, isEmpty);
      expect(
        plan.issues,
        contains(
          isA<UnreadableDevice>().having((i) => i.device, 'device', 'b00001'),
        ),
      );
    });

    test('içeriği biçime uymayan kayıt da kaynağı düşürüyor', () {
      final odd = StoredRecord(
        id: id(1),
        type: 'login',
        blob: cipher.encrypt(
          recordId: id(1),
          type: 'login',
          plainText: Uint8List.fromList(utf8.encode('{}')),
        ),
        createdAt: t1,
        updatedAt: t2,
      );
      final plan = merge(local(const []), [
        source('b00001', [odd]),
      ]);
      expect(plan.changes.put, isEmpty);
      expect(plan.issues.single, isA<UnreadableDevice>());
    });

    test('aynı kimlik başka türle gelirse kaynak düşüyor', () {
      final plan = merge(local([login(1, t1)]), [
        source('b00001', [note(1, t2), login(2, t2)]),
      ]);
      expect(plan.changes.put, isEmpty);
      expect(
        plan.issues.single,
        isA<TypeConflict>().having((i) => i.device, 'device', 'b00001'),
      );
    });
  });

  group('saat koruması', () {
    final limit = now.add(const Duration(hours: 24));

    test('24 saatten ileri kayıt ya da silme kaynağı düşürüyor', () {
      for (final bad in [
        source('b00001', [
          login(1, limit.add(const Duration(milliseconds: 1))),
        ]),
        source(
          'b00001',
          const [],
          deleted: [gone(1, limit.add(const Duration(hours: 1)))],
        ),
      ]) {
        final plan = merge(local([login(1, t1)]), [bad]);
        expect(plan.isEmpty, isTrue);
        expect(
          plan.issues.single,
          isA<ClockAhead>().having((i) => i.device, 'device', 'b00001'),
        );
      }
    });

    test('tam 24 saat ilerisi kabul ediliyor', () {
      final plan = merge(local([login(1, t1)]), [
        source('b00001', [login(1, limit, name: 'Sınırda')]),
      ]);
      expect(name(plan.changes.put.single), 'Sınırda');
      expect(plan.issues, isEmpty);
    });
  });
}

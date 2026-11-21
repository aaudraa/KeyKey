import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/crypto/vault_crypto.dart';
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

  StoredRecord login(
    int n,
    DateTime at, {
    String name = 'A',
    String password = '',
    bool favorite = false,
    List<PasswordHistoryEntry> history = const [],
  }) => StoredRecord(
    id: id(n),
    type: 'login',
    blob: cipher.encrypt(
      recordId: id(n),
      type: 'login',
      plainText: LoginContent(
        name: name,
        password: password,
        favorite: favorite,
        passwordHistory: history,
      ).toJsonBytes(),
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
    VaultHeader? head,
    DateTime? passwordAt,
    DateTime? recoveryAt,
  }) => SyncSource(
    device: device,
    header: head ?? header,
    contents: BackupContents(
      createdAt: now,
      records: records,
      version: BackupCodec.payloadVersion,
      sync: SyncInfo(
        device: device,
        passwordChangedAt: passwordAt,
        recoveryChangedAt: recoveryAt,
        deleted: deleted,
      ),
    ),
  );

  LocalState local(
    List<StoredRecord> records, {
    List<StoredTombstone> tombstones = const [],
    VaultHeader? head,
    HeaderTimes times = const HeaderTimes(),
  }) => LocalState(
    records: records,
    tombstones: tombstones,
    header: head ?? header,
    times: times,
  );

  /// Aynı kasanın, yuvaları verilen baytla doldurulmuş bir üst bilgisi.
  VaultHeader slots({int password = 1, int recovery = 1}) {
    WrappedKey slot(int fill) => WrappedKey(
      nonce: Uint8List(WrappedKey.nonceLength)..fillRange(0, 24, fill),
      cipherText: Uint8List(WrappedKey.cipherTextLength)
        ..fillRange(0, WrappedKey.cipherTextLength, fill),
    );
    return VaultHeader(
      vaultId: header.vaultId,
      kdf: header.kdf,
      passwordSlot: slot(password),
      recoverySlot: slot(recovery),
    );
  }

  LoginContent content(StoredRecord record) => LoginContent.fromJsonBytes(
    cipher.decrypt(recordId: record.id, type: record.type, blob: record.blob),
  );

  int compareBytes(Uint8List a, Uint8List b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }

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

  group('kaybeden parola', () {
    // A otomatik doldurmayla yeni parolayı kaydetti (t1); A eşitlemeden önce
    // B aynı kaydı favoriye aldı (t2).
    StoredRecord onA() => login(1, t1, password: 'yeni');
    StoredRecord onB() => login(1, t2, password: 'eski', favorite: true);

    test('kazananın geçmişine giriyor, zaman 1 ms sonrası', () {
      final plan = merge(local([onA()]), [
        source('b00001', [onB()]),
      ]);

      final rescued = plan.changes.put.single;
      expect(rescued.updatedAt, t2.add(const Duration(milliseconds: 1)));
      expect(rescued.createdAt, t1);
      final value = content(rescued);
      expect(value.favorite, isTrue);
      expect(value.password, 'eski');
      expect(value.passwordHistory, [
        PasswordHistoryEntry(password: 'yeni', changedAt: t1),
      ]);
    });

    test('iki telefon aynı sonuca varıyor, kural yeniden tetiklenmiyor', () {
      final a = onA();
      final b = onB();
      final onPhoneA = merge(local([a]), [
        source('b00001', [b]),
      ]).changes.put.single;
      final onPhoneB = merge(local([b]), [
        source('a00001', [a]),
      ]).changes.put.single;

      expect(onPhoneA.updatedAt, onPhoneB.updatedAt);
      expect(content(onPhoneA).toJsonBytes(), content(onPhoneB).toJsonBytes());

      // A, B'nin kurtardığını alır: ya hiçbir şey yazmaz ya da aynen onu.
      final winner = compareBytes(onPhoneA.blob, onPhoneB.blob) > 0
          ? onPhoneA
          : onPhoneB;
      final second = merge(local([onPhoneA]), [
        source('b00001', [onPhoneB]),
      ]);
      expect([
        for (final r in second.changes.put) r.blob,
      ], identical(winner, onPhoneA) ? isEmpty : [onPhoneB.blob]);

      // Eski dosyalar da dahil hepsi bir aradayken yeni bir kurtarma yok.
      final settled = merge(local([winner]), [
        source('a00001', [a]),
        source('b00001', [b]),
        source('c00001', [onPhoneA]),
        source('d00001', [onPhoneB]),
      ]);
      expect(settled.isEmpty, isTrue);
    });

    test('parola aynı, geçmişte ya da boşsa kurtarma yok', () {
      final old = DateTime.utc(2026);
      for (final (loser, winner) in [
        (login(1, t1, password: 'p'), login(1, t2, password: 'p')),
        (
          login(1, t1, password: 'eski'),
          login(
            1,
            t2,
            password: 'yeni',
            history: [PasswordHistoryEntry(password: 'eski', changedAt: old)],
          ),
        ),
        (login(1, t1), login(1, t2, password: 'yeni')),
      ]) {
        final plan = merge(local([loser]), [
          source('b00001', [winner]),
        ]);
        expect(plan.changes.put.single.blob, winner.blob);
        expect(plan.changes.put.single.updatedAt, t2);
      }
    });

    test('parola dışındaki türde kurtarma yok', () {
      final winner = note(1, t2);
      final plan = merge(local([note(1, t1)]), [
        source('b00001', [winner]),
      ]);
      expect(plan.changes.put.single.blob, winner.blob);
    });
  });

  group('yuvalar', () {
    test('kurtarma ve parola değişikliği ayrı ayrı birleşiyor', () async {
      final crypto = VaultCrypto(sodium);
      final created = await crypto.createVault('eski parola');
      final recovery = crypto.newRecoveryKey(created.header, created.vaultKey);
      // A kurtarma anahtarını yeniledi (t1), B ana parolayı değiştirdi (t3).
      final onA = created.header.withRecoverySlot(recovery.recoverySlot);
      final onB = await crypto.changePassword(
        created.header,
        created.vaultKey,
        'yeni parola',
      );
      created.vaultKey.dispose();

      final plan = merge(
        local(
          const [],
          head: onA,
          times: HeaderTimes(recoveryChangedAt: t1),
        ),
        [source('b00001', const [], head: onB, passwordAt: t3)],
      );
      final reverse = merge(
        local(
          const [],
          head: onB,
          times: HeaderTimes(passwordChangedAt: t3),
        ),
        [source('a00001', const [], head: onA, recoveryAt: t1)],
      );

      final merged = plan.changes.header!;
      expect(merged.toJsonString(), reverse.changes.header!.toJsonString());
      expect(plan.changes.times!.passwordChangedAt, t3);
      expect(plan.changes.times!.recoveryChangedAt, t1);
      expect(plan.issues, [isA<PasswordAdopted>()]);
      expect(reverse.issues, [isA<RecoveryAdopted>()]);

      (await crypto.unlockWithPassword(merged, 'yeni parola')).dispose();
      crypto.unlockWithRecoveryKey(merged, recovery.recoveryKeyText).dispose();
      await expectLater(
        crypto.unlockWithPassword(merged, 'eski parola'),
        throwsA(isA<WrongSecretException>()),
      );
      expect(
        () => crypto.unlockWithRecoveryKey(merged, created.recoveryKeyText),
        throwsA(isA<WrongSecretException>()),
      );
    });

    test('zamanlar boşken farklı yuva alınmıyor, bildiriliyor', () {
      final plan = merge(local(const [], head: slots()), [
        source('b00001', const [], head: slots(password: 2, recovery: 3)),
      ]);
      expect(plan.changes.header, isNull);
      expect(plan.changes.times, isNull);
      expect(
        plan.issues.single,
        isA<SlotsDiffer>().having((i) => i.device, 'device', 'b00001'),
      );
    });

    test('eski zamanlı yuva alınmıyor', () {
      final plan = merge(
        local(
          const [],
          head: slots(),
          times: HeaderTimes(passwordChangedAt: t3, recoveryChangedAt: t3),
        ),
        [
          source(
            'b00001',
            const [],
            head: slots(password: 2, recovery: 2),
            passwordAt: t2,
            recoveryAt: t2,
          ),
        ],
      );
      expect(plan.isEmpty, isTrue);
      expect(plan.issues, isEmpty);
    });

    test('eşit zamanda bayt bayt büyük yuva alınıyor', () {
      final times = HeaderTimes(passwordChangedAt: t2);
      final up = merge(local(const [], head: slots(), times: times), [
        source('b00001', const [], head: slots(password: 2), passwordAt: t2),
      ]);
      expect(
        up.changes.header!.passwordSlot.cipherText,
        slots(password: 2).passwordSlot.cipherText,
      );
      final down = merge(
        local(const [], head: slots(password: 2), times: times),
        [source('b00001', const [], head: slots(), passwordAt: t2)],
      );
      expect(down.isEmpty, isTrue);
    });

    test('başka kasanın üst bilgisini taşıyan kaynak düşüyor', () {
      final plan = merge(local(const []), [
        source('b00001', [login(4, t2)], head: sampleHeader(fill: 2)),
      ]);
      expect(plan.changes.put, isEmpty);
      expect(plan.issues.single, isA<UnreadableDevice>());
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

import 'dart:convert';
import 'dart:typed_data';

import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/features/backup/application/record_validation.dart';

/// Bir telefonun açılmış senkron dosyası.
final class SyncSource {
  const new({
    required this.device,
    required this.header,
    required this.contents,
    this.deviceName,
    this.modified,
  });

  /// Dosyanın adındaki ve içindeki kurulum kimliği.
  final String device;
  final String? deviceName;

  /// Dosyanın şifresiz başındaki üst bilgi.
  final VaultHeader header;

  /// Çözülmüş içerik; kayıtlar hâlâ kayıt biçiminde şifreli.
  final BackupContents contents;

  /// Dosyanın sunucudaki son değişme zamanı.
  final DateTime? modified;
}

/// Bu telefonun kasası, birleştirmeye girdiği haliyle.
final class LocalState {
  const new({
    required this.records,
    required this.tombstones,
    required this.header,
    required this.times,
  });

  final List<StoredRecord> records;
  final List<StoredTombstone> tombstones;
  final VaultHeader header;
  final HeaderTimes times;
}

/// Birleştirmenin kullanıcıya bildirilen durumları.
sealed class SyncIssue {
  const new();
}

/// Bir telefonun dosyası, bu telefonun saatinden 24 saatten fazla ileride
/// bir zaman taşıyor; dosya alınmadı.
final class ClockAhead extends SyncIssue {
  const new(this.device);

  final String device;
}

/// Bir telefonun dosyasındaki bir kayıt açılmadı ya da biçimine uymadı;
/// dosya alınmadı.
final class UnreadableDevice extends SyncIssue {
  const new(this.device);

  final String device;
}

/// Bir telefonun dosyasında aynı kimlik başka türle geldi; dosya alınmadı.
final class TypeConflict extends SyncIssue {
  const new(this.device);

  final String device;
}

/// Bir telefonun dosyası daha yeni bir KeyKey'in içerik sürümünde; dosya
/// alınmadı.
final class NewerApp extends SyncIssue {
  const new(this.device);

  final String device;
}

/// Birleştirmenin sonucu: kasaya yazılacaklar ve bildirilecekler.
final class SyncPlan {
  const new({required this.changes, this.issues = const []});

  final StoreChanges changes;
  final List<SyncIssue> issues;

  bool get isEmpty => changes.isEmpty;
}

/// Bu telefonun kasasını öteki telefonların senkron dosyalarıyla kayıt kayıt
/// birleştirir. Ağ ve disk bilmez; sonuç [VaultStore.applyChanges] ile tek
/// işlemde yazılır. Kurallar: `resources/docs/senkron.md`, "Birleştirme".
final class SyncMerger {
  new({required this._cipher, required this._now});

  /// Bu telefonun saatinden bu kadar ilerideki zaman güvenilmez.
  static const clockTolerance = Duration(hours: 24);

  final RecordCipher _cipher;
  final DateTime _now;

  SyncPlan merge(LocalState local, List<SyncSource> sources) {
    final issues = <SyncIssue>[];
    final limit = _now.add(clockTolerance);
    // Sıra her telefonda aynı olsun: tür çakışmasında hangi dosyanın
    // düşeceği sıraya bağlı.
    final sorted = [...sources]..sort((a, b) => a.device.compareTo(b.device));
    final types = {for (final r in local.records) _key(r.id): r.type};
    var accepted = <SyncSource>[];
    for (final source in sorted) {
      if (_isAhead(source, limit)) {
        issues.add(ClockAhead(source.device));
        continue;
      }
      if (source.contents.records.any(
        (r) => (types[_key(r.id)] ?? r.type) != r.type,
      )) {
        issues.add(TypeConflict(source.device));
        continue;
      }
      for (final r in source.contents.records) {
        types.putIfAbsent(_key(r.id), () => r.type);
      }
      accepted.add(source);
    }
    // Alınacak uzak kayıtlar çözülüp doğrulanır. Biri açılmazsa o dosya
    // bütünüyle düşer ve birleştirme kalanlarla yeniden yapılır.
    while (true) {
      final (changes, adopted) = _plan(local, accepted);
      final bad = _firstUnreadable(adopted);
      if (bad == null) return SyncPlan(changes: changes, issues: issues);
      issues.add(UnreadableDevice(bad.device));
      accepted = [
        for (final s in accepted)
          if (!identical(s, bad)) s,
      ];
    }
  }

  static bool _isAhead(SyncSource source, DateTime limit) {
    final sync = source.contents.sync;
    final times = [
      for (final r in source.contents.records) r.updatedAt,
      ...?sync?.deleted.map((t) => t.deletedAt),
      ?sync?.passwordChangedAt,
      ?sync?.recoveryChangedAt,
    ];
    return times.any((t) => t.isAfter(limit));
  }

  (StoreChanges, List<(StoredRecord, SyncSource)>) _plan(
    LocalState local,
    List<SyncSource> sources,
  ) {
    final localRecords = {for (final r in local.records) _key(r.id): r};
    final localTombs = {for (final t in local.tombstones) _key(t.id): t};
    final best = <String, (StoredRecord, SyncSource?)>{
      for (final e in localRecords.entries) e.key: (e.value, null),
    };
    final tombs = {...localTombs};
    for (final source in sources) {
      for (final record in source.contents.records) {
        final key = _key(record.id);
        final current = best[key];
        if (current == null || _isBetter(record, current.$1)) {
          best[key] = (record, source);
        }
      }
      for (final tomb
          in source.contents.sync?.deleted ?? const <StoredTombstone>[]) {
        final key = _key(tomb.id);
        final current = tombs[key];
        if (current == null || tomb.deletedAt.isAfter(current.deletedAt)) {
          tombs[key] = tomb;
        }
      }
    }

    final put = <StoredRecord>[];
    final delete = <Uint8List>[];
    final addTombstones = <StoredTombstone>[];
    final removeTombstones = <Uint8List>[];
    final adopted = <(StoredRecord, SyncSource)>[];
    final keys = {...best.keys, ...tombs.keys}.toList()..sort();
    for (final key in keys) {
      final winner = best[key];
      final tomb = tombs[key];
      final localRecord = localRecords[key];
      final localTomb = localTombs[key];
      if (tomb != null &&
          (winner == null || !tomb.deletedAt.isBefore(winner.$1.updatedAt))) {
        if (localRecord != null) delete.add(localRecord.id);
        if (localTomb == null || tomb.deletedAt.isAfter(localTomb.deletedAt)) {
          addTombstones.add(tomb);
        }
        continue;
      }
      final (record, from) = winner!;
      if (localRecord == null || !_same(localRecord, record)) {
        put.add(record);
        if (from != null) adopted.add((record, from));
      }
      if (localTomb != null) removeTombstones.add(localTomb.id);
    }
    return (
      StoreChanges(
        put: put,
        delete: delete,
        addTombstones: addTombstones,
        removeTombstones: removeTombstones,
      ),
      adopted,
    );
  }

  /// Kasaya yazılacak uzak kayıtlardan açılmayan ya da biçimine uymayan ilk
  /// kaydın dosyası; hepsi sağlamsa `null`.
  SyncSource? _firstUnreadable(List<(StoredRecord, SyncSource)> adopted) {
    for (final (record, source) in adopted) {
      final Uint8List plain;
      try {
        plain = _cipher.decrypt(
          recordId: record.id,
          type: record.type,
          blob: record.blob,
        );
      } on Exception {
        return source;
      }
      try {
        validateRecordContent(record.type, plain);
      } on Exception {
        return source;
      } finally {
        plain.fillRange(0, plain.length, 0);
      }
    }
    return null;
  }

  /// `updatedAt` büyük olan; eşitse şifreli verisi bayt bayt büyük olan.
  static bool _isBetter(StoredRecord a, StoredRecord b) {
    final byTime = a.updatedAt.compareTo(b.updatedAt);
    if (byTime != 0) return byTime > 0;
    return _compareBytes(a.blob, b.blob) > 0;
  }

  static bool _same(StoredRecord a, StoredRecord b) =>
      a.updatedAt == b.updatedAt && _compareBytes(a.blob, b.blob) == 0;

  static int _compareBytes(Uint8List a, Uint8List b) {
    final length = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }

  static String _key(Uint8List id) => base64.encode(id);
}

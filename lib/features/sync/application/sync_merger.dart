import 'dart:convert';
import 'dart:typed_data';

import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/crypto/vault_header.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/features/backup/application/record_validation.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

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

/// Ana parola başka bir telefonda değişti; parola yuvası alındı. Kasa bir
/// sonraki açılışta yeni parolayla açılır.
final class PasswordAdopted extends SyncIssue {
  const new();
}

/// Kurtarma anahtarı başka bir telefonda yenilendi; kurtarma yuvası alındı.
final class RecoveryAdopted extends SyncIssue {
  const new();
}

/// Bu telefonla [device] farklı ana parola ya da kurtarma anahtarı
/// kullanıyor ve hangisinin yeni olduğu bilinmiyor (1.8.0 öncesi değişiklik);
/// hiçbir yuva alınmadı.
final class SlotsDiffer extends SyncIssue {
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
      // Dosya bu kasanın anahtarıyla açıldıysa kimlik aynıdır; değilse bozuk.
      if (_compareBytes(source.header.vaultId, local.header.vaultId) != 0) {
        issues.add(UnreadableDevice(source.device));
        continue;
      }
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
    // Alınacak ya da parolası kurtarılacak uzak kayıtlar çözülüp doğrulanır.
    // Biri açılmazsa o dosya bütünüyle düşer ve birleştirme kalanlarla
    // yeniden yapılır.
    while (true) {
      try {
        final (records, adopted) = _plan(local, accepted);
        final bad = _firstUnreadable(adopted);
        if (bad != null) throw _BadSource(bad);
        final (header, times) = _slots(local, accepted, issues);
        return SyncPlan(
          changes: StoreChanges(
            put: records.put,
            delete: records.delete,
            addTombstones: records.addTombstones,
            removeTombstones: records.removeTombstones,
            header: header,
            times: times,
          ),
          issues: issues,
        );
      } on _BadSource catch (error) {
        issues.add(UnreadableDevice(error.source.device));
        accepted = [
          for (final s in accepted)
            if (!identical(s, error.source)) s,
        ];
      }
    }
  }

  /// Parola ve kurtarma yuvaları ayrı ayrı, kendi zamanlarıyla birleşir.
  /// Değişen yuva [issues]'a bildirilir. Bir şey değişmiyorsa ikisi de
  /// `null`.
  (VaultHeader?, HeaderTimes?) _slots(
    LocalState local,
    List<SyncSource> sources,
    List<SyncIssue> issues,
  ) {
    final differ = <String>{};
    final password = _pickSlot(
      localTime: local.times.passwordChangedAt,
      localBytes: _passwordBytes(local.header),
      sources: sources,
      timeOf: (sync) => sync?.passwordChangedAt,
      bytesOf: _passwordBytes,
      differ: differ,
    );
    final recovery = _pickSlot(
      localTime: local.times.recoveryChangedAt,
      localBytes: _recoveryBytes(local.header),
      sources: sources,
      timeOf: (sync) => sync?.recoveryChangedAt,
      bytesOf: _recoveryBytes,
      differ: differ,
    );
    issues.addAll((differ.toList()..sort()).map(SlotsDiffer.new));
    if (password == null && recovery == null) return (null, null);

    var header = local.header;
    var changed = false;
    if (password != null &&
        _compareBytes(
              _passwordBytes(password.$1.header),
              _passwordBytes(header),
            ) !=
            0) {
      header = header.withPasswordSlotFrom(password.$1.header);
      issues.add(const PasswordAdopted());
      changed = true;
    }
    if (recovery != null &&
        _compareBytes(
              _recoveryBytes(recovery.$1.header),
              _recoveryBytes(header),
            ) !=
            0) {
      header = header.withRecoverySlot(recovery.$1.header.recoverySlot);
      issues.add(const RecoveryAdopted());
      changed = true;
    }
    return (
      changed ? header : null,
      HeaderTimes(
        passwordChangedAt: password?.$2 ?? local.times.passwordChangedAt,
        recoveryChangedAt: recovery?.$2 ?? local.times.recoveryChangedAt,
      ),
    );
  }

  /// Bir yuvanın alınacağı dosya ve zamanı; yerel kalıyorsa `null`.
  ///
  /// Zamanı en büyük olan kazanır, eşitse yuvası bayt bayt büyük olan. Hiçbir
  /// tarafta zaman yoksa yuvası farklı dosyalar [differ]'e girer ve hiçbir
  /// şey alınmaz: rastgele bir seçim eski, belki sızmış bir parolayı geri
  /// getirebilirdi.
  static (SyncSource, DateTime)? _pickSlot({
    required DateTime? localTime,
    required Uint8List localBytes,
    required List<SyncSource> sources,
    required DateTime? Function(SyncInfo?) timeOf,
    required Uint8List Function(VaultHeader) bytesOf,
    required Set<String> differ,
  }) {
    (SyncSource, DateTime, Uint8List)? best;
    for (final source in sources) {
      final time = timeOf(source.contents.sync);
      if (time == null) continue;
      final bytes = bytesOf(source.header);
      if (best == null ||
          time.isAfter(best.$2) ||
          (time == best.$2 && _compareBytes(bytes, best.$3) > 0)) {
        best = (source, time, bytes);
      }
    }
    if (best == null) {
      if (localTime == null) {
        for (final source in sources) {
          if (_compareBytes(bytesOf(source.header), localBytes) != 0) {
            differ.add(source.device);
          }
        }
      }
      return null;
    }
    if (localTime != null) {
      final byTime = best.$2.compareTo(localTime);
      if (byTime < 0 ||
          (byTime == 0 && _compareBytes(best.$3, localBytes) <= 0)) {
        return null;
      }
    }
    return (best.$1, best.$2);
  }

  /// Parola yuvası KDF parametreleri ve tuzla bir bütündür.
  static Uint8List _passwordBytes(VaultHeader header) => Uint8List.fromList([
    ...header.passwordSlot.nonce,
    ...header.passwordSlot.cipherText,
    ...header.kdf.salt,
  ]);

  static Uint8List _recoveryBytes(VaultHeader header) => Uint8List.fromList([
    ...header.recoverySlot.nonce,
    ...header.recoverySlot.cipherText,
  ]);

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
    // Her kimliğin bütün sürümleri; yerelinki kaynaksız.
    final versions = <String, List<(StoredRecord, SyncSource?)>>{
      for (final e in localRecords.entries) e.key: [(e.value, null)],
    };
    final best = <String, (StoredRecord, SyncSource?)>{
      for (final e in localRecords.entries) e.key: (e.value, null),
    };
    final tombs = {...localTombs};
    for (final source in sources) {
      for (final record in source.contents.records) {
        final key = _key(record.id);
        (versions[key] ??= []).add((record, source));
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
      final rescued = record.type == LoginRepository.recordType
          ? _rescue(record, from, versions[key]!)
          : null;
      if (rescued != null) {
        put.add(rescued);
      } else if (localRecord == null || !_same(localRecord, record)) {
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

  /// Kaybeden sürümlerin parolaları kazananın geçmişine eklenmiş, yeniden
  /// şifrelenmiş kayıt; eklenecek parola yoksa `null`.
  ///
  /// Kaybedenler eskiden yeniye işlenir, en yenisi geçmişin başında kalır.
  /// `updatedAt` kazananınkinden 1 ms sonrasıdır: kurtarılmış sürüm öteki
  /// telefonlarda da düz kazananı yener. İki telefon aynı kurtarmayı yaparsa
  /// içerik aynıdır; bayt kuralıyla biri kalır ve kaybedenin parolası artık
  /// kazananınki olduğu için kural yeniden tetiklenmez.
  StoredRecord? _rescue(
    StoredRecord winner,
    SyncSource? winnerSource,
    List<(StoredRecord, SyncSource?)> versions,
  ) {
    final losers = [
      for (final version in versions)
        if (!_same(version.$1, winner)) version,
    ]..sort((a, b) => _compare(a.$1, b.$1));
    if (losers.isEmpty) return null;
    var content = _openLogin(winner, winnerSource);
    if (content == null) return null;
    var changed = false;
    for (final (loser, source) in losers) {
      final lost = _openLogin(loser, source);
      if (lost == null) continue;
      final next = content!.withRescuedPassword(lost.password, loser.updatedAt);
      if (next != null) {
        content = next;
        changed = true;
      }
    }
    if (!changed) return null;
    return StoredRecord(
      id: winner.id,
      type: winner.type,
      blob: _cipher.encrypt(
        recordId: winner.id,
        type: winner.type,
        plainText: content!.toJsonBytes(),
      ),
      createdAt: winner.createdAt,
      updatedAt: winner.updatedAt.add(const Duration(milliseconds: 1)),
    );
  }

  /// Parola kaydını çözer. Uzak kayıt açılmazsa dosyası düşer; yerel kayıt
  /// açılmazsa (bozuk yerel kasa) kurtarma yapılmaz.
  LoginContent? _openLogin(StoredRecord record, SyncSource? source) {
    try {
      final plain = _cipher.decrypt(
        recordId: record.id,
        type: record.type,
        blob: record.blob,
      );
      try {
        return LoginContent.fromJsonBytes(plain);
      } finally {
        plain.fillRange(0, plain.length, 0);
      }
    } on Exception {
      if (source != null) throw _BadSource(source);
      return null;
    }
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
  static bool _isBetter(StoredRecord a, StoredRecord b) => _compare(a, b) > 0;

  static int _compare(StoredRecord a, StoredRecord b) {
    final byTime = a.updatedAt.compareTo(b.updatedAt);
    if (byTime != 0) return byTime;
    return _compareBytes(a.blob, b.blob);
  }

  static bool _same(StoredRecord a, StoredRecord b) => _compare(a, b) == 0;

  static int _compareBytes(Uint8List a, Uint8List b) {
    final length = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }

  static String _key(Uint8List id) => base64.encode(id);
}

/// Birleştirme içinde, açılmayan uzak kaydın dosyasını düşürmek için.
final class _BadSource implements Exception {
  const new(this.source);

  final SyncSource source;
}

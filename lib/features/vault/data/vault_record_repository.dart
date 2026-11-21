import 'dart:typed_data';

import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:keykey/features/vault/data/record_content.dart';
import 'package:sodium/sodium_sumo.dart';

/// Çözülmüş bir kart ya da not kaydı. Yalnızca kasa açıkken bellekte durur.
final class VaultRecord<C> {
  const new({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final Uint8List id;
  final C content;
  final DateTime createdAt;
  final DateTime updatedAt;
}

typedef CardItem = VaultRecord<CardContent>;
typedef NoteItem = VaultRecord<NoteContent>;

/// Kayıtları yükleme sonucu.
final class LoadedRecords<C> {
  const new({required this.items, required this.unreadableCount});

  final List<VaultRecord<C>> items;

  /// Açılamayan kayıt sayısı. Bunlara dokunulmaz, kullanıcıya bildirilir.
  final int unreadableCount;
}

/// Kart ve not kayıtlarını şifreleyip saklar ve çözer.
///
/// Parola deposuyla aynı kurallar: kayıt anahtarı, AD'de tür, çöp kutusu
/// süresi. Kasa kilitlenince [VaultSession] kullanılamaz hale gelir, bu
/// yüzden her işlem anahtarlara o anda ulaşır.
class VaultRecordRepository<C extends VaultItemContent<C>> {
  new({
    required this._store,
    required this._session,
    required this._sodium,
    required this.type,
    required this._decode,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const cardType = 'card';
  static const noteType = 'note';

  /// Veritabanındaki ve AD'deki tür adı.
  final String type;

  final VaultStore _store;
  final VaultSession _session;
  final SodiumSumo _sodium;

  /// Çözülmüş baytları okur; uymayan içerikte
  /// [InvalidRecordContentException] fırlatır.
  final C Function(Uint8List bytes) _decode;
  final DateTime Function() _clock;

  /// Bütün kayıtları çözer. Açılamayan kayıt listeyi düşürmez.
  Future<LoadedRecords<C>> loadAll() async {
    final stored = await _store.recordsOfType(type);
    final cipher = _session.records;
    final items = <VaultRecord<C>>[];
    var unreadable = 0;
    for (final record in stored) {
      final item = _decrypt(cipher, record);
      if (item == null) {
        unreadable++;
      } else {
        items.add(item);
      }
    }
    return LoadedRecords(items: items, unreadableCount: unreadable);
  }

  Future<VaultRecord<C>> add(C content) async {
    final now = _clock();
    final item = VaultRecord(
      id: _sodium.randombytes.buf(RecordCipher.recordIdLength),
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    await _write(item);
    return item;
  }

  Future<VaultRecord<C>> update(VaultRecord<C> item, C content) async {
    final updated = VaultRecord(
      id: item.id,
      content: content,
      createdAt: item.createdAt,
      updatedAt: _clock(),
    );
    await _write(updated);
    return updated;
  }

  Future<void> deletePermanently(VaultRecord<C> item) =>
      _store.deleteRecord(item.id, deletedAt: _clock());

  /// Süresi dolmuş çöp kutusu kayıtlarını siler, kalanları döndürür.
  Future<List<VaultRecord<C>>> purgeExpiredTrash(
    List<VaultRecord<C>> items,
  ) async {
    final now = _clock();
    final kept = <VaultRecord<C>>[];
    for (final item in items) {
      final trashedAt = item.content.trashedAt;
      if (trashedAt != null &&
          now.difference(trashedAt) >= LoginRepository.trashRetention) {
        // Silme kaydı çöpe atılan sürümün zamanını taşır, şimdiyi değil:
        // uzun süre eşitlenmemiş bir telefonun süresi dolan çöpü, başka
        // telefonda sonradan çöpten çıkarılan ya da değişen kaydı silmesin.
        await _store.deleteRecord(item.id, deletedAt: item.updatedAt);
      } else {
        kept.add(item);
      }
    }
    return kept;
  }

  Future<void> _write(VaultRecord<C> item) async {
    final plain = item.content.toJsonBytes();
    try {
      final blob = _session.records.encrypt(
        recordId: item.id,
        type: type,
        plainText: plain,
      );
      await _store.putRecord(
        StoredRecord(
          id: item.id,
          type: type,
          blob: blob,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        ),
      );
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
  }

  VaultRecord<C>? _decrypt(RecordCipher cipher, StoredRecord record) {
    final Uint8List plain;
    try {
      plain = cipher.decrypt(
        recordId: record.id,
        type: record.type,
        blob: record.blob,
      );
    } on CorruptedDataException {
      return null;
    }
    try {
      return VaultRecord(
        id: record.id,
        content: _decode(plain),
        createdAt: record.createdAt,
        updatedAt: record.updatedAt,
      );
    } on InvalidRecordContentException {
      return null;
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
  }
}

VaultRecordRepository<CardContent> cardRepository({
  required VaultStore store,
  required VaultSession session,
  required SodiumSumo sodium,
  DateTime Function()? clock,
}) => VaultRecordRepository(
  store: store,
  session: session,
  sodium: sodium,
  type: VaultRecordRepository.cardType,
  decode: CardContent.fromJsonBytes,
  clock: clock,
);

VaultRecordRepository<NoteContent> noteRepository({
  required VaultStore store,
  required VaultSession session,
  required SodiumSumo sodium,
  DateTime Function()? clock,
}) => VaultRecordRepository(
  store: store,
  session: session,
  sodium: sodium,
  type: VaultRecordRepository.noteType,
  decode: NoteContent.fromJsonBytes,
  clock: clock,
);

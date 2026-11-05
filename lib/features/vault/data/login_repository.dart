import 'dart:typed_data';

import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:sodium/sodium_sumo.dart';

/// Çözülmüş bir parola kaydı. Yalnızca kasa açıkken bellekte durur.
final class LoginItem {
  const new({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final Uint8List id;
  final LoginContent content;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Kayıtları yükleme sonucu.
final class LoadedLogins {
  const new({required this.items, required this.unreadableCount});

  final List<LoginItem> items;

  /// Açılamayan kayıt sayısı. Bunlara dokunulmaz, kullanıcıya bildirilir.
  final int unreadableCount;
}

/// Parola kayıtlarını şifreleyip saklar ve çözer.
///
/// Kasa kilitlenince [VaultSession] kullanılamaz hale gelir, bu yüzden her
/// işlem anahtarlara o anda ulaşır.
final class LoginRepository {
  new({
    required this._store,
    required this._session,
    required this._sodium,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const recordType = 'login';

  /// Çöp kutusundaki kaydın kalıcı silinmeden önce bekleyeceği süre.
  static const trashRetention = Duration(days: 30);

  final VaultStore _store;
  final VaultSession _session;
  final SodiumSumo _sodium;
  final DateTime Function() _clock;

  /// Bütün parola kayıtlarını çözer. Açılamayan kayıt listeyi düşürmez.
  Future<LoadedLogins> loadAll() async {
    final stored = await _store.recordsOfType(recordType);
    final cipher = _session.records;
    final items = <LoginItem>[];
    var unreadable = 0;
    for (final record in stored) {
      final item = _decrypt(cipher, record);
      if (item == null) {
        unreadable++;
      } else {
        items.add(item);
      }
    }
    return LoadedLogins(items: items, unreadableCount: unreadable);
  }

  Future<LoginItem> add(LoginContent content) async {
    final now = _clock();
    final item = LoginItem(
      id: _sodium.randombytes.buf(RecordCipher.recordIdLength),
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    await _write(item);
    return item;
  }

  /// [edited] içeriğini yazar. Parola değiştiyse eskisi geçmişe eklenir.
  Future<LoginItem> update(LoginItem item, LoginContent edited) async {
    final now = _clock();
    final updated = LoginItem(
      id: item.id,
      content: item.content.applyEdit(edited, now),
      createdAt: item.createdAt,
      updatedAt: now,
    );
    await _write(updated);
    return updated;
  }

  /// Geçmişe dokunmadan yalnızca düzenleme bilgisini değiştirir: favori,
  /// klasör veya çöp kutusu.
  Future<LoginItem> updateMetadata(LoginItem item, LoginContent content) async {
    final updated = LoginItem(
      id: item.id,
      content: content,
      createdAt: item.createdAt,
      updatedAt: _clock(),
    );
    await _write(updated);
    return updated;
  }

  Future<void> deletePermanently(LoginItem item) =>
      _store.deleteRecord(item.id);

  /// Süresi dolmuş çöp kutusu kayıtlarını siler, kalanları döndürür.
  Future<List<LoginItem>> purgeExpiredTrash(List<LoginItem> items) async {
    final now = _clock();
    final kept = <LoginItem>[];
    for (final item in items) {
      final trashedAt = item.content.trashedAt;
      if (trashedAt != null && now.difference(trashedAt) >= trashRetention) {
        await deletePermanently(item);
      } else {
        kept.add(item);
      }
    }
    return kept;
  }

  Future<void> _write(LoginItem item) async {
    final plain = item.content.toJsonBytes();
    try {
      final blob = _session.records.encrypt(
        recordId: item.id,
        type: recordType,
        plainText: plain,
      );
      await _store.putRecord(
        StoredRecord(
          id: item.id,
          type: recordType,
          blob: blob,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        ),
      );
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
  }

  static LoginItem? _decrypt(RecordCipher cipher, StoredRecord record) {
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
      return LoginItem(
        id: record.id,
        content: LoginContent.fromJsonBytes(plain),
        createdAt: record.createdAt,
        updatedAt: record.updatedAt,
      );
    } on InvalidLoginContentException {
      return null;
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
  }
}

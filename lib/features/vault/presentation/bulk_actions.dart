import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/application/records_controller.dart';
import 'package:keykey/features/vault/application/vault_entries.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/note_content.dart';

/// Listede seçilen kayıtlara toplu işlem.
///
/// Kayıtlar tek tek, sırayla yazılır (her biri kendi şifreli satırı). Biri
/// hata verirse ötekiler sürer ve başarısızların sayısı döner; kasa
/// kilitlenirse işlem durur. Denetleyiciler baştan okunur, böylece geri al
/// bildirimi ekran kapandıktan sonra da çalışır.
final class BulkVault {
  new(WidgetRef ref)
    : _logins = ref.read(loginsControllerProvider.notifier),
      _cards = ref.read(cardsControllerProvider.notifier),
      _notes = ref.read(notesControllerProvider.notifier);

  final LoginsController _logins;
  final RecordsController<CardContent> _cards;
  final RecordsController<NoteContent> _notes;

  Future<int> moveToTrash(List<VaultEntry> entries, DateTime now) => _each(
    entries,
    (entry) => switch (entry) {
      LoginEntry(:final item) => _logins.moveToTrash(item, now),
      CardEntry(:final item) => _cards.moveToTrash(item, now),
      NoteEntry(:final item) => _notes.moveToTrash(item, now),
    },
  );

  /// Geri al: kayıtların en son halini denetleyicide bulup çöpten çıkarır.
  Future<int> restore(List<VaultEntry> entries) => _each(
    entries,
    (entry) => switch (entry) {
      LoginEntry() => _logins.restoreById(entry.id),
      CardEntry() => _cards.restoreById(entry.id),
      NoteEntry() => _notes.restoreById(entry.id),
    },
  );

  /// `null` klasörden çıkarır.
  Future<int> moveToFolder(List<VaultEntry> entries, String? folder) => _each(
    entries,
    (entry) => switch (entry) {
      LoginEntry(:final item) => _logins.moveToFolder(item, folder),
      CardEntry(:final item) => _cards.moveToFolder(item, folder),
      NoteEntry(:final item) => _notes.moveToFolder(item, folder),
    },
  );

  static Future<int> _each(
    List<VaultEntry> entries,
    Future<void> Function(VaultEntry) action,
  ) async {
    var failed = 0;
    for (final entry in entries) {
      try {
        await action(entry);
      } on VaultLockedException {
        rethrow;
      } on Exception {
        failed++;
      }
    }
    return failed;
  }
}

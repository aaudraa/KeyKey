import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/features/vault/application/login_search.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/application/records_controller.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:keykey/features/vault/data/vault_record_repository.dart';

/// Kasa listesindeki kayıt türleri.
enum VaultKind { login, card, note }

/// Kasa listesinde bir satır: parola, kart ya da not.
sealed class VaultEntry {
  const new();

  Uint8List get id;
  VaultKind get kind;
  String get name;
  bool get favorite;
  String? get folder;
  bool get isTrashed;
  DateTime get updatedAt;
}

final class LoginEntry extends VaultEntry {
  const new(this.item);

  final LoginItem item;

  @override
  Uint8List get id => item.id;
  @override
  VaultKind get kind => VaultKind.login;
  @override
  String get name => item.content.name;
  @override
  bool get favorite => item.content.favorite;
  @override
  String? get folder => item.content.folder;
  @override
  bool get isTrashed => item.content.isTrashed;
  @override
  DateTime get updatedAt => item.updatedAt;
}

final class CardEntry extends VaultEntry {
  const new(this.item);

  final CardItem item;

  @override
  Uint8List get id => item.id;
  @override
  VaultKind get kind => VaultKind.card;
  @override
  String get name => item.content.name;
  @override
  bool get favorite => item.content.favorite;
  @override
  String? get folder => item.content.folder;
  @override
  bool get isTrashed => item.content.isTrashed;
  @override
  DateTime get updatedAt => item.updatedAt;
}

final class NoteEntry extends VaultEntry {
  const new(this.item);

  final NoteItem item;

  @override
  Uint8List get id => item.id;
  @override
  VaultKind get kind => VaultKind.note;
  @override
  String get name => item.content.name;
  @override
  bool get favorite => item.content.favorite;
  @override
  String? get folder => item.content.folder;
  @override
  bool get isTrashed => item.content.isTrashed;
  @override
  DateTime get updatedAt => item.updatedAt;
}

/// Aramanın baktığı alanlar. Sır taşıyan alanlara (parola, kart numarası,
/// güvenlik kodu, not metni) bakılmaz.
String _searchText(VaultEntry entry) {
  final fields = switch (entry) {
    LoginEntry(:final item) => [
      item.content.name,
      item.content.username,
      ...item.content.urls,
    ],
    CardEntry(:final item) => [
      item.content.name,
      item.content.cardholder,
      ?item.content.cardBrand?.label,
    ],
    NoteEntry(:final item) => [item.content.name],
  };
  return foldForSearch([...fields, ?entry.folder].join('\n'));
}

/// Arama için önceden hazırlanmış bir satır.
final class IndexedEntry {
  new(this.entry) : searchText = _searchText(entry);

  final VaultEntry entry;
  final String searchText;
}

/// Çöp kutusu dışındaki satırları süzer ve sıralar.
List<VaultEntry> filterEntries(List<IndexedEntry> entries, LoginFilter filter) {
  final words = foldForSearch(filter.query)
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();

  final matches = <VaultEntry>[];
  for (final indexed in entries) {
    final entry = indexed.entry;
    if (entry.isTrashed) continue;
    if (filter.kind != null && entry.kind != filter.kind) continue;
    if (filter.favoritesOnly && !entry.favorite) continue;
    if (filter.folder != null && entry.folder != filter.folder) continue;
    if (words.every(indexed.searchText.contains)) matches.add(entry);
  }
  return sortEntries(matches, filter.sort);
}

List<VaultEntry> sortEntries(List<VaultEntry> entries, LoginSort sort) {
  final sorted = [...entries];
  switch (sort) {
    case LoginSort.name:
      final keys = {
        for (final entry in sorted) entry: foldForSearch(entry.name),
      };
      sorted.sort((a, b) => keys[a]!.compareTo(keys[b]!));
    case LoginSort.recentlyUpdated:
      sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
  return sorted;
}

/// Çöp kutusu dışındaki satırlarda kullanılan klasörler, sıralı.
List<String> foldersOfEntries(Iterable<VaultEntry> entries) {
  return {
    for (final entry in entries)
      if (!entry.isTrashed && entry.folder != null) entry.folder!,
  }.toList()..sort((a, b) => foldForSearch(a).compareTo(foldForSearch(b)));
}

/// Kasa listesinin durumu: üç türden biri yükleniyorsa liste de yükleniyor.
sealed class VaultEntriesState {
  const new();
}

final class VaultEntriesLoading extends VaultEntriesState {
  const new();
}

final class VaultEntriesLoaded extends VaultEntriesState {
  const new({required this.indexed, required this.unreadableCount});

  final List<IndexedEntry> indexed;

  /// Üç türün okunamayan kayıtlarının toplamı.
  final int unreadableCount;

  Iterable<VaultEntry> get entries => indexed.map((item) => item.entry);

  /// Çöp kutusu dışında en az bir kaydı olan türler.
  Set<VaultKind> get activeKinds => {
    for (final entry in entries)
      if (!entry.isTrashed) entry.kind,
  };

  List<VaultEntry> get trashed =>
      entries.where((entry) => entry.isTrashed).toList(growable: false);
}

/// Parola, kart ve not denetleyicilerini tek listede birleştirir.
final vaultEntriesProvider = Provider<VaultEntriesState>((ref) {
  final logins = ref.watch(loginsControllerProvider);
  final cards = ref.watch(cardsControllerProvider);
  final notes = ref.watch(notesControllerProvider);
  if (logins is! LoginsLoaded ||
      cards is! RecordsLoaded<CardContent> ||
      notes is! RecordsLoaded<NoteContent>) {
    return const VaultEntriesLoading();
  }
  return VaultEntriesLoaded(
    indexed: [
      for (final login in logins.indexed) IndexedEntry(LoginEntry(login.item)),
      for (final item in cards.items) IndexedEntry(CardEntry(item)),
      for (final item in notes.items) IndexedEntry(NoteEntry(item)),
    ],
    unreadableCount:
        logins.unreadableCount + cards.unreadableCount + notes.unreadableCount,
  );
});

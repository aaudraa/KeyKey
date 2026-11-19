import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:keykey/features/vault/data/record_content.dart';
import 'package:keykey/features/vault/data/vault_record_repository.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';

/// Çözülmüş kart ya da not kayıtlarının durumu.
sealed class RecordsState<C> {
  const new();
}

/// Kasa kilitli veya kayıtlar henüz çözülmedi. Bellekte kayıt yok.
final class RecordsLoading<C> extends RecordsState<C> {
  const new();
}

final class RecordsLoaded<C extends VaultItemContent<C>>
    extends RecordsState<C> {
  const new({required this.items, required this.unreadableCount});

  final List<VaultRecord<C>> items;
  final int unreadableCount;

  List<VaultRecord<C>> get trashed =>
      items.where((item) => item.content.isTrashed).toList(growable: false);
}

/// Açık oturum için kart deposunu kurar. Testler ve `main` doldurur.
final cardRepositoryFactoryProvider =
    Provider<VaultRecordRepository<CardContent> Function(VaultSession)>(
      (ref) => throw UnimplementedError('Kart deposu sağlanmadı.'),
    );

/// Açık oturum için not deposunu kurar. Testler ve `main` doldurur.
final noteRepositoryFactoryProvider =
    Provider<VaultRecordRepository<NoteContent> Function(VaultSession)>(
      (ref) => throw UnimplementedError('Not deposu sağlanmadı.'),
    );

final cardsControllerProvider =
    NotifierProvider<RecordsController<CardContent>, RecordsState<CardContent>>(
      () => RecordsController(cardRepositoryFactoryProvider),
    );

final notesControllerProvider =
    NotifierProvider<RecordsController<NoteContent>, RecordsState<NoteContent>>(
      () => RecordsController(noteRepositoryFactoryProvider),
    );

/// [idHex] kimlikli kaydı bulur; yoksa ya da yükleniyorsa `null`.
VaultRecord<C>? findRecord<C extends VaultItemContent<C>>(
  RecordsState<C> state,
  String idHex,
) {
  if (state is! RecordsLoaded<C>) return null;
  for (final item in state.items) {
    if (loginIdHex(item.id) == idHex) return item;
  }
  return null;
}

/// Çözülmüş kart ya da not kayıtlarını tutar. Kasa kilitlenince hepsini
/// bırakır. Kurallar parola denetleyicisiyle aynı.
class RecordsController<C extends VaultItemContent<C>>
    extends Notifier<RecordsState<C>> {
  new(this._factory);

  final Provider<VaultRecordRepository<C> Function(VaultSession)> _factory;

  VaultRecordRepository<C>? _repository;

  /// Her yeniden kurulumda artar. Kilitten önce başlamış bir yükleme sonradan
  /// biterse sonucu çöpe gider, kasa kilitliyken kayıtlar geri gelmez.
  int _generation = 0;

  @override
  RecordsState<C> build() {
    _generation++;
    final vault = ref.read(vaultControllerProvider.notifier)
      ..addLockListener(_wipe);
    ref.onDispose(() {
      vault.removeLockListener(_wipe);
      _generation++;
    });

    final status = ref.watch(vaultControllerProvider);
    if (status is! VaultOpen) {
      _repository = null;
      return RecordsLoading<C>();
    }
    final repository = ref.read(_factory)(status.session);
    _repository = repository;
    unawaited(_load(repository, _generation));
    return RecordsLoading<C>();
  }

  /// Kilit anında çözülmüş kayıtları bırakır, sonraki kareyi beklemez.
  void _wipe() {
    _generation++;
    _repository = null;
    state = RecordsLoading<C>();
  }

  Future<void> _load(
    VaultRecordRepository<C> repository,
    int generation,
  ) async {
    final LoadedRecords<C> loaded;
    final List<VaultRecord<C>> kept;
    try {
      loaded = await repository.loadAll();
      kept = await repository.purgeExpiredTrash(loaded.items);
    } on VaultLockedException {
      if (generation == _generation) rethrow;
      return;
    }
    if (generation != _generation) return;
    state = RecordsLoaded(items: kept, unreadableCount: loaded.unreadableCount);
  }

  VaultRecordRepository<C> get _openRepository {
    final repository = _repository;
    if (repository == null) throw const VaultLockedException();
    return repository;
  }

  Future<VaultRecord<C>> add(C content) async {
    final item = await _openRepository.add(content);
    _replaceItems((items) => [...items, item]);
    return item;
  }

  /// Sırayla ekler. Yarıda kilitlenirse o ana kadar yazılanlar kalır.
  Future<List<VaultRecord<C>>> addAll(List<C> contents) async {
    final repository = _openRepository;
    final added = <VaultRecord<C>>[];
    try {
      for (final content in contents) {
        added.add(await repository.add(content));
      }
    } finally {
      _replaceItems((items) => [...items, ...added]);
    }
    return added;
  }

  Future<VaultRecord<C>> update(VaultRecord<C> item, C content) async {
    final updated = await _openRepository.update(item, content);
    _swap(updated);
    return updated;
  }

  Future<void> setFavorite(
    VaultRecord<C> item, {
    required bool favorite,
  }) async {
    _swap(
      await _openRepository.update(
        item,
        item.content.withFavorite(favorite: favorite),
      ),
    );
  }

  /// Çöp kutusuna taşır.
  Future<void> moveToTrash(VaultRecord<C> item, DateTime now) async {
    _swap(await _openRepository.update(item, item.content.withTrashedAt(now)));
  }

  Future<void> restore(VaultRecord<C> item) async {
    _swap(await _openRepository.update(item, item.content.withTrashedAt(null)));
  }

  /// Geri al düğmesi için: kaydın en son halini kendi durumunda bulur.
  Future<void> restoreById(Uint8List id) async {
    final current = state;
    if (current is! RecordsLoaded<C>) return;
    final idHex = loginIdHex(id);
    for (final item in current.items) {
      if (loginIdHex(item.id) == idHex && item.content.isTrashed) {
        await restore(item);
        return;
      }
    }
  }

  Future<void> deletePermanently(VaultRecord<C> item) async {
    await _openRepository.deletePermanently(item);
    final idHex = loginIdHex(item.id);
    _replaceItems(
      (items) => items.where((other) => loginIdHex(other.id) != idHex).toList(),
    );
  }

  void _swap(VaultRecord<C> updated) {
    final idHex = loginIdHex(updated.id);
    _replaceItems(
      (items) => [
        for (final item in items)
          if (loginIdHex(item.id) == idHex) updated else item,
      ],
    );
  }

  void _replaceItems(
    List<VaultRecord<C>> Function(List<VaultRecord<C>>) change,
  ) {
    final current = state;
    if (current is! RecordsLoaded<C>) return;
    state = RecordsLoaded(
      items: change(current.items.toList()),
      unreadableCount: current.unreadableCount,
    );
  }
}

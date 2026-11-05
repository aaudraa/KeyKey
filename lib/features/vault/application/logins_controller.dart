import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/application/login_search.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

/// Çözülmüş kayıtların durumu.
sealed class LoginsState {
  const new();

  static const empty = LoginsLoading();
}

/// Kasa kilitli veya kayıtlar henüz çözülmedi. Bellekte kayıt yok.
final class LoginsLoading extends LoginsState {
  const new();
}

final class LoginsLoaded extends LoginsState {
  new({required List<LoginItem> items, required this.unreadableCount})
    : indexed = items.map(IndexedLogin.new).toList(growable: false);

  final List<IndexedLogin> indexed;
  final int unreadableCount;

  Iterable<LoginItem> get items => indexed.map((login) => login.item);

  List<LoginItem> get trashed =>
      items.where((item) => item.content.isTrashed).toList(growable: false);
}

/// Açık oturum için depoyu kurar. Testler ve `main` doldurur.
final loginRepositoryFactoryProvider =
    Provider<LoginRepository Function(VaultSession)>(
      (ref) => throw UnimplementedError('Kayıt deposu sağlanmadı.'),
    );

final loginsControllerProvider =
    NotifierProvider<LoginsController, LoginsState>(LoginsController.new);

/// Çözülmüş kayıtları tutar. Kasa kilitlenince hepsini bırakır.
class LoginsController extends Notifier<LoginsState> {
  LoginRepository? _repository;

  /// Her yeniden kurulumda artar. Kilitten önce başlamış bir yükleme sonradan
  /// biterse sonucu çöpe gider, kasa kilitliyken kayıtlar geri gelmez.
  int _generation = 0;

  @override
  LoginsState build() {
    _generation++;
    final vault = ref.read(vaultControllerProvider.notifier)
      ..addLockListener(_wipe);
    ref.onDispose(() => vault.removeLockListener(_wipe));

    final status = ref.watch(vaultControllerProvider);
    if (status is! VaultOpen) {
      _repository = null;
      return const LoginsLoading();
    }
    final repository = ref.read(loginRepositoryFactoryProvider)(status.session);
    _repository = repository;
    unawaited(_load(repository, _generation));
    return const LoginsLoading();
  }

  /// Kilit anında çözülmüş kayıtları bırakır, sonraki kareyi beklemez.
  void _wipe() {
    _generation++;
    _repository = null;
    state = const LoginsLoading();
  }

  Future<void> _load(LoginRepository repository, int generation) async {
    final LoadedLogins loaded;
    final List<LoginItem> kept;
    try {
      loaded = await repository.loadAll();
      kept = await repository.purgeExpiredTrash(loaded.items);
    } on VaultLockedException {
      // Yükleme sürerken kilitlendi, anahtarlar artık yok.
      if (generation == _generation) rethrow;
      return;
    }
    if (generation != _generation) return;
    state = LoginsLoaded(items: kept, unreadableCount: loaded.unreadableCount);
  }

  LoginRepository get _openRepository {
    final repository = _repository;
    if (repository == null) throw const VaultLockedException();
    return repository;
  }

  Future<LoginItem> add(LoginContent content) async {
    final item = await _openRepository.add(content);
    _replaceItems((items) => [...items, item]);
    return item;
  }

  /// Parola değiştiyse eskisi geçmişe eklenir.
  Future<LoginItem> update(LoginItem item, LoginContent edited) async {
    final updated = await _openRepository.update(item, edited);
    _swap(updated);
    return updated;
  }

  Future<void> setFavorite(LoginItem item, {required bool favorite}) async {
    _swap(
      await _openRepository.updateMetadata(
        item,
        item.content.copyWith(favorite: favorite),
      ),
    );
  }

  /// Çöp kutusuna taşır.
  Future<void> moveToTrash(LoginItem item, DateTime now) async {
    _swap(
      await _openRepository.updateMetadata(
        item,
        item.content.copyWith(trashedAt: now),
      ),
    );
  }

  Future<void> restore(LoginItem item) async {
    _swap(
      await _openRepository.updateMetadata(
        item,
        item.content.copyWith(trashedAt: null),
      ),
    );
  }

  /// Geri al düğmesi için: kaydın en son halini kendi durumunda bulur.
  Future<void> restoreById(Uint8List id) async {
    final current = state;
    if (current is! LoginsLoaded) return;
    for (final item in current.items) {
      if (_sameIds(item.id, id) && item.content.isTrashed) {
        await restore(item);
        return;
      }
    }
  }

  Future<void> deletePermanently(LoginItem item) async {
    await _openRepository.deletePermanently(item);
    _replaceItems(
      (items) => items.where((other) => !_sameId(other, item)).toList(),
    );
  }

  void _swap(LoginItem updated) {
    _replaceItems(
      (items) => [
        for (final item in items)
          if (_sameId(item, updated)) updated else item,
      ],
    );
  }

  void _replaceItems(List<LoginItem> Function(List<LoginItem>) change) {
    final current = state;
    if (current is! LoginsLoaded) return;
    state = LoginsLoaded(
      items: change(current.items.toList()),
      unreadableCount: current.unreadableCount,
    );
  }

  static bool _sameId(LoginItem a, LoginItem b) => _sameIds(a.id, b.id);

  static bool _sameIds(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

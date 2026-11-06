import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/application/otp_generator.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/data/otp_repository.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';

/// İstenen 2FA kaydı artık yok, örneğin bu sırada kalıcı olarak silindi.
final class OtpNotFoundException implements Exception {
  const new();

  @override
  String toString() => 'OtpNotFoundException: 2FA kaydı bulunamadı.';
}

/// Çözülmüş 2FA kayıtlarının durumu.
sealed class OtpsState {
  const new();
}

/// Kasa kilitli veya kayıtlar henüz çözülmedi. Bellekte kayıt yok.
final class OtpsLoading extends OtpsState {
  const new();
}

final class OtpsLoaded extends OtpsState {
  const new({required this.items, required this.unreadableCount});

  final List<OtpItem> items;
  final int unreadableCount;

  List<OtpItem> get active =>
      items.where((item) => !item.content.isTrashed).toList(growable: false);

  List<OtpItem> get trashed =>
      items.where((item) => item.content.isTrashed).toList(growable: false);

  OtpItem? byId(Uint8List id) {
    for (final item in items) {
      if (listEquals(item.id, id)) return item;
    }
    return null;
  }
}

/// Açık oturum için depoyu kurar. Testler ve `main` doldurur.
final otpRepositoryFactoryProvider =
    Provider<OtpRepository Function(VaultSession)>(
      (ref) => throw UnimplementedError('2FA deposu sağlanmadı.'),
    );

final otpsControllerProvider = NotifierProvider<OtpsController, OtpsState>(
  OtpsController.new,
);

/// Çözülmüş 2FA kayıtlarını tutar. Kasa kilitlenince hepsini bırakır.
class OtpsController extends Notifier<OtpsState> {
  OtpRepository? _repository;

  /// Her yeniden kurulumda artar. Kilitten önce başlamış bir yükleme sonradan
  /// biterse sonucu çöpe gider, kasa kilitliyken kayıtlar geri gelmez.
  int _generation = 0;

  /// Değişiklikler sırayla yazılır. Yoksa iki hızlı dokunuş aynı HOTP
  /// sayacını okuyup aynı kodu iki kez gösterebilir, ya da eski bir kopyayla
  /// yapılan düzenleme ilerlemiş sayacı geri yazabilir.
  Future<void> _queue = Future.value();

  @override
  OtpsState build() {
    _generation++;
    final vault = ref.read(vaultControllerProvider.notifier)
      ..addLockListener(_wipe);
    ref.onDispose(() => vault.removeLockListener(_wipe));

    final status = ref.watch(vaultControllerProvider);
    if (status is! VaultOpen) {
      _repository = null;
      return const OtpsLoading();
    }
    final repository = ref.read(otpRepositoryFactoryProvider)(status.session);
    _repository = repository;
    unawaited(_load(repository, _generation));
    return const OtpsLoading();
  }

  /// Kilit anında çözülmüş kayıtları bırakır, sonraki kareyi beklemez.
  void _wipe() {
    _generation++;
    _repository = null;
    state = const OtpsLoading();
  }

  Future<void> _load(OtpRepository repository, int generation) async {
    final LoadedOtps loaded;
    final List<OtpItem> kept;
    try {
      loaded = await repository.loadAll();
      kept = await repository.purgeExpiredTrash(loaded.items);
    } on VaultLockedException {
      // Yükleme sürerken kilitlendi, anahtarlar artık yok.
      if (generation == _generation) rethrow;
      return;
    }
    if (generation != _generation) return;
    state = OtpsLoaded(items: kept, unreadableCount: loaded.unreadableCount);
  }

  OtpRepository get _openRepository {
    final repository = _repository;
    if (repository == null) throw const VaultLockedException();
    return repository;
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final run = _queue.then((_) => action());
    _queue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<OtpItem> add(OtpContent content) => _serial(() async {
    final item = await _openRepository.add(content);
    _replaceItems((items) => [...items, item]);
    return item;
  });

  /// İçe aktarılan hesapları sırayla ekler. Yarıda kilitlenirse o ana kadar
  /// yazılanlar kalır.
  Future<int> addAll(List<OtpContent> contents) => _serial(() async {
    final repository = _openRepository;
    final added = <OtpItem>[];
    try {
      for (final content in contents) {
        added.add(await repository.add(content));
      }
    } finally {
      _replaceItems((items) => [...items, ...added]);
    }
    return added.length;
  });

  /// [content], [item]'dan türetilmiş yeni içeriktir.
  ///
  /// [item] eskimiş olabilir. Kullanıcı HOTP sayacını değiştirmediyse sayaç
  /// bellekteki en son kayıttan alınır, böylece ilerlemiş sayaç geri gitmez.
  Future<OtpItem> update(OtpItem item, OtpContent content) => _serial(() async {
    final repository = _openRepository;
    final latest = _latest(item);
    final staleCounter = item.content.parameters.counter;
    final latestCounter = latest.content.parameters.counter;
    var toWrite = content;
    if (content.parameters.kind == OtpKind.hotp &&
        content.parameters.counter == staleCounter &&
        latestCounter != null &&
        latestCounter != staleCounter) {
      toWrite = content.copyWith(
        parameters: content.parameters.withCounter(latestCounter),
      );
    }
    final updated = await repository.update(latest, toWrite);
    _swap(updated);
    return updated;
  });

  /// Yalnızca düzenleme bilgisini değiştirir, en son kayıt üzerinden.
  Future<void> _updateLatest(
    OtpItem item,
    OtpContent Function(OtpContent) change,
  ) => _serial(() async {
    final repository = _openRepository;
    final latest = _latest(item);
    _swap(await repository.update(latest, change(latest.content)));
  });

  Future<void> setFavorite(OtpItem item, {required bool favorite}) =>
      _updateLatest(item, (content) => content.copyWith(favorite: favorite));

  /// Çöp kutusuna taşır.
  Future<void> moveToTrash(OtpItem item, DateTime now) =>
      _updateLatest(item, (content) => content.copyWith(trashedAt: now));

  Future<void> restore(OtpItem item) =>
      _updateLatest(item, (content) => content.copyWith(trashedAt: null));

  /// Geri al düğmesi için: kaydın en son halini kendi durumunda bulur.
  Future<void> restoreById(Uint8List id) async {
    final current = state;
    if (current is! OtpsLoaded) return;
    final item = current.byId(id);
    if (item != null && item.content.isTrashed) await restore(item);
  }

  Future<void> deletePermanently(OtpItem item) => _serial(() async {
    await _openRepository.deletePermanently(item);
    _replaceItems(
      (items) =>
          items.where((other) => !listEquals(other.id, item.id)).toList(),
    );
  });

  /// HOTP için yeni kod üretir.
  ///
  /// Sayaç önce artırılıp diske yazılır, kod ondan sonra döner. Böylece
  /// uygulama yarıda kapansa da aynı kod iki kez görünmez. Kod, kayıttaki
  /// eski sayaç değeriyle hesaplanır.
  Future<String> nextHotpCode(OtpItem item) => _serial(() async {
    final repository = _openRepository;
    final latest = _latest(item);
    final used = latest.content.parameters;
    final updated = await repository.update(
      latest,
      latest.content.copyWith(parameters: used.withNextCounter()),
    );
    _swap(updated);
    return OtpGenerator.hotp(
      secret: used.secret,
      counter: used.counter!,
      algorithm: used.algorithm,
      digits: used.digits,
    );
  });

  /// Durumdaki en son kopya. Kayıt bu arada silindiyse [OtpNotFoundException].
  OtpItem _latest(OtpItem item) {
    final current = state;
    final latest = current is OtpsLoaded ? current.byId(item.id) : null;
    if (latest == null) throw const OtpNotFoundException();
    return latest;
  }

  void _swap(OtpItem updated) {
    _replaceItems(
      (items) => [
        for (final item in items)
          if (listEquals(item.id, updated.id)) updated else item,
      ],
    );
  }

  void _replaceItems(List<OtpItem> Function(List<OtpItem>) change) {
    final current = state;
    if (current is! OtpsLoaded) return;
    state = OtpsLoaded(
      items: List.unmodifiable(change(current.items.toList())),
      unreadableCount: current.unreadableCount,
    );
  }
}

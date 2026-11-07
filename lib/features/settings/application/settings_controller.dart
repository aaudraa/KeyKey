import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';

/// Açık oturum için depoyu kurar. Testler ve `main` doldurur.
final settingsRepositoryFactoryProvider =
    Provider<SettingsRepository Function(VaultSession)>(
      (ref) => throw UnimplementedError('Ayar deposu sağlanmadı.'),
    );

/// Kasadaki ayarlar. Kasa kilitliyken veya ayarlar okunurken `null`.
final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings?>(SettingsController.new);

class SettingsController extends Notifier<AppSettings?> {
  SettingsRepository? _repository;
  int _generation = 0;

  @override
  AppSettings? build() {
    _generation++;
    final vault = ref.read(vaultControllerProvider.notifier)
      ..addLockListener(_wipe);
    ref.onDispose(() => vault.removeLockListener(_wipe));

    final status = ref.watch(vaultControllerProvider);
    if (status is! VaultOpen) {
      _repository = null;
      return null;
    }
    final repository = ref.read(settingsRepositoryFactoryProvider)(
      status.session,
    );
    _repository = repository;
    unawaited(_load(repository, _generation));
    return null;
  }

  void _wipe() {
    _generation++;
    _repository = null;
    state = null;
  }

  Future<void> _load(SettingsRepository repository, int generation) async {
    final AppSettings settings;
    try {
      settings = await repository.load();
    } on VaultLockedException {
      if (generation == _generation) rethrow;
      return;
    }
    if (generation == _generation) state = settings;
  }

  Future<void> setOtpRequireAuth({required bool value}) =>
      _update((current) => current.copyWith(otpRequireAuth: value));

  Future<void> setAutofillCopyOtp({required bool value}) =>
      _update((current) => current.copyWith(autofillCopyOtp: value));

  Future<void> _update(AppSettings Function(AppSettings) change) async {
    final repository = _repository;
    final current = state;
    if (repository == null || current == null) {
      throw const VaultLockedException();
    }
    final updated = change(current);
    await repository.save(updated);
    if (identical(_repository, repository)) state = updated;
  }
}

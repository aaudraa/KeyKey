import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/generator/application/generator_preferences.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/application/login_search.dart';

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
  Future<void> _queue = Future.value();

  @override
  AppSettings? build() {
    _generation++;
    final vault = ref.read(vaultControllerProvider.notifier)
      ..addLockListener(_wipe);
    ref.onDispose(() {
      vault.removeLockListener(_wipe);
      // Süren yükleme atılmış denetleyiciye yazmasın; uygulama kapanırken
      // oturum kilit dinleyicisi çağrılmadan kapanabilir.
      _generation++;
    });

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

  /// Başarılı bir yedeğin zamanını yazar.
  Future<void> recordBackup(DateTime at) =>
      _update((current) => current.copyWith(lastBackupAt: at));

  /// Yedek hatırlatıcısını [until] anına kadar susturur.
  Future<void> snoozeBackupReminder(DateTime until) =>
      _update((current) => current.copyWith(backupReminderSnoozedUntil: until));

  Future<void> setVaultSort(LoginSort sort) =>
      _update((current) => current.copyWith(vaultSort: sort));

  /// Üreticinin son kullanılan seçenekleri; üretilen parola değil.
  Future<void> setGenerator(GeneratorPreferences generator) =>
      _update((current) => current.copyWith(generator: generator));

  /// Otomatik yedeğin klasörü; `null` kapatır.
  Future<void> setAutoBackupFolder(AutoBackupFolder? folder) =>
      _update((current) => current.withAutoBackupFolder(folder));

  /// Değişiklikler sırayla yazılır ve her biri sırası geldiğindeki güncel
  /// ayarlara uygulanır; arka planda yazılan son yedek zamanı, kullanıcının
  /// o sırada yaptığı bir değişikliği ezmez.
  Future<void> _update(AppSettings Function(AppSettings) change) {
    final repository = _repository;
    if (repository == null || state == null) {
      return Future.error(const VaultLockedException());
    }
    final run = _queue.then((_) async {
      final current = state;
      if (!identical(_repository, repository) || current == null) {
        throw const VaultLockedException();
      }
      final updated = change(current);
      await repository.save(updated);
      if (identical(_repository, repository)) state = updated;
    });
    _queue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }
}

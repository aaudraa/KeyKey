import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/platform/backup_folders.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/backup/application/auto_backup_files.dart';
import 'package:keykey/features/backup/application/backup_service.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Son otomatik yedeğin neden yazılamadığı.
enum AutoBackupProblem {
  /// Bu cihazda klasör için izin yok: klasör başka telefondan geldi ya da
  /// izin kaldırıldı.
  noAccess,

  /// Dosya yazılamadı ya da geri okununca tutmadı.
  writeFailed,
}

/// Otomatik yedeğin bu oturumdaki durumu. Kasa kilitlenince sıfırlanır.
final class AutoBackupStatus {
  const new({this.problem});

  final AutoBackupProblem? problem;
}

/// Son değişiklikten sonra yedeğin yazılması için beklenen süre.
final autoBackupDelayProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 5),
);

/// Dosya adının öneki; uygulamanın da kullandığı dil çözümüyle seçilir.
final autoBackupPrefixProvider = Provider<String>((ref) {
  final locale = basicLocaleListResolution(
    WidgetsBinding.instance.platformDispatcher.locales,
    AppLocalizations.supportedLocales,
  );
  return lookupAppLocalizations(locale).autoBackupFilePrefix;
});

/// Bu kurulumun cihaz kimliği (`auto_backup_device` dosyası); `main`
/// doldurur, testler kendi değerini verir.
final autoBackupDeviceProvider = Provider<String>(
  (ref) => throw UnimplementedError('Cihaz kimliği sağlanmadı.'),
);

final autoBackupControllerProvider =
    NotifierProvider<AutoBackupController, AutoBackupStatus>(
      AutoBackupController.new,
    );

/// Kasa açıkken, kayıtlar değişince seçilen klasöre yedek yazar. Tasarım:
/// `resources/docs/otomatik-yedek.md`.
///
/// Yalnızca ana uygulama dinler; otomatik doldurmanın ayrı motorunda çalışmaz.
/// Aynı anda tek yedek yazılır.
class AutoBackupController extends Notifier<AutoBackupStatus> {
  Timer? _timer;
  Future<void> _tail = Future.value();

  /// Kasa her kilitlendiğinde artar; kilitten önce başlamış işin sonucu
  /// durumu değiştirmez.
  int _generation = 0;

  /// Son yazılan dosyanın adındaki zaman. Sonraki ad en az bir saniye
  /// sonrası olur; sağlayıcı aynı adı "… (1)" diye değiştirip budanamayan bir
  /// kopya bırakmasın.
  DateTime? _lastStamp;

  /// Üst bilgi değişti (kurtarma anahtarıyla yeni parola ya da kasa kilitliyken
  /// istenen yedek); ayarlar yüklenince değişiklik ölçütüne bakmadan yazılır,
  /// en yeni yedek yeni üst bilgiyle açılsın.
  bool _forceOnOpen = false;

  @override
  AutoBackupStatus build() {
    final vault = ref.read(vaultControllerProvider.notifier)
      ..addLockListener(_onLock);
    ref
      ..onDispose(() {
        vault.removeLockListener(_onLock);
        _timer?.cancel();
        _generation++;
      })
      // Ayarlar kasa açılınca yüklenir: önceki oturumdan kalan ve otomatik
      // doldurmanın kaydettiği değişiklikler burada yakalanır.
      ..listen(vaultControllerProvider, (previous, next) {
        if (previous is VaultRecovering && next is VaultOpen) {
          _forceOnOpen = true;
        }
      })
      ..listen(settingsControllerProvider, (previous, next) {
        if (previous == null && next != null) {
          unawaited(_checkAccess(next.autoBackupFolder));
          if (_forceOnOpen) {
            _forceOnOpen = false;
            unawaited(backUpNow());
          } else {
            _schedule();
          }
        }
      })
      ..listen(loginsControllerProvider, (_, _) => _schedule())
      ..listen(otpsControllerProvider, (_, _) => _schedule());
    return const AutoBackupStatus();
  }

  /// Değişiklik ölçütüne bakmadan şimdi yazar. Otomatik yedek kapalıysa veya
  /// yazılamazsa `false`.
  Future<bool> backUpNow() => _enqueue(force: true);

  /// Ana parola ya da kurtarma anahtarı değişince: kasa açıksa hemen yazar;
  /// bu sırada kilitlendiyse kasa yeniden açılınca yazar.
  Future<bool> backUpNowOrOnOpen() async {
    if (ref.read(vaultControllerProvider) is VaultOpen) {
      return await backUpNow();
    }
    _forceOnOpen = true;
    return false;
  }

  /// Yeni klasörü kaydeder, öncekinin iznini bırakır ve hemen yedekler.
  /// Kasa kilitliyse `VaultLockedException`.
  Future<bool> useFolder(FolderPicked picked) async {
    final previous = ref.read(settingsControllerProvider)?.autoBackupFolder;
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .setAutoBackupFolder(
            AutoBackupFolder(uri: picked.uri, name: picked.name),
          );
    } on Exception {
      // Klasör kaydedilemedi; seçicinin verdiği izin boşta kalmasın.
      if (previous?.uri != picked.uri) {
        await ref.read(backupFoldersProvider).release(picked.uri);
      }
      rethrow;
    }
    if (previous != null && previous.uri != picked.uri) {
      await ref.read(backupFoldersProvider).release(previous.uri);
    }
    state = const AutoBackupStatus();
    return await backUpNow();
  }

  /// Otomatik yedeği kapatır ve klasörün iznini bırakır. Klasördeki yedekler
  /// silinmez. Kasa kilitliyse `VaultLockedException`.
  Future<void> disable() async {
    final previous = ref.read(settingsControllerProvider)?.autoBackupFolder;
    _timer?.cancel();
    await ref
        .read(settingsControllerProvider.notifier)
        .setAutoBackupFolder(null);
    if (previous != null) {
      await ref.read(backupFoldersProvider).release(previous.uri);
    }
    state = const AutoBackupStatus();
  }

  void _onLock() {
    _generation++;
    _forceOnOpen = false;
    _timer?.cancel();
    _timer = null;
    state = const AutoBackupStatus();
  }

  /// Kasa açılınca klasöre bu cihazda erişilebiliyor mu bakar; başka
  /// telefondan gelen bir klasör ilk değişikliği beklemeden bildirilir.
  Future<void> _checkAccess(AutoBackupFolder? folder) async {
    if (folder == null) return;
    final generation = _generation;
    if (!await ref.read(backupFoldersProvider).hasAccess(folder.uri)) {
      _report(generation, AutoBackupProblem.noAccess);
    }
  }

  void _schedule() {
    _timer?.cancel();
    // Kapalıyken zamanlayıcı da kurulmaz.
    if (ref.read(settingsControllerProvider)?.autoBackupFolder == null) return;
    _timer = Timer(ref.read(autoBackupDelayProvider), () {
      _timer = null;
      unawaited(_enqueue(force: false));
    });
  }

  /// İşleri sıraya koyar; biri bitmeden öteki başlamaz.
  Future<bool> _enqueue({required bool force}) {
    final run = _tail.then((_) => _write(force: force));
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<bool> _write({required bool force}) async {
    final generation = _generation;
    final status = ref.read(vaultControllerProvider);
    final settings = ref.read(settingsControllerProvider);
    final folder = settings?.autoBackupFolder;
    if (status is! VaultOpen || settings == null || folder == null) {
      return false;
    }
    final folders = ref.read(backupFoldersProvider);
    final String name;
    final DateTime now;
    try {
      final backups = ref.read(backupServiceProvider);
      if (!force) {
        final latest = await backups.latestChange();
        final last = settings.lastBackupAt;
        if (latest == null || (last != null && !latest.isAfter(last))) {
          return false;
        }
      }
      if (!await folders.hasAccess(folder.uri)) {
        _report(generation, AutoBackupProblem.noAccess);
        return false;
      }
      now = ref.read(backupClockProvider)();
      final Uint8List bytes;
      try {
        bytes = await backups.create(status.session, now);
      } on VaultLockedException {
        return false;
      }
      name = AutoBackupFiles.nameFor(
        _nextStamp(now),
        prefix: ref.read(autoBackupPrefixProvider),
        device: ref.read(autoBackupDeviceProvider),
      );
      if (!await folders.write(folder.uri, name, bytes)) {
        _report(generation, AutoBackupProblem.writeFailed);
        return false;
      }
    } on Exception {
      // Veritabanı, kodlayıcı ya da köprü hatası: sessiz kalmasın.
      _report(generation, AutoBackupProblem.writeFailed);
      return false;
    }
    // Kasa bu arada kilitlenip yeniden açıldıysa ya da değiştirildiyse bu
    // yedeğin zamanı yeni oturumun ayarlarına yazılmaz.
    if (generation == _generation) {
      try {
        await ref.read(settingsControllerProvider.notifier).recordBackup(now);
      } on VaultLockedException {
        // Dosya yazıldı; kasa kilitlendiği için zaman yazılamadı.
      }
    }
    _report(generation, null);
    try {
      final names = await folders.list(folder.uri);
      if (names != null) {
        final old = AutoBackupFiles.toDelete(
          names,
          device: ref.read(autoBackupDeviceProvider),
        )..remove(name);
        if (old.isNotEmpty) await folders.delete(folder.uri, old);
      }
    } on Exception {
      // Budama bir sonraki yedekte yeniden denenir.
    }
    return true;
  }

  /// [now]'ın saniyeye yuvarlanmış hali; son yazılandan ileride değilse
  /// ondan bir saniye sonrası.
  DateTime _nextStamp(DateTime now) {
    final local = now.toLocal();
    var stamp = DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
    );
    final last = _lastStamp;
    if (last != null && !stamp.isAfter(last)) {
      stamp = last.add(const Duration(seconds: 1));
    }
    return _lastStamp = stamp;
  }

  void _report(int generation, AutoBackupProblem? problem) {
    if (generation != _generation) return;
    state = AutoBackupStatus(problem: problem);
  }
}

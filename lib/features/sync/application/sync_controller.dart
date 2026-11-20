import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/network/sync_transport.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/sync/application/sync_merger.dart';
import 'package:keykey/features/sync/application/sync_service.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/application/records_controller.dart';

/// Senkronun bu oturumdaki durumu. Kasa kilitlenince sıfırlanır.
final class SyncStatus {
  const new({
    this.enabled = false,
    this.running = false,
    this.lastSyncAt,
    this.failure,
    this.otherVault = false,
    this.issues = const [],
    this.devices = const [],
  });

  /// Senkron açık mı (ayar kaydında bilgileri var mı).
  final bool enabled;

  /// Bir eşitleme sürüyor mu.
  final bool running;

  /// Son başarılı eşitleme.
  final DateTime? lastSyncAt;

  /// Son eşitlemenin hatası; başarıda `null`.
  final SyncFailureKind? failure;

  /// Klasörde başka bir kasanın dosyası çıktı; eşitleme bir şey yazmadı.
  final bool otherVault;

  /// Son başarılı eşitlemenin bildirdikleri.
  final List<SyncIssue> issues;
  final List<SyncDevice> devices;

  SyncStatus copyWith({bool? enabled, bool? running}) => SyncStatus(
    enabled: enabled ?? this.enabled,
    running: running ?? this.running,
    lastSyncAt: lastSyncAt,
    failure: failure,
    otherVault: otherVault,
    issues: issues,
    devices: devices,
  );
}

/// Son değişiklikten sonra eşitleme için beklenen süre.
final syncDelayProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 5),
);

/// Uygulama öne gelince, son eşitlemeden bu kadar geçtiyse yeniden eşitlenir.
final syncResumeGapProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 60),
);

/// Eşitlemenin saati; testler sabitler.
final syncClockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

/// `main` doldurur, testler sahtesini verir.
final syncServiceProvider = Provider<SyncService>(
  (ref) => throw UnimplementedError('Senkron servisi sağlanmadı.'),
);

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);

/// Ne zaman eşitleneceğine karar verir. Tasarım: `resources/docs/senkron.md`,
/// "Ne zaman eşitlenir".
///
/// Yalnızca ana uygulamanın kabuğu dinler; otomatik doldurmanın ayrı
/// motorunda çalışmaz. Aynı anda tek eşitleme; sürerken gelen istekler
/// bittikten sonra tek eşitlemede karşılanır.
class SyncController extends Notifier<SyncStatus> {
  Timer? _timer;
  Future<void>? _running;
  Future<void>? _queued;

  /// Kasa her kilitlendiğinde artar; kilitten önce başlamış eşitlemenin
  /// sonucu atılır.
  int _generation = 0;

  /// Değişmeyen dosyalar yeniden indirilmesin; kilitte atılır.
  SyncCache _cache = SyncCache();

  /// Son biten eşitleme denemesi (öne gelme kuralı için).
  DateTime? _lastAttempt;

  /// Bir kez gösterilecek bildirimler: ana parola ya da kurtarma anahtarı
  /// başka telefonda değişti.
  final _notices = <SyncIssue>[];

  @override
  SyncStatus build() {
    final vault = ref.read(vaultControllerProvider.notifier)
      ..addLockListener(_onLock)
      ..addHeaderListener(_onHeaderChanged);
    ref
      ..onDispose(() {
        vault
          ..removeLockListener(_onLock)
          ..removeHeaderListener(_onHeaderChanged);
        _timer?.cancel();
        _generation++;
      })
      // Ayarlar kasa açılınca yüklenir: ilk eşitleme burada.
      ..listen(settingsControllerProvider, (previous, next) {
        final enabled = next?.sync != null;
        if (state.enabled != enabled) state = state.copyWith(enabled: enabled);
        if (previous == null && next != null && enabled) {
          unawaited(_request());
        }
      })
      // Yalnızca yüklenmiş bir listenin değişmesi tetikler; kasa açılırken
      // listelerin ilk yüklenmesi tetiklemez.
      ..listen(loginsControllerProvider, (previous, _) {
        if (previous is LoginsLoaded) onRecordsChanged();
      })
      ..listen(otpsControllerProvider, (previous, _) {
        if (previous is OtpsLoaded) onRecordsChanged();
      })
      ..listen(cardsControllerProvider, (previous, _) {
        if (previous is RecordsLoaded) onRecordsChanged();
      })
      ..listen(notesControllerProvider, (previous, _) {
        if (previous is RecordsLoaded) onRecordsChanged();
      });
    return SyncStatus(
      enabled: ref.read(settingsControllerProvider)?.sync != null,
    );
  }

  bool get _enabled => ref.read(settingsControllerProvider)?.sync != null;

  /// Şimdi eşitler; bitince durumu döndürür. Senkron kapalıysa hemen döner.
  Future<SyncStatus> syncNow() async {
    if (_enabled) await _request();
    return state;
  }

  /// Bir kayıt değişti: peş peşe değişiklikler tek eşitlemede, son
  /// değişiklikten [syncDelayProvider] sonra.
  void onRecordsChanged() {
    _timer?.cancel();
    _timer = null;
    if (!_enabled) return;
    _timer = Timer(ref.read(syncDelayProvider), () {
      _timer = null;
      unawaited(_request());
    });
  }

  /// Uygulama öne geldi: son eşitlemeden [syncResumeGapProvider] geçtiyse
  /// eşitler.
  void onResumed() {
    if (!_enabled || ref.read(vaultControllerProvider) is! VaultOpen) return;
    final last = _lastAttempt;
    final now = ref.read(syncClockProvider)();
    if (last != null &&
        now.difference(last) < ref.read(syncResumeGapProvider)) {
      return;
    }
    unawaited(_request());
  }

  /// Gösterilmemiş ilk bildirimi verir ve listeden çıkarır.
  SyncIssue? consumeNotice() => _notices.isEmpty ? null : _notices.removeAt(0);

  /// Ana parola ya da kurtarma anahtarı değişti: beklemeden eşitlenir.
  void _onHeaderChanged() {
    if (_enabled) unawaited(_request());
  }

  void _onLock() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _cache = SyncCache();
    _lastAttempt = null;
    _notices.clear();
    state = const SyncStatus();
  }

  /// Süren bir eşitleme yoksa başlatır; varsa bittikten sonra bir tane
  /// daha kurar (en çok bir tane bekler).
  Future<void> _request() {
    final queued = _queued;
    if (queued != null) return queued;
    final running = _running;
    if (running == null) return _start();
    final next = running.then((_) {
      _queued = null;
      return _start();
    });
    _queued = next;
    return next;
  }

  Future<void> _start() {
    final run = _run();
    _running = run;
    unawaited(
      run.whenComplete(() {
        if (identical(_running, run)) _running = null;
      }),
    );
    return run;
  }

  /// Bir eşitleme. Hata fırlatmaz; sonucu durumda.
  Future<void> _run() async {
    final generation = _generation;
    final vault = ref.read(vaultControllerProvider);
    final sync = ref.read(settingsControllerProvider)?.sync;
    if (vault is! VaultOpen || sync == null) return;
    state = state.copyWith(running: true);
    final SyncResult result;
    try {
      result = await ref
          .read(syncServiceProvider)
          .sync(vault.session, sync, cache: _cache);
    } on VaultLockedException {
      return;
    } on OtherVaultException {
      _finish(generation, failure: null, otherVault: true);
      return;
    } on SyncTransportException catch (error) {
      _finish(generation, failure: error.kind);
      return;
    } on Object {
      // Veritabanı, kodlayıcı ya da beklenmeyen yanıt: sessiz kalmasın.
      _finish(generation, failure: SyncFailureKind.badResponse);
      return;
    }
    if (generation != _generation) return;
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .recordSync(result.at, result.digest);
    } on VaultLockedException {
      return;
    }
    if (generation != _generation) return;
    if (result.changedLocal) {
      unawaited(ref.read(loginsControllerProvider.notifier).reload());
      ref
        ..invalidate(otpsControllerProvider)
        ..invalidate(cardsControllerProvider)
        ..invalidate(notesControllerProvider);
    }
    _notices.addAll(
      result.issues.where(
        (issue) => issue is PasswordAdopted || issue is RecoveryAdopted,
      ),
    );
    _lastAttempt = ref.read(syncClockProvider)();
    state = SyncStatus(
      enabled: _enabled,
      lastSyncAt: result.at,
      issues: result.issues,
      devices: result.devices,
    );
  }

  void _finish(
    int generation, {
    required SyncFailureKind? failure,
    bool otherVault = false,
  }) {
    if (generation != _generation) return;
    _lastAttempt = ref.read(syncClockProvider)();
    state = SyncStatus(
      enabled: _enabled,
      lastSyncAt: state.lastSyncAt,
      failure: failure,
      otherVault: otherVault,
      issues: state.issues,
      devices: state.devices,
    );
  }
}

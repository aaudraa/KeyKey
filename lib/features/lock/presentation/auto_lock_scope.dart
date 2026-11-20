import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/lock_clock.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';

/// Kasayı arka plana geçince ve kullanılmadığında kilitler.
///
/// Kurallar güvenlik tasarımı belgesinin Otomatik kilit bölümündedir.
/// `inactive` kilitlemez, çünkü parmak izi penceresi ve sistem diyalogları da
/// onu tetikler. Ayarlarda bir bekleme süresi seçiliyse arka plan kilidi o
/// kadar bekler; süre iki saatle ([LockClock]) ölçülür.
class AutoLockScope extends ConsumerStatefulWidget {
  const new({
    required this.child,
    this.idleTimeout = const Duration(minutes: 5),
    super.key,
  });

  final Widget child;
  final Duration idleTimeout;

  /// Dokunma dışındaki kullanımı bildirir, örneğin klavyeyle yazmayı.
  ///
  /// Klavyeden gelen tuşlar uygulamaya dokunma olarak ulaşmaz, bu yüzden
  /// metin kutuları bunu çağırır.
  static void reportActivity(BuildContext context) {
    context.findAncestorStateOfType<_AutoLockScopeState>()?._restart();
  }

  @override
  ConsumerState<AutoLockScope> createState() => _AutoLockScopeState();
}

class _AutoLockScopeState extends ConsumerState<AutoLockScope>
    with WidgetsBindingObserver {
  Timer? _idleTimer;
  Timer? _backgroundTimer;

  /// Son dokunma ya da yazma; dönüşte dokunmama süresi buna göre denetlenir.
  LockInstant? _lastActivity;

  /// Arka plana geçiş anı ve o anki bekleme süresi. Kasa arka planda
  /// kilitlenmeden bekliyorsa dolu.
  ({LockInstant at, Duration delay})? _background;

  LockClock get _clock => ref.read(lockClockProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncTimer(ref.read(vaultControllerProvider));
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _backgroundTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        // KeyKey'in açtığı bir dosya seçicisi sürüyorsa kilit, seçicinin
        // kendi süre sınırına bırakılır.
        if (ref.read(externalActivityGateProvider)) return;
        // Dönerken de paused'dan hidden'a geçilir; bekleme zaten kurulu.
        if (_background != null) return;
        final delay =
            ref.read(settingsControllerProvider)?.backgroundLock.delay ??
            Duration.zero;
        if (delay <= Duration.zero ||
            ref.read(vaultControllerProvider) is! VaultOpen) {
          _lock();
          return;
        }
        _background = (at: _clock.read(), delay: delay);
        _backgroundTimer = Timer(delay, _lock);
      case AppLifecycleState.detached:
        _lock();
      case AppLifecycleState.resumed:
        _returnFromBackground();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _lock() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    _background = null;
    ref.read(vaultControllerProvider.notifier).lock();
  }

  /// Uygulama donmuşsa ya da telefon uyuduysa zamanlayıcılar geç kalır;
  /// süreler burada iki saatle yeniden denetlenir.
  void _returnFromBackground() {
    final background = _background;
    _background = null;
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    if (background == null) return;
    final clock = _clock;
    final lastActivity = _lastActivity;
    if (clock.hasPassed(background.at, background.delay) ||
        (lastActivity != null &&
            clock.hasPassed(lastActivity, widget.idleTimeout))) {
      _lock();
      return;
    }
    // Bu arada doldurma ekranı bir parola eklemiş ya da değiştirmiş olabilir.
    if (ref.read(loginsControllerProvider.exists)) {
      unawaited(ref.read(loginsControllerProvider.notifier).reload());
    }
  }

  void _restart() => _syncTimer(ref.read(vaultControllerProvider));

  void _syncTimer(VaultStatus status) {
    _idleTimer?.cancel();
    _lastActivity = _clock.read();
    _idleTimer = switch (status) {
      VaultOpen() || VaultRecovering() => Timer(
        widget.idleTimeout,
        () => ref.read(vaultControllerProvider.notifier).lock(),
      ),
      VaultNotSetUp() || VaultLocked() || VaultUnavailable() => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(vaultControllerProvider, (_, status) => _syncTimer(status));
    // Bekleme süresi arka plana geçerken hazır olsun: ayarlar kasa açılır
    // açılmaz yüklenir.
    ref.listen(settingsControllerProvider, (_, _) {});
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      child: widget.child,
    );
  }
}

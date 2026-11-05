import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';

/// Kasayı arka plana geçince ve kullanılmadığında kilitler.
///
/// Kurallar güvenlik tasarımı belgesinin Otomatik kilit bölümündedir.
/// `inactive` kilitlemez, çünkü parmak izi penceresi ve sistem diyalogları da
/// onu tetikler.
class AutoLockScope extends ConsumerStatefulWidget {
  const new({
    required this.child,
    this.idleTimeout = const Duration(minutes: 5),
    super.key,
  });

  final Widget child;
  final Duration idleTimeout;

  @override
  ConsumerState<AutoLockScope> createState() => _AutoLockScopeState();
}

class _AutoLockScopeState extends ConsumerState<AutoLockScope>
    with WidgetsBindingObserver {
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncTimer(ref.read(vaultControllerProvider));
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached:
        ref.read(vaultControllerProvider.notifier).lock();
      case AppLifecycleState.resumed || AppLifecycleState.inactive:
        break;
    }
  }

  void _syncTimer(VaultStatus status) {
    _idleTimer?.cancel();
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
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _syncTimer(ref.read(vaultControllerProvider)),
      child: widget.child,
    );
  }
}

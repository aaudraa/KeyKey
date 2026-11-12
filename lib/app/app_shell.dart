import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/add_panel.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/presentation/scanned_code_handler.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Sekmelerin kabuğu: alttaki cam menü ve "+" kutusu. Kutu uygulamanın
/// kendi penceresinde çizilir, ayrı pencere açmaz.
class AppShell extends ConsumerStatefulWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with TickerProviderStateMixin {
  late final AnimationController _panel = AnimationController(
    vsync: this,
    duration: KkMotion.panelOpen,
    reverseDuration: KkMotion.panelClose,
  )..addStatusListener((_) => setState(() {}));

  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: KkMotion.fast,
    value: 1,
  );

  bool _open = false;

  /// Bir seçim işlenirken ikinci dokunuş yok sayılır.
  bool _handling = false;

  @override
  void dispose() {
    _releaseBack();
    _panel.dispose();
    _tabFade.dispose();
    super.dispose();
  }

  /// Kutu açıkken geri tuşu önce kutuyu kapatır. Öncelik her açılışta
  /// yeniden alınır; sonradan açılan sayfaların dinleyicileri (ör. çöp
  /// kutusu) önceliği almış olabilir.
  ChildBackButtonDispatcher? _back;

  Future<bool> _onBack() async {
    if (!_open) return false;
    _closePanel();
    return true;
  }

  void _grabBack() {
    _releaseBack();
    final parent = Router.maybeOf(context)?.backButtonDispatcher;
    if (parent == null) return;
    _back = parent.createChildBackButtonDispatcher()
      ..addCallback(_onBack)
      ..takePriority();
  }

  void _releaseBack() {
    final back = _back;
    if (back == null) return;
    back.removeCallback(_onBack);
    back.parent.forget(back);
    _back = null;
  }

  void _openPanel() {
    _handling = false;
    _grabBack();
    _panel
      ..duration = KkMotion.of(context, KkMotion.panelOpen)
      ..reverseDuration = KkMotion.of(context, KkMotion.panelClose);
    setState(() => _open = true);
    _panel.forward();
  }

  void _closePanel() {
    if (!_open) return;
    _releaseBack();
    _panel.reverseDuration = KkMotion.of(context, KkMotion.panelClose);
    setState(() => _open = false);
    _panel.reverse();
  }

  Future<void> _choose(AddChoice choice) async {
    if (_handling) return;
    _handling = true;
    _closePanel();
    final router = GoRouter.of(context);
    switch (choice) {
      case AddChoice.password:
        router.go(AppRoutes.vaultNew);
      case AddChoice.otpManual:
        router.go(AppRoutes.authenticatorNew);
      case AddChoice.otpScan:
        router.go(AppRoutes.authenticatorScan);
      case AddChoice.otpImage:
        router.go(AppRoutes.authenticator);
        await readQrFromImage(context, ref, replace: false);
      case AddChoice.otpImport:
        router.go(AppRoutes.authenticator);
        await importFromFile(context, ref);
    }
  }

  void _selectTab(int index) {
    _closePanel();
    final shell = widget.navigationShell;
    if (index != shell.currentIndex) {
      _tabFade
        ..duration = KkMotion.of(context, KkMotion.fast)
        ..value = 0.6
        ..forward();
      shell.goBranch(index);
      return;
    }
    // Etkin sekmeye dokunmak bir üst ekrana döner. goBranch'in
    // initialLocation'ı PopScope'u atlıyor ve formdaki kaydedilmemiş
    // değişiklikler sorulmadan gidiyordu; maybePop soruyor.
    final branch = shell.route.branches[index];
    branch.navigatorKey.currentState?.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final passwordEnabled = ref.watch(loginsControllerProvider) is LoginsLoaded;
    final otpEnabled = ref.watch(otpsControllerProvider) is OtpsLoaded;
    final showPanel = _open || _panel.isAnimating || _panel.value > 0;

    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closePanel();
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                excluding: _open,
                child: FadeTransition(
                  opacity: _tabFade,
                  child: widget.navigationShell,
                ),
              ),
            ),
            if (showPanel)
              Positioned.fill(
                child: AddPanel(
                  animation: _panel,
                  passwordEnabled: passwordEnabled,
                  otpEnabled: otpEnabled,
                  onChosen: (choice) => unawaited(_choose(choice)),
                  onDismiss: _closePanel,
                ),
              ),
          ],
        ),
        bottomNavigationBar: GlassNavBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onSelected: _selectTab,
          onAdd: _open ? _closePanel : _openPanel,
          addOpen: _open,
          addLabel: l10n.vaultAdd,
          closeLabel: l10n.addClose,
          tabsHidden: _open,
          items: [
            GlassNavItem(
              icon: Icons.lock_outline,
              selectedIcon: Icons.lock,
              label: l10n.navVault,
            ),
            GlassNavItem(
              icon: Icons.shield_outlined,
              selectedIcon: Icons.shield,
              label: l10n.navAuthenticator,
            ),
            GlassNavItem(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              label: l10n.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}

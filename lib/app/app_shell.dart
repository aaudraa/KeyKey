import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

class AppShell extends StatelessWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: GlassNavBar(
        selectedIndex: navigationShell.currentIndex,
        onSelected: (index) {
          if (index != navigationShell.currentIndex) {
            navigationShell.goBranch(index);
            return;
          }
          // Etkin sekmeye dokunmak bir üst ekrana döner. goBranch'in
          // initialLocation'ı PopScope'u atlıyor ve formdaki kaydedilmemiş
          // değişiklikler sorulmadan gidiyordu; maybePop soruyor.
          final branch = navigationShell.route.branches[index];
          branch.navigatorKey.currentState?.maybePop();
        },
        // "+" kutusu Görev 5'te bağlanır.
        onAdd: () {},
        addOpen: false,
        addLabel: l10n.vaultAdd,
        closeLabel: l10n.otpClose,
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
    );
  }
}

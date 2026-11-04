import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/app_shell.dart';
import 'package:keykey/features/authenticator/presentation/authenticator_screen.dart';
import 'package:keykey/features/settings/presentation/settings_screen.dart';
import 'package:keykey/features/vault/presentation/vault_screen.dart';

abstract final class AppRoutes {
  static const vault = '/kasa';
  static const authenticator = '/2fa';
  static const settings = '/ayarlar';
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.vault,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.vault,
                builder: (context, state) => const VaultScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.authenticator,
                builder: (context, state) => const AuthenticatorScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

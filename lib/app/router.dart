import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/app_shell.dart';
import 'package:keykey/features/authenticator/presentation/authenticator_screen.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/lock_screen.dart';
import 'package:keykey/features/lock/presentation/new_password_screen.dart';
import 'package:keykey/features/lock/presentation/recovery_screen.dart';
import 'package:keykey/features/lock/presentation/unavailable_screen.dart';
import 'package:keykey/features/onboarding/presentation/onboarding_screen.dart';
import 'package:keykey/features/settings/presentation/change_password_screen.dart';
import 'package:keykey/features/settings/presentation/settings_screen.dart';
import 'package:keykey/features/vault/presentation/vault_screen.dart';

abstract final class AppRoutes {
  static const vault = '/kasa';
  static const authenticator = '/2fa';
  static const settings = '/ayarlar';
  static const changePassword = '/ayarlar/parola';
  static const setup = '/kurulum';
  static const lock = '/kilit';
  static const recovery = '/kilit/kurtarma';
  static const newPassword = '/yeni-parola';
  static const unavailable = '/kullanilamiyor';
}

/// Kasa durumuna göre gidilmesi gereken yer. `null` ise olduğu yerde kalır.
///
/// Kasa açık değilken kasa ekranlarına hiçbir yoldan ulaşılamaz.
String? vaultRedirect(VaultStatus status, String location) {
  return switch (status) {
    VaultNotSetUp() => location == AppRoutes.setup ? null : AppRoutes.setup,
    VaultLocked() =>
      location == AppRoutes.lock || location == AppRoutes.recovery
          ? null
          : AppRoutes.lock,
    VaultRecovering() =>
      location == AppRoutes.newPassword ? null : AppRoutes.newPassword,
    VaultUnavailable() =>
      location == AppRoutes.unavailable ? null : AppRoutes.unavailable,
    VaultOpen() => _gateRoutes.contains(location) ? AppRoutes.vault : null,
  };
}

const Set<String> _gateRoutes = {
  AppRoutes.setup,
  AppRoutes.lock,
  AppRoutes.recovery,
  AppRoutes.newPassword,
  AppRoutes.unavailable,
};

final routerProvider = Provider<GoRouter>((ref) {
  final statusChanges = ValueNotifier<int>(0);
  ref
    ..listen(vaultControllerProvider, (_, _) => statusChanges.value++)
    ..onDispose(statusChanges.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.vault,
    refreshListenable: statusChanges,
    redirect: (context, state) =>
        vaultRedirect(ref.read(vaultControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.setup,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.lock,
        builder: (context, state) => const LockScreen(),
        routes: [
          GoRoute(
            path: 'kurtarma',
            builder: (context, state) => const RecoveryScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.newPassword,
        builder: (context, state) => const NewPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.unavailable,
        builder: (context, state) => const UnavailableScreen(),
      ),
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
                routes: [
                  GoRoute(
                    path: 'parola',
                    builder: (context, state) => const ChangePasswordScreen(),
                  ),
                ],
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

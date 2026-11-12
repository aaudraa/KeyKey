import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/app_shell.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/features/authenticator/application/otp_import.dart';
import 'package:keykey/features/authenticator/data/otpauth_uri.dart';
import 'package:keykey/features/authenticator/presentation/authenticator_screen.dart';
import 'package:keykey/features/authenticator/presentation/otp_edit_screen.dart';
import 'package:keykey/features/authenticator/presentation/otp_import_screen.dart';
import 'package:keykey/features/authenticator/presentation/otp_trash_screen.dart';
import 'package:keykey/features/authenticator/presentation/qr_scan_screen.dart';
import 'package:keykey/features/backup/data/import/login_import.dart';
import 'package:keykey/features/backup/presentation/login_import_screen.dart';
import 'package:keykey/features/backup/presentation/restore_screen.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/lock_screen.dart';
import 'package:keykey/features/lock/presentation/new_password_screen.dart';
import 'package:keykey/features/lock/presentation/recovery_screen.dart';
import 'package:keykey/features/lock/presentation/unavailable_screen.dart';
import 'package:keykey/features/onboarding/presentation/onboarding_screen.dart';
import 'package:keykey/features/settings/presentation/change_password_screen.dart';
import 'package:keykey/features/settings/presentation/settings_screen.dart';
import 'package:keykey/features/vault/presentation/login_detail_screen.dart';
import 'package:keykey/features/vault/presentation/login_edit_screen.dart';
import 'package:keykey/features/vault/presentation/password_report_screen.dart';
import 'package:keykey/features/vault/presentation/trash_screen.dart';
import 'package:keykey/features/vault/presentation/vault_screen.dart';

abstract final class AppRoutes {
  static const vault = '/kasa';
  static const vaultNew = '/kasa/yeni';
  static const vaultTrash = '/kasa/cop';
  static const vaultReport = '/kasa/rapor';
  static const authenticator = '/2fa';
  static const authenticatorNew = '/2fa/yeni';
  static const authenticatorTrash = '/2fa/cop';
  static const authenticatorScan = '/2fa/tara';
  static const authenticatorImport = '/2fa/ice-aktar';
  static const settings = '/ayarlar';
  static const changePassword = '/ayarlar/parola';
  static const loginImport = '/ayarlar/ice-aktar';
  static const setup = '/kurulum';
  static const restore = '/geri-yukle';
  static const lock = '/kilit';
  static const recovery = '/kilit/kurtarma';
  static const newPassword = '/yeni-parola';
  static const unavailable = '/kullanilamiyor';

  static String vaultItem(String idHex) => '/kasa/kayit/$idHex';

  static String vaultItemEdit(String idHex) => '/kasa/kayit/$idHex/duzenle';

  static String authenticatorItemEdit(String idHex) =>
      '/2fa/hesap/$idHex/duzenle';
}

/// Kasa durumuna göre gidilmesi gereken yer. `null` ise olduğu yerde kalır.
///
/// Kasa açık değilken kasa ekranlarına hiçbir yoldan ulaşılamaz.
String? vaultRedirect(VaultStatus status, String location) {
  return switch (status) {
    // Yeni telefonda kasa yedekten de kurulabilir.
    VaultNotSetUp() =>
      location == AppRoutes.setup || location == AppRoutes.restore
          ? null
          : AppRoutes.setup,
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

  // Form ekranları kök gezginde açılır; alt menünün üstünü örterler.
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'kök');
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
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
        path: AppRoutes.restore,
        // Yedek yalnızca seçiciden gelir; uygulama yeniden kurulurken
        // yol kalırsa kuruluma dönülür.
        redirect: (context, state) =>
            state.extra is BackupFile ? null : AppRoutes.setup,
        builder: (context, state) =>
            RestoreScreen(file: state.extra! as BackupFile),
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
                routes: [
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'yeni',
                    builder: (context, state) => const LoginEditScreen(),
                  ),
                  GoRoute(
                    path: 'cop',
                    builder: (context, state) => const TrashScreen(),
                  ),
                  GoRoute(
                    path: 'rapor',
                    builder: (context, state) => const PasswordReportScreen(),
                  ),
                  GoRoute(
                    path: 'kayit/:id',
                    builder: (context, state) =>
                        LoginDetailScreen(idHex: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        parentNavigatorKey: rootNavigatorKey,
                        path: 'duzenle',
                        builder: (context, state) =>
                            LoginEditScreen(idHex: state.pathParameters['id']),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.authenticator,
                builder: (context, state) => const AuthenticatorScreen(),
                routes: [
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'yeni',
                    // QR'dan okunan hesap onay için forma dolu gelir.
                    builder: (context, state) => OtpEditScreen(
                      initial: switch (state.extra) {
                        final OtpauthAccount account => account,
                        _ => null,
                      },
                    ),
                  ),
                  GoRoute(
                    path: 'tara',
                    builder: (context, state) => const QrScanScreen(),
                  ),
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'ice-aktar',
                    // Okunan hesaplar yalnızca bellekte, ekrana doğrudan
                    // verilir. Kaynak yoksa, örneğin uygulama yeniden
                    // açıldıysa, listeye dönülür.
                    redirect: (context, state) => state.extra is ImportSource
                        ? null
                        : AppRoutes.authenticator,
                    builder: (context, state) =>
                        OtpImportScreen(source: state.extra! as ImportSource),
                  ),
                  GoRoute(
                    path: 'cop',
                    builder: (context, state) => const OtpTrashScreen(),
                  ),
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'hesap/:id/duzenle',
                    builder: (context, state) =>
                        OtpEditScreen(idHex: state.pathParameters['id']),
                  ),
                ],
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
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'parola',
                    builder: (context, state) => const ChangePasswordScreen(),
                  ),
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'ice-aktar',
                    // Okunan dosya yalnızca bellekte, ekrana doğrudan verilir.
                    // Yoksa, örneğin uygulama yeniden açıldıysa, ayarlara
                    // dönülür.
                    redirect: (context, state) =>
                        state.extra is LoginExport ? null : AppRoutes.settings,
                    builder: (context, state) =>
                        LoginImportScreen(export: state.extra! as LoginExport),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/app_shell.dart';
import 'package:keykey/app/ui/kk_motion.dart';
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
import 'package:keykey/features/onboarding/application/terms_controller.dart';
import 'package:keykey/features/onboarding/presentation/intro_screen.dart';
import 'package:keykey/features/onboarding/presentation/onboarding_screen.dart';
import 'package:keykey/features/onboarding/presentation/terms_screen.dart';
import 'package:keykey/features/settings/presentation/change_password_screen.dart';
import 'package:keykey/features/settings/presentation/licenses_screen.dart';
import 'package:keykey/features/settings/presentation/new_recovery_key_screen.dart';
import 'package:keykey/features/settings/presentation/settings_screen.dart';
import 'package:keykey/features/vault/presentation/card_detail_screen.dart';
import 'package:keykey/features/vault/presentation/card_edit_screen.dart';
import 'package:keykey/features/vault/presentation/login_detail_screen.dart';
import 'package:keykey/features/vault/presentation/login_edit_screen.dart';
import 'package:keykey/features/vault/presentation/note_detail_screen.dart';
import 'package:keykey/features/vault/presentation/note_edit_screen.dart';
import 'package:keykey/features/vault/presentation/password_report_screen.dart';
import 'package:keykey/features/vault/presentation/trash_screen.dart';
import 'package:keykey/features/vault/presentation/vault_screen.dart';

abstract final class AppRoutes {
  static const vault = '/kasa';
  static const vaultNew = '/kasa/yeni';
  static const cardNew = '/kasa/yeni-kart';
  static const noteNew = '/kasa/yeni-not';
  static const vaultTrash = '/kasa/cop';
  static const vaultReport = '/kasa/rapor';
  static const authenticator = '/2fa';
  static const authenticatorNew = '/2fa/yeni';
  static const authenticatorTrash = '/2fa/cop';
  static const authenticatorScan = '/2fa/tara';
  static const authenticatorImport = '/2fa/ice-aktar';
  static const settings = '/ayarlar';
  static const changePassword = '/ayarlar/parola';
  static const newRecoveryKey = '/ayarlar/kurtarma-anahtari';
  static const loginImport = '/ayarlar/ice-aktar';
  static const licenses = '/ayarlar/lisanslar';
  static const settingsTerms = '/ayarlar/kosullar';
  static const licensesAll = '/ayarlar/lisanslar/tum';
  static const setup = '/kurulum';
  static const intro = '/tanitim';
  static const terms = '/kosullar';
  static const restore = '/geri-yukle';
  static const lock = '/kilit';
  static const recovery = '/kilit/kurtarma';
  static const newPassword = '/yeni-parola';
  static const unavailable = '/kullanilamiyor';

  static String vaultItem(String idHex) => '/kasa/kayit/$idHex';

  static String cardItem(String idHex) => '/kasa/kart/$idHex';

  static String cardItemEdit(String idHex) => '/kasa/kart/$idHex/duzenle';

  static String noteItem(String idHex) => '/kasa/not/$idHex';

  static String noteItemEdit(String idHex) => '/kasa/not/$idHex/duzenle';

  /// Bir ya da birkaç paketin lisans metni; adlar sorgu parametresinde.
  static String licenseText({
    required String title,
    required List<String> packages,
  }) => Uri(
    path: '/ayarlar/lisanslar/metin',
    queryParameters: {'ad': title, 'p': packages},
  ).toString();

  static String vaultItemEdit(String idHex) => '/kasa/kayit/$idHex/duzenle';

  static String authenticatorItemEdit(String idHex) =>
      '/2fa/hesap/$idHex/duzenle';
}

/// Kasa durumuna göre gidilmesi gereken yer. `null` ise olduğu yerde kalır.
///
/// Kasa açık değilken kasa ekranlarına hiçbir yoldan ulaşılamaz. Kasa
/// açılınca [resume]'a, yani kilitlenmeden önce kalınan yere gidilir.
///
/// Kullanım koşulları kabul edilmeden ([termsAccepted]) kasa kurulmaz ve
/// açılmaz: yeni kullanıcı tanıtımı izleyebilir, kuruluma geçerken
/// koşullara gelir; kasası olan kullanıcı kilit ekranından önce koşulları
/// bir kez görür.
String? vaultRedirect(
  VaultStatus status,
  String location, {
  String resume = AppRoutes.vault,
  bool termsAccepted = true,
}) {
  if (!termsAccepted) {
    if (location == AppRoutes.terms) return null;
    if (status is VaultNotSetUp) {
      // Önce tanıtım; kuruluma ya da yedekten dönüşe geçerken koşullar.
      if (location == AppRoutes.intro) return null;
      return location == AppRoutes.setup || location == AppRoutes.restore
          ? AppRoutes.terms
          : AppRoutes.intro;
    }
    return AppRoutes.terms;
  }
  // Kabulden sonra koşullardan kuruluma; diğer durumlarda aşağıdaki kapı
  // kuralları kilit ya da kalınan yere götürür.
  if (status is VaultNotSetUp && location == AppRoutes.terms) {
    return AppRoutes.setup;
  }
  return switch (status) {
    // Önce tanıtım; yeni telefonda kasa yedekten de kurulabilir.
    VaultNotSetUp() =>
      location == AppRoutes.intro ||
              location == AppRoutes.setup ||
              location == AppRoutes.restore
          ? null
          : AppRoutes.intro,
    VaultLocked() =>
      location == AppRoutes.lock || location == AppRoutes.recovery
          ? null
          : AppRoutes.lock,
    VaultRecovering() =>
      location == AppRoutes.newPassword ? null : AppRoutes.newPassword,
    VaultUnavailable() =>
      location == AppRoutes.unavailable ? null : AppRoutes.unavailable,
    VaultOpen() => _gateRoutes.contains(location) ? resume : null,
  };
}

/// Kilit açılınca [path]'in yerine dönülecek yer: bir kasa kaydının
/// ayrıntısı ya da sekmenin kökü. Formlar ve tek seferlik ekranlar
/// (tarayıcı, içe aktarma) geri açılmaz; yarım kalan girdi kilitle zaten
/// silinir.
String resumeLocationFor(String path) {
  if (_vaultItem.hasMatch(path)) return path;
  bool under(String root) => path == root || path.startsWith('$root/');
  if (under(AppRoutes.authenticator)) return AppRoutes.authenticator;
  if (under(AppRoutes.settings)) return AppRoutes.settings;
  return AppRoutes.vault;
}

final _vaultItem = RegExp(r'^/kasa/(kayit|kart|not)/[^/]+$');

const Set<String> _gateRoutes = {
  AppRoutes.terms,
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
    ..listen(termsAcceptedProvider, (_, _) => statusChanges.value++)
    ..onDispose(statusChanges.dispose);

  // Kilitlenmeden önce kalınan yer; yalnızca bellekte tutulur.
  var resume = AppRoutes.vault;

  // Form ekranları kök gezginde açılır; alt menünün üstünü örterler.
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'kök');
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.vault,
    refreshListenable: statusChanges,
    redirect: (context, state) {
      final status = ref.read(vaultControllerProvider);
      // Yeni ya da yedekten kurulan kasa kasa sekmesinde açılır.
      if (status is VaultNotSetUp) resume = AppRoutes.vault;
      return vaultRedirect(
        status,
        state.matchedLocation,
        resume: resume,
        termsAccepted: ref.read(termsAcceptedProvider),
      );
    },
    routes: [
      kkRoute(
        path: AppRoutes.intro,
        builder: (context, state) => const IntroScreen(),
      ),
      kkRoute(
        path: AppRoutes.terms,
        builder: (context, state) => const TermsScreen(),
      ),
      kkRoute(
        path: AppRoutes.setup,
        builder: (context, state) => const OnboardingScreen(),
      ),
      kkRoute(
        path: AppRoutes.restore,
        // Yedek yalnızca seçiciden gelir; uygulama yeniden kurulurken
        // yol kalırsa kuruluma dönülür.
        redirect: (context, state) =>
            state.extra is BackupFile ? null : AppRoutes.setup,
        builder: (context, state) =>
            RestoreScreen(file: state.extra! as BackupFile),
      ),
      kkRoute(
        path: AppRoutes.lock,
        // Kilitlenince içerik hızla solar, kilit ekranı belirir (madde 4.4).
        transition: KkRouteTransition.fade,
        builder: (context, state) => const LockScreen(),
        routes: [
          kkRoute(
            path: 'kurtarma',
            builder: (context, state) => const RecoveryScreen(),
          ),
        ],
      ),
      kkRoute(
        path: AppRoutes.newPassword,
        builder: (context, state) => const NewPasswordScreen(),
      ),
      kkRoute(
        path: AppRoutes.unavailable,
        builder: (context, state) => const UnavailableScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              kkRoute(
                path: AppRoutes.vault,
                builder: (context, state) => const VaultScreen(),
                routes: [
                  kkRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'yeni',
                    builder: (context, state) => const LoginEditScreen(),
                  ),
                  kkRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'yeni-kart',
                    builder: (context, state) => const CardEditScreen(),
                  ),
                  kkRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'yeni-not',
                    builder: (context, state) => const NoteEditScreen(),
                  ),
                  kkRoute(
                    path: 'cop',
                    builder: (context, state) => const TrashScreen(),
                  ),
                  kkRoute(
                    path: 'not/:id',
                    builder: (context, state) =>
                        NoteDetailScreen(idHex: state.pathParameters['id']!),
                    routes: [
                      kkRoute(
                        parentNavigatorKey: rootNavigatorKey,
                        path: 'duzenle',
                        builder: (context, state) =>
                            NoteEditScreen(idHex: state.pathParameters['id']),
                      ),
                    ],
                  ),
                  kkRoute(
                    path: 'kart/:id',
                    builder: (context, state) =>
                        CardDetailScreen(idHex: state.pathParameters['id']!),
                    routes: [
                      kkRoute(
                        parentNavigatorKey: rootNavigatorKey,
                        path: 'duzenle',
                        builder: (context, state) =>
                            CardEditScreen(idHex: state.pathParameters['id']),
                      ),
                    ],
                  ),
                  kkRoute(
                    path: 'rapor',
                    builder: (context, state) => const PasswordReportScreen(),
                  ),
                  kkRoute(
                    path: 'kayit/:id',
                    builder: (context, state) =>
                        LoginDetailScreen(idHex: state.pathParameters['id']!),
                    routes: [
                      kkRoute(
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
              kkRoute(
                path: AppRoutes.authenticator,
                builder: (context, state) => const AuthenticatorScreen(),
                routes: [
                  kkRoute(
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
                  kkRoute(
                    path: 'tara',
                    builder: (context, state) => const QrScanScreen(),
                  ),
                  kkRoute(
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
                  kkRoute(
                    path: 'cop',
                    builder: (context, state) => const OtpTrashScreen(),
                  ),
                  kkRoute(
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
              kkRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  kkRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'parola',
                    builder: (context, state) => const ChangePasswordScreen(),
                  ),
                  kkRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'kurtarma-anahtari',
                    builder: (context, state) => const NewRecoveryKeyScreen(),
                  ),
                  kkRoute(
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
                  kkRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'kosullar',
                    builder: (context, state) =>
                        const TermsScreen(readOnly: true),
                  ),
                  kkRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'lisanslar',
                    builder: (context, state) => const LicensesScreen(),
                    routes: [
                      kkRoute(
                        parentNavigatorKey: rootNavigatorKey,
                        path: 'tum',
                        builder: (context, state) =>
                            const LicensePackagesScreen(),
                      ),
                      kkRoute(
                        parentNavigatorKey: rootNavigatorKey,
                        path: 'metin',
                        builder: (context, state) => LicenseTextScreen(
                          title: state.uri.queryParameters['ad'] ?? '',
                          packages:
                              state.uri.queryParametersAll['p'] ?? const [],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  // Geri dönüşler yönlendirmeden geçmez; kalınan yer gezginin kendisinden
  // okunur. Kilitliyken değişmez, böylece kilit ekranı kayda geçmez.
  // `currentConfiguration.uri` push ile açılan kaydı göstermez (temel yer
  // /kasa kalır); en üstteki eşleşmenin durumu kaydın kendi adresini verir.
  void remember() {
    if (ref.read(vaultControllerProvider) is! VaultOpen) return;
    if (router.routerDelegate.currentConfiguration.isEmpty) return;
    final path = router.state.uri.path;
    if (!_gateRoutes.contains(path)) resume = resumeLocationFor(path);
  }

  router.routerDelegate.addListener(remember);
  ref.onDispose(() {
    router.routerDelegate.removeListener(remember);
    router.dispose();
  });
  return router;
});

/// Bir rotanın sayfa geçişi.
enum KkRouteTransition {
  /// Temanın geçişi: yandan kayma ve solma, tahmini geri hareketiyle.
  material,

  /// Kısa solma ([KkMotion.fast]); kilit ekranı için.
  fade,
}

/// [GoRoute] ile aynı, ama sayfa her zaman Flutter'ın [MaterialPage]'iyle
/// kurulur. go_router uygulama türünü `material_ui` paketinin
/// `MaterialApp`'iyle tanır; KeyKey Flutter'ın kendi `MaterialApp`'ini
/// kullandığı için kendi hâline bırakılınca bütün sayfalar geçişsiz
/// (`NoTransitionPage`) açılıyordu.
GoRoute kkRoute({
  required String path,
  GoRouterWidgetBuilder? builder,
  GoRouterRedirect? redirect,
  GlobalKey<NavigatorState>? parentNavigatorKey,
  List<RouteBase> routes = const <RouteBase>[],
  KkRouteTransition transition = KkRouteTransition.material,
}) => GoRoute(
  path: path,
  redirect: redirect,
  parentNavigatorKey: parentNavigatorKey,
  routes: routes,
  pageBuilder: builder == null
      ? null
      : (context, state) => switch (transition) {
          KkRouteTransition.material => MaterialPage<void>(
            key: state.pageKey,
            name: state.name ?? state.path,
            arguments: state.extra,
            restorationId: state.pageKey.value,
            child: builder(context, state),
          ),
          KkRouteTransition.fade => CustomTransitionPage<void>(
            key: state.pageKey,
            name: state.name ?? state.path,
            arguments: state.extra,
            restorationId: state.pageKey.value,
            transitionDuration: KkMotion.of(context, KkMotion.fast),
            reverseTransitionDuration: KkMotion.of(context, KkMotion.fast),
            transitionsBuilder: (context, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
            child: builder(context, state),
          ),
        },
);

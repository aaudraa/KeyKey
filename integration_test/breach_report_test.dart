import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/app/app.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/application/records_controller.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/note_content.dart';
import 'package:keykey/features/vault/presentation/password_report_screen.dart';
import 'package:sodium/sodium_sumo.dart';

import '../test/support/fake_vault_service.dart';

/// Parola raporundaki sızıntı kontrolü gerçek cihazda, gerçek ağla: rapor
/// açılır, "İnternetten denetle"ye dokunulur, sonuç ekranda görünür.
///
/// Cihaz internete çıkabilmeli. Uçak modunda denemek için:
/// `adb shell cmd connectivity airplane-mode enable` ve
/// `flutter test integration_test/breach_report_test.dart
/// --dart-define=KK_BREACH_OFFLINE=true` (sonra `disable`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const offline = bool.fromEnvironment('KK_BREACH_OFFLINE');

  late SodiumSumo sodium;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  /// Gerçek ağı beklerken kareleri ilerletir; [finder] görünene ya da süre
  /// dolana kadar.
  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    offline
        ? 'uçak modunda denetlenemedi ve yeniden dene'
        : "raporda gerçek denetim: 'password' sızmış görünüyor",
    (tester) async {
      // pumpKeyKey bilgisayardaki test dosyalarını okuyor; cihazda uygulama
      // burada kuruluyor. Ağ kaynağı değiştirilmiyor: gerçek istemci.
      tester.platformDispatcher.localesTestValue = [const Locale('tr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final service = FakeVaultService(sodium);
      final logins = FakeLoginRepository(
        items: [
          FakeLoginRepository.item(
            const LoginContent(
              name: 'Eski Hesap',
              username: 'ali',
              password: 'password',
            ),
            id: 1,
          ),
          FakeLoginRepository.item(
            const LoginContent(
              name: 'Rastgele',
              password: 'Vq7#kL2m!xR9pZ4wTe-2026',
            ),
            id: 2,
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ambientMotionProvider.overrideWithValue(false),
            vaultServiceProvider.overrideWithValue(service),
            loginRepositoryFactoryProvider.overrideWithValue((_) => logins),
            cardRepositoryFactoryProvider.overrideWithValue(
              (_) => FakeRecordRepository<CardContent>(),
            ),
            noteRepositoryFactoryProvider.overrideWithValue(
              (_) => FakeRecordRepository<NoteContent>(),
            ),
            otpRepositoryFactoryProvider.overrideWithValue(
              (_) => FakeOtpRepository(),
            ),
            settingsRepositoryFactoryProvider.overrideWithValue(
              (_) => FakeSettingsRepository(),
            ),
            initialVaultStatusProvider.overrideWithValue(
              VaultOpen(service.newSession()),
            ),
          ],
          child: const KeyKeyApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Diğer işlemler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parola raporu'));
      await tester.pumpAndSettle();
      expect(find.byType(PasswordReportScreen), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('İnternetten denetle'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(PasswordReportScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('İnternetten denetle'));

      if (offline) {
        final failed = find.text(
          'Denetlenemedi. İnternet bağlantını kontrol et.',
        );
        await pumpUntil(tester, failed);
        expect(failed, findsOneWidget);
        expect(find.text('Yeniden dene'), findsOneWidget);
        expect(find.textContaining('kez görüldü'), findsNothing);
        return;
      }

      final title = find.text('Sızıntılarda görülen parolalar (1)');
      await pumpUntil(tester, title);
      expect(title, findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('kez görüldü · ali'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(PasswordReportScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.textContaining('kez görüldü · ali'), findsOneWidget);
      expect(find.text('Rastgele'), findsNothing);
      expect(find.text('Yeniden denetle'), findsOneWidget);
    },
  );
}

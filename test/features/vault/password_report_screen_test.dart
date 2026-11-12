import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/application/password_report.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/presentation/password_report_screen.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeLoginRepository logins;

  const shared = 'Ortak-Uzun-Parola-8xQ!';

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
    logins = FakeLoginRepository(
      items: [
        FakeLoginRepository.item(
          const LoginContent(
            name: 'Posta',
            username: 'ali@example.com',
            password: shared,
          ),
          id: 1,
        ),
        FakeLoginRepository.item(
          const LoginContent(name: 'Forum', password: shared),
          id: 2,
        ),
        FakeLoginRepository.item(
          const LoginContent(
            name: 'Banka',
            username: 'ali',
            password: 'qwerty12345',
          ),
          id: 3,
        ),
        FakeLoginRepository.item(
          const LoginContent(name: 'Sağlam', password: 'Vq7#kL2m!xR9pZ4wTe'),
          id: 4,
        ),
        FakeLoginRepository.item(
          LoginContent(
            name: 'Eski Oyun',
            password: shared,
            trashedAt: DateTime.utc(2026, 11, 4),
          ),
          id: 5,
        ),
      ],
    );
  });

  Future<void> openReport(
    WidgetTester tester, {
    Locale locale = const Locale('tr'),
  }) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      logins: logins,
      locale: locale,
    );
    final en = locale.languageCode == 'en';
    await tester.tap(find.byTooltip(en ? 'More actions' : 'Diğer işlemler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en ? 'Password report' : 'Parola raporu'));
    await tester.pumpAndSettle();
  }

  Finder inReport(Finder finder) =>
      find.descendant(of: find.byType(PasswordReportScreen), matching: finder);

  testWidgets('zayıf ve tekrar eden parolalar listeleniyor', (tester) async {
    await openReport(tester);

    expect(find.text('Zayıf parolalar (1)'), findsOneWidget);
    expect(find.text('Kolay tahmin edilebilir · ali'), findsOneWidget);
    expect(find.text('Tekrar eden parolalar (1)'), findsOneWidget);
    expect(find.text('Aynı parola 2 kayıtta'), findsOneWidget);
    expect(inReport(find.text('Forum')), findsOneWidget);
    expect(inReport(find.text('Posta')), findsOneWidget);

    // Güçlü ve tek kullanılan parola, çöp kutusundaki kayıt ve parolaların
    // kendisi raporda yok.
    expect(inReport(find.text('Sağlam')), findsNothing);
    expect(inReport(find.text('Eski Oyun')), findsNothing);
    expect(inReport(find.textContaining('qwerty')), findsNothing);
    expect(inReport(find.textContaining('Ortak')), findsNothing);
  });

  testWidgets(
    'kayda dokununca parola değiştirilebiliyor, rapor güncelleniyor',
    (tester) async {
      await openReport(tester);

      await tester.tap(inReport(find.text('Banka')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Parola'),
        'Yeni-Guclu-Parola-7wQ#',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Kaydet'));
      await tester.pumpAndSettle();

      expect(logins.items[2].content.password, 'Yeni-Guclu-Parola-7wQ#');
      expect(find.byType(PasswordReportScreen), findsOneWidget);
      expect(find.textContaining('Zayıf parolalar'), findsNothing);
      expect(find.text('Tekrar eden parolalar (1)'), findsOneWidget);
    },
  );

  testWidgets('İngilizce', (tester) async {
    await openReport(tester, locale: const Locale('en'));

    expect(find.text('Weak password (1)'), findsOneWidget);
    expect(find.text('Easy to guess · ali'), findsOneWidget);
    expect(find.text('Reused password (1)'), findsOneWidget);
    expect(find.text('Same password in 2 entries'), findsOneWidget);
  });

  testWidgets('sorun yoksa söyleniyor', (tester) async {
    logins = FakeLoginRepository(
      items: [
        FakeLoginRepository.item(
          const LoginContent(name: 'Sağlam', password: 'Vq7#kL2m!xR9pZ4wTe'),
          id: 1,
        ),
      ],
    );
    await openReport(tester);

    expect(find.text('Zayıf ya da tekrar eden parola yok.'), findsOneWidget);
  });

  testWidgets('kilitlenince rapor kapanıyor ve bellekten siliniyor', (
    tester,
  ) async {
    await openReport(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PasswordReportScreen)),
    );

    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('KeyKey kilitli'), findsOneWidget);
    expect(find.byType(PasswordReportScreen), findsNothing);
    // Kayıtlar bırakıldı; rapor yeniden istense de hesaplanacak bir şey yok.
    expect(container.read(loginsControllerProvider), isA<LoginsLoading>());
    expect(container.read(passwordReportProvider), isNull);

    GoRouter.of(tester.element(find.text('KeyKey kilitli')))
        .go(AppRoutes.vaultReport);
    await tester.pumpAndSettle();
    expect(find.text('KeyKey kilitli'), findsOneWidget);
  });
}

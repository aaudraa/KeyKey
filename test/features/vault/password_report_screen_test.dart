import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/core/network/pwned_passwords_client.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/application/breach_check.dart';
import 'package:keykey/features/vault/application/breach_check_controller.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/application/password_report.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/presentation/password_report_screen.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_range_source.dart';
import '../../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeLoginRepository logins;
  late FakeRangeSource source;

  const shared = 'Ortak-Uzun-Parola-8xQ!';

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
    source = FakeRangeSource();
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
    // Raporun bütün bölümleri kaydırmadan görünsün; liste ekran dışındaki
    // satırları kurmuyor.
    tester.view
      ..physicalSize = const Size(1080, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      logins: logins,
      locale: locale,
      extraOverrides: [pwnedRangeSourceProvider.overrideWithValue(source)],
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
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
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

  group('sızıntı', () {
    String leak(String password, int count) =>
        '${pwnedHash(password).substring(5)}:$count\r\n$pwnedPadding:0\r\n';

    Future<void> runCheck(
      WidgetTester tester, {
      String label = 'İnternetten denetle',
    }) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    void lock(WidgetTester tester) => tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    testWidgets('açıklama ve düğme; açılınca hiçbir şey gönderilmiyor', (
      tester,
    ) async {
      await openReport(tester);

      expect(find.text('Sızıntı kontrolü'), findsOneWidget);
      expect(
        find.textContaining('yalnızca özetinin ilk 5 karakteri gider'),
        findsOneWidget,
      );
      expect(find.text('Veri: Have I Been Pwned (CC BY 4.0)'), findsOneWidget);
      expect(find.text('İnternetten denetle'), findsOneWidget);
      expect(source.calls, isEmpty);
    });

    testWidgets('sızan parolalar sayılarıyla listeleniyor', (tester) async {
      source.answer = (prefix) => leak(shared, 1234);
      await openReport(tester);
      await runCheck(tester);

      expect(find.text('Sızıntılarda görülen parolalar (2)'), findsOneWidget);
      expect(
        find.text('Sızıntılarda 1.234 kez görüldü · ali@example.com'),
        findsOneWidget,
      );
      expect(find.text('Sızıntılarda 1.234 kez görüldü'), findsOneWidget);
      expect(inReport(find.text('Eski Oyun')), findsNothing);
      // Üç farklı etkin parola; her önek bir kez.
      expect(source.calls, hasLength(source.calls.toSet().length));
      expect(source.calls.length, lessThanOrEqualTo(3));
    });

    testWidgets('İngilizce', (tester) async {
      source.answer = (prefix) => leak(shared, 1234);
      await openReport(tester, locale: const Locale('en'));
      await runCheck(tester, label: 'Check online');

      expect(find.text('Passwords seen in breaches (2)'), findsOneWidget);
      expect(find.text('Seen 1,234 times in breaches'), findsOneWidget);
    });

    testWidgets('temiz sonuç', (tester) async {
      await openReport(tester);
      await runCheck(tester);

      expect(find.text('Sızıntılarda görülen parola yok.'), findsOneWidget);
      expect(find.text('Yeniden denetle'), findsOneWidget);
      expect(
        find.textContaining('Sızıntılarda görülen parolalar'),
        findsNothing,
      );
    });

    testWidgets('hata ve yeniden dene', (tester) async {
      source.answer = (prefix) =>
          throw const PwnedPasswordsException('bağlantı');
      await openReport(tester);
      await runCheck(tester);

      expect(
        find.text('Denetlenemedi. İnternet bağlantını kontrol et.'),
        findsOneWidget,
      );
      expect(find.text('Sızıntılarda görülen parola yok.'), findsNothing);

      source.answer = (prefix) => leak(shared, 7);
      await runCheck(tester, label: 'Yeniden dene');

      expect(find.text('Sızıntılarda görülen parolalar (2)'), findsOneWidget);
    });

    testWidgets('HTML yanıtta "sızıntı yok" denmiyor', (tester) async {
      source.answer = (prefix) => '<html><body>Otel Wi-Fi</body></html>';
      await openReport(tester);
      await runCheck(tester);

      expect(
        find.text('Denetlenemedi. İnternet bağlantını kontrol et.'),
        findsOneWidget,
      );
      expect(find.text('Sızıntılarda görülen parola yok.'), findsNothing);
    });

    testWidgets('denetlenirken kilitlenince denetim bırakılıyor', (
      tester,
    ) async {
      logins = FakeLoginRepository(
        items: [
          for (var i = 0; i < 10; i++)
            FakeLoginRepository.item(
              LoginContent(name: 'Kayıt $i', password: 'parola-$i'),
              id: i + 1,
            ),
        ],
      );
      final hold = Completer<String>();
      source.answer = (prefix) => hold.future;
      await openReport(tester);
      await tester.ensureVisible(find.text('İnternetten denetle'));
      await tester.tap(find.text('İnternetten denetle'));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining(' önek'), findsOneWidget);
      expect(source.calls, hasLength(4));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PasswordReportScreen)),
      );

      lock(tester);
      await tester.pumpAndSettle();
      expect(find.text('KeyKey kilitli'), findsOneWidget);

      hold.complete('$pwnedPadding:0\r\n');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(source.calls, hasLength(4));
      expect(container.read(breachCheckProvider), isA<BreachIdle>());
    });

    testWidgets('parolası değişen kayıt listeden düşüyor', (tester) async {
      source.answer = (prefix) => leak(shared, 3);
      await openReport(tester);
      await runCheck(tester);
      expect(find.text('Sızıntılarda görülen parolalar (2)'), findsOneWidget);

      final posta = find.text('Sızıntılarda 3 kez görüldü · ali@example.com');
      await tester.ensureVisible(posta);
      await tester.tap(posta);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Parola'),
        'Yeni-Guclu-Parola-7wQ#',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.pumpAndSettle();

      expect(find.byType(PasswordReportScreen), findsOneWidget);
      expect(find.text('Sızıntılarda görülen parolalar (1)'), findsOneWidget);
      expect(find.text('Sızıntılarda 3 kez görüldü'), findsOneWidget);
      expect(posta, findsNothing);
    });

    testWidgets('parola yoksa düğme kapalı', (tester) async {
      logins = FakeLoginRepository(
        items: [
          FakeLoginRepository.item(const LoginContent(name: 'Boş'), id: 1),
        ],
      );
      await openReport(tester);

      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('İnternetten denetle'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Sızıntı kontrolü'), findsOneWidget);
    });
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/app_shell.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/keykey_logo.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/core/platform/document_files.dart';
import 'package:keykey/core/vault/biometric_bridge.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/lock_clock.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/lock_screen.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/sync/application/sync_controller.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/presentation/card_detail_screen.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_sync_service.dart';
import '../../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;

  const lockedTitle = 'KeyKey kilitli';
  const vaultText = 'Henüz parola yok. Eklemek için alttaki + düğmesine dokun.';
  const otpEmptyText =
      'Henüz 2FA hesabı yok. İlkini kurmak için alttaki + düğmesine dokun.';

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
  });

  Future<void> pumpLocked(WidgetTester tester) =>
      pumpKeyKey(tester, status: VaultLocked(service.header), service: service);

  Future<void> enterPassword(WidgetTester tester, String password) async {
    await tester.enterText(find.byType(TextField), password);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Aç'));
    await tester.pumpAndSettle();
  }

  group('yönlendirme kuralı', () {
    test('kasa açık değilken kasa ekranlarına gidilemiyor', () {
      final header = FakeVaultService(sodium).header;
      for (final location in [
        AppRoutes.vault,
        AppRoutes.authenticator,
        AppRoutes.settings,
        AppRoutes.changePassword,
      ]) {
        expect(vaultRedirect(VaultLocked(header), location), AppRoutes.lock);
        expect(vaultRedirect(const VaultNotSetUp(), location), AppRoutes.intro);
        expect(
          vaultRedirect(const VaultUnavailable(), location),
          AppRoutes.unavailable,
        );
      }
    });

    test('kilitliyken yalnızca kilit ve kurtarma açık', () {
      final header = FakeVaultService(sodium).header;
      expect(vaultRedirect(VaultLocked(header), AppRoutes.lock), isNull);
      expect(vaultRedirect(VaultLocked(header), AppRoutes.recovery), isNull);
    });

    test('kurtarmada yeni parola dışında bir yere gidilemiyor', () {
      final session = FakeVaultService(sodium).newSession();
      addTearDown(session.dispose);
      final status = VaultRecovering(session);
      expect(vaultRedirect(status, AppRoutes.vault), AppRoutes.newPassword);
      expect(vaultRedirect(status, AppRoutes.newPassword), isNull);
    });

    test('kilit açılınca kaldığı yere dönülüyor', () {
      final session = FakeVaultService(sodium).newSession();
      addTearDown(session.dispose);
      final status = VaultOpen(session);
      expect(
        vaultRedirect(status, AppRoutes.lock, resume: AppRoutes.authenticator),
        AppRoutes.authenticator,
      );
      expect(resumeLocationFor(AppRoutes.vault), AppRoutes.vault);
      expect(resumeLocationFor('/kasa/kayit/0a1b'), '/kasa/kayit/0a1b');
      // Formlar ve tek seferlik ekranlar geri açılmaz, sekmenin köküne dönülür.
      expect(resumeLocationFor('/kasa/kayit/0a1b/duzenle'), AppRoutes.vault);
      expect(resumeLocationFor(AppRoutes.vaultNew), AppRoutes.vault);
      expect(resumeLocationFor(AppRoutes.vaultTrash), AppRoutes.vault);
      // Kart ve notun ayrıntısına kendi sekmesinde dönülür; formlara ve
      // çöp kutusuna dönülmez, sekmenin listesine dönülür.
      expect(resumeLocationFor('/kartlar/0a1b'), '/kartlar/0a1b');
      expect(resumeLocationFor('/kartlar/0a1b/duzenle'), AppRoutes.cards);
      expect(resumeLocationFor(AppRoutes.cardNew), AppRoutes.cards);
      expect(resumeLocationFor(AppRoutes.cardsTrash), AppRoutes.cards);
      expect(resumeLocationFor(AppRoutes.cards), AppRoutes.cards);
      expect(resumeLocationFor('/notlar/0a1b'), '/notlar/0a1b');
      expect(resumeLocationFor(AppRoutes.noteNew), AppRoutes.notes);
      expect(resumeLocationFor(AppRoutes.notesTrash), AppRoutes.notes);
      expect(
        resumeLocationFor(AppRoutes.authenticator),
        AppRoutes.authenticator,
      );
      expect(
        resumeLocationFor(AppRoutes.authenticatorScan),
        AppRoutes.authenticator,
      );
      expect(resumeLocationFor(AppRoutes.settings), AppRoutes.settings);
      expect(resumeLocationFor(AppRoutes.changePassword), AppRoutes.settings);
      expect(resumeLocationFor(AppRoutes.lock), AppRoutes.vault);
    });

    test('kasa açıkken kilit ekranları kasaya dönüyor', () {
      final session = FakeVaultService(sodium).newSession();
      addTearDown(session.dispose);
      final status = VaultOpen(session);
      expect(vaultRedirect(status, AppRoutes.lock), AppRoutes.vault);
      expect(vaultRedirect(status, AppRoutes.setup), AppRoutes.vault);
      expect(vaultRedirect(status, AppRoutes.vault), isNull);
      expect(vaultRedirect(status, AppRoutes.changePassword), isNull);
    });
  });

  group('parolayla açma', () {
    testWidgets('kilitli kasa kilit ekranıyla açılıyor', (tester) async {
      await pumpLocked(tester);

      expect(find.text(lockedTitle), findsOneWidget);
      expect(find.text(vaultText), findsNothing);
    });

    testWidgets('kilit ekranında logo ve tek parola kutusu var', (
      tester,
    ) async {
      await pumpLocked(tester);

      expect(find.bySemanticsLabel('KeyKey'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('doğru parola kasaya götürüyor', (tester) async {
      await pumpLocked(tester);

      await enterPassword(tester, FakeVaultService.correctPassword);

      expect(find.text(vaultText), findsOneWidget);
    });

    testWidgets('yanlış parola içeri almıyor ve kutuyu temizliyor', (
      tester,
    ) async {
      await pumpLocked(tester);

      await enterPassword(tester, 'yanlis-parola-99');

      expect(find.text('Parola yanlış.'), findsOneWidget);
      expect(find.text(vaultText), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, isEmpty);
    });

    testWidgets('yanlış parolada kutu titriyor, sonra yerine dönüyor', (
      tester,
    ) async {
      await pumpLocked(tester);
      final field = find.byType(TextField);
      final start = tester.getTopLeft(field).dx;

      await tester.enterText(field, 'yanlis-parola-99');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Aç'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getTopLeft(field).dx, isNot(start));

      await tester.pumpAndSettle();
      expect(tester.getTopLeft(field).dx, start);
      expect(find.text('Parola yanlış.'), findsOneWidget);
    });

    testWidgets('animasyonlar kapalıyken kutu titremiyor', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpLocked(tester);
      final field = find.byType(TextField);
      final start = tester.getTopLeft(field).dx;

      await tester.enterText(field, 'yanlis-parola-99');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Aç'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getTopLeft(field).dx, start);
    });

    testWidgets('kilit ekranında zemin ve logo yavaşça hareket ediyor', (
      tester,
    ) async {
      await pumpKeyKey(
        tester,
        status: VaultLocked(service.header),
        service: service,
        ambient: true,
        settle: false,
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('animasyonlar kapalıyken kilit ekranı kare istemiyor', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpKeyKey(
        tester,
        status: VaultLocked(service.header),
        service: service,
        ambient: true,
        settle: false,
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(lockedTitle), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('bekleme sürerken düğme kapalı, süre bitince açılıyor', (
      tester,
    ) async {
      service.waitAfterReject = const Duration(seconds: 5);
      await pumpLocked(tester);

      await enterPassword(tester, 'yanlis-parola-99');

      expect(find.textContaining('0:05'), findsOneWidget);
      FilledButton button() =>
          tester.widget(find.widgetWithText(FilledButton, 'Aç'));
      expect(button().onPressed, isNull);

      await tester.pump(const Duration(seconds: 3));
      expect(find.textContaining('0:02'), findsOneWidget);
      expect(button().onPressed, isNull);

      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('0:0'), findsNothing);
      expect(button().onPressed, isNotNull);
    });

    testWidgets('uygulama açılırken süren bekleme gösteriliyor', (
      tester,
    ) async {
      service.currentWait = const Duration(minutes: 15);
      await pumpLocked(tester);

      expect(find.textContaining('15:00'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Aç'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('parola kutusunda klavye öğrenmesi kapalı', (tester) async {
      await pumpLocked(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.enableIMEPersonalizedLearning, isFalse);
      expect(field.obscureText, isTrue);
    });
  });

  group('açılış ve kilit hareketleri', () {
    double logoOpacity(WidgetTester tester) => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byType(KeyKeyLogo),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

    testWidgets('K logosu küçükten ve solarak belirir', (tester) async {
      await pumpKeyKey(
        tester,
        status: VaultLocked(service.header),
        service: service,
        settle: false,
      );
      expect(logoOpacity(tester), lessThan(0.5));
      await tester.pumpAndSettle();
      expect(logoOpacity(tester), 1);
    });

    double breath(WidgetTester tester) => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byKey(LockScreen.breathKey),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .storage[0];

    testWidgets('parmak izi simgesi yavaşça nefes alır', (tester) async {
      service
        ..biometricEnabled = true
        ..biometricSupportValue = BiometricSupport.available;
      await pumpKeyKey(
        tester,
        status: VaultLocked(service.header),
        service: service,
        ambient: true,
        settle: false,
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final first = breath(tester);
      await tester.pump(KkMotion.breath ~/ 2);
      final second = breath(tester);
      expect((first - second).abs(), greaterThan(0.01));
      expect(second, inInclusiveRange(1, 1.06));
    });

    testWidgets('süren hareket kapalıyken parmak izi durur', (tester) async {
      service
        ..biometricEnabled = true
        ..biometricSupportValue = BiometricSupport.available;
      await pumpLocked(tester);
      expect(find.byKey(LockScreen.breathKey), findsNothing);
      expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);
    });

    testWidgets('kilit açılınca kasa hemen hazır, K yukarı kayıp solar', (
      tester,
    ) async {
      await pumpLocked(tester);
      await tester.enterText(
        find.byType(TextField),
        FakeVaultService.correctPassword,
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Aç'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (find.byType(AppShell).evaluate().isNotEmpty) break;
      }
      expect(find.byType(AppShell), findsOneWidget);
      // Logo katmanı dokunuşu engellemez; kasa altta hazır.
      final reveal = find.byKey(AppShell.revealKey);
      expect(reveal, findsOneWidget);
      expect(
        find.ancestor(of: reveal, matching: find.byType(IgnorePointer)),
        findsWidgets,
      );
      // Katman bir vurgu süresinde kalkar; sayfa geçişi birkaç kare
      // geciktirebilir, bu yüzden iki katı beklenir.
      await tester.pump();
      await tester.pump(KkMotion.emphasis * 2);
      await tester.pump();
      expect(find.byKey(AppShell.revealKey), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text(vaultText), findsOneWidget);
    });

    // Proje sahibinin bildirdiği hata (2026-11-16): "+" menüsü açılınca
    // katman listesi değişiyor ve K logosu baştan oynuyordu.
    testWidgets('"+" menüsü açılınca kilit açılışının K logosu dönmez', (
      tester,
    ) async {
      await pumpLocked(tester);
      await tester.enterText(
        find.byType(TextField),
        FakeVaultService.correctPassword,
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Aç'));
      await tester.pumpAndSettle();
      expect(find.byKey(AppShell.revealKey), findsNothing);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(find.byKey(AppShell.revealKey), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byKey(AppShell.revealKey), findsNothing);
    });

    testWidgets('kilitlenince kasa hızla kalkar, hareket oyalanmaz', (
      tester,
    ) async {
      await pumpKeyKey(
        tester,
        status: VaultOpen(service.newSession()),
        service: service,
      );
      expect(find.text(vaultText), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(KkMotion.fast);
      await tester.pump();
      expect(find.text(vaultText), findsNothing);
      expect(find.text(lockedTitle), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group('kurtarma', () {
    Future<void> openRecovery(WidgetTester tester) async {
      await pumpLocked(tester);
      await tester.tap(find.text('Parolamı unuttum'));
      await tester.pumpAndSettle();
    }

    testWidgets('yeni parola zorunlu, sonra kasa açılıyor', (tester) async {
      await openRecovery(tester);

      await tester.enterText(
        find.byType(TextField),
        FakeVaultService.recoveryKey,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Devam et'));
      await tester.pumpAndSettle();

      expect(find.text('YENİ ANA PAROLA'), findsOneWidget);
      expect(find.text(vaultText), findsNothing);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'yepyeni-Ana-Parola-58');
      await tester.enterText(fields.at(1), 'yepyeni-Ana-Parola-58');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Kaydet ve kasayı aç'),
      );
      await tester.pumpAndSettle();

      expect(service.changedPassword, 'yepyeni-Ana-Parola-58');
      expect(find.text(vaultText), findsOneWidget);
    });

    testWidgets('anahtar dosyadan okunabiliyor', (tester) async {
      // K7: anahtarı "Dosyaya kaydet" ile saklayan kullanıcı, tam gereken
      // yerde (parolayı unutunca) 55 karakteri elle yazmak zorundaydı.
      final documents = FakeDocumentFiles()
        ..nextOpen = DocumentOpened(
          Uint8List.fromList(
            utf8.encode('KeyKey kurtarma\n${FakeVaultService.recoveryKey}\n'),
          ),
        );
      await pumpKeyKey(
        tester,
        status: VaultLocked(service.header),
        service: service,
        documents: documents,
      );
      await tester.tap(find.text('Parolamı unuttum'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dosyadan oku'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Devam et'));
      await tester.pumpAndSettle();

      expect(documents.opens, 1);
      expect(find.text('YENİ ANA PAROLA'), findsOneWidget);
    });

    testWidgets('yazım hatası ayrı bir mesaj veriyor', (tester) async {
      await openRecovery(tester);

      await tester.enterText(
        find.byType(TextField),
        FakeVaultService.invalidRecoveryKey,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Devam et'));
      await tester.pumpAndSettle();

      expect(find.textContaining('yazım hatası'), findsOneWidget);
    });

    testWidgets('başka anahtar içeri almıyor', (tester) async {
      await openRecovery(tester);

      await tester.enterText(
        find.byType(TextField),
        FakeVaultService.otherRecoveryKey,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Devam et'));
      await tester.pumpAndSettle();

      expect(find.text('Bu anahtar bu kasaya ait değil.'), findsOneWidget);
      expect(find.text('Yeni ana parola'), findsNothing);
    });

    testWidgets('eksik anahtar uzunluğuyla söyleniyor', (tester) async {
      await openRecovery(tester);

      await tester.enterText(find.byType(TextField), 'aaaaabbbbbccccc');
      await tester.pump();
      expect(find.text('AAAAA-BBBBB-CCCCC'), findsOneWidget);
      expect(find.text('15/55 karakter'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Devam et'));
      await tester.pumpAndSettle();
      expect(
        find.text('Anahtar 55 karakter, sen 15 karakter yazdın.'),
        findsOneWidget,
      );
    });
  });

  group('otomatik kilit', () {
    Future<void> pumpOpen(WidgetTester tester) => pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
    );

    /// Telefondaki gibi aradaki durumlardan tek tek geçer, örneğin önden
    /// gizliye giderken inactive'den de geçer.
    void setLifecycle(WidgetTester tester, AppLifecycleState target) {
      const order = [
        AppLifecycleState.resumed,
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ];
      var index = order.indexOf(
        tester.binding.lifecycleState ?? AppLifecycleState.resumed,
      );
      final end = order.indexOf(target);
      while (index != end) {
        index += index < end ? 1 : -1;
        tester.binding.handleAppLifecycleStateChanged(order[index]);
      }
    }

    testWidgets('arka plana geçince kilitleniyor', (tester) async {
      await pumpOpen(tester);
      expect(find.text(vaultText), findsOneWidget);

      setLifecycle(tester, AppLifecycleState.inactive);
      setLifecycle(tester, AppLifecycleState.hidden);

      // Arka plandayken ekran çizilmez, sonucu dönünce görürüz.
      setLifecycle(tester, AppLifecycleState.inactive);
      setLifecycle(tester, AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text(lockedTitle), findsOneWidget);
      expect(find.text(vaultText), findsNothing);
    });

    testWidgets('kilitten sonra yanlış ve doğru parolayla yeniden açılıyor', (
      tester,
    ) async {
      await pumpOpen(tester);
      setLifecycle(tester, AppLifecycleState.hidden);
      setLifecycle(tester, AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text(lockedTitle), findsOneWidget);

      await enterPassword(tester, 'yanlis-parola-99');
      expect(find.text('Parola yanlış.'), findsOneWidget);

      await enterPassword(tester, FakeVaultService.correctPassword);
      expect(find.text(vaultText), findsOneWidget);

      // İkinci tur da aynı çalışmalı.
      setLifecycle(tester, AppLifecycleState.hidden);
      setLifecycle(tester, AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await enterPassword(tester, FakeVaultService.correctPassword);
      expect(find.text(vaultText), findsOneWidget);
    });

    testWidgets('kilit açılınca kilitlenmeden önceki sekmeye dönülüyor', (
      tester,
    ) async {
      await pumpOpen(tester);
      await tester.tap(find.byIcon(Icons.shield_outlined));
      await tester.pumpAndSettle();
      expect(find.text(otpEmptyText), findsOneWidget);

      setLifecycle(tester, AppLifecycleState.hidden);
      setLifecycle(tester, AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text(lockedTitle), findsOneWidget);

      await enterPassword(tester, FakeVaultService.correctPassword);
      expect(find.text(otpEmptyText), findsOneWidget);
      expect(find.text(vaultText), findsNothing);
    });

    testWidgets('kilit açılınca listeden açılan kayda dönülüyor', (
      tester,
    ) async {
      await pumpKeyKey(
        tester,
        status: VaultOpen(service.newSession()),
        service: service,
        logins: FakeLoginRepository(
          items: [
            FakeLoginRepository.item(
              const LoginContent(
                name: 'Banka',
                username: 'kullanici-banka',
                password: 'p',
              ),
              id: 1,
            ),
          ],
        ),
      );
      // Kayıt listeden açılır (push); adres çubuğundaki temel yer /kasa kalır.
      await tester.tap(find.text('Banka'));
      await tester.pumpAndSettle();
      // Yalnızca ayrıntı ekranında olan düğme.
      final detail = find.byTooltip('Kopyala: Kullanıcı adı');
      expect(detail, findsOneWidget);

      setLifecycle(tester, AppLifecycleState.hidden);
      setLifecycle(tester, AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text(lockedTitle), findsOneWidget);

      await enterPassword(tester, FakeVaultService.correctPassword);
      expect(detail, findsOneWidget);
    });

    testWidgets('kilit açılınca Kartlar sekmesinde açık karta dönülüyor', (
      tester,
    ) async {
      await pumpKeyKey(
        tester,
        status: VaultOpen(service.newSession()),
        service: service,
        cards: FakeRecordRepository<CardContent>(
          items: [
            FakeRecordRepository.item(
              CardContent(name: 'Maaş kartı', number: '4111111111111111'),
              id: 1,
            ),
          ],
        ),
      );
      await tester.tap(find.byIcon(Icons.credit_card_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maaş kartı'));
      await tester.pumpAndSettle();
      expect(find.byType(CardDetailScreen), findsOneWidget);

      setLifecycle(tester, AppLifecycleState.hidden);
      setLifecycle(tester, AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text(lockedTitle), findsOneWidget);

      await enterPassword(tester, FakeVaultService.correctPassword);
      expect(find.byType(CardDetailScreen), findsOneWidget);
      // Kartlar sekmesi seçili; geri gelince kart listesi.
      expect(find.byIcon(Icons.credit_card), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('1 kartta ara'), findsOneWidget);
    });

    group("KeyKey'in açtığı dosya seçicisi", () {
      ExternalActivityGate gate(WidgetTester tester) =>
          ProviderScope.containerOf(tester.element(find.text(vaultText)))
              .read(externalActivityGateProvider.notifier);

      testWidgets('açıkken arka plan kilitlemiyor, kapanınca yine kilitliyor', (
        tester,
      ) async {
        await pumpOpen(tester);
        final picker = Completer<String>();
        final result = gate(tester).run(() => picker.future);

        setLifecycle(tester, AppLifecycleState.paused);
        await tester.pump(const Duration(minutes: 2));
        picker.complete('dosya');
        setLifecycle(tester, AppLifecycleState.resumed);
        await tester.pumpAndSettle();
        expect(await result, 'dosya');
        expect(find.text(vaultText), findsOneWidget);

        // Seçici kapandıktan sonra arka plan yine kilitliyor.
        setLifecycle(tester, AppLifecycleState.hidden);
        setLifecycle(tester, AppLifecycleState.resumed);
        await tester.pumpAndSettle();
        expect(find.text(lockedTitle), findsOneWidget);
      });

      testWidgets('3 dakikayı geçerse kasa kilitleniyor', (tester) async {
        await pumpOpen(tester);
        final picker = Completer<String>();
        final result = gate(tester).run(() => picker.future);

        setLifecycle(tester, AppLifecycleState.paused);
        await tester.pump(const Duration(minutes: 3, seconds: 1));
        picker.complete('dosya');
        await result;
        setLifecycle(tester, AppLifecycleState.resumed);
        await tester.pumpAndSettle();
        expect(find.text(lockedTitle), findsOneWidget);
      });

      testWidgets('işlem hata verse de erteleme bitiyor', (tester) async {
        await pumpOpen(tester);
        final failing = gate(tester)
            .run<void>(() => Future.error(StateError('seçici açılmadı')));
        await expectLater(failing, throwsStateError);

        setLifecycle(tester, AppLifecycleState.hidden);
        setLifecycle(tester, AppLifecycleState.resumed);
        await tester.pumpAndSettle();
        expect(find.text(lockedTitle), findsOneWidget);
      });
    });

    testWidgets('sistem penceresi kilitlemiyor', (tester) async {
      await pumpOpen(tester);

      setLifecycle(tester, AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(find.text(vaultText), findsOneWidget);

      setLifecycle(tester, AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text(vaultText), findsOneWidget);
    });

    testWidgets('5 dakika dokunulmazsa kilitleniyor', (tester) async {
      await pumpOpen(tester);

      await tester.pump(const Duration(minutes: 4, seconds: 59));
      expect(find.text(vaultText), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text(lockedTitle), findsOneWidget);
    });

    testWidgets('dokunmak süreyi yeniden başlatıyor', (tester) async {
      await pumpOpen(tester);

      await tester.pump(const Duration(minutes: 4));
      await tester.tapAt(const Offset(200, 200));
      await tester.pump(const Duration(minutes: 4));
      await tester.pump();
      expect(find.text(vaultText), findsOneWidget);

      await tester.pump(const Duration(minutes: 1, seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text(lockedTitle), findsOneWidget);
    });

    testWidgets('klavyeyle kesmek de süreyi yeniden başlatıyor', (
      tester,
    ) async {
      await pumpOpen(tester);
      final search = find.widgetWithText(TextField, 'Ara');
      await tester.enterText(search, 'posta');
      await tester.pump(const Duration(minutes: 4));
      tester.widget<TextField>(search).controller!.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(const Duration(minutes: 4));
      await tester.pump();

      expect(find.text(lockedTitle), findsNothing);
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    });

    testWidgets('kilitten sonra kasa ekranına doğrudan dönülemiyor', (
      tester,
    ) async {
      await pumpOpen(tester);
      setLifecycle(tester, AppLifecycleState.hidden);
      setLifecycle(tester, AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      GoRouter.of(tester.element(find.byType(LockScreen))).go(AppRoutes.vault);
      await tester.pumpAndSettle();
      expect(find.text(lockedTitle), findsOneWidget);
      expect(find.text(vaultText), findsNothing);

      GoRouter.of(tester.element(find.byType(LockScreen)))
          .go(AppRoutes.settings);
      await tester.pumpAndSettle();
      expect(find.text(lockedTitle), findsOneWidget);

      setLifecycle(tester, AppLifecycleState.resumed);
    });

    group('arka planda bekleme süresi', () {
      late FakeLockClock clock;

      setUp(() => clock = FakeLockClock());

      Future<FakeLoginRepository> pumpWithDelay(
        WidgetTester tester,
        BackgroundLock lock,
      ) async {
        final logins = FakeLoginRepository();
        await pumpKeyKey(
          tester,
          status: VaultOpen(service.newSession()),
          service: service,
          logins: logins,
          settings: FakeSettingsRepository(
            AppSettings.defaults.copyWith(backgroundLock: lock),
          ),
          extraOverrides: [lockClockProvider.overrideWithValue(clock)],
        );
        return logins;
      }

      Future<void> resume(WidgetTester tester) async {
        setLifecycle(tester, AppLifecycleState.resumed);
        await tester.pumpAndSettle();
      }

      testWidgets('Hemen ayarında arka plana geçer geçmez kilitleniyor', (
        tester,
      ) async {
        await pumpWithDelay(tester, BackgroundLock.immediately);
        setLifecycle(tester, AppLifecycleState.hidden);
        await resume(tester);
        expect(find.text(lockedTitle), findsOneWidget);
      });

      testWidgets('süre dolmadan dönülünce kasa açık kalıyor', (tester) async {
        await pumpWithDelay(tester, BackgroundLock.seconds30);
        setLifecycle(tester, AppLifecycleState.paused);
        clock.advance(const Duration(seconds: 10));
        await tester.pump(const Duration(seconds: 10));
        await resume(tester);
        expect(find.text(vaultText), findsOneWidget);
        expect(find.text(lockedTitle), findsNothing);
      });

      testWidgets('kasa açık kalan dönüşte bir dakika sonra eşitleniyor', (
        tester,
      ) async {
        final sync = FakeSyncService();
        var syncNow = DateTime.utc(2026, 11, 20, 12);
        await pumpKeyKey(
          tester,
          status: VaultOpen(service.newSession()),
          service: service,
          settings: FakeSettingsRepository(
            AppSettings.defaults
                .copyWith(backgroundLock: BackgroundLock.seconds30)
                .withSync(
                  SyncSettings(
                    folder: Uri.parse('https://bulut.example.com/dav/'),
                    username: 'ayse',
                    appPassword: 'p',
                  ),
                ),
          ),
          extraOverrides: [
            lockClockProvider.overrideWithValue(clock),
            syncServiceProvider.overrideWithValue(sync),
            syncClockProvider.overrideWithValue(() => syncNow),
          ],
        );
        await tester.pumpAndSettle();
        expect(sync.calls, 1);

        setLifecycle(tester, AppLifecycleState.paused);
        clock.advance(const Duration(seconds: 10));
        syncNow = syncNow.add(const Duration(seconds: 10));
        await resume(tester);
        expect(sync.calls, 1);

        setLifecycle(tester, AppLifecycleState.paused);
        clock.advance(const Duration(seconds: 20));
        syncNow = syncNow.add(const Duration(minutes: 1));
        await resume(tester);
        expect(find.text(vaultText), findsOneWidget);
        expect(sync.calls, 2);
      });

      testWidgets('süre dolduysa dönüşte kilitli (uygulama donmuştu)', (
        tester,
      ) async {
        await pumpWithDelay(tester, BackgroundLock.seconds30);
        setLifecycle(tester, AppLifecycleState.paused);
        // Zamanlayıcı çalışmadı: yalnızca saatler ilerledi.
        clock.advance(const Duration(seconds: 31));
        await resume(tester);
        expect(find.text(lockedTitle), findsOneWidget);
      });

      testWidgets('telefon uyuduysa duvar saatiyle kilitli', (tester) async {
        await pumpWithDelay(tester, BackgroundLock.minute1);
        setLifecycle(tester, AppLifecycleState.paused);
        clock.advance(
          const Duration(seconds: 5),
          wall: const Duration(minutes: 2),
        );
        await resume(tester);
        expect(find.text(lockedTitle), findsOneWidget);
      });

      testWidgets('saat geri alındıysa kilitli', (tester) async {
        await pumpWithDelay(tester, BackgroundLock.minute1);
        setLifecycle(tester, AppLifecycleState.paused);
        clock.advance(
          const Duration(seconds: 5),
          wall: const Duration(hours: -1),
        );
        await resume(tester);
        expect(find.text(lockedTitle), findsOneWidget);
      });

      testWidgets('arka planda süre dolunca zamanlayıcı kilitliyor', (
        tester,
      ) async {
        final session = service.newSession();
        await pumpKeyKey(
          tester,
          status: VaultOpen(session),
          service: service,
          settings: FakeSettingsRepository(
            AppSettings.defaults.copyWith(
              backgroundLock: BackgroundLock.seconds30,
            ),
          ),
          extraOverrides: [lockClockProvider.overrideWithValue(clock)],
        );
        setLifecycle(tester, AppLifecycleState.paused);
        await tester.pump(const Duration(seconds: 29));
        expect(session.isDisposed, isFalse);
        await tester.pump(const Duration(seconds: 2));
        expect(session.isDisposed, isTrue);
        await resume(tester);
        expect(find.text(lockedTitle), findsOneWidget);
      });

      testWidgets('dokunmama kilidi arka planda da sayıyor', (tester) async {
        await pumpWithDelay(tester, BackgroundLock.minute1);
        clock.advance(const Duration(minutes: 4, seconds: 40));
        await tester.pump(const Duration(minutes: 4, seconds: 40));
        expect(find.text(vaultText), findsOneWidget);

        setLifecycle(tester, AppLifecycleState.paused);
        // Bekleme süresinin yarısı; ama son dokunuştan beri 5 dakikayı geçti.
        clock.advance(const Duration(seconds: 30));
        await resume(tester);
        expect(find.text(lockedTitle), findsOneWidget);
      });

      testWidgets('arka plandan dönüş son dokunma sayılmıyor', (tester) async {
        await pumpWithDelay(tester, BackgroundLock.seconds30);
        setLifecycle(tester, AppLifecycleState.paused);
        clock.advance(const Duration(seconds: 10));
        await tester.pump(const Duration(seconds: 10));
        await resume(tester);
        expect(find.text(vaultText), findsOneWidget);

        // Dönüşten sonra 4 dk 51 sn dokunulmadı: toplam 5 dakika 1 saniye.
        await tester.pump(const Duration(minutes: 4, seconds: 51));
        await tester.pumpAndSettle();
        expect(find.text(lockedTitle), findsOneWidget);
      });

      testWidgets('dönüşte parolalar yeniden okunuyor', (tester) async {
        final logins = await pumpWithDelay(tester, BackgroundLock.seconds30);
        expect(find.text(vaultText), findsOneWidget);

        setLifecycle(tester, AppLifecycleState.paused);
        // Bu arada doldurma ekranı bir kayıt ekledi.
        logins.items.add(
          FakeLoginRepository.item(
            const LoginContent(
              name: 'Doldurmadan gelen',
              username: 'u',
              password: 'p',
            ),
          ),
        );
        clock.advance(const Duration(seconds: 5));
        await tester.pump(const Duration(seconds: 5));
        await resume(tester);

        expect(find.text('Doldurmadan gelen'), findsOneWidget);
      });

      Future<FakeLoginRepository> editAcrossBackground(
        WidgetTester tester, {
        required Future<void> Function() edit,
      }) async {
        final logins = FakeLoginRepository(
          items: [
            FakeLoginRepository.item(
              const LoginContent(
                name: 'Posta',
                username: 'ali',
                password: 'eski',
              ),
              id: 1,
            ),
          ],
        );
        await pumpKeyKey(
          tester,
          status: VaultOpen(service.newSession()),
          service: service,
          logins: logins,
          settings: FakeSettingsRepository(
            AppSettings.defaults.copyWith(
              backgroundLock: BackgroundLock.seconds30,
            ),
          ),
          extraOverrides: [lockClockProvider.overrideWithValue(clock)],
        );
        final idHex = '${'00' * 15}01';
        GoRouter.of(tester.element(find.byType(Scaffold).first))
            .go(AppRoutes.vaultItemEdit(idHex));
        await tester.pumpAndSettle();
        await edit();

        setLifecycle(tester, AppLifecycleState.paused);
        // Bu arada doldurma ekranı kaydın parolasını güncelledi.
        logins.items[0] = FakeLoginRepository.item(
          logins.items[0].content.copyWith(password: 'yeni'),
          id: 1,
        );
        clock.advance(const Duration(seconds: 5));
        await tester.pump(const Duration(seconds: 5));
        await resume(tester);

        await tester.tap(find.text('Kaydet'));
        await tester.pumpAndSettle();
        return logins;
      }

      testWidgets('açık kalan form doldurmanın kaydettiği parolayı ezmiyor', (
        tester,
      ) async {
        final logins = await editAcrossBackground(
          tester,
          edit: () => tester.enterText(
            find.widgetWithText(TextField, 'Ad'),
            'Posta kutusu',
          ),
        );

        final saved = logins.items.single.content;
        expect(saved.name, 'Posta kutusu');
        expect(saved.password, 'yeni');
      });

      testWidgets('formda değişen parola kazanıyor, doldurmanınki geçmişte', (
        tester,
      ) async {
        final logins = await editAcrossBackground(
          tester,
          edit: () => tester.enterText(
            find.widgetWithText(TextField, 'Parola'),
            'benim',
          ),
        );

        final saved = logins.items.single.content;
        expect(saved.password, 'benim');
        expect(saved.passwordHistory.first.password, 'yeni');
      });

      testWidgets('dosya seçicisi açıkken bekleme süresi devreye girmiyor', (
        tester,
      ) async {
        await pumpWithDelay(tester, BackgroundLock.seconds30);
        final picker = Completer<String>();
        final result = ProviderScope.containerOf(
          tester.element(find.text(vaultText)),
        ).read(externalActivityGateProvider.notifier).run(() => picker.future);

        setLifecycle(tester, AppLifecycleState.paused);
        clock.advance(const Duration(minutes: 2));
        await tester.pump(const Duration(minutes: 2));
        picker.complete('dosya');
        await resume(tester);
        expect(await result, 'dosya');
        // Seçici kendi 3 dakikalık sınırını uygular; dönüşte açık.
        expect(find.text(vaultText), findsOneWidget);
      });

      testWidgets('dosya seçicisi açıkken telefon uyuduysa dönüşte kilitli', (
        tester,
      ) async {
        // Telefon uyurken Dart zamanlayıcıları ilerlemez; seçicinin 3
        // dakikalık sınırı dönüşte iki saatle denetlenmeli.
        await pumpWithDelay(tester, BackgroundLock.seconds30);
        final picker = Completer<String>();
        final result = ProviderScope.containerOf(
          tester.element(find.text(vaultText)),
        ).read(externalActivityGateProvider.notifier).run(() => picker.future);

        setLifecycle(tester, AppLifecycleState.paused);
        clock.advance(const Duration(hours: 4));
        picker.complete('dosya');
        await resume(tester);
        await result;
        expect(find.text(lockedTitle), findsOneWidget);
      });
    });

    testWidgets('kilit anahtarları siliyor', (tester) async {
      final session = service.newSession();
      await pumpKeyKey(tester, status: VaultOpen(session), service: service);

      setLifecycle(tester, AppLifecycleState.paused);
      await tester.pumpAndSettle();

      expect(session.isDisposed, isTrue);
      setLifecycle(tester, AppLifecycleState.resumed);
    });
  });

  group('parmak izi', () {
    void enableFake() {
      service
        ..biometricSupportValue = BiometricSupport.available
        ..biometricEnabled = true;
    }

    testWidgets('kapalıysa düğme yok ve pencere açılmıyor', (tester) async {
      await pumpLocked(tester);

      expect(find.byTooltip('Parmak izi kullan'), findsNothing);
      expect(service.biometricPrompts, 0);
    });

    testWidgets('açıksa pencere bir kez kendiliğinden açılıyor', (
      tester,
    ) async {
      enableFake();
      await pumpLocked(tester);

      expect(find.byTooltip('Parmak izi kullan'), findsOneWidget);
      expect(service.biometricPrompts, 1);
      expect(find.text(lockedTitle), findsOneWidget);
    });

    testWidgets('başarılı olunca kasa açılıyor', (tester) async {
      enableFake();
      service.nextBiometric = const BiometricSuccess(null);
      await pumpLocked(tester);

      expect(find.text(vaultText), findsOneWidget);
    });

    testWidgets('vazgeçince ana parolayla devam ediliyor', (tester) async {
      enableFake();
      await pumpLocked(tester);

      expect(find.text(lockedTitle), findsOneWidget);
      await enterPassword(tester, FakeVaultService.correctPassword);
      expect(find.text(vaultText), findsOneWidget);
    });

    testWidgets('düğme pencereyi yeniden açıyor', (tester) async {
      enableFake();
      await pumpLocked(tester);

      service.nextBiometric = const BiometricSuccess(null);
      await tester.tap(find.byTooltip('Parmak izi kullan'));
      await tester.pumpAndSettle();

      expect(service.biometricPrompts, 2);
      expect(find.text(vaultText), findsOneWidget);
    });

    testWidgets('anahtar geçersizse düğme gidiyor ve açıklama çıkıyor', (
      tester,
    ) async {
      enableFake();
      service.nextBiometric = const BiometricInvalidated();
      await pumpLocked(tester);

      expect(find.textContaining('parmak izleri değişti'), findsOneWidget);
      expect(find.byTooltip('Parmak izi kullan'), findsNothing);
      expect(find.text(vaultText), findsNothing);
    });

    testWidgets('Android kilitlediyse açıklama çıkıyor', (tester) async {
      enableFake();
      service.nextBiometric = const BiometricLockedOut();
      await pumpLocked(tester);

      expect(find.textContaining('Çok fazla deneme'), findsOneWidget);
    });

    testWidgets('açılmazsa ana parola öneriliyor', (tester) async {
      enableFake();
      service.nextBiometric = const BiometricFailed();
      await pumpLocked(tester);

      expect(find.textContaining('Parmak iziyle açılamadı'), findsOneWidget);
      expect(find.text(vaultText), findsNothing);
    });
  });

  group('kurtarılamayan durum', () {
    testWidgets('okunamayan dosyada hata ekranı çıkıyor', (tester) async {
      await pumpKeyKey(
        tester,
        status: const VaultUnavailable(),
        service: service,
      );

      expect(find.text('Kasa okunamadı'), findsOneWidget);
      // Güncelleme dışında, dosya bozulduysa yedekten dönüş yolu da anlatılır.
      expect(find.textContaining('depolama alanını temizle'), findsOneWidget);
      expect(find.textContaining('Yedekten geri yükle'), findsOneWidget);
    });
  });
}

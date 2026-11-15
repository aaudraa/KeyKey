import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/app_shell.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/keykey_logo.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/core/vault/biometric_bridge.dart';
import 'package:keykey/features/lock/application/external_activity_gate.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/lock_screen.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;

  const lockedTitle = 'KeyKey kilitli';
  const vaultText =
      'Henüz parola yok. İlkini kaydetmek için alttaki + düğmesine dokun.';

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
        expect(vaultRedirect(const VaultNotSetUp(), location), AppRoutes.setup);
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

      expect(find.text('Yeni ana parola'), findsOneWidget);
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

      expect(find.text('Bu, bu kasanın anahtarı değil.'), findsOneWidget);
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
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/features/authenticator/application/otp_import.dart';
import 'package:keykey/features/authenticator/data/import/import_result.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/backup/data/import/login_import.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:sodium/sodium_sumo.dart';

import '../support/fake_vault_service.dart';

/// Ana ekranları Flutter'ın erişilebilirlik kurallarıyla denetler: dokunma
/// hedefleri adlı ve yeterince büyük, metin kontrastı WCAG AA. Her ekran açık
/// ve koyu temada, normal ve %200 yazı boyutunda açılır; %200'de taşma
/// olursa Flutter hata verir ve test düşer.
void main() {
  late SodiumSumo sodium;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  final login = FakeLoginRepository.item(
    const LoginContent(
      name: 'Posta',
      username: 'ali@example.com',
      password: 'Ortak-Uzun-Parola-8xQ!',
      urls: ['https://mail.example.com'],
      notes: 'Not',
    ),
    id: 1,
  );
  final otp = FakeOtpRepository.item(
    OtpContent(
      parameters: OtpParameters.totp(secret: utf8.encode('anahtar-1234567')),
      issuer: 'GitHub',
      account: 'ali@example.com',
    ),
    id: 1,
  );

  // Kasa açıkken gidilen ekranlar.
  final openRoutes = <String, (String, Object?)>{
    'kasa': (AppRoutes.vault, null),
    'yeni kayıt': (AppRoutes.vaultNew, null),
    'kayıt ayrıntısı': (AppRoutes.vaultItem(loginIdHex(login.id)), null),
    'kayıt düzenleme': (AppRoutes.vaultItemEdit(loginIdHex(login.id)), null),
    'parola raporu': (AppRoutes.vaultReport, null),
    'çöp kutusu': (AppRoutes.vaultTrash, null),
    '2FA': (AppRoutes.authenticator, null),
    'yeni 2FA': (AppRoutes.authenticatorNew, null),
    '2FA düzenleme': (
      AppRoutes.authenticatorItemEdit(loginIdHex(otp.id)),
      null,
    ),
    '2FA içe aktarma': (
      AppRoutes.authenticatorImport,
      ReadyImport(
        ImportBatch(
          accounts: [
            ImportedAccount(
              parameters: OtpParameters.totp(
                secret: utf8.encode('anahtar-1234567'),
              ),
              issuer: 'GitLab',
              account: 'ali@example.com',
            ),
          ],
          unsupported: 1,
        ),
      ),
    ),
    '2FA çöp kutusu': (AppRoutes.authenticatorTrash, null),
    'ayarlar': (AppRoutes.settings, null),
    'parola değiştirme': (AppRoutes.changePassword, null),
    'parola içe aktarma': (
      AppRoutes.loginImport,
      const LoginExport(
        source: LoginExportSource.bitwardenJson,
        logins: [
          ImportedLogin(
            name: 'Forum',
            username: 'ali',
            password: 'deneme-Forum-3',
            urls: ['https://forum.example.com'],
          ),
        ],
        skipped: 1,
      ),
    ),
  };

  const variants = {
    'açık': (Brightness.light, 1.0),
    'koyu': (Brightness.dark, 1.0),
    'açık, %200 yazı': (Brightness.light, 2.0),
    'koyu, %200 yazı': (Brightness.dark, 2.0),
  };

  /// Geri sayım her kare yeni kare istediği için pumpAndSettle bitmeyebilir.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> checkGuidelines(
    WidgetTester tester, {
    required String location,
    required double scale,
  }) async {
    final context = tester.element(find.byType(Scaffold).last);
    // Denetimin gerçekten istenen ekranda ve yazı boyutunda yapıldığı.
    expect(GoRouter.of(context).state.matchedLocation, location);
    expect(MediaQuery.textScalerOf(context).scale(10), 10 * scale);
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  }

  for (final MapEntry(key: variantName, value: (brightness, scale))
      in variants.entries) {
    group(variantName, () {
      Future<FakeVaultService> prepare(WidgetTester tester) async {
        tester.platformDispatcher
          ..platformBrightnessTestValue = brightness
          ..textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        // Telefon boyutu: 1080x2400, 2.625 yoğunluk.
        tester.view
          ..physicalSize = const Size(1080, 2400)
          ..devicePixelRatio = 2.625;
        addTearDown(tester.view.reset);
        return FakeVaultService(sodium);
      }

      for (final MapEntry(key: name, value: (route, extra))
          in openRoutes.entries) {
        testWidgets(name, (tester) async {
          final service = await prepare(tester);
          await pumpKeyKey(
            tester,
            status: VaultOpen(service.newSession()),
            service: service,
            logins: FakeLoginRepository(items: [login]),
            otps: FakeOtpRepository(items: [otp]),
            clock: () =>
                DateTime.fromMillisecondsSinceEpoch(30000, isUtc: true),
          );
          GoRouter.of(tester.element(find.byType(Scaffold).first))
              .go(route, extra: extra);
          await settle(tester);
          await checkGuidelines(tester, location: route, scale: scale);
        });
      }

      Future<void> openAt(
        WidgetTester tester,
        String route, {
        AppSettings settings = AppSettings.defaults,
      }) async {
        final service = await prepare(tester);
        await pumpKeyKey(
          tester,
          status: VaultOpen(service.newSession()),
          service: service,
          logins: FakeLoginRepository(items: [login]),
          otps: FakeOtpRepository(items: [otp]),
          settings: FakeSettingsRepository(settings),
          clock: () => DateTime.fromMillisecondsSinceEpoch(30000, isUtc: true),
        );
        GoRouter.of(tester.element(find.byType(Scaffold).first)).go(route);
        await settle(tester);
      }

      testWidgets('parola üretici', (tester) async {
        await openAt(tester, AppRoutes.vaultNew);
        await tester.tap(find.byTooltip('Parola üret'));
        await settle(tester);
        expect(find.text('Parola cümlesi'), findsOneWidget);
        await checkGuidelines(
          tester,
          location: AppRoutes.vaultNew,
          scale: scale,
        );
      });

      testWidgets('2FA kodları gizliyken', (tester) async {
        await openAt(
          tester,
          AppRoutes.authenticator,
          settings: AppSettings.requireAuth,
        );
        expect(find.text('Kodları göster'), findsOneWidget);
        await checkGuidelines(
          tester,
          location: AppRoutes.authenticator,
          scale: scale,
        );
      });

      testWidgets('kilit ekranı', (tester) async {
        final service = await prepare(tester);
        await pumpKeyKey(
          tester,
          status: VaultLocked(service.header),
          service: service,
        );
        await checkGuidelines(tester, location: AppRoutes.lock, scale: scale);
      });

      testWidgets('kurtarma', (tester) async {
        final service = await prepare(tester);
        await pumpKeyKey(
          tester,
          status: VaultLocked(service.header),
          service: service,
        );
        GoRouter.of(tester.element(find.byType(Scaffold).first))
            .go(AppRoutes.recovery);
        await tester.pumpAndSettle();
        await checkGuidelines(
          tester,
          location: AppRoutes.recovery,
          scale: scale,
        );
      });

      testWidgets('kurulum', (tester) async {
        final service = await prepare(tester);
        await pumpKeyKey(
          tester,
          status: const VaultNotSetUp(),
          service: service,
        );
        await checkGuidelines(tester, location: AppRoutes.setup, scale: scale);
      });

      testWidgets('yedekten kurulum', (tester) async {
        final service = await prepare(tester);
        final restores = FakeRestoreService(sodium);
        final backup = await tester.runAsync(
          () => restores.backupBytes(service.header),
        );
        await pumpKeyKey(
          tester,
          status: const VaultNotSetUp(),
          service: service,
          restores: restores,
        );
        GoRouter.of(tester.element(find.byType(Scaffold).first)).go(
          AppRoutes.restore,
          extra: restores.parse(Uint8List.fromList(backup!)),
        );
        await tester.pumpAndSettle();
        await checkGuidelines(
          tester,
          location: AppRoutes.restore,
          scale: scale,
        );
      });
    });
  }

  group('ekran okuyucu', () {
    Future<void> openAt(WidgetTester tester, String route) async {
      final service = FakeVaultService(sodium);
      await pumpKeyKey(
        tester,
        status: VaultOpen(service.newSession()),
        service: service,
        logins: FakeLoginRepository(items: [login]),
        otps: FakeOtpRepository(items: [otp]),
        clock: () => DateTime.fromMillisecondsSinceEpoch(30000, isUtc: true),
      );
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go(route);
      await settle(tester);
    }

    testWidgets('2FA kodu rakam rakam okunuyor, geri sayım ilerleme çubuğu '
        'değil', (tester) async {
      final handle = tester.ensureSemantics();
      await openAt(tester, AppRoutes.authenticator);

      final node = tester.getSemantics(find.textContaining('GitHub'));
      expect(
        node.label,
        matches(
          RegExp(r'^GitHub\nali@example.com\n(\d ){5}\d\n30 saniye kaldı$'),
        ),
      );
      expect(node.role, isNot(SemanticsRole.progressBar));
      expect(node.value, isEmpty);
      handle.dispose();
    });

    testWidgets('gizli parola okunmuyor, gösterilince okunuyor', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openAt(tester, AppRoutes.vaultItem(loginIdHex(login.id)));

      expect(find.bySemanticsLabel('Parola\nGizli'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('•')), findsNothing);

      await tester.tap(find.byTooltip('Göster'));
      await tester.pump();
      expect(
        find.bySemanticsLabel('Parola\nOrtak-Uzun-Parola-8xQ!'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}

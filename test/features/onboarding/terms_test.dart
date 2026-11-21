import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/lock_screen.dart';
import 'package:keykey/features/onboarding/application/terms_controller.dart';
import 'package:keykey/features/onboarding/data/terms_acceptance.dart';
import 'package:keykey/features/onboarding/presentation/onboarding_screen.dart';
import 'package:keykey/features/onboarding/presentation/terms_screen.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

class _FailingStore implements TermsAcceptanceStore {
  @override
  Future<void> write(int version) async =>
      throw const FormatException('yazılamadı');
}

class _RecordingStore implements TermsAcceptanceStore {
  final written = <int>[];

  @override
  Future<void> write(int version) async => written.add(version);
}

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
  });

  group('kabulün saklanması', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('keykey-kosullar');
    });

    tearDown(() async {
      await dir.delete(recursive: true);
    });

    test('dosya yoksa kabul edilmemiş', () async {
      final store = FileTermsAcceptanceStore(File('${dir.path}/terms'));
      expect(await store.read(), 0);
    });

    test('kabul edilen sürüm yazılır ve okunur', () async {
      final store = FileTermsAcceptanceStore(File('${dir.path}/terms'));
      await store.write(currentTermsVersion);
      expect(await store.read(), currentTermsVersion);
      expect(
        File('${dir.path}/terms').readAsStringSync(),
        '$currentTermsVersion',
      );
    });

    test('2. sürümü kabul etmiş kullanıcıya yeniden sorulur', () async {
      // Sürüm 3: senkron açılırsa şifreli kopya kullanıcının sunucusuna gider.
      final file = File('${dir.path}/terms')..writeAsStringSync('2');
      final store = FileTermsAcceptanceStore(file);
      expect(await store.accepted(), isFalse);
      await store.write(currentTermsVersion);
      expect(await store.accepted(), isTrue);
      expect(currentTermsVersion, 3);
    });

    test('bozuk içerik kabul edilmemiş sayılır', () async {
      File('${dir.path}/terms').writeAsStringSync('evet');
      final store = FileTermsAcceptanceStore(File('${dir.path}/terms'));
      expect(await store.read(), 0);
    });
  });

  group('yönlendirme', () {
    test('kabul edilmeden kasa kurulmaz, açılmaz; tanıtım serbest', () {
      final header = FakeVaultService(sodium).header;
      final session = FakeVaultService(sodium).newSession();
      addTearDown(session.dispose);
      String? go(VaultStatus status, String location) =>
          vaultRedirect(status, location, termsAccepted: false);

      expect(go(const VaultNotSetUp(), AppRoutes.intro), isNull);
      // Açılış rotası (kasa) kurulmamış kasada tanıtıma gider.
      expect(go(const VaultNotSetUp(), AppRoutes.vault), AppRoutes.intro);
      expect(go(const VaultNotSetUp(), AppRoutes.terms), isNull);
      expect(go(const VaultNotSetUp(), AppRoutes.setup), AppRoutes.terms);
      expect(go(const VaultNotSetUp(), AppRoutes.restore), AppRoutes.terms);
      expect(go(const VaultNotSetUp(), AppRoutes.syncSetup), AppRoutes.terms);
      expect(go(VaultLocked(header), AppRoutes.lock), AppRoutes.terms);
      expect(go(VaultLocked(header), AppRoutes.terms), isNull);
      expect(go(VaultOpen(session), AppRoutes.vault), AppRoutes.terms);
      expect(
        go(VaultRecovering(session), AppRoutes.newPassword),
        AppRoutes.terms,
      );
      expect(
        go(const VaultUnavailable(), AppRoutes.unavailable),
        AppRoutes.terms,
      );
    });

    test('kabul edilince koşullardan sıradaki yere geçilir', () {
      final header = FakeVaultService(sodium).header;
      final session = FakeVaultService(sodium).newSession();
      addTearDown(session.dispose);

      expect(
        vaultRedirect(const VaultNotSetUp(), AppRoutes.terms),
        AppRoutes.setup,
      );
      expect(
        vaultRedirect(VaultLocked(header), AppRoutes.terms),
        AppRoutes.lock,
      );
      expect(
        vaultRedirect(
          VaultOpen(session),
          AppRoutes.terms,
          resume: AppRoutes.settings,
        ),
        AppRoutes.settings,
      );
    });
  });

  group('ekran', () {
    Future<_RecordingStore> pump(
      WidgetTester tester,
      VaultStatus status, {
      bool accepted = false,
    }) async {
      final store = _RecordingStore();
      await pumpKeyKey(
        tester,
        status: status,
        service: service,
        extraOverrides: [
          initialTermsAcceptedProvider.overrideWithValue(accepted),
          termsAcceptanceStoreProvider.overrideWithValue(store),
        ],
      );
      return store;
    }

    Finder continueButton() =>
        find.widgetWithText(FilledButton, 'Kabul et ve devam et');

    Future<void> accept(WidgetTester tester) async {
      await tester.tap(find.text('Okudum, anladım ve kabul ediyorum.'));
      await tester.pumpAndSettle();
      await tester.tap(continueButton());
      await tester.pumpAndSettle();
    }

    testWidgets('yeni kullanıcı: tanıtımdan sonra koşullar, sonra kurulum', (
      tester,
    ) async {
      final store = await pump(tester, const VaultNotSetUp());
      await tester.tap(find.text('Atla'));
      await tester.pumpAndSettle();

      expect(find.byType(TermsScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      // Kutu işaretlenmeden devam edilemez.
      expect(tester.widget<FilledButton>(continueButton()).onPressed, isNull);

      await accept(tester);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(store.written, [currentTermsVersion]);
    });

    testWidgets('kurulmamış kasada geri tuşu tanıtıma döner', (tester) async {
      await pump(tester, const VaultNotSetUp());
      await tester.tap(find.text('Atla'));
      await tester.pumpAndSettle();
      expect(find.byType(TermsScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TermsScreen), findsNothing);
      expect(find.text('Atla'), findsOneWidget);
    });

    testWidgets('kabul etmiş kullanıcıya bir daha sorulmaz', (tester) async {
      await pump(tester, const VaultNotSetUp(), accepted: true);
      await tester.tap(find.text('Atla'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('kasası olan kullanıcı: önce koşullar, sonra kilit', (
      tester,
    ) async {
      final store = await pump(tester, VaultLocked(service.header));
      expect(find.byType(TermsScreen), findsOneWidget);
      expect(find.byType(LockScreen), findsNothing);

      await accept(tester);
      expect(find.byType(LockScreen), findsOneWidget);
      expect(store.written, [currentTermsVersion]);
    });

    testWidgets('verilerin gizliliğini ve sorumluluğu açıkça anlatır', (
      tester,
    ) async {
      await pump(tester, VaultLocked(service.header));
      // Ekrandaki sırayla: liste yalnızca aşağı kaydırılır.
      for (final text in [
        // Yedek ve dışa aktarma da var: veriler yalnızca telefonda değil.
        'senin seçtiğin yere',
        'senin açtığın özellikler',
        'Argon2id',
        'kimse verilerini kurtaramaz',
        'şifreli yedek',
        // Senkron: kopya kullanıcının sunucusunda, yedek yerine geçmez.
        'senin seçtiğin WebDAV sunucusuna',
        'Senkron yedek yerine geçmez',
        // Pano 30 saniyede silinir ama klavyenin geçmişi tutabilir.
        'pano geçmişi',
        'yapay zekâ',
        'hiçbir garanti olmadan',
      ]) {
        await tester.scrollUntilVisible(find.textContaining(text), 300);
        expect(find.textContaining(text), findsWidgets, reason: text);
      }
    });

    testWidgets("Ayarlar'dan okunur; onay kutusu yok", (tester) async {
      await pump(tester, VaultOpen(service.newSession()), accepted: true);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Kullanım koşulları'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kullanım koşulları'));
      await tester.pumpAndSettle();

      expect(find.byType(TermsScreen), findsOneWidget);
      expect(find.textContaining('senin açtığın özellikler'), findsOneWidget);
      expect(continueButton(), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    });
  });

  test('kabul yazılamasa da bu oturumda geçerli, hata dışarı çıkmaz', () async {
    final container = ProviderContainer(
      overrides: [
        initialTermsAcceptedProvider.overrideWithValue(false),
        termsAcceptanceStoreProvider.overrideWithValue(_FailingStore()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(termsAcceptedProvider.notifier).accept();
    expect(container.read(termsAcceptedProvider), isTrue);
  });

  test('sağlayıcı varsayılanı kabul edilmiş (testler ve bootstrap dışı)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(termsAcceptedProvider), isTrue);
  });
}

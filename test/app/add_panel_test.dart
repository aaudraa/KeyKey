import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/add_panel.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/presentation/login_edit_screen.dart';
import 'package:keykey/features/vault/presentation/trash_screen.dart';
import 'package:sodium/sodium_sumo.dart';

import '../support/fake_vault_service.dart';

/// Kayıtları hiç yüklenmeyen depo: kasa "yükleniyor"da kalır.
class _SlowLogins extends FakeLoginRepository {
  final _never = Completer<LoadedLogins>();

  @override
  Future<LoadedLogins> loadAll() => _never.future;
}

/// Anlam ağacında şu an bulunan bütün etiketler.
List<String> _labels(WidgetTester tester) {
  final labels = <String>[];
  bool visit(SemanticsNode node) {
    if (node.label.isNotEmpty) labels.add(node.label);
    node.visitChildren(visit);
    return true;
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return labels;
}

String _location(WidgetTester tester) {
  final context = tester.element(find.byType(Navigator).first);
  return GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
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

  Future<void> pumpApp(WidgetTester tester) => pumpKeyKey(
    tester,
    status: VaultOpen(service.newSession()),
    service: service,
  );

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byKey(GlassNavBar.addKey));
    await tester.pumpAndSettle();
  }

  Future<void> goTab(WidgetTester tester, IconData icon) async {
    await tester.tap(
      find.descendant(
        of: find.byType(GlassNavBar),
        matching: find.byIcon(icon),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (name, icon) in [
    ('Kasa', null),
    ('2FA', Icons.shield_outlined),
    ('Ayarlar', Icons.settings_outlined),
  ]) {
    testWidgets('$name sekmesinde "+" türü sorar, Parola formu açar', (
      tester,
    ) async {
      await pumpApp(tester);
      if (icon != null) await goTab(tester, icon);
      final handle = tester.ensureSemantics();
      await openPanel(tester);
      expect(find.text('Parola'), findsOneWidget);
      expect(find.text('2FA kodu'), findsOneWidget);
      expect(find.bySemanticsLabel('Kapat'), findsOneWidget);
      handle.dispose();

      await tester.tap(find.text('Parola'));
      await tester.pumpAndSettle();
      expect(_location(tester), AppRoutes.vaultNew);
      expect(find.byType(LoginEditScreen), findsOneWidget);
      expect(find.byType(GlassNavBar), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_location(tester), AppRoutes.vault);
      expect(find.byType(GlassNavBar), findsOneWidget);
      expect(find.text('Kasa'), findsWidgets);
    });
  }

  testWidgets('"2FA kodu" dört yolu gösterir, geri oku döner', (tester) async {
    await pumpApp(tester);
    await openPanel(tester);
    await tester.tap(find.text('2FA kodu'));
    await tester.pumpAndSettle();
    expect(find.text('QR kodu tara'), findsOneWidget);
    expect(find.text('Görseldeki QR kodunu oku'), findsOneWidget);
    expect(find.text('Anahtarı elle gir'), findsOneWidget);
    expect(find.text('Başka uygulamadan aktar'), findsOneWidget);
    expect(find.text('Parola'), findsNothing);

    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    expect(find.text('Parola'), findsOneWidget);
    expect(find.text('QR kodu tara'), findsNothing);
  });

  testWidgets('"Anahtarı elle gir" 2FA formunu, "QR kodu tara" taramayı açar', (
    tester,
  ) async {
    await pumpApp(tester);
    await openPanel(tester);
    await tester.tap(find.text('2FA kodu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anahtarı elle gir'));
    await tester.pumpAndSettle();
    expect(_location(tester), AppRoutes.authenticatorNew);
    expect(find.byType(GlassNavBar), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_location(tester), AppRoutes.authenticator);

    await openPanel(tester);
    await tester.tap(find.text('2FA kodu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('QR kodu tara'));
    await tester.pumpAndSettle();
    expect(_location(tester), AppRoutes.authenticatorScan);
    expect(find.byType(GlassNavBar), findsOneWidget);
  });

  testWidgets('karartma, "Kapat" ve geri tuşu kutuyu kapatır', (tester) async {
    await pumpApp(tester);

    await openPanel(tester);
    await tester.tapAt(const Offset(200, 100));
    await tester.pumpAndSettle();
    expect(find.byType(AddPanel), findsNothing);

    await openPanel(tester);
    await tester.tap(find.byKey(GlassNavBar.addKey));
    await tester.pumpAndSettle();
    expect(find.byType(AddPanel), findsNothing);

    await openPanel(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AddPanel), findsNothing);
    expect(_location(tester), AppRoutes.vault);
  });

  testWidgets('ayrıntı açıkken geri tuşu önce kutuyu kapatır', (tester) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(Navigator).first);
    unawaited(GoRouter.of(context).push(AppRoutes.vaultTrash));
    await tester.pumpAndSettle();
    expect(find.text('Çöp kutusu'), findsWidgets);
    expect(find.byType(TrashScreen), findsOneWidget);

    await openPanel(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AddPanel), findsNothing);
    expect(find.byType(TrashScreen), findsOneWidget);
  });

  testWidgets('"Parola"ya art arda iki dokunuş tek form açar', (tester) async {
    await pumpApp(tester);
    await openPanel(tester);
    await tester.tap(find.text('Parola'));
    await tester.tap(find.text('Parola'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(LoginEditScreen), findsOneWidget);
  });

  testWidgets('kutu açıkken kasa kilitlenirse açılınca kutu kapalı', (
    tester,
  ) async {
    await pumpApp(tester);
    await openPanel(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GlassNavBar)),
    );
    container.read(vaultControllerProvider.notifier).lock();
    await tester.pumpAndSettle();
    expect(find.byType(AddPanel), findsNothing);
    await container
        .read(vaultControllerProvider.notifier)
        .unlockWithPassword(FakeVaultService.correctPassword);
    await tester.pumpAndSettle();
    expect(find.byType(GlassNavBar), findsOneWidget);
    expect(find.byType(AddPanel), findsNothing);
  });

  testWidgets('kutu açıkken liste ekran okuyucudan gizlenir', (tester) async {
    await pumpApp(tester);
    final handle = tester.ensureSemantics();
    expect(_labels(tester).any((l) => l.contains('Henüz parola yok')), isTrue);
    await openPanel(tester);
    final labels = _labels(tester);
    expect(labels.any((l) => l.contains('Henüz parola yok')), isFalse);
    expect(labels.any((l) => l.startsWith('Kasa\n')), isFalse);
    expect(labels.any((l) => l.contains('Parola')), isTrue);
    expect(labels, contains('Kapat'));
    handle.dispose();
  });

  testWidgets('animasyonlar kapalıyken kutu tek karede açılır', (tester) async {
    await pumpApp(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    await tester.tap(find.byKey(GlassNavBar.addKey));
    await tester.pump();
    await tester.pump();
    expect(find.text('Parola'), findsOneWidget);
    final fades = tester.widgetList<FadeTransition>(
      find.descendant(
        of: find.byType(AddPanel),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fades, isNotEmpty);
    for (final fade in fades) {
      expect(fade.opacity.value, 1);
    }
  });

  testWidgets('kayıtlar yüklenmeden "Parola" etkisiz', (tester) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      logins: _SlowLogins(),
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(GlassNavBar.addKey));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Parola'), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LoginEditScreen), findsNothing);
  });

  testWidgets('menü form ekranlarında gizli, diğer ekranlarda görünür', (
    tester,
  ) async {
    await pumpApp(tester);
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));
    for (final (path, visible) in [
      (AppRoutes.vaultNew, false),
      (AppRoutes.authenticatorNew, false),
      (AppRoutes.changePassword, false),
      (AppRoutes.vaultReport, true),
      (AppRoutes.vaultTrash, true),
      (AppRoutes.authenticatorScan, true),
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(
        find.byType(GlassNavBar),
        visible ? findsOneWidget : findsNothing,
        reason: path,
      );
      router.go(AppRoutes.vault);
      await tester.pumpAndSettle();
    }
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/presentation/card_detail_screen.dart';
import 'package:keykey/features/vault/presentation/login_detail_screen.dart';
import 'package:keykey/features/vault/presentation/login_edit_screen.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:sodium/sodium_sumo.dart';

import '../support/fake_vault_service.dart';

/// Android 14+ kenardan geri hareketi (#173, S1). Hareketi kabul eden her
/// sayfa kapanıyordu: sekmelerde ve formun altında görünmeyen sayfalar da.
void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeLoginRepository logins;
  late FakeRecordRepository<CardContent> cards;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
    logins = FakeLoginRepository(
      items: [
        FakeLoginRepository.item(
          const LoginContent(name: 'Posta', password: 'p'),
          id: 1,
        ),
      ],
    );
    cards = FakeRecordRepository<CardContent>(
      items: [FakeRecordRepository.item(CardContent(name: 'Maaş'), id: 1)],
    );
  });

  Future<void> pumpApp(WidgetTester tester) => pumpKeyKey(
    tester,
    status: VaultOpen(service.newSession()),
    service: service,
    logins: logins,
    cards: cards,
  );

  GoRouter router(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Navigator).first));

  Future<void> push(WidgetTester tester, String location) async {
    unawaited(router(tester).push(location));
    await tester.pumpAndSettle();
  }

  Future<void> send(String method, [Object? arguments]) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            SystemChannels.backGesture.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(method, arguments),
            ),
            (_) {},
          );

  Future<void> backGesture(WidgetTester tester) async {
    Map<String, Object?> event(double progress) => {
      'touchOffset': [5.0, 300.0],
      'progress': progress,
      'swipeEdge': 0,
    };
    await send('startBackGesture', event(0));
    await tester.pump();
    await send('updateBackGestureProgress', event(0.5));
    await tester.pump();
    await send('commitBackGesture');
    await tester.pumpAndSettle();
  }

  /// Alt menüdeki gibi sekme değiştirir; sekmenin sayfaları korunur.
  Future<void> switchTab(WidgetTester tester, int index) async {
    tester
        .widget<StatefulNavigationShell>(find.byType(StatefulNavigationShell))
        .goBranch(index);
    await tester.pumpAndSettle();
  }

  String loginId() => loginIdHex(logins.items.first.id);

  testWidgets('düzenlemeden geri hareketi yalnızca formu kapatıyor', (
    tester,
  ) async {
    await pumpApp(tester);
    await push(tester, AppRoutes.vaultItem(loginId()));
    await tester.tap(find.byTooltip('Düzenle'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginEditScreen), findsOneWidget);

    await backGesture(tester);

    expect(find.byType(LoginEditScreen), findsNothing);
    expect(find.byType(LoginDetailScreen), findsOneWidget);
  });

  testWidgets('değişmiş formda geri hareketi önce soruyor', (tester) async {
    await pumpApp(tester);
    await push(tester, AppRoutes.vaultItem(loginId()));
    await tester.tap(find.byTooltip('Düzenle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ad'), 'Yeni');
    await tester.pump();

    await backGesture(tester);

    expect(find.text('Değişiklikler silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('Değişiklikleri at'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginDetailScreen), findsOneWidget);
  });

  testWidgets('geri hareketi öteki sekmedeki sayfayı kapatmıyor', (
    tester,
  ) async {
    await pumpApp(tester);
    await push(tester, AppRoutes.vaultItem(loginId()));
    await switchTab(tester, 1);
    await push(tester, AppRoutes.cardItem(loginIdHex(cards.items.first.id)));
    expect(find.byType(CardDetailScreen), findsOneWidget);

    await backGesture(tester);
    expect(find.byType(CardDetailScreen), findsNothing);

    await switchTab(tester, 0);
    expect(find.byType(LoginDetailScreen), findsOneWidget);
  });
}

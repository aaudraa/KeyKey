import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/ui/kk_card.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/presentation/vault_screen.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

/// Parolalar, Kartlar ve Notlar listelerinde toplu seçim (Faz 18).
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
          const LoginContent(name: 'Posta', password: 'p1', folder: 'Kişisel'),
          id: 1,
        ),
        FakeLoginRepository.item(
          const LoginContent(name: 'Banka', password: 'p2', folder: 'Banka'),
          id: 2,
        ),
        FakeLoginRepository.item(
          const LoginContent(name: 'Oyun', password: 'p3'),
          id: 3,
        ),
      ],
    );
    cards = FakeRecordRepository<CardContent>(
      items: [
        FakeRecordRepository.item(
          CardContent(name: 'Maaş kartı', number: '4111111111111111'),
          id: 4,
        ),
      ],
    );
  });

  Future<void> pumpVault(WidgetTester tester) => pumpKeyKey(
    tester,
    status: VaultOpen(service.newSession()),
    service: service,
    logins: logins,
    cards: cards,
  );

  Finder row(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(KkCard));

  Future<void> longPress(WidgetTester tester, String name) async {
    await tester.longPress(row(name));
    await tester.pumpAndSettle();
  }

  Future<void> tapRow(WidgetTester tester, String name) async {
    await tester.tap(row(name));
    await tester.pumpAndSettle();
  }

  LoginContent login(int id) =>
      logins.items.firstWhere((item) => item.id[15] == id).content;

  bool isSelected(WidgetTester tester, String name) =>
      tester
          .getSemantics(row(name))
          .getSemanticsData()
          .flagsCollection
          .isSelected ==
      Tristate.isTrue;

  testWidgets('uzun basma seçimi başlatıyor, dokunma seçip bırakıyor', (
    tester,
  ) async {
    await pumpVault(tester);
    await longPress(tester, 'Posta');
    expect(find.text('1 seçildi'), findsOneWidget);
    expect(isSelected(tester, 'Posta'), isTrue);
    expect(isSelected(tester, 'Banka'), isFalse);

    // Seçim modunda dokunmak ayrıntıyı açmaz, seçer.
    await tapRow(tester, 'Banka');
    expect(find.text('2 seçildi'), findsOneWidget);
    expect(find.byType(VaultScreen), findsWidgets);

    await tapRow(tester, 'Posta');
    await tapRow(tester, 'Banka');
    // Son seçim bırakılınca mod kapanır.
    expect(find.textContaining('seçildi'), findsNothing);
    expect(find.text('PAROLALAR'), findsOneWidget);
  });

  testWidgets('kapat düğmesi seçimi bırakıyor', (tester) async {
    await pumpVault(tester);
    await longPress(tester, 'Posta');
    await tester.tap(find.byTooltip('Seçimi kapat'));
    await tester.pumpAndSettle();
    expect(find.textContaining('seçildi'), findsNothing);
  });

  testWidgets('tümünü seç aramada görünenleri seçiyor', (tester) async {
    await pumpVault(tester);
    await tester.enterText(find.byType(TextField).first, 'a');
    await tester.pumpAndSettle();
    // "a" geçen iki kayıt: Posta ve Banka.
    await longPress(tester, 'Posta');
    await tester.tap(find.byTooltip('Tümünü seç'));
    await tester.pumpAndSettle();
    expect(find.text('2 seçildi'), findsOneWidget);
  });

  testWidgets('arama daralınca görünmeyen seçim düşüyor', (tester) async {
    await pumpVault(tester);
    await longPress(tester, 'Posta');
    await tapRow(tester, 'Oyun');
    expect(find.text('2 seçildi'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Posta');
    await tester.pumpAndSettle();
    expect(find.text('1 seçildi'), findsOneWidget);

    await tester.tap(find.byTooltip('Çöp kutusuna taşı'));
    await tester.pumpAndSettle();
    expect(login(1).isTrashed, isTrue);
    expect(login(3).isTrashed, isFalse);
  });

  testWidgets('çöpe taşıma ve geri al', (tester) async {
    await pumpVault(tester);
    await longPress(tester, 'Posta');
    await tapRow(tester, 'Banka');
    await tester.tap(find.byTooltip('Çöp kutusuna taşı'));
    await tester.pumpAndSettle();

    expect(login(1).isTrashed, isTrue);
    expect(login(2).isTrashed, isTrue);
    expect(find.text('2 kayıt çöp kutusuna taşındı'), findsOneWidget);
    expect(find.text('Posta'), findsNothing);
    expect(find.textContaining('seçildi'), findsNothing);

    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    expect(login(1).isTrashed, isFalse);
    expect(login(2).isTrashed, isFalse);
    expect(find.text('Posta'), findsOneWidget);
  });

  testWidgets('var olan klasöre taşıma', (tester) async {
    await pumpVault(tester);
    await longPress(tester, 'Posta');
    await tapRow(tester, 'Oyun');
    await tester.tap(find.byTooltip('Klasöre taşı'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Banka'));
    await tester.pumpAndSettle();

    expect(login(1).folder, 'Banka');
    expect(login(3).folder, 'Banka');
    expect(login(2).folder, 'Banka');
    expect(find.textContaining('seçildi'), findsNothing);
  });

  testWidgets('yeni klasör ve klasörden çıkarma', (tester) async {
    await pumpVault(tester);
    await longPress(tester, 'Posta');
    await tester.tap(find.byTooltip('Klasöre taşı'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Yeni klasör'),
      '  Ortak  ',
    );
    await tester.pump();
    await tester.tap(find.text('Taşı'));
    await tester.pumpAndSettle();
    expect(login(1).folder, 'Ortak');

    await longPress(tester, 'Posta');
    await tester.tap(find.byTooltip('Klasöre taşı'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Klasörden çıkar'));
    await tester.pumpAndSettle();
    expect(login(1).folder, isNull);
  });

  testWidgets('geri tuşu seçimi bırakıyor, ekrandan çıkmıyor', (tester) async {
    await pumpVault(tester);
    await longPress(tester, 'Posta');
    expect(find.text('1 seçildi'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.textContaining('seçildi'), findsNothing);
    expect(find.text('Posta'), findsOneWidget);
  });

  testWidgets('sekme değişince seçim bırakılıyor', (tester) async {
    await pumpVault(tester);
    await longPress(tester, 'Posta');
    await tester.tap(find.byIcon(Icons.credit_card_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.key_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('seçildi'), findsNothing);
    expect(isSelected(tester, 'Posta'), isFalse);
  });

  testWidgets('Kartlar sekmesinde yalnızca kartlar seçiliyor', (tester) async {
    await pumpVault(tester);
    await tester.tap(find.byIcon(Icons.credit_card_outlined));
    await tester.pumpAndSettle();
    await longPress(tester, 'Maaş kartı');
    await tester.tap(find.byTooltip('Tümünü seç'));
    await tester.pumpAndSettle();
    expect(find.text('1 seçildi'), findsOneWidget);
    await tester.tap(find.byTooltip('Çöp kutusuna taşı'));
    await tester.pumpAndSettle();
    expect(cards.items.single.content.isTrashed, isTrue);
    expect(logins.items.any((item) => item.content.isTrashed), isFalse);
  });

  testWidgets('seçim modunda kopyalama düğmesi yok, uzun basma ipucu "Seç"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpVault(tester);
    expect(
      find.descendant(
        of: row('Posta'),
        matching: find.byTooltip('Parolayı kopyala'),
      ),
      findsOneWidget,
    );
    final data = tester.getSemantics(row('Posta')).getSemanticsData();
    expect(data.hasAction(SemanticsAction.longPress), isTrue);
    expect(
      tester.getSemantics(row('Posta')).hintOverrides?.onLongPressHint,
      'Seç',
    );
    await longPress(tester, 'Posta');
    expect(
      find.descendant(
        of: row('Posta'),
        matching: find.byTooltip('Parolayı kopyala'),
      ),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('%200 yazıda seçim çubuğu taşmıyor', (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpVault(tester);
    await longPress(tester, 'Posta');
    expect(tester.takeException(), isNull);
    for (final tooltip in ['Tümünü seç', 'Klasöre taşı', 'Çöp kutusuna taşı']) {
      expect(find.byTooltip(tooltip), findsOneWidget);
    }
  });
}

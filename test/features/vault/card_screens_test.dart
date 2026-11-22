import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/kk_secret_text.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/application/records_controller.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/card_number.dart';
import 'package:keykey/features/vault/presentation/card_detail_screen.dart';
import 'package:keykey/features/vault/presentation/card_edit_screen.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:keykey/features/vault/presentation/vault_screen.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeRecordRepository<CardContent> cards;
  late RecordingClipboard clipboard;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() {
    service = FakeVaultService(sodium);
    clipboard = RecordingClipboard();
    cards = FakeRecordRepository<CardContent>(
      items: [
        FakeRecordRepository.item(
          CardContent(
            name: 'Maaş kartı',
            cardholder: 'AYŞE YILMAZ',
            number: '4111111111111111',
            expiry: CardExpiry(month: 12, year: 2099),
            securityCode: '123',
            pin: '4321',
          ),
          id: 1,
        ),
        FakeRecordRepository.item(
          CardContent(
            name: 'Eski kart',
            number: '5555555555554444',
            expiry: CardExpiry(month: 1, year: 2020),
          ),
          id: 2,
        ),
      ],
    );
  });

  Future<void> pumpApp(WidgetTester tester) => pumpKeyKey(
    tester,
    status: VaultOpen(service.newSession()),
    service: service,
    cards: cards,
    clipboard: clipboard,
  );

  Future<void> go(WidgetTester tester, String location) async {
    unawaited(
      GoRouter.of(tester.element(find.byType(VaultScreen))).push(location),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openCard(WidgetTester tester, int index) async {
    await pumpApp(tester);
    await go(tester, AppRoutes.cardItem(loginIdHex(cards.items[index].id)));
    expect(find.byType(CardDetailScreen), findsOneWidget);
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  group('ayrıntı', () {
    testWidgets('numara, güvenlik kodu ve PIN gizli gelir', (tester) async {
      await openCard(tester, 0);

      expect(find.text('Maaş kartı'), findsWidgets);
      expect(find.text('4111 1111 1111 1111'), findsNothing);
      expect(find.text('123'), findsNothing);
      expect(find.text('4321'), findsNothing);
      expect(find.text('•••• •••• •••• 1111'), findsOneWidget);

      await tester.scrollUntilVisible(find.byTooltip('Göster').first, 100);
      await tester.tap(find.byTooltip('Göster').first);
      await tester.pump();
      await tester.pump(KkSecretText.maxTotal);

      expect(find.text('4111 1111 1111 1111'), findsOneWidget);
    });

    testWidgets('numara gruplanmadan, kart sahibi ve son kullanma da '
        'hassas panoya kopyalanır', (tester) async {
      await openCard(tester, 0);

      for (final label in ['Kart numarası', 'Kart sahibi', 'Son kullanma']) {
        final copy = find.byTooltip('Kopyala: $label');
        await tester.scrollUntilVisible(copy, 100);
        await tester.tap(copy);
        await tester.pump();
      }

      expect(clipboard.copied, ['4111111111111111', 'AYŞE YILMAZ', '12/99']);
    });

    testWidgets('süresi geçmiş kartta "Süresi doldu" görünür', (tester) async {
      await openCard(tester, 1);

      expect(find.text('Süresi doldu'), findsOneWidget);
    });

    testWidgets('süresi geçmemiş kartta uyarı yok', (tester) async {
      await openCard(tester, 0);

      expect(find.text('Süresi doldu'), findsNothing);
    });

    testWidgets('menüden çöp kutusuna taşınır', (tester) async {
      await openCard(tester, 0);

      await tester.tap(find.byTooltip('Diğer işlemler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çöp kutusuna taşı'));
      await tester.pumpAndSettle();

      expect(cards.items.first.content.isTrashed, isTrue);
      expect(find.byType(CardDetailScreen), findsNothing);
    });
  });

  testWidgets('adsız kartın kalıcı silme onayı listedeki adını söyler', (
    tester,
  ) async {
    cards.items.add(
      FakeRecordRepository.item(
        CardContent(
          name: '',
          number: '4111111111111111',
          trashedAt: DateTime.utc(2026, 11, 10),
        ),
        id: 3,
      ),
    );
    await pumpApp(tester);
    await go(tester, AppRoutes.cardsTrash);

    await tester.tap(find.byTooltip('Kalıcı olarak sil'));
    await tester.pumpAndSettle();

    expect(
      find.text('"Visa •••• 1111" silinecek ve geri getirilemeyecek.'),
      findsOneWidget,
    );
  });

  group('düzenleme', () {
    Future<void> openNew(WidgetTester tester) async {
      await pumpApp(tester);
      await go(tester, AppRoutes.cardNew);
      expect(find.byType(CardEditScreen), findsOneWidget);
    }

    testWidgets('yalnızca adla kart kaydedilir', (tester) async {
      await openNew(tester);

      await tester.enterText(field('Ad'), 'Yeni kart');
      await tester.pump();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(cards.items.last.content.name, 'Yeni kart');
      expect(find.byType(CardEditScreen), findsNothing);
    });

    testWidgets('bütün alanlar kayda girer', (tester) async {
      await openNew(tester);

      await tester.enterText(field('Ad'), 'Kredi');
      await tester.enterText(field('Kart sahibi'), 'ALİ VELİ');
      await tester.enterText(field('Kart numarası'), '4111-1111 1111 1111');
      await tester.enterText(field('Son kullanma (AA/YY)'), '0930');
      await tester.enterText(field('Güvenlik kodu'), '987');
      await tester.enterText(field('PIN'), '2468');
      await tester.pump();
      await tester.ensureVisible(find.text('Kaydet'));
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      final saved = cards.items.last.content;
      expect(saved.name, 'Kredi');
      expect(saved.cardholder, 'ALİ VELİ');
      expect(saved.number, '4111111111111111');
      expect(saved.expiry, CardExpiry(month: 9, year: 2030));
      expect(saved.securityCode, '987');
      expect(saved.pin, '2468');
    });

    testWidgets('geçersiz ay hata gösterir ve kaydetmez', (tester) async {
      await openNew(tester);

      await tester.enterText(field('Ad'), 'Kredi');
      await tester.enterText(field('Son kullanma (AA/YY)'), '1328');
      await tester.pump();

      expect(find.text('Ay 01-12, yıl iki haneli olmalı.'), findsOneWidget);

      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(cards.items, hasLength(2));
      expect(find.byType(CardEditScreen), findsOneWidget);
    });

    testWidgets('yarım son kullanma kaydetmez ve nedenini söyler', (
      tester,
    ) async {
      await openNew(tester);

      await tester.enterText(field('Ad'), 'Kredi');
      await tester.enterText(field('Son kullanma (AA/YY)'), '1/2');
      await tester.pump();
      // Yazarken henüz uyarı yok.
      expect(find.text('Ay 01-12, yıl iki haneli olmalı.'), findsNothing);

      await tester.ensureVisible(find.text('Kaydet'));
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(find.text('Ay 01-12, yıl iki haneli olmalı.'), findsOneWidget);
      expect(cards.items, hasLength(2));
      expect(find.byType(CardEditScreen), findsOneWidget);
    });

    testWidgets('yarım son kullanma kutudan çıkınca uyarır', (tester) async {
      await openNew(tester);

      await tester.enterText(field('Son kullanma (AA/YY)'), '9/30');
      await tester.pump();
      expect(find.text('Ay 01-12, yıl iki haneli olmalı.'), findsNothing);

      await tester.enterText(field('Güvenlik kodu'), '123');
      await tester.pump();

      expect(find.text('Ay 01-12, yıl iki haneli olmalı.'), findsOneWidget);
    });

    testWidgets('Luhn tutmazsa uyarır ama kaydeder', (tester) async {
      await openNew(tester);

      await tester.enterText(field('Ad'), 'Kısmi');
      await tester.enterText(field('Kart numarası'), '4111111111111112');
      await tester.pump();

      expect(
        find.text(
          'Bu numara bir kart numarasına benzemiyor. Yine de kaydedebilirsin.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(cards.items.last.content.number, '4111111111111112');
    });

    testWidgets('marka numara yazılırken görünür', (tester) async {
      await openNew(tester);

      await tester.enterText(field('Kart numarası'), '3782');
      await tester.pump();

      expect(find.text('American Express'), findsOneWidget);
    });

    testWidgets('kaydedilmemiş değişiklikle çıkarken onay ister', (
      tester,
    ) async {
      await openNew(tester);

      await tester.enterText(field('Ad'), 'Yarım');
      await tester.pump();
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      await navigator.maybePop();
      await tester.pumpAndSettle();

      expect(find.text('Değişiklikler silinsin mi?'), findsOneWidget);
    });

    testWidgets('form açıkken gelen değişiklik kaydetmede ezilmiyor', (
      tester,
    ) async {
      // Form açıkken senkron öteki telefonun yeni PIN'ini ve çöpe atmasını
      // getirdi; kullanıcı yalnızca adı değiştirdi.
      await pumpApp(tester);
      await go(
        tester,
        AppRoutes.cardItemEdit(loginIdHex(cards.items.first.id)),
      );
      final controller = ProviderScope.containerOf(
        tester.element(find.byType(CardEditScreen)),
      ).read(cardsControllerProvider.notifier);
      final item = cards.items.first;
      await controller.update(
        item,
        item.content.copyWith(pin: '9999', trashedAt: DateTime.utc(2026)),
      );

      await tester.enterText(field('Ad'), 'Yeni ad');
      await tester.pump();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      final saved = cards.items.first.content;
      expect(saved.name, 'Yeni ad');
      expect(saved.pin, '9999');
      expect(saved.isTrashed, isTrue);
    });

    testWidgets('kayıt sürerken kilitlenirse hata çıkmıyor', (tester) async {
      final gate = cards.writeGate = Completer<void>();
      await pumpApp(tester);
      await go(
        tester,
        AppRoutes.cardItemEdit(loginIdHex(cards.items.first.id)),
      );
      await tester.enterText(field('Ad'), 'Yeni ad');
      await tester.pump();
      await tester.tap(find.text('Kaydet'));
      await tester.pump();
      ProviderScope.containerOf(tester.element(find.byType(CardEditScreen)))
          .read(vaultControllerProvider.notifier)
          .lock();
      await tester.pumpAndSettle();

      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('klasör adı harf farkıyla var olana bağlanıyor', (
      tester,
    ) async {
      final other = cards.items[1];
      cards.items[1] = FakeRecordRepository.item(
        other.content.copyWith(folder: 'İş'),
        id: 2,
      );
      await pumpApp(tester);
      await go(
        tester,
        AppRoutes.cardItemEdit(loginIdHex(cards.items.first.id)),
      );
      await tester.ensureVisible(field('Klasör'));
      await tester.enterText(field('Klasör'), 'iş');
      await tester.pump();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(cards.items.first.content.folder, 'İş');
    });

    testWidgets('var olan kart düzenlenir', (tester) async {
      await pumpApp(tester);
      await go(
        tester,
        AppRoutes.cardItemEdit(loginIdHex(cards.items.first.id)),
      );

      expect(
        tester.widget<TextField>(field('Kart numarası')).controller!.text,
        '4111 1111 1111 1111',
      );
      await tester.enterText(field('Ad'), 'Yeni ad');
      await tester.pump();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(cards.items.first.content.name, 'Yeni ad');
      expect(cards.items.first.content.pin, '4321');
    });
  });
}

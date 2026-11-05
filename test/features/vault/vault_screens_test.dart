import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:keykey/features/vault/presentation/vault_screen.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeLoginRepository logins;

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
            password: 'posta-parolasi',
            urls: ['https://mail.example.com'],
            folder: 'Kişisel',
          ),
          id: 1,
        ),
        FakeLoginRepository.item(
          const LoginContent(
            name: 'İş Bankası',
            username: 'ali',
            password: 'banka-parolasi',
            favorite: true,
            folder: 'Banka',
          ),
          id: 2,
        ),
        FakeLoginRepository.item(
          const LoginContent(name: 'Zeka Oyunu', password: 'oyun-parolasi'),
          id: 3,
        ),
      ],
    );
  });

  Future<void> pumpVault(WidgetTester tester) => pumpKeyKey(
    tester,
    status: VaultOpen(service.newSession()),
    service: service,
    logins: logins,
  );

  List<String> visibleNames(WidgetTester tester) => tester
      .widgetList<ListTile>(
        find.descendant(
          of: find.byType(VaultScreen),
          matching: find.byType(ListTile),
        ),
      )
      .map((tile) => (tile.title! as Text).data!)
      .toList();

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.widgetWithText(TextField, 'Ara'), query);
    await tester.pumpAndSettle();
  }

  group('liste', () {
    testWidgets('kayıtlar ada göre sıralı', (tester) async {
      await pumpVault(tester);

      expect(visibleNames(tester), ['İş Bankası', 'Posta', 'Zeka Oyunu']);
    });

    testWidgets('boş kasada yönlendirme var', (tester) async {
      logins = FakeLoginRepository();
      await pumpVault(tester);

      expect(find.textContaining('Henüz parola yok'), findsOneWidget);
    });

    testWidgets('Türkçe harflerle arama', (tester) async {
      await pumpVault(tester);

      await search(tester, 'is bank');
      expect(visibleNames(tester), ['İş Bankası']);

      await search(tester, 'mail.example');
      expect(visibleNames(tester), ['Posta']);

      await search(tester, 'banka-parolasi');
      expect(visibleNames(tester), isEmpty);
      expect(find.text('Eşleşen kayıt yok.'), findsOneWidget);
    });

    testWidgets('favoriler ve klasörler süzülüyor', (tester) async {
      await pumpVault(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Favoriler'));
      await tester.pumpAndSettle();
      expect(visibleNames(tester), ['İş Bankası']);

      await tester.tap(find.widgetWithText(FilterChip, 'Favoriler'));
      await tester.tap(find.widgetWithText(FilterChip, 'Kişisel'));
      await tester.pumpAndSettle();
      expect(visibleNames(tester), ['Posta']);
    });

    testWidgets('okunamayan kayıt sayısı gösteriliyor', (tester) async {
      logins = FakeLoginRepository(unreadableCount: 2);
      await pumpVault(tester);

      expect(find.textContaining('2 kayıt okunamadı'), findsOneWidget);
    });
  });

  group('ayrıntı', () {
    Future<void> openPosta(WidgetTester tester) async {
      await pumpVault(tester);
      await tester.tap(find.text('Posta'));
      await tester.pumpAndSettle();
    }

    testWidgets('parola varsayılan olarak gizli', (tester) async {
      await openPosta(tester);

      expect(find.text('ali@example.com'), findsOneWidget);
      expect(find.text('posta-parolasi'), findsNothing);

      await tester.tap(find.byTooltip('Göster'));
      await tester.pump();
      expect(find.text('posta-parolasi'), findsOneWidget);
    });

    testWidgets('kilitlenince ayrıntı kapanıyor, dönülemiyor', (tester) async {
      await openPosta(tester);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('KeyKey kilitli'), findsOneWidget);
      expect(find.text('ali@example.com'), findsNothing);

      final idHex = loginIdHex(logins.items.first.id);
      GoRouter.of(tester.element(find.text('KeyKey kilitli')))
          .go(AppRoutes.vaultItem(idHex));
      await tester.pumpAndSettle();
      expect(find.text('KeyKey kilitli'), findsOneWidget);
    });

    testWidgets('favori düğmesi kaydı değiştiriyor', (tester) async {
      await openPosta(tester);

      await tester.tap(find.byTooltip('Favorilere ekle'));
      await tester.pumpAndSettle();

      expect(logins.items.first.content.favorite, isTrue);
      expect(find.byTooltip('Favorilerden çıkar'), findsOneWidget);
    });
  });

  group('ekleme ve düzenleme', () {
    testWidgets('yeni kayıt ekleniyor ve listede görünüyor', (tester) async {
      await pumpVault(tester);

      await tester.tap(find.text('Ekle'));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(TextButton, 'Kaydet');
      expect(tester.widget<TextButton>(save).onPressed, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Ad'), 'Yeni Site');
      await tester.enterText(
        find.widgetWithText(TextField, 'Kullanıcı adı'),
        'veli',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Parola'),
        'yeni-parola',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Web adresi'),
        'https://yeni.example.com',
      );
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();

      final added = logins.items.last.content;
      expect(added.name, 'Yeni Site');
      expect(added.username, 'veli');
      expect(added.password, 'yeni-parola');
      expect(added.urls, ['https://yeni.example.com']);
      expect(visibleNames(tester), contains('Yeni Site'));
    });

    testWidgets('form kutularında klavye öğrenmesi kapalı', (tester) async {
      await pumpVault(tester);
      await tester.tap(find.text('Ekle'));
      await tester.pumpAndSettle();

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.length, greaterThanOrEqualTo(6));
      for (final field in fields) {
        expect(field.enableIMEPersonalizedLearning, isFalse);
        expect(field.autocorrect, isFalse);
        expect(field.enableSuggestions, isFalse);
      }
    });

    testWidgets('parola değişince eskisi geçmişte', (tester) async {
      await pumpVault(tester);
      await tester.tap(find.text('Posta'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Düzenle'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Parola'),
        'degisen-parola',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Kaydet'));
      await tester.pumpAndSettle();

      final content = logins.items.first.content;
      expect(content.password, 'degisen-parola');
      expect(content.passwordHistory.single.password, 'posta-parolasi');
      expect(find.text('Parola geçmişi (1)'), findsOneWidget);
    });

    testWidgets('kaydedilmeden çıkarken onay isteniyor', (tester) async {
      await pumpVault(tester);
      await tester.tap(find.text('Ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Ad'), 'Yarım');
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Değişiklikler silinsin mi?'), findsOneWidget);

      await tester.tap(find.text('Düzenlemeye devam et'));
      await tester.pumpAndSettle();
      expect(find.text('Yeni parola'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      expect(find.byType(VaultScreen), findsOneWidget);
      expect(
        logins.items.map((item) => item.content.name),
        isNot(contains('Yarım')),
      );
    });
  });

  group('çöp kutusu', () {
    Future<void> trashPosta(WidgetTester tester) async {
      await pumpVault(tester);
      await tester.tap(find.text('Posta'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Çöp kutusuna taşı'));
      await tester.pumpAndSettle();
    }

    testWidgets('taşınan kayıt listeden çıkıyor, geri alınabiliyor', (
      tester,
    ) async {
      await trashPosta(tester);

      expect(visibleNames(tester), isNot(contains('Posta')));
      expect(logins.items.first.content.isTrashed, isTrue);

      await tester.tap(find.text('Geri al'));
      await tester.pumpAndSettle();
      expect(logins.items.first.content.isTrashed, isFalse);
      expect(visibleNames(tester), contains('Posta'));
    });

    testWidgets('çöp kutusundan geri alınıyor', (tester) async {
      await trashPosta(tester);
      ScaffoldMessenger.of(tester.element(find.byType(VaultScreen)))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Çöp kutusu'));
      await tester.pumpAndSettle();
      expect(find.text('Posta'), findsOneWidget);

      await tester.tap(find.byTooltip('Geri al'));
      await tester.pumpAndSettle();
      expect(find.text('Çöp kutusu boş.'), findsOneWidget);
      expect(logins.items.first.content.isTrashed, isFalse);
    });

    testWidgets('kalıcı silme onay istiyor', (tester) async {
      await trashPosta(tester);
      await tester.tap(find.byTooltip('Çöp kutusu'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Kalıcı olarak sil'));
      await tester.pumpAndSettle();
      expect(find.text('Kalıcı olarak silinsin mi?'), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(logins.items, hasLength(3));

      await tester.tap(find.byTooltip('Kalıcı olarak sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Kalıcı olarak sil'));
      await tester.pumpAndSettle();
      expect(logins.items, hasLength(2));
      expect(find.text('Çöp kutusu boş.'), findsOneWidget);
    });
  });

  testWidgets('yazmak otomatik kilit süresini yeniliyor', (tester) async {
    await pumpVault(tester);
    await tester.tap(find.text('Ekle'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(minutes: 4));
      await tester.enterText(find.widgetWithText(TextField, 'Notlar'), 'n$i');
      await tester.pump();
    }
    expect(find.text('KeyKey kilitli'), findsNothing);

    await tester.pump(const Duration(minutes: 5, seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('KeyKey kilitli'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_animated_items.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_card.dart';
import 'package:keykey/app/ui/kk_done_mark.dart';
import 'package:keykey/app/ui/kk_form.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_secret_text.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:keykey/features/vault/presentation/login_detail_screen.dart';
import 'package:keykey/features/vault/presentation/login_edit_screen.dart';
import 'package:keykey/features/vault/presentation/login_ids.dart';
import 'package:keykey/features/vault/presentation/vault_screen.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/add_flow.dart';
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

  Finder cards() => find.descendant(
    of: find.byType(VaultScreen),
    matching: find.byType(KkCard),
  );

  /// Kartın başlığındaki ad; favori kayıtta başlık ad ve yıldızdan oluşur.
  String titleOf(KkCard card) => switch (card.title) {
    final Text text => text.data!,
    final Row row =>
      (row.children.whereType<Flexible>().first.child as Text).data!,
    _ => throw StateError('beklenmeyen başlık'),
  };

  List<String> visibleNames(WidgetTester tester) =>
      tester.widgetList<KkCard>(cards()).map(titleOf).toList();

  Finder searchField() => find.descendant(
    of: find.byType(VaultScreen),
    matching: find.byType(TextField),
  );

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(searchField(), query);
    await tester.pumpAndSettle();
  }

  /// Uzun formda alttaki öğeyi görünür yapıp dokunur.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Diğer işlemler'));
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

    testWidgets('arama kutusu kayıt sayısını söylüyor', (tester) async {
      await pumpVault(tester);
      expect(
        find.descendant(
          of: searchField(),
          matching: find.text('3 kayıtta ara'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('boş kasada arama kutusu yalnızca "Ara"', (tester) async {
      logins = FakeLoginRepository();
      await pumpVault(tester);
      expect(
        find.descendant(of: searchField(), matching: find.text('Ara')),
        findsOneWidget,
      );
    });

    testWidgets('favori ve klasör yoksa süzgeç satırı yok', (tester) async {
      logins = FakeLoginRepository(
        items: [
          FakeLoginRepository.item(
            const LoginContent(name: 'Posta', password: 'p'),
            id: 1,
          ),
        ],
      );
      await pumpVault(tester);
      expect(find.byType(FilterChip), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VaultScreen)),
      );
      await container
          .read(loginsControllerProvider.notifier)
          .setFavorite(logins.items.first, favorite: true);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, 'Favoriler'), findsOneWidget);
    });

    testWidgets('son favori kalkınca süzgeç sıfırlanıyor', (tester) async {
      await pumpVault(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Favoriler'));
      await tester.pumpAndSettle();
      expect(visibleNames(tester), ['İş Bankası']);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VaultScreen)),
      );
      await container
          .read(loginsControllerProvider.notifier)
          .setFavorite(logins.items[1], favorite: false);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, 'Favoriler'), findsNothing);
      expect(visibleNames(tester), ['İş Bankası', 'Posta', 'Zeka Oyunu']);
    });

    testWidgets('sıralama ve ekranlar üç nokta menüsünde', (tester) async {
      await pumpVault(tester);
      expect(find.byTooltip('Çöp kutusu'), findsNothing);
      expect(find.byTooltip('Sırala'), findsNothing);

      await openMenu(tester);
      await tester.tap(find.text('Son değişene göre sırala'));
      await tester.pumpAndSettle();
      expect(visibleNames(tester).first, isNot('İş Bankası'));

      await openMenu(tester);
      final checked = find.descendant(
        of: find.ancestor(
          of: find.text('Son değişene göre sırala'),
          matching: find.byType(InkWell),
        ),
        matching: find.byIcon(Icons.check_rounded),
      );
      expect(checked, findsOneWidget);
      await tester.tap(find.text('Çöp kutusu'));
      await tester.pumpAndSettle();
      expect(find.text('Çöp kutusu boş.'), findsOneWidget);
    });

    testWidgets('listeden parola kopyalanıyor, kayıt açılmıyor', (
      tester,
    ) async {
      final clipboard = RecordingClipboard();
      await pumpKeyKey(
        tester,
        status: VaultOpen(service.newSession()),
        service: service,
        logins: logins,
        clipboard: clipboard,
      );
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(KkCard, 'Posta'),
          matching: find.byTooltip('Parolayı kopyala'),
        ),
      );
      await tester.pumpAndSettle();
      expect(clipboard.copied, ['posta-parolasi']);
      expect(
        find.text('Kopyalandı. Pano 30 saniye sonra temizlenecek.'),
        findsOneWidget,
      );
      expect(find.byType(VaultScreen), findsOneWidget);
      expect(find.text('Kullanıcı adı'), findsNothing);
    });

    testWidgets('parolası boş kayıtta kopyala düğmesi yok', (tester) async {
      logins = FakeLoginRepository(
        items: [
          FakeLoginRepository.item(const LoginContent(name: 'Boş'), id: 1),
        ],
      );
      await pumpVault(tester);
      expect(find.byTooltip('Parolayı kopyala'), findsNothing);
    });

    testWidgets('favori kayıtta "Favori" etiketi okunuyor', (tester) async {
      await pumpVault(tester);
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('Favori')), findsWidgets);
      handle.dispose();
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

    testWidgets('kayıt kartları aynı boyda, kullanıcı adı olmasa da', (
      tester,
    ) async {
      await pumpVault(tester);

      final heights = tester
          .widgetList(cards())
          .map((w) => tester.getSize(find.byWidget(w)).height)
          .toSet();
      expect(heights, {64.0});
    });

    // Telefon denemesi 4: arama kutusu kaydırınca yukarı gitmiyordu.
    testWidgets('büyük başlık ve arama kutusu listeyle birlikte kayar', (
      tester,
    ) async {
      logins = FakeLoginRepository(
        items: [
          for (var i = 0; i < 30; i++)
            FakeLoginRepository.item(
              LoginContent(name: 'Kayıt $i', password: 'p$i'),
              id: 10 + i,
            ),
        ],
      );
      await pumpVault(tester);
      final bar = find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Kasa'),
      );
      expect(bar, findsNothing);
      final large = find.descendant(
        of: find.byType(KkLargeTitle),
        matching: find.text('Kasa'),
      );
      final titleTop = tester.getTopLeft(large).dy;
      final searchTop = tester.getTopLeft(searchField()).dy;

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -30));
      await tester.pumpAndSettle();
      // Kartlar dokunuşu da dinlediği için sürükleme payı düşer; başlık
      // ve arama kutusu listeyle aynı miktarda kayar.
      final moved = titleTop - tester.getTopLeft(large).dy;
      expect(moved, greaterThan(5));
      expect(
        tester.getTopLeft(searchField()).dy,
        closeTo(searchTop - moved, 1),
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(bar, findsOneWidget);
      expect(searchField().hitTestable(), findsNothing);
    });

    testWidgets('son kart alt menünün altında kalmayacak kadar boşluk var', (
      tester,
    ) async {
      await pumpVault(tester);

      final list = tester.widget<KkItemsView<LoginItem>>(
        find.descendant(
          of: find.byType(VaultScreen),
          matching: find.byType(KkItemsView<LoginItem>),
        ),
      );
      expect(list.padding.bottom, greaterThanOrEqualTo(kNavClearance));
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

    testWidgets('ayrıntı ekranı geçişle açılır, geri geçişle kapanır', (
      tester,
    ) async {
      await pumpVault(tester);
      await tester.tap(find.text('Posta'));
      await tester.pump();
      await tester.pump();
      final route = ModalRoute.of(
        tester.element(find.byType(LoginDetailScreen)),
      )!;
      expect(route, isA<PageRoute<dynamic>>());
      expect(
        (route as PageRoute).transitionDuration,
        greaterThan(Duration.zero),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(route.animation!.status, AnimationStatus.forward);
      await tester.pumpAndSettle();
      expect(route.animation!.status, AnimationStatus.completed);
    });

    testWidgets('her alan kendi kartında', (tester) async {
      await openPosta(tester);

      GlassSurface cardOf(String label) => tester.widget<GlassSurface>(
        find
            .ancestor(of: find.text(label), matching: find.byType(GlassSurface))
            .first,
      );
      final username = cardOf('Kullanıcı adı');
      final password = cardOf('Parola');
      final url = cardOf('https://mail.example.com');
      expect(identical(username, password), isFalse);
      expect(identical(password, url), isFalse);
    });

    testWidgets('parola varsayılan olarak gizli', (tester) async {
      await openPosta(tester);

      expect(find.text('ali@example.com'), findsOneWidget);
      expect(find.text('posta-parolasi'), findsNothing);

      await tester.tap(find.byTooltip('Göster'));
      await tester.pump();
      // Karakterler sırayla açılır (madde 3.1).
      await tester.pump(KkSecretText.maxTotal);
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

    testWidgets('gizli değer kopyalanabiliyor, süre bildiriliyor', (
      tester,
    ) async {
      final clipboard = RecordingClipboard();
      await pumpKeyKey(
        tester,
        status: VaultOpen(service.newSession()),
        service: service,
        logins: logins,
        clipboard: clipboard,
      );
      await tester.tap(find.text('Posta'));
      await tester.pumpAndSettle();

      final passwordTile = find
          .ancestor(
            of: find.text('Parola'),
            matching: find.byType(GlassSurface),
          )
          .first;
      await tester.tap(
        find.descendant(of: passwordTile, matching: find.byTooltip('Kopyala')),
      );
      await tester.pump();

      expect(clipboard.copied, ['posta-parolasi']);
      expect(find.text('posta-parolasi'), findsNothing);
      expect(
        find.textContaining('30 saniye sonra temizlenecek'),
        findsOneWidget,
      );
    });

    testWidgets('favori menüden değişiyor', (tester) async {
      await openPosta(tester);
      expect(find.byTooltip('Favorilere ekle'), findsNothing);

      await tester.tap(find.byTooltip('Diğer işlemler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favorilere ekle'));
      await tester.pumpAndSettle();

      expect(logins.items.first.content.favorite, isTrue);
      await tester.tap(find.byTooltip('Diğer işlemler'));
      await tester.pumpAndSettle();
      expect(find.text('Favorilerden çıkar'), findsOneWidget);
    });

    testWidgets('üstte simge kutusu, ad ve site; altta son değişiklik', (
      tester,
    ) async {
      await openPosta(tester);
      final idHex = loginIdHex(logins.items.first.id);
      final hero = tester.widget<Hero>(
        find.descendant(
          of: find.byType(LoginDetailScreen),
          matching: find.byType(Hero),
        ),
      );
      expect(hero.tag, loginAvatarHeroTag(idHex));
      expect(find.textContaining('Son değişiklik: '), findsOneWidget);
      // Başlık çubuğunda ad yok; ad simge kutusunun altında.
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Posta')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(LoginDetailScreen),
          matching: find.text('Posta'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('onay işareti sürerken geri: yalnızca form kapanır', (
      tester,
    ) async {
      await openPosta(tester);
      await tester.tap(find.byTooltip('Düzenle'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Ad'), 'Posta 2');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (find.byType(KkDoneMark).evaluate().isNotEmpty) break;
      }
      expect(find.byType(KkDoneMark), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LoginEditScreen), findsNothing);
      expect(find.byType(LoginDetailScreen), findsOneWidget);
    });

    testWidgets('"Düzenle" formu açar, alt menü görünmez', (tester) async {
      await openPosta(tester);
      expect(find.byType(GlassNavBar), findsOneWidget);
      await tester.tap(find.byTooltip('Düzenle'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginEditScreen), findsOneWidget);
      expect(find.byType(GlassNavBar), findsNothing);
    });
  });

  group('ekleme ve düzenleme', () {
    testWidgets('yeni kayıt ekleniyor ve listede görünüyor', (tester) async {
      await pumpVault(tester);

      await openAddPassword(tester);
      final save = find.widgetWithText(FilledButton, 'Kaydet');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

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

    testWidgets('kaydedince onay işareti, çift basış tek kayıt, ekran '
        'kapanır ve kart listede bir kez parlar', (tester) async {
      await pumpVault(tester);
      final before = logins.items.length;
      await openAddPassword(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Ad'), 'Yeni Site');
      await tester.pump();
      final save = find.widgetWithText(FilledButton, 'Kaydet');
      await tester.tap(save);
      await tester.tap(save);

      var sawDone = false;
      var maxFlash = 0.0;
      final flash = find.descendant(
        of: find.widgetWithText(KkCard, 'Yeni Site'),
        matching: find.byKey(KkCard.flashKey),
      );
      for (var i = 0; i < 150; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (find.byType(KkDoneMark).evaluate().isNotEmpty) sawDone = true;
        if (flash.evaluate().isNotEmpty) {
          final box = tester.widget<DecoratedBox>(flash);
          final alpha = (box.decoration as BoxDecoration).color!.a;
          if (alpha > maxFlash) maxFlash = alpha;
        }
      }
      await tester.pumpAndSettle();

      expect(sawDone, isTrue);
      expect(logins.items, hasLength(before + 1));
      expect(find.byType(LoginEditScreen), findsNothing);
      expect(maxFlash, greaterThan(0.05));
    });

    testWidgets('yeni kayıtta yalnızca dört temel alan', (tester) async {
      await pumpVault(tester);
      await openAddPassword(tester);
      for (final label in ['Ad', 'Kullanıcı adı', 'Parola', 'Web adresi']) {
        expect(find.widgetWithText(TextField, label), findsOneWidget);
      }
      expect(find.widgetWithText(TextField, 'Klasör'), findsNothing);
      expect(find.widgetWithText(TextField, 'Notlar'), findsNothing);
      expect(find.text('Daha fazla seçenek'), findsOneWidget);
      expect(find.byType(GlassNavBar), findsNothing);
    });

    testWidgets('"Not" yongası not alanını ekler ve odaklar', (tester) async {
      await pumpVault(tester);
      await openAddPassword(tester);
      await tapVisible(tester, find.text('Daha fazla seçenek'));
      await tapVisible(tester, find.widgetWithText(ActionChip, 'Not'));

      final notes = find.widgetWithText(TextField, 'Notlar');
      expect(notes, findsOneWidget);
      final editable = tester.widget<EditableText>(
        find.descendant(of: notes, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue);
      expect(find.widgetWithText(ActionChip, 'Not'), findsNothing);
    });

    testWidgets('"Başka site" iki kez: üç adres alanı', (tester) async {
      await pumpVault(tester);
      await openAddPassword(tester);
      await tapVisible(tester, find.text('Daha fazla seçenek'));
      await tapVisible(tester, find.widgetWithText(ActionChip, 'Başka site'));
      await tapVisible(tester, find.widgetWithText(ActionChip, 'Başka site'));
      expect(find.widgetWithText(TextField, 'Web adresi'), findsNWidgets(3));
    });

    testWidgets('düzenlemede dolu ek alanlar doğrudan görünür', (tester) async {
      logins = FakeLoginRepository(
        items: [
          FakeLoginRepository.item(
            const LoginContent(
              name: 'Dolu',
              password: 'p',
              urls: ['https://a.example', 'https://b.example'],
              folder: 'İş',
              notes: 'bir not',
              customFields: [LoginCustomField(name: 'PIN', value: '1234')],
            ),
            id: 1,
          ),
        ],
      );
      await pumpVault(tester);
      await tester.tap(find.text('Dolu'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Düzenle'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Klasör'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Notlar'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Web adresi'), findsNWidgets(2));
      expect(find.text('PIN'), findsOneWidget);

      await tapVisible(tester, find.text('Daha fazla seçenek'));
      expect(find.widgetWithText(ActionChip, 'Klasör'), findsNothing);
      expect(find.widgetWithText(ActionChip, 'Not'), findsNothing);
      expect(find.widgetWithText(ActionChip, 'Özel alan'), findsOneWidget);
    });

    testWidgets('dolu notu kaldırmak sorulur ve boş kaydedilir', (
      tester,
    ) async {
      logins = FakeLoginRepository(
        items: [
          FakeLoginRepository.item(
            const LoginContent(name: 'Notlu', password: 'p', notes: 'gizli'),
            id: 1,
          ),
        ],
      );
      await pumpVault(tester);
      await tester.tap(find.text('Notlu'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Düzenle'));
      await tester.pumpAndSettle();

      final notesCard = find.ancestor(
        of: find.widgetWithText(TextField, 'Notlar'),
        matching: find.byType(KkFieldCard),
      );
      await tester.tap(
        find.descendant(
          of: notesCard,
          matching: find.byTooltip('Alanı kaldır'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Notlar'), findsNothing);

      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();
      expect(find.text('Değişiklikler silinsin mi?'), findsOneWidget);
      await tester.tap(find.text('Düzenlemeye devam et'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.pumpAndSettle();
      expect(logins.items.first.content.notes, '');
    });

    testWidgets('"Kaydet" altta ve klavyenin üstünde', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpVault(tester);
      await openAddPassword(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final save = tester.getRect(find.widgetWithText(FilledButton, 'Kaydet'));
      expect(save.bottom, lessThanOrEqualTo(800 - 300));
    });

    testWidgets('form kutularında klavye öğrenmesi kapalı', (tester) async {
      await pumpVault(tester);
      await openAddPassword(tester);

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.length, greaterThanOrEqualTo(4));
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
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.pumpAndSettle();

      final content = logins.items.first.content;
      expect(content.password, 'degisen-parola');
      expect(content.passwordHistory.single.password, 'posta-parolasi');
      expect(find.text('Parola geçmişi (1)'), findsOneWidget);
    });

    testWidgets('kaydedilmeden çıkarken onay isteniyor', (tester) async {
      await pumpVault(tester);
      await openAddPassword(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Ad'), 'Yarım');
      await tester.pump();

      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();
      expect(find.text('Değişiklikler silinsin mi?'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);

      await tester.tap(find.text('Düzenlemeye devam et'));
      await tester.pumpAndSettle();
      expect(find.text('Yeni parola'), findsOneWidget);

      await tester.tap(find.byTooltip('Geri'));
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

  group('bağlı uygulamalar', () {
    final app = LoginApp(
      packageName: 'com.example.posta',
      certsSha256: ['ab' * 32],
    );

    setUp(() {
      logins.items[0] = FakeLoginRepository.item(
        logins.items[0].content.copyWith(apps: [app]),
        id: 1,
      );
    });

    Future<void> openEdit(WidgetTester tester) async {
      await pumpVault(tester);
      await tester.tap(find.text('Posta'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Düzenle'));
      await tester.pumpAndSettle();
    }

    testWidgets('listede bağlı uygulamanın simgesi, diğerlerinde baş harf', (
      tester,
    ) async {
      await pumpKeyKey(
        tester,
        status: VaultOpen(service.newSession()),
        service: service,
        logins: logins,
        packages: FakeAppPackages(installed: {'com.example.posta'}),
      );

      Finder inCard(String name, Finder matching) => find.descendant(
        of: find.widgetWithText(KkCard, name),
        matching: matching,
      );
      expect(inCard('Posta', find.byType(Image)), findsOneWidget);
      expect(inCard('İş Bankası', find.text('İ')), findsOneWidget);
      expect(inCard('İş Bankası', find.byType(Image)), findsNothing);
      expect(inCard('Posta', find.byType(CircleAvatar)), findsNothing);
    });

    testWidgets('ayrıntıda görünüyor', (tester) async {
      await pumpVault(tester);
      await tester.tap(find.text('Posta'));
      await tester.pumpAndSettle();

      expect(find.text('Uygulama'), findsOneWidget);
      expect(find.text('com.example.posta'), findsOneWidget);
    });

    testWidgets('düzenlemede imzasıyla görünüyor ve korunuyor', (tester) async {
      await openEdit(tester);
      expect(find.text('com.example.posta'), findsOneWidget);
      expect(find.text('İmza AB:AB:AB:AB:AB:AB:AB:AB…'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Ad'), 'E-posta');
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.pumpAndSettle();

      expect(logins.items.first.content.name, 'E-posta');
      expect(logins.items.first.content.apps, [app]);
    });

    testWidgets('düzenlemede kaldırılabiliyor', (tester) async {
      await openEdit(tester);

      await tester.tap(find.byTooltip('Uygulamayı kaldır'));
      await tester.pump();
      expect(find.text('com.example.posta'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.pumpAndSettle();

      final content = logins.items.first.content;
      expect(content.apps, isEmpty);
      expect(content.urls, ['https://mail.example.com']);
    });
  });

  group('çöp kutusu', () {
    Future<void> trashPosta(WidgetTester tester) async {
      await pumpVault(tester);
      await tester.tap(find.text('Posta'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Diğer işlemler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çöp kutusuna taşı'));
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

      await openMenu(tester);
      await tester.tap(find.text('Çöp kutusu'));
      await tester.pumpAndSettle();
      expect(find.text('Posta'), findsOneWidget);

      await tester.tap(find.byTooltip('Geri al'));
      await tester.pumpAndSettle();
      expect(find.text('Çöp kutusu boş.'), findsOneWidget);
      expect(logins.items.first.content.isTrashed, isFalse);
    });

    testWidgets('kalıcı silme onay istiyor', (tester) async {
      await trashPosta(tester);
      await openMenu(tester);
      await tester.tap(find.text('Çöp kutusu'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Kalıcı olarak sil'));
      await tester.pumpAndSettle();
      expect(find.text('Kalıcı olarak silinsin mi?'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(logins.items, hasLength(3));

      await tester.tap(find.byTooltip('Kalıcı olarak sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Kalıcı olarak sil'));
      await tester.pumpAndSettle();
      expect(logins.items, hasLength(2));
      expect(find.text('Çöp kutusu boş.'), findsOneWidget);
    });
  });

  testWidgets('yazmak otomatik kilit süresini yeniliyor', (tester) async {
    await pumpVault(tester);
    await openAddPassword(tester);

    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(minutes: 4));
      await tester.enterText(find.widgetWithText(TextField, 'Ad'), 'n$i');
      await tester.pump();
    }
    expect(find.text('KeyKey kilitli'), findsNothing);

    await tester.pump(const Duration(minutes: 5, seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('KeyKey kilitli'), findsOneWidget);
  });
}

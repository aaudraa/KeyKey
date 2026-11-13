import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/last_saved.dart';
import 'package:keykey/app/ui/glass_nav_bar.dart';
import 'package:keykey/app/ui/kk_card.dart';
import 'package:keykey/app/ui/kk_done_mark.dart';
import 'package:keykey/app/ui/kk_motion.dart';
import 'package:keykey/app/ui/kk_shake.dart';
import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/authenticator/presentation/otp_display.dart';
import 'package:keykey/features/authenticator/presentation/otp_ring.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/add_flow.dart';
import '../../support/fake_vault_service.dart';

/// Son kayıt durumunu dinleyenleri sayar.
class _CountingLastSaved extends LastSaved {
  int active = 0;

  @override
  String? build() {
    ref
      ..onAddListener(() => active++)
      ..onRemoveListener(() => active--);
    return super.build();
  }
}

void main() {
  // RFC 4226 Ek D anahtarı: sayaç 1 → 287082, 2 → 359152, 0 → 755224.
  final rfcSecret = ascii.encode('12345678901234567890');

  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeOtpRepository otps;
  late RecordingClipboard clipboard;
  late DateTime now;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    // Ekran dışına düşen dokunuş başka bir düğmeye basabilir, sessiz geçmesin.
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);

  OtpContent totp(String issuer, {String account = '', bool favorite = false}) {
    return OtpContent(
      parameters: OtpParameters.totp(
        secret: issuer == 'GitHub' ? rfcSecret : utf8.encode('$issuer-anahtar'),
      ),
      issuer: issuer,
      account: account,
      favorite: favorite,
    );
  }

  setUp(() {
    service = FakeVaultService(sodium);
    clipboard = RecordingClipboard();
    // 30. saniye: TOTP sayacı 1, sürenin tamamı kalıyor.
    now = DateTime.fromMillisecondsSinceEpoch(30000, isUtc: true);
    otps = FakeOtpRepository(
      items: [
        FakeOtpRepository.item(
          totp('GitHub', account: 'ali@example.com'),
          id: 1,
        ),
        FakeOtpRepository.item(totp('Posta'), id: 2),
        FakeOtpRepository.item(totp('Zeka', favorite: true), id: 3),
      ],
    );
  });

  /// Geri sayım her karede yeni kare istediği için pumpAndSettle bitmez.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openAuthenticator(
    WidgetTester tester, {
    Locale locale = const Locale('tr'),
  }) async {
    await pumpKeyKey(
      tester,
      status: VaultOpen(service.newSession()),
      service: service,
      otps: otps,
      clock: () => now,
      clipboard: clipboard,
      locale: locale,
    );
    await tester.tap(find.byIcon(Icons.shield_outlined));
    await settle(tester);
  }

  Finder tileOf(int id) => find.byKey(
    ValueKey(otpIdHex(otps.items.firstWhere((i) => i.id[15] == id))),
  );

  /// Küçük test ekranında alttaki düğmeler önce görünür alana kaydırılır.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await settle(tester);
    await tester.tap(finder);
    await settle(tester);
  }

  /// Kartın işlemleri uzun basınca alttan açılan pencerede.
  Future<void> openMenu(WidgetTester tester, int id) async {
    await tester.longPress(tileOf(id));
    await settle(tester);
  }

  Future<void> openScreenMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Diğer işlemler'));
    await settle(tester);
  }

  group('liste', () {
    testWidgets('saat ilerledikçe dinleyiciler birikmez', (tester) async {
      final counted = _CountingLastSaved();
      var time = now;
      await pumpKeyKey(
        tester,
        status: VaultOpen(service.newSession()),
        service: service,
        otps: otps,
        clock: () => time,
        clipboard: clipboard,
        extraOverrides: [lastSavedProvider.overrideWith(() => counted)],
      );
      await tester.tap(find.byIcon(Icons.shield_outlined));
      await settle(tester);
      final before = counted.active;
      for (var i = 0; i < 20; i++) {
        time = time.add(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(counted.active, before);
    });

    testWidgets('kodlar gösteriliyor, favori önde', (tester) async {
      await openAuthenticator(tester);

      expect(find.text('287 082'), findsOneWidget);
      expect(find.text('ali@example.com'), findsOneWidget);
      final titles = [
        for (final text in tester.widgetList<Text>(find.byType(Text)))
          if (['GitHub', 'Posta', 'Zeka'].contains(text.data)) text.data,
      ];
      expect(titles, ['Zeka', 'GitHub', 'Posta']);
      expect(find.textContaining('Sıradaki'), findsNothing);
    });

    testWidgets('süre halkası kalan saniyeyi okutuyor', (tester) async {
      await openAuthenticator(tester);
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('30 saniye kaldı')), findsWidgets);
      expect(find.byType(OtpRing), findsWidgets);
      handle.dispose();
    });

    testWidgets('kartın işlemleri ekran okuyucuda da var', (tester) async {
      await openAuthenticator(tester);
      final handle = tester.ensureSemantics();
      final node = tester.getSemantics(
        find.descendant(of: tileOf(2), matching: find.byType(InkWell)).first,
      );
      final labels = [
        for (final id
            in node.getSemanticsData().customSemanticsActionIds ??
                const <int>[])
          CustomSemanticsAction.getAction(id)!.label,
      ];
      expect(
        labels,
        unorderedEquals(['Düzenle', 'Favorilere ekle', 'Çöp kutusuna taşı']),
      );
      handle.dispose();
    });

    testWidgets('%200 yazıda kartlar taşmıyor', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openAuthenticator(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('287 082'), findsOneWidget);
    });

    testWidgets('dokununca kod boşluksuz kopyalanıyor', (tester) async {
      await openAuthenticator(tester);

      await tester.tap(find.text('287 082'));
      await settle(tester);

      expect(clipboard.copied, ['287082']);
      expect(find.textContaining('Kopyalandı'), findsOneWidget);
    });

    testWidgets('saat ilerledikçe geri sayım ve kod değişiyor', (tester) async {
      await openAuthenticator(tester);
      expect(find.text('30'), findsWidgets);

      now = DateTime.fromMillisecondsSinceEpoch(45500, isUtc: true);
      await settle(tester);
      expect(find.text('15'), findsWidgets);
      expect(find.text('287 082'), findsOneWidget);

      now = DateTime.fromMillisecondsSinceEpoch(60000, isUtc: true);
      await settle(tester);
      expect(find.text('359 152'), findsOneWidget);
    });

    testWidgets('süre bitmek üzereyken sıradaki kod görünüyor', (tester) async {
      now = DateTime.fromMillisecondsSinceEpoch(50000, isUtc: true);
      await openAuthenticator(tester);

      expect(find.text('Sıradaki: 359 152'), findsOneWidget);
    });

    testWidgets('kartlar aynı boyda, sıradaki kod çıkınca da büyümüyor', (
      tester,
    ) async {
      Set<double> heights() => {
        for (final id in [1, 2, 3]) tester.getSize(tileOf(id)).height,
      };

      await openAuthenticator(tester);
      expect(heights(), {72.0});

      now = DateTime.fromMillisecondsSinceEpoch(50000, isUtc: true);
      await settle(tester);
      // Saat sağlayıcısı yeni zamanı bir sonraki tıkta okur.
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Sıradaki'), findsWidgets);
      expect(heights(), {72.0});
    });

    testWidgets('HOTP kartı TOTP kartıyla aynı boyda, kod üret düğmesi var', (
      tester,
    ) async {
      otps.items.add(
        FakeOtpRepository.item(
          OtpContent(
            parameters: OtpParameters.hotp(secret: rfcSecret),
            issuer: 'Sayaçlı',
          ),
          id: 9,
        ),
      );
      await openAuthenticator(tester);

      expect(tester.getSize(tileOf(9)).height, 72);
      expect(
        find.descendant(
          of: tileOf(9),
          matching: find.widgetWithText(TextButton, 'Kod üret'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('bağlı parola kaydının uygulama simgesi kartta', (
      tester,
    ) async {
      final login = FakeLoginRepository.item(
        LoginContent(
          name: 'GitHub',
          apps: [
            LoginApp(
              packageName: 'com.github.android',
              certsSha256: ['c' * 64],
            ),
          ],
        ),
        id: 7,
      );
      otps.items[0] = FakeOtpRepository.item(
        totp('GitHub', account: 'ali@example.com').copyWith(loginId: login.id),
        id: 1,
      );
      await pumpKeyKey(
        tester,
        status: VaultOpen(service.newSession()),
        service: service,
        otps: otps,
        logins: FakeLoginRepository(items: [login]),
        clock: () => now,
        clipboard: clipboard,
        packages: FakeAppPackages(installed: {'com.github.android'}),
      );
      await tester.tap(find.byIcon(Icons.shield_outlined));
      await settle(tester);

      expect(
        find.descendant(of: tileOf(1), matching: find.byType(Image)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tileOf(2), matching: find.byType(Image)),
        findsNothing,
      );
    });

    testWidgets('arama servis ve hesap adında', (tester) async {
      await openAuthenticator(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Ara'), 'ALİ');
      await settle(tester);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('Posta'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Ara'), 'yok');
      await settle(tester);
      expect(find.text('Eşleşen hesap yok.'), findsOneWidget);
    });

    testWidgets('hesap yoksa yönlendiren metin', (tester) async {
      otps.items.clear();
      await openAuthenticator(tester);

      expect(find.textContaining('Henüz 2FA hesabı yok'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Ara'), findsNothing);
    });

    testWidgets('okunamayan kayıt sayısı bildiriliyor', (tester) async {
      otps = FakeOtpRepository(items: otps.items, unreadableCount: 2);
      await openAuthenticator(tester);

      expect(find.textContaining('2 kayıt okunamadı'), findsOneWidget);
    });

    testWidgets('HOTP kodu istenince üretiliyor ve sayaç ilerliyor', (
      tester,
    ) async {
      otps.items
        ..clear()
        ..add(
          FakeOtpRepository.item(
            OtpContent(
              parameters: OtpParameters.hotp(secret: rfcSecret),
              issuer: 'Sayaçlı',
            ),
            id: 9,
          ),
        );
      await openAuthenticator(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Kod üret'));
      await settle(tester);
      expect(find.text('755 224'), findsOneWidget);
      expect(otps.items.single.content.parameters.counter, 1);

      await tester.tap(find.byTooltip('Kod üret'));
      await settle(tester);
      expect(find.text('287 082'), findsOneWidget);
      expect(otps.items.single.content.parameters.counter, 2);

      await tester.tap(find.text('287 082'));
      await settle(tester);
      expect(clipboard.copied, ['287082']);
    });

    testWidgets('saat yardımı cihaz saatini gösteriyor', (tester) async {
      await openAuthenticator(tester);

      await openScreenMenu(tester);
      await tester.tap(find.text('Kodlar tutmuyor mu?'));
      await settle(tester);

      expect(find.text('Cihaz saatini kontrol et'), findsOneWidget);
      expect(find.textContaining('Cihaz saati: '), findsOneWidget);
      expect(find.textContaining('1970'), findsOneWidget);
      await tester.tap(find.text('Kapat'));
      await settle(tester);
      expect(find.text('Cihaz saatini kontrol et'), findsNothing);
    });

    testWidgets('İngilizce', (tester) async {
      otps.items.clear();
      await openAuthenticator(tester, locale: const Locale('en'));

      expect(find.textContaining('No 2FA accounts yet'), findsOneWidget);
    });
  });

  group('menü', () {
    testWidgets('favori', (tester) async {
      await openAuthenticator(tester);

      await openMenu(tester, 2);
      await tester.tap(find.text('Favorilere ekle'));
      await settle(tester);

      expect(otps.items[1].content.favorite, isTrue);
    });

    testWidgets('çöp kutusuna taşı ve geri al', (tester) async {
      await openAuthenticator(tester);

      await openMenu(tester, 2);
      await tester.tap(find.text('Çöp kutusuna taşı'));
      await settle(tester);
      expect(find.text('Posta'), findsNothing);
      expect(otps.items[1].content.isTrashed, isTrue);

      await tester.tap(find.text('Geri al'));
      await settle(tester);
      expect(find.text('Posta'), findsOneWidget);
      expect(otps.items[1].content.isTrashed, isFalse);
    });

    testWidgets('düzenleme', (tester) async {
      await openAuthenticator(tester);

      await openMenu(tester, 2);
      await tester.tap(find.text('Düzenle'));
      await settle(tester);
      // Kayıtlı hesabın anahtarı gizli açılır.
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Gizli anahtar'))
            .obscureText,
        isTrue,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Servis'),
        'E-posta',
      );
      await tester.tap(find.text('Kaydet'));
      await settle(tester);
      // Onay işareti, ardından kapanış geçişi.
      await settle(tester);

      expect(find.text('E-posta'), findsOneWidget);
      expect(otps.items[1].content.issuer, 'E-posta');
      expect(otps.items[1].content.parameters, totp('Posta').parameters);
    });
  });

  group('elle ekleme', () {
    Future<void> openForm(WidgetTester tester) async {
      await openAuthenticator(tester);
      await openAddOtp(
        tester,
        'Anahtarı elle gir',
        settle: () => settle(tester),
      );
    }

    testWidgets('anahtar ve servis adıyla kaydediliyor', (tester) async {
      await openForm(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Servis'), 'Yeni');
      await tester.enterText(
        find.widgetWithText(TextField, 'Gizli anahtar'),
        'jbsw y3dp ehpk 3pxp',
      );
      await tester.tap(find.text('Kaydet'));
      await settle(tester);
      // Onay işareti, ardından kapanış geçişi.
      await settle(tester);

      final added = otps.items.last.content;
      expect(added.issuer, 'Yeni');
      expect(
        added.parameters,
        OtpParameters.totp(secret: Base32.decodeCanonical('JBSWY3DPEHPK3PXP')),
      );
      expect(find.text('Yeni'), findsOneWidget);
    });

    testWidgets('kaydedince onay işareti, çift basış tek hesap, kart '
        'listede bir kez parlar', (tester) async {
      await openForm(tester);
      final before = otps.items.length;
      await tester.enterText(find.widgetWithText(TextField, 'Servis'), 'Yeni');
      await tester.enterText(
        find.widgetWithText(TextField, 'Gizli anahtar'),
        'jbsw y3dp ehpk 3pxp',
      );
      await tester.tap(find.text('Kaydet'));
      await tester.tap(find.text('Kaydet'));

      var sawDone = false;
      var maxFlash = 0.0;
      final flash = find.descendant(
        of: find.widgetWithText(KkCard, 'Yeni'),
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
      await settle(tester);

      expect(sawDone, isTrue);
      expect(otps.items, hasLength(before + 1));
      expect(find.text('Yeni 2FA hesabı'), findsNothing);
      expect(maxFlash, greaterThan(0.05));
    });

    testWidgets('geri tuşu kaydedilmemişi sormadan silmiyor', (tester) async {
      await openForm(tester);
      // Form ekranında alt menü yok; geri tuşu tek çıkış yolu.
      expect(find.byType(GlassNavBar), findsNothing);
      await tester.enterText(find.widgetWithText(TextField, 'Servis'), 'Yarım');
      await settle(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Değişiklikler silinsin mi?'), findsOneWidget);
      await tester.tap(find.text('Düzenlemeye devam et'));
      await settle(tester);
      expect(find.text('Yeni 2FA hesabı'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Yarım'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.tap(find.text('Sil'));
      await settle(tester);
      expect(find.text('Yeni 2FA hesabı'), findsNothing);
      expect(otps.items, hasLength(3));
    });

    testWidgets('boş formda geri tuşu listeye döndürüyor', (tester) async {
      await openForm(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.text('Yeni 2FA hesabı'), findsNothing);
      expect(find.text('287 082'), findsOneWidget);
    });

    testWidgets('geçersiz anahtar ve eksik ad kaydedilmiyor', (tester) async {
      await openForm(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Gizli anahtar'),
        'BU-ANAHTAR-01',
      );
      await tester.tap(find.text('Kaydet'));
      await settle(tester);

      expect(
        find.text('“0” anahtarlarda bulunmaz, büyük O harfi olabilir.'),
        findsOneWidget,
      );
      expect(find.text('Servis veya hesap adı gir.'), findsOneWidget);
      expect(otps.items, hasLength(3));
    });

    testWidgets('hatalı alanlar titrer, telefon bir kez titreşir', (
      tester,
    ) async {
      final haptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await openForm(tester);
      await tester.tap(find.text('Kaydet'));
      // Hata metinleri çizilir, titreme kareden sonra başlar.
      await tester.pump();
      await tester.pump();
      await tester.pump(KkMotion.shake ~/ 4);
      final shaking = tester
          .widgetList<KkShake>(find.byType(KkShake))
          .where((s) => s.enabled);
      expect(shaking, isNotEmpty);
      final dx = tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byWidget(shaking.first),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .storage[12];
      expect(dx.abs(), greaterThan(0.5));
      expect(haptics, hasLength(1));
      await settle(tester);
    });

    testWidgets('çok kısa anahtar kaydederken reddediliyor', (tester) async {
      await openForm(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Servis'), 'Kısa');
      await tester.enterText(
        find.widgetWithText(TextField, 'Gizli anahtar'),
        'M',
      );
      await settle(tester);
      expect(find.textContaining('Geçerli bir anahtar değil'), findsNothing);

      await tester.tap(find.text('Kaydet'));
      await settle(tester);
      expect(find.textContaining('Geçerli bir anahtar değil'), findsOneWidget);
      expect(otps.items, hasLength(3));
    });

    testWidgets('anahtar görünür, büyük harfli ve gruplu yazılıyor', (
      tester,
    ) async {
      await openForm(tester);
      final field = find.widgetWithText(TextField, 'Gizli anahtar');

      expect(tester.widget<TextField>(field).obscureText, isFalse);
      await tester.enterText(field, 'jbswy3dpehpk3pxp');
      await settle(tester);

      expect(find.text('JBSW Y3DP EHPK 3PXP'), findsOneWidget);
    });

    group('yapıştır düğmesi', () {
      void mockClipboard(WidgetTester tester, String? text) {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => call.method == 'Clipboard.getData'
              ? (text == null ? null : <String, Object?>{'text': text})
              : null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
      }

      testWidgets('panodaki anahtar gruplanarak geliyor', (tester) async {
        mockClipboard(tester, '  jbsw y3dp ehpk 3pxp\n');
        await openForm(tester);

        await tester.tap(find.text('Yapıştır'));
        await settle(tester);
        expect(find.text('JBSW Y3DP EHPK 3PXP'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextField, 'Servis'),
          'Yapışık',
        );
        await tester.tap(find.text('Kaydet'));
        await settle(tester);
        expect(
          otps.items.last.content.parameters.secret,
          Base32.decodeCanonical('JBSWY3DPEHPK3PXP'),
        );
      });

      testWidgets('panodaki bağlantı formu dolduruyor', (tester) async {
        mockClipboard(
          tester,
          'otpauth://totp/Banka:veli?secret=JBSWY3DPEHPK3PXP',
        );
        await openForm(tester);

        await tester.tap(find.text('Yapıştır'));
        await settle(tester);

        expect(find.text('Bilgiler bağlantıdan dolduruldu.'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'Banka'), findsOneWidget);
        expect(find.text('JBSW Y3DP EHPK 3PXP'), findsOneWidget);
      });

      testWidgets('pano boşsa söyleniyor', (tester) async {
        mockClipboard(tester, null);
        await openForm(tester);

        await tester.tap(find.text('Yapıştır'));
        await settle(tester);

        expect(find.text('Panoda metin yok.'), findsOneWidget);
      });
    });

    testWidgets('yanlış karakter yazarken hemen söyleniyor', (tester) async {
      await openForm(tester);
      final field = find.widgetWithText(TextField, 'Gizli anahtar');

      await tester.enterText(field, 'JBSW1');
      await settle(tester);
      expect(
        find.text('“1” anahtarlarda bulunmaz, büyük I veya L harfi olabilir.'),
        findsOneWidget,
      );

      await tester.enterText(field, 'JBSW8');
      await settle(tester);
      expect(
        find.text('“8” anahtarlarda bulunmaz, büyük B harfi olabilir.'),
        findsOneWidget,
      );

      await tester.enterText(field, 'JBSWş');
      await settle(tester);
      expect(find.textContaining('“ş” anahtarlarda bulunmaz.'), findsOneWidget);

      await tester.enterText(field, 'JBSWB');
      await settle(tester);
      expect(find.textContaining('anahtarlarda bulunmaz'), findsNothing);
    });

    testWidgets('Türkçe klavyenin İ harfiyle yazılan anahtar kaydediliyor', (
      tester,
    ) async {
      await openForm(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Servis'),
        'Türkçe',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Gizli anahtar'),
        'İİİİ İİİİ',
      );
      await tester.tap(find.text('Kaydet'));
      await settle(tester);

      expect(
        otps.items.last.content.parameters.secret,
        Base32.decodeLenient('IIIIIIII'),
      );
    });

    testWidgets('otpauth bağlantısı yapıştırılınca form doluyor', (
      tester,
    ) async {
      await openForm(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Gizli anahtar'),
        'otpauth://hotp/Banka:veli?secret=JBSWY3DPEHPK3PXP&counter=4&digits=8',
      );
      await settle(tester);

      expect(find.text('Bilgiler bağlantıdan dolduruldu.'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Banka'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'veli'), findsOneWidget);

      await tester.tap(find.text('Kaydet'));
      await settle(tester);
      final added = otps.items.last.content;
      expect(added.parameters.kind, OtpKind.hotp);
      expect(added.parameters.counter, 4);
      expect(added.parameters.digits, 8);
    });

    testWidgets('desteklenmeyen bağlantı anlaşılır hata veriyor', (
      tester,
    ) async {
      await openForm(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Gizli anahtar'),
        'otpauth://steam/x?secret=JBSWY3DPEHPK3PXP',
      );
      await settle(tester);

      expect(find.textContaining('Bu kod türü desteklenmiyor'), findsOneWidget);
    });

    testWidgets('yeni hesapta yalnızca üç temel alan, menü yok', (
      tester,
    ) async {
      await openForm(tester);
      for (final label in ['Servis', 'Hesap', 'Gizli anahtar']) {
        expect(find.widgetWithText(TextField, label), findsOneWidget);
      }
      expect(find.widgetWithText(TextField, 'Notlar'), findsNothing);
      expect(find.text('Algoritma'), findsNothing);
      expect(find.byType(GlassNavBar), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Kaydet'), findsOneWidget);
    });

    testWidgets('gelişmiş ayarlar: SHA-512, 8 hane, 60 saniye', (tester) async {
      await openForm(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Servis'), 'Özel');
      await tester.enterText(
        find.widgetWithText(TextField, 'Gizli anahtar'),
        'JBSWY3DPEHPK3PXP',
      );
      await tapVisible(tester, find.text('Daha fazla seçenek'));
      await tapVisible(tester, find.widgetWithText(ActionChip, 'Gelişmiş'));
      await tapVisible(tester, find.text('SHA512'));
      await tapVisible(tester, find.text('8'));
      await tester.enterText(find.widgetWithText(TextField, '30'), '60');
      await tester.tap(find.text('Kaydet'));
      await settle(tester);

      final parameters = otps.items.last.content.parameters;
      expect(parameters.algorithm, OtpAlgorithm.sha512);
      expect(parameters.digits, 8);
      expect(parameters.period, 60);
    });

    testWidgets('geçersiz süre gelişmiş bölümde gösteriliyor', (tester) async {
      await openForm(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Servis'), 'Özel');
      await tester.enterText(
        find.widgetWithText(TextField, 'Gizli anahtar'),
        'JBSWY3DPEHPK3PXP',
      );
      await tapVisible(tester, find.text('Daha fazla seçenek'));
      await tapVisible(tester, find.widgetWithText(ActionChip, 'Gelişmiş'));
      await tester.enterText(find.widgetWithText(TextField, '30'), '0');
      await tester.tap(find.text('Kaydet'));
      await settle(tester);

      expect(
        find.text('1 ile 3600 arasında bir tam sayı gir.'),
        findsOneWidget,
      );
      expect(otps.items, hasLength(3));
    });
  });

  group('çöp kutusu', () {
    setUp(() {
      otps.items[1] = FakeOtpRepository.item(
        totp('Posta').copyWith(trashedAt: DateTime.utc(2026, 11)),
        id: 2,
      );
    });

    Future<void> openTrash(WidgetTester tester) async {
      await openAuthenticator(tester);
      await openScreenMenu(tester);
      await tester.tap(find.text('Çöp kutusu'));
      await settle(tester);
    }

    testWidgets('geri alma', (tester) async {
      await openTrash(tester);

      await tester.tap(find.byTooltip('Geri al'));
      await settle(tester);

      expect(otps.items[1].content.isTrashed, isFalse);
      expect(find.text('Çöp kutusu boş.'), findsOneWidget);
    });

    testWidgets('kalıcı silme uyarıyla soruluyor', (tester) async {
      await openTrash(tester);

      await tester.tap(find.byTooltip('Kalıcı olarak sil'));
      await settle(tester);
      expect(
        find.textContaining('servise giriş yapamayabilirsin'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Kalıcı olarak sil'));
      await settle(tester);

      expect(otps.items, hasLength(2));
      expect(find.text('Çöp kutusu boş.'), findsOneWidget);
    });
  });
}

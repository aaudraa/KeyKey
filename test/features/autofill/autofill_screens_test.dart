import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/platform/sensitive_clipboard.dart';
import 'package:keykey/features/authenticator/application/otp_clock.dart';
import 'package:keykey/features/authenticator/application/otp_generator.dart';
import 'package:keykey/features/authenticator/application/otps_controller.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/application/autofill_matches.dart';
import 'package:keykey/features/autofill/domain/public_suffix_list.dart';
import 'package:keykey/features/autofill/presentation/autofill_app.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';

/// Android tarafının yerine geçer; doldurulanı ve kapatılmayı kaydeder.
class FakeAutofillBridge implements AutofillBridge {
  new(this.target);

  final AutofillTarget? target;
  ({String username, String password})? filled;
  bool cancelled = false;

  @override
  Future<AutofillTarget?> currentTarget() async => target;

  @override
  Future<bool> hasSigningCertificates(
    String packageName,
    List<String> certs,
  ) async =>
      packageName == target?.packageName &&
      certs.every(target!.certsSha256.contains);

  @override
  Future<void> fill({
    required String username,
    required String password,
  }) async => filled = (username: username, password: password);

  @override
  Future<void> cancel() async => cancelled = true;
}

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeLoginRepository logins;
  late FakeOtpRepository otps;
  late FakeSettingsRepository settings;
  late RecordingClipboard clipboard;
  late PublicSuffixList psl;
  final now = DateTime.utc(2026, 11, 7, 9);

  const cert =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const app = AutofillTarget(
    packageName: 'io.github.aaudraa.ornekgiris',
    appLabel: 'Örnek Giriş',
    certsSha256: [cert],
  );

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    // rootBundle büyük dosyayı izolede okuyor, sahte zamanlı testte bitmiyor.
    psl = PublicSuffixList.parse(File(publicSuffixListPath).readAsStringSync());
  });

  setUp(() {
    service = FakeVaultService(sodium);
    otps = FakeOtpRepository();
    settings = FakeSettingsRepository();
    clipboard = RecordingClipboard();
    logins = FakeLoginRepository(
      items: [
        FakeLoginRepository.item(
          const LoginContent(
            name: 'Banka',
            username: 'ali@example.com',
            password: 'banka-parolasi',
            urls: ['https://banka.example.com'],
          ),
          id: 1,
        ),
        FakeLoginRepository.item(
          const LoginContent(
            name: 'Posta',
            username: 'ali',
            password: 'posta-parolasi',
          ),
          id: 2,
        ),
        FakeLoginRepository.item(
          LoginContent(
            name: 'Örnek hesap',
            username: 'veli',
            password: 'ornek-parolasi',
            apps: [
              LoginApp(
                packageName: 'io.github.aaudraa.ornekgiris',
                certsSha256: const [cert],
              ),
            ],
          ),
          id: 3,
        ),
      ],
    );
  });

  Future<FakeAutofillBridge> pumpAutofill(
    WidgetTester tester, {
    required VaultStatus status,
    AutofillTarget? target = app,
  }) async {
    tester.platformDispatcher.localesTestValue = [const Locale('tr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final bridge = FakeAutofillBridge(target);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultServiceProvider.overrideWithValue(service),
          initialVaultStatusProvider.overrideWithValue(status),
          loginRepositoryFactoryProvider.overrideWithValue((_) => logins),
          settingsRepositoryFactoryProvider.overrideWithValue((_) => settings),
          otpRepositoryFactoryProvider.overrideWithValue((_) => otps),
          sensitiveClipboardProvider.overrideWithValue(clipboard),
          otpClockProvider.overrideWithValue(() => now),
          autofillBridgeProvider.overrideWithValue(bridge),
          publicSuffixListProvider.overrideWith((ref) => psl),
        ],
        child: const AutofillApp(),
      ),
    );
    await tester.pumpAndSettle();
    return bridge;
  }

  testWidgets('istek yoksa kapatılabilir bir mesaj gösteriliyor', (
    tester,
  ) async {
    final bridge = await pumpAutofill(
      tester,
      status: VaultLocked(service.header),
      target: null,
    );

    expect(find.text('Doldurulacak bir form yok.'), findsOneWidget);
    await tester.tap(find.text('Kapat'));
    await tester.pump();
    expect(bridge.cancelled, isTrue);
  });

  testWidgets('kasa yoksa önce kurulması söyleniyor', (tester) async {
    await pumpAutofill(tester, status: const VaultNotSetUp());

    expect(find.text("Önce KeyKey'de bir kasa oluştur."), findsOneWidget);
  });

  testWidgets('kilitliyken kayıt adı görünmüyor, kurtarma yok', (tester) async {
    await pumpAutofill(tester, status: VaultLocked(service.header));

    expect(find.text('Örnek Giriş için'), findsOneWidget);
    expect(find.text('Parolamı unuttum'), findsNothing);
    expect(find.text('Banka'), findsNothing);
    expect(find.text('ali@example.com'), findsNothing);
  });

  testWidgets('ana parolayla açılıyor ve kayıtlar listeleniyor', (
    tester,
  ) async {
    await pumpAutofill(tester, status: VaultLocked(service.header));

    await tester.enterText(
      find.byType(TextField),
      FakeVaultService.correctPassword,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Banka'), findsOneWidget);
    expect(find.text('Posta'), findsOneWidget);
  });

  testWidgets('eşleşen kayıt sormadan dolduruluyor ve kasa kilitleniyor', (
    tester,
  ) async {
    final bridge = await pumpAutofill(
      tester,
      status: VaultOpen(service.newSession()),
    );

    await tester.tap(find.text('Örnek hesap'));
    await tester.pumpAndSettle();

    expect(find.text('Doldurmadan önce'), findsNothing);
    expect(bridge.filled, (username: 'veli', password: 'ornek-parolasi'));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AutofillHome)),
    );
    expect(container.read(vaultControllerProvider), isA<VaultLocked>());
    // Ekran kapanırken kilit ekranı ve parmak izi penceresi yeniden açılmaz.
    expect(find.text('KeyKey kilitli'), findsNothing);
    expect(find.text('Örnek hesap'), findsNothing);
  });

  testWidgets('arama süzüyor', (tester) async {
    await pumpAutofill(tester, status: VaultOpen(service.newSession()));

    await tester.enterText(find.widgetWithText(TextField, 'Ara'), 'posta');
    await tester.pump();

    expect(find.text('Posta'), findsOneWidget);
    expect(find.text('Banka'), findsNothing);
  });

  group('2FA kodu', () {
    // "Örnek hesap" kaydının kimliği.
    final loginId = FakeLoginRepository.item(
      const LoginContent(name: ''),
      id: 3,
    ).id;
    final parameters = OtpParameters.totp(secret: utf8.encode('ornek-anahtar'));

    testWidgets('bağlı TOTP kodu doldurmadan önce kopyalanıyor', (
      tester,
    ) async {
      otps.items.add(
        FakeOtpRepository.item(
          OtpContent(parameters: parameters, loginId: loginId),
        ),
      );
      final bridge = await pumpAutofill(
        tester,
        status: VaultOpen(service.newSession()),
      );

      await tester.tap(find.text('Örnek hesap'));
      await tester.pumpAndSettle();

      expect(clipboard.copied, [OtpGenerator.codeFor(parameters, now)]);
      expect(bridge.filled?.username, 'veli');
    });

    testWidgets('ayar kapalıysa kopyalanmıyor', (tester) async {
      settings.settings = const AppSettings(
        otpRequireAuth: false,
        autofillCopyOtp: false,
      );
      otps.items.add(
        FakeOtpRepository.item(
          OtpContent(parameters: parameters, loginId: loginId),
        ),
      );
      final bridge = await pumpAutofill(
        tester,
        status: VaultOpen(service.newSession()),
      );

      await tester.tap(find.text('Örnek hesap'));
      await tester.pumpAndSettle();

      expect(clipboard.copied, isEmpty);
      expect(bridge.filled?.username, 'veli');
    });

    testWidgets('bağlı hesap yoksa kopyalanmıyor', (tester) async {
      final bridge = await pumpAutofill(
        tester,
        status: VaultOpen(service.newSession()),
      );

      await tester.tap(find.text('Örnek hesap'));
      await tester.pumpAndSettle();

      expect(clipboard.copied, isEmpty);
      expect(bridge.filled, isNotNull);
    });
  });

  testWidgets('kapat düğmesi hiçbir şey doldurmuyor', (tester) async {
    final bridge = await pumpAutofill(
      tester,
      status: VaultOpen(service.newSession()),
    );

    await tester.tap(find.byTooltip('Kapat'));
    await tester.pump();

    expect(bridge.cancelled, isTrue);
    expect(bridge.filled, isNull);
  });

  testWidgets('uygulamaya bağlı kayıt üstte, diğerleri altta', (tester) async {
    await pumpAutofill(tester, status: VaultOpen(service.newSession()));

    expect(find.text('Eşleşen kayıtlar'), findsOneWidget);
    expect(find.text('Diğer kayıtlar'), findsOneWidget);
    final matched = tester.getTopLeft(find.text('Örnek hesap')).dy;
    final header = tester.getTopLeft(find.text('Diğer kayıtlar')).dy;
    expect(matched, lessThan(header));
    expect(tester.getTopLeft(find.text('Banka')).dy, greaterThan(header));
  });

  testWidgets('imzası tutmayan uygulama eşleşmiyor', (tester) async {
    await pumpAutofill(
      tester,
      status: VaultOpen(service.newSession()),
      target: const AutofillTarget(
        packageName: 'io.github.aaudraa.ornekgiris',
        appLabel: 'Örnek Giriş',
        certsSha256: [
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        ],
      ),
    );

    expect(find.text('Eşleşen kayıtlar'), findsNothing);
    expect(
      find.text(
        'Örnek Giriş için kayıtlı giriş yok. Listeden kendin seçebilirsin.',
      ),
      findsOneWidget,
    );
    expect(find.text('Bütün kayıtlar'), findsOneWidget);
    expect(find.text('Örnek hesap'), findsOneWidget);
  });

  testWidgets('tarayıcıda aynı sitenin kaydı eşleşiyor', (tester) async {
    final bridge = await pumpAutofill(
      tester,
      status: VaultOpen(service.newSession()),
      target: const AutofillTarget(
        packageName: 'com.android.chrome',
        appLabel: 'Chrome',
        webDomain: 'giris.banka.example.com',
        webScheme: 'https',
      ),
    );

    expect(find.text('giris.banka.example.com için'), findsOneWidget);
    expect(find.text('Eşleşen kayıtlar'), findsOneWidget);
    final header = tester.getTopLeft(find.text('Diğer kayıtlar')).dy;
    expect(tester.getTopLeft(find.text('Banka')).dy, lessThan(header));
    expect(tester.getTopLeft(find.text('Örnek hesap')).dy, greaterThan(header));

    await tester.tap(find.text('Banka'));
    await tester.pumpAndSettle();
    // Eşleşen ve https: uyarı yok.
    expect(find.text('Doldurmadan önce'), findsNothing);
    expect(bridge.filled?.password, 'banka-parolasi');
  });

  testWidgets('arama eşleşmeyenleri de buluyor', (tester) async {
    await pumpAutofill(tester, status: VaultOpen(service.newSession()));

    await tester.enterText(find.widgetWithText(TextField, 'Ara'), 'banka');
    await tester.pump();

    expect(find.text('Banka'), findsOneWidget);
    expect(find.text('Örnek hesap'), findsNothing);
    expect(find.text('Eşleşen kayıtlar'), findsNothing);
  });

  group('uyarılar', () {
    testWidgets('eşleşmeyen kayıtta uyarı; vazgeçince doldurulmuyor', (
      tester,
    ) async {
      final bridge = await pumpAutofill(
        tester,
        status: VaultOpen(service.newSession()),
      );

      await tester.tap(find.text('Banka'));
      await tester.pumpAndSettle();

      expect(find.text('Doldurmadan önce'), findsOneWidget);
      expect(
        find.textContaining('Örnek Giriş uygulamasına bağlı değil'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Paket: io.github.aaudraa.ornekgiris'),
        findsOneWidget,
      );
      expect(find.textContaining('İmza (SHA-256): CC:CC:CC'), findsOneWidget);

      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(bridge.filled, isNull);
      expect(find.text('Banka'), findsOneWidget);
    });

    testWidgets('onaylanınca dolduruluyor, bağlanmadan', (tester) async {
      final bridge = await pumpAutofill(
        tester,
        status: VaultOpen(service.newSession()),
      );

      await tester.tap(find.text('Banka'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yine de doldur'));
      await tester.pumpAndSettle();

      expect(bridge.filled?.password, 'banka-parolasi');
      final banka = logins.items.firstWhere((i) => i.content.name == 'Banka');
      expect(banka.content.apps, isEmpty);
    });

    testWidgets('istenirse uygulama kayda bağlanıyor', (tester) async {
      final bridge = await pumpAutofill(
        tester,
        status: VaultOpen(service.newSession()),
      );

      await tester.tap(find.text('Banka'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uygulamayı bu kayda bağla'));
      await tester.pump();
      await tester.tap(find.text('Yine de doldur'));
      await tester.pumpAndSettle();

      expect(bridge.filled?.password, 'banka-parolasi');
      final banka = logins.items.firstWhere((i) => i.content.name == 'Banka');
      expect(banka.content.apps.single.packageName, app.packageName);
      expect(banka.content.apps.single.certsSha256, [cert]);
    });

    testWidgets('imzası tutmayan uygulamada sahte uyarısı, bağlama yok', (
      tester,
    ) async {
      final bridge = await pumpAutofill(
        tester,
        status: VaultOpen(service.newSession()),
        target: const AutofillTarget(
          packageName: 'io.github.aaudraa.ornekgiris',
          appLabel: 'Örnek Giriş',
          certsSha256: [
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          ],
        ),
      );

      await tester.tap(find.text('Örnek hesap'));
      await tester.pumpAndSettle();

      expect(find.text('Bu uygulama sahte olabilir'), findsOneWidget);
      expect(find.text('Uygulamayı bu kayda bağla'), findsNothing);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(bridge.filled, isNull);
    });

    testWidgets('WebView ve şifresiz bağlantı uyarıları', (tester) async {
      await pumpAutofill(
        tester,
        status: VaultOpen(service.newSession()),
        target: const AutofillTarget(
          packageName: 'io.github.aaudraa.ornekgiris',
          appLabel: 'Örnek Giriş',
          certsSha256: [cert],
          untrustedWebDomain: 'banka.example.com',
        ),
      );

      await tester.tap(find.text('Banka'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('kendini banka.example.com olarak tanıtıyor'),
        findsOneWidget,
      );
    });

    testWidgets('alan adı bildirmeyen WebView uyarısı', (tester) async {
      await pumpAutofill(
        tester,
        status: VaultOpen(service.newSession()),
        target: const AutofillTarget(
          packageName: 'io.github.aaudraa.ornekgiris',
          appLabel: 'Örnek Giriş',
          certsSha256: [cert],
          inWebView: true,
        ),
      );

      await tester.tap(find.text('Banka'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('sayfanın kime ait olduğunu doğrulayamaz'),
        findsOneWidget,
      );
    });

    testWidgets('http sayfasında eşleşen kayıt da uyarılıyor', (tester) async {
      await pumpAutofill(
        tester,
        status: VaultOpen(service.newSession()),
        target: const AutofillTarget(
          packageName: 'com.android.chrome',
          webDomain: 'banka.example.com',
          webScheme: 'http',
        ),
      );

      await tester.tap(find.text('Banka'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bağlantı şifresiz (http)'), findsOneWidget);
      expect(find.textContaining('kaydedilmemiş'), findsNothing);
      expect(find.textContaining('Paket:'), findsNothing);
    });
  });

  group('kaydetme', () {
    const saveApp = AutofillTarget(
      packageName: 'io.github.aaudraa.ornekgiris',
      appLabel: 'Örnek Giriş',
      certsSha256: [cert],
      save: AutofillSave(username: 'ayse', password: 'yeni-parola-1'),
    );

    LoginItem? saved(String username) {
      for (final item in logins.items) {
        if (item.content.username == username) return item;
      }
      return null;
    }

    testWidgets('kilitliyken yalnızca hedef görünüyor, değer görünmüyor', (
      tester,
    ) async {
      await pumpAutofill(
        tester,
        status: VaultLocked(service.header),
        target: saveApp,
      );

      expect(find.text('Örnek Giriş için kaydet'), findsOneWidget);
      expect(find.text('ayse'), findsNothing);
      expect(find.text('Örnek hesap'), findsNothing);
    });

    testWidgets('yeni kayıt uygulamaya bağlanıyor ve kasa kilitleniyor', (
      tester,
    ) async {
      final bridge = await pumpAutofill(
        tester,
        status: VaultLocked(service.header),
        target: saveApp,
      );
      await tester.enterText(
        find.byType(TextField),
        FakeVaultService.correctPassword,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text("KeyKey'e kaydet"), findsOneWidget);
      expect(find.text('Bağlanacak uygulama: Örnek Giriş'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.pumpAndSettle();

      final item = saved('ayse');
      expect(item, isNotNull);
      expect(item!.content.name, 'Örnek Giriş');
      expect(item.content.password, 'yeni-parola-1');
      expect(item.content.urls, isEmpty);
      expect(item.content.apps, [
        LoginApp(packageName: saveApp.packageName, certsSha256: const [cert]),
      ]);
      expect(bridge.cancelled, isTrue);
      expect(bridge.filled, isNull);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AutofillHome)),
      );
      expect(container.read(vaultControllerProvider), isA<VaultLocked>());
      expect(find.text('KeyKey kilitli'), findsNothing);
    });

    testWidgets('düzenlenen değerler kaydediliyor', (tester) async {
      await pumpAutofill(
        tester,
        status: VaultOpen(service.newSession()),
        target: saveApp,
      );

      await tester.enterText(find.widgetWithText(TextField, 'Ad'), 'İş');
      await tester.enterText(
        find.widgetWithText(TextField, 'Kullanıcı adı'),
        'ayse.k',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.pumpAndSettle();

      expect(saved('ayse.k')?.content.name, 'İş');
      expect(saved('ayse'), isNull);
    });

    testWidgets('tarayıcıda site adresi bağlanıyor', (tester) async {
      await pumpAutofill(
        tester,
        status: VaultOpen(service.newSession()),
        target: const AutofillTarget(
          packageName: 'com.android.chrome',
          certsSha256: [cert],
          webDomain: 'www.yeni.example.com',
          webScheme: 'https',
          save: AutofillSave(username: 'ayse', password: 'yeni-parola-1'),
        ),
      );

      expect(
        find.text('Bağlanacak site: https://www.yeni.example.com'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.pumpAndSettle();

      final item = saved('ayse')!;
      expect(item.content.name, 'yeni.example.com');
      expect(item.content.urls, ['https://www.yeni.example.com']);
      expect(item.content.apps, isEmpty);
    });

    testWidgets('WebView sayfası değil, uygulama bağlanıyor', (tester) async {
      await pumpAutofill(
        tester,
        status: VaultOpen(service.newSession()),
        target: const AutofillTarget(
          packageName: 'io.github.aaudraa.ornekgiris',
          appLabel: 'Örnek Giriş',
          certsSha256: [cert],
          untrustedWebDomain: 'banka.example.com',
          save: AutofillSave(username: 'ayse', password: 'yeni-parola-1'),
        ),
      );

      expect(find.textContaining('web sayfası gösteriyor'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.pumpAndSettle();

      final item = saved('ayse')!;
      expect(item.content.urls, isEmpty);
      expect(item.content.apps.single.packageName, saveApp.packageName);
    });

    testWidgets('imzası okunamayan uygulama bağlanmıyor ve söyleniyor', (
      tester,
    ) async {
      // Android uygulamayı KeyKey'e göstermezse ad ve imza gelmez.
      await pumpAutofill(
        tester,
        status: VaultOpen(service.newSession()),
        target: const AutofillTarget(
          packageName: 'com.ornek.yeni',
          untrustedWebDomain: 'banka.example.com',
          save: AutofillSave(username: 'ayse', password: 'yeni-parola-1'),
        ),
      );

      expect(
        find.textContaining('com.ornek.yeni uygulaması doğrulanamadığı için'),
        findsOneWidget,
      );
      expect(find.textContaining('web sayfası gösteriyor'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.pumpAndSettle();

      final item = saved('ayse')!;
      expect(item.content.name, 'com.ornek.yeni');
      expect(item.content.apps, isEmpty);
      expect(item.content.urls, isEmpty);
    });

    testWidgets('aynı kullanıcı adlı kaydın parolası güncellenebiliyor', (
      tester,
    ) async {
      final bridge = await pumpAutofill(
        tester,
        status: VaultOpen(service.newSession()),
        target: const AutofillTarget(
          packageName: 'io.github.aaudraa.ornekgiris',
          appLabel: 'Örnek Giriş',
          certsSha256: [cert],
          save: AutofillSave(username: 'veli', password: 'degisen-parola'),
        ),
      );

      expect(find.textContaining('Örnek hesap kaydında'), findsOneWidget);
      await tester.tap(find.text('Parolasını güncelle'));
      await tester.pumpAndSettle();

      final item = saved('veli')!;
      expect(item.content.password, 'degisen-parola');
      expect(item.content.passwordHistory.single.password, 'ornek-parolasi');
      expect(logins.items, hasLength(3));
      expect(bridge.cancelled, isTrue);
    });

    testWidgets('kayıt zaten varsa bunu söylüyor', (tester) async {
      await pumpAutofill(
        tester,
        status: VaultOpen(service.newSession()),
        target: const AutofillTarget(
          packageName: 'io.github.aaudraa.ornekgiris',
          appLabel: 'Örnek Giriş',
          certsSha256: [cert],
          save: AutofillSave(username: 'veli', password: 'ornek-parolasi'),
        ),
      );

      expect(
        find.text('Bu giriş Örnek hesap kaydında zaten var.'),
        findsOneWidget,
      );
      expect(find.text('Parolasını güncelle'), findsNothing);
    });

    testWidgets('eşleşmeyen kaydın parolası önerilmiyor', (tester) async {
      // "Posta" kaydının kullanıcı adı aynı ama uygulamaya bağlı değil.
      await pumpAutofill(
        tester,
        status: VaultOpen(service.newSession()),
        target: const AutofillTarget(
          packageName: 'io.github.aaudraa.ornekgiris',
          appLabel: 'Örnek Giriş',
          certsSha256: [cert],
          save: AutofillSave(username: 'ali', password: 'baska'),
        ),
      );

      expect(find.text('Parolasını güncelle'), findsNothing);
    });
  });

  group('erişilebilirlik', () {
    const saveTarget = AutofillTarget(
      packageName: 'io.github.aaudraa.ornekgiris',
      appLabel: 'Örnek Giriş',
      certsSha256: [cert],
      save: AutofillSave(username: 'ayse', password: 'yeni-parola-1'),
    );

    Future<void> checkGuidelines(WidgetTester tester) async {
      final handle = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    }

    for (final (brightness, scale) in [
      (Brightness.light, 1.0),
      (Brightness.dark, 1.0),
      (Brightness.light, 2.0),
      (Brightness.dark, 2.0),
    ]) {
      for (final (name, target) in [
        ('doldurma', app),
        ('kaydetme', saveTarget),
      ]) {
        testWidgets('$name, ${brightness.name}, yazı x$scale', (tester) async {
          tester.platformDispatcher
            ..platformBrightnessTestValue = brightness
            ..textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          tester.view
            ..physicalSize = const Size(1080, 2400)
            ..devicePixelRatio = 2.625;
          addTearDown(tester.view.reset);

          await pumpAutofill(
            tester,
            status: VaultLocked(service.header),
            target: target,
          );
          await checkGuidelines(tester);

          await tester.enterText(
            find.byType(TextField),
            FakeVaultService.correctPassword,
          );
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsWidgets);
          await checkGuidelines(tester);
        });
      }
    }
  });
}

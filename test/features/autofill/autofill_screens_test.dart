import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/application/autofill_matches.dart';
import 'package:keykey/features/autofill/domain/public_suffix_list.dart';
import 'package:keykey/features/autofill/presentation/autofill_app.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_content.dart';
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
  late PublicSuffixList psl;

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
          settingsRepositoryFactoryProvider.overrideWithValue(
            (_) => FakeSettingsRepository(),
          ),
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
}

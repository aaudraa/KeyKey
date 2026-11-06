import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
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

  const app = AutofillTarget(
    packageName: 'io.github.aaudraa.ornekgiris',
    appLabel: 'Örnek Giriş',
  );

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
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

  testWidgets('seçilen kayıt dolduruluyor ve kasa kilitleniyor', (
    tester,
  ) async {
    final bridge = await pumpAutofill(
      tester,
      status: VaultOpen(service.newSession()),
    );

    await tester.tap(find.text('Banka'));
    await tester.pumpAndSettle();

    expect(bridge.filled, (
      username: 'ali@example.com',
      password: 'banka-parolasi',
    ));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AutofillHome)),
    );
    expect(container.read(vaultControllerProvider), isA<VaultLocked>());
    // Ekran kapanırken kilit ekranı ve parmak izi penceresi yeniden açılmaz.
    expect(find.text('KeyKey kilitli'), findsNothing);
    expect(find.text('Banka'), findsNothing);
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
}

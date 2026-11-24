import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/network/asset_links_client.dart';
import 'package:keykey/features/autofill/application/autofill_matches.dart';
import 'package:keykey/features/autofill/domain/public_suffix_list.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/lock/presentation/lock_screen.dart';
import 'package:keykey/features/onboarding/application/terms_controller.dart';
import 'package:keykey/features/passkey/application/passkey_bridge.dart';
import 'package:keykey/features/passkey/domain/passkey_caller.dart';
import 'package:keykey/features/passkey/domain/webauthn.dart';
import 'package:keykey/features/passkey/presentation/passkey_app.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_passkey.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../support/fake_vault_service.dart';
import '../autofill/autofill_screens_test.dart' show FakeAssetLinks;

String fixture(String name) =>
    File('test/features/passkey/fixtures/$name').readAsStringSync();

class FakePasskeyBridge implements PasskeyBridge {
  new(this.passkeyRequest, {this.domains = const []});

  final PasskeyRequest? passkeyRequest;
  final List<AppDomain> domains;
  String? created;
  List<PasskeyAssertion>? got;
  PasskeyError? failed;
  bool cancelled = false;

  @override
  Future<PasskeyRequest?> request() async => passkeyRequest;

  @override
  Future<bool> hasSigningCertificates(
    String packageName,
    List<String> certs,
  ) async => packageName == passkeyRequest?.caller.packageName;

  @override
  Future<List<AppDomain>> appDomains(String packageName) async => domains;

  @override
  Future<void> finishCreate(String responseJson) async =>
      created = responseJson;

  @override
  Future<void> finishGet(List<PasskeyAssertion> assertions) async =>
      got = assertions;

  @override
  Future<void> fail(PasskeyError error) async => failed = error;

  @override
  Future<void> cancel() async => cancelled = true;
}

class FakeKeys implements PasskeyKeys {
  final signed = <Uint8List>[];

  @override
  Future<PasskeyKeyPair> generate() async => PasskeyKeyPair(
    privateKey: Uint8List.fromList([9, 9, 9]),
    x: Uint8List(32)..[0] = 1,
    y: Uint8List(32)..[0] = 2,
  );

  @override
  Future<Uint8List> sign(Uint8List privateKey, Uint8List data) async {
    signed.add(privateKey);
    return Uint8List.fromList([0x30, 0x00]);
  }
}

void main() {
  late SodiumSumo sodium;
  late FakeVaultService service;
  late FakeLoginRepository logins;
  late PublicSuffixList psl;
  late FakeKeys keys;
  final cert = 'ab' * 32;

  final chrome = PasskeyCaller(
    packageName: 'com.android.chrome',
    certsSha256: [cert],
    browserOrigin: 'https://github.com',
    appLabel: 'Chrome',
  );
  final githubApp = PasskeyCaller(
    packageName: 'com.github.android',
    certsSha256: [cert],
    appLabel: 'GitHub',
  );

  LoginPasskey passkey(int id, String user) => LoginPasskey(
    credentialId: Uint8List.fromList(List.filled(16, id)),
    rpId: 'github.com',
    userHandle: utf8.encode(user),
    userName: user,
    userDisplayName: user,
    privateKey: Uint8List.fromList([id]),
    createdAt: DateTime.utc(2026),
  );

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    psl = PublicSuffixList.parse(File(publicSuffixListPath).readAsStringSync());
  });

  setUp(() {
    service = FakeVaultService(sodium);
    keys = FakeKeys();
    logins = FakeLoginRepository(
      items: [
        FakeLoginRepository.item(
          const LoginContent(
            name: 'GitHub',
            username: 'furkan',
            password: 'parola',
            urls: ['https://github.com'],
          ),
          id: 1,
        ),
        FakeLoginRepository.item(
          const LoginContent(name: 'Banka', urls: ['https://banka.example']),
          id: 2,
        ),
      ],
    );
  });

  Future<FakePasskeyBridge> pump(
    WidgetTester tester, {
    required VaultStatus status,
    PasskeyRequest? request,
    List<AppDomain> domains = const [],
  }) async {
    tester.platformDispatcher.localesTestValue = [const Locale('tr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final bridge = FakePasskeyBridge(request, domains: domains);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultServiceProvider.overrideWithValue(service),
          initialVaultStatusProvider.overrideWithValue(status),
          loginRepositoryFactoryProvider.overrideWithValue((_) => logins),
          settingsRepositoryFactoryProvider.overrideWithValue(
            (_) => FakeSettingsRepository(),
          ),
          passkeyBridgeProvider.overrideWithValue(bridge),
          passkeyKeysProvider.overrideWithValue(keys),
          publicSuffixListProvider.overrideWith((ref) => psl),
          initialTermsAcceptedProvider.overrideWithValue(true),
          assetLinksSourceProvider.overrideWithValue(FakeAssetLinks(const {})),
        ],
        child: const PasskeyApp(),
      ),
    );
    await tester.pumpAndSettle();
    return bridge;
  }

  PasskeyRequest create(PasskeyCaller caller, {String? json}) => PasskeyRequest(
    kind: PasskeyRequestKind.create,
    requestJson: json ?? fixture('github_create.json'),
    caller: caller,
  );

  PasskeyRequest get(PasskeyCaller caller) => PasskeyRequest(
    kind: PasskeyRequestKind.get,
    requestJson: jsonEncode({
      'challenge': base64UrlNoPad(Uint8List(32)),
      'rpId': 'github.com',
    }),
    caller: caller,
  );

  bool locked(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(PasskeyHome)))
              .read(vaultControllerProvider)
          is VaultLocked;

  group('oluşturma', () {
    testWidgets('kilitliyken yalnızca site görünüyor', (tester) async {
      await pump(
        tester,
        status: VaultLocked(service.header),
        request: create(chrome),
      );
      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.text('github.com için passkey'), findsOneWidget);
      expect(find.text('GitHub'), findsNothing);
    });

    testWidgets('aynı site ve kullanıcı adındaki kayda ekleniyor', (
      tester,
    ) async {
      final bridge = await pump(
        tester,
        status: VaultLocked(service.header),
        request: create(chrome),
      );
      await tester.enterText(
        find.byType(TextField),
        FakeVaultService.correctPassword,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Site: github.com'), findsOneWidget);
      expect(find.text('Hesap: furkan'), findsOneWidget);
      expect(find.text('Chrome içinde'), findsOneWidget);
      expect(find.text('Kaydedileceği yer'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Passkey oluştur'));
      await tester.pumpAndSettle();

      final saved = logins.items.first.content;
      expect(saved.passkeys, hasLength(1));
      expect(saved.passkeys.single.rpId, 'github.com');
      expect(saved.passkeys.single.privateKey, [9, 9, 9]);
      expect(logins.items, hasLength(2));
      final response = jsonDecode(bridge.created!) as Map<String, Object?>;
      expect(response['id'], saved.passkeys.single.credentialIdB64);
      expect(locked(tester), isTrue);
    });

    testWidgets('"Yeni kayıt" seçilirse yeni kayıt açılıyor', (tester) async {
      final bridge = await pump(
        tester,
        status: VaultOpen(service.newSession()),
        request: create(chrome),
      );
      await tester.tap(find.text('Yeni kayıt'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Passkey oluştur'));
      await tester.pumpAndSettle();

      expect(logins.items, hasLength(3));
      final added = logins.items.last.content;
      expect(added.name, 'GitHub');
      expect(added.urls, ['https://github.com']);
      expect(added.passkeys, hasLength(1));
      expect(logins.items.first.content.passkeys, isEmpty);
      expect(bridge.created, isNotNull);
    });

    testWidgets('doğrulanmamış uygulama uyarılıyor ve bağlanmıyor', (
      tester,
    ) async {
      logins.items.removeAt(0);
      await pump(
        tester,
        status: VaultOpen(service.newSession()),
        request: create(githubApp),
      );
      expect(find.text('GitHub uygulaması için'), findsOneWidget);
      expect(
        find.textContaining('github.com sitesine ait olduğu doğrulanamadı'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Passkey oluştur'));
      await tester.pumpAndSettle();
      expect(logins.items.last.content.apps, isEmpty);
    });

    testWidgets('Android doğruladıysa uygulama kayda bağlanıyor', (
      tester,
    ) async {
      logins.items.removeAt(0);
      await pump(
        tester,
        status: VaultOpen(service.newSession()),
        request: create(githubApp),
        domains: [AppDomain(host: 'github.com', verified: true)],
      );
      expect(find.textContaining('doğrulanamadı'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Passkey oluştur'));
      await tester.pumpAndSettle();
      expect(
        logins.items.last.content.apps.single.packageName,
        'com.github.android',
      );
    });

    testWidgets('kasada zaten varsa reddediliyor', (tester) async {
      final excluded = LoginPasskey(
        credentialId: base64UrlDecodeNoPad('AQIDBAUGBwgJCgsMDQ4PEA'),
        rpId: 'github.com',
        userHandle: utf8.encode('x'),
        userName: 'furkan',
        userDisplayName: '',
        privateKey: Uint8List.fromList([1]),
        createdAt: DateTime.utc(2026),
      );
      logins.items[0] = FakeLoginRepository.item(
        logins.items[0].content.copyWith(passkeys: [excluded]),
        id: 1,
      );
      final bridge = await pump(
        tester,
        status: VaultOpen(service.newSession()),
        request: create(chrome),
      );
      expect(
        find.text("Bu hesabın passkey'i kasanda zaten var."),
        findsOneWidget,
      );
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      expect(bridge.failed, PasskeyError.alreadyExists);
    });

    testWidgets('başka sitenin isteği kilit açtırmadan reddediliyor', (
      tester,
    ) async {
      final bridge = await pump(
        tester,
        status: VaultLocked(service.header),
        request: create(
          PasskeyCaller(
            packageName: 'com.android.chrome',
            certsSha256: [cert],
            browserOrigin: 'https://evil.example.com',
          ),
        ),
      );
      expect(find.byType(LockScreen), findsNothing);
      expect(find.textContaining('güvenlik için reddedildi'), findsOneWidget);
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      expect(bridge.failed, PasskeyError.rpIdMismatch);
    });

    testWidgets('vazgeç iptal ediyor ve kilitliyor', (tester) async {
      final bridge = await pump(
        tester,
        status: VaultOpen(service.newSession()),
        request: create(chrome),
      );
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(bridge.cancelled, isTrue);
      expect(logins.items.first.content.passkeys, isEmpty);
      expect(locked(tester), isTrue);
    });
  });

  group('giriş', () {
    void addPasskeys() {
      logins.items[0] = FakeLoginRepository.item(
        logins.items[0].content.copyWith(
          passkeys: [passkey(1, 'furkan'), passkey(2, 'keykey')],
        ),
        id: 1,
      );
    }

    testWidgets('kilit açılınca iki hesap sisteme veriliyor', (tester) async {
      addPasskeys();
      final bridge = await pump(
        tester,
        status: VaultLocked(service.header),
        request: get(chrome),
      );
      expect(
        find.text('github.com sitesine passkey ile giriş'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byType(TextField),
        FakeVaultService.correctPassword,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(bridge.got!.map((a) => a.userName), ['furkan', 'keykey']);
      expect(keys.signed, [
        [1],
        [2],
      ]);
      expect(locked(tester), isTrue);
    });

    testWidgets('passkey yoksa söyleniyor ve boş liste dönüyor', (
      tester,
    ) async {
      final bridge = await pump(
        tester,
        status: VaultOpen(service.newSession()),
        request: get(chrome),
      );
      expect(find.text('Kasanda github.com için passkey yok.'), findsOneWidget);
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      expect(bridge.got, isEmpty);
    });

    testWidgets('doğrulanmamış uygulamada önce onay isteniyor', (tester) async {
      addPasskeys();
      final bridge = await pump(
        tester,
        status: VaultOpen(service.newSession()),
        request: get(githubApp),
      );
      expect(bridge.got, isNull);
      expect(find.textContaining('doğrulanamadı'), findsOneWidget);
      await tester.tap(find.text('Yine de devam et'));
      await tester.pumpAndSettle();
      expect(bridge.got, hasLength(2));
    });
  });
}

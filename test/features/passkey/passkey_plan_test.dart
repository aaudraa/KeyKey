import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/autofill/domain/public_suffix_list.dart';
import 'package:keykey/features/passkey/domain/passkey_caller.dart';
import 'package:keykey/features/passkey/domain/passkey_plan.dart';
import 'package:keykey/features/passkey/domain/webauthn.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_passkey.dart';

import '../../support/fake_vault_service.dart';

String fixture(String name) =>
    File('test/features/passkey/fixtures/$name').readAsStringSync();

Matcher throwsKind(PasskeyError kind) =>
    throwsA(isA<PasskeyRequestException>().having((e) => e.kind, 'kind', kind));

LoginPasskey passkey({
  String rpId = 'github.com',
  int id = 1,
  String handle = 'furkan',
}) => LoginPasskey(
  credentialId: Uint8List.fromList(List.filled(16, id)),
  rpId: rpId,
  userHandle: utf8.encode(handle),
  userName: handle,
  userDisplayName: '',
  privateKey: Uint8List.fromList([1, 2, 3]),
  createdAt: DateTime.utc(2026),
);

void main() {
  late PublicSuffixList psl;
  setUpAll(
    () => psl = PublicSuffixList.parse(
      File('resources/assets/autofill/public_suffix_list.dat')
          .readAsStringSync(),
    ),
  );

  final cert = 'ab' * 32;
  PasskeyCaller chrome(String origin) => PasskeyCaller(
    packageName: 'com.android.chrome',
    certsSha256: [cert],
    browserOrigin: origin,
  );

  group('istek çözümü', () {
    test('tarayıcıda origin ve rpId', () {
      final prompt = resolvePasskeyPrompt(
        create: true,
        requestJson: fixture('github_create.json'),
        caller: chrome('https://github.com'),
        suffixes: psl,
      );
      expect(prompt.rpId, 'github.com');
      expect(prompt.origin, 'https://github.com');
      expect(prompt.isCreate, isTrue);
    });

    test('başka sitenin rpId isteği reddediliyor', () {
      expect(
        () => resolvePasskeyPrompt(
          create: true,
          requestJson: fixture('github_create.json'),
          caller: chrome('https://evil.example.com'),
          suffixes: psl,
        ),
        throwsKind(PasskeyError.rpIdMismatch),
      );
    });

    test('rpId yoksa tarayıcıda origin ana bilgisayarı, uygulamada hata', () {
      final json = (jsonDecode(fixture('webauthn_io_get.json')) as Map)
        ..remove('rpId');
      final prompt = resolvePasskeyPrompt(
        create: false,
        requestJson: jsonEncode(json),
        caller: chrome('https://webauthn.io'),
        suffixes: psl,
      );
      expect(prompt.rpId, 'webauthn.io');
      expect(
        () => resolvePasskeyPrompt(
          create: false,
          requestJson: jsonEncode(json),
          caller: PasskeyCaller(packageName: 'a.b', certsSha256: [cert]),
          suffixes: psl,
        ),
        throwsKind(PasskeyError.invalidRequest),
      );
    });
  });

  group('kayıtlar', () {
    final github = FakeLoginRepository.item(
      LoginContent(
        name: 'GitHub',
        username: 'Furkan',
        urls: const ['https://github.com/login'],
        passkeys: [passkey()],
      ),
      id: 1,
    );
    final other = FakeLoginRepository.item(
      const LoginContent(
        name: 'GitHub iş',
        username: 'keykey',
        urls: ['github.com'],
      ),
      id: 2,
    );
    final trashed = FakeLoginRepository.item(
      LoginContent(
        name: 'Eski',
        username: 'furkan',
        urls: const ['https://github.com'],
        passkeys: [passkey(id: 9)],
        trashedAt: DateTime.utc(2026),
      ),
      id: 3,
    );
    final items = [github, other, trashed];

    test('aday: aynı site ve kullanıcı adı, çöp hariç', () {
      expect(
        createTargets(
          items: items,
          rpId: 'github.com',
          userName: 'furkan',
          suffixes: psl,
        ),
        [github],
      );
      expect(
        createTargets(
          items: items,
          rpId: 'gitlab.com',
          userName: 'furkan',
          suffixes: psl,
        ),
        isEmpty,
      );
    });

    test('excludeCredentials yalnızca çöp dışı ve aynı rpId', () {
      final id = passkey().credentialId;
      expect(alreadyRegistered(items, 'github.com', [id]), isTrue);
      expect(alreadyRegistered(items, 'gitlab.com', [id]), isFalse);
      expect(
        alreadyRegistered(items, 'github.com', [passkey(id: 9).credentialId]),
        isFalse,
      );
      expect(alreadyRegistered(items, 'github.com', const []), isFalse);
    });

    test('giriş adayları allowCredentials ile süzülüyor', () {
      expect(
        passkeysFor(items: items, rpId: 'github.com', allowIds: const []),
        hasLength(1),
      );
      expect(
        passkeysFor(
          items: items,
          rpId: 'github.com',
          allowIds: [passkey(id: 5).credentialId],
        ),
        isEmpty,
      );
    });

    test('aynı kullanıcı kimliğindeki eski passkey değişiyor', () {
      final fresh = passkey(id: 7);
      final content = withPasskey(github.content, fresh);
      expect(content.passkeys, [fresh]);
      final second = withPasskey(content, passkey(id: 8, handle: 'iki'));
      expect(second.passkeys, hasLength(2));
    });

    test('uygulama bir kez bağlanıyor', () {
      final app = LoginApp(
        packageName: 'com.github.android',
        certsSha256: [cert],
      );
      final once = withPasskey(other.content, passkey(), app: app);
      expect(once.apps, [app]);
      final twice = withPasskey(once, passkey(id: 2, handle: 'x'), app: app);
      expect(twice.apps, hasLength(1));
    });

    test('20 passkey sınırı', () {
      var content = other.content;
      for (var i = 0; i < LoginContent.maxPasskeys; i++) {
        content = withPasskey(content, passkey(id: i, handle: 'h$i'));
      }
      expect(
        () => withPasskey(content, passkey(id: 99, handle: 'yeni')),
        throwsKind(PasskeyError.tooMany),
      );
    });

    test('yeni kayıt sitenin adıyla', () {
      final options = CreationOptions.parse(fixture('github_create.json'));
      final content = newPasskeyLogin(
        options: options,
        rpId: 'github.com',
        passkey: passkey(),
      );
      expect(content.name, options.rpName);
      expect(content.username, options.userName);
      expect(content.urls, ['https://github.com']);
      expect(content.password, isEmpty);
      expect(content.passkeys, hasLength(1));
    });

    test('hesap adı boş kalmıyor', () {
      final empty = LoginPasskey(
        credentialId: Uint8List(16),
        rpId: 'github.com',
        userHandle: Uint8List(1),
        userName: '',
        userDisplayName: '',
        privateKey: Uint8List(1),
        createdAt: DateTime.utc(2026),
      );
      expect(passkeyAccountName(empty, github), 'Furkan');
    });
  });
}

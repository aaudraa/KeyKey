import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/network/asset_links_client.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/domain/public_suffix_list.dart';
import 'package:keykey/features/passkey/domain/passkey_caller.dart';
import 'package:keykey/features/passkey/domain/webauthn.dart';

const pslPath = 'resources/assets/autofill/public_suffix_list.dat';
const pkg = 'com.github.android';
final String cert = 'ab' * 32;

class _Links implements AssetLinksSource {
  new(this.bodies);

  final Map<String, String?> bodies;
  final asked = <String>[];

  @override
  Future<String?> fetch(String host) async {
    asked.add(host);
    return bodies[host];
  }
}

void main() {
  late PublicSuffixList psl;
  setUpAll(
    () => psl = PublicSuffixList.parse(File(pslPath).readAsStringSync()),
  );

  PasskeyCaller browser(String origin) => PasskeyCaller(
    packageName: 'com.android.chrome',
    certsSha256: [cert],
    browserOrigin: origin,
  );
  final app = PasskeyCaller(packageName: pkg, certsSha256: [cert]);

  group('origin', () {
    test('uygulamanın origin metni imza özetinden', () {
      expect(
        app.origin(),
        'android:apk-key-hash:'
        '${base64Url.encode(List.filled(32, 0xab)).replaceAll('=', '')}',
      );
      expect(app.isBrowser, isFalse);
    });

    test('tarayıcının origin metni tarayıcının verdiği', () {
      expect(browser('https://github.com').origin(), 'https://github.com');
      expect(browser('https://github.com').isBrowser, isTrue);
    });

    test('çok imzacılı uygulama desteklenmiyor', () {
      expect(
        () =>
            PasskeyCaller(packageName: pkg, certsSha256: [cert, cert]).origin(),
        throwsA(isA<PasskeyRequestException>()),
      );
    });
  });

  group('rpId kuralı', () {
    test('tarayıcıda site ya da alt alanı', () {
      expect(
        rpIdAllowed('github.com', browser('https://github.com'), psl),
        isTrue,
      );
      expect(
        rpIdAllowed('github.com', browser('https://www.github.com'), psl),
        isTrue,
      );
      expect(
        rpIdAllowed('www.github.com', browser('https://github.com'), psl),
        isFalse,
      );
      expect(
        rpIdAllowed('github.com', browser('https://evil.com'), psl),
        isFalse,
      );
      expect(
        rpIdAllowed('github.com', browser('https://notgithub.com'), psl),
        isFalse,
      );
      expect(
        rpIdAllowed('github.com', browser('http://github.com'), psl),
        isFalse,
      );
    });

    test('public suffix ve geçersiz ad hiçbir zaman', () {
      expect(rpIdAllowed('com', browser('https://com'), psl), isFalse);
      expect(
        rpIdAllowed('github.io', browser('https://a.github.io'), psl),
        isFalse,
      );
      expect(
        rpIdAllowed('a.github.io', browser('https://a.github.io'), psl),
        isTrue,
      );
      expect(rpIdAllowed('com', app, psl), isFalse);
      expect(rpIdAllowed('GitHub.com', app, psl), isFalse);
      expect(rpIdAllowed('1.2.3.4', app, psl), isFalse);
      expect(rpIdAllowed('github.com', app, psl), isTrue);
    });

    test('rpId yoksa tarayıcının origin ana bilgisayarı', () {
      expect(defaultRpId(browser('https://www.github.com')), 'www.github.com');
      expect(defaultRpId(app), isNull);
    });
  });

  group('uygulama siteye ait mi', () {
    Future<bool> belongs({
      List<AppDomain> domains = const [],
      bool online = false,
      _Links? links,
      String rpId = 'github.com',
    }) => appBelongsToRp(
      caller: app,
      rpId: rpId,
      domains: domains,
      verifyOnline: online,
      source: links ?? _Links(const {}),
      hasSigningCertificates: (p, certs) async =>
          p == pkg && certs.contains(cert),
      suffixes: psl,
    );

    test('Android doğruladıysa evet, ağa çıkmadan', () async {
      final links = _Links(const {});
      expect(
        await belongs(
          domains: [AppDomain(host: 'github.com', verified: true)],
          links: links,
        ),
        isTrue,
      );
      expect(links.asked, isEmpty);
    });

    test('ayar kapalı ve doğrulanmamışsa hayır, ağa çıkılmaz', () async {
      final links = _Links({'github.com': '[]'});
      expect(
        await belongs(
          domains: [AppDomain(host: 'github.com', verified: false)],
          links: links,
        ),
        isFalse,
      );
      expect(links.asked, isEmpty);
    });

    test('ayar açıkken assetlinks.json onaylıyorsa evet', () async {
      final body = jsonEncode([
        {
          'relation': ['delegate_permission/common.get_login_creds'],
          'target': {
            'namespace': 'android_app',
            'package_name': pkg,
            'sha256_cert_fingerprints': [List.filled(32, 'AB').join(':')],
          },
        },
      ]);
      final links = _Links({'github.com': body});
      expect(await belongs(online: true, links: links), isTrue);
      expect(links.asked, ['github.com']);
    });
  });
}

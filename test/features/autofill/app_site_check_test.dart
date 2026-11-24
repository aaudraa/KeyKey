import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/network/asset_links_client.dart';
import 'package:keykey/features/autofill/application/app_site_check.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/domain/public_suffix_list.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

const pslPath = 'resources/assets/autofill/public_suffix_list.dat';
const pkg = 'com.github.android';
final String certA = 'a' * 64;
final String certB = 'b' * 64;

String fp(String hex) => [
  for (var i = 0; i < hex.length; i += 2) hex.substring(i, i + 2).toUpperCase(),
].join(':');

String assetLinks(List<String> certs, {String package = pkg}) => jsonEncode([
  {
    'relation': ['delegate_permission/common.get_login_creds'],
    'target': {
      'namespace': 'android_app',
      'package_name': package,
      'sha256_cert_fingerprints': [for (final c in certs) fp(c)],
    },
  },
]);

/// Sorulan alan adlarını kaydeder; yanıtı [bodies]'den, gecikmeyi
/// [gates]'ten alır.
class FakeSource implements AssetLinksSource {
  new(this.bodies);

  final Map<String, String?> bodies;
  final Map<String, Completer<void>> gates = {};
  final asked = <String>[];

  @override
  Future<String?> fetch(String host) async {
    asked.add(host);
    await gates[host]?.future;
    return bodies[host];
  }
}

var _id = 0;
LoginItem login(String name, List<String> urls) => LoginItem(
  id: Uint8List.fromList([_id++]),
  content: LoginContent(name: name, username: 'u', password: 'p', urls: urls),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late PublicSuffixList psl;

  setUpAll(() {
    psl = PublicSuffixList.parse(File(pslPath).readAsStringSync());
  });

  group('internet adayları', () {
    List<String> candidates(
      List<AppDomain> domains,
      List<LoginItem> unmatched, {
      String packageName = pkg,
    }) => onlineCandidates(
      packageName: packageName,
      domains: domains,
      unmatched: unmatched,
      suffixes: psl,
    );

    test('paket adından türetilen site, kasada kaydı varsa', () {
      expect(
        candidates(const [], [
          login('GitHub', ['github.com']),
        ]),
        ['github.com'],
      );
      expect(
        candidates(const [], [
          login('GitLab', ['gitlab.com']),
        ]),
        isEmpty,
      );
      expect(candidates(const [], const []), isEmpty);
    });

    test(
      'bildirilen doğrulanmamış alan adı türetilenden önce, site başına bir',
      () {
        expect(
          candidates(
            [
              AppDomain(host: 'www.github.com', verified: false),
              AppDomain(host: '*.github.com', verified: false),
            ],
            [
              login('GitHub', ['https://github.com/login']),
            ],
          ),
          ['github.com'],
        );
        expect(
          candidates(
            [AppDomain(host: 'www.github.com', verified: false)],
            [
              login('GitHub', ['https://github.com/login']),
            ],
          ),
          ['www.github.com'],
        );
      },
    );

    test('doğrulanmış alan adı aday olmuyor', () {
      expect(
        candidates(
          [AppDomain(host: 'github.com', verified: true)],
          [
            login('GitHub', ['github.com']),
          ],
          packageName: 'org.example.app',
        ),
        isEmpty,
      );
    });

    test('en fazla dört site, site adına göre sıralı', () {
      final sites = ['e.com', 'd.com', 'c.com', 'b.com', 'a.com'];
      expect(
        candidates(
          [for (final s in sites) AppDomain(host: s, verified: false)],
          [
            for (final s in sites) login(s, [s]),
          ],
          packageName: 'org.example.app',
        ),
        ['a.com', 'b.com', 'c.com', 'd.com'],
      );
    });

    test('sitesinin bir kaydı uygulamaya bağlıysa aday olmuyor', () {
      expect(
        onlineCandidates(
          packageName: pkg,
          domains: const [],
          unmatched: [
            login('GitHub iş', ['github.com']),
            login('GitLab', ['gitlab.com']),
          ],
          bound: [
            login('GitHub', ['https://github.com/login']),
          ],
          suffixes: psl,
        ),
        isEmpty,
      );
    });

    test('IP adresi ve geçersiz alan adı aday olmuyor', () {
      expect(
        candidates(
          [
            AppDomain(host: '192.168.1.1', verified: false),
            AppDomain(host: 'kötü ad', verified: false),
          ],
          [
            login('Yerel', ['192.168.1.1']),
          ],
          packageName: 'org.example.app',
        ),
        isEmpty,
      );
    });
  });

  group('internetle doğrulama', () {
    Future<Map<String, bool>> check(
      FakeSource source, {
      List<String>? certs,
      Set<String> deviceCerts = const {},
      Duration budget = const Duration(seconds: 5),
      List<String> hosts = const ['github.com'],
    }) => checkSitesOnline(
      packageName: pkg,
      certsSha256: certs ?? [certA],
      hosts: hosts,
      source: source,
      hasSigningCertificates: (packageName, list) async =>
          packageName == pkg && list.every(deviceCerts.contains),
      budget: budget,
    );

    test('tek imzacıda listedeki bir özet tutarsa doğrulanır', () async {
      final source = FakeSource({
        'github.com': assetLinks([certB, certA]),
      });
      expect(await check(source, deviceCerts: {certA}), {'github.com': true});
    });

    test('imza ya da paket tutmazsa doğrulanmaz', () async {
      expect(
        await check(
          FakeSource({
            'github.com': assetLinks([certB]),
          }),
          deviceCerts: {certA},
        ),
        {'github.com': false},
      );
      expect(
        await check(
          FakeSource({
            'github.com': assetLinks([certA], package: 'x.y'),
          }),
          deviceCerts: {certA},
        ),
        {'github.com': false},
      );
    });

    test('çok imzacıda bütün imzacılar listede olmalı', () async {
      final both = FakeSource({
        'github.com': assetLinks([certA, certB]),
      });
      expect(await check(both, certs: [certA, certB]), {'github.com': true});
      final one = FakeSource({
        'github.com': assetLinks([certA]),
      });
      expect(await check(one, certs: [certA, certB]), {'github.com': false});
    });

    test('yanıt yoksa doğrulanmaz', () async {
      expect(
        await check(FakeSource({'github.com': null}), deviceCerts: {certA}),
        {'github.com': false},
      );
    });

    test('süre dolunca yanıt vermeyen düşer, öteki kalır', () async {
      final source = FakeSource({
        'github.com': assetLinks([certA]),
        'githubusercontent.com': assetLinks([certA]),
      });
      source.gates['githubusercontent.com'] = Completer<void>();
      final result = await check(
        source,
        deviceCerts: {certA},
        hosts: ['github.com', 'githubusercontent.com'],
        budget: const Duration(milliseconds: 100),
      );
      expect(result, {'github.com': true, 'githubusercontent.com': false});
      source.gates['githubusercontent.com']!.complete();
    });
  });

  group('sorgu önbelleği', () {
    test('süren sorguya yeniden sorulmuyor, ikisi de sonucu alıyor', () async {
      final cache = SiteCheckCache();
      final asked = <List<String>>[];
      final gate = Completer<void>();
      Future<Map<String, bool>> check(List<String> hosts) async {
        asked.add(hosts);
        await gate.future;
        return {for (final host in hosts) host: host == 'github.com'};
      }

      final first = cache.ensure(['github.com'], check);
      final second = cache.ensure(['github.com', 'gitlab.com'], check);
      gate.complete();
      await Future.wait([first, second]);

      expect(asked, [
        ['github.com'],
        ['gitlab.com'],
      ]);
      expect(cache.results, {'github.com': true, 'gitlab.com': false});
      await cache.ensure(['github.com'], check);
      expect(asked, hasLength(2));
    });
  });

  test('doğrulanıyor yazısı son sorgu bitince kalkıyor', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final progress = container.read(siteCheckInProgressProvider.notifier)
      ..start()
      ..start()
      ..finish();
    expect(container.read(siteCheckInProgressProvider), isTrue);
    progress.finish();
    expect(container.read(siteCheckInProgressProvider), isFalse);
  });
}

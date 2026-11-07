import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/domain/domain_name.dart';
import 'package:keykey/features/autofill/domain/login_matcher.dart';
import 'package:keykey/features/autofill/domain/public_suffix_list.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

const pslPath = 'resources/assets/autofill/public_suffix_list.dat';

void main() {
  late PublicSuffixList psl;

  setUpAll(() {
    psl = PublicSuffixList.parse(File(pslPath).readAsStringSync());
  });

  group('punycode', () {
    // Beklenen değerler Node'un url.domainToASCII çıktısı.
    test('etiketler', () {
      expect(Punycode.encode('bücher'), 'bcher-kva');
      expect(Punycode.encode('münchen'), 'mnchen-3ya');
      expect(Punycode.encode('türkiye'), 'trkiye-3ya');
      expect(Punycode.encode('şeker'), 'eker-45a');
      expect(Punycode.encode('ığdır'), 'dr-wna5ec');
      expect(Punycode.encode('食狮'), '85x722f');
      expect(Punycode.encode('公司'), '55qx5d');
      expect(Punycode.encode('ключ'), 'j1ac0b1a');
      expect(Punycode.encode('рф'), 'p1ai');
      expect(Punycode.encode('日本語'), 'wgv71a119e');
    });

    test('alan adı', () {
      expect(DomainName.normalize('Bücher.DE.'), 'xn--bcher-kva.de');
      expect(DomainName.normalize('ığdır.bel.tr'), 'xn--dr-wna5ec.bel.tr');
      expect(DomainName.normalize('ключ.рф'), 'xn--j1ac0b1a.xn--p1ai');
      expect(DomainName.normalize('ex-ample.com'), 'ex-ample.com');
      expect(DomainName.normalize(''), isNull);
      expect(DomainName.normalize('a..b'), isNull);
      expect(DomainName.normalize('kötü site.com'), isNull);
      expect(DomainName.normalize('-a.com'), isNull);
    });
  });

  group('adresten alan adı', () {
    test('biçimler', () {
      expect(
        DomainName.hostOfUrl('https://Banka.example.com/giris?x=1'),
        'banka.example.com',
      );
      expect(DomainName.hostOfUrl('banka.com.tr'), 'banka.com.tr');
      expect(DomainName.hostOfUrl('banka.com.tr/giris'), 'banka.com.tr');
      expect(
        DomainName.hostOfUrl('http://ali:parola@site.com:8080/'),
        'site.com',
      );
      expect(DomainName.hostOfUrl('https://bücher.de'), 'xn--bcher-kva.de');
      expect(DomainName.hostOfUrl('https://[::1]:8443/'), '[::1]');
      expect(DomainName.hostOfUrl('192.168.1.1'), '192.168.1.1');
      expect(DomainName.hostOfUrl('  '), isNull);
      expect(DomainName.hostOfUrl('https://'), isNull);
    });
  });

  group('kayıt edilebilir alan adı', () {
    void check(String host, String? expected) =>
        expect(psl.registrableDomain(host), expected, reason: host);

    // Listenin resmî test kümesinden (tests/test_psl.txt) seçmeler.
    test('düz kurallar', () {
      check('com', null);
      check('example.com', 'example.com');
      check('b.example.com', 'example.com');
      check('a.b.example.com', 'example.com');
      check('uk.com', null);
      check('example.uk.com', 'example.uk.com');
      check('a.b.example.uk.com', 'example.uk.com');
      check('test.ac', 'test.ac');
      check('c.gov.cn', 'c.gov.cn');
    });

    test('joker ve istisna kuralları', () {
      check('mm', null);
      check('c.mm', null);
      check('b.c.mm', 'b.c.mm');
      check('a.b.c.mm', 'b.c.mm');
      check('jp', null);
      check('test.jp', 'test.jp');
      check('www.test.jp', 'test.jp');
      check('ac.jp', null);
      check('kyoto.jp', null);
      check('test.kyoto.jp', 'test.kyoto.jp');
      check('ide.kyoto.jp', null);
      check('b.ide.kyoto.jp', 'b.ide.kyoto.jp');
      check('c.kobe.jp', null);
      check('b.c.kobe.jp', 'b.c.kobe.jp');
      check('city.kobe.jp', 'city.kobe.jp');
      check('www.city.kobe.jp', 'city.kobe.jp');
      check('ck', null);
      check('test.ck', null);
      check('b.test.ck', 'b.test.ck');
      check('www.ck', 'www.ck');
      check('www.www.ck', 'www.ck');
    });

    test('uluslararası alan adları', () {
      check('食狮.com.cn', 'xn--85x722f.com.cn');
      check('食狮.公司.cn', 'xn--85x722f.xn--55qx5d.cn');
      check('www.食狮.公司.cn', 'xn--85x722f.xn--55qx5d.cn');
      check('shishi.公司.cn', 'shishi.xn--55qx5d.cn');
      check('公司.cn', null);
      check('xn--85x722f.xn--55qx5d.cn', 'xn--85x722f.xn--55qx5d.cn');
      check('www.xn--85x722f.xn--55qx5d.cn', 'xn--85x722f.xn--55qx5d.cn');
      check('xn--55qx5d.cn', null);
    });

    test('Türkiye ve özel bölüm', () {
      check('com.tr', null);
      check('banka.com.tr', 'banka.com.tr');
      check('giris.banka.com.tr', 'banka.com.tr');
      check('ankara.bel.tr', 'ankara.bel.tr');
      check('github.io', null);
      check('ali.github.io', 'ali.github.io');
    });

    test('bilinmeyen sonek ve IP adresi', () {
      check('example.example', 'example.example');
      check('b.example.example', 'example.example');
      check('192.168.1.1', null);
      check('[::1]', null);
    });
  });

  test('bozuk liste reddediliyor', () {
    expect(
      () => PublicSuffixList.parse('com\nnet\n'),
      throwsA(isA<InvalidPublicSuffixListException>()),
    );
  });

  group('eşleştirme', () {
    const ownCert =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const otherCert =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    var nextId = 0;

    LoginItem item(
      String name, {
      List<String> urls = const [],
      List<LoginApp> apps = const [],
    }) {
      return LoginItem(
        id: Uint8List.fromList([nextId++]),
        content: LoginContent(
          name: name,
          username: 'ali',
          password: 'parola',
          urls: urls,
          apps: apps,
        ),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
    }

    final items = [
      item('Banka giriş', urls: ['https://giris.banka.com.tr/']),
      item('Banka', urls: ['banka.com.tr']),
      item('Sahte banka', urls: ['https://sahte-banka.com.tr']),
      item('Başka', urls: ['https://banka.com']),
      item('GitHub Ali', urls: ['https://ali.github.io']),
      item(
        'Uygulama',
        apps: [
          LoginApp(
            packageName: 'com.banka.mobil',
            certsSha256: const [ownCert],
          ),
        ],
      ),
      item(
        'Uygulama başka imza',
        apps: [
          LoginApp(
            packageName: 'com.banka.mobil',
            certsSha256: const [otherCert],
          ),
        ],
      ),
    ];

    // Telefondaki com.banka.mobil yalnızca ownCert ile imzalı.
    Future<bool> signedWith(String packageName, List<String> certs) async =>
        packageName == 'com.banka.mobil' && certs.every((c) => c == ownCert);

    Future<LoginMatches> match(AutofillTarget target) => matchLogins(
      target: target,
      items: items,
      suffixes: psl,
      hasSigningCertificates: signedWith,
    );

    List<(String, LoginMatchKind)> names(LoginMatches result) => [
      for (final m in result.matches) (m.item.content.name, m.kind),
    ];

    test('tarayıcıda tam alan adı önce, aynı site sonra', () async {
      final result = await match(
        const AutofillTarget(
          packageName: 'com.android.chrome',
          webDomain: 'giris.banka.com.tr',
          webScheme: 'https',
        ),
      );
      expect(names(result), [
        ('Banka giriş', LoginMatchKind.exactHost),
        ('Banka', LoginMatchKind.sameSite),
      ]);
    });

    test('benzer görünen alan adları eşleşmiyor', () async {
      final result = await match(
        const AutofillTarget(
          packageName: 'com.android.chrome',
          webDomain: 'banka.com.tr.sahte.com',
        ),
      );
      expect(result.matches, isEmpty);
    });

    test('github.io altındaki başka kullanıcı eşleşmiyor', () async {
      final result = await match(
        const AutofillTarget(
          packageName: 'com.android.chrome',
          webDomain: 'veli.github.io',
        ),
      );
      expect(result.matches, isEmpty);
    });

    test('uygulama paket adı ve imzayla eşleşiyor', () async {
      final result = await match(
        const AutofillTarget(packageName: 'com.banka.mobil'),
      );
      expect(names(result), [('Uygulama', LoginMatchKind.app)]);
      expect(result.signatureMismatches.map((i) => i.content.name), [
        'Uygulama başka imza',
      ]);
    });

    test('WebView alan adı eşleştirmede kullanılmıyor', () async {
      final result = await match(
        const AutofillTarget(
          packageName: 'com.kotu.uygulama',
          untrustedWebDomain: 'giris.banka.com.tr',
        ),
      );
      expect(result.matches, isEmpty);
      expect(result.signatureMismatches, isEmpty);
    });

    test('tarayıcıda uygulama bağı dikkate alınmıyor', () async {
      final bound = item(
        'Chrome kaydı',
        apps: [
          LoginApp(
            packageName: 'com.android.chrome',
            certsSha256: const [ownCert],
          ),
        ],
      );
      final result = await matchLogins(
        target: const AutofillTarget(
          packageName: 'com.android.chrome',
          webDomain: 'example.org',
        ),
        items: [bound],
        suffixes: psl,
        hasSigningCertificates: (_, _) async => true,
      );
      expect(result.matches, isEmpty);
    });
  });
}

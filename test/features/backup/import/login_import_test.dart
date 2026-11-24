import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/backup/data/import/login_import.dart';
import 'package:keykey/features/vault/data/card_number.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/login_passkey.dart';

import '../../../support/passkey_test_keys.dart';

/// Örneklerin bir kısmı Bitwarden'ın içe aktarma testlerinden
/// (bitwarden/clients, GPL-3.0); diğerleri dışa aktaranların yazdığı
/// sütunlarla KeyKey için hazırlandı. Hepsi deneme verisi.
void main() {
  LoginExport read(String name) => LoginExportReader.read(
    File('test/fixtures/import/logins/$name').readAsBytesSync(),
  );

  group('Firefox', () {
    test('ad adresten geliyor, tırnaklı alanlar ve CRLF', () {
      final export = read('firefox.csv');
      expect(export.source, LoginExportSource.firefoxCsv);
      expect(export.skipped, 0);
      expect(export.logins.map((login) => login.name), [
        'forum.example.org',
        'router.example.net',
        'basit.example.com',
      ]);
      final forum = export.logins[0];
      expect(forum.urls, ['https://forum.example.org']);
      expect(forum.username, 'ayşe.yılmaz');
      expect(forum.password, 'sahte-Sifre-1');
      expect(forum.notes, isEmpty);
      expect(export.logins[1].password, 'sahte, "Sifre" 2');
      expect(export.logins[2].username, isEmpty);
    });

    test('Chrome dosyası Firefox sanılmıyor', () {
      expect(read('chrome_simple.csv').source, LoginExportSource.chromeCsv);
    });
  });

  group('Chrome', () {
    test('basit dosya', () {
      final export = read('chrome_simple.csv');
      expect(export.source, LoginExportSource.chromeCsv);
      final login = export.logins.single;
      expect(login.name, 'www.example.com');
      expect(login.urls, ['https://www.example.com/']);
      expect(login.username, 'username@example.com');
      expect(login.password, 'wpC9qFvsbWQK5Z');
    });

    test('CRLF ve çok satırlı not; notta satır sonu LF oluyor', () {
      final login = read('chrome_note.csv').logins.single;
      expect(
        login.notes,
        'First line, with a comma\nSecond line with "quotes"',
      );
      expect(login.password, 'fake-password');
    });

    test('android:// adresi alınmıyor, ad kullanıcı adından geliyor', () {
      final login = read('chrome_android.csv').logins.single;
      expect(login.urls, isEmpty);
      expect(login.name, 'username@example.com');
      expect(login.password, 'Qh6W4Wz55YGFNU');
    });

    test('Android Chrome 145 ile alınmış gerçek dışa aktarma', () {
      // Google Parola Yöneticisi > Ayarlar > Parolaları dışa aktar. İçe
      // aktarılan dosyadaki "name" yerine alan adını yazıyor, satır sonu LF.
      final export = read('chrome_gercek.csv');
      expect(export.source, LoginExportSource.chromeCsv);
      expect(export.skipped, 0);
      expect(export.logins.map((login) => login.name), [
        'banka.example.com',
        'basit.example.net',
        'forum.example.org',
      ]);
      final bank = export.logins[0];
      expect(bank.urls, ['https://banka.example.com/giris']);
      expect(bank.username, 'ayşe.yılmaz');
      expect(bank.password, 'sahte-Sifre-1');
      expect(bank.notes, 'İlk satır, virgüllü\nİkinci satır "tırnaklı"');
      final simple = export.logins[1];
      expect(simple.username, isEmpty);
      expect(simple.notes, 'boş kullanıcı adı');
      expect(export.logins[2].notes, isEmpty);
    });
  });

  group('KeePassXC', () {
    test('grup klasör oluyor, kök atılıyor, TOTP alınıyor', () {
      final export = read('keepassxc.csv');
      expect(export.source, LoginExportSource.keepassxcCsv);
      expect(export.logins, hasLength(2));
      // Hiç bilgi taşımayan üçüncü satır atlandı.
      expect(export.skipped, 1);
      final bank = export.logins[0];
      expect(bank.name, 'Örnek Banka');
      expect(bank.folder, isNull);
      expect(bank.totp, startsWith('otpauth://totp/Banka:ayse'));
      final mail = export.logins[1];
      expect(mail.folder, 'E-posta');
      expect(mail.notes, 'İki satırlı\nnot, virgüllü');
      expect(mail.totp, isNull);
    });

    test('KeePassXC 2.8.0 CLI ile alınmış gerçek dışa aktarma', () {
      // keepassxc-cli export -f csv; kök grubun adı arayüz diline göre
      // değişiyor (burada "Parolalar").
      final export = read('keepassxc_gercek.csv');
      expect(export.source, LoginExportSource.keepassxcCsv);
      expect(export.skipped, 0);
      expect(export.logins.map((login) => login.folder), [
        null,
        'E-posta',
        'E-posta/İş',
      ]);
      final bank = export.logins[0];
      expect(bank.notes, 'İki satırlı\nnot, "tırnaklı"');
      expect(bank.totp, contains('secret=JBSWY3DPEHPK3PXP'));
      expect(export.logins[1].urls, ['mail.example.com']);
      expect(export.logins[2].urls, isEmpty);
    });

    test('Group sütunu olmayan eski dosya', () {
      final export = read('keepassx_bitwarden.csv');
      expect(export.source, LoginExportSource.keepassxcCsv);
      expect(export.logins, hasLength(2));
      expect(export.logins[0].folder, isNull);
      expect(
        export.logins[1].totp,
        'otpauth://totp/Another?secret=ABCD1234EFGH5678',
      );
    });
  });

  group('Bitwarden', () {
    test('2026-11 sürümüyle alınmış gerçek JSON dışa aktarma', () {
      // Kullanıcının hesabından alınan şifresiz dışa aktarma. Ad, kullanıcı
      // adı ve parola sahte değerlerle değiştirildi; geri kalan baytlar
      // Bitwarden'ın yazdığı gibi (adres yok, fido2Credentials boş, sonda
      // satır sonu yok, kullanıcı adının sonunda boşluk var).
      final export = read('bitwarden_gercek.json');
      expect(export.source, LoginExportSource.bitwardenJson);
      expect(export.skipped, 0);
      expect(export.logins.map((login) => login.name), [
        'ornek.com',
        'Örnek Sosyal',
      ]);
      final first = export.logins[0];
      expect(first.username, 'deneme@example.com');
      expect(first.password, 'sahte-Sifre-4');
      expect(first.urls, isEmpty);
      expect(first.folder, isNull);
      expect(first.fields, isEmpty);
      expect(first.totp, isNull);
      expect(export.logins[1].password, 'sahte-Sifre-5');
    });

    test('CSV: birden çok adres, özel alanlar, favori ve klasör', () {
      final export = read('bitwarden.csv');
      expect(export.source, LoginExportSource.bitwardenCsv);
      expect(export.skipped, 0);
      final note = export.notes.single;
      expect(note.name, 'Gizli not');
      expect(note.text, 'Not içeriği');
      final forum = export.logins[0];
      expect(forum.urls, [
        'https://forum.example.com',
        'https://m.forum.example.com',
      ]);
      expect(forum.favorite, isTrue);
      expect(forum.folder, 'Sosyal');
      expect(forum.totp, 'JBSWY3DPEHPK3PXP');
      expect(forum.fields.map((f) => (f.name, f.value)), [
        ('PIN', '1234'),
        ('Soru: Evcil', 'kedi'),
      ]);
      // androidapp:// adresi alınmadı, ad ve parola kaldı.
      final app = export.logins[1];
      expect(app.urls, isEmpty);
      expect(app.name, 'Uygulama');
    });

    test('JSON: klasör, gizli alan, TOTP; kimlik atlanıyor', () {
      final export = read('bitwarden.json');
      expect(export.source, LoginExportSource.bitwardenJson);
      expect(export.logins, hasLength(2));
      expect(export.cards, hasLength(1));
      expect(export.notes, hasLength(1));
      expect(export.skipped, 1, reason: 'kimlik');
      final company = export.logins[0];
      expect(company.folder, 'İş');
      expect(company.favorite, isTrue);
      expect(company.urls, ['https://sirket.example.com']);
      expect(company.fields.map((f) => (f.name, f.value, f.hidden)), [
        ('PIN', '4321', true),
        ('Bölüm', 'BT', false),
      ]);
      expect(company.totp, contains('digits=8'));
      final simple = export.logins[1];
      expect(simple.name, 'Basit');
      expect(simple.username, '');
      expect(simple.notes, '');
    });

    test('JSON: kart alanları, PIN ve kalan özel alanlar', () {
      final imported = read('bitwarden.json').cards.single;
      expect(imported.adjusted, isFalse);
      final card = imported.content;
      expect(card.name, 'Kart');
      expect(card.cardholder, 'Ali Veli');
      expect(card.number, '4111111111111111');
      expect(card.expiry, CardExpiry(month: 1, year: 2028));
      expect(card.securityCode, '123');
      expect(card.pin, '1234');
      expect(card.folder, 'İş');
      expect(card.favorite, isTrue);
      expect(card.notes, 'kart notu\nBanka: Deneme Bankası');
    });

    test('JSON: not metnine özel alanlar ekleniyor', () {
      final note = read('bitwarden.json').notes.single;
      expect(note.name, 'Not');
      expect(note.text, 'gizli\nAğ: Ev');
      expect(note.folder, 'İş');
    });

    test('boş dışa aktarma', () {
      final export = read('bitwarden_empty.json');
      expect(export.logins, isEmpty);
      expect(export.skipped, 0);
    });

    test('parola korumalı dışa aktarma ayrıca söyleniyor', () {
      expect(
        () => read('bitwarden_password_protected.json'),
        throwsA(isA<EncryptedBitwardenExportException>()),
      );
    });
  });

  group("Bitwarden passkey'leri", () {
    LoginExport readItems(List<Map<String, Object?>> items) =>
        LoginExportReader.read(
          Uint8List.fromList(
            utf8.encode(jsonEncode({'encrypted': false, 'items': items})),
          ),
        );

    Map<String, Object?> credential({
      required String id,
      String rpId = 'github.com',
      String curve = 'P-256',
      String algorithm = 'ECDSA',
      String key = p256Pkcs8B64Url,
      String user = 'furkan',
    }) => {
      'credentialId': id,
      'keyType': 'public-key',
      'keyAlgorithm': algorithm,
      'keyCurve': curve,
      'keyValue': key,
      'rpId': rpId,
      'userHandle': base64UrlNoPad(utf8.encode('id-$user')),
      'userName': user,
      'counter': '0',
      'rpName': rpId,
      'userDisplayName': 'Furkan',
      'discoverable': 'true',
      'creationDate': '2026-03-05T12:00:00.000Z',
    };

    Map<String, Object?> login(
      String name,
      List<Map<String, Object?>> credentials, {
      String? password,
    }) => {
      'type': 1,
      'name': name,
      'login': {
        'username': null,
        'password': password,
        'uris': <Object?>[],
        'fido2Credentials': credentials,
      },
    };

    test("GUID ve b64. kimlikli P-256 passkey'ler alınıyor", () {
      final export = readItems([
        login('GitHub', [
          credential(id: '6a7b1c2d-3e4f-4a5b-8c9d-0e1f2a3b4c5d'),
          credential(id: 'b64.AQIDBAUGBwgJCgsMDQ4PEA', rpId: 'example.com'),
        ], password: 'parola'),
      ]);

      expect(export.skipped, 0);
      expect(export.skippedPasskeys, 0);
      final passkeys = export.logins.single.passkeys;
      expect(passkeys, hasLength(2));
      final first = passkeys[0];
      expect(first.credentialId, [
        0x6a, 0x7b, 0x1c, 0x2d, 0x3e, 0x4f, 0x4a, 0x5b, //
        0x8c, 0x9d, 0x0e, 0x1f, 0x2a, 0x3b, 0x4c, 0x5d,
      ]);
      expect(first.rpId, 'github.com');
      expect(utf8.decode(first.userHandle), 'id-furkan');
      expect(first.userName, 'furkan');
      expect(first.userDisplayName, 'Furkan');
      expect(first.privateKey, base64UrlDecodeNoPad(p256Pkcs8B64Url));
      expect(first.createdAt, DateTime.utc(2026, 3, 5, 12));
      expect(passkeys[1].credentialId, List.generate(16, (i) => i + 1));
      expect(passkeys[1].rpId, 'example.com');
    });

    test("yalnızca passkey'i olan giriş atlanmıyor", () {
      final export = readItems([
        login('webauthn.io', [credential(id: 'b64.AQIDBAUGBwgJCgsMDQ4PEA')]),
      ]);

      expect(export.skipped, 0);
      expect(export.logins.single.name, 'webauthn.io');
      expect(export.logins.single.passkeys, hasLength(1));
    });

    test(
      'P-256 olmayan ya da bozuk passkey atlanıp sayılıyor, giriş kalıyor',
      () {
        final export = readItems([
          login('Eski', [
            credential(id: 'b64.AQ', curve: 'P-384', key: p384Pkcs8B64),
            credential(id: 'b64.Ag', algorithm: 'EdDSA'),
            credential(id: 'kimlik-değil'),
            credential(id: 'b64.Aw', key: p384Pkcs8B64),
            credential(id: 'b64.BA', rpId: 'Örnek Site'),
            credential(id: 'b64.BQ'),
          ], password: 'parola'),
        ]);

        expect(export.skipped, 0);
        expect(export.skippedPasskeys, 5);
        expect(export.logins.single.password, 'parola');
        expect(export.logins.single.passkeys.single.credentialId, [5]);
      },
    );

    test('kayıt başına sınırdan fazlası atlanıp sayılıyor', () {
      final export = readItems([
        login('Çok', [
          for (var i = 1; i <= LoginContent.maxPasskeys + 2; i++)
            credential(id: 'b64.${base64UrlNoPad([i])}'),
        ]),
      ]);

      expect(
        export.logins.single.passkeys,
        hasLength(LoginContent.maxPasskeys),
      );
      expect(export.skippedPasskeys, 2);
    });
  });

  group('Bitwarden kartında biçime uymayan değerler', () {
    LoginExport readItems(
      List<Map<String, Object?>> items, {
      ImportLabels labels = ImportLabels.english,
    }) => LoginExportReader.read(
      Uint8List.fromList(
        utf8.encode(jsonEncode({'encrypted': false, 'items': items})),
      ),
      labels: labels,
    );

    ImportedCard cardOf(
      Map<String, Object?> card, {
      List<Map<String, Object?>> fields = const [],
      ImportLabels labels = ImportLabels.english,
    }) => readItems([
      {'type': 3, 'name': 'Kart', 'fields': fields, 'card': card},
    ], labels: labels).cards.single;

    test('rakam dışı numara boş kalır, ham değeri nota gider', () {
      final card = cardOf({'number': 'abc'});
      expect(card.adjusted, isTrue);
      expect(card.content.number, isEmpty);
      expect(card.content.notes, 'Card number: abc');
    });

    test('etiketler arayüz dilinden gelir', () {
      final card = cardOf(
        {'number': 'abc', 'code': '12345'},
        labels: const ImportLabels(
          cardNumber: 'Kart numarası',
          expiry: 'Son kullanma',
          securityCode: 'Güvenlik kodu',
        ),
      );
      expect(card.content.notes, 'Kart numarası: abc\nGüvenlik kodu: 12345');
    });

    test(
      'ay ve yıl metin ya da sayı olabilir, iki haneli yıla 2000 eklenir',
      () {
        expect(
          cardOf({'expMonth': 7, 'expYear': 2031}).content.expiry,
          CardExpiry(month: 7, year: 2031),
        );
        expect(
          cardOf({'expMonth': '12', 'expYear': '30'}).content.expiry,
          CardExpiry(month: 12, year: 2030),
        );
      },
    );

    test('okunamayan ya da tek başına ay ve yıl nota gider', () {
      final bad = cardOf({'expMonth': '13', 'expYear': '28'});
      expect(bad.content.expiry, isNull);
      expect(bad.adjusted, isTrue);
      expect(bad.content.notes, 'Expiry: 13/28');

      final monthOnly = cardOf({'expMonth': '5', 'expYear': null});
      expect(monthOnly.content.expiry, isNull);
      expect(monthOnly.content.notes, 'Expiry: 5/');

      final none = cardOf({'expMonth': null, 'expYear': ''});
      expect(none.adjusted, isFalse);
      expect(none.content.notes, isEmpty);
    });

    test('sayı olarak yazılmış numara, kod ve kart sahibi okunur', () {
      final card = cardOf({
        'number': 4111111111111111,
        'code': 123,
        'cardholderName': 42,
        'expMonth': 7.0,
        'expYear': 2031,
      });
      expect(card.adjusted, isFalse);
      expect(card.content.number, '4111111111111111');
      expect(card.content.securityCode, '123');
      expect(card.content.cardholder, '42');
      expect(card.content.expiry, CardExpiry(month: 7, year: 2031));
    });

    test('başka türde değer atılmaz, nota gider', () {
      final card = cardOf({'number': 1.5, 'code': true});
      expect(card.adjusted, isTrue);
      expect(card.content.number, isEmpty);
      expect(card.content.securityCode, isEmpty);
      expect(card.content.notes, 'Card number: 1.5\nSecurity code: true');
    });

    test('4 haneden uzun güvenlik kodu nota gider', () {
      final card = cardOf({'code': '12345'});
      expect(card.content.securityCode, isEmpty);
      expect(card.content.notes, 'Security code: 12345');
    });

    test('rakam dışı PIN alanı PIN olmaz, nota gider', () {
      final card = cardOf(
        const {},
        fields: [
          {'name': 'PIN', 'value': '12ab', 'type': 1},
          {'name': 'Pin', 'value': '9876', 'type': 1},
        ],
      );
      expect(card.content.pin, '9876');
      expect(card.content.notes, 'PIN: 12ab');
    });

    test("64 KiB'ı aşan not atlanır ve sayılır", () {
      final export = readItems([
        {'type': 2, 'name': 'Uzun', 'notes': 'a' * 70000},
        {'type': 2, 'name': 'Kısa', 'notes': 'b'},
      ]);
      expect(export.notes.single.name, 'Kısa');
      expect(export.skipped, 1);
    });

    test('adı ve içeriği boş kart ya da not atlanır', () {
      final export = readItems([
        {'type': 3, 'name': '', 'card': <String, Object?>{}},
        {'type': 2, 'name': ' ', 'notes': ''},
      ]);
      expect(export.cards, isEmpty);
      expect(export.notes, isEmpty);
      expect(export.skipped, 2);
    });
  });

  group('tanınmayan dosyalar', () {
    void expectUnknown(String text) => expect(
      () => LoginExportReader.read(Uint8List.fromList(utf8.encode(text))),
      throwsA(isA<UnknownLoginExportException>()),
      reason: text,
    );

    test('başka sütunlar, bozuk JSON, boş dosya, bozuk UTF-8', () {
      expectUnknown('');
      expectUnknown('a,b,c\n1,2,3');
      expectUnknown('{"items": 3}');
      expectUnknown('{bozuk');
      expectUnknown('[]');
      expectUnknown('"kapanmayan');
      expect(
        () => LoginExportReader.read(Uint8List.fromList([0xC3, 0x28])),
        throwsA(isA<UnknownLoginExportException>()),
      );
    });

    test('sütun sayısı tutmayan satır atlanıyor', () {
      final export = LoginExportReader.read(
        Uint8List.fromList(
          utf8.encode('name,url,username,password\na,b\nx,https://x,u,p\n'),
        ),
      );
      expect(export.logins.single.name, 'x');
      expect(export.skipped, 1);
    });

    test('rastgele bozulan dosyalar yalnızca kendi hatalarını veriyor', () {
      final random = Random(5);
      final samples = [
        for (final name in [
          'bitwarden.json',
          'bitwarden.csv',
          'keepassxc.csv',
          'chrome_note.csv',
          'firefox.csv',
        ])
          File('test/fixtures/import/logins/$name').readAsBytesSync(),
      ];
      for (var round = 0; round < 1000; round++) {
        final sample = samples[round % samples.length];
        final changed = Uint8List.fromList(sample);
        for (var i = 0; i < 1 + random.nextInt(4); i++) {
          changed[random.nextInt(changed.length)] = random.nextInt(256);
        }
        try {
          LoginExportReader.read(changed);
        } on UnknownLoginExportException {
          // Beklenen.
        } on EncryptedBitwardenExportException {
          // Beklenen.
        }
      }
    });
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/backup/data/import/login_import.dart';

/// Örneklerin bir kısmı Bitwarden'ın içe aktarma testlerinden
/// (bitwarden/clients, GPL-3.0); diğerleri dışa aktaranların yazdığı
/// sütunlarla KeyKey için hazırlandı. Hepsi deneme verisi.
void main() {
  LoginExport read(String name) => LoginExportReader.read(
    File('test/fixtures/import/logins/$name').readAsBytesSync(),
  );

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
    test('CSV: birden çok adres, özel alanlar, favori ve klasör', () {
      final export = read('bitwarden.csv');
      expect(export.source, LoginExportSource.bitwardenCsv);
      expect(export.skipped, 1, reason: 'not satırı');
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

    test('JSON: klasör, gizli alan, TOTP; kart ve not atlanıyor', () {
      final export = read('bitwarden.json');
      expect(export.source, LoginExportSource.bitwardenJson);
      expect(export.logins, hasLength(2));
      expect(export.skipped, 2);
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

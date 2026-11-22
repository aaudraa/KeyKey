import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_import.dart';
import 'package:keykey/features/backup/data/import/login_import.dart';

import '../../../../support/kdbx_fixtures.dart';

Future<LoginExport> _export(String path) async =>
    kdbxToLoginExport(await kdbxFixtureDatabase(path));

ImportedLogin _named(LoginExport export, String name) =>
    export.logins.firstWhere((login) => login.name == name);

void main() {
  group('keykey_ornek.kdbx', () {
    late LoginExport export;
    setUpAll(() async => export = await _export('keykey/keykey_ornek.kdbx'));

    test('kaynak ve sayılar', () {
      expect(export.source, LoginExportSource.keepassKdbx);
      expect(export.inRecycleBin, 1);
      expect(export.withAttachments, 1);
      // Hiçbir alanı olmayan kayıt.
      expect(export.skipped, 1);
    });

    test('grup yolu klasör olur', () {
      final github = _named(export, 'GitHub');
      expect(github.folder, 'E-posta/İş');
      expect(_named(export, 'Posta').folder, 'E-posta');
      expect(_named(export, 'Steam').folder, isNull);
    });

    test('temel alanlar ve not satır sonları', () {
      final github = _named(export, 'GitHub');
      expect(github.username, 'furkan');
      expect(github.password, 'gizli-parola');
      expect(github.notes, 'birinci satır\nikinci satır');
    });

    test('ek adresler eklenir, uygulama adresi alınmaz', () {
      expect(_named(export, 'GitHub').urls, [
        'https://github.com/login',
        'https://gist.github.com',
      ]);
    });

    test('otp alanı 2FA olur', () {
      expect(
        _named(export, 'GitHub').totp,
        'otpauth://totp/GitHub:furkan?secret=JBSWY3DPEHPK3PXP&issuer=GitHub',
      );
    });

    test('KeePass 2 TimeOtp alanları 2FA olur', () {
      final totp = Uri.parse(_named(export, 'Posta').totp!);
      expect(totp.scheme, 'otpauth');
      expect(totp.host, 'totp');
      expect(totp.queryParameters, {
        'secret': 'GEZDGNBVGY3TQOJQ',
        'algorithm': 'SHA256',
        'digits': '8',
        'period': '60',
      });
    });

    test('eski KeePassXC Steam ayarı Steam olur', () {
      expect(_named(export, 'Steam').totp, 'steam://JBSWY3DPEHPK3PXP');
    });

    test('özel alanlar; 2FA, adres ve iç alanlar tekrar gelmez', () {
      expect(_named(export, 'GitHub').fields, [
        (name: 'Kurtarma kodu', value: '1234-5678', hidden: true),
        (name: 'Açık alan', value: 'görünür', hidden: false),
      ]);
      expect(_named(export, 'Posta').fields, isEmpty);
      expect(_named(export, 'Steam').fields, isEmpty);
    });

    test('alan başvurusu çözülür', () {
      final reference = _named(export, 'Başvuru');
      expect(reference.username, 'furkan');
      expect(reference.password, 'gizli-parola');
    });

    test('yalnızca notu olan kayıt güvenli not olur', () {
      expect(export.logins.map((l) => l.name), isNot(contains('Wi-Fi notu')));
      final note = export.notes.single;
      expect(note.name, 'Wi-Fi notu');
      expect(note.text, 'ağ: keykey\nşifre kutuda');
    });

    test('çöp kutusundaki kayıt alınmaz', () {
      expect(export.logins.map((l) => l.name), isNot(contains('Eski hesap')));
    });
  });

  group('test4.kdbx başvuruları', () {
    late LoginExport export;
    setUpAll(() async => export = await _export('pykeepass/test4.kdbx'));

    test('kopya ve kopyanın kopyası', () {
      expect(_named(export, 'foobar_entry - Clone').username, 'foobar');
      expect(
        _named(export, 'foobar_entry - Clone of clone').password,
        'foobar',
      );
    });

    test('ön ve son ekli başvuru', () {
      final entry = _named(
        export,
        'foobar_entry - Clone with prefix and suffix',
      );
      expect(entry.username, r'domain\foobar2');
      expect(entry.password, 'AfoobarBC');
    });

    test('adsız kayıt kullanıcı adıyla adlanır', () {
      expect(export.logins.map((l) => l.name), contains('blank_title'));
    });
  });

  test('NewDatabase: eski TOTP alanları ve büyük-küçük harf', () async {
    final export = await _export('keepassxc/NewDatabase.kdbx');
    final entry = _named(export, 'Sample Entry');
    expect(entry.totp, startsWith('otpauth://totp/'));
    expect(
      Uri.parse(entry.totp!).queryParameters['secret'],
      'HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ',
    );
    expect(entry.fields.map((f) => f.name), [
      'TestAttribute1',
      'testattribute1',
    ]);
    expect(export.withAttachments, 1);
  });

  test('çözülemeyen başvuru olduğu gibi kalır', () {
    expect(
      resolveKdbxReferences('{REF:P@I:00000000000000000000000000000000}', {}),
      '{REF:P@I:00000000000000000000000000000000}',
    );
    expect(resolveKdbxReferences('{REF:P@T:GitHub}', {}), '{REF:P@T:GitHub}');
  });

  test('döngülü başvuru 10 adımda durur', () {
    const id = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
    final entries = {
      id: {'Password': '{REF:P@I:$id}'},
    };
    expect(resolveKdbxReferences('{REF:P@I:$id}', entries), contains('{REF:'));
  });
}

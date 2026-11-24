import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_import.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_xml.dart';
import 'package:keykey/features/backup/data/import/login_import.dart';
import 'package:keykey/features/vault/data/login_passkey.dart';

import '../../../../support/kdbx_fixtures.dart';
import '../../../../support/passkey_test_keys.dart';

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

  test('çok dallı başvuru zinciri sınırlı işte biter', () {
    // Her kayıt bir sonrakine beş kez başvuruyor: sınırsız çözüm 5^10 iş
    // ve 5^10 uzunluk olurdu.
    String id(int i) => i.toRadixString(16).padLeft(32, '0').toUpperCase();
    final entries = {
      for (var i = 0; i < 12; i++)
        id(i): {'Password': '{REF:P@I:${id(i + 1)}}' * 5},
      id(12): {'Password': 'x' * 100},
    };
    final watch = Stopwatch()..start();
    final result = resolveKdbxReferences('{REF:P@I:${id(0)}}', entries);
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    expect(result.length, lessThanOrEqualTo(maxKdbxReferenceLength));
    expect(result, contains('{REF:'));
  });

  group('yalnız notu olan kayıt', () {
    LoginExport single(Map<String, ({String value, bool protected})> strings) =>
        kdbxToLoginExport(
          KdbxDatabase(
            entries: [
              const KdbxEntry(
                uuid: 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
                groupPath: [],
                strings: {
                  'Title': (value: 'Kaynak', protected: false),
                  'UserName': (value: 'ali', protected: false),
                  'Password': (value: 'kaynak-parola', protected: true),
                },
                attachments: 0,
              ),
              KdbxEntry(
                uuid: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
                groupPath: const [],
                strings: strings,
                attachments: 0,
              ),
            ],
            recycledEntries: 0,
          ),
        );

    test('korumalı alanı varsa gizli alanlı kayıt olur, not olmaz', () {
      final export = single({
        'Title': (value: 'Kasa', protected: false),
        'Notes': (value: 'kapı kodu', protected: false),
        'PIN': (value: '4321', protected: true),
      });
      expect(export.notes, isEmpty);
      final login = _named(export, 'Kasa');
      expect(login.notes, 'kapı kodu');
      expect(login.fields.single, (name: 'PIN', value: '4321', hidden: true));
    });

    test('parolaya başvuran korumasız alan gizli gelir', () {
      final export = single({
        'Title': (value: 'Kopya', protected: false),
        'Notes': (value: 'not', protected: false),
        'Eski': (
          value: '{REF:P@I:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB}',
          protected: false,
        ),
      });
      expect(export.notes, isEmpty);
      expect(_named(export, 'Kopya').fields.single, (
        name: 'Eski',
        value: 'kaynak-parola',
        hidden: true,
      ));
    });

    test('korumasız alanlarla yine güvenli not olur', () {
      final export = single({
        'Title': (value: 'Wi-Fi', protected: false),
        'Notes': (value: 'ev', protected: false),
        'Ağ': (value: 'keykey', protected: false),
      });
      expect(export.notes.single.text, 'ev\nAğ: keykey');
    });
  });

  test('yüzde işaretli otp alanı okumayı durdurmaz', () {
    // Uri.splitQueryString bozuk kaçışta ArgumentError fırlatıyordu.
    final export = kdbxToLoginExport(
      const KdbxDatabase(
        entries: [
          KdbxEntry(
            uuid: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
            groupPath: [],
            strings: {
              'Title': (value: 'Banka', protected: false),
              'Password': (value: 'parola', protected: true),
              'otp': (value: 'Kurtarma kodu: 100%', protected: false),
            },
            attachments: 0,
          ),
        ],
        recycledEntries: 0,
      ),
    );
    final entry = _named(export, 'Banka');
    expect(entry.password, 'parola');
    expect(entry.totp, isNull);
  });

  group('KeePassXC passkey alanları', () {
    LoginExport single(Map<String, ({String value, bool protected})> extra) =>
        kdbxToLoginExport(
          KdbxDatabase(
            entries: [
              KdbxEntry(
                uuid: 'CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC',
                groupPath: const [],
                strings: {
                  'Title': (value: 'webauthn.io', protected: false),
                  'UserName': (value: 'furkan', protected: false),
                  'URL': (value: 'https://webauthn.io', protected: false),
                  ...extra,
                },
                attachments: 0,
              ),
            ],
            recycledEntries: 0,
          ),
        );

    Map<String, ({String value, bool protected})> passkey({
      String pem = p256Pem,
      String id = 'AQIDBAUGBwgJCgsMDQ4PEA',
    }) => {
      'KPEX_PASSKEY_CREDENTIAL_ID': (value: id, protected: false),
      'KPEX_PASSKEY_PRIVATE_KEY_PEM': (value: pem, protected: true),
      'KPEX_PASSKEY_RELYING_PARTY': (value: 'webauthn.io', protected: false),
      'KPEX_PASSKEY_USERNAME': (value: 'furkan', protected: false),
      'KPEX_PASSKEY_USER_HANDLE': (
        value: base64UrlNoPad('id-furkan'.codeUnits),
        protected: false,
      ),
    };

    test('passkey olur, alanları özel alana düşmez', () {
      final export = single(passkey());
      final login = export.logins.single;

      expect(export.skippedPasskeys, 0);
      expect(login.fields, isEmpty);
      final key = login.passkeys.single;
      expect(key.credentialId, List.generate(16, (i) => i + 1));
      expect(key.rpId, 'webauthn.io');
      expect(key.userName, 'furkan');
      expect(String.fromCharCodes(key.userHandle), 'id-furkan');
      expect(key.privateKey, base64UrlDecodeNoPad(p256Pkcs8B64Url));
    });

    test('P-256 olmayan ya da eksik passkey atlanıp sayılıyor', () {
      const p384 =
          '-----BEGIN PRIVATE KEY-----\n$p384Pkcs8B64\n'
          '-----END PRIVATE KEY-----';
      expect(single(passkey(pem: p384)).skippedPasskeys, 1);
      expect(single(passkey(id: '')).skippedPasskeys, 1);
      final export = single(passkey(pem: p384));
      expect(export.logins.single.passkeys, isEmpty);
      expect(export.logins.single.fields, isEmpty);
    });

    test('passkey alanı olmayan kayıtta sayaç sıfır', () {
      expect(single(const {}).skippedPasskeys, 0);
    });
  });
}

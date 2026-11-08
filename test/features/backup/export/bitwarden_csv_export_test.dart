import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/backup/application/login_import_plan.dart';
import 'package:keykey/features/backup/data/export/bitwarden_csv_export.dart';
import 'package:keykey/features/backup/data/import/login_import.dart';
import 'package:keykey/features/vault/data/login_content.dart';

import '../../../support/fake_vault_service.dart';

void main() {
  final secret = Base32.decodeLenient('JBSWY3DPEHPK3PXP');

  final forum = FakeLoginRepository.item(
    LoginContent(
      name: 'Forum, eski',
      username: 'ali',
      password: '=deneme "Forum" 3 ',
      urls: const ['https://forum.example.com', 'https://m.forum.example.com'],
      apps: [
        LoginApp(packageName: 'com.example.forum', certsSha256: ['ab' * 32]),
      ],
      notes: 'İki satırlı\nnot',
      folder: 'Sosyal',
      favorite: true,
      customFields: const [
        LoginCustomField(name: 'PIN', value: '1234', hidden: true),
        LoginCustomField(name: 'Soru', value: 'kedi'),
      ],
    ),
    id: 1,
  );
  final plain = FakeLoginRepository.item(
    const LoginContent(name: 'Basit', password: 'deneme-Basit-6'),
    id: 2,
  );
  final trashed = FakeLoginRepository.item(
    LoginContent(name: 'Silinen', trashedAt: DateTime.utc(2026, 11)),
    id: 3,
  );

  final forumOtp = FakeOtpRepository.item(
    OtpContent(
      parameters: OtpParameters.totp(secret: secret, digits: 8),
      issuer: 'Forum',
      account: 'ali',
      loginId: forum.id,
    ),
    id: 1,
  );
  final standalone = FakeOtpRepository.item(
    OtpContent(
      parameters: OtpParameters.totp(
        secret: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      ),
      issuer: 'Banka',
      account: 'ayse',
      favorite: true,
    ),
    id: 2,
  );
  final trashedOtp = FakeOtpRepository.item(
    OtpContent(
      parameters: OtpParameters.totp(secret: const [9, 9, 9, 9, 9]),
      issuer: 'Eski',
      trashedAt: DateTime.utc(2026, 11),
    ),
    id: 3,
  );

  LoginExport roundTrip() => LoginExportReader.read(
    Uint8List.fromList(
      utf8.encode(
        BitwardenCsvExport.build(
          logins: [forum, plain, trashed],
          otps: [standalone, forumOtp, trashedOtp],
        ),
      ),
    ),
  );

  test('KeyKey kendi dışa aktarmasını Bitwarden CSV olarak okuyor', () {
    final export = roundTrip();
    expect(export.source, LoginExportSource.bitwardenCsv);
    expect(export.skipped, 0);
    expect(export.logins.map((login) => login.name), [
      'Forum, eski',
      'Basit',
      'Banka',
    ]);
  });

  test('kayıt alanları kayıpsız geri geliyor', () {
    final login = roundTrip().logins[0];
    final content = forum.content;
    expect(login.username, content.username);
    expect(login.password, content.password);
    // Uygulama adresleri yazılıyor ama KeyKey onları içe almıyor.
    expect(login.urls, content.urls);
    expect(login.notes, content.notes);
    expect(login.folder, content.folder);
    expect(login.favorite, isTrue);
    // Bitwarden CSV'de gizli alan ayrımı yok.
    expect(login.fields.map((field) => (field.name, field.value)), [
      ('PIN', '1234'),
      ('Soru', 'kedi'),
    ]);
  });

  test('uygulama androidapp:// adresi olarak yazılıyor', () {
    final csv = BitwardenCsvExport.build(logins: [forum], otps: const []);
    expect(csv, contains('androidapp://com.example.forum'));
  });

  test('bağlı 2FA kaydın satırında, ayarlarıyla geri geliyor', () {
    final export = roundTrip();
    final otp = otpFromImport(
      export.logins[0].totp!,
      issuer: 'x',
      account: 'y',
    )!;
    expect(otp.parameters.secret, secret);
    expect(otp.parameters.digits, 8);
    expect(otp.issuer, 'Forum');
    expect(export.logins[1].totp, isNull);
  });

  test('bağlı olmayan 2FA ayrı satırda, çöp kutusundakiler yok', () {
    final export = roundTrip();
    final bank = export.logins[2];
    expect(bank.username, 'ayse');
    expect(bank.password, '');
    expect(bank.favorite, isTrue);
    final otp = otpFromImport(bank.totp!, issuer: '', account: '')!;
    expect(otp.parameters.secret, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    expect(otp.issuer, 'Banka');
    final csv = BitwardenCsvExport.build(logins: [trashed], otps: [trashedOtp]);
    expect(csv, isNot(contains('Silinen')));
    expect(csv, isNot(contains('Eski')));
  });

  test('boş kasa yalnızca başlık satırı', () {
    expect(
      BitwardenCsvExport.build(logins: const [], otps: const []),
      '${BitwardenCsvExport.columns.join(',')}\r\n',
    );
  });
}

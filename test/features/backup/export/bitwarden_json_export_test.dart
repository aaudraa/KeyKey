import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/authenticator/data/otp_content.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';
import 'package:keykey/features/backup/application/login_import_plan.dart';
import 'package:keykey/features/backup/data/export/bitwarden_json_export.dart';
import 'package:keykey/features/backup/data/import/login_import.dart';
import 'package:keykey/features/vault/data/card_content.dart';
import 'package:keykey/features/vault/data/card_number.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:keykey/features/vault/data/note_content.dart';

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
    ),
    id: 2,
  );
  final card = FakeRecordRepository.item(
    CardContent(
      name: 'Maaş kartı',
      cardholder: 'Ali Veli',
      number: '4111111111111111',
      expiry: CardExpiry(month: 3, year: 2029),
      securityCode: '123',
      pin: '0042',
      notes: 'Şubeden alındı',
      folder: 'Banka',
      favorite: true,
    ),
    id: 1,
  );
  final trashedCard = FakeRecordRepository.item(
    CardContent(
      name: 'Eski kart',
      number: '5555555555554444',
      trashedAt: DateTime.utc(2026, 11),
    ),
    id: 2,
  );
  final note = FakeRecordRepository.item(
    NoteContent(name: 'Ev Wi-Fi', text: 'ağ: Ev\nparola: kapi', folder: 'Ev'),
    id: 3,
  );

  String build() => BitwardenJsonExport.build(
    logins: [forum, plain],
    otps: [standalone, forumOtp],
    cards: [card, trashedCard],
    notes: [note],
  );

  LoginExport roundTrip() =>
      LoginExportReader.read(Uint8List.fromList(utf8.encode(build())));

  test("Bitwarden'ın şifresiz JSON biçiminde", () {
    final root = jsonDecode(build()) as Map<String, Object?>;
    expect(root.keys, unorderedEquals(['encrypted', 'folders', 'items']));
    expect(root['encrypted'], isFalse);
    final folders = [
      for (final folder in root['folders']! as List<Object?>)
        (folder! as Map<String, Object?>)['name'],
    ];
    expect(folders, unorderedEquals(['Sosyal', 'Banka', 'Ev']));
    final uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    );
    final items = root['items']! as List<Object?>;
    for (final item in items) {
      expect((item! as Map<String, Object?>)['id'], matches(uuid));
    }
    final cardItem =
        items.singleWhere((item) => (item! as Map)['type'] == 3)!
            as Map<String, Object?>;
    final cardData = cardItem['card']! as Map<String, Object?>;
    expect(cardData['brand'], 'Visa');
    expect(cardData['expMonth'], '3');
    expect(cardData['expYear'], '2029');
    expect(cardItem['fields'], [
      {'name': 'PIN', 'value': '0042', 'type': 1, 'linkedId': null},
    ]);
  });

  test('içe aktarmayla gidiş-dönüş: parolalar ve 2FA', () {
    final export = roundTrip();
    expect(export.source, LoginExportSource.bitwardenJson);
    expect(export.skipped, 0);
    expect(export.logins.map((login) => login.name), [
      'Forum, eski',
      'Basit',
      'Banka',
    ]);
    final login = export.logins[0];
    final content = forum.content;
    expect(login.username, content.username);
    expect(login.password, content.password);
    expect(login.urls, content.urls);
    expect(login.notes, content.notes);
    expect(login.folder, 'Sosyal');
    expect(login.favorite, isTrue);
    expect(
      login.fields.map((field) => (field.name, field.value, field.hidden)),
      [('PIN', '1234', true), ('Soru', 'kedi', false)],
    );
    final otp = otpFromImport(login.totp!, issuer: 'x', account: 'y')!;
    expect(otp.parameters.secret, secret);
    expect(otp.parameters.digits, 8);
    expect(export.logins[1].totp, isNull);
    final bank = otpFromImport(
      export.logins[2].totp!,
      issuer: '',
      account: '',
    )!;
    expect(bank.parameters.secret, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    expect(export.logins[2].username, 'ayse');
  });

  test('içe aktarmayla gidiş-dönüş: kart PIN dahil, çöptekiler yok', () {
    final imported = roundTrip().cards.single;
    expect(imported.adjusted, isFalse);
    final content = imported.content;
    final original = card.content;
    expect(content.name, original.name);
    expect(content.cardholder, original.cardholder);
    expect(content.number, original.number);
    expect(content.expiry, original.expiry);
    expect(content.securityCode, original.securityCode);
    expect(content.pin, '0042');
    expect(content.notes, original.notes);
    expect(content.folder, 'Banka');
    expect(content.favorite, isTrue);
    expect(build(), isNot(contains('Eski kart')));
  });

  test('içe aktarmayla gidiş-dönüş: not', () {
    final imported = roundTrip().notes.single;
    expect(imported.name, 'Ev Wi-Fi');
    expect(imported.text, 'ağ: Ev\nparola: kapi');
    expect(imported.folder, 'Ev');
  });

  test('boş kasa', () {
    final root = jsonDecode(
      BitwardenJsonExport.build(
        logins: const [],
        otps: const [],
        cards: const [],
        notes: const [],
      ),
    ) as Map<String, Object?>;
    expect(root['folders'], isEmpty);
    expect(root['items'], isEmpty);
  });
}

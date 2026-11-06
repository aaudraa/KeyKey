import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/authenticator/data/import/google_migration.dart';
import 'package:keykey/features/authenticator/data/import/import_result.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';

/// Testler için en küçük protobuf yazıcı.
final class _Proto {
  final _bytes = <int>[];

  void _varint(int value) {
    var rest = value;
    while (rest >= 0x80 || rest < 0) {
      _bytes.add((rest & 0x7f) | 0x80);
      rest >>>= 7;
    }
    _bytes.add(rest);
  }

  void number(int field, int value) {
    _varint(field << 3);
    _varint(value);
  }

  void bytes(int field, List<int> value) {
    _varint((field << 3) | 2);
    _varint(value.length);
    _bytes.addAll(value);
  }

  void text(int field, String value) => bytes(field, utf8.encode(value));

  List<int> get result => _bytes;
}

List<int> _account({
  List<int>? secret,
  String name = '',
  String issuer = '',
  int algorithm = 1,
  int digits = 1,
  int type = 2,
  int? counter,
}) {
  final proto = _Proto()
    ..bytes(1, secret ?? ascii.encode('12345678901234567890'))
    ..text(2, name)
    ..text(3, issuer)
    ..number(4, algorithm)
    ..number(5, digits)
    ..number(6, type);
  if (counter != null) proto.number(7, counter);
  return proto.result;
}

String _uri(List<List<int>> accounts, {bool urlSafe = false}) {
  final payload = _Proto();
  for (final account in accounts) {
    payload.bytes(1, account);
  }
  payload
    ..number(2, 1)
    ..number(3, 1)
    ..number(4, 0)
    ..number(5, 12345);
  final data = urlSafe
      ? base64Url.encode(payload.result).replaceAll('=', '')
      : Uri.encodeQueryComponent(base64.encode(payload.result));
  return 'otpauth-migration://offline?data=$data';
}

void main() {
  final rfcSecret = ascii.encode('12345678901234567890');

  test('hesaplar okunuyor', () {
    final batch = GoogleMigration.parse(
      _uri([
        _account(name: 'GitHub:ali@example.com', issuer: 'GitHub'),
        _account(
          name: 'veli',
          issuer: 'Banka',
          algorithm: 3,
          digits: 2,
          type: 1,
          counter: 42,
        ),
      ]),
    );

    expect(batch.unsupported, 0);
    expect(batch.accounts, hasLength(2));
    final github = batch.accounts[0];
    expect(github.issuer, 'GitHub');
    expect(github.account, 'ali@example.com');
    expect(github.parameters, OtpParameters.totp(secret: rfcSecret));
    final bank = batch.accounts[1];
    expect(bank.issuer, 'Banka');
    expect(bank.account, 'veli');
    expect(
      bank.parameters,
      OtpParameters.hotp(
        secret: rfcSecret,
        algorithm: OtpAlgorithm.sha512,
        digits: 8,
        counter: 42,
      ),
    );
  });

  test('servis alanı boşsa ad bölünüyor', () {
    final batch = GoogleMigration.parse(_uri([_account(name: 'Posta:ayşe')]));
    expect(batch.accounts.single.issuer, 'Posta');
    expect(batch.accounts.single.account, 'ayşe');
  });

  test('belirtilmemiş değerler varsayılana dönüyor', () {
    final batch = GoogleMigration.parse(
      _uri([_account(algorithm: 0, digits: 0, type: 0)]),
    );
    expect(
      batch.accounts.single.parameters,
      OtpParameters.totp(secret: rfcSecret),
    );
  });

  test('desteklenmeyen hesaplar sayılıyor', () {
    final batch = GoogleMigration.parse(
      _uri([
        _account(name: 'MD5', algorithm: 4),
        _account(name: '7 hane', digits: 3),
        _account(name: 'tür', type: 9),
        _account(name: 'anahtarsız', secret: const []),
        _account(name: 'iyi'),
      ]),
    );
    expect(batch.unsupported, 4);
    expect(batch.accounts.single.account, 'iyi');
  });

  test("URL'ye uygun ve dolgusuz Base64 kabul ediliyor", () {
    final batch = GoogleMigration.parse(
      _uri([_account(name: 'a')], urlSafe: true),
    );
    expect(batch.accounts.single.account, 'a');
  });

  test('bilinmeyen alanlar atlanıyor', () {
    final account = [
      ..._account(name: 'a'),
      ...(_Proto()..bytes(99, [1, 2, 3])).result,
      ...(_Proto()..number(98, 7)).result,
    ];
    expect(GoogleMigration.parse(_uri([account])).accounts.single.account, 'a');
  });

  group('reddedilenler', () {
    final cases = {
      'otpauth://totp/x?secret=JBSWY3DP': 'başka şema',
      'otpauth-migration://offline': 'data yok',
      'otpauth-migration://offline?data=': 'boş data',
      'otpauth-migration://offline?data=%ZZ': 'kodlama',
      'otpauth-migration://offline?data=!!!!': 'Base64',
      'otpauth-migration://offline?data=CgU&data=CgU': 'iki data',
      // Alan 1, uzunluk 100 ama veri yok.
      'otpauth-migration://offline?data=CmQ': 'yarım alan',
      // Alan türü 3 (grup) desteklenmiyor.
      'otpauth-migration://offline?data=Cw': 'grup',
    };
    for (final MapEntry(key: uri, value: reason) in cases.entries) {
      test(reason, () {
        expect(
          () => GoogleMigration.parse(uri),
          throwsA(isA<InvalidImportException>()),
        );
      });
    }

    test('çok uzun metin', () {
      expect(
        () => GoogleMigration.parse(
          'otpauth-migration://offline?data=${'A' * 20000}',
        ),
        throwsA(isA<InvalidImportException>()),
      );
    });
  });

  test('rastgele bozulmuş veri yalnızca kendi hatamızı fırlatıyor', () {
    final random = Random(13);
    final valid = _uri([
      _account(name: 'GitHub:ali', issuer: 'GitHub'),
      _account(name: 'b', type: 1, counter: 5),
    ]);
    final payload = base64.decode(
      Uri.decodeQueryComponent(valid.substring(valid.indexOf('=') + 1)),
    );
    for (var i = 0; i < 20000; i++) {
      final bytes = Uint8List.fromList(payload);
      for (var j = 0; j < 1 + random.nextInt(4); j++) {
        bytes[random.nextInt(bytes.length)] = random.nextInt(256);
      }
      final cut = random.nextInt(bytes.length + 1);
      final text =
          'otpauth-migration://offline?data='
          '${Uri.encodeQueryComponent(base64.encode(bytes.sublist(0, cut)))}';
      try {
        GoogleMigration.parse(text);
      } on InvalidImportException {
        // Beklenen tek hata türü.
      }
    }
  });
}

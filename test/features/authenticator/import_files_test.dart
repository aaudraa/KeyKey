// Örnek dışa aktarma dosyaları Aegis projesinin içe aktarma testlerinden
// alındı (GPL-3.0, KeyKey ile aynı lisans):
// https://github.com/beemdevelopment/Aegis/tree/master/app/src/test/resources/com/beemdevelopment/aegis/importers
// Şifreli olanların parolası "test". aes_gcm_vectors.json bu dosyalar Node'un
// (OpenSSL) kriptosuyla açılarak üretildi; böylece bizim scrypt ve PBKDF2
// kodumuz bağımsız bir uygulamayla karşılaştırılmış olur.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/authenticator/application/otp_import.dart';
import 'package:keykey/features/authenticator/data/base32.dart';
import 'package:keykey/features/authenticator/data/import/aegis_import.dart';
import 'package:keykey/features/authenticator/data/import/import_result.dart';
import 'package:keykey/features/authenticator/data/import/twofas_import.dart';
import 'package:keykey/features/authenticator/data/otp_parameters.dart';

import '../../support/vector_aes_gcm.dart';

Uint8List _secret(String base32) => Base32.decodeCanonical(base32);

void main() {
  final aes = VectorAesGcm();

  // Aegis ve 2FAS örneklerinde aynı hesaplar var.
  void expectSampleAccounts(
    ImportBatch batch, {
    required bool withTotpVariants,
  }) {
    final byIssuer = {
      for (final account in batch.accounts) account.issuer: account,
    };
    expect(byIssuer['Deno']!.account, 'Mason');
    expect(
      byIssuer['Deno']!.parameters,
      OtpParameters.totp(secret: _secret('4SJHB4GSD43FZBAI7C2HLRJGPQ')),
    );
    expect(
      byIssuer['Air Canada']!.parameters,
      OtpParameters.hotp(
        secret: _secret('KUVJJOM753IHTNDSZVCNKL7GII'),
        algorithm: OtpAlgorithm.sha256,
        digits: 7,
        counter: 50,
      ),
    );
    expect(
      byIssuer['WWE']!.parameters,
      OtpParameters.hotp(
        secret: _secret('5VAML3X35THCEBVRLV24CGBKOY'),
        algorithm: OtpAlgorithm.sha512,
        digits: 8,
        counter: 10300,
      ),
    );
    if (withTotpVariants) {
      expect(
        byIssuer['Airbnb']!.parameters,
        OtpParameters.totp(
          secret: _secret('7ELGJSGXNCCTV3O6LKJWYFV2RA'),
          algorithm: OtpAlgorithm.sha512,
          digits: 8,
          period: 50,
        ),
      );
    }
    // Steam desteklenmiyor.
    expect(byIssuer.containsKey('Boeing'), isFalse);
    expect(batch.unsupported, 1);
  }

  group('Aegis', () {
    test('şifresiz dosya', () {
      final file = AegisFile.parse(importFixture('aegis_plain.json'));
      expect(file.isEncrypted, isFalse);

      final batch = file.accounts();

      expect(batch.accounts, hasLength(6));
      expectSampleAccounts(batch, withTotpVariants: true);
    });

    test('şifreli dosya doğru parolayla açılıyor', () async {
      final file = AegisFile.parse(importFixture('aegis_encrypted.json'));
      expect(file.isEncrypted, isTrue);
      expect(file.accounts, throwsA(isA<InvalidImportException>()));

      final batch = await file.decrypt('test', aes);

      expect(batch.accounts, hasLength(6));
      expectSampleAccounts(batch, withTotpVariants: true);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('yanlış parola', () async {
      final file = AegisFile.parse(importFixture('aegis_encrypted.json'));
      await expectLater(
        file.decrypt('yanlis', aes),
        throwsA(isA<WrongImportPasswordException>()),
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('kötü niyetli scrypt parametreleri reddediliyor', () async {
      final root = jsonDecode(
        utf8.decode(importFixture('aegis_encrypted.json')),
      ) as Map<String, Object?>;
      final header = root['header']! as Map<String, Object?>;
      final slot =
          (header['slots']! as List<Object?>).first! as Map<String, Object?>;
      slot['n'] = 1 << 24;
      final file = AegisFile.parse(utf8.encode(jsonEncode(root)));

      await expectLater(
        file.decrypt('test', aes),
        throwsA(isA<InvalidImportException>()),
      );
    });
  });

  group('2FAS', () {
    test('şifresiz dosya', () {
      final file = TwoFasFile.parse(importFixture('2fas_plain_v4.2fas'));
      expect(file.isEncrypted, isFalse);

      final batch = file.accounts();

      expect(batch.accounts, hasLength(4));
      expectSampleAccounts(batch, withTotpVariants: false);
    });

    test('şifreli dosya, şema 4', () async {
      final file = TwoFasFile.parse(importFixture('2fas_encrypted_v4.2fas'));
      expect(file.isEncrypted, isTrue);

      final batch = await file.decrypt('test', aes);

      expect(batch.accounts, hasLength(4));
      expectSampleAccounts(batch, withTotpVariants: false);
    });

    test('şifreli dosya, eski şema', () async {
      final batch = await TwoFasFile.parse(
        importFixture('2fas_encrypted_v2.2fas'),
      ).decrypt('test', aes);

      expect(batch.accounts, isNotEmpty);
      expect(batch.accounts.map((account) => account.issuer), contains('Deno'));
    });

    test('yanlış parola', () async {
      await expectLater(
        TwoFasFile.parse(importFixture('2fas_encrypted_v4.2fas'))
            .decrypt('yanlis', aes),
        throwsA(isA<WrongImportPasswordException>()),
      );
    });
  });

  group('bozuk dosyalar', () {
    test('biçim tanınınca bozukluk ayrıca bildiriliyor', () {
      final aegis = utf8.encode('{"version": 1, "header": {}, "db": {}}');
      expect(
        () => ImportSource.fromFile(aegis, aes),
        throwsA(isA<InvalidImportException>()),
      );
      expect(
        () => ImportSource.fromFile(utf8.encode('{"x": 1}'), aes),
        throwsA(isA<UnknownImportFileException>()),
      );
      expect(
        ImportSource.fromFile(importFixture('aegis_plain.json'), aes),
        isA<ReadyImport>(),
      );
      expect(
        ImportSource.fromFile(importFixture('2fas_encrypted_v4.2fas'), aes),
        isA<EncryptedImport>(),
      );
    });

    test('başka biçimler birbirinin yerine okunmuyor', () {
      expect(
        () => AegisFile.parse(importFixture('2fas_plain_v4.2fas')),
        throwsA(isA<InvalidImportException>()),
      );
      expect(
        () => TwoFasFile.parse(importFixture('aegis_plain.json')),
        throwsA(isA<InvalidImportException>()),
      );
    });

    test('JSON olmayan ve çok büyük dosya', () {
      for (final bytes in [
        Uint8List.fromList([0xff, 0xfe, 0x00]),
        Uint8List.fromList(utf8.encode('[1, 2]')),
        Uint8List(10 * 1024 * 1024 + 1),
      ]) {
        expect(
          () => AegisFile.parse(bytes),
          throwsA(isA<InvalidImportException>()),
        );
        expect(
          () => TwoFasFile.parse(bytes),
          throwsA(isA<InvalidImportException>()),
        );
      }
    });

    test('rastgele bozulmuş dosyalar düşürmüyor', () async {
      final random = Random(17);
      Uint8List mutate(Uint8List source) {
        final bytes = Uint8List.fromList(source);
        for (var j = 0; j < 1 + random.nextInt(6); j++) {
          bytes[random.nextInt(bytes.length)] = 0x20 + random.nextInt(0x5f);
        }
        return bytes;
      }

      final aegis = importFixture('aegis_plain.json');
      final twofas = importFixture('2fas_plain_v4.2fas');
      for (var i = 0; i < 3000; i++) {
        try {
          if (i.isEven) {
            AegisFile.parse(mutate(aegis)).accounts();
          } else {
            TwoFasFile.parse(mutate(twofas)).accounts();
          }
        } on InvalidImportException {
          // Beklenen.
        }
      }

      // Şifreli dosyada her deneme 10 000 turluk PBKDF2 demek, az tur yeter.
      final encrypted = importFixture('2fas_encrypted_v4.2fas');
      for (var i = 0; i < 20; i++) {
        try {
          await TwoFasFile.parse(mutate(encrypted)).decrypt('test', aes);
        } on InvalidImportException {
          // Beklenen.
        } on WrongImportPasswordException {
          // Bozulan şifreli metin etiketi tutmaz.
        }
      }
    });
  });
}

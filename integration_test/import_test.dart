import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/features/authenticator/data/import/aegis_import.dart';
import 'package:keykey/features/authenticator/data/import/import_result.dart';
import 'package:keykey/features/authenticator/data/import/platform_aes_gcm.dart';
import 'package:keykey/features/authenticator/data/import/twofas_import.dart';

import 'import_fixtures.dart';

Uint8List _hex(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

/// Android'in AES-GCM'ini ve şifreli dışa aktarmaları gerçek cihazda sınar.
/// Vektörler Node'un (OpenSSL) kriptosuyla üretildi.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final aes = PlatformAesGcm();
  final vectors = [
    for (final value in jsonDecode(aesGcmVectors) as List<Object?>)
      value! as Map<String, Object?>,
  ];

  testWidgets('Android AES-GCM vektörleri çözüyor', (tester) async {
    for (final vector in vectors) {
      final plain = await aes.decrypt(
        key: _hex(vector['key']! as String),
        nonce: _hex(vector['nonce']! as String),
        cipherTextWithTag: base64.decode(
          vector['cipherTextWithTag']! as String,
        ),
      );
      expect(plain, base64.decode(vector['plainText']! as String));
    }
  });

  testWidgets('yanlış anahtar ve bozuk veri null veriyor', (tester) async {
    final vector = vectors.first;
    final key = _hex(vector['key']! as String);
    final nonce = _hex(vector['nonce']! as String);
    final cipherText = base64.decode(vector['cipherTextWithTag']! as String);

    final wrongKey = Uint8List.fromList(key)..[0] ^= 1;
    expect(
      await aes.decrypt(
        key: wrongKey,
        nonce: nonce,
        cipherTextWithTag: cipherText,
      ),
      isNull,
    );
    final tampered = Uint8List.fromList(cipherText)..[0] ^= 1;
    expect(
      await aes.decrypt(key: key, nonce: nonce, cipherTextWithTag: tampered),
      isNull,
    );
    expect(
      await aes.decrypt(
        key: key,
        nonce: nonce,
        cipherTextWithTag: Uint8List(8),
      ),
      isNull,
    );
    await expectLater(
      aes.decrypt(key: key, nonce: Uint8List(0), cipherTextWithTag: cipherText),
      throwsA(isA<InvalidImportException>()),
    );
  });

  testWidgets('şifreli Aegis dosyası cihazda açılıyor', (tester) async {
    final file = AegisFile.parse(utf8.encode(aegisEncrypted));
    final watch = Stopwatch()..start();

    final batch = await file.decrypt('test', aes);

    watch.stop();
    // Ölçüm için: scrypt N=2^15, r=8, p=1 bu cihazda ne kadar sürüyor.
    // ignore: avoid_print
    print('KKOLCUM aegis_scrypt_ms=${watch.elapsedMilliseconds}');
    expect(batch.accounts, hasLength(6));
    await expectLater(
      file.decrypt('yanlis', aes),
      throwsA(isA<WrongImportPasswordException>()),
    );
  });

  testWidgets('şifreli 2FAS dosyası cihazda açılıyor', (tester) async {
    final batch = await TwoFasFile.parse(utf8.encode(twoFasEncrypted))
        .decrypt('test', aes);

    expect(batch.accounts, hasLength(4));
  });
}

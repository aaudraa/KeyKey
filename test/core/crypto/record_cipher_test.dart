import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/crypto/crypto_exceptions.dart';
import 'package:keykey/core/crypto/record_cipher.dart';
import 'package:sodium/sodium_sumo.dart';

import 'hex.dart';
import 'vectors.dart';

void main() {
  late SodiumSumo sodium;
  late SecureKey vaultKey;
  late Uint8List vaultKeyBytes;
  late Uint8List vaultId;
  late Uint8List recordId;
  late RecordCipher cipher;

  final message = Uint8List.fromList(utf8.encode('{"parola":"gizli-ığüşöç"}'));

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    vaultKey = sodium.crypto.kdfHkdfSha256.keygen();
    vaultKeyBytes = vaultKey.extractBytes();
    vaultId = sodium.randombytes.buf(16);
    recordId = sodium.randombytes.buf(RecordCipher.recordIdLength);
    cipher = RecordCipher(sodium, vaultKey, vaultId);
  });

  tearDownAll(() {
    cipher.dispose();
    vaultKey.dispose();
  });

  Aead aead() => sodium.crypto.aeadXChaCha20Poly1305IETF;

  /// HKDF-Expand'in tek bloklu halini HMAC-SHA256 ile bağımsız hesaplar.
  Uint8List independentSubkey(String context) {
    final digest = hashes.Hmac(
      hashes.sha256,
      vaultKeyBytes,
    ).convert([...utf8.encode(context), 1]);
    return Uint8List.fromList(digest.bytes);
  }

  Uint8List field(List<int> content) => Uint8List.fromList([
    ...(ByteData(4)..setUint32(0, content.length)).buffer.asUint8List(),
    ...content,
  ]);

  /// Tasarım belgesindeki AD tanımını koddan bağımsız olarak kurar.
  Uint8List expectedAd(String type) => Uint8List.fromList([
    ...field(utf8.encode('keykey/v1/record')),
    ...field(vaultId),
    ...field(recordId),
    ...field(utf8.encode(type)),
  ]);

  Matcher throwsCorrupted() => throwsA(isA<CorruptedDataException>());

  Uint8List encrypt({String type = 'login', Uint8List? plain}) => cipher
      .encrypt(recordId: recordId, type: type, plainText: plain ?? message);

  Uint8List decrypt(Uint8List blob, {String type = 'login', Uint8List? id}) =>
      cipher.decrypt(recordId: id ?? recordId, type: type, blob: blob);

  group('bağımsız doğrulama', () {
    test('libsodium XChaCha20-Poly1305 test vektörü', () {
      final key = sodium.secureCopy(fromHex(xchachaKeyHex));
      addTearDown(key.dispose);

      final cipherText = aead().encrypt(
        message: Uint8List.fromList(utf8.encode(xchachaMessage)),
        nonce: fromHex(xchachaNonceHex),
        key: key,
        additionalData: fromHex(xchachaAdHex),
      );

      expect(cipherText, fromHex(xchachaCipherTextHex));
    });

    for (final (type, context) in [
      ('login', 'keykey/v1/records'),
      ('otp', 'keykey/v1/otp'),
    ]) {
      test('$type kaydı tasarımdaki biçimle bağımsız olarak açılıyor', () {
        final blob = encrypt(type: type);
        final key = sodium.secureCopy(independentSubkey(context));
        addTearDown(key.dispose);

        expect(blob[0], 1);
        final padded = aead().decrypt(
          cipherText: Uint8List.sublistView(blob, 25),
          nonce: Uint8List.sublistView(blob, 1, 25),
          key: key,
          additionalData: expectedAd(type),
        );

        expect(sodium.unpad(padded, 256), message);
      });
    }
  });

  group('şifreleme ve açma', () {
    test('türüne bakmadan aynen geri okunuyor', () {
      for (final type in ['login', 'note', RecordCipher.otpType]) {
        expect(decrypt(encrypt(type: type), type: type), message);
      }
    });

    test('boş ve blok sınırındaki içerikler aynen geri okunuyor', () {
      for (final length in [0, 1, 255, 256, 257, 1024]) {
        final plain = Uint8List(length);
        expect(decrypt(encrypt(plain: plain)), plain);
      }
    });

    test('aynı içerik her seferinde farklı şifreleniyor', () {
      final first = encrypt();
      final second = encrypt();

      expect(first, isNot(second));
      expect(first.sublist(1, 25), isNot(second.sublist(1, 25)));
    });

    test('düz metin şifreli veride görünmüyor', () {
      final text = latin1.decode(encrypt());
      expect(text, isNot(contains('parola')));
    });
  });

  group('kayıt ve 2FA anahtarları ayrı', () {
    test('kayıt türünde şifrelenen 2FA olarak açılmıyor', () {
      expect(
        () => decrypt(encrypt(), type: RecordCipher.otpType),
        throwsCorrupted(),
      );
      expect(
        () => decrypt(encrypt(type: RecordCipher.otpType)),
        throwsCorrupted(),
      );
    });
  });

  group('uzunluk gizleniyor', () {
    test('aynı bloğa düşen içeriklerin uzunluğu aynı', () {
      final lengths = {
        for (final size in [0, 1, 8, 64, 255])
          encrypt(plain: Uint8List(size)).length,
      };

      expect(lengths, hasLength(1));
    });

    test('blok uzunluğu tasarımla aynı', () {
      expect(encrypt(plain: Uint8List(0)).length, 1 + 24 + 256 + 16);
      expect(encrypt(plain: Uint8List(256)).length, 1 + 24 + 512 + 16);
    });
  });

  group('değiştirilmiş veri açılmıyor', () {
    test('her baytta tek bit değişimi reddediliyor', () {
      final blob = encrypt();
      for (var i = 0; i < blob.length; i++) {
        final tampered = Uint8List.fromList(blob)..[i] ^= 1;
        expect(() => decrypt(tampered), throwsCorrupted(), reason: 'bayt $i');
      }
    });

    test('kısaltılmış veri reddediliyor', () {
      final blob = encrypt();
      for (final length in [0, 1, 24, 25, 40, 41, blob.length - 1]) {
        expect(() => decrypt(blob.sublist(0, length)), throwsCorrupted());
      }
    });

    test('sona bayt eklenmiş veri reddediliyor', () {
      expect(
        () => decrypt(Uint8List.fromList([...encrypt(), 0])),
        throwsCorrupted(),
      );
    });
  });

  group('başka bağlamda açılmıyor', () {
    test('başka kayıt kimliği', () {
      expect(
        () => decrypt(encrypt(), id: sodium.randombytes.buf(16)),
        throwsCorrupted(),
      );
    });

    test('başka tür', () {
      expect(() => decrypt(encrypt(), type: 'note'), throwsCorrupted());
    });

    test('aynı anahtarla başka kasa kimliği', () {
      final other = RecordCipher(sodium, vaultKey, sodium.randombytes.buf(16));
      addTearDown(other.dispose);

      expect(
        () => other.decrypt(recordId: recordId, type: 'login', blob: encrypt()),
        throwsCorrupted(),
      );
    });

    test('başka kasa anahtarı', () {
      final otherKey = sodium.crypto.kdfHkdfSha256.keygen();
      addTearDown(otherKey.dispose);
      final other = RecordCipher(sodium, otherKey, vaultId);
      addTearDown(other.dispose);

      expect(
        () => other.decrypt(recordId: recordId, type: 'login', blob: encrypt()),
        throwsCorrupted(),
      );
    });
  });

  group('hatalı kullanım', () {
    test('yanlış uzunlukta kayıt kimliği reddediliyor', () {
      expect(
        () => cipher.encrypt(
          recordId: Uint8List(15),
          type: 'login',
          plainText: message,
        ),
        throwsArgumentError,
      );
    });

    test('boş tür reddediliyor', () {
      expect(() => encrypt(type: ''), throwsArgumentError);
    });
  });
}

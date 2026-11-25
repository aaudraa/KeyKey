import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/passkey/domain/webauthn.dart';
import 'package:keykey/features/vault/data/login_passkey.dart';
import 'package:pointycastle/export.dart';

import 'cbor_test.dart' show hex;

String fixture(String name) =>
    File('test/features/passkey/fixtures/$name').readAsStringSync();

BigInt _int(List<int> bytes) =>
    bytes.fold(BigInt.zero, (value, b) => (value << 8) | BigInt.from(b));

Uint8List _bytes(BigInt value, [int length = 32]) {
  final out = Uint8List(length);
  var rest = value;
  for (var i = length - 1; i >= 0; i--) {
    out[i] = (rest & BigInt.from(0xff)).toInt();
    rest >>= 8;
  }
  return out;
}

/// DER `SEQUENCE { INTEGER r, INTEGER s }`.
Uint8List _der(BigInt r, BigInt s) {
  List<int> integer(BigInt v) {
    var bytes = _bytes(v).toList();
    while (bytes.length > 1 && bytes[0] == 0 && bytes[1] < 0x80) {
      bytes = bytes.sublist(1);
    }
    if (bytes[0] >= 0x80) bytes = [0, ...bytes];
    return [0x02, bytes.length, ...bytes];
  }

  final body = [...integer(r), ...integer(s)];
  return Uint8List.fromList([0x30, body.length, ...body]);
}

(BigInt, BigInt) _parseDer(Uint8List der) {
  var i = 2;
  BigInt next() {
    expect(der[i], 0x02);
    final length = der[i + 1];
    final value = _int(der.sublist(i + 2, i + 2 + length));
    i += 2 + length;
    return value;
  }

  return (next(), next());
}

/// Testlerin P-256 anahtarı; `privateKey` burada yalnızca `d` sayısıdır,
/// çünkü imza sahte imzacıyla atılır.
_TestKey _generateKey() {
  final random = FortunaRandom()
    ..seed(KeyParameter(Uint8List.fromList(List.generate(32, (i) => i))));
  final generator = ECKeyGenerator()
    ..init(
      ParametersWithRandom(
        ECKeyGeneratorParameters(ECCurve_secp256r1()),
        random,
      ),
    );
  final pair = generator.generateKeyPair();
  return _TestKey(pair.privateKey, pair.publicKey);
}

final class _TestKey {
  const new(this.private, this.public);

  final ECPrivateKey private;
  final ECPublicKey public;

  Uint8List get d => _bytes(private.d!);
  Uint8List get x => _bytes(public.Q!.x!.toBigInteger()!);
  Uint8List get y => _bytes(public.Q!.y!.toBigInteger()!);

  Future<Uint8List> sign(Uint8List key, Uint8List data) async {
    final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
      ..init(
        true,
        PrivateKeyParameter<ECPrivateKey>(
          ECPrivateKey(_int(key), ECCurve_secp256r1()),
        ),
      );
    final signature = signer.generateSignature(data) as ECSignature;
    return _der(signature.r, signature.s);
  }

  bool verify(Uint8List data, Uint8List der) {
    final (r, s) = _parseDer(der);
    final verifier = ECDSASigner(SHA256Digest())
      ..init(false, PublicKeyParameter<ECPublicKey>(public));
    return verifier.verifySignature(data, ECSignature(r, s));
  }
}

Map<String, Object?> _decode(String json) =>
    jsonDecode(json) as Map<String, Object?>;

Uint8List _b64(Object? text) => base64UrlDecodeNoPad(text! as String);

void main() {
  final key = _generateKey();
  final credentialId = Uint8List.fromList(List.generate(16, (i) => i + 1));

  group('istek', () {
    test('webauthn.io oluşturma isteği okunuyor', () {
      final options = CreationOptions.parse(fixture('webauthn_io_create.json'));
      expect(options.rpId, 'webauthn.io');
      expect(options.rpName, 'webauthn.io');
      expect(options.userName, 'furkan');
      expect(utf8.decode(options.userId), 'ZnVya2Fu');
      expect(options.algorithms, [-8, -7, -257]);
      expect(options.excludeCredentialIds, isEmpty);
      expect(options.challenge, hasLength(64));
    });

    test('GitHub isteğinde dışlanan kimlik', () {
      final options = CreationOptions.parse(fixture('github_create.json'));
      expect(options.rpId, 'github.com');
      expect(options.excludeCredentialIds.single, credentialId);
    });

    test('rp.id yoksa null; origin ile çözülür', () {
      final json = _decode(fixture('github_create.json'));
      (json['rp']! as Map).remove('id');
      expect(CreationOptions.parse(jsonEncode(json)).rpId, isNull);
    });

    test('ES256 yoksa desteklenmiyor', () {
      final json = _decode(fixture('github_create.json'))
        ..['pubKeyCredParams'] = [
          {'type': 'public-key', 'alg': -257},
        ];
      expect(
        () => CreationOptions.parse(jsonEncode(json)),
        throwsA(
          isA<PasskeyRequestException>().having(
            (e) => e.kind,
            'kind',
            PasskeyError.unsupportedAlgorithm,
          ),
        ),
      );
    });

    test('bozuk istek geçersiz', () {
      Matcher invalid() => throwsA(
        isA<PasskeyRequestException>().having(
          (e) => e.kind,
          'kind',
          PasskeyError.invalidRequest,
        ),
      );
      expect(() => CreationOptions.parse('{bozuk'), invalid());
      final noChallenge = _decode(fixture('github_create.json'))
        ..remove('challenge');
      expect(() => CreationOptions.parse(jsonEncode(noChallenge)), invalid());
      final badUser = _decode(fixture('github_create.json'))
        ..['user'] = {'id': 'A' * 100, 'name': 'x', 'displayName': 'x'};
      expect(() => CreationOptions.parse(jsonEncode(badUser)), invalid());
      expect(() => RequestOptions.parse('[]'), invalid());
    });

    test('16 bayttan kısa meydan okuma kabul, boşu reddediliyor', () {
      final short = _decode(fixture('webauthn_io_get.json'))
        ..['challenge'] = base64UrlNoPad(Uint8List(8));
      expect(RequestOptions.parse(jsonEncode(short)).challenge, hasLength(8));
      final empty = _decode(fixture('webauthn_io_get.json'))
        ..['challenge'] = '';
      expect(
        () => RequestOptions.parse(jsonEncode(empty)),
        throwsA(isA<PasskeyRequestException>()),
      );
    });

    test('giriş isteği okunuyor', () {
      final options = RequestOptions.parse(fixture('webauthn_io_get.json'));
      expect(options.rpId, 'webauthn.io');
      expect(options.allowCredentialIds, isEmpty);
      expect(options.challenge, isNotEmpty);
    });
  });

  group('authenticatorData', () {
    test('oluşturma: AT dahil bayraklar ve COSE anahtarı', () {
      final data = authenticatorData(
        rpId: 'github.com',
        credentialId: credentialId,
        publicX: key.x,
        publicY: key.y,
      );
      expect(
        data.sublist(0, 32),
        sha256.convert(utf8.encode('github.com')).bytes,
      );
      expect(data[32], 0x5D);
      expect(data.sublist(33, 37), [0, 0, 0, 0]);
      expect(hex(data.sublist(37, 53)), hex(keyKeyAaguid));
      expect(data.sublist(53, 55), [0, 16]);
      expect(data.sublist(55, 71), credentialId);
      expect(hex(data.sublist(71, 81)), 'a5010203262001215820');
      expect(data, hasLength(148));
    });

    test('giriş: 37 bayt, AT yok', () {
      final data = authenticatorData(rpId: 'github.com');
      expect(data, hasLength(37));
      expect(data[32], 0x1D);
    });
  });

  test('clientDataJSON alan sırası', () {
    expect(
      buildClientDataJson(
        type: 'webauthn.get',
        challenge: Uint8List.fromList([1, 2, 3]),
        origin: 'https://github.com',
      ),
      '{"type":"webauthn.get","challenge":"AQID",'
      '"origin":"https://github.com","crossOrigin":false}',
    );
  });

  group('yanıt', () {
    test('oluşturma yanıtı', () {
      final options = CreationOptions.parse(fixture('github_create.json'));
      final json = _decode(
        registrationResponse(
          options: options,
          rpId: 'github.com',
          credentialId: credentialId,
          publicX: key.x,
          publicY: key.y,
          origin: 'https://github.com',
        ),
      );
      expect(json['id'], 'AQIDBAUGBwgJCgsMDQ4PEA');
      expect(json['rawId'], json['id']);
      expect(json['type'], 'public-key');
      expect(json['authenticatorAttachment'], 'platform');
      expect(json['clientExtensionResults'], {
        'credProps': {'rk': true},
      });
      final response = json['response']! as Map<String, Object?>;
      final client = _decode(utf8.decode(_b64(response['clientDataJSON'])));
      expect(client['type'], 'webauthn.create');
      expect(client['challenge'], '7pE5x1Kq9t8m2HJ3nJdZ6bQ1f0Vw4XgL');
      expect(client['origin'], 'https://github.com');
      final attestation = _b64(response['attestationObject']);
      expect(hex(attestation.sublist(0, 10)), 'a363666d74646e6f6e65');
      expect(response['publicKeyAlgorithm'], -7);
      expect(response['transports'], ['internal', 'hybrid']);
      final spki = _b64(response['publicKey']);
      expect(spki, hasLength(91));
      expect(spki.sublist(26), [4, ...key.x, ...key.y]);
      expect(_b64(response['authenticatorData']), hasLength(148));
    });

    LoginPasskey passkey({String user = 'furkan'}) => LoginPasskey(
      credentialId: credentialId,
      rpId: 'webauthn.io',
      userHandle: utf8.encode(user),
      userName: 'furkan',
      userDisplayName: 'Furkan',
      privateKey: key.d,
      createdAt: DateTime.utc(2026),
    );

    test('giriş yanıtının imzası açık anahtarla doğrulanıyor', () async {
      final options = RequestOptions.parse(fixture('webauthn_io_get.json'));
      final json = _decode(
        await assertionResponse(
          options: options,
          rpId: 'webauthn.io',
          passkey: passkey(),
          origin: 'https://webauthn.io',
          sign: key.sign,
        ),
      );
      final response = json['response']! as Map<String, Object?>;
      final clientData = _b64(response['clientDataJSON']);
      final authData = _b64(response['authenticatorData']);
      expect(authData[32], 0x1D);
      expect(utf8.decode(_b64(response['userHandle'])), 'furkan');
      final signed = Uint8List.fromList([
        ...authData,
        ...sha256.convert(clientData).bytes,
      ]);
      expect(key.verify(signed, _b64(response['signature'])), isTrue);
    });

    test('kullanıcı kimliği boşsa yanıtta userHandle yok', () async {
      final json = _decode(
        await assertionResponse(
          options: RequestOptions.parse(fixture('webauthn_io_get.json')),
          rpId: 'webauthn.io',
          passkey: passkey(user: ''),
          origin: 'https://webauthn.io',
          sign: key.sign,
        ),
      );
      final response = json['response']! as Map<String, Object?>;
      expect(response.containsKey('userHandle'), isFalse);
    });

    test('tarayıcının verdiği clientDataHash imzalanıyor', () async {
      final hash = Uint8List.fromList(List.filled(32, 7));
      final json = _decode(
        await assertionResponse(
          options: RequestOptions.parse(fixture('webauthn_io_get.json')),
          rpId: 'webauthn.io',
          passkey: passkey(),
          origin: 'https://webauthn.io',
          clientDataHash: hash,
          sign: key.sign,
        ),
      );
      final response = json['response']! as Map<String, Object?>;
      final signed = Uint8List.fromList([
        ..._b64(response['authenticatorData']),
        ...hash,
      ]);
      expect(key.verify(signed, _b64(response['signature'])), isTrue);
    });
  });

  test('rastgele kimlik 16 bayt', () {
    final id = newCredentialId(Random(1));
    expect(id, hasLength(16));
  });
}

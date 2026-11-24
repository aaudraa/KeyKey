import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:keykey/features/passkey/domain/cbor.dart';
import 'package:keykey/features/vault/data/login_passkey.dart';

/// Passkey isteğinin reddedilme nedeni; Credential Manager'a uygun hata
/// türüyle döner.
enum PasskeyError {
  /// İstek okunamadı ya da bir alanı geçersiz.
  invalidRequest,

  /// İstek ES256'yı (-7) kabul etmiyor.
  unsupportedAlgorithm,

  /// `excludeCredentials` kasadaki bir passkey'i içeriyor.
  alreadyExists,

  /// `rpId` origin'e ya da kurala uymuyor.
  rpIdMismatch,

  /// Kayıtta passkey sınırı doldu.
  tooMany,
}

final class PasskeyRequestException implements Exception {
  const new(this.kind);

  final PasskeyError kind;

  @override
  String toString() => 'PasskeyRequestException($kind)';
}

/// KeyKey'in AAGUID'i: `b3c1e1d0-6b2a-4f3e-9c7a-4b6579b4b579`.
final Uint8List keyKeyAaguid = Uint8List.fromList([
  0xb3, 0xc1, 0xe1, 0xd0, 0x6b, 0x2a, 0x4f, 0x3e, //
  0x9c, 0x7a, 0x4b, 0x65, 0x79, 0xb4, 0xb5, 0x79,
]);

/// ES256: ECDSA, P-256, SHA-256.
const es256 = -7;

/// Passkey özel anahtarıyla imza; Android'de `PasskeyCryptoApi.sign`.
typedef PasskeySigner = Future<Uint8List> Function(
  Uint8List privateKey,
  Uint8List data,
);

/// `PublicKeyCredentialCreationOptionsJSON`.
final class CreationOptions {
  const new({
    required this.rpId,
    required this.rpName,
    required this.userId,
    required this.userName,
    required this.userDisplayName,
    required this.challenge,
    required this.algorithms,
    required this.excludeCredentialIds,
  });

  /// Geçersiz istek ve ES256'sız istek [PasskeyRequestException].
  factory parse(String json) {
    final root = _root(json);
    final rp = _map(root['rp']);
    final user = _map(root['user']);
    final userId = _bytes(user['id']);
    if (userId.isEmpty || userId.length > LoginPasskey.maxUserHandleBytes) {
      throw const PasskeyRequestException(PasskeyError.invalidRequest);
    }
    final algorithms = [
      for (final param in _list(root['pubKeyCredParams']))
        if (_map(param) case {'type': 'public-key', 'alg': final int alg}) alg,
    ];
    if (!algorithms.contains(es256)) {
      throw const PasskeyRequestException(PasskeyError.unsupportedAlgorithm);
    }
    return CreationOptions(
      rpId: _optionalString(rp['id']),
      rpName: _optionalString(rp['name']) ?? '',
      userId: userId,
      userName: _string(user['name']),
      userDisplayName: _optionalString(user['displayName']) ?? '',
      challenge: _challenge(root['challenge']),
      algorithms: algorithms,
      excludeCredentialIds: _credentialIds(root['excludeCredentials']),
    );
  }

  /// `null` ise origin'in ana bilgisayarı kullanılır (WebAuthn kuralı).
  final String? rpId;
  final String rpName;
  final Uint8List userId;
  final String userName;
  final String userDisplayName;
  final Uint8List challenge;
  final List<int> algorithms;
  final List<Uint8List> excludeCredentialIds;
}

/// `PublicKeyCredentialRequestOptionsJSON`.
final class RequestOptions {
  const new({
    required this.rpId,
    required this.challenge,
    required this.allowCredentialIds,
  });

  factory parse(String json) {
    final root = _root(json);
    return RequestOptions(
      rpId: _optionalString(root['rpId']),
      challenge: _challenge(root['challenge']),
      allowCredentialIds: _credentialIds(root['allowCredentials']),
    );
  }

  final String? rpId;
  final Uint8List challenge;

  /// Boşsa site herhangi bir passkey'ini kabul eder (keşfedilebilir giriş).
  final List<Uint8List> allowCredentialIds;
}

/// 16 rastgele bayt.
Uint8List newCredentialId([Random? random]) {
  final source = random ?? Random.secure();
  return Uint8List.fromList(List.generate(16, (_) => source.nextInt(256)));
}

/// `authenticatorData`. [credentialId] verilirse oluşturmadır: `AT` bayrağı,
/// AAGUID, kimlik ve COSE anahtarı eklenir.
///
/// Bayraklar: UP (kullanıcı orada), UV (kasa ana parola ya da parmak iziyle
/// açıldı), BE ve BS (passkey kasayla yedeklenir ve taşınır). Sayaç 0.
Uint8List authenticatorData({
  required String rpId,
  Uint8List? credentialId,
  Uint8List? publicX,
  Uint8List? publicY,
}) {
  const up = 0x01;
  const uv = 0x04;
  const be = 0x08;
  const bs = 0x10;
  const at = 0x40;
  final attested = credentialId != null;
  final out = BytesBuilder(copy: false)
    ..add(sha256.convert(ascii.encode(rpId)).bytes)
    ..addByte(up | uv | be | bs | (attested ? at : 0))
    ..add(const [0, 0, 0, 0]);
  if (attested) {
    out
      ..add(keyKeyAaguid)
      ..add([credentialId.length >> 8, credentialId.length & 0xff])
      ..add(credentialId)
      ..add(coseKey(publicX!, publicY!));
  }
  return out.takeBytes();
}

/// P-256 açık anahtarının COSE biçimi: `{1:2, 3:-7, -1:1, -2:x, -3:y}`.
Uint8List coseKey(Uint8List x, Uint8List y) =>
    cborEncode({1: 2, 3: es256, -1: 1, -2: x, -3: y});

/// `collectedClientData`; alan sırası WebAuthn'ın JSON sıralamasıdır.
String buildClientDataJson({
  required String type,
  required Uint8List challenge,
  required String origin,
}) => jsonEncode({
  'type': type,
  'challenge': base64UrlNoPad(challenge),
  'origin': origin,
  'crossOrigin': false,
});

/// `RegistrationResponseJSON`. Onay `none`.
String registrationResponse({
  required CreationOptions options,
  required String rpId,
  required Uint8List credentialId,
  required Uint8List publicX,
  required Uint8List publicY,
  required String origin,
}) {
  final clientData = utf8.encode(
    buildClientDataJson(
      type: 'webauthn.create',
      challenge: options.challenge,
      origin: origin,
    ),
  );
  final authData = authenticatorData(
    rpId: rpId,
    credentialId: credentialId,
    publicX: publicX,
    publicY: publicY,
  );
  final attestation = cborEncode({
    'fmt': 'none',
    'attStmt': <String, Object?>{},
    'authData': authData,
  });
  final id = base64UrlNoPad(credentialId);
  return jsonEncode({
    'id': id,
    'rawId': id,
    'type': 'public-key',
    'authenticatorAttachment': 'platform',
    'response': {
      'clientDataJSON': base64UrlNoPad(clientData),
      'attestationObject': base64UrlNoPad(attestation),
      'authenticatorData': base64UrlNoPad(authData),
      'transports': const ['internal', 'hybrid'],
      'publicKey': base64UrlNoPad(_spki(publicX, publicY)),
      'publicKeyAlgorithm': es256,
    },
    'clientExtensionResults': {
      'credProps': {'rk': true},
    },
  });
}

/// `AuthenticationResponseJSON`. Tarayıcı [clientDataHash] verdiyse imza
/// onunla atılır; yanıttaki clientDataJSON'u tarayıcı kendisininkiyle
/// değiştirir.
Future<String> assertionResponse({
  required RequestOptions options,
  required String rpId,
  required LoginPasskey passkey,
  required String origin,
  required PasskeySigner sign,
  Uint8List? clientDataHash,
}) async {
  final clientData = utf8.encode(
    buildClientDataJson(
      type: 'webauthn.get',
      challenge: options.challenge,
      origin: origin,
    ),
  );
  final authData = authenticatorData(rpId: rpId);
  final hash = clientDataHash ?? sha256.convert(clientData).bytes;
  final signature = await sign(
    passkey.privateKey,
    Uint8List.fromList([...authData, ...hash]),
  );
  final id = passkey.credentialIdB64;
  return jsonEncode({
    'id': id,
    'rawId': id,
    'type': 'public-key',
    'authenticatorAttachment': 'platform',
    'response': {
      'clientDataJSON': base64UrlNoPad(clientData),
      'authenticatorData': base64UrlNoPad(authData),
      'signature': base64UrlNoPad(signature),
      'userHandle': base64UrlNoPad(passkey.userHandle),
    },
    'clientExtensionResults': <String, Object?>{},
  });
}

/// P-256 `SubjectPublicKeyInfo` (DER): sabit başlık ve sıkıştırılmamış
/// nokta.
Uint8List _spki(Uint8List x, Uint8List y) => Uint8List.fromList([
  0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, //
  0x02, 0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01,
  0x07, 0x03, 0x42, 0x00, 0x04, ...x, ...y,
]);

Map<String, Object?> _root(String json) {
  try {
    return _map(jsonDecode(json));
  } on FormatException {
    throw const PasskeyRequestException(PasskeyError.invalidRequest);
  }
}

Map<String, Object?> _map(Object? value) => value is Map<String, Object?>
    ? value
    : throw const PasskeyRequestException(PasskeyError.invalidRequest);

List<Object?> _list(Object? value) => value is List<Object?>
    ? value
    : throw const PasskeyRequestException(PasskeyError.invalidRequest);

String _string(Object? value) => value is String
    ? value
    : throw const PasskeyRequestException(PasskeyError.invalidRequest);

String? _optionalString(Object? value) => value == null ? null : _string(value);

Uint8List _bytes(Object? value) {
  try {
    return base64UrlDecodeNoPad(_string(value));
  } on FormatException {
    throw const PasskeyRequestException(PasskeyError.invalidRequest);
  }
}

/// WebAuthn en az 16 bayt ister; çok uzun meydan okuma da reddedilir.
Uint8List _challenge(Object? value) {
  final bytes = _bytes(value);
  if (bytes.length < 16 || bytes.length > 1024) {
    throw const PasskeyRequestException(PasskeyError.invalidRequest);
  }
  return bytes;
}

List<Uint8List> _credentialIds(Object? value) {
  if (value == null) return const [];
  return [
    for (final item in _list(value))
      if (_map(item) case {'type': 'public-key', 'id': final Object? id})
        _bytes(id),
  ];
}

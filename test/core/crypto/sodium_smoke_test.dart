import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';

// Kripto katmanı Faz 2'de yazılacak. Şimdilik yalnızca libsodium'un derlenip
// yüklendiğini ve temel işlemlerin çalıştığını doğruluyor.
void main() {
  test('libsodium yükleniyor ve şifre çözme bağlamı doğruluyor', () async {
    final sodium = await SodiumSumoInit.init();
    final aead = sodium.crypto.aeadXChaCha20Poly1305IETF;
    final key = aead.keygen();
    addTearDown(key.dispose);

    final nonce = sodium.randombytes.buf(aead.nonceBytes);
    final message = Uint8List.fromList(utf8.encode('deneme'));
    final context = Uint8List.fromList(utf8.encode('bağlam-1'));
    final cipherText = aead.encrypt(
      message: message,
      nonce: nonce,
      key: key,
      additionalData: context,
    );

    expect(
      aead.decrypt(
        cipherText: cipherText,
        nonce: nonce,
        key: key,
        additionalData: context,
      ),
      message,
    );
    expect(
      () => aead.decrypt(
        cipherText: cipherText,
        nonce: nonce,
        key: key,
        additionalData: Uint8List.fromList(utf8.encode('bağlam-2')),
      ),
      throwsA(isA<SodiumException>()),
    );
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:keykey/features/authenticator/data/import/aes_gcm.dart';

import '../core/crypto/hex.dart';

/// test/fixtures/import altındaki örnek dosya.
Uint8List importFixture(String name) =>
    File('test/fixtures/import/$name').readAsBytesSync();

/// Yalnızca Node'un ürettiği vektörlerle birebir eşleşen girdiyi çözer.
/// Anahtar yanlışsa, gerçek AES-GCM gibi `null` döner.
final class VectorAesGcm implements AesGcmDecrypter {
  new() {
    final list = jsonDecode(
      utf8.decode(importFixture('aes_gcm_vectors.json')),
    ) as List<Object?>;
    for (final value in list) {
      final map = value! as Map<String, Object?>;
      _vectors.add((
        key: fromHex(map['key']! as String),
        nonce: fromHex(map['nonce']! as String),
        cipherText: base64.decode(map['cipherTextWithTag']! as String),
        plainText: base64.decode(map['plainText']! as String),
      ));
    }
  }

  final _vectors =
      <
        ({
          Uint8List key,
          Uint8List nonce,
          Uint8List cipherText,
          Uint8List plainText,
        })
      >[];

  @override
  Future<Uint8List?> decrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List cipherTextWithTag,
  }) async {
    for (final vector in _vectors) {
      if (listEquals(vector.key, key) &&
          listEquals(vector.nonce, nonce) &&
          listEquals(vector.cipherText, cipherTextWithTag)) {
        return Uint8List.fromList(vector.plainText);
      }
    }
    return null;
  }
}

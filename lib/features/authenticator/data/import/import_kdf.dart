import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Şifreli dışa aktarma dosyalarını açmak için anahtar türetme.
///
/// Aegis scrypt, 2FAS PBKDF2-HMAC-SHA256 kullanıyor. libsodium'un scrypt'i
/// `sodium` paketinde yok, PBKDF2 ise libsodium'da hiç yok. Bu yüzden ikisi
/// de RFC 7914'teki test vektörleriyle doğrulanan kendi kodumuz. Yalnızca
/// kullanıcının verdiği dosyayı açmak için çalışır, kasanın şifrelemesinde
/// kullanılmaz.
abstract final class ImportKdf {
  /// Bozuk veya kötü niyetli bir dosya cihazı belleksiz bırakmasın diye
  /// scrypt parametrelerinin üst sınırları. Aegis'in varsayılanı N=2^15, r=8,
  /// p=1, yani 32 MiB.
  static const int maxScryptMemory = 128 * 1024 * 1024;
  static const maxScryptP = 16;
  static const maxPbkdf2Iterations = 10000000;

  /// Parametreler [scrypt]'in kabul edeceği gibi mi.
  static bool isValidScrypt({required int n, required int r, required int p}) =>
      n >= 2 &&
      n & (n - 1) == 0 &&
      r >= 1 &&
      p >= 1 &&
      p <= maxScryptP &&
      128 * r <= maxScryptMemory ~/ n;

  /// PBKDF2-HMAC-SHA256 (RFC 8018).
  static Uint8List pbkdf2Sha256({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int length,
  }) {
    if (iterations < 1 || iterations > maxPbkdf2Iterations) {
      throw ArgumentError.value(iterations, 'iterations');
    }
    if (length < 1) throw ArgumentError.value(length, 'length');
    final hmac = Hmac(sha256, password);
    final out = Uint8List(length);
    final block = Uint8List(salt.length + 4)..setAll(0, salt);
    for (var index = 1, offset = 0; offset < length; index++, offset += 32) {
      ByteData.sublistView(block).setUint32(salt.length, index);
      var u = Uint8List.fromList(hmac.convert(block).bytes);
      final t = Uint8List.fromList(u);
      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      final take = length - offset < 32 ? length - offset : 32;
      out.setRange(offset, offset + take, t);
    }
    return out;
  }

  /// scrypt (RFC 7914). [n] 2'nin kuvveti olmalıdır.
  static Uint8List scrypt({
    required List<int> password,
    required List<int> salt,
    required int n,
    required int r,
    required int p,
    required int length,
  }) {
    if (n < 2 || n & (n - 1) != 0) throw ArgumentError.value(n, 'n');
    if (r < 1 || p < 1 || p > maxScryptP) {
      throw ArgumentError.value('$r, $p', 'r, p');
    }
    if (128 * r > maxScryptMemory ~/ n) {
      throw ArgumentError.value(n, 'n', 'Çok fazla bellek');
    }
    final blockWords = 32 * r;
    final b = pbkdf2Sha256(
      password: password,
      salt: salt,
      iterations: 1,
      length: p * 128 * r,
    );
    final words = _toWords(b);
    final v = Uint32List(n * blockWords);
    final x = Uint32List(blockWords);
    final scratch = Uint32List(blockWords);
    for (var i = 0; i < p; i++) {
      x.setRange(0, blockWords, words, i * blockWords);
      _roMix(x, v, scratch, n, r);
      words.setRange(i * blockWords, (i + 1) * blockWords, x);
    }
    return pbkdf2Sha256(
      password: password,
      salt: _toBytes(words),
      iterations: 1,
      length: length,
    );
  }

  static void _roMix(
    Uint32List x,
    Uint32List v,
    Uint32List scratch,
    int n,
    int r,
  ) {
    final blockWords = x.length;
    for (var i = 0; i < n; i++) {
      v.setRange(i * blockWords, (i + 1) * blockWords, x);
      _blockMix(x, scratch, r);
    }
    for (var i = 0; i < n; i++) {
      // Integerify: son 64 baytlık bloğun ilk sözcüğü. N 2^32'den küçük.
      final j = x[(2 * r - 1) * 16] & (n - 1);
      final offset = j * blockWords;
      for (var k = 0; k < blockWords; k++) {
        x[k] ^= v[offset + k];
      }
      _blockMix(x, scratch, r);
    }
  }

  /// scryptBlockMix. [b] yerinde değişir, [y] geçici alandır.
  static void _blockMix(Uint32List b, Uint32List y, int r) {
    final x = Uint32List(16)..setRange(0, 16, b, (2 * r - 1) * 16);
    for (var i = 0; i < 2 * r; i++) {
      for (var k = 0; k < 16; k++) {
        x[k] ^= b[i * 16 + k];
      }
      salsa20_8(x);
      // Çift sıralı bloklar başa, tek sıralılar sona.
      final target = (i.isEven ? i ~/ 2 : r + i ~/ 2) * 16;
      y.setRange(target, target + 16, x);
    }
    b.setAll(0, y);
  }

  /// Salsa20/8 çekirdeği, 16 sözcük üzerinde yerinde.
  @visibleForTesting
  static void salsa20_8(Uint32List b) {
    final x = Uint32List.fromList(b);
    int rotl(int value, int shift) =>
        ((value << shift) | (value >>> (32 - shift))) & 0xffffffff;
    void quarter(int a, int b, int c, int d) {
      x[b] ^= rotl((x[a] + x[d]) & 0xffffffff, 7);
      x[c] ^= rotl((x[b] + x[a]) & 0xffffffff, 9);
      x[d] ^= rotl((x[c] + x[b]) & 0xffffffff, 13);
      x[a] ^= rotl((x[d] + x[c]) & 0xffffffff, 18);
    }

    for (var i = 0; i < 8; i += 2) {
      quarter(0, 4, 8, 12);
      quarter(5, 9, 13, 1);
      quarter(10, 14, 2, 6);
      quarter(15, 3, 7, 11);
      quarter(0, 1, 2, 3);
      quarter(5, 6, 7, 4);
      quarter(10, 11, 8, 9);
      quarter(15, 12, 13, 14);
    }
    for (var i = 0; i < 16; i++) {
      b[i] = (b[i] + x[i]) & 0xffffffff;
    }
  }

  static Uint32List _toWords(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    return Uint32List.fromList([
      for (var i = 0; i < bytes.length; i += 4)
        data.getUint32(i, Endian.little),
    ]);
  }

  static Uint8List _toBytes(Uint32List words) {
    final bytes = Uint8List(words.length * 4);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < words.length; i++) {
      data.setUint32(i * 4, words[i], Endian.little);
    }
    return bytes;
  }
}

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_header.dart';
import 'package:pointycastle/export.dart';

/// Gövdenin şifresini çözer. CBC dolgusu tutmazsa ya da uzunluk blok
/// boyutunun katı değilse `null`: anahtar yanlış ya da veri bozuk.
///
/// `pointycastle` kullanılır: birkaç megabaytlık iş, bilgisayardaki
/// testlerle telefonda aynı kod çalışır.
Uint8List? decryptBody(
  KdbxCipher cipher,
  Uint8List key,
  Uint8List iv,
  Uint8List data,
) {
  switch (cipher) {
    case KdbxCipher.chaCha20:
      final engine = ChaCha7539Engine()
        ..init(false, ParametersWithIV(KeyParameter(key), iv));
      return engine.process(data);
    case KdbxCipher.aes256 || KdbxCipher.twofish:
      if (data.isEmpty || data.length % 16 != 0) return null;
      final engine = CBCBlockCipher(
        cipher == KdbxCipher.aes256 ? AESEngine() : TwofishEngine(),
      )..init(false, ParametersWithIV(KeyParameter(key), iv));
      final plain = Uint8List(data.length);
      for (var offset = 0; offset < data.length; offset += 16) {
        engine.processBlock(data, offset, plain, offset);
      }
      // PKCS#7 dolgusu.
      final pad = plain.last;
      var valid = pad >= 1 && pad <= 16;
      for (var i = 1; valid && i <= pad; i++) {
        valid = plain[plain.length - i] == pad;
      }
      if (!valid) {
        plain.fillRange(0, plain.length, 0);
        return null;
      }
      final out = Uint8List.fromList(
        Uint8List.sublistView(plain, 0, plain.length - pad),
      );
      plain.fillRange(0, plain.length, 0);
      return out;
  }
}

/// Korumalı değerlerin iç akışı: belge sırasıyla her değer bu akışla
/// XOR'lanır. Kimlik 2 Salsa20, 3 ChaCha20, 0 koruma yok.
final class KdbxInnerStream {
  new(int id, Uint8List key) : _engine = _engineFor(id, key);

  final StreamCipher? _engine;

  static const _salsa20Iv = [0xE8, 0x30, 0x09, 0x4B, 0x97, 0x20, 0x5D, 0x2A];

  static StreamCipher? _engineFor(int id, Uint8List key) {
    switch (id) {
      case 2:
        final engine = Salsa20Engine()
          ..init(
            false,
            ParametersWithIV(
              KeyParameter(Uint8List.fromList(sha256.convert(key).bytes)),
              Uint8List.fromList(_salsa20Iv),
            ),
          );
        return engine;
      case 3:
        final hash = sha512.convert(key).bytes;
        return ChaCha7539Engine()..init(
          false,
          ParametersWithIV(
            KeyParameter(Uint8List.fromList(hash.sublist(0, 32))),
            Uint8List.fromList(hash.sublist(32, 44)),
          ),
        );
      default:
        return null;
    }
  }

  /// [data] akışın sıradaki baytlarıyla XOR'lanmış kopya.
  Uint8List apply(Uint8List data) => _engine?.process(data) ?? data;
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:keykey/features/backup/data/import/kdbx/kdbx_bytes.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_exception.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_kdf.dart';

/// Gövdenin şifresi.
enum KdbxCipher { aes256, chaCha20, twofish }

/// Gövdenin sıkıştırması.
enum KdbxCompression { none, gzip }

/// Anahtar türetme parametreleri.
sealed class KdbxKdfParams {
  const new();
}

final class AesKdfParams extends KdbxKdfParams {
  const new({required this.seed, required this.rounds});

  final Uint8List seed;
  final int rounds;
}

final class Argon2Params extends KdbxKdfParams {
  const new({
    required this.type,
    required this.salt,
    required this.iterations,
    required this.memoryKiB,
    required this.parallelism,
    required this.version,
    this.secret,
    this.associatedData,
  });

  final Argon2Type type;
  final Uint8List salt;
  final int iterations;
  final int memoryKiB;
  final int parallelism;
  final int version;
  final Uint8List? secret;
  final Uint8List? associatedData;
}

/// KDBX dosyasının şifresiz dış başlığı.
///
/// Dosya güvenilmeyen veridir: her uzunluk sınırlıdır, taşan okuma ve
/// beklenmeyen değer [KdbxCorrupt], tanınmayan biçim [KdbxUnsupported],
/// telefon için ağır anahtar türetme [KdbxTooHeavy] olur. Kurallar KeePass
/// içe aktarma tasarımında.
final class KdbxHeader {
  const new({
    required this.majorVersion,
    required this.minorVersion,
    required this.cipher,
    required this.compression,
    required this.masterSeed,
    required this.encryptionIv,
    required this.kdf,
    required this.bytes,
    this.protectedStreamKey,
    this.streamStartBytes,
    this.innerStreamId,
  });

  factory parse(Uint8List file) {
    if (isKdb(file)) throw const KdbxUnsupported('KeePass 1');
    if (!isKdbx(file)) throw const KdbxCorrupt();
    final reader = KdbxByteReader(file)..view(8);
    final minor = reader.u16();
    final major = reader.u16();
    if (major < 2 || major > 4) throw KdbxUnsupported('KDBX $major');
    final v4 = major == 4;

    final fields = <int, Uint8List>{};
    while (true) {
      final id = reader.u8();
      final length = v4 ? reader.u32() : reader.u16();
      if (length > maxFieldBytes) throw const KdbxCorrupt();
      final data = reader.view(length);
      if (id == 0) break;
      // Yorum (1) ve genel özel veri (12) yok sayılır.
      if (id == 1 || id == 12) continue;
      if (id > 12 || fields.containsKey(id)) throw const KdbxCorrupt();
      fields[id] = data;
    }

    Uint8List required(int id) => fields[id] ?? (throw const KdbxCorrupt());

    final cipher = _cipher(required(2));
    final ivLength = cipher == KdbxCipher.chaCha20 ? 12 : 16;
    final iv = required(7);
    if (iv.length != ivLength) throw const KdbxCorrupt();
    final masterSeed = required(4);
    if (masterSeed.length != 32) throw const KdbxCorrupt();

    if (v4) {
      for (final id in [5, 6, 8, 9, 10]) {
        if (fields.containsKey(id)) throw const KdbxCorrupt();
      }
      return KdbxHeader(
        majorVersion: major,
        minorVersion: minor,
        cipher: cipher,
        compression: _compression(required(3)),
        masterSeed: masterSeed,
        encryptionIv: iv,
        kdf: _kdfFromDictionary(required(11)),
        bytes: Uint8List.sublistView(file, 0, reader.offset),
      );
    }

    if (fields.containsKey(11)) throw const KdbxCorrupt();
    final seed = required(5);
    if (seed.length != 32) throw const KdbxCorrupt();
    final rounds = _u64(required(6));
    if (rounds > maxAesKdfRounds) throw const KdbxTooHeavy();
    final streamStart = required(9);
    if (streamStart.length != 32) throw const KdbxCorrupt();
    final innerStream = _u32(required(10));
    checkInnerStreamId(innerStream);
    return KdbxHeader(
      majorVersion: major,
      minorVersion: minor,
      cipher: cipher,
      compression: _compression(required(3)),
      masterSeed: masterSeed,
      encryptionIv: iv,
      kdf: AesKdfParams(seed: seed, rounds: rounds),
      bytes: Uint8List.sublistView(file, 0, reader.offset),
      protectedStreamKey: required(8),
      streamStartBytes: streamStart,
      innerStreamId: innerStream,
    );
  }

  final int majorVersion;
  final int minorVersion;
  final KdbxCipher cipher;
  final KdbxCompression compression;
  final Uint8List masterSeed;
  final Uint8List encryptionIv;
  final KdbxKdfParams kdf;

  /// Başlığın ham baytları, son alan dahil (özet ve HMAC için).
  final Uint8List bytes;

  /// Yalnızca KDBX 2 ve 3; KDBX 4'te bunlar iç başlıkta.
  final Uint8List? protectedStreamKey;
  final Uint8List? streamStartBytes;
  final int? innerStreamId;

  /// Başlık alanı ve sözlük değeri için üst sınır.
  static const int maxFieldBytes = 1024 * 1024;
  static const int maxArgon2MemoryKiB = 1024 * 1024;
  static const maxArgon2Iterations = 1000;
  static const maxArgon2Parallelism = 64;
  static const maxAesKdfRounds = 1000000000;

  static const _signature1 = [0x03, 0xD9, 0xA2, 0x9A];
  static const _signatureKdbx = [0x67, 0xFB, 0x4B, 0xB5];
  static const _signatureKdb = [0x65, 0xFB, 0x4B, 0xB5];

  static bool _startsWith(Uint8List bytes, List<int> second) {
    if (bytes.length < 8) return false;
    for (var i = 0; i < 4; i++) {
      if (bytes[i] != _signature1[i] || bytes[4 + i] != second[i]) {
        return false;
      }
    }
    return true;
  }

  /// İlk 8 bayt KDBX imzası mı (sürüme bakılmaz).
  static bool isKdbx(Uint8List bytes) => _startsWith(bytes, _signatureKdbx);

  /// İlk 8 bayt KeePass 1 (`.kdb`) imzası mı.
  static bool isKdb(Uint8List bytes) => _startsWith(bytes, _signatureKdb);

  /// İç akış kimliği: 0 koruma yok, 2 Salsa20, 3 ChaCha20.
  static void checkInnerStreamId(int id) {
    if (id == 1) throw const KdbxUnsupported('ArcFour');
    if (id != 0 && id != 2 && id != 3) throw KdbxUnsupported('akış $id');
  }

  static KdbxCipher _cipher(Uint8List uuid) => switch (kdbxHex(uuid)) {
    '31c1f2e6bf714350be5805216afc5aff' => KdbxCipher.aes256,
    'd6038a2b8b6f4cb5a524339a31dbb59a' => KdbxCipher.chaCha20,
    'ad68f29f576f4bb9a36ad47af965346c' => KdbxCipher.twofish,
    final other => throw KdbxUnsupported(other),
  };

  static KdbxCompression _compression(Uint8List data) => switch (_u32(data)) {
    0 => KdbxCompression.none,
    1 => KdbxCompression.gzip,
    _ => throw const KdbxCorrupt(),
  };

  static int _u32(Uint8List data) {
    if (data.length != 4) throw const KdbxCorrupt();
    return KdbxByteReader(data).u32();
  }

  static int _u64(Uint8List data) {
    if (data.length != 8) throw const KdbxCorrupt();
    return KdbxByteReader(data).u64();
  }

  static KdbxKdfParams _kdfFromDictionary(Uint8List data) {
    final values = _variantDictionary(data);
    Uint8List bytes(String key) => switch (values[key]) {
      (0x42, final Uint8List value) => value,
      _ => throw const KdbxCorrupt(),
    };
    Uint8List? optionalBytes(String key) =>
        values.containsKey(key) ? bytes(key) : null;
    int number(String key) => switch (values[key]) {
      (0x04, final Uint8List value) => _u32(value),
      (0x05, final Uint8List value) => _u64(value),
      _ => throw const KdbxCorrupt(),
    };

    switch (kdbxHex(bytes(r'$UUID'))) {
      case 'c9d9f39a628a4460bf740d08c18a4fea' ||
          '7c02bb8279a74ac0927d114a00648238':
        // İkinci UUID KeePass'ın KDBX 3 AES-KDF kimliği; KeePassXC bazen
        // KDBX 4'te de yazıyor.
        final seed = bytes('S');
        if (seed.length != 32) throw const KdbxCorrupt();
        final rounds = number('R');
        if (rounds > maxAesKdfRounds) throw const KdbxTooHeavy();
        return AesKdfParams(seed: seed, rounds: rounds);
      case final uuid
          when uuid == 'ef636ddf8c29444b91f7a9a403e30a0c' ||
              uuid == '9e298b1956db4773b23dfc3ec6f0a1e6':
        final type = uuid.startsWith('ef63') ? Argon2Type.d : Argon2Type.id;
        final memory = number('M');
        final iterations = number('I');
        final parallelism = number('P');
        final version = number('V');
        final salt = bytes('S');
        if (memory % 1024 != 0 || iterations < 1 || parallelism < 1) {
          throw const KdbxCorrupt();
        }
        if (salt.length < 8) throw const KdbxCorrupt();
        if (version != 0x10 && version != 0x13) {
          throw KdbxUnsupported('Argon2 $version');
        }
        final memoryKiB = memory ~/ 1024;
        if (memoryKiB > maxArgon2MemoryKiB ||
            iterations > maxArgon2Iterations ||
            parallelism > maxArgon2Parallelism) {
          throw const KdbxTooHeavy();
        }
        // Argon2'nin kendi kuralı: her şerit için en az 8 KiB.
        if (memoryKiB < 8 * parallelism) throw const KdbxCorrupt();
        return Argon2Params(
          type: type,
          salt: salt,
          iterations: iterations,
          memoryKiB: memoryKiB,
          parallelism: parallelism,
          version: version,
          secret: optionalBytes('K'),
          associatedData: optionalBytes('A'),
        );
      case final other:
        throw KdbxUnsupported(other);
    }
  }

  /// KDBX 4 `VariantDictionary`: ad → (tür, değer).
  static Map<String, (int, Uint8List)> _variantDictionary(Uint8List data) {
    final reader = KdbxByteReader(data);
    if (reader.u16() & 0xFF00 != 0x0100) throw const KdbxCorrupt();
    final values = <String, (int, Uint8List)>{};
    while (true) {
      final type = reader.u8();
      if (type == 0) break;
      final nameLength = reader.u32();
      if (nameLength > maxFieldBytes) throw const KdbxCorrupt();
      final String name;
      try {
        name = utf8.decode(reader.view(nameLength));
      } on FormatException {
        throw const KdbxCorrupt();
      }
      final valueLength = reader.u32();
      if (valueLength > maxFieldBytes) throw const KdbxCorrupt();
      final value = reader.view(valueLength);
      if (values.containsKey(name)) throw const KdbxCorrupt();
      values[name] = (type, value);
    }
    return values;
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_bytes.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_cipher.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_exception.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_header.dart';
import 'package:keykey/features/backup/data/import/kdbx/kdbx_kdf.dart';

/// Açılmış XML'in ve tek bloğun en büyük boyutu.
const int maxKdbxXmlBytes = 64 * 1024 * 1024;

/// Şifresi çözülmüş, doğrulanmış ve açılmış gövde.
final class KdbxPayload {
  new({
    required this.xml,
    required this.innerStreamId,
    required this.innerStreamKey,
    required this.binaryCount,
  });

  final Uint8List xml;
  final int innerStreamId;
  final Uint8List innerStreamKey;

  /// KDBX 4 iç başlığındaki ek sayısı; KDBX 2 ve 3'te ekler XML'de.
  final int binaryCount;

  /// Çözülmüş baytları sıfırlar.
  void wipe() {
    xml.fillRange(0, xml.length, 0);
    innerStreamKey.fillRange(0, innerStreamKey.length, 0);
  }
}

/// Bileşik anahtardan dönüştürülmüş anahtar (32 bayt).
Future<Uint8List> transformKey(
  KdbxHeader header,
  Uint8List composite,
  KdbxKdf kdf,
) => switch (header.kdf) {
  AesKdfParams(:final seed, :final rounds) => kdf.aesKdf(
    key: composite,
    seed: seed,
    rounds: rounds,
  ),
  final Argon2Params p => kdf.argon2(
    type: p.type,
    password: composite,
    salt: p.salt,
    iterations: p.iterations,
    memoryKiB: p.memoryKiB,
    parallelism: p.parallelism,
    version: p.version,
    secret: p.secret,
    associatedData: p.associatedData,
  ),
};

/// Gövdeyi doğrular, şifresini çözer ve açar.
///
/// Yanlış anahtar [KdbxWrongKey], bozulma [KdbxCorrupt] olur. Hiçbir bayt
/// doğrulanmadan dönmez. Kurallar KeePass içe aktarma tasarımında.
KdbxPayload decryptPayload(
  Uint8List file,
  KdbxHeader header,
  Uint8List transformedKey,
) {
  final seeded = Uint8List(64)
    ..setAll(0, header.masterSeed)
    ..setAll(32, transformedKey);
  final masterKey = Uint8List.fromList(sha256.convert(seeded).bytes);
  try {
    return header.majorVersion >= 4
        ? _decrypt4(file, header, masterKey, seeded)
        : _decrypt3(file, header, masterKey);
  } finally {
    seeded.fillRange(0, seeded.length, 0);
    masterKey.fillRange(0, masterKey.length, 0);
  }
}

KdbxPayload _decrypt3(Uint8List file, KdbxHeader header, Uint8List masterKey) {
  final body = Uint8List.sublistView(file, header.bytes.length);
  // Anahtar önce gövdenin kesilmeden çözülebilen başıyla doğrulanır; sonra
  // çıkan uzunluk ya da dolgu hatası yarım kalmış bir dosyadır, yanlış
  // parola değil.
  if (body.length < 32) throw const KdbxCorrupt();
  final start = decryptStart(
    header.cipher,
    masterKey,
    header.encryptionIv,
    body,
    32,
  );
  final keyMatches = kdbxBytesEqual(start, header.streamStartBytes!);
  start.fillRange(0, start.length, 0);
  if (!keyMatches) throw const KdbxWrongKey();
  final plain = decryptBody(
    header.cipher,
    masterKey,
    header.encryptionIv,
    body,
  );
  if (plain == null || plain.length < 32) throw const KdbxCorrupt();
  try {
    final blocks = readHashedBlocks(Uint8List.sublistView(plain, 32));
    final Uint8List xml;
    try {
      xml = _decompress(header, blocks);
    } finally {
      // Birden çok blokta yeni bir kopya, tek blokta [plain]'in görünümü.
      blocks.fillRange(0, blocks.length, 0);
    }
    return KdbxPayload(
      xml: xml,
      innerStreamId: header.innerStreamId!,
      innerStreamKey: Uint8List.fromList(header.protectedStreamKey!),
      binaryCount: 0,
    );
  } finally {
    plain.fillRange(0, plain.length, 0);
  }
}

KdbxPayload _decrypt4(
  Uint8List file,
  KdbxHeader header,
  Uint8List masterKey,
  Uint8List seeded,
) {
  final reader = KdbxByteReader(file)..view(header.bytes.length);
  final storedHash = reader.view(32);
  if (!kdbxBytesEqual(sha256.convert(header.bytes).bytes, storedHash)) {
    throw const KdbxCorrupt();
  }
  final baseInput = Uint8List(seeded.length + 1)
    ..setAll(0, seeded)
    ..[seeded.length] = 0x01;
  final hmacBase = Uint8List.fromList(sha512.convert(baseInput).bytes);
  baseInput.fillRange(0, baseInput.length, 0);
  try {
    final storedHmac = reader.view(32);
    final headerHmac = _hmac(hmacBase, -1, header.bytes);
    if (!kdbxBytesEqual(headerHmac, storedHmac)) throw const KdbxWrongKey();

    final cipherText = BytesBuilder(copy: false);
    for (var index = 0; ; index++) {
      final hmac = reader.view(32);
      final size = reader.u32();
      if (size > maxKdbxXmlBytes || cipherText.length + size > file.length) {
        throw const KdbxCorrupt();
      }
      final data = reader.view(size);
      final message = BytesBuilder(copy: false)
        ..add(_u64le(index))
        ..add(_u32le(size))
        ..add(data);
      final expected = _hmac(hmacBase, index, message.takeBytes());
      if (!kdbxBytesEqual(expected, hmac)) throw const KdbxCorrupt();
      if (size == 0) break;
      cipherText.add(data);
    }
    final plain = decryptBody(
      header.cipher,
      masterKey,
      header.encryptionIv,
      cipherText.takeBytes(),
    );
    // HMAC doğrulandıktan sonra dolgu tutmuyorsa dosya bozuk yazılmış.
    if (plain == null) throw const KdbxCorrupt();
    Uint8List? opened;
    try {
      opened = _decompress(header, plain);
      return _innerHeader(opened);
    } finally {
      plain.fillRange(0, plain.length, 0);
      opened?.fillRange(0, opened.length, 0);
    }
  } finally {
    hmacBase.fillRange(0, hmacBase.length, 0);
  }
}

/// KDBX 4 iç başlığı; kalan baytlar XML.
KdbxPayload _innerHeader(Uint8List data) {
  final reader = KdbxByteReader(data);
  int? streamId;
  Uint8List? streamKey;
  var binaries = 0;
  try {
    while (true) {
      final id = reader.u8();
      final length = reader.u32();
      final value = reader.view(length);
      if (id == 0) break;
      switch (id) {
        case 1:
          if (length != 4) throw const KdbxCorrupt();
          streamId = KdbxByteReader(value).u32();
        case 2:
          streamKey = Uint8List.fromList(value);
        case 3:
          binaries++;
        default:
          throw const KdbxCorrupt();
      }
    }
    if (streamId == null || streamKey == null) throw const KdbxCorrupt();
    KdbxHeader.checkInnerStreamId(streamId);
    return KdbxPayload(
      xml: Uint8List.fromList(Uint8List.sublistView(data, reader.offset)),
      innerStreamId: streamId,
      innerStreamKey: streamKey,
      binaryCount: binaries,
    );
  } finally {
    data.fillRange(0, data.length, 0);
  }
}

Uint8List _decompress(KdbxHeader header, Uint8List data) =>
    header.compression == KdbxCompression.gzip
    ? kdbxGunzip(data)
    : Uint8List.fromList(data);

/// KDBX 2 ve 3'ün `HashedBlockStream`'i: `u32 sıra ‖ SHA-256 ‖ i32 boy ‖
/// veri`, son blok boş ve özeti sıfır.
Uint8List readHashedBlocks(Uint8List data) {
  final reader = KdbxByteReader(data);
  final out = BytesBuilder(copy: false);
  for (var index = 0; ; index++) {
    if (reader.u32() != index) throw const KdbxCorrupt();
    final hash = reader.view(32);
    final size = reader.u32();
    if (size > maxKdbxXmlBytes) throw const KdbxCorrupt();
    final block = reader.view(size);
    if (size == 0) {
      if (hash.any((b) => b != 0)) throw const KdbxCorrupt();
      return out.takeBytes();
    }
    if (!kdbxBytesEqual(sha256.convert(block).bytes, hash)) {
      throw const KdbxCorrupt();
    }
    out.add(block);
  }
}

/// gzip'i en çok [limit] bayta kadar açar; aşarsa [KdbxTooHeavy].
Uint8List kdbxGunzip(Uint8List data, {int limit = maxKdbxXmlBytes}) {
  final sink = _LimitedSink(limit);
  final input = GZipCodec().decoder.startChunkedConversion(sink);
  try {
    // Küçük parçalarla verilir; gzip bombası sınırı çok aşmadan durur.
    const chunk = 4096;
    for (var offset = 0; offset < data.length; offset += chunk) {
      final end = offset + chunk < data.length ? offset + chunk : data.length;
      input.add(Uint8List.sublistView(data, offset, end));
    }
    input.close();
  } on KdbxException {
    sink.wipe();
    rethrow;
  } on Object {
    // FormatException ya da zlib hatası.
    sink.wipe();
    throw const KdbxCorrupt();
  }
  // Dart'ın çözücüsü kesik akışta hata vermiyor. gzip'in son 4 baytı açılmış
  // boyutun 2^32'ye göre kalanı; tutmazsa akış kesik ya da bozuk.
  final out = sink.takeBytes();
  if (data.length < 18 ||
      ByteData.sublistView(data).getUint32(data.length - 4, Endian.little) !=
          out.length & 0xFFFFFFFF) {
    out.fillRange(0, out.length, 0);
    throw const KdbxCorrupt();
  }
  return out;
}

final class _LimitedSink implements Sink<List<int>> {
  new(this._limit);

  final int _limit;
  final _chunks = <Uint8List>[];
  int _length = 0;

  @override
  void add(List<int> data) {
    if (_length + data.length > _limit) throw const KdbxTooHeavy();
    _chunks.add(Uint8List.fromList(data));
    _length += data.length;
  }

  @override
  void close() {}

  void wipe() {
    for (final chunk in _chunks) {
      chunk.fillRange(0, chunk.length, 0);
    }
  }

  /// Parçaları tek diziye kopyalar ve parçaları sıfırlar. Ara bir birleşik
  /// dizi bırakılmaz; çözülmüş verinin her kopyası sıfırlanabilir kalır.
  Uint8List takeBytes() {
    final bytes = Uint8List(_length);
    var offset = 0;
    for (final chunk in _chunks) {
      bytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    wipe();
    return bytes;
  }
}

/// Blok HMAC'i. Anahtar `SHA-512(u64le(sıra) ‖ taban)`; başlık için sıra
/// `2^64 − 1` ([index] −1). Anahtar ve girdisi işi bitince sıfırlanır.
List<int> _hmac(Uint8List base, int index, List<int> message) {
  final input = Uint8List(8 + base.length)
    ..setAll(0, _u64le(index))
    ..setAll(8, base);
  final key = Uint8List.fromList(sha512.convert(input).bytes);
  input.fillRange(0, input.length, 0);
  try {
    return Hmac(sha256, key).convert(message).bytes;
  } finally {
    key.fillRange(0, key.length, 0);
  }
}

Uint8List _u64le(int value) =>
    (ByteData(8)..setInt64(0, value, Endian.little)).buffer.asUint8List();

Uint8List _u32le(int value) =>
    (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();

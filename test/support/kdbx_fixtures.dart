import 'dart:io';
import 'dart:typed_data';

/// `test/fixtures/import/kdbx/` altındaki bir dosya, ör. `pykeepass/test4.kdbx`.
Uint8List kdbxFixture(String path) =>
    File('test/fixtures/import/kdbx/$path').readAsBytesSync();

/// Testlerde elle KDBX başlığı kurmak için.
final class KdbxHeaderBuilder {
  new(this.major, {this.minor = 1});

  final int major;
  final int minor;
  final _fields = BytesBuilder();

  void field(int id, List<int> data) {
    _fields
      ..addByte(id)
      ..add(major >= 4 ? u32(data.length) : _u16(data.length))
      ..add(data);
  }

  Uint8List build({List<int> signature2 = const [0x67, 0xFB, 0x4B, 0xB5]}) {
    final version = ByteData(4)
      ..setUint16(0, minor, Endian.little)
      ..setUint16(2, major, Endian.little);
    return (BytesBuilder()
          ..add([0x03, 0xD9, 0xA2, 0x9A])
          ..add(signature2)
          ..add(version.buffer.asUint8List())
          ..add(_fields.toBytes()))
        .toBytes();
  }
}

/// KDBX 4 sözlüğü (`VariantDictionary`).
Uint8List variantDictionary(Map<String, (int, List<int>)> items) {
  final out = BytesBuilder()..add([0x00, 0x01]);
  for (final MapEntry(:key, value: (type, value)) in items.entries) {
    final name = key.codeUnits;
    out
      ..addByte(type)
      ..add(u32(name.length))
      ..add(name)
      ..add(u32(value.length))
      ..add(value);
  }
  out.addByte(0);
  return out.toBytes();
}

List<int> u32(int value) =>
    (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();

List<int> u64(int value) =>
    (ByteData(8)..setUint64(0, value, Endian.little)).buffer.asUint8List();

List<int> _u16(int value) =>
    (ByteData(2)..setUint16(0, value, Endian.little)).buffer.asUint8List();

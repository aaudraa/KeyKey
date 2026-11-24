import 'dart:convert';
import 'dart:typed_data';

/// WebAuthn'ın ihtiyaç duyduğu kadar CBOR yazıcısı (RFC 8949): tamsayı,
/// bayt dizisi, metin, mantıksal değer, dizi ve eşlem. Eşlem anahtarları
/// CTAP2'nin kanonik sırasıyla yazılır: önce kodlanmış uzunluk, sonra
/// baytlar. Başka türler [ArgumentError].
Uint8List cborEncode(Object? value) {
  final out = BytesBuilder(copy: false);
  _write(out, value);
  return out.takeBytes();
}

void _write(BytesBuilder out, Object? value) {
  switch (value) {
    case final int v when v >= 0:
      _head(out, 0, v);
    case final int v:
      _head(out, 1, -1 - v);
    case final Uint8List v:
      _head(out, 2, v.length);
      out.add(v);
    case final String v:
      final bytes = utf8.encode(v);
      _head(out, 3, bytes.length);
      out.add(bytes);
    case final List<Object?> v:
      _head(out, 4, v.length);
      for (final item in v) {
        _write(out, item);
      }
    case final Map<Object?, Object?> v:
      final entries = [
        for (final MapEntry(:key, :value) in v.entries)
          (cborEncode(key), value),
      ]..sort((a, b) => _compare(a.$1, b.$1));
      _head(out, 5, entries.length);
      for (final (key, item) in entries) {
        out.add(key);
        _write(out, item);
      }
    case true:
      out.addByte(0xf5);
    case false:
      out.addByte(0xf4);
    default:
      throw ArgumentError.value(value, 'value', 'CBOR türü desteklenmiyor');
  }
}

void _head(BytesBuilder out, int major, int length) {
  final type = major << 5;
  if (length < 24) {
    out.addByte(type | length);
  } else if (length < 0x100) {
    out
      ..addByte(type | 24)
      ..addByte(length);
  } else if (length < 0x10000) {
    out.add([type | 25, length >> 8, length & 0xff]);
  } else if (length < 0x100000000) {
    out
      ..addByte(type | 26)
      ..add(_bigEndian(length, 4));
  } else {
    out
      ..addByte(type | 27)
      ..add(_bigEndian(length, 8));
  }
}

List<int> _bigEndian(int value, int length) => [
  for (var i = length - 1; i >= 0; i--) (value >> (8 * i)) & 0xff,
];

int _compare(Uint8List a, Uint8List b) {
  if (a.length != b.length) return a.length.compareTo(b.length);
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return a[i].compareTo(b[i]);
  }
  return 0;
}

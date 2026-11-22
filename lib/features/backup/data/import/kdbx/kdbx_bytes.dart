import 'dart:typed_data';

import 'package:keykey/features/backup/data/import/kdbx/kdbx_exception.dart';

/// Güvenilmeyen ikili veriyi küçük-endian okuyan imleç. Taşan her okuma
/// [KdbxCorrupt] fırlatır.
final class KdbxByteReader {
  new(this._data);

  final Uint8List _data;
  int _offset = 0;

  int get offset => _offset;
  int get remaining => _data.length - _offset;

  void _need(int count) {
    if (count < 0 || count > remaining) throw const KdbxCorrupt();
  }

  int u8() {
    _need(1);
    return _data[_offset++];
  }

  int u16() {
    _need(2);
    final value = ByteData.sublistView(_data).getUint16(_offset, Endian.little);
    _offset += 2;
    return value;
  }

  int u32() {
    _need(4);
    final value = ByteData.sublistView(_data).getUint32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  /// İşaretsiz 64 bit; 2^63'ü aşan değer bozuk sayılır (Dart'ın `int`'i
  /// işaretli).
  int u64() {
    _need(8);
    final value = ByteData.sublistView(_data).getInt64(_offset, Endian.little);
    _offset += 8;
    if (value < 0) throw const KdbxCorrupt();
    return value;
  }

  /// [count] bayt, kopyalanmadan görünüm olarak.
  Uint8List view(int count) {
    _need(count);
    final value = Uint8List.sublistView(_data, _offset, _offset + count);
    _offset += count;
    return value;
  }
}

/// Sabit zamanlı karşılaştırma.
bool kdbxBytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Küçük harf onaltılık.
String kdbxHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

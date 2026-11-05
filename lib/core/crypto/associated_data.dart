import 'dart:convert';
import 'dart:typed_data';

/// Şifreli veriyi bağlamına bağlayan ek doğrulama verisini üretir.
///
/// Her alan 4 baytlık uzunluk önekiyle yazılır, böylece farklı alan dizilimleri
/// aynı bayt dizisine denk gelemez. Metinler UTF-8, sayılar 8 baytlık büyük
/// uçlu olarak kodlanır.
Uint8List buildAssociatedData(List<Object> fields) {
  final builder = BytesBuilder(copy: false);
  for (final field in fields) {
    final bytes = switch (field) {
      final String text => utf8.encode(text),
      final int number => _encodeInt(number),
      final Uint8List data => data,
      _ => throw ArgumentError.value(field, 'fields', 'Desteklenmeyen tür'),
    };
    builder
      ..add(_encodeLength(bytes.length))
      ..add(bytes);
  }
  return builder.takeBytes();
}

Uint8List _encodeLength(int length) =>
    (ByteData(4)..setUint32(0, length)).buffer.asUint8List();

Uint8List _encodeInt(int number) =>
    (ByteData(8)..setInt64(0, number)).buffer.asUint8List();

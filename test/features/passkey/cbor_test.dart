import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/passkey/domain/cbor.dart';

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  // RFC 8949, ek A.
  final vectors = <Object?, String>{
    0: '00',
    23: '17',
    24: '1818',
    255: '18ff',
    256: '190100',
    65536: '1a00010000',
    4294967296: '1b0000000100000000',
    -1: '20',
    -500: '3901f3',
    'a': '6161',
    'ü': '62c3bc',
    true: 'f5',
    false: 'f4',
  };

  for (final MapEntry(:key, :value) in vectors.entries) {
    test('$key', () => expect(hex(cborEncode(key)), value));
  }

  test('bayt dizisi, dizi ve eşlem', () {
    expect(hex(cborEncode(Uint8List(0))), '40');
    expect(hex(cborEncode(Uint8List.fromList([1, 2, 3, 4]))), '4401020304');
    expect(
      hex(
        cborEncode([
          1,
          [2, 3],
        ]),
      ),
      '8201820203',
    );
    expect(hex(cborEncode({1: 2, 3: 4})), 'a201020304');
    expect(hex(cborEncode(<String, Object?>{})), 'a0');
  });

  test('eşlem anahtarları kanonik sırada (önce uzunluk)', () {
    // COSE anahtarı: 1, 3, -1, -2, -3.
    expect(
      hex(cborEncode({-3: 0, -1: 0, 3: 0, -2: 0, 1: 0})),
      'a501000300200021002200',
    );
    expect(
      hex(cborEncode({'authData': 0, 'fmt': 0, 'attStmt': 0})),
      'a3'
      '63666d7400'
      '6761747453746d7400'
      '68617574684461746100',
    );
  });

  test('desteklenmeyen tür reddedilir', () {
    expect(() => cborEncode(1.5), throwsArgumentError);
    expect(() => cborEncode(null), throwsArgumentError);
  });
}

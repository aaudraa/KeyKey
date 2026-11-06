import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/authenticator/data/import/import_json.dart';
import 'package:keykey/features/authenticator/data/import/import_result.dart';

void main() {
  group('onaltılık değer', () {
    test('büyük ve küçük harf okunuyor', () {
      expect(ImportJson.hex('00ffAb'), [0x00, 0xff, 0xab]);
      expect(ImportJson.hex(''), isEmpty);
    });

    test('işaret, boşluk ve tek uzunluk reddediliyor', () {
      for (final value in ['+1', '-1', '0x', ' 1', '1 ', 'abc', 'zz', 12]) {
        expect(
          () => ImportJson.hex(value),
          throwsA(isA<InvalidImportException>()),
          reason: '$value',
        );
      }
    });
  });
}

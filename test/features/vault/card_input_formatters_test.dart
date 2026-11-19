import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/vault/presentation/card_input_formatters.dart';

TextEditingValue _typed(String text) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
);

void main() {
  group('CardNumberInputFormatter', () {
    const formatter = CardNumberInputFormatter();

    String apply(String text) =>
        formatter.formatEditUpdate(TextEditingValue.empty, _typed(text)).text;

    test('yapıştırılan boşluklu ve tireli numara gruplanır', () {
      expect(apply('4111-1111 1111 1111'), '4111 1111 1111 1111');
    });

    test('American Express 4-6-5', () {
      expect(apply('378282246310005'), '3782 822463 10005');
    });

    test('19 haneden sonrası yok sayılır', () {
      expect(apply('1' * 20).replaceAll(' ', ''), '1' * 19);
    });

    test('rakam dışı karakterler atılır', () {
      expect(apply('4111a'), '4111');
    });

    test('imleç yazılan rakamın arkasında kalır', () {
      final value = formatter.formatEditUpdate(
        _typed('4111 1111'),
        const TextEditingValue(
          text: '41111 1111',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(value.text, '4111 1111 1');
      expect(value.selection.extentOffset, 6);
    });
  });

  group('ExpiryInputFormatter', () {
    const formatter = ExpiryInputFormatter();

    String apply(String text) =>
        formatter.formatEditUpdate(TextEditingValue.empty, _typed(text)).text;

    test('ikinci rakamdan sonra eğik çizgi', () {
      expect(apply('1228'), '12/28');
      expect(apply('123'), '12/3');
      expect(apply('12'), '12');
    });

    test('dört rakamdan fazlası ve harfler atılır', () {
      expect(apply('12/289'), '12/28');
      expect(apply('1a2'), '12');
    });
  });
}

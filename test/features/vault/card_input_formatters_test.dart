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

    test('dolu numaranın ortasına yazılan rakam sondakini silmez', () {
      final full = formatter.formatEditUpdate(
        TextEditingValue.empty,
        _typed('4111111111111111123'),
      );
      final text = full.text;
      // İkinci rakamdan sonra bir rakam daha yazılıyor: 20 rakam olurdu.
      final value = formatter.formatEditUpdate(
        full,
        TextEditingValue(
          text: '${text.substring(0, 2)}9${text.substring(2)}',
          selection: const TextSelection.collapsed(offset: 3),
        ),
      );
      expect(value.text, text);
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

    test('dört haneli yılla yapıştırılan tarih AA/YY olur', () {
      expect(apply('12/2030'), '12/30');
      expect(apply('9/2031'), '09/31');
      expect(apply(' 03 / 2029 '), '03/29');
    });

    test('dolu tarihin tamamı seçilip yapıştırılan tarih yerine geçer', () {
      final value = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '12/30',
          selection: TextSelection(baseOffset: 0, extentOffset: 5),
        ),
        _typed('01/2032'),
      );
      expect(value.text, '01/32');
    });

    test('dolu tarihin ortasına yazılan rakam sondakini silmez', () {
      final value = formatter.formatEditUpdate(
        _typed('12/30'),
        const TextEditingValue(
          text: '152/30',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      expect(value.text, '12/30');
    });
  });
}

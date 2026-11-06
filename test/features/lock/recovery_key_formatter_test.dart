import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/crypto/recovery_key.dart';
import 'package:keykey/features/lock/presentation/recovery_key_formatter.dart';

void main() {
  final formatter = RecoveryKeyFormatter();

  TextEditingValue type(String text, [int? cursor]) =>
      formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: cursor ?? text.length),
        ),
      );

  test('tireler kendiliğinden geliyor, harfler büyüyor', () {
    final value = type('pvbr54zaz78gv');
    expect(value.text, 'PVBR5-4ZAZ7-8GV');
    expect(value.selection.extentOffset, value.text.length);
  });

  test('grup sonunda tire bırakmıyor, elle yazılan tire yok sayılıyor', () {
    expect(type('pvbr5').text, 'PVBR5');
    expect(type('PVBR5-').text, 'PVBR5');
    expect(type('pvbr5 - 4zaz7').text, 'PVBR5-4ZAZ7');
  });

  test('alfabede olmayan O, I, L ve Türkçe ı, İ rakama dönüyor', () {
    expect(type('oOiIlLıİ').text, '00111-111');
  });

  test('ortaya yazınca imleç yazılan karakterin arkasında kalıyor', () {
    // "AAAAA-BBBBB" içinde ilk B'den önce X yazıldı, imleç 7.
    final value = type('AAAAA-XBBBBB', 7);
    expect(value.text, 'AAAAA-XBBBB-B');
    expect(value.selection.extentOffset, 7);
  });

  test('başka karakter içeren metne dokunmuyor', () {
    expect(type('ab.cd').text, 'ab.cd');
  });

  test('symbolsOf tire ve boşluğu atıp karakterleri çeviriyor', () {
    expect(RecoveryKeyCodec.symbolsOf('pvbr5-4zaz7 o'), 'PVBR54ZAZ70');
    expect(RecoveryKeyCodec.symbolsOf(''), '');
  });
}

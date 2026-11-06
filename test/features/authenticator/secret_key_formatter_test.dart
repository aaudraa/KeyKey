import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/authenticator/presentation/secret_key_formatter.dart';

void main() {
  final formatter = SecretKeyFormatter();

  TextEditingValue type(String text, [int? cursor]) =>
      formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: cursor ?? text.length),
        ),
      );

  test('büyük harfe çeviriyor ve dörderli grupluyor', () {
    final value = type('jbswy3dpehpk3pxp');
    expect(value.text, 'JBSW Y3DP EHPK 3PXP');
    expect(value.selection.extentOffset, value.text.length);
  });

  test('servisin boşluklu veya tireli yazımı aynı düzene giriyor', () {
    expect(type('jbsw y3dp ehpk 3pxp').text, 'JBSW Y3DP EHPK 3PXP');
    expect(type('JBSW-Y3DP-EHPK-3PXP').text, 'JBSW Y3DP EHPK 3PXP');
    expect(type('jb sw  y3').text, 'JBSW Y3');
  });

  test('grup sonunda boşluk bırakmıyor', () {
    expect(type('abcd').text, 'ABCD');
    expect(type('ABCD ').text, 'ABCD');
  });

  test('Türkçe ı ve İ, I oluyor', () {
    expect(type('ıİi').text, 'III');
  });

  test('ortaya yazınca imleç yazılan karakterin arkasında kalıyor', () {
    // "ABCD EFGH" içinde E'den önce X yazıldı: "ABCD XEFGH", imleç 6.
    final value = type('ABCD XEFGH', 6);
    expect(value.text, 'ABCD XEFG H');
    expect(value.selection.extentOffset, 6);
  });

  test('silince imleç yerinde kalıyor', () {
    // "ABCD EFGH" içinde F silindi: "ABCD EGH", imleç 6.
    final value = type('ABCD EGH', 6);
    expect(value.text, 'ABCD EGH');
    expect(value.selection.extentOffset, 6);
  });

  test('yanlış rakamlar da gruplanıyor, hata formda gösteriliyor', () {
    expect(type('abc0 1890').text, 'ABC0 1890');
  });

  test('otpauth bağlantısına ve başka metne dokunmuyor', () {
    const link = 'otpauth://totp/x?secret=JBSWY3DPEHPK3PXP';
    expect(type(link).text, link);
    expect(type('ab.cd ef').text, 'ab.cd ef');
  });

  test('group kayıtlı anahtarı aynı düzende gösteriyor', () {
    expect(SecretKeyFormatter.group('JBSWY3DPEHPK3PXP'), 'JBSW Y3DP EHPK 3PXP');
    expect(SecretKeyFormatter.group(''), '');
  });
}

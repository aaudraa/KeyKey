import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/platform/web_links.dart';

void main() {
  group('webPageUri', () {
    test('http ve https adresleri olduğu gibi', () {
      expect(
        webPageUri('https://bank.example/giris'),
        Uri.parse('https://bank.example/giris'),
      );
      expect(webPageUri('  http://a.example '), Uri.parse('http://a.example'));
      expect(webPageUri('HTTPS://B.example'), Uri.parse('https://b.example'));
    });

    test('şemasız adrese https eklenir', () {
      expect(webPageUri('bank.example'), Uri.parse('https://bank.example'));
      expect(
        webPageUri('bank.example/giris?x=1'),
        Uri.parse('https://bank.example/giris?x=1'),
      );
    });

    test('şemasız adres port taşıyabilir', () {
      expect(
        webPageUri('nas.example:5001'),
        Uri.parse('https://nas.example:5001'),
      );
      expect(
        webPageUri('router.local:8080/admin'),
        Uri.parse('https://router.local:8080/admin'),
      );
      expect(
        webPageUri('192.168.1.1:8080'),
        Uri.parse('https://192.168.1.1:8080'),
      );
    });

    test('kullanıcı bilgisi taşıyan adres açılmaz', () {
      // Ekranda mybank gibi okunur, tarayıcı phish.example'ı açardı.
      expect(webPageUri('https://mybank.example@phish.example'), isNull);
      expect(webPageUri('ali:parola@site.example'), isNull);
    });

    test('web sayfası olmayan adresler açılmaz', () {
      for (final text in [
        '',
        '   ',
        'androidapp://com.example.app',
        'javascript:alert(1)',
        'intent://x#Intent;scheme=https;end',
        'file:///sdcard/a.html',
        'content://com.example/x',
        'mailto:a@example.com',
        'https://',
        'bank example',
      ]) {
        expect(webPageUri(text), isNull, reason: text);
      }
    });
  });
}

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

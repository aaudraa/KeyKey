import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Yol haritasındaki kural: "Ekranlar veritabanına ve kriptoya doğrudan
/// erişemez; yalnızca `application` katmanıyla konuşur." Kaynak üzerinden
/// denetlenir (K4, K9, K12).
///
/// Kayıt türleri (`LoginItem` gibi) ve yakalanan hata türleri
/// (`crypto_exceptions.dart`) ekranlarda kullanılabilir; depo kurmak, kripto
/// yardımcılarını ve veri sağlayıcılarını doğrudan çağırmak kullanılamaz.
void main() {
  Iterable<(String, String)> presentationLines() sync* {
    final files = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') &&
              f.path.replaceAll(r'\', '/').contains('/presentation/'),
        );
    for (final file in files) {
      final path = file.path.replaceAll(r'\', '/');
      for (final line in file.readAsLinesSync()) {
        if (line.trimLeft().startsWith('//')) continue;
        yield (path, line);
      }
    }
  }

  test('ekranlar depo kurmuyor', () {
    final offenders = [
      for (final (path, line) in presentationLines())
        if (line.contains('RepositoryFactoryProvider')) '$path: ${line.trim()}',
    ];
    expect(offenders, isEmpty);
  });

  test('ekranlar kripto yardımcılarını içe aktarmıyor', () {
    final offenders = [
      for (final (path, line) in presentationLines())
        if (line.startsWith("import 'package:keykey/core/crypto/") &&
            !line.contains('crypto_exceptions.dart'))
          '$path: ${line.trim()}',
    ];
    expect(offenders, isEmpty);
  });

  test('ekranlar veri sağlayıcılarını içe aktarmıyor', () {
    final offenders = [
      for (final (path, line) in presentationLines())
        if (line.startsWith("import 'package:keykey/core/storage/") ||
            line.contains('/data/wordlists.dart'))
          '$path: ${line.trim()}',
    ];
    expect(offenders, isEmpty);
  });
}

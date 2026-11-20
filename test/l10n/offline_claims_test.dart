import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/onboarding/data/terms_acceptance.dart';

/// KeyKey 1.6.0'dan beri internete çıkabiliyor (yalnızca kullanıcının
/// başlattığı sızıntı kontrolü). Kullanıcıya gösterilen metinler ve
/// yayımlanan belgeler artık "internete çıkmaz" diyemez.
void main() {
  // Küçük harfe çevrilmiş metinde aranır; Türkçe büyük İ önce i olur.
  const claims = [
    'internet izni yok',
    'internet izni de yok',
    'internete çıkmaz',
    'internete bağlanmadığı',
    'internete çıkmadığı',
    'çevrimdışı parola',
    'çevrimdışı rapor',
    'android için çevrimdışı',
    'no internet permission',
    'not have the internet permission',
    'does not request internet',
    'never goes online',
    'works without the internet',
    'offline password manager',
    'offline report',
  ];

  String normalized(String text) => text.replaceAll('İ', 'i').toLowerCase();

  final files = [
    'README.md',
    'resources/docs/kosullar.md',
    'resources/docs/terms.md',
    'resources/docs/gizlilik.md',
    'resources/docs/privacy.md',
    for (final entity in Directory(
      'fastlane/metadata/android',
    ).listSync(recursive: true))
      if (entity is File &&
          (entity.path.endsWith('full_description.txt') ||
              entity.path.endsWith('short_description.txt')))
        entity.path,
  ];

  for (final path in files) {
    test('$path internete çıkmadığını söylemiyor', () {
      final text = normalized(File(path).readAsStringSync());
      for (final claim in claims) {
        expect(text, isNot(contains(claim)), reason: claim);
      }
    });
  }

  for (final arb in ['lib/l10n/app_tr.arb', 'lib/l10n/app_en.arb']) {
    test('$arb metinleri internete çıkmadığını söylemiyor', () {
      final strings =
          jsonDecode(File(arb).readAsStringSync()) as Map<String, dynamic>;
      for (final MapEntry(:key, :value) in strings.entries) {
        if (key.startsWith('@') || value is! String) continue;
        final text = normalized(value);
        for (final claim in claims) {
          expect(text, isNot(contains(claim)), reason: '$key: $claim');
        }
      }
    });
  }

  test('koşullar değişti, kabul yeniden soruluyor', () {
    expect(currentTermsVersion, greaterThanOrEqualTo(2));
  });
}

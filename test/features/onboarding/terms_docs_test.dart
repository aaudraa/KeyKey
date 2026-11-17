import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/features/onboarding/data/terms_acceptance.dart';

/// Repodaki koşul belgeleri uygulamadaki metinle aynı kalmalı: koşullar
/// uygulamada değişip belgede eski kalırsa (ya da tersi) test kırılır.
void main() {
  for (final (arb, doc, version) in [
    ('lib/l10n/app_tr.arb', 'resources/docs/kosullar.md', '**Sürüm:**'),
    ('lib/l10n/app_en.arb', 'resources/docs/terms.md', '**Version:**'),
  ]) {
    test('$doc uygulamadaki koşullarla aynı', () {
      final strings =
          jsonDecode(File(arb).readAsStringSync()) as Map<String, dynamic>;
      final text = File(doc).readAsStringSync();
      final keys = strings.keys.where(
        (key) => key.startsWith('terms') && !key.startsWith('@'),
      );
      expect(keys, isNotEmpty);
      for (final key in keys) {
        if (key == 'termsTitle' || key == 'termsContinue') continue;
        expect(text, contains(strings[key] as String), reason: key);
      }
      expect(text, contains('$version $currentTermsVersion '));
    });
  }
}

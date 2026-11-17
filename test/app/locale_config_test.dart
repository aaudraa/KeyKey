import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Android 13 ve üstünde uygulamanın dili sistem ayarlarından ayrıca
/// seçilebilir; listede arayüzün çevrildiği diller olmalı.
void main() {
  test('uygulama başına dil listesi çeviri dosyalarıyla aynı', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:localeConfig="@xml/locales_config"'));

    final config = File('android/app/src/main/res/xml/locales_config.xml')
        .readAsStringSync();
    final listed = RegExp('<locale android:name="([^"]+)"')
        .allMatches(config)
        .map((m) => m.group(1))
        .toSet();

    final translated = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .map((f) => RegExp(r'app_(\w+)\.arb$').firstMatch(f.path)?.group(1))
        .whereType<String>()
        .toSet();
    expect(translated, isNotEmpty);
    expect(listed, translated);
  });
}

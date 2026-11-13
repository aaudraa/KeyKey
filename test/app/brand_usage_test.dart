import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Turuncu yalnızca dört yerde: K logosu, "+" düğmesi, ekranın ana düğmesi
/// (tema) ve 2FA halkası (`resources/docs/tasarim-siyah-beyaz.md`).
void main() {
  test('turuncu yalnızca izinli dosyalarda kullanılıyor', () {
    final pattern = RegExp(r'\.brand\b|brandStroke|brandOrange|onBrand');
    final found = <String>{
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            pattern.hasMatch(file.readAsStringSync()))
          file.path.replaceAll(r'\', '/'),
    };
    expect(found, {
      'lib/app/theme.dart',
      'lib/app/ui/kk_glass.dart',
      'lib/app/ui/keykey_logo.dart',
      'lib/app/ui/glass_nav_bar.dart',
      'lib/features/authenticator/presentation/otp_ring.dart',
    });
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/app/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('QR okuyucunun gömülü kitaplıklarının lisansları kayıtlı', () async {
    registerDataLicenses();

    final entries = await LicenseRegistry.licenses.toList();
    String textOf(String package) => entries
        .where((entry) => entry.packages.contains(package))
        .expand((entry) => entry.paragraphs)
        .map((paragraph) => paragraph.text)
        .join('\n');

    expect(textOf('zxing-cpp'), contains('Apache License'));
    expect(textOf('zint'), contains('Robin Stuart'));
    expect(textOf('EFF Large Wordlist'), contains('CC BY 3.0'));
    expect(textOf('Public Suffix List'), contains('Mozilla Public License'));
  });
}

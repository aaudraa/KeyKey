import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Paketlerle gelmeyen, uygulamaya veri olarak giren kaynakların lisansları.
///
/// Flutter paket lisanslarını kendisi ekler. Sözcük listeleri paket olmadığı
/// için burada elle eklenir, EFF listesi atıf istiyor. flutter_zxing'in
/// içine gömülü C++ kitaplıkları da paketin lisansında yazmadığı için
/// buradadır.
void registerDataLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['EFF Large Wordlist'],
      'EFF Large Wordlist for Passphrases\n'
      'Electronic Frontier Foundation, https://www.eff.org/dice\n\n'
      'Licensed under the Creative Commons Attribution 3.0 Unported License '
      '(CC BY 3.0), https://creativecommons.org/licenses/by/3.0/\n\n'
      'Used unchanged as the word list for passphrases.',
    );
    yield const LicenseEntryWithLineBreaks(['SecLists'], _secListsMit);
    for (final (name, path) in _embeddedNative) {
      yield LicenseEntryWithLineBreaks([
        'flutter_zxing',
        name,
      ], await rootBundle.loadString(path));
    }
  });
}

/// QR okuyucunun derlenen C++ kitaplıkları ve lisans metinleri.
const _embeddedNative = [
  ('zxing-cpp', 'resources/assets/licenses/zxing-cpp.txt'),
  ('zint', 'resources/assets/licenses/zint.txt'),
];

const _secListsMit = '''
MIT License

Copyright (c) 2018 Daniel Miessler

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Used as the list of common passwords: 10k-most-common.txt.
''';

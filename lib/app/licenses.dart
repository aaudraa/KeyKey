import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Paketlerle gelmeyen, uygulamaya veri olarak giren kaynakların lisansları.
///
/// Flutter paket lisanslarını kendisi ekler. Sözcük listeleri paket olmadığı
/// için burada elle eklenir, EFF listesi atıf istiyor. Public Suffix List
/// otomatik doldurmada alan adlarını karşılaştırmak için gömülüdür.
/// flutter_zxing'in içine gömülü C++ kitaplıkları da paketin lisansında
/// yazmadığı için buradadır.
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
    yield const LicenseEntryWithLineBreaks(
      ['Public Suffix List'],
      'Public Suffix List, https://publicsuffix.org/\n\n'
      'This Source Code Form is subject to the terms of the Mozilla Public '
      'License, v. 2.0. If a copy of the MPL was not distributed with this '
      'file, You can obtain one at https://mozilla.org/MPL/2.0/.\n\n'
      'Embedded unchanged; used by autofill to compare website domains. '
      'The source is resources/assets/autofill/public_suffix_list.dat in '
      'the KeyKey repository.',
    );
    for (final (name, path) in _embeddedNative) {
      yield LicenseEntryWithLineBreaks([
        'flutter_zxing',
        name,
      ], await rootBundle.loadString(path));
    }
    yield const LicenseEntryWithLineBreaks(
      ['SQLite'],
      'SQLite, https://sqlite.org/\n\n'
      'The SQLite source code is in the public domain '
      '(https://sqlite.org/copyright.html). The sqlite3 package bundles a '
      'build of it as the database engine.',
    );
    final apache = await rootBundle.loadString(_apacheLicense);
    yield LicenseEntryWithLineBreaks([
      'Android libraries',
    ], '$_androidLibraries\n\n$apache');
  });
}

const _apacheLicense = 'resources/assets/licenses/apache-2.0.txt';

/// Gradle'dan gelen Android kütüphaneleri. Flutter yalnızca Dart
/// paketlerinin lisanslarını toplar; bunlar elle eklenir. Liste ve
/// lisansları resources/docs/bagimliliklar.md'de.
const _androidLibraries = '''
The Android part of KeyKey and its Flutter plugins use these libraries, all
licensed under the Apache License, Version 2.0:

AndroidX (Android Jetpack), The Android Open Source Project
Kotlin standard library and kotlinx.coroutines, kotlinx.atomicfu, JetBrains
Guava, Dagger, Error Prone annotations, AutoValue annotations, Google
J2ObjC annotations, Google
JetBrains Java annotations, JetBrains
JSpecify annotations, The JSpecify Authors
javax.inject, The JSR-330 Expert Group
Jakarta Dependency Injection, Eclipse Foundation
ReLinker, KeepSafe Software''';

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

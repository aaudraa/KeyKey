import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// KeyKey'in internet izni yalnızca sızıntı kontrolü için. Ağ kodu tek bir
/// dosyada durur; başka bir yerde ağ kodu görünürse bu test kırılır ve
/// bilinçli bir karar ister (güvenlik tasarımı, "Ağ").
const _allowed = 'lib/core/network/pwned_passwords_client.dart';

final _patterns = [
  RegExp(
    r'\b(HttpClient|HttpServer|WebSocket|RawSocket|SecureSocket|Socket|'
    r'RawDatagramSocket|HttpURLConnection|URLConnection)\b',
  ),
  RegExp('package:http/'),
  RegExp(r'java\.net\.URL\b'),
  RegExp('okhttp', caseSensitive: false),
];

/// Ağ kodu içeren satırlar, `yol:satır` biçiminde.
List<String> networkLines(String path, String text) => [
  for (final (index, line) in text.split('\n').indexed)
    if (_patterns.any((pattern) => pattern.hasMatch(line)))
      '$path:${index + 1}',
];

Iterable<File> _sources(String root, String extension) =>
    Directory(root)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith(extension));

void main() {
  test('denetleyici ağ kodunu yakalar', () {
    expect(networkLines('a.dart', 'final c = HttpClient();'), ['a.dart:1']);
    expect(networkLines('a.dart', "import 'package:http/http.dart';"), [
      'a.dart:1',
    ]);
    expect(networkLines('A.kt', 'val u = java.net.URL(s)'), ['A.kt:1']);
    expect(networkLines('A.kt', 'import okhttp3.OkHttpClient'), ['A.kt:1']);
    expect(
      networkLines('A.kt', 'val c = url.openConnection() as HttpURLConnection'),
      ['A.kt:1'],
    );
    expect(networkLines('a.dart', 'final socketless = 1;'), isEmpty);
  });

  test('ağ kodu yalnızca Pwned Passwords istemcisinde', () {
    final found = <String>[];
    for (final file in [
      ..._sources('lib', '.dart'),
      ..._sources('android/app/src/main', '.kt'),
    ]) {
      final path = file.path.replaceAll(r'\', '/');
      if (path == _allowed) continue;
      found.addAll(networkLines(path, file.readAsStringSync()));
    }
    expect(found, isEmpty);
    expect(File(_allowed).existsSync(), isTrue);
  });
}

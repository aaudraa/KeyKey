import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// KeyKey'in ağ trafiği sızıntı kontrolü, senkron ve uygulama ile site
/// eşleştirmesi için. Ağ kodu yalnızca bu üç dosyada durur; başka bir yerde
/// ağ kodu görünürse bu test kırılır ve bilinçli bir karar ister (güvenlik
/// tasarımı, "Ağ").
const _allowed = {
  'lib/core/network/asset_links_client.dart',
  'lib/core/network/pwned_passwords_client.dart',
  'lib/core/network/webdav_client.dart',
};

/// İzin verilen dosyalar dışındaki ağ kodu satırları.
List<String> disallowedLines(Map<String, String> sources) => [
  for (final MapEntry(key: path, value: text) in sources.entries)
    if (!_allowed.contains(path)) ...networkLines(path, text),
];

final _patterns = [
  RegExp(
    r'\b(HttpClient|HttpServer|WebSocket|RawSocket|SecureSocket|Socket|'
    'RawDatagramSocket|HttpURLConnection|HttpsURLConnection|URLConnection|'
    r'NetworkImage|NetworkAssetBundle|InternetAddress)\b',
  ),
  // Dart paketleri ve Flutter'ın ağdan resim yükleyen kısayolu.
  RegExp('package:(http|dio)/'),
  RegExp("'dart:html'"),
  RegExp(r'\bImage\.network\b'),
  // Kotlin ve Java: java.net ve javax.net'in her şeyi, URL nesnesi,
  // bağlantı açma.
  RegExp(r'\bjavax?\.net\.'),
  RegExp(r'\bURL\('),
  RegExp(r'\.openConnection\('),
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

/// Taranan kaynaklar: uygulamanın Dart kodu ve Android'in Kotlin ve Java
/// kodu, `/` ayraçlı yollarla.
List<String> auditedSources() => [
  for (final file in [
    ..._sources('lib', '.dart'),
    ..._sources('android/app/src/main', '.kt'),
    ..._sources('android/app/src/main', '.java'),
  ])
    file.path.replaceAll(r'\', '/'),
];

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

  test('denetleyici öteki ağ yollarını da yakalar', () {
    for (final (path, line) in [
      ('A.kt', 'val c = URI(s).toURL().openConnection() as HttpsURLConnection'),
      ('A.kt', 'import java.net.*'),
      ('A.kt', 'val text = URL(s).readText()'),
      ('A.java', 'import javax.net.ssl.SSLSocketFactory;'),
      ('a.dart', "Image.network('https://example.com/a.png')"),
      ('a.dart', 'const image = NetworkImage(url);'),
      ('a.dart', 'final bundle = NetworkAssetBundle(base);'),
      ('a.dart', 'await InternetAddress.lookup(host);'),
      ('a.dart', "import 'package:dio/dio.dart';"),
      ('a.dart', "import 'dart:html';"),
    ]) {
      expect(networkLines(path, line), ['$path:1'], reason: line);
    }
    // Ağ olmayan, benzer adlı şeyler yakalanmaz.
    for (final line in [
      'final networkPolicy = 1;',
      "const url = 'https://example.com';",
      'openWebPage(context, ref, uri);',
    ]) {
      expect(networkLines('a.dart', line), isEmpty, reason: line);
    }
  });

  test('Java kaynakları da taranır', () {
    expect(auditedSources().any((path) => path.endsWith('.java')), isTrue);
  });

  test('izin verilen dosyalar dışındaki ağ kodu yakalanır', () {
    const line = 'final c = HttpClient();';
    expect(
      disallowedLines({
        'lib/core/network/pwned_passwords_client.dart': line,
        'lib/core/network/webdav_client.dart': line,
        'lib/features/sync/data/other.dart': line,
      }),
      ['lib/features/sync/data/other.dart:1'],
    );
  });

  test(
    'ağ kodu yalnızca sızıntı kontrolü, senkron ve assetlinks istemcisinde',
    () {
      final found = disallowedLines({
        for (final path in auditedSources())
          path: File(path).readAsStringSync(),
      });
      expect(found, isEmpty);
      for (final path in _allowed) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    },
  );
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/network/asset_links_client.dart';

void main() {
  late HttpServer server;
  late List<HttpRequest> requests;
  late FutureOr<void> Function(HttpRequest) handler;

  setUp(() async {
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..listen((request) async {
        requests.add(request);
        await handler(request);
      });
  });

  tearDown(() => server.close(force: true));

  AssetLinksClient client({Duration timeout = const Duration(seconds: 5)}) =>
      AssetLinksClient(
        locate: (host) => Uri.parse(
          'http://127.0.0.1:${server.port}/$host/.well-known/assetlinks.json',
        ),
        requestTimeout: timeout,
      );

  test('200 gövdesini verir, User-Agent KeyKey', () async {
    handler = (request) async {
      request.response.write('[]');
      await request.response.close();
    };
    expect(await client().fetch('github.com'), '[]');
    expect(requests.single.uri.path, '/github.com/.well-known/assetlinks.json');
    expect(requests.single.headers.value('user-agent'), 'KeyKey');
  });

  test('yönlendirme izlenmez', () async {
    handler = (request) async {
      if (request.uri.path.startsWith('/hedef')) {
        request.response.write('[]');
      } else {
        request.response
          ..statusCode = HttpStatus.movedPermanently
          ..headers.set('location', '/hedef');
      }
      await request.response.close();
    };
    expect(await client().fetch('github.com'), isNull);
    expect(requests, hasLength(1));
  });

  test('200 dışı yanıt null', () async {
    handler = (request) async {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    };
    expect(await client().fetch('github.com'), isNull);
  });

  test('128 KiB üstü gövde null', () async {
    handler = (request) async {
      request.response.write('a' * (AssetLinksClient.maxResponseBytes + 1));
      await request.response.close();
    };
    expect(await client().fetch('github.com'), isNull);
  });

  test('sıkıştırma istenmez, sıkıştırılmış yanıt reddedilir', () async {
    handler = (request) async {
      request.response
        ..headers.set('content-encoding', 'gzip')
        ..add(gzip.encode(utf8.encode('[]')));
      await request.response.close();
    };
    expect(await client().fetch('github.com'), isNull);
    expect(requests.single.headers.value('accept-encoding'), 'identity');
  });

  test('zaman aşımında null', () async {
    final release = Completer<void>();
    handler = (request) async {
      await release.future;
      await request.response.close();
    };
    expect(
      await client(timeout: const Duration(milliseconds: 200)).fetch('a.com'),
      isNull,
    );
    release.complete();
  });

  test('IP adresi, port ve geçersiz ad için ağa çıkılmaz', () async {
    handler = (request) => request.response.close();
    for (final host in [
      '1.2.3.4',
      'a.com:8443',
      '[::1]',
      'a.com/x',
      'Kötü site.com',
      '',
    ]) {
      expect(await client().fetch(host), isNull, reason: host);
    }
    expect(requests, isEmpty);
  });

  test('varsayılan adres https', () {
    expect(
      AssetLinksClient.defaultLocate('github.com'),
      Uri.parse('https://github.com/.well-known/assetlinks.json'),
    );
  });

  test('https dışı adres reddedilir, ağa çıkılmaz', () async {
    handler = (request) => request.response.close();
    final insecure = AssetLinksClient(
      locate: (host) => Uri.parse('http://$host/.well-known/assetlinks.json'),
    );
    expect(await insecure.fetch('example.com'), isNull);
    expect(requests, isEmpty);
  });
}

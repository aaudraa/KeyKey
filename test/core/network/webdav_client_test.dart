import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/network/sync_transport.dart';
import 'package:keykey/core/network/webdav_client.dart';

/// Bellekte dosya tutan küçük bir WebDAV sunucusu. İstemci yalnızca bu
/// cihazdaki test sunucusuna şifresiz bağlanabilir.
final class _FakeDav {
  final files = <String, Uint8List>{};
  final requests = <({String method, String path, HttpHeaders headers})>[];

  /// Verilirse her isteğe bu durum koduyla yanıt verilir.
  int? forceStatus;

  /// PROPFIND yanıtı; verilmezse [files]'tan üretilir.
  String? propfindBody;
  int moveStatus = HttpStatus.created;
  bool corruptReads = false;
  Duration delay = Duration.zero;
  bool folderExists = true;

  late HttpServer _server;

  int get port => _server.port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..listen(_handle);
  }

  Future<void> stop() => _server.close(force: true);

  static const folderPath = '/dav/Key Kasa/';

  Future<void> _handle(HttpRequest request) async {
    final path = Uri.decodeFull(request.uri.path);
    requests.add((
      method: request.method,
      path: path,
      headers: request.headers,
    ));
    final body = BytesBuilder(copy: false);
    await request.forEach(body.add);
    final response = request.response;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final forced = forceStatus;
    if (forced != null) {
      response.statusCode = forced;
      if (forced >= 300 && forced < 400) {
        response.headers.set(HttpHeaders.locationHeader, '/baska/');
      }
      await response.close();
      return;
    }
    final name = path.startsWith(folderPath)
        ? path.substring(folderPath.length)
        : null;
    switch (request.method) {
      case 'PROPFIND':
        if (!folderExists) {
          response.statusCode = HttpStatus.notFound;
        } else {
          response
            ..statusCode = 207
            ..headers.contentType = ContentType('application', 'xml')
            ..write(propfindBody ?? _listing());
        }
      case 'MKCOL':
        folderExists = true;
        response.statusCode = HttpStatus.created;
      case 'PUT':
        files[name!] = body.takeBytes();
        response.statusCode = HttpStatus.created;
      case 'GET':
        final data = files[name];
        if (data == null) {
          response.statusCode = HttpStatus.notFound;
        } else {
          response.add(corruptReads ? [...data.reversed, 0] : data);
        }
      case 'MOVE':
        if (moveStatus != HttpStatus.created) {
          response.statusCode = moveStatus;
        } else {
          final target = Uri.decodeFull(
            Uri.parse(request.headers.value('destination')!).path,
          ).substring(folderPath.length);
          files[target] = files.remove(name)!;
          response.statusCode = HttpStatus.created;
        }
      case 'DELETE':
        response.statusCode = files.remove(name) == null
            ? HttpStatus.notFound
            : HttpStatus.noContent;
      default:
        response.statusCode = HttpStatus.methodNotAllowed;
    }
    await response.close();
  }

  String _listing() =>
      '''
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:">
<d:response><d:href>/dav/Key%20Kasa/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
${[for (final e in files.entries) '<d:response><d:href>/dav/Key%20Kasa/${Uri.encodeComponent(e.key)}</d:href><d:propstat><d:prop><d:resourcetype/><d:getcontentlength>${e.value.length}</d:getcontentlength></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>'].join('\n')}
</d:multistatus>''';
}

void main() {
  late _FakeDav dav;

  setUp(() async {
    dav = _FakeDav();
    await dav.start();
  });

  tearDown(() => dav.stop());

  Uri folder() => Uri.parse('http://127.0.0.1:${dav.port}/dav/Key%20Kasa/');

  WebDavClient client({
    Duration requestTimeout = const Duration(seconds: 60),
    int maxListBytes = WebDavClient.defaultMaxListBytes,
    int maxFileBytes = WebDavClient.defaultMaxFileBytes,
  }) => WebDavClient(
    folder: folder(),
    username: 'ayse',
    password: 'gizli-uygulama-parolasi',
    requestTimeout: requestTimeout,
    maxListBytes: maxListBytes,
    maxFileBytes: maxFileBytes,
  );

  Uint8List bytes(int n) => Uint8List.fromList(List.generate(n, (i) => i));

  Matcher fails(SyncFailureKind kind) => throwsA(
    isA<SyncTransportException>().having((e) => e.kind, 'kind', kind),
  );

  group('liste', () {
    for (final server in ['nextcloud', 'apache', 'rclone']) {
      test('$server yanıtı yalnızca senkron dosyalarını veriyor', () async {
        dav.propfindBody = File(
          'test/core/network/fixtures/propfind_$server.xml',
        ).readAsStringSync();

        final files = await client().list();

        final sorted = [...files]..sort((a, b) => a.name.compareTo(b.name));
        expect(
          [for (final f in sorted) f.name],
          ['keykey-sync-0f0f0f.keykey', 'keykey-sync-a1b2c3.keykey'],
        );
        expect([for (final f in sorted) f.size], [300, 200]);
        expect([for (final f in sorted) f.etag], ['"e2"', '"e1"']);
        expect(sorted.last.modified, DateTime.utc(2026, 11, 20, 9));
        final request = dav.requests.single;
        expect(request.method, 'PROPFIND');
        expect(request.headers.value('depth'), '1');
        expect(request.path, _FakeDav.folderPath);
      });
    }

    test('adı UTF-8 olmayan başka bir dosya listeyi bozmuyor', () async {
      // N7: Latin-1 bir sistemden gelen "café.txt" (caf%E9) çözülürken
      // FormatException fırlıyor, kurulum ve senkron kalıcı olarak düşüyordu.
      dav.propfindBody = '''
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:">
<d:response><d:href>/dav/Key%20Kasa/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
<d:response><d:href>/dav/Key%20Kasa/caf%E9.txt</d:href><d:propstat><d:prop><d:resourcetype/><d:getcontentlength>3</d:getcontentlength></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
<d:response><d:href>/dav/Key%20Kasa/keykey-sync-a1b2c3.keykey</d:href><d:propstat><d:prop><d:resourcetype/><d:getcontentlength>200</d:getcontentlength></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
</d:multistatus>''';

      final files = await client().list();

      expect([for (final f in files) f.name], ['keykey-sync-a1b2c3.keykey']);
    });

    test('klasör yoksa oluşturuluyor', () async {
      dav.folderExists = false;
      await client().ensureFolder();
      expect([for (final r in dav.requests) r.method], ['PROPFIND', 'MKCOL']);

      dav.requests.clear();
      await client().ensureFolder();
      expect([for (final r in dav.requests) r.method], ['PROPFIND']);
    });
  });

  group('yazma', () {
    const name = 'keykey-sync-a1b2c3.keykey';

    test('ara dosyaya yazıp geri okuyor, sonra taşıyor', () async {
      await client().write(name, bytes(1000));

      // Nextcloud ve ownCloud `.part` uzantısını yarım yükleme sayıp dosya
      // önbelleğine almıyor; ara ad bu yüzden `.tmp`.
      expect(
        [for (final r in dav.requests) (r.method, r.path)],
        [
          ('PUT', '${_FakeDav.folderPath}$name.tmp'),
          ('GET', '${_FakeDav.folderPath}$name.tmp'),
          ('MOVE', '${_FakeDav.folderPath}$name.tmp'),
        ],
      );
      final move = dav.requests.last.headers;
      expect(
        move.value('destination'),
        'http://127.0.0.1:${dav.port}/dav/Key%20Kasa/$name',
      );
      expect(move.value('overwrite'), 'T');
      expect(dav.files.keys, [name]);
      expect(dav.files[name], bytes(1000));
      expect(await client().read(name), bytes(1000));
    });

    test('sunucu taşımayı desteklemezse doğrudan yazıyor', () async {
      for (final status in [
        HttpStatus.methodNotAllowed,
        HttpStatus.notImplemented,
      ]) {
        dav
          ..moveStatus = status
          ..requests.clear()
          ..files.clear();

        await client().write(name, bytes(10));

        expect(
          [for (final r in dav.requests) r.method],
          ['PUT', 'GET', 'MOVE', 'PUT', 'DELETE'],
        );
        expect(dav.files.keys, [name]);
        expect(dav.files[name], bytes(10));
      }
    });

    test('geri okunan farklıysa ara dosya siliniyor', () async {
      dav.corruptReads = true;

      await expectLater(
        client().write(name, bytes(10)),
        fails(SyncFailureKind.badResponse),
      );
      expect(
        [for (final r in dav.requests) r.method],
        ['PUT', 'GET', 'DELETE'],
      );
      expect(dav.files, isEmpty);
    });

    test('silme olmayan dosyada sorun çıkarmıyor', () async {
      dav.files[name] = bytes(3);
      await client().delete(name);
      await client().delete(name);
      expect(dav.files, isEmpty);
    });
  });

  group('hatalar', () {
    test('durum kodları türlere ayrılıyor', () async {
      for (final (status, kind) in [
        (HttpStatus.unauthorized, SyncFailureKind.unauthorized),
        (HttpStatus.forbidden, SyncFailureKind.unauthorized),
        (HttpStatus.notFound, SyncFailureKind.notFound),
        (HttpStatus.found, SyncFailureKind.redirect),
        (HttpStatus.movedPermanently, SyncFailureKind.redirect),
        (HttpStatus.temporaryRedirect, SyncFailureKind.redirect),
        (507, SyncFailureKind.insufficientStorage),
        (HttpStatus.internalServerError, SyncFailureKind.server),
        (HttpStatus.serviceUnavailable, SyncFailureKind.server),
      ]) {
        dav
          ..forceStatus = status
          ..requests.clear();
        await expectLater(
          client().read('keykey-sync-a1b2c3.keykey'),
          fails(kind),
          reason: '$status',
        );
        // Yönlendirme izlenmez: ikinci istek gitmez.
        expect(dav.requests, hasLength(1), reason: '$status');
      }
    });

    test('zaman aşımı ve kapalı sunucu bağlantı yok sayılıyor', () async {
      dav.delay = const Duration(seconds: 2);
      await expectLater(
        client(requestTimeout: const Duration(milliseconds: 200)).list(),
        fails(SyncFailureKind.offline),
      );

      final closed = WebDavClient(
        folder: Uri.parse('http://127.0.0.1:1/dav/'),
        username: 'ayse',
        password: 'p',
      );
      await expectLater(closed.list(), fails(SyncFailureKind.offline));
    });

    test('büyük yanıt okunmuyor', () async {
      dav.files['keykey-sync-a1b2c3.keykey'] = bytes(2000);
      await expectLater(
        client(maxListBytes: 100).list(),
        fails(SyncFailureKind.tooLarge),
      );
      await expectLater(
        client(maxFileBytes: 1000).read('keykey-sync-a1b2c3.keykey'),
        fails(SyncFailureKind.tooLarge),
      );
    });

    test('hata mesajı yol ve kimlik bilgisi taşımıyor', () async {
      dav.forceStatus = HttpStatus.unauthorized;
      try {
        await client().list();
        fail('hata bekleniyordu');
      } on SyncTransportException catch (error) {
        final text = error.toString();
        for (final secret in ['ayse', 'gizli', 'Kasa', 'dav', '127.0.0.1']) {
          expect(text, isNot(contains(secret)));
        }
      }
    });
  });

  group('güvenlik', () {
    test('şifresiz uzak adres reddediliyor, yerel kabul ediliyor', () {
      for (final bad in [
        'http://example.com/dav/',
        'ftp://example.com/dav/',
        'https://ayse:p@example.com/dav/',
        'https:///dav/',
      ]) {
        expect(
          () => WebDavClient(
            folder: Uri.parse(bad),
            username: 'ayse',
            password: 'p',
          ),
          throwsArgumentError,
          reason: bad,
        );
      }
      WebDavClient(
        folder: Uri.parse('http://127.0.0.1:8080/dav/'),
        username: 'ayse',
        password: 'p',
      );
      WebDavClient(
        folder: Uri.parse('https://bulut.example.com/dav/'),
        username: 'ayse',
        password: 'p',
      );
    });

    test('her istekte Basic kimlik ve KeyKey tanıtımı', () async {
      final expected =
          'Basic ${base64.encode(utf8.encode('ayse:gizli-uygulama-parolasi'))}';
      await client().ensureFolder();
      await client().write('keykey-sync-a1b2c3.keykey', bytes(5));
      await client().list();
      await client().delete('keykey-sync-a1b2c3.keykey');

      expect(dav.requests, hasLength(greaterThan(5)));
      for (final request in dav.requests) {
        expect(request.headers.value('authorization'), expected);
        expect(request.headers.value('user-agent'), 'KeyKey');
        expect(request.headers.value('cookie'), isNull);
      }
    });

    test('klasör adresi eğik çizgisiz de verilebiliyor', () async {
      final noSlash = WebDavClient(
        folder: Uri.parse('http://127.0.0.1:${dav.port}/dav/Key%20Kasa'),
        username: 'ayse',
        password: 'p',
      );
      await noSlash.write('keykey-sync-a1b2c3.keykey', bytes(4));
      expect(dav.files.keys, ['keykey-sync-a1b2c3.keykey']);
      expect(
        [for (final f in await noSlash.list()) f.name],
        ['keykey-sync-a1b2c3.keykey'],
      );
    });
  });
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keykey/core/network/pwned_passwords_client.dart';

/// İstemci yerel bir test sunucusuna karşı denenir; uygulamada adres sabit.
void main() {
  late HttpServer server;
  late List<HttpRequest> requests;
  late Future<void> Function(HttpRequest request) respond;

  setUp(() async {
    requests = [];
    respond = (request) async {
      request.response.write('OK');
      await request.response.close();
    };
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..listen((request) async {
        requests.add(request);
        await respond(request);
      });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  PwnedPasswordsClient client({
    Duration requestTimeout = const Duration(seconds: 30),
  }) => PwnedPasswordsClient(
    baseUri: Uri.parse('http://127.0.0.1:${server.port}/range/'),
    requestTimeout: requestTimeout,
  );

  test('sorgu yalnızca öneki gönderir', () async {
    respond = (request) async {
      request.response.write('1E4C9B93F3F0682250B6CF8331B7EE68FD8:3\r\n');
      await request.response.close();
    };

    final body = await client().fetchRange('5BAA6');

    expect(body, '1E4C9B93F3F0682250B6CF8331B7EE68FD8:3\r\n');
    expect(requests, hasLength(1));
    final request = requests.single;
    expect(request.method, 'GET');
    expect(request.uri.path, '/range/5BAA6');
    expect(request.uri.query, isEmpty);
    expect(request.headers.value('add-padding'), 'true');
    expect(request.headers.value('user-agent'), 'KeyKey');
  });

  test('geçersiz önek ağa çıkmaz', () async {
    for (final prefix in ['5baa6', '5BAA', '5BAA61', '5BA/6', '', '5BAA6?']) {
      await expectLater(
        client().fetchRange(prefix),
        throwsA(isA<ArgumentError>()),
        reason: prefix,
      );
    }
    expect(requests, isEmpty);
  });

  test('yönlendirme izlenmez', () async {
    respond = (request) async {
      request.response
        ..statusCode = HttpStatus.found
        ..headers.set(HttpHeaders.locationHeader, '/range/ABCDE');
      await request.response.close();
    };

    await expectLater(
      client().fetchRange('5BAA6'),
      throwsA(isA<PwnedPasswordsException>()),
    );
    expect(requests, hasLength(1));
  });

  test('başarısız yanıt hata', () async {
    respond = (request) async {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
    };

    await expectLater(
      client().fetchRange('5BAA6'),
      throwsA(isA<PwnedPasswordsException>()),
    );
  });

  test("1 MiB'ı aşan yanıt reddedilir", () async {
    respond = (request) async {
      request.response.add(List.filled(1024 * 1024 + 1, 0x41));
      await request.response.close();
    };

    await expectLater(
      client().fetchRange('5BAA6'),
      throwsA(isA<PwnedPasswordsException>()),
    );
  });

  test('tam 1 MiB yanıt okunur', () async {
    respond = (request) async {
      request.response.add(List.filled(1024 * 1024, 0x41));
      await request.response.close();
    };

    expect(await client().fetchRange('5BAA6'), hasLength(1024 * 1024));
  });

  test('zaman aşımı hata', () async {
    final hold = Completer<void>();
    respond = (request) => hold.future;
    addTearDown(hold.complete);

    await expectLater(
      client(requestTimeout: const Duration(milliseconds: 200))
          .fetchRange('5BAA6'),
      throwsA(isA<PwnedPasswordsException>()),
    );
  });

  test('bağlanamayınca hata', () async {
    final port = server.port;
    await server.close(force: true);
    final closed = PwnedPasswordsClient(
      baseUri: Uri.parse('http://127.0.0.1:$port/range/'),
    );

    await expectLater(
      closed.fetchRange('5BAA6'),
      throwsA(isA<PwnedPasswordsException>()),
    );
  });

  test('uygulamadaki adres Pwned Passwords', () {
    expect(
      PwnedPasswordsClient.defaultBaseUri.toString(),
      'https://api.pwnedpasswords.com/range/',
    );
  });
}

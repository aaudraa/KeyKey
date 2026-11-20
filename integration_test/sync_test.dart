import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/network/webdav_client.dart';
import 'package:keykey/core/storage/vault_database.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/vault_service.dart';
import 'package:keykey/core/vault/vault_session.dart';
import 'package:keykey/features/settings/data/app_settings.dart';
import 'package:keykey/features/sync/application/sync_service.dart';
import 'package:keykey/features/vault/data/login_content.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium_sumo.dart';

/// Telefonda, bu cihazın kendi adresinde çalışan küçük bir WebDAV sunucusu.
/// Gerçek istemci, gerçek SQLite ve libsodium ile senkronu sınar.
final class _Dav {
  final files = <String, ({Uint8List bytes, int etag})>{};
  var _counter = 0;
  late HttpServer _server;

  static const folder = '/keykey/';

  int get port => _server.port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..listen(_handle);
  }

  Future<void> stop() => _server.close(force: true);

  void put(String name, Uint8List bytes) =>
      files[name] = (bytes: bytes, etag: ++_counter);

  Future<void> _handle(HttpRequest request) async {
    final path = Uri.decodeFull(request.uri.path);
    final body = BytesBuilder(copy: false);
    await request.forEach(body.add);
    final response = request.response;
    final name = path.startsWith(folder) ? path.substring(folder.length) : '';
    switch (request.method) {
      case 'PROPFIND':
        response
          ..statusCode = 207
          ..headers.contentType = ContentType('application', 'xml')
          ..write(_listing());
      case 'MKCOL':
        response.statusCode = HttpStatus.methodNotAllowed;
      case 'PUT':
        put(name, body.takeBytes());
        response.statusCode = HttpStatus.created;
      case 'GET':
        final file = files[name];
        if (file == null) {
          response.statusCode = HttpStatus.notFound;
        } else {
          response.add(file.bytes);
        }
      case 'MOVE':
        final target = Uri.decodeFull(
          Uri.parse(request.headers.value('destination')!).path,
        ).substring(folder.length);
        final moved = files.remove(name)!;
        put(target, moved.bytes);
        response.statusCode = HttpStatus.created;
      case 'DELETE':
        response.statusCode = files.remove(name) == null
            ? HttpStatus.notFound
            : HttpStatus.noContent;
      default:
        response.statusCode = HttpStatus.methodNotAllowed;
    }
    await response.close();
  }

  String _listing() {
    final entries = [
      for (final MapEntry(:key, :value) in files.entries)
        _entry(
          '$folder${Uri.encodeComponent(key)}',
          '<d:resourcetype/>'
              '<d:getcontentlength>${value.bytes.length}</d:getcontentlength>'
              '<d:getetag>"${value.etag}"</d:getetag>',
        ),
    ];
    return '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">'
        '${_entry(folder, '<d:resourcetype><d:collection/></d:resourcetype>')}'
        '${entries.join()}</d:multistatus>';
  }

  static String _entry(String href, String props) => [
    '<d:response><d:href>$href</d:href><d:propstat><d:prop>$props</d:prop>',
    '<d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>',
  ].join();
}

final class _Phone {
  new(this.database, this.store, this.session, this.service, this.settings);

  final VaultDatabase database;
  final VaultStore store;
  final VaultSession session;
  final SyncService service;
  SyncSettings settings;
  final cache = SyncCache();

  Future<SyncResult> sync() async {
    final result = await service.sync(session, settings, cache: cache);
    settings = settings.withLastSync(result.at, result.digest);
    return result;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SodiumSumo sodium;
  late _Dav dav;
  late Directory directory;
  final phones = <_Phone>[];

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
  });

  setUp(() async {
    dav = _Dav();
    await dav.start();
    final support = await getApplicationSupportDirectory();
    directory = support.createTempSync('senkron_testi_');
  });

  tearDown(() async {
    for (final phone in phones) {
      phone.session.dispose();
      await phone.database.close();
    }
    phones.clear();
    await dav.stop();
    directory.deleteSync(recursive: true);
  });

  Uint8List id(int n) => Uint8List(16)..[15] = n;

  _Phone phone(
    String device,
    VaultDatabase database,
    VaultStore store,
    VaultSession session,
  ) {
    final result = _Phone(
      database,
      store,
      session,
      SyncService(
        store: store,
        codec: BackupCodec(sodium),
        sodium: sodium,
        transport: (settings) => WebDavClient(
          folder: settings.folder,
          username: settings.username,
          password: settings.appPassword,
        ),
        device: device,
        deviceName: () async => 'Telefon $device',
        now: () => DateTime.now().toUtc(),
      ),
      SyncSettings(
        folder: Uri.parse('http://127.0.0.1:${dav.port}${_Dav.folder}'),
        username: 'ayse',
        appPassword: 'uygulama-parolasi',
      ),
    );
    phones.add(result);
    return result;
  }

  Future<_Phone> first(String device) async {
    final database = VaultDatabase.openFile(
      File('${directory.path}/$device.db'),
    );
    final store = VaultStore(database);
    final vaults = VaultService(sodium: sodium, store: store);
    final pending = await vaults.prepareVault('Ana-Parola-2026');
    final session = await vaults.confirmRecoveryKey(
      pending,
      pending.recoveryKeyText,
    );
    return phone(device, database, store, session);
  }

  Future<_Phone> second(_Phone other, String device) async {
    final database = VaultDatabase.openFile(
      File('${directory.path}/$device.db'),
    );
    final store = VaultStore(database);
    await store.createVault(other.session.header);
    final session = VaultService(sodium: sodium, store: store)
        .openRestoredSession(
          other.session.header,
          sodium.secureCopy(other.session.vaultKey.extractBytes()),
        );
    return phone(device, database, store, session);
  }

  Future<void> addLogin(_Phone phone, int n) {
    final now = DateTime.now().toUtc();
    return phone.store.putRecord(
      StoredRecord(
        id: id(n),
        type: 'login',
        blob: phone.session.records.encrypt(
          recordId: id(n),
          type: 'login',
          plainText: LoginContent(name: 'Site $n').toJsonBytes(),
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<List<int>> loginIds(_Phone phone) async => [
    for (final r in await phone.store.allRecords())
      if (r.type == 'login') r.id[15],
  ]..sort();

  test('iki telefonun kayıtları birleşiyor, silme taşınıyor', () async {
    final a = await first('a1b2c3');
    await addLogin(a, 1);
    final uploaded = await a.sync();
    expect(uploaded.uploaded, isTrue);
    expect(dav.files.keys, ['keykey-sync-a1b2c3.keykey']);

    final b = await second(a, 'b2c3d4');
    await addLogin(b, 2);
    await b.sync();
    expect(await loginIds(b), [1, 2]);

    await a.sync();
    expect(await loginIds(a), [1, 2]);

    // Saniye farkı: silme kaydının zamanı kaydınkinden yeni olsun.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await b.store.deleteRecord(id(1));
    await b.sync();
    await a.sync();
    expect(await loginIds(a), [2]);
    expect([for (final t in await a.store.allTombstones()) t.id[15]], [1]);

    // A'nın eski dosyası silinen kaydı B'ye geri getirmiyor.
    await b.sync();
    expect(await loginIds(b), [2]);
    expect(dav.files.keys.toList()..sort(), [
      'keykey-sync-a1b2c3.keykey',
      'keykey-sync-b2c3d4.keykey',
    ]);
  });

  test('yarım kalan yükleme görünmüyor', () async {
    final a = await first('a1b2c3');
    await addLogin(a, 1);
    await a.sync();
    final b = await second(a, 'b2c3d4');
    // Kesilmiş bir yazmanın ara dosyası klasörde kalmış.
    dav.put(
      'keykey-sync-a1b2c3.keykey.tmp',
      Uint8List.fromList(List.filled(64, 7)),
    );

    final result = await b.sync();

    expect(result.issues, isEmpty);
    expect([for (final d in result.devices) d.device]..sort(), [
      'a1b2c3',
      'b2c3d4',
    ]);
    expect(await loginIds(b), [1]);
  });
}

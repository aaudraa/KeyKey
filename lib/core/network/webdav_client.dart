import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:keykey/core/backup/backup_codec.dart';
import 'package:keykey/core/network/secure_url.dart';
import 'package:keykey/core/network/sync_transport.dart';
import 'package:xml/xml.dart';

/// Senkron klasörüyle konuşan WebDAV istemcisi.
///
/// Sunucuyla konuşan kod yalnızca bu dosyadadır; ağ denetim testi
/// (`test/core/network/network_audit_test.dart`) başka yerde ağ kodu
/// olmadığını denetler. Kurallar: `resources/docs/senkron.md`, "WebDAV
/// istemcisi".
///
/// Yalnızca https (bu telefonun kendi adresinde http); yönlendirme izlenmez,
/// çerez tutulmaz, her istekte Basic kimlik ve `User-Agent: KeyKey`.
final class WebDavClient implements SyncTransport {
  /// [folder] [isSecureServiceUrl] kuralına uymazsa [ArgumentError].
  new({
    required Uri folder,
    required String username,
    required String password,
    this.connectTimeout = const Duration(seconds: 10),
    this.requestTimeout = const Duration(seconds: 60),
    this.maxListBytes = defaultMaxListBytes,
    this.maxFileBytes = defaultMaxFileBytes,
  }) : _folder = _checked(folder),
       _authorization =
           'Basic ${base64.encode(utf8.encode('$username:$password'))}';

  /// Klasör listesi yanıtının sınırı.
  static const int defaultMaxListBytes = 1024 * 1024;

  /// Okunan dosyanın sınırı: yedek kapsayıcısının en büyük boyutu.
  static const int defaultMaxFileBytes = BackupCodec.maxFileSize;

  static const _filePrefix = 'keykey-sync-';
  static const _fileSuffix = '.keykey';

  /// Ara dosyanın eki. `.part` olamaz: Nextcloud ve ownCloud o uzantıyı
  /// yarım yükleme sayıp dosya önbelleğine almıyor (geri okuma ve taşıma
  /// bulamıyor).
  static const _partSuffix = '.tmp';
  static const _dav = 'DAV:';
  static const _propfindBody = '''
<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:getetag/>
    <d:getcontentlength/>
    <d:getlastmodified/>
    <d:resourcetype/>
  </d:prop>
</d:propfind>
''';

  final Uri _folder;
  final String _authorization;
  final Duration connectTimeout;
  final Duration requestTimeout;
  final int maxListBytes;
  final int maxFileBytes;

  /// Adres kuralı; yol eğik çizgiyle biter ki dosya adları klasörün içine
  /// çözülsün. Hata mesajı adresi taşımaz.
  static Uri _checked(Uri folder) {
    if (!isSecureServiceUrl(folder)) {
      throw ArgumentError('Güvenli olmayan senkron adresi');
    }
    final path = folder.path;
    return path.endsWith('/') ? folder : folder.replace(path: '$path/');
  }

  Uri _file(String name) => _folder.resolveUri(Uri(path: name));

  @override
  Future<void> ensureFolder() => _session((client) async {
    final found = await _send(
      client,
      'PROPFIND',
      _folder,
      headers: const {'Depth': '0'},
      body: utf8.encode(_propfindBody),
      ok: const {207},
      allowNotFound: true,
      readBody: false,
    );
    if (found.status != HttpStatus.notFound) return;
    await _send(
      client,
      'MKCOL',
      _folder,
      // 405: başka bir telefon bu arada oluşturdu.
      ok: const {HttpStatus.created, HttpStatus.methodNotAllowed},
    );
  });

  @override
  Future<List<RemoteFile>> list() => _session((client) async {
    final body = await _send(
      client,
      'PROPFIND',
      _folder,
      headers: const {'Depth': '1'},
      body: utf8.encode(_propfindBody),
      ok: const {207},
      limit: maxListBytes,
    );
    return _parseListing(body.body!);
  });

  @override
  Future<Uint8List> read(String name) => _session(
    (client) async => (await _send(
      client,
      'GET',
      _file(name),
      ok: const {HttpStatus.ok},
      limit: maxFileBytes,
    )).body!,
  );

  /// Önce `<ad>.tmp` yazılır, geri okunup bayt bayt karşılaştırılır, sonra
  /// son adına taşınır. Sunucu taşımayı desteklemiyorsa (405, 501) son adla
  /// doğrudan yazılır ve ara dosya silinir.
  @override
  Future<void> write(String name, Uint8List bytes) => _session((client) async {
    final part = _file('$name$_partSuffix');
    final target = _file(name);
    await _put(client, part, bytes);
    final back = await _send(
      client,
      'GET',
      part,
      ok: const {HttpStatus.ok},
      limit: maxFileBytes,
    );
    if (!_equal(back.body!, bytes)) {
      await _deleteQuietly(client, part);
      throw const SyncTransportException(SyncFailureKind.badResponse);
    }
    final moved = await _send(
      client,
      'MOVE',
      part,
      headers: {'Destination': target.toString(), 'Overwrite': 'T'},
      ok: const {
        HttpStatus.created,
        HttpStatus.noContent,
        HttpStatus.ok,
        HttpStatus.methodNotAllowed,
        HttpStatus.notImplemented,
      },
      readBody: false,
    );
    if (moved.status
        case HttpStatus.methodNotAllowed || HttpStatus.notImplemented) {
      await _put(client, target, bytes);
      await _deleteQuietly(client, part);
    }
  });

  @override
  Future<void> delete(String name) => _session((client) async {
    await _send(
      client,
      'DELETE',
      _file(name),
      ok: const {HttpStatus.ok, HttpStatus.noContent},
      allowNotFound: true,
    );
  });

  Future<void> _put(HttpClient client, Uri uri, Uint8List bytes) async {
    await _send(
      client,
      'PUT',
      uri,
      headers: const {'Content-Type': 'application/octet-stream'},
      body: bytes,
      ok: const {HttpStatus.ok, HttpStatus.created, HttpStatus.noContent},
      readBody: false,
    );
  }

  Future<void> _deleteQuietly(HttpClient client, Uri uri) async {
    try {
      await _send(
        client,
        'DELETE',
        uri,
        ok: const {HttpStatus.ok, HttpStatus.noContent},
        allowNotFound: true,
      );
    } on SyncTransportException {
      // Ara dosya kalırsa bir sonraki yazma üzerine yazar.
    }
  }

  /// Tek bir işlem için bir istemci açar, sonunda kapatır ve G/Ç hatalarını
  /// [SyncTransportException]'a çevirir.
  Future<T> _session<T>(Future<T> Function(HttpClient client) body) async {
    final client = HttpClient()
      ..connectionTimeout = connectTimeout
      ..userAgent = 'KeyKey'
      ..autoUncompress = true;
    try {
      return await body(client);
    } on SyncTransportException {
      rethrow;
    } on TimeoutException {
      throw const SyncTransportException(SyncFailureKind.offline);
    } on TlsException {
      // HandshakeException dahil: sertifikaya güvenilmedi.
      throw const SyncTransportException(SyncFailureKind.certificate);
    } on IOException {
      // SocketException, HttpException.
      throw const SyncTransportException(SyncFailureKind.offline);
    } finally {
      client.close(force: true);
    }
  }

  /// Bir istek gönderir. Durum [ok] içinde değilse (ya da [allowNotFound]
  /// iken 404 değilse) [SyncTransportException]. [readBody] ise gövde en çok
  /// [limit] bayt okunur; değilse ve 404'te gövde `null`.
  Future<({int status, Uint8List? body})> _send(
    HttpClient client,
    String method,
    Uri uri, {
    required Set<int> ok,
    Map<String, String> headers = const {},
    List<int>? body,
    int limit = 64 * 1024,
    bool allowNotFound = false,
    bool readBody = true,
  }) {
    Future<({int status, Uint8List? body})> run() async {
      final request = await client.openUrl(method, uri);
      request
        ..followRedirects = false
        ..maxRedirects = 0
        ..headers.set(HttpHeaders.authorizationHeader, _authorization);
      headers.forEach(request.headers.set);
      if (body != null) {
        request
          ..contentLength = body.length
          ..add(body);
      }
      final response = await request.close();
      final status = response.statusCode;
      final found = !(allowNotFound && status == HttpStatus.notFound);
      if (found && !ok.contains(status)) {
        await _discard(response);
        throw SyncTransportException(_kindOf(status));
      }
      if (!found || !readBody) {
        await _discard(response);
        return (status: status, body: null);
      }
      return (status: status, body: await _read(response, limit));
    }

    return run().timeout(requestTimeout);
  }

  static SyncFailureKind _kindOf(int status) => switch (status) {
    HttpStatus.unauthorized ||
    HttpStatus.forbidden => SyncFailureKind.unauthorized,
    // 409: üst klasör yok.
    HttpStatus.notFound || HttpStatus.conflict => SyncFailureKind.notFound,
    HttpStatus.requestEntityTooLarge => SyncFailureKind.tooLarge,
    507 => SyncFailureKind.insufficientStorage,
    >= 300 && < 400 => SyncFailureKind.redirect,
    >= 500 => SyncFailureKind.server,
    _ => SyncFailureKind.badResponse,
  };

  static Future<Uint8List> _read(HttpClientResponse response, int limit) async {
    if (response.contentLength > limit) {
      await _discard(response);
      throw const SyncTransportException(SyncFailureKind.tooLarge);
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (bytes.length + chunk.length > limit) {
        throw const SyncTransportException(SyncFailureKind.tooLarge);
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  /// Gövdeyi okumadan bağlantıyı bırakır.
  static Future<void> _discard(HttpClientResponse response) =>
      response.listen(null).cancel();

  static bool _equal(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// `multistatus` yanıtından klasörün doğrudan içindeki senkron dosyaları.
  /// `href` tam adres ya da yol olabilir; yüzde kodları çözülerek
  /// karşılaştırılır.
  List<RemoteFile> _parseListing(Uint8List body) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(utf8.decode(body));
    } on Exception {
      throw const SyncTransportException(SyncFailureKind.badResponse);
    }
    final folderPath = Uri.decodeFull(_folder.path);
    final files = <RemoteFile>[];
    for (final response in document.findAllElements(
      'response',
      namespaceUri: _dav,
    )) {
      final href = _text(response, 'href');
      if (href == null) continue;
      final Uri resolved;
      try {
        resolved = _folder.resolve(href);
      } on FormatException {
        continue;
      }
      final path = Uri.decodeFull(resolved.path);
      if (!path.startsWith(folderPath)) continue;
      final name = path.substring(folderPath.length);
      if (name.isEmpty ||
          name.contains('/') ||
          !name.startsWith(_filePrefix) ||
          !name.endsWith(_fileSuffix)) {
        continue;
      }
      final isCollection = response
          .findAllElements('collection', namespaceUri: _dav)
          .isNotEmpty;
      if (isCollection) continue;
      files.add(
        RemoteFile(
          name: name,
          etag: _text(response, 'getetag'),
          size: int.tryParse(_text(response, 'getcontentlength') ?? ''),
          modified: _date(_text(response, 'getlastmodified')),
        ),
      );
    }
    return files;
  }

  /// [parent] içindeki ilk boş olmayan DAV öğesinin metni.
  static String? _text(XmlElement parent, String name) {
    for (final element in parent.findAllElements(name, namespaceUri: _dav)) {
      final text = element.innerText.trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static DateTime? _date(String? value) {
    if (value == null) return null;
    try {
      return HttpDate.parse(value);
    } on HttpException {
      return null;
    } on FormatException {
      return null;
    }
  }
}

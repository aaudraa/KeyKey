import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Have I Been Pwned'ın Pwned Passwords aralık sorgusu.
///
/// KeyKey'in tek ağ kodu bu dosyadadır; başka bir yerde ağ kodu olmadığını
/// `test/core/network/network_audit_test.dart` denetler. Tasarım:
/// `resources/docs/internet-ve-sizinti.md`.
abstract interface class PwnedRangeSource {
  /// SHA-1 özetinin ilk 5 karakteri ([prefix], büyük harfli onaltılık) için
  /// yanıt gövdesi: `SONEK:SAYI` satırları.
  Future<String> fetchRange(String prefix);
}

/// Sorgu yapılamadı ya da yanıt kullanılamaz. Mesaj önek ya da parola
/// taşımaz.
final class PwnedPasswordsException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => 'PwnedPasswordsException: $message';
}

/// `https://api.pwnedpasswords.com/range/{önek}` sorgusu.
///
/// Yalnızca 5 karakterlik önek gider; önek denetlenir, uymazsa ağa hiç
/// çıkılmaz. Yanıt dolguludur (`Add-Padding`), yönlendirme izlenmez, çerez
/// tutulmaz, `User-Agent` yalnızca "KeyKey"dir.
final class PwnedPasswordsClient implements PwnedRangeSource {
  /// [baseUri] yalnızca testlerde değişir (yerel test sunucusu).
  ///
  /// Flutter, Android'in şifresiz trafik yasağını (`usesCleartextTraffic`,
  /// ağ güvenlik yapılandırması) Dart'ın `HttpClient`'ına uygulamıyor. Bu
  /// yüzden https dışı adres burada reddedilir; yalnızca bu cihazdaki test
  /// sunucusuna şifresiz bağlanılabilir.
  new({
    Uri? baseUri,
    this.connectTimeout = const Duration(seconds: 10),
    this.requestTimeout = const Duration(seconds: 30),
  }) : baseUri = _checked(baseUri ?? defaultBaseUri);

  static final Uri defaultBaseUri = Uri.parse(
    'https://api.pwnedpasswords.com/range/',
  );

  /// Gerçek yanıt 30-40 KB; bu sınır bozuk ya da kötü niyetli bir yanıtın
  /// belleği doldurmasını önler.
  static const int maxResponseBytes = 1024 * 1024;

  static final RegExp _prefix = RegExp(r'^[0-9A-F]{5}$');

  static const Set<String> _loopbackHosts = {'127.0.0.1', 'localhost', '::1'};

  static Uri _checked(Uri uri) {
    final secure = uri.scheme == 'https';
    final loopback = uri.scheme == 'http' && _loopbackHosts.contains(uri.host);
    if (!secure && !loopback) {
      throw ArgumentError.value(uri, 'baseUri', 'yalnızca https');
    }
    return uri;
  }

  final Uri baseUri;
  final Duration connectTimeout;
  final Duration requestTimeout;

  @override
  Future<String> fetchRange(String prefix) async {
    if (!_prefix.hasMatch(prefix)) {
      throw ArgumentError.value(prefix, 'prefix', '5 büyük onaltılık karakter');
    }
    final client = HttpClient()
      ..connectionTimeout = connectTimeout
      ..userAgent = 'KeyKey';
    try {
      return await _get(
        client,
        baseUri.resolve(prefix),
      ).timeout(requestTimeout);
    } on PwnedPasswordsException {
      rethrow;
    } on TimeoutException {
      throw const PwnedPasswordsException('zaman aşımı');
    } on IOException catch (error) {
      // SocketException, HandshakeException, HttpException.
      throw PwnedPasswordsException('bağlantı: ${error.runtimeType}');
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _get(HttpClient client, Uri uri) async {
    final request = await client.getUrl(uri);
    request
      ..followRedirects = false
      ..maxRedirects = 0
      ..persistentConnection = false
      ..headers.set('Add-Padding', 'true');
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw PwnedPasswordsException('yanıt ${response.statusCode}');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (bytes.length + chunk.length > maxResponseBytes) {
        throw const PwnedPasswordsException('yanıt çok büyük');
      }
      bytes.add(chunk);
    }
    try {
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const PwnedPasswordsException('yanıt UTF-8 değil');
    }
  }
}

/// Uygulamanın kullandığı kaynak; testler sahtesini verir.
final Provider<PwnedRangeSource> pwnedRangeSourceProvider =
    Provider<PwnedRangeSource>((ref) => PwnedPasswordsClient());

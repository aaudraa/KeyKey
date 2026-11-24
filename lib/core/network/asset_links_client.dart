import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/network/secure_url.dart';
import 'package:keykey/features/autofill/domain/domain_name.dart';

/// Bir sitenin Digital Asset Links dosyası
/// (`/.well-known/assetlinks.json`).
///
/// KeyKey'in ağ kodu yalnızca izin verilen dosyalardadır; başka bir yerde ağ
/// kodu olmadığını `test/core/network/network_audit_test.dart` denetler.
/// Tasarım: `resources/docs/uygulama-site-eslestirme.md`.
abstract interface class AssetLinksSource {
  /// [host]'un `assetlinks.json` gövdesi. Bağlantı hatası, zaman aşımı,
  /// `200` dışı yanıt, yönlendirme, büyük gövde ya da geçersiz alan adında
  /// `null`; hata kullanıcıya ayrıca gösterilmez.
  Future<String?> fetch(String host);
}

/// `https://<alan adı>/.well-known/assetlinks.json` sorgusu.
///
/// Siteye yalnızca sabit yol gider. Yönlendirme izlenmez (Android'in kendi
/// doğrulaması da izlemez), çerez tutulmaz, `User-Agent` yalnızca "KeyKey".
final class AssetLinksClient implements AssetLinksSource {
  /// [locate] yalnızca testlerde değişir (yerel test sunucusu); ürettiği
  /// adres [isSecureServiceUrl] ile denetlenir.
  new({
    Uri Function(String host)? locate,
    this.connectTimeout = const Duration(seconds: 3),
    this.requestTimeout = const Duration(seconds: 5),
  }) : locate = locate ?? defaultLocate;

  static Uri defaultLocate(String host) =>
      Uri(scheme: 'https', host: host, path: '/.well-known/assetlinks.json');

  /// Gerçek dosyalar birkaç KB; bu sınır bozuk ya da kötü niyetli bir
  /// yanıtın belleği doldurmasını önler.
  static const int maxResponseBytes = 128 * 1024;

  final Uri Function(String host) locate;
  final Duration connectTimeout;
  final Duration requestTimeout;

  @override
  Future<String?> fetch(String host) async {
    final name = DomainName.normalize(host);
    if (name == null || DomainName.isIpAddress(name)) return null;
    final uri = locate(name);
    if (!isSecureServiceUrl(uri)) return null;
    // Sıkıştırma istenmez: açılmış veri sınırı aşsa da tek bir parçanın
    // tamamı bellekte açılırdı.
    final client = HttpClient()
      ..connectionTimeout = connectTimeout
      ..userAgent = 'KeyKey'
      ..autoUncompress = false;
    try {
      return await _get(client, uri).timeout(requestTimeout);
    } on TimeoutException {
      return null;
    } on IOException {
      // SocketException, HandshakeException, HttpException.
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<String?> _get(HttpClient client, Uri uri) async {
    final request = await client.getUrl(uri);
    request
      ..followRedirects = false
      ..maxRedirects = 0
      ..persistentConnection = false;
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    final response = await request.close();
    final encoding = response.headers.value(HttpHeaders.contentEncodingHeader);
    if (response.statusCode != HttpStatus.ok ||
        (encoding != null && encoding.toLowerCase() != 'identity')) {
      await response.drain<void>();
      return null;
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (bytes.length + chunk.length > maxResponseBytes) return null;
      bytes.add(chunk);
    }
    try {
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      return null;
    }
  }
}

/// Uygulamanın kullandığı kaynak; testler sahtesini verir.
final Provider<AssetLinksSource> assetLinksSourceProvider =
    Provider<AssetLinksSource>((ref) => AssetLinksClient());

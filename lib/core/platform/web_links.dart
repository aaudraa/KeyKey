import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/platform/platform_api.g.dart';

/// Web sayfasını sistemin tarayıcısında açar. KeyKey internete çıkmaz;
/// adres yalnızca kullanıcı dokununca tarayıcıya devredilir.
abstract interface class WebLinks {
  /// Açacak uygulama yoksa `false`.
  Future<bool> open(Uri page);
}

final class PigeonWebLinks implements WebLinks {
  new([WebLinkApi? api]) : _api = api ?? WebLinkApi();

  final WebLinkApi _api;

  @override
  Future<bool> open(Uri page) => _api.openWebPage(page.toString());
}

/// Tarayıcıya ulaşamayan uygulama; varsayılan. `main` Pigeon uygulamasıyla
/// değiştirir.
final class NoWebLinks implements WebLinks {
  const new();

  @override
  Future<bool> open(Uri page) async => false;
}

final webLinksProvider = Provider<WebLinks>((ref) => const NoWebLinks());

/// Kayıttaki adresi açılabilir bir web sayfasına çevirir. Şeması olmayan
/// adrese `https://` eklenir; http ve https dışındaki şemalar
/// (`androidapp://`, `javascript:`, `intent:`, `file:`) ve adı olmayan
/// adresler `null` döner.
Uri? webPageUri(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final hasScheme = RegExp('^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(trimmed);
  final uri = Uri.tryParse(hasScheme ? trimmed : 'https://$trimmed');
  if (uri == null || !const {'http', 'https'}.contains(uri.scheme)) {
    return null;
  }
  // Boşluk gibi geçersiz karakterler ana bilgisayar adında yüzde kodlanır.
  if (uri.host.isEmpty || uri.host.contains('%')) return null;
  return uri;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/platform/platform_api.g.dart';

/// Web sayfasını sistemin tarayıcısında açar. Sayfayı KeyKey indirmez;
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
/// (`androidapp://`, `javascript:`, `intent:`, `file:`), adı olmayan ya da
/// kullanıcı bilgisi taşıyan adresler `null` döner. ASCII dışı adlar yüzde
/// kodlandığı için reddedilir; benzer görünen alan adlarına karşı bilerek.
Uri? webPageUri(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  // "nas.example:5001" şema değil, port taşıyan ad.
  final hostWithPort = RegExp(r'^[^:/?#\s]+:\d+(?:[/?#]|$)').hasMatch(trimmed);
  final hasScheme =
      !hostWithPort && RegExp('^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(trimmed);
  final uri = Uri.tryParse(hasScheme ? trimmed : 'https://$trimmed');
  if (uri == null || !const {'http', 'https'}.contains(uri.scheme)) {
    return null;
  }
  // Boşluk gibi geçersiz karakterler ana bilgisayar adında yüzde kodlanır.
  if (uri.host.isEmpty || uri.host.contains('%')) return null;
  // "https://banka.example@baska.example" ekranda banka gibi okunur ama
  // tarayıcı baska.example'ı açar.
  if (uri.userInfo.isNotEmpty) return null;
  return uri;
}

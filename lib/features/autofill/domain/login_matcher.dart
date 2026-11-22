import 'package:flutter/foundation.dart' show listEquals;
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/domain/domain_name.dart';
import 'package:keykey/features/autofill/domain/public_suffix_list.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

/// Kaydın hedefle nasıl eşleştiği; sıralama da bu sıradadır.
enum LoginMatchKind {
  /// Kayda bağlı uygulama: paket adı ve imza tutuyor.
  app,

  /// Kayıttaki adreslerden birinin sitesi, uygulamanın doğrulanmış sitesi:
  /// Android doğrulamış ya da sitenin `assetlinks.json` dosyası uygulamanın
  /// imzasını listeliyor. Yalnızca uygulama hedefinde.
  verifiedSite,

  /// Kayıttaki adresin alan adı formunkiyle aynı.
  exactHost,

  /// Kayıt edilebilir alan adı aynı: `giris.banka.com.tr` ile `banka.com.tr`.
  sameSite,
}

final class LoginMatch {
  const new(this.item, this.kind);

  final LoginItem item;
  final LoginMatchKind kind;
}

final class LoginMatches {
  const new({required this.matches, required this.signatureMismatches});

  static const empty = LoginMatches(matches: [], signatureMismatches: []);

  /// Eşleşen kayıtlar; önce türe, sonra ada göre sıralı.
  final List<LoginMatch> matches;

  /// Bağlı uygulamanın paket adı aynı ama imzası tutmayan kayıtlar. Bunlar
  /// eşleşmiş sayılmaz; seçilirse uygulamanın sahte olabileceği söylenir.
  final List<LoginItem> signatureMismatches;

  /// [item]'ın eşleşme türü; eşleşmediyse `null`.
  LoginMatchKind? kindOf(LoginItem item) {
    for (final match in matches) {
      if (listEquals(match.item.id, item.id)) return match.kind;
    }
    return null;
  }
}

/// İmza denetimi; Android'de `PackageManager.hasSigningCertificate`.
typedef SignatureCheck = Future<bool> Function(
  String packageName,
  List<String> certsSha256,
);

/// Kayıtları doldurulacak hedefle eşleştirir. Kurallar güvenlik tasarımı
/// belgesinin Eşleştirme bölümünde:
///
/// - Tarayıcı olmayan uygulamada yalnızca o uygulamaya bağlı kayıtlar
///   eşleşir; WebView'ın bildirdiği alan adı kullanılmaz.
/// - Uygulamada, bağlı olmayan kayıt, adreslerinden birinin sitesi
///   [verifiedSites] içindeyse (uygulamanın doğrulanmış siteleri, kayıt
///   edilebilir alan adı olarak) eşleşir. İmzası tutmayan kayıt bu yolla
///   eşleşmez. Uygulama web sayfası gösteriyorsa bu yol kullanılmaz:
///   uygulamanın kendi tarayıcısında açılan başka bir sitenin sahte giriş
///   sayfası, uygulamanın sitesinin kaydını uyarısız almasın.
/// - Güvenilen tarayıcıda yalnızca adresler karşılaştırılır.
///
/// [suffixes] web hedefinde ve [verifiedSites] doluyken gerekir; uygulama
/// hedefinde liste hiç yüklenmesin diye boş bırakılabilir.
Future<LoginMatches> matchLogins({
  required AutofillTarget target,
  required Iterable<LoginItem> items,
  required PublicSuffixList? suffixes,
  required SignatureCheck hasSigningCertificates,
  Set<String> verifiedSites = const {},
}) async {
  final matches = <LoginMatch>[];
  final mismatches = <LoginItem>[];
  final webDomain = target.webDomain;
  if (webDomain != null) {
    final list = suffixes ?? (throw ArgumentError.notNull('suffixes'));
    final host = DomainName.normalize(webDomain);
    if (host == null) return LoginMatches.empty;
    final site = list.registrableDomain(host);
    for (final item in items) {
      final kind = _webMatch(item, host, site, list);
      if (kind != null) matches.add(LoginMatch(item, kind));
    }
  } else {
    for (final item in items) {
      final bound = item.content.apps.where(
        (app) => app.packageName == target.packageName,
      );
      if (bound.isEmpty) {
        if (verifiedSites.isNotEmpty && !target.showsWebPage) {
          final list = suffixes ?? (throw ArgumentError.notNull('suffixes'));
          if (_onVerifiedSite(item, verifiedSites, list)) {
            matches.add(LoginMatch(item, LoginMatchKind.verifiedSite));
          }
        }
        continue;
      }
      var verified = false;
      for (final app in bound) {
        if (await hasSigningCertificates(app.packageName, app.certsSha256)) {
          verified = true;
          break;
        }
      }
      if (verified) {
        matches.add(LoginMatch(item, LoginMatchKind.app));
      } else {
        mismatches.add(item);
      }
    }
  }
  matches.sort((a, b) {
    final byKind = a.kind.index.compareTo(b.kind.index);
    if (byKind != 0) return byKind;
    return a.item.content.name.toLowerCase().compareTo(
      b.item.content.name.toLowerCase(),
    );
  });
  return LoginMatches(matches: matches, signatureMismatches: mismatches);
}

bool _onVerifiedSite(
  LoginItem item,
  Set<String> sites,
  PublicSuffixList suffixes,
) => item.content.urls.any((url) {
  final host = DomainName.hostOfUrl(url);
  return host != null && sites.contains(suffixes.registrableDomain(host));
});

LoginMatchKind? _webMatch(
  LoginItem item,
  String host,
  String? site,
  PublicSuffixList suffixes,
) {
  LoginMatchKind? best;
  for (final url in item.content.urls) {
    final urlHost = DomainName.hostOfUrl(url);
    if (urlHost == null) continue;
    if (urlHost == host) return LoginMatchKind.exactHost;
    if (site != null && suffixes.registrableDomain(urlHost) == site) {
      best = LoginMatchKind.sameSite;
    }
  }
  return best;
}

import 'dart:typed_data';

import 'package:keykey/core/network/asset_links_client.dart';
import 'package:keykey/features/autofill/application/app_site_check.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/domain/app_sites.dart';
import 'package:keykey/features/autofill/domain/login_matcher.dart';
import 'package:keykey/features/autofill/domain/public_suffix_list.dart';
import 'package:keykey/features/passkey/domain/webauthn.dart';
import 'package:keykey/features/vault/data/login_passkey.dart';

/// Passkey isteyen uygulama ya da tarayıcı.
///
/// Güvenilen tarayıcının origin'ini Android, KeyKey'in gömülü tarayıcı
/// listesine bakarak verir ([browserOrigin]); başka her çağıran uygulama
/// sayılır ve origin'i imza özetinden kurulur.
final class PasskeyCaller {
  const new({
    required this.packageName,
    required this.certsSha256,
    this.browserOrigin,
    this.appLabel,
  });

  final String packageName;

  /// İmza sertifikalarının SHA-256 özetleri, küçük harfli onaltılık.
  final List<String> certsSha256;

  /// Güvenilen tarayıcının bildirdiği sayfa origin'i (`https://…`).
  final String? browserOrigin;
  final String? appLabel;

  bool get isBrowser => browserOrigin != null;

  /// clientDataJSON'daki origin. Uygulamada
  /// `android:apk-key-hash:<base64url(SHA-256(imza))>`; çok imzacılı
  /// uygulama desteklenmez.
  String origin() {
    if (browserOrigin case final origin?) return origin;
    if (certsSha256.length != 1) {
      throw const PasskeyRequestException(PasskeyError.invalidRequest);
    }
    final hex = certsSha256.single;
    final digest = Uint8List.fromList([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]);
    return 'android:apk-key-hash:${base64UrlNoPad(digest)}';
  }
}

/// İstekte `rpId` yoksa tarayıcıda origin'in ana bilgisayarı (WebAuthn
/// kuralı); uygulamada `null` (istek reddedilir).
String? defaultRpId(PasskeyCaller caller) {
  final origin = caller.browserOrigin;
  if (origin == null) return null;
  return Uri.tryParse(origin)?.host;
}

/// `rpId` kullanılabilir mi: geçerli bir alan adı, public suffix değil;
/// tarayıcıda origin `https` ve ana bilgisayarı `rpId` ya da onun alt alanı.
/// Uygulamanın siteye ait olduğu ayrıca [appBelongsToRp] ile denetlenir.
bool rpIdAllowed(String rpId, PasskeyCaller caller, PublicSuffixList psl) {
  if (!LoginPasskey.isValidRpId(rpId)) return false;
  if (psl.registrableDomain(rpId) == null) return false;
  final origin = caller.browserOrigin;
  if (origin == null) return true;
  final uri = Uri.tryParse(origin);
  if (uri == null || uri.scheme != 'https') return false;
  final host = uri.host.toLowerCase();
  return host == rpId || host.endsWith('.$rpId');
}

/// Uygulama `rpId`'nin sitesine ait mi: Android'in doğruladığı alan adları
/// (internetsiz), ayar açıksa sitenin `assetlinks.json` dosyası. Kurallar
/// otomatik doldurmadaki doğrulanmış site kuralıyla aynı.
Future<bool> appBelongsToRp({
  required PasskeyCaller caller,
  required String rpId,
  required List<AppDomain> domains,
  required bool verifyOnline,
  required AssetLinksSource source,
  required SignatureCheck hasSigningCertificates,
  required PublicSuffixList suffixes,
}) async {
  final site = suffixes.registrableDomain(rpId);
  if (site == null) return false;
  if (verifiedSites(domains, suffixes).contains(site)) return true;
  if (!verifyOnline) return false;
  final result = await checkSitesOnline(
    packageName: caller.packageName,
    certsSha256: caller.certsSha256,
    hosts: [rpId],
    source: source,
    hasSigningCertificates: hasSigningCertificates,
  );
  return result[rpId] ?? false;
}

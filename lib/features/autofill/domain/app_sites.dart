import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/domain/domain_name.dart';
import 'package:keykey/features/autofill/domain/public_suffix_list.dart';

/// Uygulama ile sitenin eşleştirilmesi için saf yardımcılar. Tasarım:
/// `resources/docs/uygulama-site-eslestirme.md`.

/// Joker (`*.ornek.com`) baştaki `*.` atılmış alan adı.
String withoutWildcard(String host) =>
    host.startsWith('*.') ? host.substring(2) : host;

/// Android'in uygulama için doğruladığı alan adlarının kayıt edilebilir
/// alan adları. Doğrulanmamış (`SELECTED` dahil) alan adları alınmaz.
Set<String> verifiedSites(
  Iterable<AppDomain> domains,
  PublicSuffixList suffixes,
) => {
  for (final domain in domains)
    if (domain.verified)
      ?suffixes.registrableDomain(withoutWildcard(domain.host)),
};

/// Paket adından türetilen site: parçalar ters sırayla birleştirilir ve
/// kayıt edilebilir alan adı olan ilk (en kısa) önek alınır.
/// `com.github.android` → `github.com`, `tr.com.garanti.cep` →
/// `garanti.com.tr`.
///
/// Paket adını herkes seçebilir; bu yalnızca hangi siteye sorulacağını
/// bulur, kendisi hiçbir zaman eşleşme sayılmaz.
String? siteFromPackageName(String packageName, PublicSuffixList suffixes) {
  final labels = packageName.split('.');
  for (var count = 1; count <= labels.length; count++) {
    final candidate = DomainName.normalize(
      labels.take(count).toList().reversed.join('.'),
    );
    if (candidate == null) return null;
    if (suffixes.registrableDomain(candidate) == candidate) return candidate;
  }
  return null;
}

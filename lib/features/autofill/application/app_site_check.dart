import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/network/asset_links_client.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/domain/app_sites.dart';
import 'package:keykey/features/autofill/domain/asset_links.dart';
import 'package:keykey/features/autofill/domain/domain_name.dart';
import 'package:keykey/features/autofill/domain/login_matcher.dart';
import 'package:keykey/features/autofill/domain/public_suffix_list.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

/// Bir doldurmada en fazla bu kadar siteye sorulur.
const maxOnlineSites = 4;

/// İnternetle doğrulanacak alan adları. Tasarım:
/// `resources/docs/uygulama-site-eslestirme.md`, Akış 3.
///
/// Adaylar uygulamanın bildirdiği ama Android'in doğrulamadığı alan adları
/// (joker atılmış) ve paket adından türetilen sitedir. Yalnızca sitesi
/// [unmatched] kayıtlardan birinin adresiyle aynı olanlar kalır; site başına
/// bir alan adı (bildirilen, yoksa türetilen; alfabetik ilk), site adına göre
/// sıralı, en fazla [maxOnlineSites].
List<String> onlineCandidates({
  required String packageName,
  required Iterable<AppDomain> domains,
  required Iterable<LoginItem> unmatched,
  required PublicSuffixList suffixes,
}) {
  final recordSites = <String>{
    for (final item in unmatched)
      for (final url in item.content.urls)
        if (DomainName.hostOfUrl(url) case final host?)
          ?suffixes.registrableDomain(host),
  };
  if (recordSites.isEmpty) return const [];
  String? siteOf(String host) {
    final name = DomainName.normalize(host);
    if (name == null || DomainName.isIpAddress(name)) return null;
    final site = suffixes.registrableDomain(name);
    return recordSites.contains(site) ? site : null;
  }

  final declared = <String, String>{};
  for (final domain in domains) {
    if (domain.verified) continue;
    final host = DomainName.normalize(withoutWildcard(domain.host));
    if (host == null) continue;
    final site = siteOf(host);
    if (site == null) continue;
    final current = declared[site];
    if (current == null || host.compareTo(current) < 0) declared[site] = host;
  }
  final derived = siteFromPackageName(packageName, suffixes);
  if (derived != null && siteOf(derived) != null) {
    declared.putIfAbsent(derived, () => derived);
  }
  final sites = declared.keys.toList()..sort();
  return [for (final site in sites.take(maxOnlineSites)) declared[site]!];
}

/// [hosts]'un `assetlinks.json` dosyaları uygulamayı onaylıyor mu. Sorgular
/// birlikte başlar; [budget] dolunca yanıt vermeyen `false` sayılır.
///
/// Tek imzacılı uygulamada listedeki özetlerden biri
/// [hasSigningCertificates] ile tutarsa yeter (imza geçmişi de kabul
/// edilir); çok imzacılıda uygulamanın bütün imzacıları listede olmalıdır.
Future<Map<String, bool>> checkSitesOnline({
  required String packageName,
  required List<String> certsSha256,
  required List<String> hosts,
  required AssetLinksSource source,
  required SignatureCheck hasSigningCertificates,
  Duration budget = const Duration(seconds: 5),
}) async {
  Future<bool> approves(String host) async {
    final body = await source.fetch(host);
    if (body == null) return false;
    final listed = assetLinkFingerprints(body, packageName);
    if (listed.isEmpty || certsSha256.isEmpty) return false;
    if (certsSha256.length > 1) return listed.toSet().containsAll(certsSha256);
    for (final fingerprint in listed) {
      if (await hasSigningCertificates(packageName, [fingerprint])) {
        return true;
      }
    }
    return false;
  }

  final results = await Future.wait([
    for (final host in hosts)
      approves(host)
          .timeout(budget, onTimeout: () => false)
          .catchError((Object _) => false),
  ]);
  return {for (final (i, host) in hosts.indexed) host: results[i]};
}

/// Ekran açıkken internetle doğrulanmış alan adları; aynı alan adına ikinci
/// kez sorulmaz (kayda bağlama eşleşmeleri yeniden hesaplatır).
final siteCheckCacheProvider = Provider<Map<String, bool>>((ref) => {});

/// İnternetle doğrulama sürüyor; ekran yükleniyor görünümünde bunu söyler.
final siteCheckInProgressProvider = NotifierProvider<SiteCheckInProgress, bool>(
  SiteCheckInProgress.new,
);

class SiteCheckInProgress extends Notifier<bool> {
  @override
  bool build() => false;

  // Notifier'ın durumu dışarıdan bu yolla değişir.
  // ignore: use_setters_to_change_properties
  void set({required bool value}) => state = value;
}

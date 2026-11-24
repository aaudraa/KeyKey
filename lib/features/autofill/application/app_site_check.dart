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
///
/// [bound] uygulamaya imzasıyla zaten bağlı kayıtlardır. Sitelerine
/// sorulmaz: aynı sitede hiç seçilmeyen ikinci bir hesap yüzünden her
/// doldurmada internete çıkılmasın. O hesap aramayla bulunur.
List<String> onlineCandidates({
  required String packageName,
  required Iterable<AppDomain> domains,
  required Iterable<LoginItem> unmatched,
  required PublicSuffixList suffixes,
  Iterable<LoginItem> bound = const [],
}) {
  Set<String> sitesOf(Iterable<LoginItem> items) => {
    for (final item in items)
      for (final url in item.content.urls)
        if (DomainName.hostOfUrl(url) case final host?)
          ?suffixes.registrableDomain(host),
  };
  final recordSites = sitesOf(unmatched).difference(sitesOf(bound));
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

/// Ekran açıkken internetle doğrulanan alan adları; aynı alan adına ikinci
/// kez sorulmaz (kayda bağlama ve kayıtların değişmesi eşleşmeleri yeniden
/// hesaplatır, sorgu sürerken de).
final class SiteCheckCache {
  /// Sonucu bilinen alan adları.
  final Map<String, bool> results = {};

  final Map<String, Future<void>> _pending = {};

  /// [hosts]'un sonuçları [results]'a girene kadar bekler. Yalnızca sonucu
  /// bilinmeyen ve sorgusu sürmeyen alan adları [check]'e verilir.
  Future<void> ensure(
    List<String> hosts,
    Future<Map<String, bool>> Function(List<String> hosts) check,
  ) async {
    final fresh = [
      for (final host in hosts)
        if (!results.containsKey(host) && !_pending.containsKey(host)) host,
    ];
    if (fresh.isNotEmpty) {
      final batch = _run(fresh, check);
      for (final host in fresh) {
        _pending[host] = batch;
      }
    }
    await Future.wait({for (final host in hosts) ?_pending[host]});
  }

  Future<void> _run(
    List<String> hosts,
    Future<Map<String, bool>> Function(List<String> hosts) check,
  ) async {
    try {
      results.addAll(await check(hosts));
    } finally {
      hosts.forEach(_pending.remove);
    }
  }
}

final siteCheckCacheProvider = Provider<SiteCheckCache>(
  (ref) => SiteCheckCache(),
);

/// İnternetle doğrulama sürüyor; ekran yükleniyor görünümünde bunu söyler.
/// Eşleşmeler sorgu sürerken yeniden hesaplanabildiği için sayaçla tutulur:
/// yazı son sorgu bitince kalkar.
final siteCheckInProgressProvider = NotifierProvider<SiteCheckInProgress, bool>(
  SiteCheckInProgress.new,
);

class SiteCheckInProgress extends Notifier<bool> {
  var _running = 0;

  @override
  bool build() => _running > 0;

  void start() => state = ++_running > 0;

  void finish() {
    if (_running > 0) _running--;
    state = _running > 0;
  }
}

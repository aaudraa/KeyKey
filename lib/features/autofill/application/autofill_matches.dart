import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/network/asset_links_client.dart';
import 'package:keykey/features/autofill/application/app_site_check.dart';
import 'package:keykey/features/autofill/application/autofill_bridge.dart';
import 'package:keykey/features/autofill/domain/app_sites.dart';
import 'package:keykey/features/autofill/domain/login_matcher.dart';
import 'package:keykey/features/autofill/domain/public_suffix_list.dart';
import 'package:keykey/features/lock/application/vault_controller.dart';
import 'package:keykey/features/settings/application/settings_controller.dart';
import 'package:keykey/features/vault/application/logins_controller.dart';
import 'package:keykey/features/vault/data/login_repository.dart';

const publicSuffixListPath = 'resources/assets/autofill/public_suffix_list.dat';

/// Gömülü Public Suffix List; web hedefinde ve uygulamanın sitesi
/// aranırken yüklenir.
final publicSuffixListProvider = FutureProvider<PublicSuffixList>((ref) async {
  return PublicSuffixList.parse(
    await rootBundle.loadString(publicSuffixListPath),
  );
});

/// Açık kasadaki kayıtların doldurulacak hedefle eşleşmesi.
///
/// Uygulama hedefinde, imzası okunabildiyse, uygulamanın doğrulanmış
/// siteleri de kullanılır: önce Android'in doğruladıkları, sonra ayar açıksa
/// `assetlinks.json` ile internetten doğrulananlar. Tasarım:
/// `resources/docs/uygulama-site-eslestirme.md`.
final autofillMatchesProvider = FutureProvider<LoginMatches>((ref) async {
  final logins = ref.watch(loginsControllerProvider);
  final bridge = ref.watch(autofillBridgeProvider);
  final target = await ref.watch(autofillTargetProvider.future);
  if (target == null || logins is! LoginsLoaded) return LoginMatches.empty;
  // Çöpteki kayıt doldurulmaz, kaydetme ekranında güncellenecek kayıt
  // olarak da önerilmez; arama çöpü zaten süzüyor.
  final items = [
    for (final item in logins.items)
      if (!item.content.isTrashed) item,
  ];
  if (target.isWeb) {
    return await matchLogins(
      target: target,
      items: items,
      suffixes: await ref.read(publicSuffixListProvider.future),
      hasSigningCertificates: bridge.hasSigningCertificates,
    );
  }
  final appSites = target.certsSha256.isEmpty
      ? const <AppDomain>[]
      : await _appDomains(bridge, target.packageName);
  final verifyOnline =
      target.certsSha256.isNotEmpty && await _verifyOnlineEnabled(ref);
  if (appSites.isEmpty && !verifyOnline) {
    return await matchLogins(
      target: target,
      items: items,
      suffixes: null,
      hasSigningCertificates: bridge.hasSigningCertificates,
    );
  }
  final suffixes = await ref.read(publicSuffixListProvider.future);
  final cache = ref.read(siteCheckCacheProvider);
  final sites = verifiedSites(appSites, suffixes);
  void addCached() {
    for (final MapEntry(key: host, value: approved) in cache.entries) {
      final site = approved ? suffixes.registrableDomain(host) : null;
      if (site != null) sites.add(site);
    }
  }

  Future<LoginMatches> match() => matchLogins(
    target: target,
    items: items,
    suffixes: suffixes,
    hasSigningCertificates: bridge.hasSigningCertificates,
    verifiedSites: sites,
  );

  if (verifyOnline) addCached();
  final matches = await match();
  if (!verifyOnline) return matches;
  final unmatched = _unmatched(items, matches);
  final hosts = [
    for (final host in onlineCandidates(
      packageName: target.packageName,
      domains: appSites,
      unmatched: unmatched,
      suffixes: suffixes,
    ))
      if (!cache.containsKey(host)) host,
  ];
  if (hosts.isEmpty) return matches;
  final progress = ref.read(siteCheckInProgressProvider.notifier)
    ..set(value: true);
  try {
    cache.addAll(
      await checkSitesOnline(
        packageName: target.packageName,
        certsSha256: target.certsSha256,
        hosts: hosts,
        source: ref.read(assetLinksSourceProvider),
        hasSigningCertificates: bridge.hasSigningCertificates,
      ),
    );
  } finally {
    progress.set(value: false);
  }
  addCached();
  return await match();
});

Future<List<AppDomain>> _appDomains(
  AutofillBridge bridge,
  String packageName,
) async {
  try {
    return await bridge.appDomains(packageName);
  } on Exception {
    return const [];
  }
}

/// Ayar okunamazsa kapalı sayılır.
Future<bool> _verifyOnlineEnabled(Ref ref) async {
  final status = ref.read(vaultControllerProvider);
  if (status is! VaultOpen) return false;
  try {
    final settings = await ref
        .read(settingsRepositoryFactoryProvider)(status.session)
        .load();
    return settings.autofillVerifySites;
  } on Exception {
    return false;
  }
}

/// Eşleşmeyen ve imzası tutmuyor sayılmayan kayıtlar.
List<LoginItem> _unmatched(List<LoginItem> items, LoginMatches matches) {
  final excluded = {
    for (final m in matches.matches) m.item.id.join(','),
    for (final item in matches.signatureMismatches) item.id.join(','),
  };
  return [
    for (final item in items)
      if (!excluded.contains(item.id.join(','))) item,
  ];
}

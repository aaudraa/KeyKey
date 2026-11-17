import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keykey/app/router.dart';
import 'package:keykey/app/ui/kk_backdrop.dart';
import 'package:keykey/app/ui/kk_bars.dart';
import 'package:keykey/app/ui/kk_glass.dart';
import 'package:keykey/app/ui/kk_section.dart';
import 'package:keykey/features/settings/application/license_catalog_provider.dart';
import 'package:keykey/features/settings/data/license_catalog.dart';
import 'package:keykey/l10n/generated/app_localizations.dart';

/// Ayarlar'daki Lisanslar: önce KeyKey'in kendi lisansı, sonra uygulamada
/// gerçekten işi olan parçalar ne işe yaradıklarıyla, en sonda bütün
/// paketlerin listesi. Flutter'ın hazır lisans sayfası yüzlerce teknik
/// paket adını tek listede gösterdiği için yerine bu ekran geldi.
class LicensesScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final catalog = ref.watch(licenseCatalogProvider).value;
    return KkScaffold(
      appBar: kkAppBar(context, title: l10n.settingsLicenses),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          KkSection(
            title: 'KeyKey',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.licensesKeyKeyBody),
                    const SizedBox(height: 8),
                    Text(
                      l10n.licensesCopyright,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                title: Text(l10n.licensesReadKeyKey),
                subtitle: const Text('GPL-3.0'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(
                  AppRoutes.licenseText(title: 'KeyKey', packages: ['keykey']),
                ),
              ),
            ],
          ),
          if (catalog == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            KkSection(
              title: l10n.licensesUsed,
              children: [
                for (final part in _parts(l10n))
                  if (_present(catalog, part.packages) case final present
                      when present.isNotEmpty)
                    ListTile(
                      title: Text(part.name),
                      subtitle: Text(
                        '${part.purpose} · '
                        '${_kindsLabel(l10n, _kindsOf(catalog, present))}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(
                        AppRoutes.licenseText(
                          title: part.name,
                          packages: present,
                        ),
                      ),
                    ),
              ],
            ),
            KkSection(
              title: l10n.licensesAll,
              children: [
                ListTile(
                  title: Text(l10n.licensesAllPackages),
                  subtitle: Text(
                    l10n.licensesAllCount(catalog.packages.length),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.licensesAll),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Bütün paketler, baş harflerine göre gruplanmış.
class LicensePackagesScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(licenseCatalogProvider).value;
    final groups = <String, List<LicensePackage>>{};
    for (final package in catalog?.packages ?? const <LicensePackage>[]) {
      final key = package.name == LicenseCatalog.unnamed
          ? '#'
          : package.name.substring(0, 1).toUpperCase();
      (groups[key] ??= []).add(package);
    }
    final entries = groups.entries.toList();
    return KkScaffold(
      appBar: kkAppBar(context, title: l10n.licensesAllPackages),
      body: catalog == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final MapEntry(key: letter, value: packages) = entries[index];
                return KkSection(
                  title: letter,
                  children: [
                    for (final package in packages)
                      ListTile(
                        title: Text(_displayName(l10n, package.name)),
                        subtitle: Text(_kindsLabel(l10n, package.kinds)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(
                          AppRoutes.licenseText(
                            title: _displayName(l10n, package.name),
                            packages: [package.name],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

/// Bir ya da birkaç paketin lisans metinleri. Birden fazla paket varsa her
/// birinin adı metinlerinin üstünde yazar.
class LicenseTextScreen extends ConsumerWidget {
  const new({required this.title, required this.packages, super.key});

  final String title;
  final List<String> packages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final catalog = ref.watch(licenseCatalogProvider).value;
    final items = <Widget>[];
    for (final name in packages) {
      final package = catalog?[name];
      if (package == null) continue;
      if (packages.length > 1) {
        items.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              _displayName(l10n, name),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(
            _kindsLabel(l10n, package.kinds),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
      for (final text in package.texts) {
        items.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: GlassSurface(
              padding: const EdgeInsets.all(16),
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
              ),
            ),
          ),
        );
      }
    }
    return KkScaffold(
      appBar: kkAppBar(context, title: title),
      body: catalog == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: items.length,
              itemBuilder: (context, index) => items[index],
            ),
    );
  }
}

typedef _Part = ({String name, String purpose, List<String> packages});

/// Uygulamada işi olan parçalar ve lisansları katalogda hangi adlarla
/// geçtiği. Katalogda olmayan ad atlanır.
List<_Part> _parts(AppLocalizations l10n) => [
  (
    name: 'libsodium',
    purpose: l10n.licensesPurposeCrypto,
    packages: ['libsodium', 'sodium'],
  ),
  (
    name: 'SQLite',
    purpose: l10n.licensesPurposeDatabase,
    packages: ['SQLite', 'sqlite', 'sqlite3', 'drift'],
  ),
  (name: 'Flutter', purpose: l10n.licensesPurposeUi, packages: ['flutter']),
  (
    name: 'zxing-cpp, zint',
    purpose: l10n.licensesPurposeQr,
    packages: ['flutter_zxing', 'zxing-cpp', 'zint'],
  ),
  (
    name: 'camera',
    purpose: l10n.licensesPurposeCamera,
    packages: ['camera', 'camera_android_camerax'],
  ),
  (
    name: 'Barlow Condensed',
    purpose: l10n.licensesPurposeFont,
    packages: ['Barlow Condensed'],
  ),
  (
    name: 'EFF Large Wordlist',
    purpose: l10n.licensesPurposePassphrase,
    packages: ['EFF Large Wordlist'],
  ),
  (
    name: 'SecLists',
    purpose: l10n.licensesPurposeCommon,
    packages: ['SecLists'],
  ),
  (
    name: 'Public Suffix List',
    purpose: l10n.licensesPurposeDomains,
    packages: ['Public Suffix List'],
  ),
  (
    name: l10n.licensesAndroid,
    purpose: l10n.licensesPurposeAndroid,
    packages: ['Android libraries'],
  ),
];

List<String> _present(LicenseCatalog catalog, List<String> names) => [
  for (final name in names)
    if (catalog[name] != null) name,
];

Set<LicenseKind> _kindsOf(LicenseCatalog catalog, List<String> names) => {
  for (final name in names) ...?catalog[name]?.kinds,
};

String _displayName(AppLocalizations l10n, String name) =>
    name == LicenseCatalog.unnamed ? l10n.licensesUnnamed : name;

/// Türler tanımlandıkları sırada, kısa adlarıyla.
String _kindsLabel(AppLocalizations l10n, Set<LicenseKind> kinds) {
  final sorted = kinds.toList()..sort((a, b) => a.index.compareTo(b.index));
  return sorted
      .map(
        (kind) => switch (kind) {
          LicenseKind.publicDomain => l10n.licenseKindPublicDomain,
          LicenseKind.other => l10n.licenseKindOther,
          _ => kind.shortName!,
        },
      )
      .join(', ');
}

import 'dart:convert';

/// Uygulamayla giriş bilgisi paylaşımını ya da bağlantıları onaylayan
/// ilişkiler. Tasarım: `resources/docs/uygulama-site-eslestirme.md`.
const assetLinkRelations = {
  'delegate_permission/common.get_login_creds',
  'delegate_permission/common.handle_all_urls',
};

final _fingerprint = RegExp(r'^[0-9a-f]{64}$');

/// `assetlinks.json` gövdesinde [packageName]'i kabul edilen bir ilişkiyle
/// listeleyen ifadelerin imza özetleri; küçük harfli, ayraçsız 64 hane.
/// Biçimi bozuk dosya ya da ifade sessizce atlanır. `include` izlenmez.
List<String> assetLinkFingerprints(String json, String packageName) {
  final Object? root;
  try {
    root = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  if (root is! List) return const [];
  final result = <String>{};
  for (final statement in root) {
    if (statement is! Map) continue;
    final relation = statement['relation'];
    final target = statement['target'];
    if (relation is! List || target is! Map) continue;
    if (!relation.any(assetLinkRelations.contains)) continue;
    if (target['namespace'] != 'android_app') continue;
    if (target['package_name'] != packageName) continue;
    final fingerprints = target['sha256_cert_fingerprints'];
    if (fingerprints is! List) continue;
    for (final value in fingerprints) {
      if (value is! String) continue;
      final hex = value.replaceAll(':', '').toLowerCase();
      if (_fingerprint.hasMatch(hex)) result.add(hex);
    }
  }
  return result.toList();
}

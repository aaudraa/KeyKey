import 'package:flutter/foundation.dart';

/// Lisans metninden tanınan lisans türü. Ekranda kısa adıyla gösterilir;
/// karar vermek için değil, okuyana yol göstermek için.
enum LicenseKind {
  gpl3('GPL-3.0'),
  lgpl('LGPL'),
  apache2('Apache-2.0'),
  mit('MIT'),
  bsd3('BSD-3-Clause'),
  bsd2('BSD-2-Clause'),
  isc('ISC'),
  mpl2('MPL-2.0'),
  ofl('OFL-1.1'),
  ccBy3('CC BY 3.0'),
  zlib('Zlib'),
  publicDomain(null),
  other(null);

  new(this.shortName);

  /// SPDX'e yakın kısa ad. Kamu malı ve tanınmayan metinlerde yok; ekran
  /// onları kendi dilinde yazar.
  final String? shortName;
}

/// Metnin içindeki lisansları tanır. Hiçbiri tanınmazsa [LicenseKind.other].
///
/// Bir metinde birden fazla lisans olabilir (ör. Flutter motorunun üçüncü
/// taraf kodları). Başka bir lisansı yalnızca adıyla anan metin o lisans
/// sayılmaz: türler lisansların kendine özgü cümlelerinden tanınır.
Set<LicenseKind> licenseKindsOf(String text) {
  final t = text.toUpperCase();
  final kinds = <LicenseKind>{};
  final lesser = t.contains('GNU LESSER GENERAL PUBLIC LICENSE');
  if (lesser) kinds.add(LicenseKind.lgpl);
  if (!lesser && t.contains('GNU GENERAL PUBLIC LICENSE')) {
    kinds.add(LicenseKind.gpl3);
  }
  if (t.contains('APACHE LICENSE') && t.contains('VERSION 2.0')) {
    kinds.add(LicenseKind.apache2);
  }
  if (t.contains('PERMISSION IS HEREBY GRANTED, FREE OF CHARGE')) {
    kinds.add(LicenseKind.mit);
  }
  if (t.contains('REDISTRIBUTION AND USE IN SOURCE AND BINARY FORMS')) {
    kinds.add(
      t.contains('NEITHER THE NAME') || t.contains('NAMES OF ITS CONTRIBUTORS')
          ? LicenseKind.bsd3
          : LicenseKind.bsd2,
    );
  }
  if (t.contains('PERMISSION TO USE, COPY, MODIFY, AND/OR DISTRIBUTE') ||
      t.contains('PERMISSION TO USE, COPY, MODIFY, AND DISTRIBUTE')) {
    kinds.add(LicenseKind.isc);
  }
  if (t.contains('MOZILLA PUBLIC LICENSE')) kinds.add(LicenseKind.mpl2);
  if (t.contains('SIL OPEN FONT LICENSE')) kinds.add(LicenseKind.ofl);
  if (t.contains('CREATIVE COMMONS ATTRIBUTION 3.0')) {
    kinds.add(LicenseKind.ccBy3);
  }
  if (t.contains("PROVIDED 'AS-IS'") &&
      t.contains('PERMISSION IS GRANTED TO ANYONE TO USE THIS SOFTWARE')) {
    kinds.add(LicenseKind.zlib);
  }
  if (kinds.isEmpty && t.contains('PUBLIC DOMAIN')) {
    kinds.add(LicenseKind.publicDomain);
  }
  return kinds.isEmpty ? {LicenseKind.other} : kinds;
}

/// Bir paketin ya da bileşenin lisans metinleri.
@immutable
class LicensePackage {
  const new({required this.name, required this.texts, required this.kinds});

  final String name;
  final List<String> texts;
  final Set<LicenseKind> kinds;
}

/// Uygulamaya giren bütün lisans metinleri, paket adına göre.
///
/// Flutter derlemede paketlerin `LICENSE` dosyalarını toplar; KeyKey de
/// paket olmayan kaynakları (`registerDataLicenses`) ekler. Bazı
/// paketlerin dosyası Flutter'ın beklediği biçimde olmadığı için başlık
/// yerine bir satır parçası ("-", "Copyright ...") gelir; bu metinler
/// [unnamed] altında toplanır, kaybolmaz.
@immutable
class LicenseCatalog {
  const new _(this._packages);

  /// Adı okunamayan metinlerin grubu; ekran kendi dilinde adlandırır.
  static const unnamed = '';

  final Map<String, LicensePackage> _packages;

  static Future<LicenseCatalog> fromRegistry(
    Stream<LicenseEntry> entries,
  ) async {
    final texts = <String, List<String>>{};
    await for (final entry in entries) {
      final text = entry.paragraphs
          .map((p) => '${'  ' * (p.indent < 0 ? 0 : p.indent)}${p.text}')
          .join('\n\n');
      for (final name in entry.packages) {
        (texts[_isBroken(name) ? unnamed : name] ??= []).add(text);
      }
    }
    return LicenseCatalog._({
      for (final MapEntry(:key, :value) in texts.entries)
        key: LicensePackage(
          name: key,
          texts: List.unmodifiable(value),
          kinds: {for (final text in value) ...licenseKindsOf(text)},
        ),
    });
  }

  static bool _isBroken(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty || trimmed == '-' || trimmed.startsWith('Copyright');
  }

  LicensePackage? operator [](String name) => _packages[name];

  /// Harf sırasında; adsız grup en sonda.
  List<LicensePackage> get packages {
    final named = _packages.values.where((p) => p.name != unnamed).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return [...named, ?_packages[unnamed]];
  }
}

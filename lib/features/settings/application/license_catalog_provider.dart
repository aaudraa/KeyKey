import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/features/settings/data/license_catalog.dart';

/// Uygulamadaki bütün lisans metinleri. Lisans ekranları açıkken bellekte
/// durur, kapanınca bırakılır (metinler birkaç megabayt). Test ortamında
/// Flutter lisansları yüklemediği için testler sabit bir katalog verir.
final FutureProvider<LicenseCatalog> licenseCatalogProvider =
    FutureProvider.autoDispose<LicenseCatalog>(
      (ref) => LicenseCatalog.fromRegistry(LicenseRegistry.licenses),
    );

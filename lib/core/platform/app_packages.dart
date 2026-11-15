import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:keykey/core/platform/platform_api.g.dart';

/// Telefondaki uygulamaların simgeleri ve KeyKey'in sürümü.
abstract interface class AppPackages {
  /// Simgeler bu boyutta (piksel) okunur.
  static const iconSizePx = 144;

  Future<Uint8List?> appIcon(String packageName);

  Future<String> versionName();
}

final class PigeonAppPackages implements AppPackages {
  new([AppPackagesApi? api]) : _api = api ?? AppPackagesApi();

  final AppPackagesApi _api;

  @override
  Future<Uint8List?> appIcon(String packageName) =>
      _api.appIcon(packageName, AppPackages.iconSizePx);

  @override
  Future<String> versionName() => _api.versionName();
}

/// Simge göstermeyen uygulama; varsayılan. Simgeler yalnızca görünüş için
/// olduğu için sağlanmadığında hata yerine çizgi simgelere düşülür.
final class NoAppPackages implements AppPackages {
  const new();

  @override
  Future<Uint8List?> appIcon(String packageName) async => null;

  @override
  Future<String> versionName() async => '';
}

/// `main` ve `autofillMain` Pigeon uygulamasıyla doldurur.
final appPackagesProvider = Provider<AppPackages>(
  (ref) => const NoAppPackages(),
);

/// Uygulama simgesi. Yalnızca bellekte tutulur; onu gösteren ekran kapanınca
/// (kasa kilitlenince de) düşer.
final FutureProviderFamily<Uint8List?, String> appIconProvider = FutureProvider
    .autoDispose
    .family<Uint8List?, String>((ref, packageName) async {
      try {
        return await ref.watch(appPackagesProvider).appIcon(packageName);
      } on Object {
        return null;
      }
    });

final appVersionProvider = FutureProvider<String>(
  (ref) => ref.watch(appPackagesProvider).versionName(),
);

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:keykey/core/platform/platform_api.g.dart';

/// Telefondaki uygulamaların simgeleri, KeyKey'in sürümü ve telefonun
/// modeli.
abstract interface class AppPackages {
  /// Simgeler bu boyutta (piksel) okunur.
  static const iconSizePx = 144;

  /// Telefon modeli en çok bu kadar karakter (senkron dosyasının sınırı).
  static const maxDeviceModelLength = 64;

  Future<Uint8List?> appIcon(String packageName);

  Future<String> versionName();

  /// Telefonun modeli, örneğin "SM-G780G"; bilinmiyorsa boş.
  Future<String> deviceModel();
}

final class PigeonAppPackages implements AppPackages {
  new([AppPackagesApi? api]) : _api = api ?? AppPackagesApi();

  final AppPackagesApi _api;

  @override
  Future<Uint8List?> appIcon(String packageName) =>
      _api.appIcon(packageName, AppPackages.iconSizePx);

  @override
  Future<String> versionName() => _api.versionName();

  @override
  Future<String> deviceModel() async {
    final model = (await _api.deviceModel()).trim();
    return model.length > AppPackages.maxDeviceModelLength
        ? model.substring(0, AppPackages.maxDeviceModelLength)
        : model;
  }
}

/// Simge göstermeyen uygulama; varsayılan. Simgeler yalnızca görünüş için
/// olduğu için sağlanmadığında hata yerine çizgi simgelere düşülür.
final class NoAppPackages implements AppPackages {
  const new();

  @override
  Future<Uint8List?> appIcon(String packageName) async => null;

  @override
  Future<String> versionName() async => '';

  @override
  Future<String> deviceModel() async => '';
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

/// Telefonun modeli; senkron dosyasında cihaz adı olarak gider.
final deviceModelProvider = FutureProvider<String>(
  (ref) => ref.watch(appPackagesProvider).deviceModel(),
);

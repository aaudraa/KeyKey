import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/platform/platform_api.g.dart';

/// Otomatik doldurmanın bu cihazdaki kurulum durumu.
@immutable
final class AutofillSetupState {
  const new({
    required this.supported,
    required this.enabled,
    this.chromeMajorVersion,
    this.passkeysSupported = false,
  });

  /// Chrome başka bir doldurma servisini bu sürümden beri kullanabiliyor.
  static const minChromeVersion = 135;

  final bool supported;

  /// Seçili servis KeyKey.
  final bool enabled;

  /// Kurulu Chrome'un ana sürümü; Chrome yoksa `null`.
  final int? chromeMajorVersion;

  /// KeyKey bu cihazda passkey sağlayıcısı olabilir (Android 14+).
  final bool passkeysSupported;

  bool get chromeTooOld =>
      chromeMajorVersion != null && chromeMajorVersion! < minChromeVersion;
}

/// Kurulumun Android tarafı. Testler kendi sahtesini verir.
abstract interface class AutofillSetupBridge {
  Future<AutofillSetupState> status();

  /// Sistemin servis seçimini açar; açılamazsa `false`.
  Future<bool> openAutofillSettings();

  /// Chrome'un otomatik doldurma ayarını açar; açılamazsa `false`.
  Future<bool> openChromeAutofillSettings();

  /// Sistemin passkey sağlayıcısı seçimini açar; açılamazsa `false`.
  Future<bool> openCredentialProviderSettings();
}

final class PigeonAutofillSetupBridge implements AutofillSetupBridge {
  final _api = AutofillSetupApi();

  @override
  Future<AutofillSetupState> status() async {
    final status = await _api.status();
    return AutofillSetupState(
      supported: status.supported,
      enabled: status.enabled,
      chromeMajorVersion: status.chromeMajorVersion,
      passkeysSupported: status.passkeysSupported,
    );
  }

  @override
  Future<bool> openAutofillSettings() => _api.openAutofillSettings();

  @override
  Future<bool> openChromeAutofillSettings() =>
      _api.openChromeAutofillSettings();

  @override
  Future<bool> openCredentialProviderSettings() =>
      _api.openCredentialProviderSettings();
}

final autofillSetupBridgeProvider = Provider<AutofillSetupBridge>(
  (ref) => PigeonAutofillSetupBridge(),
);

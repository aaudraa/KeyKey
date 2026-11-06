import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/platform/platform_api.g.dart';

/// Doldurulacak formun sahibi: uygulama ve varsa web sitesi.
///
/// Kasaya bakmadan bilinenlerdir. [webDomain] yalnızca güvenilen bir
/// tarayıcıdan geldiyse doludur. Kurallar güvenlik tasarımı belgesinin
/// Otomatik doldurma bölümündedir.
@immutable
final class AutofillTarget {
  const new({
    required this.packageName,
    this.appLabel,
    this.certsSha256 = const [],
    this.webDomain,
    this.webScheme,
    this.untrustedWebDomain,
    this.hasUsernameField = true,
    this.hasPasswordField = true,
  });

  final String packageName;
  final String? appLabel;

  /// Uygulamanın imza sertifikalarının SHA-256 özetleri. Okunamadıysa boş.
  final List<String> certsSha256;

  final String? webDomain;
  final String? webScheme;

  /// Tarayıcı olmayan bir uygulamanın bildirdiği alan adı (WebView).
  /// Eşleştirmede kullanılmaz.
  final String? untrustedWebDomain;

  final bool hasUsernameField;
  final bool hasPasswordField;

  bool get isWeb => webDomain != null;
}

/// Doldurma ekranının Android tarafı. Testler kendi sahtesini verir.
abstract interface class AutofillBridge {
  /// Ekranı açan istek; ekran bir istekle açılmadıysa `null`.
  Future<AutofillTarget?> currentTarget();

  /// [packageName] verilen imza özetlerinin hepsiyle imzalanmış mı.
  Future<bool> hasSigningCertificates(String packageName, List<String> certs);

  /// Değerleri forma verir; Android ekranı kapatır.
  Future<void> fill({required String username, required String password});

  /// Hiçbir şey doldurmadan kapatır.
  Future<void> cancel();
}

final class PigeonAutofillBridge implements AutofillBridge {
  final _api = AutofillApi();

  @override
  Future<AutofillTarget?> currentTarget() async {
    final request = await _api.currentRequest();
    if (request == null) return null;
    return AutofillTarget(
      packageName: request.packageName,
      appLabel: request.appLabel,
      certsSha256: List.unmodifiable(request.certsSha256),
      webDomain: request.webDomain,
      webScheme: request.webScheme,
      untrustedWebDomain: request.untrustedWebDomain,
      hasUsernameField: request.hasUsernameField,
      hasPasswordField: request.hasPasswordField,
    );
  }

  @override
  Future<bool> hasSigningCertificates(String packageName, List<String> certs) =>
      _api.hasSigningCertificates(packageName, certs);

  @override
  Future<void> fill({required String username, required String password}) =>
      _api.fill(username, password);

  @override
  Future<void> cancel() => _api.cancel();
}

final autofillBridgeProvider = Provider<AutofillBridge>(
  (ref) => throw UnimplementedError('Doldurma köprüsü sağlanmadı.'),
);

/// Ekranı açan istek, bir kez okunur.
final autofillTargetProvider = FutureProvider<AutofillTarget?>(
  (ref) => ref.watch(autofillBridgeProvider).currentTarget(),
);

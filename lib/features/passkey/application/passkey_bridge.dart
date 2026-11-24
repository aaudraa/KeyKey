import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keykey/core/platform/platform_api.g.dart';
import 'package:keykey/features/passkey/domain/passkey_caller.dart';
import 'package:keykey/features/passkey/domain/webauthn.dart';

export 'package:keykey/core/platform/platform_api.g.dart'
    show AppDomain, PasskeyAssertion, PasskeyKeyPair;

enum PasskeyRequestKind { create, get }

/// Passkey penceresini açan istek; kasaya bakmadan bilinenler.
@immutable
final class PasskeyRequest {
  const new({
    required this.kind,
    required this.requestJson,
    required this.caller,
    this.clientDataHash,
  });

  final PasskeyRequestKind kind;

  /// Credential Manager'ın verdiği WebAuthn seçenekleri.
  final String requestJson;
  final PasskeyCaller caller;

  /// Tarayıcının verdiği clientDataJSON özeti; imzada bu kullanılır.
  final Uint8List? clientDataHash;
}

/// Passkey penceresinin Android tarafı. Testler kendi sahtesini verir.
abstract interface class PasskeyBridge {
  /// Pencereyi açan istek; okunamadıysa `null`.
  Future<PasskeyRequest?> request();

  /// [packageName] verilen imza özetlerinin hepsiyle imzalanmış mı.
  Future<bool> hasSigningCertificates(String packageName, List<String> certs);

  /// [packageName]'in bildirdiği alan adları ve doğrulama durumu.
  Future<List<AppDomain>> appDomains(String packageName);

  /// Oluşturma yanıtını sisteme verir ve pencereyi kapatır.
  Future<void> finishCreate(String responseJson);

  /// Hesapları sisteme verir ve pencereyi kapatır. Boşsa hesap gösterilmez.
  Future<void> finishGet(List<PasskeyAssertion> assertions);

  /// İsteği reddeder ve pencereyi kapatır.
  Future<void> fail(PasskeyError error);

  Future<void> cancel();
}

/// P-256 anahtarları Android'in kendi sağlayıcısıyla.
abstract interface class PasskeyKeys {
  Future<PasskeyKeyPair> generate();

  /// `SHA256withECDSA`, DER imza; [privateKey] PKCS#8.
  Future<Uint8List> sign(Uint8List privateKey, Uint8List data);
}

final class PigeonPasskeyBridge implements PasskeyBridge {
  final _api = PasskeyApi();

  @override
  Future<PasskeyRequest?> request() async {
    final info = await _api.request();
    if (info == null) return null;
    final kind = switch (info.kind) {
      'create' => PasskeyRequestKind.create,
      'get' => PasskeyRequestKind.get,
      _ => null,
    };
    if (kind == null) return null;
    return PasskeyRequest(
      kind: kind,
      requestJson: info.requestJson,
      caller: PasskeyCaller(
        packageName: info.packageName,
        certsSha256: List.unmodifiable(info.certsSha256),
        browserOrigin: info.browserOrigin,
        appLabel: info.appLabel,
      ),
      clientDataHash: info.clientDataHash,
    );
  }

  @override
  Future<bool> hasSigningCertificates(String packageName, List<String> certs) =>
      _api.hasSigningCertificates(packageName, certs);

  @override
  Future<List<AppDomain>> appDomains(String packageName) =>
      _api.appDomains(packageName);

  @override
  Future<void> finishCreate(String responseJson) =>
      _api.finishCreate(responseJson);

  @override
  Future<void> finishGet(List<PasskeyAssertion> assertions) =>
      _api.finishGet(assertions);

  @override
  Future<void> fail(PasskeyError error) => _api.fail(error.name);

  @override
  Future<void> cancel() => _api.cancel();
}

final class PigeonPasskeyKeys implements PasskeyKeys {
  final _api = PasskeyCryptoApi();

  @override
  Future<PasskeyKeyPair> generate() => _api.generate();

  @override
  Future<Uint8List> sign(Uint8List privateKey, Uint8List data) =>
      _api.sign(privateKey, data);
}

final passkeyBridgeProvider = Provider<PasskeyBridge>(
  (ref) => throw UnimplementedError('Passkey köprüsü sağlanmadı.'),
);

final passkeyKeysProvider = Provider<PasskeyKeys>((ref) => PigeonPasskeyKeys());

/// Pencereyi açan istek, bir kez okunur.
final passkeyRequestProvider = FutureProvider<PasskeyRequest?>(
  (ref) => ref.watch(passkeyBridgeProvider).request(),
);

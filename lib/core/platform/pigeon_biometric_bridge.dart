import 'dart:typed_data';

import 'package:keykey/core/platform/biometric_api.g.dart';
import 'package:keykey/core/storage/vault_store.dart';
import 'package:keykey/core/vault/biometric_bridge.dart';

/// [BiometricBridge] arayüzünü Kotlin köprüsüne bağlar.
final class PigeonBiometricBridge implements BiometricBridge {
  new([BiometricApi? api]) : _api = api ?? BiometricApi();

  final BiometricApi _api;

  @override
  Future<BiometricSupport> support() async {
    return switch (await _api.availability()) {
      BiometricAvailability.available => BiometricSupport.available,
      BiometricAvailability.noHardware => BiometricSupport.noHardware,
      BiometricAvailability.notEnrolled => BiometricSupport.notEnrolled,
      BiometricAvailability.unavailable => BiometricSupport.unavailable,
    };
  }

  @override
  Future<BiometricOutcome<StoredBiometricSlot>> wrap(
    Uint8List plainText,
    Uint8List associatedData,
    BiometricTexts texts,
  ) async {
    final result = await _api.wrap(plainText, associatedData, _texts(texts));
    final iv = result.iv;
    final cipherText = result.cipherText;
    if (result.status == BiometricStatus.success &&
        iv != null &&
        cipherText != null) {
      return BiometricSuccess(
        StoredBiometricSlot(iv: iv, cipherText: cipherText),
      );
    }
    return _failure(result.status);
  }

  @override
  Future<BiometricOutcome<Uint8List>> unwrap(
    StoredBiometricSlot slot,
    Uint8List associatedData,
    BiometricTexts texts,
  ) async {
    final result = await _api.unwrap(
      slot.iv,
      slot.cipherText,
      associatedData,
      _texts(texts),
    );
    final plainText = result.plainText;
    if (result.status == BiometricStatus.success && plainText != null) {
      return BiometricSuccess(plainText);
    }
    return _failure(result.status);
  }

  @override
  Future<void> deleteKey() => _api.deleteKey();

  static BiometricPromptTexts _texts(BiometricTexts texts) =>
      BiometricPromptTexts(
        title: texts.title,
        negativeButton: texts.negativeButton,
      );

  static BiometricOutcome<T> _failure<T>(BiometricStatus status) {
    return switch (status) {
      BiometricStatus.cancelled => BiometricCancelled<T>(),
      BiometricStatus.lockedOut => BiometricLockedOut<T>(),
      BiometricStatus.invalidated => BiometricInvalidated<T>(),
      BiometricStatus.success || BiometricStatus.failed => BiometricFailed<T>(),
    };
  }
}

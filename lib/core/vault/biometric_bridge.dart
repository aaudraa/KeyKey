import 'dart:typed_data';

import 'package:keykey/core/storage/vault_store.dart';

/// Cihazın güçlü biyometri durumu.
enum BiometricSupport { available, noHardware, notEnrolled, unavailable }

/// Parmak izi işleminin sonucu. [T] başarıda dönen değerdir.
sealed class BiometricOutcome<T> {
  const new();
}

final class BiometricSuccess<T> extends BiometricOutcome<T> {
  const new(this.value);

  final T value;
}

/// Kullanıcı vazgeçti veya ana parolayı seçti.
final class BiometricCancelled<T> extends BiometricOutcome<T> {
  const new();
}

/// Çok fazla hatalı deneme, Android bir süre izin vermiyor.
final class BiometricLockedOut<T> extends BiometricOutcome<T> {
  const new();
}

/// Yeni parmak izi eklendi veya ekran kilidi kaldırıldı, anahtar geçersiz.
final class BiometricInvalidated<T> extends BiometricOutcome<T> {
  const new();
}

final class BiometricFailed<T> extends BiometricOutcome<T> {
  const new();
}

/// Parmak izi penceresinin metinleri.
final class BiometricTexts {
  const new({required this.title, required this.negativeButton});

  final String title;
  final String negativeButton;
}

/// Keystore köprüsü. Testlerde taklit edilebilsin diye arayüzdür.
abstract interface class BiometricBridge {
  Future<BiometricSupport> support();

  /// Yeni Keystore anahtarı üretir ve [plainText]'i sarar.
  Future<BiometricOutcome<StoredBiometricSlot>> wrap(
    Uint8List plainText,
    Uint8List associatedData,
    BiometricTexts texts,
  );

  Future<BiometricOutcome<Uint8List>> unwrap(
    StoredBiometricSlot slot,
    Uint8List associatedData,
    BiometricTexts texts,
  );

  Future<void> deleteKey();
}

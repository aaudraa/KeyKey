import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/platform/platform_api.g.dart',
    dartPackageName: 'keykey',
    kotlinOut:
        'android/app/src/main/kotlin/io/github/aaudraa/keykey/PlatformApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'io.github.aaudraa.keykey'),
  ),
)
/// Cihazın güçlü biyometri durumu.
enum BiometricAvailability { available, noHardware, notEnrolled, unavailable }

/// Parmak izi işleminin sonucu.
enum BiometricStatus { success, cancelled, lockedOut, invalidated, failed }

class BiometricPromptTexts {
  BiometricPromptTexts({required this.title, required this.negativeButton});

  String title;
  String negativeButton;
}

class BiometricWrapResult {
  BiometricWrapResult({required this.status, this.iv, this.cipherText});

  BiometricStatus status;
  Uint8List? iv;
  Uint8List? cipherText;
}

class BiometricUnwrapResult {
  BiometricUnwrapResult({required this.status, this.plainText});

  BiometricStatus status;
  Uint8List? plainText;
}

/// Kasa anahtarını Keystore'daki biyometriye bağlı anahtarla sarar ve açar.
///
/// Kurallar güvenlik tasarımı belgesinin Biyometri bölümündedir.
@HostApi()
abstract class BiometricApi {
  BiometricAvailability availability();

  /// Yeni Keystore anahtarı üretir ve parmak izi doğrulamasıyla sarar.
  @async
  BiometricWrapResult wrap(
    Uint8List plainText,
    Uint8List associatedData,
    BiometricPromptTexts texts,
  );

  @async
  BiometricUnwrapResult unwrap(
    Uint8List iv,
    Uint8List cipherText,
    Uint8List associatedData,
    BiometricPromptTexts texts,
  );

  void deleteKey();
}

/// Hassas metni panoya kopyalar ve süre dolunca temizler.
///
/// Kurallar ve sınırlar güvenlik tasarımı belgesinin Pano bölümündedir.
@HostApi()
abstract class ClipboardApi {
  void copySensitive(String text, int clearAfterMillis);
}

/// Başka uygulamaların şifreli dışa aktarma dosyalarını açmak için AES-GCM.
///
/// Kasanın şifrelemesinde kullanılmaz. Kurallar güvenlik tasarımı belgesinin
/// İçe aktarma bölümündedir.
@HostApi()
abstract class ImportCryptoApi {
  /// AES-256-GCM, 128 bitlik etiket şifreli metnin sonundadır. Etiket
  /// doğrulanmazsa `null` döner.
  Uint8List? aesGcmDecrypt(
    Uint8List key,
    Uint8List nonce,
    Uint8List cipherTextWithTag,
  );
}

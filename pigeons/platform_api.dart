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

/// Doldurma ekranını açan isteğin, kasaya bakmadan bilinen özeti.
///
/// Kurallar güvenlik tasarımı belgesinin Otomatik doldurma bölümündedir.
class AutofillRequestInfo {
  AutofillRequestInfo({
    required this.packageName,
    required this.appLabel,
    required this.certsSha256,
    required this.webDomain,
    required this.webScheme,
    required this.untrustedWebDomain,
    required this.inWebView,
    required this.hasUsernameField,
    required this.hasPasswordField,
    this.save,
  });

  /// Formu gösteren uygulama. Tarayıcıysa tarayıcının kendisi.
  String packageName;
  String? appLabel;

  /// Uygulamanın imza sertifikalarının SHA-256 özetleri, küçük harf
  /// onaltılık. Okunamadıysa boştur.
  List<String> certsSha256;

  /// Sayfanın alan adı; yalnızca güvenilen bir tarayıcıdan geldiyse dolu.
  String? webDomain;
  String? webScheme;

  /// Tarayıcı olmayan bir uygulamanın formu web alan adı bildiriyor
  /// (WebView). Eşleştirmede kullanılmaz, yalnızca uyarıda gösterilir.
  String? untrustedWebDomain;

  /// Tarayıcı olmayan bir uygulamanın formu bir web sayfasında (WebView).
  /// Bazı WebView sürümleri alan adını bildirmediği için ayrıca tutulur.
  bool inWebView;

  bool hasUsernameField;
  bool hasPasswordField;

  /// Ekran kaydetmek için açıldıysa formdaki değerler; doldurmada `null`.
  AutofillSaveValues? save;
}

/// Kullanıcının forma yazıp kaydetmeyi onayladığı değerler.
class AutofillSaveValues {
  AutofillSaveValues({required this.username, required this.password});

  String username;
  String password;
}

/// Otomatik doldurma ekranının Kotlin tarafı.
@HostApi()
abstract class AutofillApi {
  /// Ekranı açan istek. Ekran bir istekle açılmadıysa `null`.
  AutofillRequestInfo? currentRequest();

  /// Kayıtların uygulamaya bağlanabilmesi için verilen paketin imzası
  /// kayıttaki özetlerin hepsiyle tutuyor mu. İmza geçmişi de kabul edilir.
  bool hasSigningCertificates(String packageName, List<String> certsSha256);

  /// Değerleri forma verir ve ekranı kapatır.
  void fill(String username, String password);

  /// Hiçbir şey doldurmadan ekranı kapatır. Kaydetme bitince de kullanılır.
  void cancel();
}

/// Ana uygulamanın otomatik doldurma kurulumu durumu.
class AutofillSetupStatus {
  AutofillSetupStatus({
    required this.supported,
    required this.enabled,
    this.chromeMajorVersion,
  });

  /// Cihaz otomatik doldurmayı destekliyor.
  bool supported;

  /// Seçili otomatik doldurma servisi KeyKey.
  bool enabled;

  /// Kurulu Chrome'un ana sürümü; Chrome yoksa `null`.
  int? chromeMajorVersion;
}

/// Kurulum ekranının Kotlin tarafı: durum ve ayarlara doğrudan geçiş.
@HostApi()
abstract class AutofillSetupApi {
  AutofillSetupStatus status();

  /// Sistemin otomatik doldurma servisi seçimini açar. Açılamazsa `false`.
  bool openAutofillSettings();

  /// Chrome'un otomatik doldurma ayarını açar. Açılamazsa `false`.
  bool openChromeAutofillSettings();
}

/// Belge kaydetmenin veya açmanın sonucu.
enum DocumentStatus {
  /// İşlem tamamlandı.
  done,

  /// Kullanıcı seçiciden vazgeçti.
  cancelled,

  /// Seçilen dosya izin verilen boyuttan büyük.
  tooLarge,

  /// Yazma, okuma veya doğrulama başarısız oldu.
  failed,
}

/// Belge seçicinin sonucu. Açmada [bytes] yalnızca [status] `done` ise
/// doludur.
class DocumentResult {
  DocumentResult({required this.status, this.bytes});

  DocumentStatus status;
  Uint8List? bytes;
}

/// Android'in belge oluşturma ve açma ekranları (Storage Access Framework).
///
/// Depolama izni gerekmez; dosya uygulamanın klasörüne hiç yazılmaz.
@HostApi()
abstract class DocumentApi {
  /// Belge oluşturma ekranını açar, [bytes]'ı seçilen yere yazar, geri okuyup
  /// karşılaştırır. Tutmazsa yarım dosyayı silmeyi dener ve `failed` döner.
  @async
  DocumentResult save(String suggestedName, String mimeType, Uint8List bytes);

  /// Belge açma ekranını açar ve seçilen dosyayı okur. [maxBytes]'tan büyükse
  /// okumadan `tooLarge` döner.
  @async
  DocumentResult open(List<String> mimeTypes, int maxBytes);
}

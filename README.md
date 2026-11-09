# KeyKey

Android için çevrimdışı, açık kaynak parola yöneticisi ve 2FA doğrulama uygulaması.

*English: see the [security design summary](resources/docs/security-summary.md) and the [security policy](.github/SECURITY.md#security-policy).*

> [!WARNING]
> **KeyKey henüz yayımlanmadı.** Kurulabilir bir sürümü yok ve bağımsız bir güvenlik denetiminden geçmedi; projenin kendi güvenlik denetimi tamamlandı. İlk sürüme kadar gerçek parolalarını emanet etme.

## Neden KeyKey?

- **Verilerin sende kalır.** Sunucu ve hesap yok; her şey telefonunda şifreli olarak durur.
- **İnternete çıkmaz.** Uygulamanın internet izni yok, yani verini dışarı gönderemez. Bu her derlemede otomatik olarak denetleniyor.
- **Yedeğin senin kontrolünde.** Şifreli yedek dosyanı istediğin yere kendin kaydedersin.
- **Kodu açık.** Uygulamanın ne yaptığını herkes inceleyebilir.

## Özellikler

| Alan | Özellikler |
|---|---|
| **Parola kasası** | Kayıt ekleme ve düzenleme, arama, klasörler, çöp kutusu, parola üretici, güç ölçer; zayıf ve tekrar eden parolaları gösteren çevrimdışı parola raporu |
| **2FA doğrulama** | TOTP ve HOTP kodları, QR ile ekleme, Google Authenticator, Aegis ve 2FAS'tan aktarım, kodları göstermek için isteğe bağlı ek onay |
| **Otomatik doldurma** | Android uygulamalarında ve Chrome'da parola doldurma ve kaydetme; uygulamalar imza sertifikasıyla eşleşir, şüpheli durumlarda uyarı verilir |
| **Kilit** | Ana parola, parmak iziyle açma, otomatik kilitlenme, kurtarma anahtarı |
| **Yedekleme** | Şifreli yedek ve geri yükleme; Bitwarden, Chrome ve KeePassXC'den içe aktarma; başka bir parola yöneticisine geçmek için şifresiz dışa aktarma |

Bu özelliklerin hepsi geliştirme sürümünde çalışıyor. Her faz sonunda cihaz testleri dört Android sürümünde (11, 14, 16, 17) emülatörlerde çalışıyor, büyük değişiklikler gerçek bir telefonda da deneniyor. İlk sürüm Faz 9'da çıkacak. İlerlemeyi [yol haritasından](resources/yol-haritasi.md) ve [milestone'lardan](https://github.com/aaudraa/KeyKey/milestones) takip edebilirsin.

## Güvenlik yaklaşımı

- Kasanın şifrelemesi için kendi kriptografimizi yazmıyoruz; denenmiş [libsodium](https://libsodium.org) kütüphanesini kullanıyoruz.
- Ana parolandan anahtar türetmek için **Argon2id**, verileri şifrelemek için **XChaCha20-Poly1305** kullanılıyor.
- 2FA kodları (TOTP, HOTP) ve başka uygulamaların şifreli dışa aktarmalarını açmak için gereken birkaç standart algoritmayı biz uyguluyoruz; hepsi RFC test vektörleriyle doğrulanıyor.
- Ana parola hiçbir yerde saklanmaz. Onu ve kurtarma anahtarını birlikte kaybedersen verilerin geri getirilemez; bunu yapabilecek bir sunucu ya da arka kapı yok.

Ayrıntılar [güvenlik tasarımı belgesinde](resources/docs/guvenlik-tasarimi.md); neyin korunduğu ve neyin korunmadığı da orada, "Tehdit modeli" ve "Bilinen sınırlar" bölümlerinde. Projenin OWASP MASVS'e göre yaptığı kendi denetiminin sonuçları [denetim belgesinde](resources/docs/guvenlik-denetimi.md).

Bir güvenlik açığı bulursan lütfen [güvenlik politikasındaki](.github/SECURITY.md) adımları izle, herkese açık issue açma.

## Teknoloji

[Flutter](https://flutter.dev) ve Dart, Android'e özgü bölümler için Kotlin. Android 11 (API 30) ve üstünde çalışır.

## Geliştirme

Proje fazlar halinde ilerliyor ve her fazın kendi branch'i var. Çalışma düzeni için [yol haritasına](resources/yol-haritasi.md#çalışma-düzeni), katkı kuralları için [katkı rehberine](.github/CONTRIBUTING.md) bakabilirsin.

### Windows'ta kurulum

1. [Flutter](https://docs.flutter.dev/get-started) ve Android Studio'yu kur.
2. [Git for Windows](https://git-scm.com/install/windows) kurup `C:\Program Files\Git\bin` klasörünü PATH'e ekle.
3. GNU Make kur: `winget install ezwinports.make`
4. Visual Studio'yu "Desktop development with C++" iş yüküyle kur.
5. Düzenleyiciyi yeniden başlat, sonra çalıştır:

```powershell
flutter pub get
flutter test
flutter run

# Emülatör testleri, çalışan bir emülatör gerekir
flutter test integration_test -d <emülatör>

# Parmak izi, pano ve kamera betikleri dahil bütün cihaz testleri
bash resources/scripts/all-device-tests.sh <emülatör>
```

Repoyu `C:\KeyKey` gibi kısa bir yola klonla. Uzun yollarda libsodium derlemesi hata verebiliyor. Ayrıntılar yol haritasının [Geliştirme ortamı](resources/yol-haritasi.md#geliştirme-ortamı) bölümünde.

## Lisans

KeyKey, [GNU GPL v3.0](LICENSE) lisansıyla dağıtılır.

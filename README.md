# KeyKey

Android için çevrimdışı, açık kaynak parola yöneticisi ve 2FA doğrulama uygulaması.

> [!WARNING]
> **KeyKey henüz geliştirme aşamasında ve kullanıma hazır değil.** Kurulabilir bir sürümü yok, bağımsız bir güvenlik denetiminden de geçmedi. Şimdilik gerçek parolalarını emanet etme.

## Neden KeyKey?

- **Verilerin sende kalır.** Sunucu ve hesap yok; her şey telefonunda şifreli olarak durur.
- **İnternete çıkmaz.** Yayın sürümünde internet izni olmayacak, yani uygulama verini dışarı gönderemeyecek.
- **Yedeğin senin kontrolünde.** Şifreli yedek dosyanı istediğin yere kendin kaydedersin.
- **Kodu açık.** Uygulamanın ne yaptığını herkes inceleyebilir.

## Planlanan özellikler

| Alan | Özellikler |
|---|---|
| **Parola kasası** | Kayıt ekleme ve düzenleme, arama, klasörler, parola üretici, güç ölçer |
| **2FA doğrulama** | TOTP ve HOTP kodları, QR ile ekleme, Google Authenticator ve Aegis'ten aktarım |
| **Otomatik doldurma** | Android uygulamalarında ve tarayıcılarda parola doldurma ve kaydetme |
| **Kilit** | Ana parola, parmak izi ile açma, otomatik kilitlenme, kurtarma anahtarı |
| **Yedekleme** | Şifreli yedek ve geri yükleme, Bitwarden ve Chrome'dan içe aktarma |

Bunların hiçbiri henüz hazır değil. İlerlemeyi [yol haritasından](resources/yol-haritasi.md) ve [milestone'lardan](https://github.com/aaudraa/KeyKey/milestones) takip edebilirsin.

## Güvenlik yaklaşımı

- Kriptografi için kendi algoritmalarımızı yazmıyoruz; denenmiş [libsodium](https://libsodium.org) kütüphanesini kullanıyoruz.
- Ana parolandan anahtar türetmek için **Argon2id**, verileri şifrelemek için **XChaCha20-Poly1305** kullanılacak.
- Ana parola hiçbir yerde saklanmaz. Onu ve kurtarma anahtarını birlikte kaybedersen verilerin geri getirilemez; bunu yapabilecek bir sunucu ya da arka kapı yok.

Bir güvenlik açığı bulursan lütfen [güvenlik politikasındaki](.github/SECURITY.md) adımları izle, herkese açık issue açma.

## Teknoloji

[Flutter](https://flutter.dev) ve Dart, Android'e özgü bölümler için Kotlin. En düşük Android sürümü Android 11 (API 30) olacak.

## Geliştirme

Proje fazlar halinde ilerliyor ve her fazın kendi branch'i var. Çalışma düzeni için [yol haritasına](resources/yol-haritasi.md#çalışma-düzeni), katkı kuralları için [katkı rehberine](.github/CONTRIBUTING.md) bakabilirsin.

## Lisans

KeyKey, [GNU GPL v3.0](LICENSE) lisansıyla dağıtılır.

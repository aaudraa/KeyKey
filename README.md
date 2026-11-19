# KeyKey

Android için çevrimdışı, açık kaynak parola yöneticisi ve 2FA doğrulama uygulaması.

*English: see the [security design summary](resources/docs/security-summary.md), the [privacy policy](resources/docs/privacy.md) and the [security policy](.github/SECURITY.md#security-policy).*

<p>
  <img src="resources/design/kilavuz/04-kasa-listesi.webp" width="200" alt="Kasa listesi">
  <img src="resources/design/kilavuz/09-2fa-kodlari.webp" width="200" alt="2FA kodları">
  <img src="resources/design/kilavuz/08-parola-uretici.webp" width="200" alt="Parola üretici">
  <img src="resources/design/kilavuz/15-koyu-tema.webp" width="200" alt="Koyu tema">
</p>

> [!IMPORTANT]
> KeyKey 1.0 yayında. Projenin kendi güvenlik denetimi tamamlandı ama bağımsız bir denetimden geçmedi. Şifreli yedeğini düzenli al ve telefonun dışında da sakla.

## Neden KeyKey?

- **Verilerin sende kalır.** Sunucu ve hesap yok; her şey telefonunda şifreli olarak durur.
- **İnternete çıkmaz.** Uygulamanın internet izni yok, yani verini dışarı gönderemez. Bu her derlemede otomatik olarak denetleniyor.
- **Yedeğin senin kontrolünde.** Şifreli yedek dosyanı istediğin yere kendin kaydedersin.
- **Kodu açık.** Uygulamanın ne yaptığını herkes inceleyebilir; derleme yeniden üretilebilir.

## Kurulum

KeyKey Android 11 ve üstünde çalışır.

- **GitHub:** [son sürümü indir](https://github.com/aaudraa/KeyKey/releases/latest) (`keykey-<sürüm>.apk`). İndirdiğin APK'yı [doğrulamak](resources/docs/yayin.md) için imza sertifikasının SHA-256 özeti:

  ```
  66ff7b5c0c009a8530d0a55dd1d80a3af35de48bd0667c456a0cf86a6d1129a0
  ```

- **Obtainium:** [Obtainium'a ekle](https://apps.obtainium.imranr.dev/redirect?r=obtainium://app/%7B%22id%22%3A%22io.github.aaudraa.keykey%22%2C%22url%22%3A%22https%3A%2F%2Fgithub.com%2Faaudraa%2FKeyKey%22%2C%22author%22%3A%22aaudraa%22%2C%22name%22%3A%22KeyKey%22%7D); yeni sürümler GitHub'dan kendiliğinden gelir.
- **F-Droid:** Şimdilik yok. İlk başvuru 2026-11-18'de kabul edilmedi ([fdroiddata!57995](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/57995)): F-Droid en az 3 aylık geliştirme istiyor ve KeyKey'i benzerlerinden yeterince farklı bulmadı. Derleme F-Droid'in aracıyla birebir aynı çıkmaya devam ediyor; yeniden başvurmak proje sahibinin kararı.

Eski bir `v0.x` deneme sürümü kullanıyorsan önce [geçiş adımlarını](resources/docs/yayin.md#eski-sürümlerden-geçiş) oku. İlk kasa, otomatik doldurma, 2FA, yedekleme ve bilinen sınırlar ekran görüntüleriyle [kullanım kılavuzunda](resources/docs/kullanim.md).

## Özellikler

| Alan | Özellikler |
|---|---|
| **Parola kasası** | Kayıt ekleme ve düzenleme, arama, klasörler, çöp kutusu, parola üretici, güç ölçer; zayıf ve tekrar eden parolaları gösteren çevrimdışı parola raporu |
| **Kartlar ve notlar** | Banka kartları (numara, son kullanma, güvenlik kodu, PIN; marka numaradan anlaşılır) ve güvenli notlar; parolalarla aynı listede, klasörlerde ve çöp kutusunda |
| **2FA doğrulama** | TOTP ve HOTP kodları, QR ile ekleme, Google Authenticator, Aegis ve 2FAS'tan aktarım, kodları göstermek için isteğe bağlı ek onay |
| **Otomatik doldurma** | Android uygulamalarında ve Chrome'da parola doldurma ve kaydetme; uygulamalar imza sertifikasıyla eşleşir, şüpheli durumlarda uyarı verilir |
| **Kilit** | Ana parola, parmak iziyle açma, otomatik kilitlenme, kurtarma anahtarı |
| **Yedekleme** | Şifreli yedek, otomatik yedek ve geri yükleme; Bitwarden (kart ve notlar dahil), Chrome, Firefox ve KeePassXC'den içe aktarma; başka bir parola yöneticisine geçmek için şifresiz dışa aktarma (CSV ya da kartlar dahil JSON) |
| **Görünüm** | Açık, koyu ya da sistem teması; Türkçe ve İngilizce |

## Güvenlik yaklaşımı

- Kasanın şifrelemesi için kendi kriptografimizi yazmıyoruz; denenmiş [libsodium](https://libsodium.org) kütüphanesini kullanıyoruz.
- Ana parolandan anahtar türetmek için **Argon2id**, verileri şifrelemek için **XChaCha20-Poly1305** kullanılıyor.
- 2FA kodları (TOTP, HOTP) ve başka uygulamaların şifreli dışa aktarmalarını açmak için gereken birkaç standart algoritmayı biz uyguluyoruz; hepsi RFC test vektörleriyle doğrulanıyor.
- Ana parola hiçbir yerde saklanmaz. Onu ve kurtarma anahtarını birlikte kaybedersen verilerin geri getirilemez; bunu yapabilecek bir sunucu ya da arka kapı yok.
- KeyKey hiçbir veri toplamaz ([gizlilik bildirimi](resources/docs/gizlilik.md)).

Neyin korunduğu ve neyin korunmadığı [güvenlik tasarımı belgesinin](resources/docs/guvenlik-tasarimi.md) "Tehdit modeli" ve "Bilinen sınırlar" bölümlerinde. Projenin OWASP MASVS'e göre yaptığı kendi denetiminin sonuçları [denetim belgesinde](resources/docs/guvenlik-denetimi.md).

Bir güvenlik açığı bulursan lütfen [güvenlik politikasındaki](.github/SECURITY.md) adımları izle, herkese açık issue açma.

## Proje hakkında

KeyKey'in kodunun büyük kısmı bir yapay zekâ kodlama asistanıyla yazıldı; yönü ve kararları proje sahibi belirledi, uygulamayı kendi telefonunda kullanarak denedi. Bu yüzden testlere, belgelenmiş kararlara ve dışarıdan incelemeye ayrıca önem veriliyor: 1600'den fazla birim testi ve Android 11, 14 ve 17 emülatörlerinde çalışan cihaz testleri her değişiklikte koşuyor. İnceleme ve geri bildirim için [issue'lar](https://github.com/aaudraa/KeyKey/issues) açık.

| Belge | İçerik |
|---|---|
| [Kullanım kılavuzu](resources/docs/kullanim.md) | Kurulumdan yedeklemeye adım adım, ekran görüntüleriyle |
| [Güvenlik tasarımı](resources/docs/guvenlik-tasarimi.md) | Tehdit modeli, anahtar hiyerarşisi, bilinen sınırlar |
| [Güvenlik denetimi](resources/docs/guvenlik-denetimi.md) | OWASP MASVS'e göre kendi denetimimiz |
| [Yayın ve doğrulama](resources/docs/yayin.md) | Sürüm numarası, imza, yeniden üretilebilir derleme |
| [Bağımlılıklar](resources/docs/bagimliliklar.md) | Kullanılan paketler, lisanslar, derlemede indirilenler |
| [Değişiklik günlüğü](resources/CHANGELOG.md) | Sürümlerde ne değişti |
| [Yol haritası](resources/yol-haritasi.md) | Fazlar, kararlar, sıradaki işler |

## Teknoloji

[Flutter](https://flutter.dev) ve Dart, Android'e özgü bölümler için Kotlin. Kasa, SQLite (kaynaktan derlenir) üstünde kayıt kayıt şifreli tutulur.

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

© 2026 KeyKey geliştiricileri. KeyKey, [GNU GPL v3.0](LICENSE) lisansıyla dağıtılır: kaynak kodunu inceleyebilir, değiştirebilir ve aynı lisansla paylaşabilirsin. KeyKey **hiçbir garanti olmadan**, olduğu gibi sunulur (lisansın 15. ve 16. maddeleri). Uygulamayı ilk açtığında [kullanım koşulları](resources/docs/kosullar.md) ([English](resources/docs/terms.md)) gösterilir. Kullanılan kütüphanelerin lisansları uygulamada Ayarlar → Hakkında → Lisanslar'da ve [bağımlılıklar belgesinde](resources/docs/bagimliliklar.md).

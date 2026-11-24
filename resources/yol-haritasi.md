# KeyKey Yol Haritası

KeyKey, Android için açık kaynak bir parola yöneticisi ve 2FA doğrulama uygulaması. 1.5.0'a kadar tamamen çevrimdışıydı; 2026-11-19'da internet gerektiren özelliklere de açılma kararı alındı ([İnternet](#temel-kararlar)). Bu belge neyi, hangi sırayla ve neden yaptığımızın tek kaynağıdır. Her faz bittiğinde güncellenir.

**Son güncelleme:** 2026-11-23 · **Şu anki faz:** 25 bitti; sıradaki 21, passkey sağlayıcısı. [1.10.0](https://github.com/aaudraa/KeyKey/releases/tag/v1.10.0) yayında (uygulama ve site eşleştirme: Android'in doğruladığı siteler ve isteğe bağlı `assetlinks.json` doğrulaması, [#178](https://github.com/aaudraa/KeyKey/issues/178); koşullar sürüm 4, yedek içerik sürümü 5; küçük bulgular [#182](https://github.com/aaudraa/KeyKey/issues/182)'de). [1.9.0](https://github.com/aaudraa/KeyKey/releases/tag/v1.9.0) yayında (KeePass `.kdbx` dosyalarını doğrudan açıp içe aktarma, [#177](https://github.com/aaudraa/KeyKey/issues/177); Argon2 yerel kodda, F-Droid karşılaştırması yeşil). [1.8.2](https://github.com/aaudraa/KeyKey/releases/tag/v1.8.2) yayında (düzeltme sürümü: ultra review'a girmeyen arayüz kodunun incelemesi, [#173](https://github.com/aaudraa/KeyKey/issues/173); kalan dört küçük bulgu [#174](https://github.com/aaudraa/KeyKey/issues/174)'te). [1.8.1](https://github.com/aaudraa/KeyKey/releases/tag/v1.8.1) (düzeltme sürümü: projenin bütününün ultra review bulguları, [#168](https://github.com/aaudraa/KeyKey/issues/168); gömülü çerçeveye parola yazılmaması N9 gerçek Chrome'da denendi; navbar yalnızca simge, #163). [1.8.0](https://github.com/aaudraa/KeyKey/releases/tag/v1.8.0) (kendi WebDAV sunucusu üzerinden uçtan uca şifreli senkron, senkrondan kurma, başka kasası olan telefonu katma; Nextcloud ile ilk deneme ve 1.4.0'dan beri gelenlerle birlikte telefon denemesi Obtainium güncellemesinden sonra); otomatik yedek ve yeni kurtarma anahtarı proje sahibinin telefonunda denendi; F-Droid başvurusu ([fdroiddata!57995](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/57995)) kabul edilmedi

> [!IMPORTANT]
> **KeyKey 1.0 yayında.** Projenin kendi güvenlik denetimi tamamlandı, ama bağımsız bir denetim yapılmadı. Şifreli yedeğini düzenli al ve telefonun dışında da sakla.

**Bu belgede:** [Durum](#durum) · [Temel kararlar](#temel-kararlar) · [Teknoloji seçimleri](#teknoloji-seçimleri) · [Mimari](#mimari) · [Güvenlik tasarımı](#güvenlik-tasarımı) · [Çalışma düzeni](#çalışma-düzeni) · [Fazlar](#fazlar) · [1.0 sonrası](#10-sonrası) · [Riskler](#riskler)

## Durum

| Faz | Konu | Büyüklük | Önce bitmeli | Branch | Durum |
|---|---|---|---|---|---|
| 0 | Repo ve GitHub altyapısı | S | — | `faz/0-repo-altyapisi` | Tamamlandı |
| 1 | Flutter iskeleti ve CI | M | 0 | `faz/1-flutter-iskeleti` | Tamamlandı |
| 2 | Kripto çekirdeği | L | 1 | `faz/2-kripto-cekirdegi` | Tamamlandı |
| 3 | Kasa, kilit ve biyometri | L | 2 | `faz/3-kasa-ve-kilit` | Tamamlandı |
| 4 | Parola kasası | L | 3 | `faz/4-parola-kasasi` | Tamamlandı |
| 5 | 2FA doğrulayıcı | M | 3 | `faz/5-2fa-dogrulayici` | Tamamlandı |
| 6 | Otomatik doldurma | XL | 4 | `faz/6-otomatik-doldurma` | Tamamlandı |
| 7 | Yedekleme, içe ve dışa aktarma | L | 4, 5 | `faz/7-yedekleme` | Tamamlandı |
| 8 | Güvenlik sertleştirme ve denetim | L | 6, 7 | `faz/8-guvenlik-denetimi` | Tamamlandı |
| 9 | 1.0 yayını | M | 8 | `faz/9-yayin` | Tamamlandı |
| 10 | F-Droid ve Obtainium | M | 9 | `faz/10-f-droid` | Tamamlandı |
| 11 | Kullanıcı gözüyle iyileştirmeler | M | 10 | `faz/11-kullanici-gozuyle` | Tamamlandı |
| 12 | Otomatik yedek | M | 11 | `faz/12-otomatik-yedek` | Tamamlandı (1.2.0) |
| 13 | Yeni kurtarma anahtarı | S | 12 | `faz/13-kurtarma-anahtari` | Tamamlandı (1.3.0) |
| 14 | Kart ve güvenli not kayıtları | L | 13 | `faz/14-kart-ve-not` | Tamamlandı (1.4.0) |
| 15 | Kart doldurma | M | 14 | `faz/15-kart-doldurma` | Tamamlandı (1.5.0) |
| 16 | İnternete açılma ve sızıntı kontrolü | M | 14 | `faz/16-internet` | Tamamlandı (1.6.0) |
| 17 | Kartlar ve notlar için gezinme | S | 14 | `faz/17-gezinme` | Tamamlandı (1.6.0) |
| 18 | Kilit süresi, klavye, toplu seçim, Steam Guard | M | 14 | `faz/18-kullanim-kolayligi` | Tamamlandı (1.7.0) |
| 19 | Senkron (WebDAV; Google Drive ayrı) | XL | 16 | `faz/19-senkron` | Tamamlandı (1.8.0) |
| 20 | KeePass (`.kdbx`) içe aktarma | L | 14 | `faz/20-keepass` | Bitti (1.9.0) |
| 21 | Passkey sağlayıcısı | XL | 15 | `faz/21-passkey` | Sıradaki |
| 22 | İşlemciye göre APK ve kendi F-Droid deposu | M | — | `faz/22-dagitim` | Planlandı |
| 23 | KeyKey klavyesi | XL | 15 | `faz/23-klavye` | Planlandı |
| 24 | Windows sürümü | XL | 19 | `faz/24-windows` | Planlandı |
| 25 | Uygulama ve site eşleştirme | M | 16 | `faz/25-uygulama-site` | Bitti (1.10.0) |

Büyüklük göreli iş miktarını gösterir, takvim sözü değildir. Faz 4 ve 5 aynı anda ilerleyebilir. Faz 14'ten sonraki sıra ve gerekçesi [1.0 sonrası](#10-sonrası) bölümünde; dal adları faz başlayınca kesinleşir. İlerlemeyi [milestone'lardan](https://github.com/aaudraa/KeyKey/milestones) da izleyebilirsin.

## Temel kararlar

| Konu | Karar | Neden |
|---|---|---|
| Platform | Önce yalnızca Android | Test ortamı hazır ve otomatik doldurma en çok telefonda işe yarıyor. iOS için Mac gerekiyor; o ve Windows sürümü 1.0 sonrasına kaldı. |
| En düşük sürüm | Android 11 (API 30) | Elimizdeki en eski emülatör bu ve test edemediğimiz sürümü desteklemek istemiyoruz. Satır içi otomatik doldurma önerileri de bu sürümle geldi. |
| Veri | Cihazda ve kullanıcının seçtiği yerde; bizim sunucumuz ve hesabımız yok | Saldırı yüzeyi küçülür, sunucu maliyeti olmaz, başkasının verisini koruma yükü doğmaz. Senkron gelince (Faz 18) veri kullanıcının kendi WebDAV sunucusuna ya da Drive'ına, uçtan uca şifreli gider. |
| İnternet | **2026-11-19'da değişti.** İnternet gerektiren özellikler eklenecek. Her biri kullanıcı açınca çalışır, varsayılan kapalıdır; kasadan çıkan veri uçtan uca şifrelidir ya da parolayı göndermeyen bir yöntemle (k-anonimlik) gider. `INTERNET` izni ilk böyle özellikle (Faz 16) gelir; o zamana kadar yayın sürümünde izin yok ve CI bunu denetliyor. | 1.3.0'a kadarki karar "izin yoksa uygulama veriyi dışarı gönderemez" idi. F-Droid başvurusu "benzersiz özellik yok" gerekçesiyle reddedildi; proje sahibi çevrimdışı nişin dışına çıkıp senkron ve sızıntı kontrolü gibi özellikleri istedi ("internete açalım ... kaldıralım sloganımızdan"). Varsayılanın kapalı olması, interneti istemeyen kullanıcıya bugünkü davranışı korur. README'deki "İnternete çıkmaz" sözü, gizlilik bildirimi, koşullar ve uygulama içi metinler izinle aynı fazda değişir; arada yanlış bir metin kalmaz. |
| Cihazlar arası geçiş | Kullanıcının kaydettiği şifreli yedek dosyası; 1.8.0'dan beri isteyen için kendi WebDAV sunucusu üzerinden uçtan uca şifreli senkron | Android dosya seçicisiyle Drive'a bile kaydedilebilir ve internet izni gerektirmez. Otomatik yedek (1.2.0) aynı dosyayı seçilen klasöre kendiliğinden yazıyor. |
| Lisans | GPL-3.0 | Değiştirip dağıtan herkes kaynak kodunu da açmak zorunda. Aegis ve KeePassDX de aynı lisansı kullanıyor. |
| Dil | Repo Türkçe, koddaki adlar İngilizce, arayüz Türkçe ve İngilizce | Proje Türkçe yürüyor; kodda İngilizce ad kullanmak Dart ve Flutter dünyasının standardı. |
| Paket kimliği | `io.github.aaudraa.keykey` | Alan adı gerektirmez ve GitHub hesabına bağlıdır. **Play Store'a çıktıktan sonra değiştirilemez.** |

## Teknoloji seçimleri

Sürümler ve lisanslar 2026-11-05 tarihinde pub.dev'den kontrol edildi. Faz başlarken yeniden gözden geçirilir.

| İhtiyaç | Seçim | Sürüm | Lisans | Neden |
|---|---|---|---|---|
| Uygulama çatısı | Flutter ve Dart | 3.47.9 / 3.13.7 | BSD-3 | CI aynı sürüme sabitlenir. |
| Android'e özgü kod | Kotlin | — | — | Otomatik doldurma ve Keystore gibi işler Flutter'dan yapılamıyor. |
| Durum yönetimi | `flutter_riverpod` | 3.4.3 | MIT | Yaygın ve test etmesi kolay. |
| Yönlendirme | `go_router` | 18.1.3 | BSD-3 | Flutter ekibinin paketi. |
| Veritabanı | `drift` ve `sqlite3` | 2.35.3 / 3.9.0 | MIT | Tür güvenli sorgular ve hazır veritabanı göçleri. |
| Uygulama klasörü | `path_provider` | 2.1.6 | BSD-3 | Flutter ekibinin paketi; veritabanının özel klasördeki yerini bulur. |
| Kriptografi | `sodium` (libsodium 1.0.22) | 4.1.2+1 | BSD-3, ISC | Argon2id, XChaCha20-Poly1305, HKDF ve korumalı bellek tek pakette. [Doğrulandı](#libsodium-doğrulaması). |
| 2FA hesaplama | Kendi kodumuz ve `crypto` | 3.0.8 | BSD-3 | Algoritma kısa ve RFC test vektörleriyle doğrulanabiliyor; ek bağımlılığa gerek yok. |
| QR okuma | `flutter_zxing` | 3.1.0 | MIT; içindeki zxing-cpp Apache-2.0, zint BSD-3 | Açık kaynak, tamamen cihazda çalışıyor. Gömülü C++ kitaplıklarının lisansları uygulamanın lisans sayfasına elle eklenir. |
| Kamera | `camera` | 0.12.2 | BSD-3 | Flutter ekibinin paketi, `flutter_zxing` tarama için kullanıyor. Eklediği mikrofon ve depolama izinleri manifestte kaldırılır. |
| Görsel ve dosya seçme | `image_picker`, `file_selector` | 1.2.4 / 1.1.0 | BSD-3 | Flutter ekibinin paketleri. Android'in seçicilerini açar, depolama izni gerekmez. |
| Dart-Kotlin köprüsü | `pigeon` | 30.0.4 | BSD-3 | Elle yazılan kanallara göre tür güvenli. Üretilen Dart dosyası ayrıca `dart format`'tan geçirilir. |
| Parmak izi | `androidx.biometric` | 1.1.0 | Apache-2.0 | Google'ın kitaplığı. Son kararlı sürüm, daha yenileri beta. |
| Köprü çalışma zamanı | `kotlinx-coroutines-android` | 1.11.0 | Apache-2.0 | `pigeon`'un ürettiği Kotlin kodu bunu gerektiriyor. |
| Sözcük listeleri | EFF büyük liste, SecLists 10k | — | CC BY 3.0, MIT | Veri olarak; kaynak ve özet değerleri `resources/assets/wordlists/KAYNAKLAR.md` içinde. |
| Kod kalitesi | `very_good_analysis` | 11.0.0 | MIT | Sıkı lint kuralları. |
| Test | `flutter_test`, `integration_test` | SDK | BSD-3 | Birim, widget ve emülatör testleri. Taklit nesneler gerektiğinde `mocktail` eklenecek. |

### Bilerek kullanmadığımız paketler

| Paket | Neden |
|---|---|
| `mobile_scanner` | Android'de kapalı kaynak Google ML Kit kullanıyor. Bu, GPL-3.0 ve çevrimdışı hedefimizle çelişiyor. |
| `flutter_autofill_service` | AGPL-3.0 lisanslı: kullanırsak uygulama AGPL koşullarına da uymak zorunda kalır. Ayrıca projenin en kritik kodunu kendimiz yazmak istiyoruz. Kodundan kopya da almıyoruz. |
| `local_auth` | Yalnızca "doğrulandı" veya "doğrulanmadı" sonucu döndürüyor, şifreleme anahtarını parmak izine bağlamıyor. |
| `biometric_storage` | Son sürümü Şubat 2024'ten; güvenlik kodunda bakımsız pakete güvenmek istemiyoruz. |
| `flutter_secure_storage` | Biyometrik modu ayarına göre cihaz PIN'ini kabul ediyor veya biyometri olmadan da çalışabiliyor. Bize yalnızca güçlü biyometriye bağlı ve yeni parmak izinde geçersiz olan bir anahtar gerekiyor, bunu kendi Keystore köprümüzle sağlıyoruz. |
| `zxcvbn` | Dart 3 ile uyumlu değil (`sdk <3.0.0`). |
| `sodium_libs` | Kullanımdan kalktı, yerini `sodium` aldı. |
| `pointycastle` | Şifreli Aegis ve 2FAS dosyalarını açmak için yalnızca scrypt, PBKDF2 ve AES-GCM gerekiyor. Büyük bir saf Dart kripto kütüphanesi yerine AES-GCM için Android'in kitaplığını, scrypt ve PBKDF2 için RFC 7914 vektörleriyle doğrulanan kısa kendi kodumuzu kullanıyoruz. |
| `sqlite3_flutter_libs` | Kullanım ömrü bitti, `sqlite3` paketi yerel kütüphaneyi artık kendisi sağlıyor. Derlemede GitHub'dan hazır dosya indiriyor ve paketin içindeki SHA-256 ile doğruluyor. Aynı yayıncının Dart kodu zaten uygulamanın içinde çalıştığı için bu, güvenmemiz gereken kişiyi değiştirmiyor. Faz 9'dan beri uygulamadaki SQLite repodaki kaynaktan derleniyor (#99); hazır dosya yalnızca bilgisayardaki testlerde kullanılıyor. |

### libsodium doğrulaması

`sodium` paketi libsodium'u derleme sırasında kaynak koddan ürettiği için, karar vermeden önce 2026-11-04'te geliştirme bilgisayarında atılacak bir deneme projesiyle sınandı.

| Deneme | Sonuç |
|---|---|
| Windows'tan Android derlemesi (`arm64-v8a`, `x86_64`) | Çalışıyor. Temiz derleme yaklaşık 6 dakika, kod değişince sonraki derleme 13 saniye. |
| Bilgisayarda `flutter test` ile kripto testi | Çalışıyor, 3-4 saniye sürüyor. |
| Android 11, 14, 16 ve 17 emülatörlerinde çalıştırma | Argon2id ve XChaCha20-Poly1305 hepsinde çalışıyor. Yanlış bağlam verisiyle şifre çözmenin reddedilmesi ve HKDF, Android 14 dışındakilerde ayrıca denendi. |
| Uygulamaya eklenen boyut | `arm64-v8a` için 336 KB, `x86_64` için 454 KB. |

Argon2id (64 MiB, 3 geçiş), Faz 2 ölçümlerinde emülatörlerde 97-152 ms, gerçek telefonda (Samsung Galaxy S20 FE) 233-235 ms sürdü. Ayrıntılar [güvenlik tasarımında](docs/guvenlik-tasarimi.md#ölçülen-süreler). Bu bölümün ilk halindeki 0,8-1,3 saniyelik emülatör değeri Faz 2 ölçümlerinde tekrarlanmadı, nedeni araştırılmadı.

**Dikkat:** Proje klasörünün yolu kısa olmalı. Yol uzun olduğunda libsodium yedek bir derleme yöntemine geçiyor ve ikinci derlemede `PathExistsException` hatası veriyor. `C:\KeyKey` bu sorunu yaşamıyor.

### Geliştirme ortamı

Windows'ta projeyi derlemek ve test etmek için şunlar gerekli:

| Araç | Neden gerekli |
|---|---|
| Flutter ve Android SDK | Uygulamayı derlemek ve çalıştırmak için. |
| Git Bash (`C:\Program Files\Git\bin` PATH'te) | libsodium'un Android derlemesi için. |
| GNU Make (`winget install ezwinports.make`) | libsodium'un Android derlemesi için. |
| Visual Studio, "Desktop development with C++" | `flutter test` libsodium'u Windows için de derliyor. Bu olmadan en basit test bile çalışmıyor. |

`flutter doctor`'ın Chrome uyarısı önemsiz: projenin web hedefi yok.

## Mimari

```text
KeyKey/
├── android/                Android projesi ve Kotlin kodu
├── lib/
│   ├── main.dart
│   ├── app/                Uygulama kabuğu: yönlendirme, tema
│   ├── core/
│   │   ├── crypto/         Anahtar hiyerarşisi ve şifreleme
│   │   ├── storage/        Veritabanı ve göçler
│   │   ├── vault/          Kasa servisi: oluşturma, açma, bekleme
│   │   └── platform/       Kotlin köprüleri (Keystore, pano)
│   ├── features/
│   │   ├── onboarding/     Kasa oluşturma
│   │   ├── lock/           Kilit açma ve otomatik kilit
│   │   ├── vault/          Parola kayıtları
│   │   ├── generator/      Parola üretici
│   │   ├── authenticator/  2FA kodları
│   │   ├── autofill/       Otomatik doldurma ekranları
│   │   ├── backup/         Yedek, içe ve dışa aktarma
│   │   └── settings/       Ayarlar
│   └── l10n/               Türkçe ve İngilizce metinler
├── pigeons/                Dart-Kotlin köprü tanımları
├── test/                   Birim ve widget testleri
├── integration_test/       Emülatörde çalışan uçtan uca testler
├── resources/              Proje kodu dışındaki her şey
│   ├── yol-haritasi.md     Bu belge
│   ├── docs/               Tasarım ve denetim belgeleri
│   ├── design/             Logo ve tasarım kaynakları
│   └── scripts/            Yardımcı betikler
└── .github/                Issue ve PR şablonları, CI
```

Klasörler içine kod girdikçe açılır, boş klasör tutulmaz.

**Dosya düzeni kuralı:** Proje kodu dışındaki her şey `resources/` altında durur. Kök dizinde yalnızca çalışması için orada olması gereken dosyalar kalır: `README.md`, `CLAUDE.md`, `LICENSE`, `.gitignore`, `.gitattributes`, `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `l10n.yaml` ve Flutter'ın `.metadata` dosyası. `.github/` da GitHub onu yalnızca orada aradığı için köktedir.

**Katman kuralları:**

- Her özellik kendi klasöründe `presentation` (ekranlar), `application` (durum ve iş akışı) ve `data` (depolama) olarak ayrılır.
- Ekranlar veritabanına ve kriptoya doğrudan erişemez; yalnızca `application` katmanıyla konuşur.
- `core/crypto` Flutter'a bağımlı olamaz. Anahtarlar bu katmandan ham bayt olarak çıkmaz.

## Güvenlik tasarımı

Bu bölüm tasarımın özeti. Ayrıntılı belge: [`resources/docs/guvenlik-tasarimi.md`](docs/guvenlik-tasarimi.md).

### Tehdit modeli

Özet. Varlıklar, saldırganlar ve kapsam dışı olanlarla ayrıntılı model [güvenlik tasarımı belgesinde](docs/guvenlik-tasarimi.md#tehdit-modeli).

| Senaryo | KeyKey korur mu? | Nasıl |
|---|---|---|
| Telefon kilitli haldeyken çalındı veya kayboldu | Evet | Kasa diskte şifreli, anahtar ana paroladan türetiliyor ve diskte durmuyor. |
| Yedek dosyası başkasının eline geçti | Parola güçlüyse evet | Argon2id deneme yanılmayı çok yavaşlatır, ama zayıf bir parola yine de kırılabilir. |
| Başka bir uygulama kasayı okumaya çalışıyor | Evet | Android uygulama yalıtımı ve kasa şifrelemesi. |
| Sahte uygulama veya site parolayı istiyor | Büyük ölçüde | Uygulama imzası ve alan adı eşleştirmesi, doldurmadan önce kullanıcı onayı. |
| Ekran görüntüsü ve ekran kaydı | Evet | `FLAG_SECURE`. |
| Başka bir uygulama panoyu okuyor | Kısmen | Pano bir süre sonra temizlenir ve hassas olarak işaretlenir. Kopyalama anında aktif bir klavye veya kötü amaçlı uygulama yine görebilir. |
| Bindirme izni olan uygulama kullanıcıya istemediği bir şeye dokunduruyor | Evet | Android 12+ bindirmeler gizlenir; Android 11'de örtülü dokunuş düşürülür. |
| Erişilebilirlik izni olan zararlı uygulama ekranı okuyor | Android 14+ evet, 11-13 **hayır** | `FLAG_SECURE` bunu engellemez. Android 14+ pencere hassas işaretli; yalnızca TalkBack gibi araçlar okuyabilir. |
| Kötü niyetli klavye | **Hayır** | Yazılan her şeyi görür. Gizli alanlarda öğrenme kapalı, bu yalnızca dürüst klavyeleri etkiler. |
| Telefon root'lu veya zararlı yazılım bulaşmış, kasa açık | **Hayır** | Kasa açıkken anahtar bellekte durur. Hiçbir uygulama bunu tam olarak önleyemez. |
| Ana parola ve kurtarma anahtarı birlikte kayboldu | **Hayır** | Veri geri getirilemez. Bu bilinçli bir tasarım: arka kapı yok. |

### Anahtar hiyerarşisi

```text
Ana parola ── Argon2id ──► Parola anahtarı ─┐
Kurtarma anahtarı (rastgele 256 bit) ───────┼─ sarar ─► Kasa anahtarı (rastgele 256 bit)
Parmak izi ── Android Keystore anahtarı ────┘                     │
                                                             HKDF-SHA256
                                                    ┌─────────────┴─────────────┐
                                             Kayıt anahtarı               2FA anahtarı
```

- **Kasa anahtarı rastgeledir ve kapıları ayrıdır.** Ana parola değişince yalnızca sarmalama yenilenir, tüm kayıtları yeniden şifrelemek gerekmez. Parola, kurtarma anahtarı ve parmak izi aynı kasa anahtarını açan üç ayrı kapı gibi çalışır.
- **Argon2id:** Başlangıç değerleri 64 MiB bellek ve 3 geçiş. Değerler kasa üst bilgisinde saklanır, cihaza göre yükseltilebilir ama bu tabanın altına inilmez.
- **Şifreleme:** XChaCha20-Poly1305. Her kayıt için rastgele 24 baytlık nonce kullanılır. Kasa kimliği, kayıt kimliği, tür ve biçim sürümü ek doğrulama verisi olarak bağlanır; böylece bir kaydın şifreli verisi başka bir kaydın yerine konamaz.
- **Üst veriler de şifrelidir.** Başlık, kullanıcı adı ve URL şifreli verinin içindedir, böylece dosyayı ele geçiren hangi sitelerde hesabın olduğunu göremez. Şifresiz kalanlar yalnızca kayıt kimliği, tür, zaman damgaları ve biçim sürümü; yani kayıt sayısı ve değişim zamanları görülebilir.
- **Parmak izi:** Android Keystore'da üretilen ve çıkarılamayan AES-256-GCM anahtarı, kasa anahtarını sarar. Anahtar `BIOMETRIC_STRONG` doğrulaması ve `CryptoObject` olmadan kullanılamaz. Yeni parmak izi eklenirse anahtar geçersiz olur ve ana parola istenir. Varsa StrongBox kullanılır.
- **Kurtarma anahtarı:** Kasa oluşturulurken bir kez gösterilir ve kullanıcıya geri yazdırılarak doğrulanır. KeyKey bunu saklamaz, yalnızca onunla sarılmış kasa anahtarını saklar.
- **Bellek:** Anahtarlar libsodium'un korumalı belleğinde (`SecureKey`) tutulur ve kilitlenince silinir.

### Bilinen ödünler

1. **Parola ve 2FA aynı uygulamada.** Bu büyük kolaylık sağlar ama kasa açılırsa iki faktör de aynı anda ele geçer. Faz 5'te kodları görmek için ek onay seçeneği geliyor. Çok kritik hesaplar için ayrı bir cihaz veya donanım anahtarı yine daha güvenli.
2. **Dart bellekten silmeyi garanti edemiyor.** Ana parola metin kutusundan değiştirilemez bir Dart `String` olarak gelir ve çöp toplayıcı temizleyene kadar bellekte kalabilir. Ömrünü olabildiğince kısa tutarız, ama bunu tamamen önleyemeyiz.
3. **Bağımsız denetim yok.** Testler, açık kaynak ve Faz 8'deki denetim bunu azaltır ama uzman denetiminin yerini tutmaz.
4. **Yedek yoksa telefon kaybı veri kaybıdır.** Sunucu olmadığından kopya da yok. Uygulama yedek almayı düzenli olarak hatırlatacak.

## Çalışma düzeni

### Akış

1. **Faz başlar.** `main`'den `faz/<numara>-<kısa-ad>` branch'i açılır. Fazın takip issue'su görevlere bölünür ve görevler milestone'a eklenir.
2. **Geliştirme.** Her iş bir issue'ya bağlıdır. Commit'ler küçük ve tek amaçlıdır.
3. **Doğrulama.** Çıkış kriterleri tamamlanır, CI yeşil olur ve dört emülatörde elle denenir.
4. **PR.** Faz tamamen çalışınca `main`'e PR açılır. Başlık `Faz <numara>: <konu>` biçimindedir ve şablondaki kontrol listesi doldurulur.
5. **Birleştirme.** PR merge commit ile birleşir, squash kullanılmaz. Böylece faz branch'i `main` ile bağını korur ve gerektiğinde üzerinde çalışmaya devam edilebilir.
6. **Branch kalır.** Biten fazın branch'i silinmez; `faz/**` branch'lerinin silinmesi kuralla engellidir.
7. **Faz kapanır.** Bu belgedeki durum tablosu güncellenir, `main`'e `v0.<numara>.0` etiketi konur ve milestone kapatılır.

Biten bir fazda sonradan düzeltme gerekirse önce `main` o fazın branch'ine birleştirilir, düzeltme orada yapılır ve yeni bir PR açılır.

Kök dizindeki `CLAUDE.md`, Claude Code'un her oturumda otomatik okuduğu kısa kural listesidir. Durum bilgisi içermez, plan ve durumun tek kaynağı bu belgedir.

### Commit mesajları

Biçim: `<tür>(<alan>): <kısa açıklama>`. Alan isteğe bağlıdır.

| Tür | Ne zaman | Örnek |
|---|---|---|
| `özellik` | Yeni bir yetenek | `özellik(kasa): parola üretici eklendi` |
| `düzeltme` | Hata düzeltmesi | `düzeltme(2fa): geri sayım sıfırlanması düzeltildi` |
| `güvenlik` | Güvenliği iyileştiren değişiklik | `güvenlik(android): ekran görüntüsü engellendi` |
| `test` | Yalnızca test | `test(kripto): bozuk veri testleri eklendi` |
| `belge` | Yalnızca belge | `belge: yol haritası güncellendi` |
| `altyapı` | Derleme, CI, araçlar | `altyapı: CI'a biçim kontrolü eklendi` |
| `düzenleme` | Davranışı değiştirmeyen kod düzenlemesi | `düzenleme(kasa): depo sınıfı ayrıldı` |

### Issue ve etiketler

- Her fazın bir milestone'u ve bir takip issue'su vardır. Faz başlayınca takip issue'su görevlere bölünür, böylece planlar gerçek bilgiye göre netleşir.
- **Tür etiketleri:** `görev`, `özellik`, `hata`, `belge`, `güvenlik`, `faz-takibi`.
- **Alan etiketleri:** `alan: altyapı`, `alan: android`, `alan: arayüz`, `alan: kripto`, `alan: kasa`, `alan: 2fa`, `alan: otomatik-doldurma`, `alan: yedekleme`.
- **Öncelik etiketleri:** `öncelik: yüksek`, `öncelik: orta`, `öncelik: düşük`.
- PR açıklamasında `Closes #12` yazılır. Bu anahtar kelime İngilizce kalmalı, GitHub başka türlü issue'yu kapatmıyor.

### Test düzeni

| Emülatör | Android | Neden önemli |
|---|---|---|
| `KeyKey_API_30` | 11 | Desteklenen en eski sürüm; satır içi doldurma önerilerinin geldiği sürüm. |
| `KeyKey_API_34` | 14 | Credential Manager'ın geldiği sürüm; davranış farklarını yakalamak için. |
| `KeyKey_API_36` | 16 | Ana geliştirme cihazı. |
| `Medium_Phone_API_37.0` | 17 | En yeni sürüm; yaklaşan değişiklikleri erken görmek için. |

Emülatör testleri `flutter test integration_test -d <emülatör>` ile çalışır. `KeyKey_API_*` emülatörleri her zaman temiz açılacak şekilde ayarlı (`fastboot.forceColdBoot=yes`), çünkü bu bilgisayarda hızlı açılış kaydından açılırken takıldılar.

Emülatörlerde ekran kilidi yok. Parmak izi testi `resources/scripts/biometric-device-test.sh <emülatör>` ile çalışır: PIN ve parmak izi kaydeder, sanal parmağı dokundurur, ikinci parmak izini ekler ve sonunda PIN'i kaldırır. `flutter test integration_test` bu testi atlar. Kilit varken soğuk açılıştan sonra PIN girilene kadar uygulama başlatılamaz ve `adb` `Activity class does not exist` hatası verir; bu bir uygulama hatası değildir.

Panonun arka planda temizlendiğini `resources/scripts/clipboard-device-test.sh <emülatör>` sınar: uygulamayı arka plana alıp geri getirir.

Emülatörlerde gerçek güvenlik donanımı yok. Bu yüzden Faz 8'de gerçek bir ARM telefonda da test zorunlu.

**Her fazın ortak bitiş koşulları:** `dart format`, `flutter analyze` ve `flutter test` temiz; CI yeşil; dört emülatörde elle denendi; bu belge güncel; kayıtlarda gizli bilgi yok.

## Fazlar

### Faz 0 — Repo ve GitHub altyapısı

**Amaç:** Kod yazmadan önce repoyu düzenli ve herkese açılmaya hazır hale getirmek.

- [x] Temiz repo geçmişi ve commit'lerde gizli e-posta adresi
- [x] GPL-3.0, README, `.gitignore` ve `.gitattributes`
- [x] `resources/` klasörü ve bu yol haritası
- [x] Issue ve PR şablonları, güvenlik politikası, katkı rehberi
- [x] Etiketler, milestone'lar, issue'lar ve birleştirme ayarları
- [x] Repoyu herkese açmak; `main` ve `faz/**` kuralları; güvenlik taramaları

**Bitti sayılması için:** Repo herkese açık; geçmişte gizli bilgi ve kişisel e-posta yok; `main`'e doğrudan push engelli.

### Faz 1 — Flutter iskeleti ve CI

**Amaç:** Henüz özelliği olmayan ama çalışan bir uygulama ve kaliteyi koruyan otomatik kontroller.

- [x] Projeyi yalnızca Android için oluşturmak; paket kimliği ve `minSdk 30`
- [x] `MainActivity`'yi `FlutterFragmentActivity` yapmak (`BiometricPrompt` bunu gerektiriyor)
- [x] [Geliştirme ortamı](#geliştirme-ortamı) adımlarını README'nin geliştirme bölümüne eklemek
- [x] `very_good_analysis` ve mimarideki klasör yapısı
- [x] Riverpod, go_router ve açık/koyu Material 3 teması
- [x] Türkçe ve İngilizce yerelleştirme altyapısı
- [x] `FLAG_SECURE`, son uygulamalar ekranında içerik gizleme ve kapalı Android yedeklemesi
- [x] GitHub Actions: biçim, analiz, test, Android derlemesi, gizli bilgi taraması
- [x] CI'da birleşik manifest kontrolü: yayın sürümünde `INTERNET` izni olmamalı
- [x] Action'ları commit SHA'sına sabitlemek ve workflow izinlerini salt okunur yapmak
- [x] Dependabot ve `main` için zorunlu CI kontrolü

**Bitti sayılması için:** Uygulama dört emülatörde açılıyor; tema ve dil değişiyor; ekran görüntüsü alınamıyor; CI yeşil ve kontrolü geçmeyen PR birleştirilemiyor.

### Faz 2 — Kripto çekirdeği

**Amaç:** Her şeyin üzerine kurulacağı şifreleme katmanını arayüz olmadan, testlerle kanıtlanmış şekilde bitirmek.

- [x] libsodium'u başlatmak; Argon2id'yi arka planda çalıştırıp arayüzün donmasını önlemek
- [x] Argon2id parametre kalibrasyonu ve alt sınırı
- [x] Kasa anahtarı üretme; ana parola ve kurtarma anahtarıyla sarma
- [x] HKDF ile kayıt ve 2FA alt anahtarları
- [x] Ek doğrulama verisiyle kayıt şifreleme
- [x] Kasa üst bilgisi biçimi v1 (sürüm, tuz, parametreler, sarılmış anahtarlar)
- [x] Testler: yanlış parola, bozulmuş veri, yer değiştirilmiş kayıt, nonce tekrarı olmaması
- [x] Biçim uyumluluğu testi: bugün yazılan örnek dosya gelecekte de açılmalı
- [x] Tüm emülatörlerde ve gerçek ARM telefonda (Samsung Galaxy S20 FE) süre ölçümü
- [x] `resources/docs/guvenlik-tasarimi.md`
- [x] Gizli bilgi taraması için `resources/gitleaks.toml`: izin yalnızca iki deneme dosyasını kapsıyor

**Bitti sayılması için:** Tüm kripto testleri emülatörde geçiyor; tek bir bit değişen veri açılmıyor; yanlış parola temiz bir hata veriyor; tasarım belgesi kodla aynı.

**Dikkat:** Bu fazdaki hatalar sonradan en pahalıya patlayanlar. Kasa biçimine sürüm numarası baştan konur.

### Faz 3 — Kasa, kilit ve biyometri

**Amaç:** Kullanıcının kasa oluşturup açabildiği ve kilitleyebildiği ilk gerçek akış.

- [x] drift şeması, depo katmanı ve göç testleri
- [x] Kasa oluşturma ekranları: ana parola, güç göstergesi, parolanın geri alınamayacağı uyarısı
- [x] Kurtarma anahtarını gösterme ve geri yazdırarak doğrulama
- [x] Ana parolayla açma; hatalı denemelerde artan bekleme
- [x] Otomatik kilit: arka plana geçince ve süre dolunca; kilitte anahtarlar ve çözülmüş veri temizlenir
- [x] Kotlin köprüsü: Keystore anahtarı, `BiometricPrompt`, `CryptoObject`
- [x] Parmak iziyle açma; yeni parmak izi eklenince geçersiz olma
- [x] Ana parola değiştirme ve kurtarma anahtarıyla erişim
- [x] Metin kutularında otomatik düzeltme ve klavye öğrenmesini kapatma

**Bitti sayılması için:** Uygulama kapatılınca kasa kilitli açılıyor; yanlış parola içeri almıyor; parmak izi `adb emu finger touch` ile emülatörde çalışıyor; yeni parmak izi eklenince ana parola isteniyor; parola değişince tüm kayıtlar okunabilir kalıyor.

### Faz 4 — Parola kasası

**Amaç:** Parolaların saklandığı, arandığı ve üretildiği ana ekran.

- [x] Kayıt modeli: ad, kullanıcı adı, parola, birden çok URL, not, özel alanlar
- [x] Kilitlenince çözülmüş kayıt tutan bütün durumların temizlendiğini test etmek (Faz 3'te henüz çözülmüş kayıt tutulmuyor)
- [x] Otomatik kilit süresini klavye kullanımında da yenilemek (Faz 3'te yalnızca dokunmayla yenileniyor)
- [x] Liste, arama, favoriler, klasörler ve sıralama (arama çözülmüş veri üzerinde bellekte yapılır)
- [x] Ekleme, düzenleme, çöp kutusu ve parola geçmişi
- [x] Parola üretici: rastgele parola ve parola cümlesi, libsodium'un güvenli rastgele üreticisiyle
- [x] Kendi güç ölçerimiz: entropi, yaygın parola listesi ve desen kontrolü
- [x] Güvenli pano: hassas işareti (Android 13+) ve 30 saniye sonra otomatik temizleme
- [x] Parolayı göster/gizle ve kilit durumuyla uyumlu ekran davranışı

**Bitti sayılması için:** 1000 kayıtla liste ve arama akıcı; pano uygulama arka plandayken de temizleniyor; düzenleme sonrası eski parola geçmişte; hiçbir kayıt düz metin olarak diske yazılmıyor (veritabanı dosyası incelenerek doğrulanır).

### Faz 5 — 2FA doğrulayıcı

**Amaç:** Uygulamanın doğrulama kodu üreten yarısı.

- [x] TOTP (RFC 6238) ve HOTP (RFC 4226); SHA-1, SHA-256, SHA-512; 6-8 hane; özel süre
- [x] RFC test vektörleriyle doğrulama
- [x] `otpauth://` ayrıştırıcı ve hatalı girdi testleri
- [x] Kamera ve görselden QR okuma (`flutter_zxing`); kamera izni yalnızca tarama sırasında istenir
- [x] Elle anahtar girişi
- [x] Kod listesi: geri sayım, dokununca kopyalama, sıradaki kodu gösterme, arama
- [x] Parola kaydıyla 2FA hesabını eşleştirme
- [x] Google Authenticator (`otpauth-migration://`), Aegis ve 2FAS'tan içe aktarma (şifreli dosyalar dahil)
- [x] İsteğe bağlı ek onay: kodları görmek için parmak izi veya ana parola
- [x] Cihaz saati yanlışsa kodların tutmayacağına dair yardım metni

**Bitti sayılması için:** RFC vektörleri geçiyor; üretilen kod gerçek bir servisteki test hesabında kabul ediliyor; bozuk QR uygulamayı düşürmüyor.

**Sonuç:** RFC vektörleri geçiyor, bozuk QR ve bozuk dosyalar uygulamayı düşürmüyor (rastgele girdi testleriyle). 2026-11-06'da gerçek telefonda (Samsung Galaxy S20 FE, sürüm derlemesi) bilgisayar ekranındaki QR kamerayla okundu ve üretilen kod, deneme amaçlı herkese açık bir serviste ([authenticationtest.com](https://authenticationtest.com/totpChallenge/)) kabul edildi. Aynı telefonda kasa kurulumu ve parmak iziyle açma da çalıştı.

Telefon denemesi üç sorun buldu ve [#60](https://github.com/aaudraa/KeyKey/pull/60) ile düzeldi: kurulumdaki 55 karakterlik kurtarma anahtarı yazım hatasının yeri söylenmediği için yeniden yazılamıyordu; 2FA anahtarı gizli kutuya körlemesine yazılıyordu ve Türkçe klavyenin İ harfi reddediliyordu; kamera bilgisayar ekranındaki QR'ı ancak 15 saniyede okuyordu.

### Faz 6 — Otomatik doldurma

**Amaç:** Parolayı kopyala-yapıştır yapmadan güvenle doldurmak. Projenin en zor ve güvenlik açısından en hassas parçası.

**Tasarım:** Kasa kilitliyken sistem yalnızca "KeyKey ile doldur" seçeneğini görür. Kullanıcı seçince KeyKey açılır, kilit çözülür ve eşleşen kayıt onaylanır. Kullanıcı onayı olmadan hiçbir veri servise veya hedef uygulamaya verilmez.

- [x] Kotlin `AutofillService` ve manifest kaydı
- [x] Alan tespiti: autofill ipuçları, giriş türü, HTML nitelikleri, Türkçe ve İngilizce alan adları (test edilebilir saf Kotlin işlevleri olarak)
- [x] Kilit akışı: öneri düzeyinde kimlik doğrulama (`Dataset.setAuthentication`) ile KeyKey ekranını açmak
- [x] Hızlı açılan, ayrı bir Flutter giriş noktası (`autofillMain`)
- [x] Uygulama eşleştirme: paket adı ve imza sertifikası özeti birlikte
- [x] Web eşleştirme: gömülü Public Suffix List ile alan adı; `webDomain` yalnızca güvenilen tarayıcılardan kabul edilir
- [x] Şüpheli eşleşmede açık uyarı ve ek onay
- [x] Satır içi öneriler (Android 11+)
- [x] Yeni parola kaydetme akışı
- [x] Doldurma sonrası 2FA kodunu panoya kopyalama seçeneği
- [x] Kurulum yönlendirmesi: sistem ayarına doğrudan geçiş ve Chrome 135+ için [gereken "Autofill using another service" ayarına](https://android-developers.googleblog.com/2025/02/chrome-3p-autofill-services-update.html) doğrudan bağlantı
- [x] Saldırı testleri: aynı paket adıyla farklı imzalı uygulama, sahte `webDomain`, WebView içeren uygulama (2023'te yayımlanan AutoSpill senaryosu)

**Durum (2026-11-07):** #61-#69 bitti. #70 son denemeleri dört emülatörde (Android 11, 14, 16, 17) yapıldı: kaydetme, kilitliyken kayıt adının görünmemesi ve saldırı denemeleri hepsinde geçti; denemelerde iki hata bulunup düzeltildi. Yeni bir uygulamada ilk kayıt da uygulamaya bağlanıyor; bunun için KeyKey ana ekranda simgesi olan uygulamaları görebiliyor. Chrome yalnızca Android 17'de (Chrome 145) denenebildi; diğer emülatörlerdeki Chrome 83, 113 ve 133 başka doldurma servisini desteklemiyor ve güncellenemiyor. Ölçüt kullanıcının onayıyla buna göre değiştirildi (2026-11-07). Telefonda (Samsung Galaxy S20 FE, Android 13) Samsung klavyesiyle örnek uygulamada kaydetme ve doldurma çalıştı; öneri önce klavye şeridinde, yazı silinince kutunun altındaki listede çıkıyor. Samsung Internet 30 KeyKey'i seçili servis olarak görse de doldurma servisine hiç istek göndermiyor, yalnızca kendi parola ve form özelliklerini kullanıyor; bu tarayıcı [desteklenmiyor](docs/guvenlik-tasarimi.md#samsung-internet).

**Bitti sayılması için:** Dört emülatörde örnek bir uygulama, Chrome 135+ olan emülatörde (Android 17) Chrome'daki bir giriş formu dolduruluyor; yeni parola kaydediliyor; kilitliyken hiçbir kayıt adı görünmüyor; saldırı testlerinin hepsinde parola sahte hedefe verilmiyor.

### Faz 7 — Yedekleme, içe ve dışa aktarma

**Amaç:** Telefon kaybolsa bile verinin kurtarılabilmesi ve başka uygulamalardan kolay geçiş.

- [x] Sürümlü `.keykey` biçimi: Argon2id ve libsodium `secretstream`
- [x] Android dosya seçicisiyle kaydetme: Drive gibi konumlar internet izni olmadan çalışır
- [x] Geri yükleme: önce doğrulama, sonra birleştirme veya değiştirme seçeneği; hata olursa mevcut kasaya dokunulmaz
- [x] Yedek hatırlatıcısı ve "son yedek" bilgisi
- [x] İçe aktarma: Bitwarden (JSON, CSV), Chrome (CSV), KeePassXC (CSV), Aegis ve 2FAS
- [x] Düz metin kaynak dosyasını silmeyi hatırlatma
- [x] Çift onaylı ve uyarılı düz metin dışa aktarma
- [x] Biçim uyumluluğu testleri

**Durum (2026-11-08):** Tamamlandı ([#81](https://github.com/aaudraa/KeyKey/pull/81), `v0.7.0`). Yedek ayrı bir parola istemez: alındığı andaki ana parola veya kurtarma anahtarıyla açılır. API 36'da alınan yedek API 30'da aynen açıldı; bozuk dosya ve yanlış parola kasaya dokunmadan reddedildi; cihaz testleri dört emülatörde geçti. Bitwarden, Chrome 145 ve KeePassXC 2.8'in gerçek dışa aktarmaları testlere girdi. Telefonda (Samsung Galaxy S20 FE, Android 13) yedek Google Drive'a alındı, uygulama kaldırılıp yedek Drive'dan geri yüklendi. Bu deneme, ayarları hiç değiştirilmemiş bir kasanın yedeğinde son yedek saatinin boş kaldığı bir hatayı buldu; düzeltildi.

**Bitti sayılması için:** API 36'da alınan yedek API 30'da aynen açılıyor; bozuk dosya temiz bir hata veriyor ve veri kaybettirmiyor; yanlış parola dosyayı açmıyor.

### Faz 8 — Güvenlik sertleştirme ve denetim

**Amaç:** 1.0 öncesi son güvenlik ve kalite geçişi. Gerçek veriyle kullanım ancak bu fazdan sonra düşünülebilir.

- [x] [OWASP MASVS](https://mas.owasp.org/MASVS/) maddelerini tek tek denetlemek ve sonucu `resources/docs/guvenlik-denetimi.md` dosyasına yazmak
- [x] Tehdit modeli ve tüm kayıt (log) çıktılarının gözden geçirilmesi
- [x] Dokunma korsanlığı koruması: `setHideOverlayWindows` ve gizlenmiş dokunuşları filtreleme
- [x] R8 ayarları ve yayın derlemesi testi (`debuggable` kapalı, gizli sembol yok)
- [x] Çevrimdışı parola raporu: zayıf ve tekrar eden parolalar
- [x] Bağımlılık ve lisans denetimi; gereksiz paketlerin çıkarılması
- [x] Gerçek ARM telefonda test: StrongBox, biyometri, performans
- [x] Erişilebilirlik: TalkBack, büyük yazı boyutu, kontrast
- [x] Deneme verisiyle günlük kullanım (iki hafta planlanmıştı, kullanıcının kararıyla iki günde bitti; aşağıda)
- [ ] Dışarıdan inceleme çağrısı: tasarım belgesini güvenlik topluluklarıyla paylaşmak (Faz 9'a taşındı)

**Durum (2026-11-08):** Faz başladı, görevler #82-#91 ve Faz 6'dan kalan #71. Biten: kayıtlar ve tehdit modeli (#82), arayüz koruması (#83), yayın derlemesi (#84), bağımlılık ve lisans denetimi (#86, [bağımlılık belgesi](docs/bagimliliklar.md)), çevrimdışı parola raporu (#85), erişilebilirlik (#87), gerçek telefon (#88; StrongBox, parmak izi, süreler [denetim belgesinde](docs/guvenlik-denetimi.md#gerçek-telefon)), MASVS denetimi (#91, 2026-11-09, [özet](docs/guvenlik-denetimi.md#özet)). Denetim bir açık buldu ve düzeltildi: başka bir uygulama, adres taşıyan bir niyetle KeyKey'i istediği ekrana götürebiliyordu. Kilitten sonra bellekte kalan dizeler kabul edilen risk olarak [bilinen sınırlara](docs/guvenlik-tasarimi.md#bilinen-sınırlar) yazıldı. Faz sonu cihaz testleri (entegrasyon, parmak izi, pano, kamera) 2026-11-09'da dört emülatörde (Android 11, 14, 16, 17) geçti. Bu iş [#92](https://github.com/aaudraa/KeyKey/pull/92) ile `main`'e birleşti (`v0.8.0`). Faz, #89 ve #90 bitene kadar sürüyor. Uzun süreli kullanım (#89) Faz 8'in son sürümüyle başlayacak; dış inceleme paylaşımı (#90) kullanıcıyla yapılır.

**Deneme (#89, 2026-11-09 - 2026-11-10):** Telefona `v0.8.0` kuruldu. İki haftalık plan, kullanıcının kararıyla 2026-11-10'da erken bitti. İki bulgu çıktı, ikisi de bu dalda kapandı:

- #94: HoYoLAB'ın giriş ekranı kutularını doldurma sistemine bildirmiyor, bu yüzden ne doldurma ne kaydetme önerisi çıkıyor. Sebep uygulamada; [bilinen sınır](docs/guvenlik-tasarimi.md#doldurma-sistemine-katılmayan-ekranlar) olarak yazıldı, KeyKey klavyesi fikri [1.0 sonrasına](#10-sonrası) eklendi.
- #95: Firefox'un parola dışa aktarması içe aktarılamıyordu. Eklendi ve telefonda gerçek bir Firefox dosyasıyla denendi.

Güvenlik ya da veri kaybı sorunu çıkmadı. Ayrıntılar [denetim belgesinde](docs/guvenlik-denetimi.md#günlük-kullanım-denemesi).

**Kapanış (2026-11-10):** Faz tamamlandı. Dış inceleme çağrısı (#90) Faz 9'a taşındı: gönderiyi kullanıcı bu faz `main`'e girince paylaşır, gelen geri bildirimler 1.0'dan önce Faz 9'da toplanır. #71 (simgesi olmayan uygulama) denemede karşımıza çıkmadı; issue açık kalıyor ve [Riskler](#riskler) tablosunda duruyor, 1.0 sonrasında gerçek bir örnek çıkarsa ele alınacak.

**Bitti sayılması için:** Açık `güvenlik` issue'su yok; denetim belgesi tamamlandı; gerçek cihaz testleri geçti.

### Faz 9 — 1.0 yayını

**Amaç:** İlk kararlı sürümü imzalı ve doğrulanabilir şekilde yayımlamak.

- [x] Yayın anahtarı: repoya girmez, yedeği ayrı ve güvenli bir yerde tutulur, CI'da GitHub Secrets ile kullanılır
- [x] Yayın otomasyonu: etiket atılınca imzalı APK ve AAB, SHA-256 özetleri, GitHub Release; R8 `mapping.txt` dosyası da sürüme eklenir (yığın izlerini okumak için)
- [x] `CHANGELOG.md` ve sürüm numaralandırma
- [x] Yeniden üretilebilir derleme denemesi; `sqlite3`'ü hazır dosya yerine kaynaktan derlemek (F-Droid de bunu gerektiriyor)
- [x] Dağıtım kararı (2026-11-09): 1.0 GitHub Releases'ta; ardından IzzyOnDroid, sonra F-Droid ana deposu (bizim imzamızla); Play Store şimdilik yok
- [x] `v0.x` sürümünden 1.0'a yükseltme testi: veri kaybı olmamalı (1.0 etiketinden önce son derlemeyle kısa tekrar)
- [x] Gizlilik bildirimi: seçilen mağazaların istediği açıklamalar (Play Store veri güvenliği formu, F-Droid); MASVS-PRIVACY denetiminden
- [x] Tasarım incelemesi: bütün ekranların baştan gözden geçirilmesi, uygulama simgesi ve açılış ekranı; kaynak dosyalar `resources/design/` altında. Deneme (#89) boyunca biriken arayüz notları ve ertelenen fikirler (örneğin otomatik doldurma ekranının yarım yükseklikte açılması) buraya girer. İlk tur kodda bitti (#103, [ilk tasarım belgesi](docs/tasarim-yenileme.md)) ama kullanıcı görünümü beğenmedi; ikinci tur: [cam tasarım belgesi](docs/tasarim-cam.md). Telefonda kullanıcıyla deneme 1.0 etiketinden önce.
- [x] Kullanım kılavuzu ve ekran görüntüleri (`resources/docs/kullanim.md`, `resources/design/`)
- [ ] Dışarıdan inceleme çağrısı (#90, Faz 8'den taşındı): gönderiyi kullanıcı paylaşır; gelen geri bildirimler 1.0 etiketinden önce issue'lara dönüştürülür

**Sıra:** Önce görünümü değiştirmeyen işler (yayın otomasyonu, derleme, sürüm, yükseltme testi). Tasarım incelemesi fazın sonunda yapılır, çünkü deneme bitmeden arayüzü değiştirmek denenen sürümü değiştirir. Kılavuz ve ekran görüntüleri tasarımdan sonra gelir; önce çekilirse tasarım değişince yeniden çekmek gerekir. Kullanıcının kararı (2026-11-09).

**Durum (2026-11-09):** Faz başladı, görevler #96-#104. Biten: sürüm kuralı ve [değişiklik günlüğü](CHANGELOG.md) (#98), [gizlilik bildirimi](docs/gizlilik.md) (#102, mağaza yanıtları dağıtım kararını bekliyor). Yayın iş akışı (#96, [yayın belgesi](docs/yayin.md)) deneme anahtarıyla GitHub'da sınandı: etiketten taslak ön sürüm, özetler ve imza doğru. Gerçek anahtar #97'yi bekliyor. SQLite artık repodaki kaynaktan derleniyor; aynı yolda yapılan iki derleme, yayın iş akışındakiler dahil, bayt bayt aynı; farklı yolda Flutter'ın gömdüğü mutlak yol yüzünden ayrılıyor (#99, [ayrıntılar](docs/yayin.md#yeniden-üretilebilir-derleme)). Yükseltme denemesi (#101) fazın son derlemesiyle yapılacak.

**Durum (2026-11-10):** Kalıcı yayın anahtarı oluşturuldu, sertifika özeti README'de ve [yayın belgesinde](docs/yayin.md) (#97). Dağıtım kararı verildi (#100, yukarıda). Faz 8 [#105](https://github.com/aaudraa/KeyKey/pull/105) ile kapandı; dış inceleme çağrısı (#90) bu faza taşındı. Yükseltme testi (#101) emülatörde iki yolla geçti: aynı imzayla üstüne kurulum ve farklı imzada yedekle taşıma ([ayrıntılar](docs/yayin.md#eski-sürümlerden-geçiş)). Bilgisayarda Windows Smart App Control, Flutter'ın 32 bit ARM aracını (`gen_snapshot`) engellemeye başladı; yerel derlemeler `--target-platform android-x64,android-arm64` ile yapılıyor, CI etkilenmiyor. Kalan sıra: tasarım incelemesi (#103), kullanım kılavuzu (#104), ardından 1.0.

**Durum (2026-11-11):** Tasarım yenilemesi (#103) kodda bitti: yeni tema ve renkler, aynı boy kartlar, yüzen alt menü, gruplu ayarlar, alttan açılan pencereler, yeni simge ve açılış ekranı, yarım pencerede otomatik doldurma ve tek kesin eşleşmenin sorulmadan doldurulması. Entegrasyon testleri Android 11, 14 ve 17 emülatörlerinde geçti; Android 16 emülatörü bozuk durumda (hiçbir KeyKey sürümü açılmıyor, tasarımdan önceki sürüm de), yeniden kurulacak. Kalan: telefonda kullanıcıyla deneme, kılavuz (#104), dış inceleme çağrısı (#90).

**Durum (2026-11-12):** Kullanıcı ilk turun görünümünü telefonda birkaç gün kullandıktan sonra beğenmedi ("sadece renkler değişmiş", cam fark edilmiyor, yeni parola ekranı korkutucu). Tasarım incelemesi yeniden açıldı. Örnek ekranlar üzerinden yeni yön kararlaştırıldı: renkli yumuşak zemin, cam kartlar, ucunda "+" olan cam menü, sade formlar, yumuşak hareketler ([cam tasarım belgesi](docs/tasarim-cam.md), [örnek ekranlar](design/cam-tasarim-ornekleri.html)). İlk turun otomatik doldurma davranışı, simge ve açılış ekranı kalıyor. Kullanıcı belgeyi aynı gün onayladı; [uygulama planı](docs/tasarim-cam-plani.md) yazıldı (15 görev). Sıra: kullanıcının plan onayı, uygulama, telefonda deneme; kılavuz (#104) bunun arkasında.

**Durum (2026-11-13):** Cam tasarım planının 15 görevi kodda bitti (#103). Bütün ekranlar renkli zemin ve cam kartlarla çiziliyor; tek "+", listeden kopyalama, sade formlar, ayarlarda yedek kartı, hareketli kilit ekranı, cam doldurma penceresi ve tahmini geri hareketi eklendi. Bir tarama testi düz `Scaffold`, düz alt pencere ve `AlertDialog` kalmadığını denetliyor. Birim testleri (1099) ve entegrasyon testleri Android 11, 14 ve 17 emülatörlerinde geçti. Tahmini geri hareketi Android 17 emülatöründe elle denendi: "+" kutusu açıkken geri kutuyu kapatıyor, değişmiş formda soru çıkıyor, kökte geri uygulamayı arka plana alıyor.

Ölçüm: 1000 kayıtlı listede beş savurma (debug, aynı Android 14 emülatörü) cam öncesi 15,2-15,5 sn, cam sonrası 17,0-18,0 sn sürdü. Karttaki gölgeyi kapatmak 16,6 sn, alt menünün bulanıklığını kapatmak 17,1 sn verdi; kalan fark kart başına daha çok bileşenden. Emülatörde profil modu olmadığı için karar telefondaki denemeye bırakıldı; takılma görülürse önce gölge ucuzlatılır. Yazılımsal grafikli emülatör (`-gpu swiftshader_indirect` ve `guest`) bulanık yüzeylerde qemu erişim ihlaliyle çöktü; testler `-gpu host` ile çalıştırıldı. KeyKey ekran görüntüsünü engellediği için emülatörde görsel karşılaştırma yapılamadı; görsel denetim telefondaki denemede. Kalan: telefonda kullanıcıyla deneme, kılavuz (#104), dış inceleme çağrısı (#90).

**Durum (2026-11-13, öğleden önce):** Kullanıcı cam tasarımı telefonda denedi: cam ve hareketler hoşuna gitti ama turuncu fazla, yazı ve düğmeler büyük geldi. Üçüncü tur konuşuldu: siyah-beyaz zemin ve simgeler, turuncu yalnızca dört yerde (K logosu, "+", ekranın ana düğmesi, 2FA halkası), cam korunuyor, ölçüler küçülüyor, ayarlarda (i) anahtarın solunda, kayıt simgeleri kutusuz; ayrıca dört katmanlı bir hareket planı ([siyah-beyaz tasarım belgesi](docs/tasarim-siyah-beyaz.md), [örnek ekranlar](design/siyah-beyaz-tasarim-ornekleri.html)). Açık sorular aynı gün yanıtlandı: küçülen başlık ve hata titreşimi eklenecek, simgesiz kayıtta harf ince daire içinde, güç çubuğu renksiz. Kullanıcı hareketlerin yalnızca ilk girişte kalmayıp kullanım boyunca sürmesini istedi; belgeye her dönüşte giriş hareketi ve bütün ekranlarda yavaş kayan zemin eklendi. Sıra: uygulama planı, uygulama (altı aşama, üç telefon denemesi); kılavuz (#104) bunun arkasında.

**Durum (2026-11-13, gece):** Siyah-beyaz tasarım ve hareket planının 15 görevi kodda bitti (#103, [belge](docs/tasarim-siyah-beyaz.md)). Turuncu yalnızca dört yerde; kartlar beyaz, alt menü buzlu cam; ölçüler küçüldü. Hareketler dört katmanda: yavaş kayan zemin, kaydırınca küçülen başlık ve kaydırdıkça gelen kartlar; basınca küçülme, kopyalayınca onay işareti, hatada titreme ve titreşim, kaydedince onay işareti ve parlayan kart; listelerde silinen kartın kayıp kapanması; parolanın sırayla açılması, 2FA rakamlarının kayması, halkanın son saniyelerde atması; kilit ekranında logo, nefes alan parmak izi, kilit açılışında solan K; yedek kartının atması, kurulumda kayan adımlar, nefes alan QR çerçevesi. "Animasyonları kaldır" açıkken hepsi anında biter. Bitişte yeni gözle bir inceleme yapıldı; bulunan iki önemli sorun (2FA listesinde saniyede biriken dinleyiciler, ekran geçişlerinin hiç çalışmaması) ve altı küçük sorun testle birlikte düzeltildi. Birim testleri (1206) geçti. Entegrasyon testleri Android 11, 14 ve 17 emülatörlerinde hepsi geçti (emülatörler sırayla, birer birer açıldı). Telefonda birinci deneme yapıldı; ikinci ve üçüncü deneme sürümleri taslak yayında. Dördüncü denemede proje sahibi kartları buzlu ve küçük buldu, arama kutusunun listeyle kaymasını istedi, küçülen başlığı anlamsız buldu; kartlar dolu ve büyük oldu, büyük başlık ve arama listeyle birlikte kayıyor (afcf10f). Beşinci denemede başlıkların sabit, biraz büyük ve kalın olması, kayan arama kutusunun üst çubukta simgeye dönmesi istendi; form alanlarının etiketinin yarısının kesildiği görüldü. Başlık ve arama düzeltildi (dacb9a5). Etiket için alanlar etiketi içeride gösteren stile geçirildi (405b759), ama proje sahibi altıncı denemede düğmelerdeki yazının kesilmesinin sürdüğünü söyledi; sonraki oturumun ilk işi bu. #103 onun onayıyla kapanır.

**Durum (2026-11-15):** "Kesilen düğme yazısı" aslında form alanlarının görünümüydü; iki farklı alan stili denendi, proje sahibi ikisini de beğenmedi ve beşinci denemedeki görünüme dönüldü. Koyu tema sakinleşti: zemin tam siyah yerine koyu gri, yazı kısık beyaz, kartlar zeminden belirgin, arkadaki lekeler çok soluk. Açık tema Claude uygulamasındaki gibi krem oldu. Kartların tepesindeki ince beyaz şerit iki temada da kalktı, yalnızca alt menünün camında duruyor. Ayarlar'a Görünüm grubu ve tema seçimi (Sistem, Açık, Koyu) eklendi; seçim kilit ekranı da uysun diye kasanın dışında şifresiz bir dosyada ([tasarım](docs/tema-secimi.md), [plan](docs/tema-secimi-plani.md)). #103 proje sahibinin onayıyla kapanır. Proje sahibi altıncı denemeden sonra görünümü şimdilik uygun buldu. Aynı gün entegrasyon testleri Android 11, 14 ve 17 emülatörlerinde hepsi geçti; kullanım kılavuzu ([kullanim.md](docs/kullanim.md)) ekran görüntüleriyle yazıldı (#104); gizlilik bildirimine tema dosyası eklendi, mağaza yanıtları kesinleşti (#102). Kalan: faz PR'ı, dışarıdan inceleme çağrısı (#90, gönderiyi proje sahibi paylaşır), 1.0'dan önce son derlemeyle kısa yükseltme denemesi (#101), sürüm numarası ve 1.0 etiketi.

**Durum (2026-11-16):** Faz PR'ı [#109](https://github.com/aaudraa/KeyKey/pull/109) proje sahibinin onayıyla `main`'e birleşti. #101 eski bir commit'in `Closes` satırıyla kapandı, 1.0'dan önceki kısa tekrar için yeniden açıldı. Dışarıdan inceleme çağrısı (#90) proje sahibinin kararıyla 1.0'ın önkoşulu değil, milestone'dan çıkarıldı. Proje sahibi 1.0'dan önce ilk açılışa hareketli bir tanıtım istedi; altı sayfa yazıldı ([tasarım](docs/tanitim.md), [plan](docs/tanitim-plani.md)). Başka uygulamalar logosuz, aynı görünen ad rozetleriyle geçiyor (önce özgür lisanslı KeePassXC logosu konmuştu, proje sahibi telefonda gördükten sonra kaldırılmasını istedi). Entegrasyon testleri Android 17'de hepsi geçti. Proje sahibinin isteğiyle ayrıca: "+" menüsünün K logosunu yeniden oynatması düzeltildi, sekme adları büyüdü, ekran başlıkları Barlow Condensed eğik büyük harf ve 44 punto oldu. Kalan: telefonda son deneme (`keykey-deneme-14-spor-basliklar.apk`), ikinci PR, #101 kısa tekrarı, sürüm numarası ve `v1.0.0` etiketi.

**Durum (2026-11-16, akşam):** Proje sahibi 14. denemeyi telefonda gördü, başlıkları beğendi. Birim testleri (1254) ve entegrasyon testleri Android 17'de geçti; tanıtım ve başlıklar için ikinci faz PR'ı açıldı. Kalan: PR'ın birleşmesi (proje sahibinin onayıyla), #101 kısa tekrarı, sürüm numarası ve `v1.0.0` etiketi.

**Durum (2026-11-16, gece):** [#110](https://github.com/aaudraa/KeyKey/pull/110) proje sahibinin onayıyla `main`'e birleşti. #101'in kısa tekrarı son derlemeyle Android 17 emülatöründe geçti: `v0.8.0` kasası üstüne kurulumda bütün veriyle, 2FA bağıyla ve parmak iziyle açıldı ([ayrıntılar](docs/yayin.md#eski-sürümlerden-geçiş)). Kalan: sürüm numarası ve `v1.0.0` etiketi.

**Durum (2026-11-16, gece, devam):** Proje sahibi 1.0'dan önce uygulama içi bildirimlerin üstten inmesini istedi. Bütün bildirimler artık durum çubuğunun altında, ortada duran cam bir hap: yazı 16 punto kalın, yukarı kaydırınca ya da dokununca kapanıyor, düğmeli olanlar 6 saniye kalıyor, kasa kilitlenince kapanıyor ([tasarım](docs/ust-bildirim.md), [plan](docs/ust-bildirim-plani.md)). Yeni gözle yapılan incelemede bulunan iki sorun (TalkBack'le kapatılamama, uzun bildirimin geri tuşunu örtmesi) testle düzeltildi. Birim testleri (1271) geçti. Kalan: proje sahibinin telefonda denemesi, PR, sürüm numarası ve `v1.0.0` etiketi.

**Durum (2026-11-16, son):** Proje sahibi bildirimi telefonda (`keykey-deneme-15-ust-bildirim.apk`) beğendi. Sürüm `1.0.0+3` oldu, değişiklik günlüğünün başlığı 1.0.0 aldı; üçüncü faz PR'ı açıldı. Kalan: PR'ın birleşmesi (proje sahibinin onayıyla) ve `v1.0.0` etiketi.

**Durum (2026-11-16, yayın):** [#111](https://github.com/aaudraa/KeyKey/pull/111) proje sahibinin onayıyla birleşti, `v1.0.0` etiketlendi. İlk derleme imzalamada durdu: anahtar oluşturulurken parolanın sonunda görünmez bir CR kalmıştı ([ayrıntılar](docs/yayin.md#kalıcı-anahtar)). Aynı anahtar temiz parolayla yeniden paketlendi, sertifika değişmedi. Yeniden çalıştırılan iş akışı geçti; özetler ve imza yerelde doğrulandı. Proje sahibi [KeyKey 1.0.0](https://github.com/aaudraa/KeyKey/releases/tag/v1.0.0)'ı yayınladı; #21 ve Faz 9 milestone'u kapandı. Ardından anahtar betikleri bu tuzaklara karşı düzeltildi, iş akışı parolaları derlemeden önce deniyor. **Faz 9 bitti.**

**Bitti sayılması için:** GitHub Release'teki APK dört emülatöre ve gerçek telefona kuruluyor; önceki sürümden yükseltmede veri korunuyor; README son durumu anlatıyor.

### Faz 10 — F-Droid

**Amaç:** KeyKey'i F-Droid ana deposuna bizim imzamızla (birebir aynı derleme) başvurmaya hazırlamak, bu düzenle 1.0.1'i yayımlamak ve README'ye Obtainium bağlantısı koymak. [Tasarım](docs/f-droid.md), [uygulama planı](docs/f-droid-plani.md). Takip: #120.

- [x] README'ye Obtainium bağlantısı (#114; telefonda denendi 2026-11-18)
- [x] F-Droid için Fastlane açıklamaları ve denetimi (#115)
- [x] F-Droid tarifi ve birebir aynı derleme denetimi (#116)
- [x] Yayın iş akışı F-Droid yolunda ve F-Droid karşılaştırması (#117; gerçek sınama `v1.1.0` etiketinde)
- [x] F-Droid düzeniyle ilk yayın (#118; 1.0.1 yayımlanmadı, ilk yayın 1.1.0)
- [x] F-Droid başvurusu (#119; [fdroiddata!57995](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/57995); 2026-11-18'de kabul edilmedi, #130)

**Durum (2026-11-17):** Faz başladı. IzzyOnDroid'e başvurulmuyor: [kabul kuralları](https://izzyondroid.org/docs/general/AppInclusionPolicy/) yapay zekâyla yazılmış kodu kabul etmiyor, ayrıca APK başına 30 MB sınırı var (APK'mız 77 MB). F-Droid'in kurallarında yapay zekâ maddesi yok. Proje sahibi tek evrensel APK'yı seçti; işlemci türüne göre bölme sonraya kaldı. Faz başvurunun gönderilmesiyle biter; F-Droid'in kabulü ve README'ye F-Droid bağlantısı ayrı iş.

**Durum (2026-11-17, gece):** F-Droid'in kendi aracıyla derlenen APK bizim imzamızı kabul ediyor: dokuzuncu denemede `apksigcopier compare` yeşil ([ayrıntılar](docs/yayin.md#yeniden-üretilebilir-derleme)). Yayın iş akışı artık F-Droid'in imajında ve yolunda imzasız derliyor, ayrı bir işte `apksigner` ile imzalıyor ve taslak yayımlanmadan önce F-Droid derlemesiyle karşılaştırıyor. README yeniden düzenlendi. Proje sahibinin isteğiyle aynı gece QR tarayıcının hizası ve feneri düzeltildi, kurulumda kurtarma anahtarı kopyalanabilir ve dosyaya kaydedilebilir oldu ([#121](https://github.com/aaudraa/KeyKey/pull/121)). Sürüm `1.0.1+4`. Kalan: faz PR'ı, `v1.0.1` etiketi (dağıtım onayı ve yayımlama proje sahibinde), Obtainium bağlantısının telefonda denenmesi, başvuru ([metin](f-droid/basvuru.md)).

**Durum (2026-11-17, sabaha karşı):** Faz PR'ı ([#122](https://github.com/aaudraa/KeyKey/pull/122)) birleşti; zincirin tamamı PR'da tek kullanımlık anahtarla yeşil. `v1.0.1` etiketi birleştirme commit'inde (`6e4d97e`); yayın iş akışında imzasız derleme ve F-Droid derlemesi yeşil, imzalı yayın işi proje sahibinin dağıtım onayını bekliyor. F-Droid tarifinin `commit:` alanı bu commit. Kalan, hepsi proje sahibinde: dağıtımı onaylamak ve taslağı yayımlamak (#118), GitLab'da birleştirme isteği ([adımlar](f-droid/basvuru.md), #119), Obtainium bağlantısını telefonda denemek (#114).

**Durum (2026-11-17, akşam):** Proje sahibi önce `v1.1.0`'ın dağıtımını onayladı. İmzalı yayın işi, APK doğru anahtarla imzalandığı halde "İmza denetimi" adımında durdu: GitHub'ın imajındaki `apksigner` 37 sertifikayı yeni bir biçimde yazıyor, denetim satırı yalnızca eskisini okuyordu ve bu adım PR provasında yoktu ([ayrıntı](docs/yayin.md#imza-denetimi)). Denetim [`imza-ozeti.sh`](scripts/imza-ozeti.sh) betiğine taşındı, iki biçimi de okuyor, testi var ve provada tek kullanımlık anahtarla da çalışıyor. Proje sahibi gitmeden önce bütün adımları bana bıraktı ("hepsini yap, taslağı da yayımla"). `v1.0.1`'in bekleyen çalışması aynı satırı taşıdığı için iptal edildi; 1.0.1 yayımlanmadı, F-Droid'e giren ilk sürüm 1.1.0. `v1.1.0` etiketi düzeltmenin commit'ine taşındı, F-Droid tarifi ve başvuru metni 1.1.0'a göre güncellendi.

**Durum (2026-11-17, yayın):** [#129](https://github.com/aaudraa/KeyKey/pull/129) birleşti, provada yeni imza denetimi `apksigner` 37 ile yeşil. Taşınan `v1.1.0` etiketinde zincirin tamamı yeşil: imzasız derleme, F-Droid derlemesi, imza ve imza denetimi, F-Droid karşılaştırması. İndirilen APK'nın özeti `SHA256SUMS` ile tutuyor, sertifikası `66ff7b5c…`, versionCode 5. Proje sahibinin yetkisiyle [KeyKey 1.1.0](https://github.com/aaudraa/KeyKey/releases/tag/v1.1.0)'ı yayımladım; #118 kapandı. Kalan, hepsi proje sahibinde: GitLab'da birleştirme isteği ([adımlar](f-droid/basvuru.md), #119), Obtainium bağlantısını telefonda denemek (#114).

**Durum (2026-11-18):** F-Droid başvurusu açıldı: [fdroiddata!57995](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/57995) (`New app: KeyKey`, tarif `v1.1.0`). Proje sahibi GitLab hesabını açıp çatalı oluşturdu ve commit e-postasını gizli adrese aldı; dalı, commit'i ve isteği onun onayıyla `glab` üzerinden ben açtım ([adımlar](f-droid/basvuru.md)). Açmadan önce iki engel çıktı ve ikisi de istekte açıkça yazıldı. Birincisi, F-Droid'in kabul politikası en az 3 ay geliştirme istiyor; KeyKey 2026-11-04'te başladı. Proje sahibi yine de başvurup istisna istemeyi seçti, olmazsa istek 2027-02-04'e kadar bekler. İkincisi, şablon büyük APK'lar için mimariye göre bölünmüş APK istiyor; 80,8 MB'lık APK için isterlerse bölmeyi teklif ettik. Çataldaki CI hesap doğrulaması istediği için çalışmadı; şablonun dediği gibi telefon ya da kart verilmedi, F-Droid'den başlatması rica edildi. #119 kapandı, inceleme ve kabul #130'da. Fazda kalan: Obtainium bağlantısını telefonda denemek (#114).

**Durum (2026-11-18, Obtainium):** README'deki bağlantı proje sahibinin telefonunda (Samsung, Android 13, Obtainium 1.7.4) denendi. Bağlantı tarayıcıda kalmadan Obtainium'u açıyor; Obtainium içe aktarmayı onaylatıyor, KeyKey'i ekliyor ve yenileyince en son sürümü `v1.1.0` olarak buluyor. İndirilecek dosya yalnızca `keykey-1.1.0.apk`; `.aab` ve `mapping.txt` seçilmiyor. Eklendikten hemen sonra sürüm "Bilinmeyen" görünüyor, liste aşağı çekilince geliyor; kılavuza yazıldı. Telefondaki KeyKey geliştirici anahtarıyla imzalı deneme sürümü olduğu için kurulum denenmedi; Obtainium'un sayfasında görünen sertifika da o anahtarınki (`16fb73ec…`). Faz 10 bitti: başvuru açık ve incelemesi #130'da, Obtainium bağlantısı çalışıyor. Proje sahibinin isteğiyle deneme aynı gün sıfırdan, gerçek bir kullanıcının yolundan tekrarlandı: Obtainium kaldırıldı; README GitHub uygulamasında açıldı, bağlantı Firefox'ta yönlendirme sayfasını açtı; Obtainium o sayfadaki bağlantıyla resmi sitesinden indirildi (özeti yayımlanan özetle aynı) ve kuruldu. Obtainium kuruluyken Firefox yönlendirmeyi kendiliğinden yapmıyor, sayfadaki "Click here if you are not redirected" düğmesi gerekiyor; ilk denemede bu görünmemişti, çünkü bağlantı adb ile açılmış ve Android onu doğrudan Obtainium'a vermişti. Sonrası ilk denemeyle aynı (içe aktarma onayı, "Bilinmeyen", yenileyince `v1.1.0`, yalnızca `keykey-1.1.0.apk`). Kılavuza Firefox adımı, README'ye başvurunun durumu eklendi. Aynı gün temiz bir emülatörde (Android 17, Chrome) yeni kullanıcının yolu baştan sona denendi: Chrome'da bağlantı Obtainium'u kendiliğinden açtı; KeyKey "Not installed" olarak eklendi, Install'a basınca Obtainium `v1.1.0`'ı buldu ve indirdi; Android Obtainium'a yükleme izni istedi, Play Protect "App scan recommended" dedi ("Install without scanning" ile geçildi). Kurulan KeyKey 1.1.0 (versionCode 5), yükleyeni Obtainium, sertifikası `66ff7b5c…`, APK yayındaki `keykey-1.1.0.apk` ile bayt bayt aynı; uygulama açıldı. Play Protect adımı kılavuza eklendi. Aynı akşam proje sahibinin telefonu yayın sürümüne geçti: şifreli yedek alındı (kopyası bilgisayarda), geliştirici anahtarıyla imzalı deneme sürümü kaldırıldı, 1.1.0 Obtainium'dan kuruldu (Samsung'da "Bilinmeyen uygulamaları yükle" izni, Play Protect'te "Taramadan yükle"; APK yayındakiyle bayt bayt aynı), yedek geri yüklendi, parmak iziyle açma yeniden açıldı. Bundan sonra telefondaki KeyKey'in güncellemeleri Obtainium'dan gelir. Geliştirici anahtarıyla imzalı deneme APK'ları artık onun üstüne kurulamaz; telefonda yeni bir deneme gerekirse ya ayrı paket adıyla derlenir ya da yayın sürümü yine yedekle kaldırılır.

**Durum (2026-11-18, F-Droid kararı):** İstek açıldıktan 18 dakika sonra F-Droid'den `linsui` kapattı: "This app doesn't meet the policy that it needs to be maintained for more than 3 months" ve "This app doesn't provide unique features". İlki bekleniyordu ve 2027-02-04'te kalkar. İkincisi daha ağır: F-Droid'de parola yöneticileri (KeePassDX gibi) ve 2FA uygulamaları (Aegis gibi) zaten var, KeyKey'in ikisini tek uygulamada birleştirmesi yeterli görülmedi. Yanıt yazılmadı, istek kapalı kaldı. Yeniden başvurmak proje sahibinin kararı (bkz. [1.0 sonrası](#10-sonrası)); başvuru yapılmazsa da yayın iş akışındaki F-Droid karşılaştırması birebir aynı derlemenin kanıtı olarak işe yarıyor. README ve gizlilik bildirimi buna göre düzeltildi, #130 kapandı. Dağıtım şimdilik GitHub Releases ve Obtainium.

**Bitti sayılması için:** ilk F-Droid sürümü (`v1.1.0`) yayınlandı ve yayın iş akışındaki F-Droid karşılaştırması yeşil; fdroiddata'ya birleştirme isteği açıldı; README'deki Obtainium bağlantısı telefonda çalışıyor.

### Faz 11 — Kullanıcı gözüyle iyileştirmeler

Proje sahibinin isteği (2026-11-17, gece): uygulamaya bir kullanıcının gözüyle bakmak, eksik ya da takılan yerleri gidermek, tasarımı iyileştirmek. Seçimler ve gerekçeleri: [kullanıcı gözüyle iyileştirmeler](docs/kullanici-gozuyle.md). Takip: #123. Hedef sürüm `1.1.0`; yeni özellikler yayından önce telefonda denenir.

**Durum (2026-11-17, sabaha karşı):** Belgedeki 15 maddeden 14'ü yapıldı; klavye maddesi gerekçesiyle proje sahibinin kararına bırakıldı. Ek olarak kayıttaki siteyi ve Hakkında bağlantılarını tarayıcıda açma (`INTERNET` izni olmadan) ve boş 2FA listesinde aktarma kısayolu. Bağımsız gözden geçirmenin bulduğu önemli hata (listeden açılan kayda dönüş) ve küçük bulgular düzeltildi. 1320 birim testi ve Android 17 emülatöründe entegrasyon testleri yeşil. Faz PR'ı #124; telefon denemesi için `keykey-deneme-16-kullanici-gozuyle.apk` taslak ön sürümde. Sürüm numarası telefon denemesinden sonra `1.1.0` olur.

**Tasarım (2026-11-17, sabah):** Proje sahibi camı yalnızca alt menüde istedi, gerisini bana bıraktı. Pencereler, menüler ve bildirim dolu yüzeye geçti; kayıt ayrıntısında alanlar iki kartta toplandı; kılavuz ve F-Droid görüntüleri yenilendi. Gerekçeler [belgede](docs/kullanici-gozuyle.md#tasarım-cam-yalnızca-alt-menüde). İkinci PR #125 birleşti, `keykey-deneme-17` telefonda.

**Telefon denemesi 17 (2026-11-17, öğleden sonra):** koyu temada alt menüdeki beyaz çizgi kaldırıldı; lisanslar yeniden denetlendi ve Lisanslar ekranı sadeleşti; ilk açılışa kullanım koşulları ve onay eklendi. Kararlar [belgede](docs/kullanici-gozuyle.md#telefon-denemesi-17-2026-11-17-öğleden-sonra). Üçüncü PR #126 birleşti, `keykey-deneme-18` telefonda.

**Telefon denemesi 18 (2026-11-17, akşamüstü):** koşullar kabul edildi, Lisanslar ekranı beğenildi; alt menüdeki beyaz çizgi açık temada da kaldırıldı, telefonda iki temada da doğrulandı (PR #127) ([belge](docs/kullanici-gozuyle.md#telefon-denemesi-18-2026-11-17-akşamüstü)).

**Kapanış (2026-11-17, akşam):** Proje sahibi telefonda başka bir şey görmedi ve kalan işleri bana bıraktı. Sürüm `1.1.0+5` oldu, değişiklik günlüğünün başlığı 1.1.0 aldı, iki dilde F-Droid sürüm notu eklendi. Klavye maddesi uygulanmadı; "1.0 sonrası" tablosunda proje sahibinin kararını bekliyor. #123, #124'teki `Closes` satırıyla erken kapanmıştı; yeniden açıldı, son faz PR'ıyla kapanıyor. `v1.1.0` etiketi birleştirme commit'ine atılır; dağıtım onayı ve yayımlama proje sahibinde. F-Droid tarifi `v1.0.1`'de kalıyor: başvuru o sürümle yapılır, sonraki sürümleri F-Droid etiketlerden kendisi bulur. **Faz 11 bitti.**

**Bitti sayılması için:** belgedeki "Bu fazda" maddeleri `main`'de, telefon denemesi için APK proje sahibinde.

### Faz 12 — Otomatik yedek

Proje sahibi 2026-11-18'de sıradaki işi bana bıraktı; "1.0 sonrası" listesinden bunu seçtim, çünkü bir parola yöneticisinde en büyük risk veri kaybı ve bugün yedek elle alınıyor. Tasarım, seçilmeyen yaklaşımlar ve gerekçeler: [otomatik yedek](docs/otomatik-yedek.md). Hedef sürüm `1.2.0`.

- [x] Klasör seçme ve kalıcı izin (`ACTION_OPEN_DOCUMENT_TREE`), klasöre yazma, listeleme ve silme köprüsü
- [x] Ayar kaydı sürüm 5: klasörün adresi ve adı
- [x] Dosya adı ve budama kuralı: en yeni 5 dosya ve en yeni 14 günün her birinin en yenisi; adda cihaz kimliği; elle alınan yedeklere ve başka cihazların yedeklerine dokunulmaz
- [x] Otomatik yedek denetleyicisi: kayıt değişince 5 sn sonra, kasa açılınca, ana parola değişince; tek iş; hata durumu
- [x] Ayarlarda "Otomatik yedek" satırı, açıklama penceresi, klasör değiştirme ve kapatma; yedek kartında durum
- [x] Güvenlik tasarımı, kılavuz ve değişiklik günlüğü
- [x] Android 17 ve 11 emülatörlerinde deneme
- [x] Telefonda deneme (proje sahibiyle, 2026-11-19, Obtainium güncellemesinden sonra): otomatik yedek çalışıyor

**Durum (2026-11-18, gece):** Kodda bitti ([plan](docs/otomatik-yedek-plani.md)). Uygulama sırasında verilen kararlar:

- Ayarlardaki satır diğer anahtarlar gibi davranıyor: dokununca açılıp kapanıyor. Klasörü değiştirme ve hemen yedekleme ayrı satırlarda.
- Android, seçiciden gelen geçici izni etkinlik kapanana kadar tutuyor; denetleyici bu yüzden yazmadan önce kalıcı izne bakıyor.
- Son gözden geçirmeden sonra (taze bir gözden geçirici, kritik bulgu yok) dosya adına cihaz kimliği eklendi: aynı klasörü kullanan iki telefon birbirinin yedeğini budamaz. Kimlik kasanın dışında, rastgele; yeniden kurulumda eski kimliğin dosyaları elle silinir.
- Aynı saniyedeki iki yedek ayrı ad alıyor, sağlayıcının "… (1)" kopyası geri alınıyor; yedek önce `.part` ara adıyla yazılıyor; en yeni 5 yedek hep kalıyor; alt klasörlere dokunulmuyor.
- Ayar değişiklikleri sırayla yazılıyor; kasanın yerine yedek konunca bu cihazın klasörü korunuyor; kurtarma anahtarıyla yeni parola ve birleştirerek geri yükleme de hemen yedekliyor.

Testler: 1439 birim ve arayüz testi. Gerçek Storage Access Framework testi ([`auto-backup-device-test.sh`](scripts/auto-backup-device-test.sh)) Android 17 ve 11 emülatörlerinde geçti, iki emülatörde de bütün entegrasyon testleri yeşil (2026-11-18 gecesi, son düzeltmelerden sonra). Sürüm `1.2.0+6` oldu.

1.2.0 olarak yayımlandı (2026-11-18). Telefondaki KeyKey yayın anahtarıyla imzalı ve Obtainium'la kurulu; telefon denemesi Obtainium güncellemesinden sonra yapılır.

**Bitti sayılması için:** kayıt değişince seçilen klasörde doğrulanmış bir yedek oluşuyor ve geri yükleme ekranıyla açılıyor; budama yalnızca otomatik yedeklere dokunuyor; izin kalkınca hata ayarlarda görünüyor.

### Faz 13 — Yeni kurtarma anahtarı

Proje sahibi 2026-11-18 gecesi kalan işleri soru sormadan yapmamı istedi. "1.0 sonrası" listesinden bunu seçtim: kâğıt kaybolursa ya da anahtarın kaydedildiği dosya sızarsa bugün kurtarma anahtarını değiştirmenin yolu yok, ana parola ise değiştirilebiliyor. İnternet izni ya da proje sahibinin kararını gerektiren fikirlere dokunulmadı. Tasarım: [`kurtarma-anahtari-yenileme.md`](docs/kurtarma-anahtari-yenileme.md), plan: [`kurtarma-anahtari-yenileme-plani.md`](docs/kurtarma-anahtari-yenileme-plani.md).

- [x] Kripto: yalnızca kurtarma yuvasını yeni rastgele anahtarla yeniden saran işlem; üst bilgi biçimi aynı
- [x] Servis ve denetleyici: ana parola kilit ekranının yolundan, yeni yuva bellekte, geri yazılan anahtarla doğrulanınca tek yazma; kilit ve yarıda kalma
- [x] Ayarlar → Güvenlik → "Yeni kurtarma anahtarı" ekranı; kurulumdaki anahtar adımları ortak bileşende
- [x] Güvenlik tasarımı, kılavuz, değişiklik günlüğü, sürüm `1.3.0+7`
- [x] Android 17 ve 11 emülatörlerinde bütün cihaz testleri
- [x] Son gözden geçirme
- [x] Telefonda deneme (proje sahibiyle, 2026-11-19, Obtainium güncellemesinden sonra): yenileme çalışıyor

**Durum (2026-11-19):** 1.3.0 olarak yayımlandı; telefon denemesi Obtainium güncellemesinden sonra yapılır. Uygulama sırasında verilen kararlar:

- Yeni anahtar ekranında "Kopyala" yok. Kasa açıkken başka uygulamaya geçmek kasayı hemen kilitler; kopyalayıp not uygulamasına yapıştıran kullanıcı, yenileme sessizce iptal olduğu halde geçersiz bir anahtarı saklamış olurdu. Son gözden geçirme bunu buldu.
- Anahtar doğrulanmadan kasa kilitlenirse kilit açılınca ayarlarda "kaydedilmedi, eski anahtar geçerli" uyarısı çıkar; uyarıdan yenileme yeniden başlatılabilir. İşaret yalnızca bellekte tutulur: uygulama kapanırsa uyarı çıkmaz, ama diske de bir şey yazılmamıştır.
- Parola ya da kurtarma anahtarı değiştiği anda kasa kilitlenirse otomatik yedek kasa açılınca yazılır.
- Ortak bileşenler `RecoveryWarningCard`, `RecoveryKeyCard`, `RecoveryKeyEntry`; dosya seçicinin kapıdan geçmesi `gated` ile seçilir (kurulumda kapalı).

Testler: 1467 birim ve arayüz testi; cihaz testleri (yenilemenin gerçek libsodium'la denendiği test dahil) Android 17 ve 11'de geçti. Gözden geçirme düzeltmelerinden sonra Android 11'de bütünü yeniden çalıştı; Android 17'deki koşu düzeltmelerden önceydi (düzeltmeler yalnızca arayüz ve birim testleriyle kapsanıyor).

**Bitti sayılması için:** yeni anahtar kasayı açıyor, eskisi açmıyor; yanlış parola ya da yarıda bırakma hiçbir şeyi değiştirmiyor; kurulum eskisi gibi çalışıyor.

### Faz 14 — Kart ve güvenli not kayıtları

Proje sahibi 2026-11-19'da kart bilgilerini en çok ihtiyaç duyduğu şey olarak söyledi. Tasarım: [`kart-ve-not.md`](docs/kart-ve-not.md), plan: [`kart-ve-not-plani.md`](docs/kart-ve-not-plani.md). Bu fazda internet izni eklenmedi.

- [x] Veri: `card` ve `note` kayıt türleri, katı JSON biçimleri, ortak kayıt deposu ve denetleyicisi; kart numarası, marka, Luhn ve son kullanma kuralları
- [x] Kart ekranları: kart yüzü, ayrıntı, form (numara gruplanır, yapıştırılan boşluk ve tire temizlenir, Luhn uyarısı)
- [x] Not ekranları: ayrıntı, form (64 KiB sınırı); yalnızca "Kopyala" ve "Tümünü seç" olan seçim menüsü
- [x] Kasa listesi üç türü birlikte gösteriyor, tür düğmeleri; çöp kutusu üç türü birlikte
- [x] Yedek: içerik sürümü 2 yalnızca kart ya da not varsa; daha yeni sürüm hatası; 64 MiB'ı aşan yedek yazılmıyor; geri yükleme kart ve notları doğruluyor ve sayıyor; otomatik yedek kart ve notları izliyor
- [x] Bitwarden'dan kart ve not içe aktarma; uymayan değer kartın notuna
- [x] Şifresiz dışa aktarmada biçim seçimi: CSV (notlar dahil) ve Bitwarden JSON (kartlar dahil)
- [x] Güvenlik tasarımı, kılavuz, değişiklik günlüğü, sürüm `1.4.0+8`
- [x] Android 17 ve 11 emülatörlerinde bütün cihaz testleri
- [x] Son gözden geçirme
- [ ] Telefonda deneme (proje sahibiyle, Obtainium güncellemesinden sonra)

**Uygulama sırasında verilen kararlar:**

- Kartsız ve notsuz yedek hâlâ içerik sürümü 1 ile yazılıyor; 1.3.0 kartlı yedeği "bozuk" diye reddediyor, değişiklik günlüğü bunu söylüyor.
- Geri yükleme özeti eski yedekte "0 kart ve 0 not" demesin diye iki metin var; kart ya da not varsa beşli özet çıkıyor.
- Elle yedekte sınırı aşan kasa için ayrı bir metin var ("Başka bir konum dene" yanlış yönlendirirdi); otomatik yedek bunu "yazılamadı" olarak gösteriyor.
- JSON dışa aktarmada marka Bitwarden'ın adlarıyla yazılıyor (Troy onda yok, `Other`); KeyKey içe aktarırken markayı zaten yok sayıyor.
- Bitwarden'ın onay kutusu alanları kart ve notta `ad: değer` satırı olarak nota ekleniyor; parolada eskisi gibi alınmıyor.

**Son gözden geçirme (2026-11-19):** Taze bir gözden geçirici bütün dalı okudu; kritik bulgu yok. Düzeltilenler, her biri önce kırmızı bir testle:

- Daha yeni içerik sürümü, JSON alanları denetlenmeden önce okunuyor; yoksa sonraki bir sürümün yedeği 1.4.0'da "bozuk" görünebilirdi. Yayımlanan sürümün davranışı sonradan değişmediği için yayından önce düzeltildi. Kayıt içerik sürümleri yedeğin içerik sürümüyle birlikte bir testte sabitlendi; tam 64 MiB sınırı bayt bayt sınanıyor.
- "Kasanın yerine yedeği koy" onayı kartları ve notları da sayıyor.
- Yarım son kullanma Kaydet'i sessizce kapatmıyor, uyarı çıkıyor; "12/2030" yapıştırılınca "12/30" oluyor; dolu numaraya araya yazılan rakam sondakini silmiyor.
- Metin kutularında uzun basınca açılan menüde kes ve kopyala hassas panodan geçiyor (parolalar dahil, bu 1.0'dan beri vardı); paylaş, ara, çevir düğmeleri yok. Not seçim menüsünde "Kopyalandı" bildirimi gerçek panoda çıkmıyordu.
- Bitwarden'da sayı olarak yazılmış kart değerleri okunuyor, başka türde değer nota gidiyor; 64 KiB'ı aşan not yapıştırması söyleniyor; kart görünümü yalnızca son dört haneyi gösteriyor; adsız kart sıralamada ve silme onayında listedeki adıyla; parola formu kart ve not klasörlerini de öneriyor.
- Kart, not ve içerik sürümü 2 yedeği için sabit örnek dosyalar eklendi.
- Bırakılanlar: donanım klavyesinde Ctrl+C ve klavyenin kendi kopyala düğmesi sistem panosuna yazıyor (bilinen sınır); entegrasyon testi yedeği arayüzden değil servislerden geri yüklüyor (arayüz yolu arayüz testlerinde ve telefon denemesinde); arama metninin her değişiklikte yeniden hazırlanması (performans testi geçiyor).

Düzeltmeler ikinci bir gözden geçirmeden geçti; bulguların hepsi kapandı.

Testler: 1649 birim ve arayüz testi. Bütün entegrasyon testleri son kodla Android 17 ve 11 emülatörlerinde geçti. Aynı koşularda cihaz kaydı deneme değerleri için tarandı: Android 17 temiz; Android 11'de Gboard'ın panodaki kart numarasını verdiği sistem metin sınıflandırıcısı numarayı bir hata metninde logcat'e yazdı ([denetim](docs/guvenlik-denetimi.md#kayıtlar-logcat)). KeyKey'in kendisi kayıt yazmıyor; bu, pano sınırlarına eklendi.

1.4.0 olarak yayımlandı (2026-11-19). İmza sertifikası aynı (`66ff7b5c…`), Obtainium 1.3.0'ın üstüne günceller; F-Droid'in kendi derlemesi APK'yla bayt bayt aynı çıktı.

**Bitti sayılması için:** kart ve not eklenip düzenleniyor, kasa listesinde ve çöpte görünüyor; yedekten geri geliyor; Bitwarden'dan içe ve JSON'la dışa aktarılınca alanlar kaybolmuyor; kartsız yedekler eski sürümlerle açılıyor.

### Faz 15 — Kart doldurma

Faz 14'teki kartların ödeme formlarına doldurulması ([#149](https://github.com/aaudraa/KeyKey/issues/149)). Tasarım: [`kart-doldurma.md`](docs/kart-doldurma.md), plan: [`kart-doldurma-plani.md`](docs/kart-doldurma-plani.md). İnternet izni eklenmedi.

- [x] Kart alanlarını tanıma: Android ipuçları, HTML `autocomplete`, Chrome'un tahmini, güvenlik kodu adları, Türkçe ve İngilizce sözcükler; iki grup kuralıyla ödeme formu; kart alanları giriş tanımaya ve kaydetmeye girmiyor
- [x] Değerleri alanın türüne göre biçimleme: bölünmüş numara, ad ve soyad, son kullanma biçimleri, açılır liste ve tarih alanı
- [x] Ayrı "KeyKey ile kart doldur" önerisi, `fillCard` köprüsü, istek türünün denetimi
- [x] Doldurma ekranında kart listesi, arama, `http` uyarısı
- [x] Örnek uygulamada üç kart formu; Android 17 ve 11 emülatörlerinde elle deneme, kayıt taraması
- [x] Güvenlik tasarımı, kılavuz, değişiklik günlüğü, sürüm `1.5.0+9`
- [x] Son gözden geçirme
- [ ] Telefonda deneme (proje sahibiyle)

**Uygulama sırasında verilen kararlar:**

- Ödeme formunda "kart şifresi" ya da "card PIN" diyen kutu kart PIN'i sayılıyor ve hiç doldurulmuyor; giriş tanımaya da girmiyor, böylece ona parola doldurulmuyor ve kaydedilmiyor.
- Chrome bir alanı kart dışı bir türle (örneğin parola) biliyorsa o alanda sözcüklere bakılmıyor; Chrome bütün sayfayı görüyor.
- Yanlış türde bir doldurma çağrısı (kart isteğine giriş, giriş isteğine kart) Kotlin'de doldurmadan kapanıyor. Bunun otomatik testi yok, çünkü etkinlik Android çerçevesi istiyor; Flutter yalnızca isteğin türüne uyan çağrıyı yapıyor ve bu test ediliyor.

**Cihazda bulunan:** Android 14 ve sonrası ipucu verilmemiş gizli kutulara kendiliğinden `passwordAuto` ipucunu ekliyor. İlk denemede sınıflandırıcı bunu geliştiricinin ipucu sandı ve ipucusuz formdaki gizli CVV kutusu parola sayıldı: kart doldurulmadı, kutuda giriş önerisi çıktı. Bu ipucu artık yok sayılıyor; testle birlikte düzeltildi ve iki emülatörde yeniden denendi. Örnek uygulamanın açılır listeleri de doldurulmadı, çünkü koddan kurulan `ArrayAdapter` seçeneklerini doldurma sistemine vermiyor; bu KeyKey'in değil örnek uygulamanın eksiğiydi (`setAutofillOptions` eklendi). Seçeneklerini bildirmeyen gerçek bir uygulamada KeyKey listeye değer tahmin etmiyor.

**Son gözden geçirme (2026-11-20):** Taze bir gözden geçirici bütün dalı okudu ve sınıflandırıcıyı örnek girdilerle ayrıca çalıştırdı. Kritik bulgu yok; Türkçe formlarda üç önemli bulgu vardı. Hepsi önce kırmızı bir testle düzeltildi, tasarım belgesi yeni kurallarla güncellendi:

- "Kredi kartı sahibi" kutusu numara sanılıyor, numara sahibi kutusuna yazılıyordu. Kart türü adları ("kredi kartı") tek başına numara sayılmıyor; hediye ve üyelik kartları, taksit seçimi (Aralık kartı 12 taksit seçebilirdi), SMS ve resim kodları kart sayılmıyor; aynı yeri tutan güçlü kanıtlı alan varsa sözcükle bulunan tahmin geçersiz.
- Kart numarasıyla girilen banka formunda captcha "Güvenlik kodu" formu ödeme formu yapıyordu. Yalnızca zayıf kanıtla verilecek karar, formda kart dışı parola kutusu ya da kart şifresi varsa verilmiyor.
- Tek başına duran gizli "Güvenlik kodu" kutusu parola sayılıyordu; artık hiçbir formda sayılmıyor.
- Bırakılanlar (küçük): birleşik "AA/YY" açılır listesi tanınıyor ama doldurulmuyor; kutu sınırları numaradan kısa bölünmüş numara kesik yazılıyor; standart dışı `autocomplete` değerleri Chrome'un kart tahminini gizleyebilir (cihazda denenmeli); Pigeon'un ürettiği `toString` kart değerlerini yazıyor (hiçbir yerde kaydedilmiyor); kart listesinde son dört haneyle arama yok.

Testler: 1667 birim ve arayüz testi, 65 Kotlin testi. Bütün entegrasyon testleri son kodla Android 17 ve 11 emülatörlerinde geçti. Düzeltmelerden sonra örnek formlar iki emülatörde yeniden denendi; Android 17'nin kaydı temiz.

1.5.0 olarak yayımlandı (2026-11-20, [#150](https://github.com/aaudraa/KeyKey/pull/150)). İmza sertifikası aynı (`66ff7b5c…`), Obtainium 1.4.0'ın üstüne günceller; F-Droid'in kendi derlemesi APK'yla bayt bayt aynı çıktı.

**Bitti sayılması için:** üç örnek formda (ipuçlu, ipucusuz, web) kart listeden seçilip bütün alanlar doğru doluyor; güvenlik kodu parola sanılmıyor ve kaydetme önerisi çıkmıyor; giriş doldurma ve kaydetme eskisi gibi çalışıyor.

### Faz 16 — İnternete açılma ve sızıntı kontrolü

KeyKey'in ilk internet özelliği ([#152](https://github.com/aaudraa/KeyKey/issues/152)). Tasarım: [`internet-ve-sizinti.md`](docs/internet-ve-sizinti.md), plan: [`internet-ve-sizinti-plani.md`](docs/internet-ve-sizinti-plani.md).

- [x] Ağ istemcisi tek dosyada (`lib/core/network/pwned_passwords_client.dart`); başka yerde ağ kodu olmadığını denetleyen test
- [x] Sızıntı denetimi: SHA-1, önek gruplama, dolgu, en çok 4 eşzamanlı istek, karışık sıra, bir kez yeniden deneme, iptal; biçime uymayan yanıt "temiz" sayılmıyor
- [x] Parola raporunda "Sızıntı kontrolü": açıklama, Have I Been Pwned atfı, ilerleme, hata ve yeniden dene, görülme sayılarıyla liste
- [x] Android: `INTERNET` izni, şifresiz trafik kapalı, ağ güvenliği yapılandırması, yayın APK denetimi
- [x] Metinler: kullanım koşulları sürüm 2 (yeniden soruluyor), tanıtım, gizlilik bildirimi, README, mağaza açıklamaları, F-Droid `NonFreeNet`; metinlerin "internete çıkmaz" demediğini denetleyen test
- [x] Android 17 ve 11 emülatörlerinde gerçek API'yle deneme, uçak modu, kayıt taraması
- [x] Güvenlik tasarımı, denetim, İngilizce özet, kılavuz, değişiklik günlüğü, sürüm `1.6.0+10`
- [x] Son gözden geçirme: taze gözden geçirici kritik bulgu bulmadı. Düzeltilenler: sızan parolalar değiştirilince raporun yanlışlıkla "sızıntı yok" demesi (artık denetlenmeyen parolaları söylüyor), boş yanıtın "temiz" sayılması, ağ denetimi testinin kaçırdığı ağ yolları ve Java dosyaları, kalan "internete çıkmaz" ifadeleri

**Uygulama sırasında verilen kararlar:**

- Sızıntı kontrolü raporun en üstünde ve yalnızca düğmeyle başlıyor; ayar, arka plan denetimi ya da kaydedilen sonuç yok. Sonuç yalnızca bellekte, rapor ekranıyla yaşıyor.
- Yeni paket eklenmedi: Dart'ın `HttpClient`'ı. Sertifika sabitleme yok (trafikte parola yok; sabitleme hizmetin sertifikası değişince denetimi bozardı).
- Kartlar ve notlar denetlenmiyor; yalnızca giriş kayıtlarının parolaları.

**Uygulama sırasında bulunan:** Flutter 3.47, Android'in şifresiz trafik yasağını (`usesCleartextTraffic`, ağ güvenliği yapılandırması) Dart'ın `HttpClient`'ına uygulamıyor: motor `domainNetworkPolicy` değerini boş geçiyor ve emülatörde `http://` isteği reddedilmedi. Tasarım bunun tersini varsayıyordu. İstemci artık https dışı adresi kendisi reddediyor (testle); manifest ayarları platform kodu için duruyor. Hata ayıklama derlemesinde Flutter araç bağlantısı için `INTERNET` izni zaten var; yayın derlemesindeki izin `check-release-apk.sh` ile denetlendi.

**Cihazda (2026-11-20):** Android 17 ve Android 11 emülatörlerinde gerçek API'yle denendi: `password` sızmış, rastgele parola temiz çıktı; uçak modunda "Denetlenemedi" çıktı; logcat'te önek, özet ya da parola yok. Koşullar 1'den 2'ye yükselince tanıtım ve koşullar yeniden soruldu. Android 17'de bütün cihaz testleri geçti.

**Bu fazda görülen eski hata:** parmak izi cihaz testi, 1.1.0'da gelen "kilit açılınca kalınan sekmeye dön" davranışından beri kasa listesini bekliyordu; Android 17'deki tam koşuda kırıldı ve düzeltildi.

1.6.0 olarak yayımlandı (2026-11-20, [#154](https://github.com/aaudraa/KeyKey/pull/154), Faz 17 ile birlikte). İmza sertifikası aynı (`66ff7b5c…`), Obtainium 1.5.0'ın üstüne günceller; F-Droid'in kendi derlemesi APK'yla bayt bayt aynı çıktı. Yayın APK'sında yeni izin yalnızca `INTERNET`.

**Bitti sayılması için:** raporda `password` gibi sızmış bir parola görülme sayısıyla listeleniyor; bağlantı yokken ya da beklenmeyen yanıtta "Denetlenemedi" çıkıyor, yanlış bir "sızıntı yok" çıkmıyor; güncellemeden sonra koşullar bir kez yeniden soruluyor; kayıtta parola, özet ya da önek yok.

### Faz 17 — Kartlar ve notlar için gezinme

Proje sahibinin 2026-11-20 gecesi isteği ([#153](https://github.com/aaudraa/KeyKey/issues/153)): kartlar ve notlar, kasa listesinin üstünde sekme gibi duran düğmelerle değil, alttaki menüde kendi sekmeleriyle açılsın. Tasarım: [`gezinme.md`](docs/gezinme.md), plan: [`gezinme-plani.md`](docs/gezinme-plani.md). Faz 16 ile aynı sürümde (1.6.0) çıkar; planlanan 17-23 numaralı fazlar 18-24 oldu.

- [x] Alt menüde beş sekme: Parolalar, Kartlar, Notlar, 2FA, Ayarlar; kasa listesindeki tür düğmeleri kalktı
- [x] Her sekme kendi türünü, klasörlerini ve çöp kutusunu gösteriyor; parola raporu ve yedek hatırlatıcısı Parolalar'da
- [x] Yollar `/kartlar` ve `/notlar` altında; "+" ile eklenen kayıt kendi sekmesinde, kilitten dönüş kart ve notun ayrıntısına
- [x] Dar ekranda menünün boşlukları daralıyor (320 dp ve %200 yazıda taşma yok, sekmeler 48 dp)
- [x] Tanıtımın "Nerede ne var" sayfası, kılavuz, cam tasarım belgesi, değişiklik günlüğü
- [x] Erişilebilirlik testleri kart ve not listeleri, ayrıntıları ve çöp kutusu için
- [x] Android 11 ve 17 emülatörlerinde bütün cihaz testleri (Android 17'deki koşu yayından sonra tamamlandı)
- [x] Son gözden geçirme

**Uygulama sırasında verilen kararlar:**

- Telefonda beş sekme ve "+" şeride sığıyor ama seçili sekmenin adı sığmıyor; sekmeler yalnızca simgeyle görünür, seçili olan kapsülde. Geniş ekranda ad yine görünür. Simgeler: anahtar, kart, not.
- Yedek hatırlatıcısı ve okunamayan kayıt uyarısı bütün kasa için; yalnızca açılıştaki sekmede, Parolalar'da görünür.
- Her sekmenin çöp kutusu yalnızca kendi türünü gösterir; "Tümünü geri yükle" ve "Çöpü boşalt" da yalnızca o türe dokunur.

**Cihazda (2026-11-20):** Android 11 emülatöründe bütün cihaz testleri geçti; iki eski test (arama etiketi, seçili sekmenin simgesi) düzeltildi ve yeniden koşuda geçti. Android 17'deki tam koşu, bilgisayarın belleği azaldığı için ilk 4 testten sonra durduruldu ve yeniden başlatılmadı; Android 17'de aynı koşu Faz 16 koduyla tam geçmişti. Proje sahibinin isteğiyle yayından sonra (2026-11-20 öğleden sonra) 1.6.0'ın `main`'i Android 17'de baştan sona koşuldu: entegrasyon testlerinden 27'si geçti, 7'si bu emülatörde atlandı; parmak izi (4/4), pano (3/3) ve kamera (izin verilince ve verilmeyince) denemeleri geçti.

1.6.0 olarak yayımlandı (2026-11-20, [#155](https://github.com/aaudraa/KeyKey/pull/155), Faz 16 ile birlikte).

**Bitti sayılması için:** kart ve not alttaki menüden açılıyor; kasa listesinin üstünde tür düğmesi yok; "+" ile eklenen kart Kartlar'da, not Notlar'da görünüyor; her çöp kutusu yalnızca kendi türünü geri yüklüyor; 320 dp ekranda menü taşmıyor.

### Faz 18 — Kullanım kolaylıkları

1.0 sonrası listesinin dört küçük işi ([#157](https://github.com/aaudraa/KeyKey/issues/157)). Proje sahibi 2026-11-20'de yol haritasını onay beklemeden bitirmemi istedi; kararlar bu yüzden benim. Tasarım: [`kullanim-kolayligi.md`](docs/kullanim-kolayligi.md), plan: [`kullanim-kolayligi-plani.md`](docs/kullanim-kolayligi-plani.md).

- [x] Ayarlar sürüm 6: arka plan kilidi süresi ve klavye ayarı; yedeğin içerik sürümü 3
- [x] Arka planda kilitlenme süresi (Hemen, 30 saniye, 1 dakika), iki saatle ölçülüyor; dönüşte parola listesi yeniden okunuyor
- [x] Gizli olmayan kutularda normal klavye (isteğe bağlı)
- [x] Parolalar, Kartlar ve Notlar'da toplu seçim: tümünü seç, klasöre taşı, çöp kutusuna taşı ve geri al
- [x] Steam Guard kodları: içe aktarma (Aegis, 2FAS, otpauth, Bitwarden `steam://`), elle ekleme, Bitwarden dışa aktarma
- [x] Android 17 ve 11 emülatörlerinde bütün cihaz testleri ve bu fazın cihaz denemeleri
- [x] Kılavuz, güvenlik tasarımı, değişiklik günlüğü, mağaza notu
- [x] Son gözden geçirme

**Uygulama sırasında verilen kararlar:**

- Kasa ayarları sürüm 6 olunca 1.6.0, 1.7.0'ın yedeğindeki ayar kaydını okuyamaz ve yedeği "bozuk" sanardı; Steam hesabı da öyle. Yedeğin içerik sürümü 3 oldu ve her yedek bu sürümle yazılıyor (kayıtlar şifreli olduğu için içlerine bakılamıyor). Eski sürüm artık "daha yeni bir yedek" diyor; 1.6.0'a geri dönüş için yedek açılamıyor.
- Bekleme süresini ya da klavye ayarını gevşetmek kimlik doğrulaması istemiyor: ayarı değiştirebilen kişi kasayı zaten açık tutuyor. Bekleme süresinde kasa açık kaldığı için 2FA ek onayı da sürüyor.
- Kullanıcı adı, özel alan adları ve kart sahibi her ayarda öğrenmeyen klavyede kalıyor; işaretlenmemiş yeni bir kutu da öyle.
- Bitwarden Steam hesabını yalnızca `steam://ANAHTAR` biçiminde tanıyor; `otpauth://steam/…` verilince 5 haneli sayı, yani yanlış kod üretiyor. Bitwarden biçimli dışa aktarma bu yüzden `steam://` yazıyor, içe aktarma da okuyor.
- 2FA formunda üç tür dar ekrana sığmadığı için tür seçimi çiplerle.
- Normal klavyeli kutularda klavyenin öneri şeridi açık, düzeltme ve öğrenme isteği kapalı. Tasarım öneriyi de kapalı istiyordu, ama Flutter Android'de öneriyi kapatan her kutuyu görünür parola klavyesine çeviriyor; cihaz denemesinde ayar hiçbir şeyi değiştirmiyordu (ad kutusu `0x82091`, web adresi `0x80091`). Şimdi ad `0x2001` (kelime başı büyük harf), web adresi `0x11` (adres klavyesi).

**Son gözden geçirme:** Bağımsız gözden geçirme iki önemli bulgu verdi, ikisi de önce testle düzeltildi. (1) Bekleme süresinde açık kalan bir düzenleme formu ya da toplu işlem, doldurma ekranının bu arada kaydettiği yeni parolayı eski kopyayla ezebiliyordu; artık küçük yazmalar kaydın en son hâline yapılıyor, form yalnızca kullanıcının değiştirdiği alanları taşıyor. (2) Dart'ın `Stopwatch`'ı telefon uyurken duruyor; uyku ile saati geri almak bir araya gelince süre uzayabiliyordu. Tekdüze saat Android'de `CLOCK_BOOTTIME` oldu (FFI ile `clock_gettime`); bir cihaz testi bunu `/proc/uptime` ile karşılaştırıyor. Tasarımın "kelime başı büyük harf" maddesine de dönüldü. Küçük bulgular (5 dakika kilidinin dönüşte yeniden kurulmaması, toplu klasör penceresinde harf büyüklüğü, TalkBack'in seçili olmayan satırı okuması gibi) sonraya kaldı.

**Cihazda (2026-11-20):** Android 17'de bütün cihaz testleri geçti (entegrasyonda iki içe aktarma testinin hesap sayısı Steam yüzünden değişmişti, düzeltilip yeniden koşuldu). Bu fazın denemeleri Android 17'de gerçek kullanıcı yolundan: varsayılan ayarda dönüşte kasa kilitli; 30 saniye ayarında kısa dönüşte açık, 40 saniyelik dönüşte kilitli; normal klavye ayarında ad ve web adresi doğru klavye türüyle, kullanıcı adı ve parola yine görünür parola klavyesiyle; iki kayıt seçilip çöpe taşındı, "Geri al" ikisini de getirdi; Steam hesabı elle eklendi, kopyalanan kod bağımsız bir Python hesabıyla aynı. Android 11'de bütün entegrasyon testleri (yeni saat testi dahil), parmak izi, pano ve kamera testleri geçti; normal klavye ayarında kutu türleri Android 17'dekiyle aynı.

1.7.0 olarak yayımlandı (2026-11-20, [#158](https://github.com/aaudraa/KeyKey/pull/158)). İmza sertifikası aynı (`66ff7b5c…`), Obtainium 1.6.0'ın üstüne günceller; F-Droid'in kendi derlemesi APK'yla bayt bayt aynı çıktı. Yeni izin yok.

**Bitti sayılması için:** 30 saniye ayarında 10 saniye sonra dönülünce kasa açık, 31 saniye sonra, telefon uyuyup döndüğünde ya da saat geri alındığında kilitli; normal klavye ayarında parola kutusu yine öğrenmeyen klavyede; aramayla gizlenen seçili kayıt çöpe gitmiyor; Steam kodu Steam uygulamasının kodlarıyla aynı.

### Faz 19 — Senkron

Kasanın kullanıcının kendi WebDAV klasörü üzerinden telefonlar arasında uçtan uca şifreli eşitlenmesi ([#160](https://github.com/aaudraa/KeyKey/issues/160)). Proje sahibi soru istemedi; kararlar benim. Tasarım: [`senkron.md`](docs/senkron.md), plan: [`senkron-plani.md`](docs/senkron-plani.md). Google Drive ayrı bir iş: proje sahibinin Google Cloud hesabında bir OAuth istemcisi gerekir.

- [x] Veritabanı şeması 2: silme kayıtları ve yuva zamanları; kalıcı silme iz bırakıyor
- [x] Ayarlar sürüm 7 (senkron bilgileri), yedeğin içerik sürümü 4, senkron dosyasının `sync` nesnesi
- [x] Birleştirme: kayıt kayıt, yeni olan kazanır, silme kayıtları, kaybeden parolanın kurtarılması, yuvaların ayrı birleşmesi, 24 saat saat sınırı
- [x] WebDAV istemcisi (yalnızca HTTPS, yönlendirme yok, `.part` yazıp geri okuma, Nextcloud/Apache/rclone listeleri); ağ kodu iki dosyada
- [x] Eşitleme servisi ve tetikler (açılış, değişiklik, dönüş, elle); tek seferde bir eşitleme
- [x] Ayarlar → Senkron: kurulum, durum, şimdi eşitle, cihazlar, kaldırma, kapatma
- [x] Yeni telefonu senkrondan kurma; senkron açıkken geri yükleme; başka kasası olan telefonu katma
- [x] Kullanım koşulları sürüm 3, gizlilik bildirimi, güvenlik tasarımı ve özeti, kılavuz, değişiklik günlüğü, mağaza notu
- [x] Entegrasyon testi ve gerçek bir WebDAV sunucusuyla (rclone) cihaz denemeleri
- [x] Son gözden geçirme

**Uygulama sırasında verilen kararlar:**

- Her telefon klasöre yalnızca kendi dosyasını yazar (`keykey-sync-<cihaz>.keykey`); öteki telefonların dosyalarını yalnızca okur. Böylece iki telefon aynı dosyaya yazıp birbirinin değişikliğini ezemez ve sunucudan kilit istemek gerekmez.
- Dosya yedekle aynı biçimde; ayar kaydı ve uygulama parolası dosyaya girmez. Yedeğin içerik sürümü 4 olduğu için 1.7.0 1.8.0'ın yedeklerini açamaz, "daha yeni bir yedek" der.
- Silme kayıtları senkron kapalıyken de yazılır: senkron sonradan açılınca eski silmeler bilinir ve başka telefonun dosyası silinen kaydı geri getiremez.
- Değişmeyen dosya (ETag'i aynı) bir sonraki eşitlemede indirilmez; kasa kilitlenince bu bellek silinir.
- Başka kasanın dosyası olan klasörde senkron açılmaz; telefon o kasaya ancak o kasanın ana parolasıyla katılabilir. Katılınca kasa yeni oturumla açık kalır, kilit ekranına gidilmez.
- Senkron açıkken geri yüklenen kayıtlar şimdiyle damgalanır; öteki telefonlardaki eski silmeler onları yeniden silmez. Değiştirmede yedekte olmayan kayıtlar eşitlemede geri gelir, yani geri yükleme senkron üzerinden hiçbir şeyi silmez.
- Ayarlar'da senkron, yedek grubunun altında kendi grubunda ("Telefonlar arası").
- Ana parola değişince ya da kurtarma anahtarı yenilenince senkron beklemeden eşitler. Tasarımın tetik listesinde yoktu; cihaz denemesinde yeni üst bilgi bir sonraki tetiğe kadar telefonda kaldı, sunucudaki dosya o arada eski parolayla açılıyordu.

**Son gözden geçirme:** Bağımsız gözden geçirme (Opus) iki kritik ve üç önemli bulgu verdi; hepsi önce testle düzeltildi. (1) Ara dosyanın `.part` eki: Nextcloud ve ownCloud bu eki yarım yükleme sayıp dosya önbelleğine almıyor, her eşitleme hata verirdi. Ara ek `.tmp` oldu. (2) Uzun süre eşitlenmemiş bir telefonda çöp kutusunun süresi dolunca silme kaydı şimdiyle yazılıyordu; başka telefonda sonradan çöpten çıkarılan kayıt bütün telefonlardan siliniyordu. Silme kaydı artık çöpe atılan sürümün zamanını taşıyor. (3) Eşitleme yerel durumu okuyup ayrı bir işlemde yazıyordu: arada kaydedilen bir değişiklik eziliyor, geri yükleme başka bir kasa koyduysa eski oturumun kayıtları yeni kasaya yazılabiliyordu. Okuma, birleştirme ve yazma artık tek işlemde; diskteki kasa oturumun kasası değilse hiçbir şey yazılmıyor. (4) Üst bilgi yuvaları oturumun elindeki kopyadan kuruluyordu; bir yarışla parola değişikliği ya da yeni kurtarma anahtarı geri alınabilirdi. Üst bilgi artık diskten okunuyor, her işlem yalnızca kendi yuvasını yazıyor, kilitten hemen önce biten eşitlemeden sonra kilit ekranı diskteki üst bilgiyi alıyor. (5) Kılavuz ve güvenlik tasarımı artık parolası sızan kullanıcıya kasayı yeni bir kasaya taşımayı öneriyor. Gerçek bir Nextcloud sunucusuyla deneme yapılamadı: bu makinede kapsayıcı aracı yok, Nextcloud da Windows'ta çalışmıyor. Küçük bulgular (beklenmedik bir hatadan sonra oturum boyunca eşitlemenin durması, eşitleme sürerken kapatılan senkronun dosyayı geri yükleyebilmesi, çok büyük kasada yanlış hata metni, otomatik yedeğin eşitlemeyle gelen değişiklikleri saymaması, şema göçünün işlem içinde olmaması gibi) sonraya kaldı.

**Cihazda (2026-11-20/21):** Android 17 ve Android 11 emülatörlerinde bütün entegrasyon testleri (yeni senkron testi dahil: telefonun içinde çalışan küçük bir WebDAV sunucusu, gerçek istemci, SQLite ve libsodium ile iki telefonun birleşmesi, silmenin taşınması, yarım kalan yüklemenin görünmemesi), parmak izi, pano ve kamera testleri geçti. 2FA akış testi Android 17'de yalnızca emülatörün animasyon ölçekleri 0 iken çerçeve hatası veriyor; 1.7.0'da da aynı, ölçekler kullanıcı varsayılanı olan 1'deyken geçiyor. Gerçek kullanıcı yolu Android 17'de `rclone serve webdav` ile (kullanıcı adı ve parolalı, `adb reverse` ile `http://127.0.0.1`): kasa kuruldu, senkron açıldı, kayıt eklendi; sunucudaki dosyada kayıt adı, kullanıcı adı, parola, uygulama parolası ve cihaz adı şifresiz geçmiyor. Uygulama verisi silinip "Senkrondan kur" ile ikinci telefon gibi kuruldu, kayıt geldi; kalıcı silinen kayıt öteki telefonun eski dosyasından geri gelmedi. Parola değişikliğinin hemen yüklenmediği burada bulundu ve düzeltildi; düzeltmeden sonra parola değişince dosya beş saniye içinde yeni üst bilgiyle yüklendi, yeni kurulan telefonda eski parola reddedildi, yenisi kasayı açtı. Son gözden geçirmenin düzeltmelerinden sonra senkron, kasa akışı, uygulama ve yedek entegrasyon testleri Android 17'de yeniden geçti.

1.8.0 olarak yayımlandı (2026-11-21, [#161](https://github.com/aaudraa/KeyKey/pull/161)). İmza sertifikası aynı (`66ff7b5c…`), Obtainium 1.7.0'ın üstüne günceller; F-Droid'in kendi derlemesi APK'yla bayt bayt aynı çıktı. Yeni izin yok.

**Bitti sayılması için:** iki telefonda eklenen, değiştirilen ve silinen kayıtlar ötekine geçiyor; eski bir dosya yeni bir değişikliği geri almıyor; kalıcı silinen kayıt geri gelmiyor; yeni telefon senkrondan kuruluyor; başka kasası olan telefon kayıtlarını kaybetmeden katılıyor; sunucuya giden dosyada şifresiz kayıt yok.

### Faz 20 — KeePass içe aktarma

KeePass 2, KeePassXC, KeePassDX ve Keepass2Android'in `.kdbx` dosyalarını ana parola ve anahtar dosyasıyla açıp kasaya almak ([#177](https://github.com/aaudraa/KeyKey/issues/177)). Proje sahibi soru istemedi; kararlar benim. Tasarım: [`keepass-ice-aktarma.md`](docs/keepass-ice-aktarma.md), plan: [`keepass-ice-aktarma-plani.md`](docs/keepass-ice-aktarma-plani.md).

- [x] Test dosyaları (pykeepass, KeePassXC, KeePassXC'in komut satırıyla oluşturulan) ve kaynak belgesi
- [x] KDBX okuyucu: başlık, sözlük, anahtar dosyası, blok akışları, şifre çözme (`pointycastle`), iç akış, XML
- [x] Anahtar türetme: Kotlin'de AES-KDF, Argon2 başvuru uygulaması JNI ile; Pigeon arka plan kuyruğu
- [x] Kayıt eşleme: klasör, 2FA, özel alanlar, başvurular, çöp kutusu, güvenli not
- [x] KeePass dosyasını aç ekranı ve önizlemeye bağlama
- [x] Bozuk girdi testleri, cihaz testleri (Android 11 ve 17)
- [x] Güvenlik tasarımı, bağımlılıklar, lisanslar, kılavuz, değişiklik günlüğü
- [x] Son gözden geçirme, 1.9.0

Son gözden geçirme taze bir alt ajanla yapıldı: kritik bulgu yok; iki önemli bulgu (bozuk bir `otp` değerinin ekranı "açılıyor"da bırakması, çözülmüş verinin sıfırlanmayan tamponları) ve önemliye yükseltilen iki küçük bulgu (yarım inmiş KDBX 3 dosyasına "yanlış parola" denmesi, sıfırlanmayan ara anahtarlar) düzeltildi. Dosya sınırı 64'ten 32 MiB'a indi: dosya Kotlin'den Pigeon'la geçerken Java yığınında birkaç kopya oluyor. Ertelenen küçük bulgular [#180](https://github.com/aaudraa/KeyKey/issues/180)'de.

Ölçümler (emülatör, x86_64): Argon2d 64 MiB, 10 geçiş, 2 şerit 0,35 saniye; AES-KDF on milyon tur 0,33 saniye (ilk Kotlin sürümü ECB ile 11,6 saniyeydi; sıfırlar üstünde CBC zinciriyle 35 kat hızlandı).

**Bitti sayılması için:** test klasöründeki bütün desteklenen dosyalar bilgisayarda ve telefonda açılıyor ve aynı kayıtları veriyor; yanlış parola, desteklenmeyen biçim ve bozuk dosya ayrı mesajlarla reddediliyor; KeePassXC'in varsayılan ayarlarıyla oluşturulmuş bir dosya telefonda makul sürede açılıyor; hiçbir şey diske yazılmıyor.

### Faz 25 — Uygulama ve site eşleştirme

İnternet izni yokken bir uygulamanın hangi siteye ait olduğu doğrulanamıyordu, uygulama kayda ilk doldurmada elle bağlanıyordu. Proje sahibi 2026-11-22'de bunun internetle yeniden ele alınmasını istedi ("o an engelimiz vardı artık yok"; "hangi sistem daha iyi ve sağlamsa"). Faz 20'den sonra yapılır ([#178](https://github.com/aaudraa/KeyKey/issues/178)).

- Önce internetsiz: Android 12+ `DomainVerificationManager` ile sistemin zaten doğruladığı alan adları.
- Sonra internetle: kayıtlı sitenin `/.well-known/assetlinks.json` dosyası (Digital Asset Links); paket adı ve imza özeti tutarsa eşleşme kendiliğinden kurulur. Ağ kodu üçüncü bir dosyaya çıkar, gizlilik bildirimi güncellenir.
- Güvenilen tarayıcı listesi gömülü kalır, internetten güncellenmez: sahte siteye karşı ana savunma o.

Proje sahibi soru istemedi; kararlar benim. Tasarım: [`uygulama-site-eslestirme.md`](docs/uygulama-site-eslestirme.md), plan: [`uygulama-site-eslestirme-plani.md`](docs/uygulama-site-eslestirme-plani.md).

- [x] Kotlin: uygulamanın alan adları ve doğrulama durumu (`DomainVerificationManager`, yalnızca `VERIFIED`)
- [x] Doğrulanmış site eşleşmesi, paket adından site türetme
- [x] `assetlinks.json` istemcisi (üçüncü ağ dosyası) ve karar
- [x] Ayar (varsayılan kapalı); ayar kaydı sürüm 8, yedek içerik sürümü 5, senkron dosyası 4'te
- [x] Doldurma ekranı: internet adayları, önbellek, kendiliğinden bağlama
- [x] Cihazda: sistemin doğrulaması ve internet yolu (Android 17, Wikipedia)
- [x] Güvenlik tasarımı, gizlilik, koşullar sürüm 4, kılavuz, değişiklik günlüğü
- [x] Son gözden geçirme, 1.10.0

Bir karar plandan saptı: ayar kaydının sürümü artınca yedeğin içerik sürümü de artmalı (bunu bir test sabitliyor). Yedekler 5 ile yazılıyor, eski sürüm "daha yeni yedek" der. Senkron dosyası ayar kaydı taşımadığı için 4'te kaldı; böylece 1.9.x telefonlarla eşitleme kırılmıyor. Kullanım koşullarındaki "internete yalnızca … için çıkar" cümlesi yeni özellikle eksik kalacağı için koşullar sürüm 4 oldu.

**Son gözden geçirme:** Taze bir alt ajan (Opus) kritik bulgu bulmadı. Bir önemli bulgu düzeltildi: sitesi doğrulanmış bir uygulama (Instagram gibi) kendi tarayıcısında başka birinin sahte giriş sayfasını açarsa, uygulamanın sitesinin kaydı uyarısız eşleşmiş görünüyordu; artık web sayfası gösteren formda doğrulanmış site kullanılmıyor. Dört küçük bulgu [#182](https://github.com/aaudraa/KeyKey/issues/182)'de.

1.10.0 olarak yayımlandı (2026-11-23, [#183](https://github.com/aaudraa/KeyKey/pull/183)). İmza sertifikası aynı (`66ff7b5c…`); F-Droid'in kendi derlemesi APK'yla bayt bayt aynı çıktı. Android 17 emülatöründe bütün entegrasyon testleri geçti (40 test). Yeni izin yok.

**Cihazda (2026-11-22, Android 17 emülatörü):** Örnek giriş uygulamasının `autoVerify` alan adı sistemde "approved" yapıldı; bağsız `example.com` kaydı liste açılmadan doldu ve uygulama kayda bağlandı. F-Droid'deki Wikipedia'nın imzası `wikipedia.org` dosyasında listeli; sistemin doğrulaması geri alınıp ayar açıldı, `en.wikipedia.org` kaydı giriş ekranında liste açılmadan doldu ve `org.wikipedia` bağlandı.

## 1.0 sonrası

**2026-11-19:** Proje sahibi bu bölümdeki fikirlerin, kendi kararını bekleyenler dahil hepsini onayladı ve internete açılmaya karar verdi ([İnternet](#temel-kararlar)). Sıra benim kararım ve [Durum](#durum) tablosunda faz olarak duruyor. Gerekçesi:

1. **Kart ve güvenli not (Faz 14), sonra kart doldurma (Faz 15).** Proje sahibinin en çok ihtiyaç duyduğu şey bu. Kayıt modeli türlere açık kurulduğu için internet kararına bağlı değil.
2. **İnternete açılma ve sızıntı kontrolü (Faz 16).** Misyon değişikliği tek bir fazda yapılır: izin, CI denetimi, gizlilik bildirimi, koşullar, güvenlik tasarımı ve uygulama içi metinler. Have I Been Pwned denetimi küçük ve kendi içinde kapalı olduğu için ağ altyapısını ilk o sınar.
3. **Kullanım kolaylıkları (Faz 18):** arka plan kilidinde bekleme süresi, gizli olmayan alanlarda normal klavye, toplu seçim, Steam Guard kodları. Küçük işler, hepsi kasada.
4. **Senkron (Faz 19).** En büyük internet işi, ağ altyapısı Faz 16'da sınanmış olur. Önce WebDAV; Google Drive için proje sahibinin Google Cloud hesabında bir OAuth istemcisi gerekir, o adım ona kalır.
5. **KeePass içe aktarma (Faz 20), passkey (Faz 21).** Biri geçişi kolaylaştırır, diğeri F-Droid'in "benzersiz özellik yok" itirazına verilebilecek en güçlü cevap.
6. **Dağıtım (Faz 22), klavye (Faz 23), Windows (Faz 24).** Büyük ya da kullanıcıya dolaylı dokunan işler sona kaldı.

| Fikir | Faz | Not |
|---|---|---|
| Kart ve güvenli not kayıtları | 14 | Kayıt modeli türlere açık; veritabanında `type` sütunu zaten var. Tasarım: [kart ve not](docs/kart-ve-not.md). |
| Kart doldurma | 15 | Android'in doldurma sistemi kart alanlarını da tanıyor (`creditCardNumber` vb.). |
| Sızıntı kontrolü (Have I Been Pwned) | 16 | k-anonimlik ile parolayı göndermeden çalışır, internet gerektirir. |
| Otomatik senkron (WebDAV, Google Drive) | 19 | Uçtan uca şifreli. Önce WebDAV; Drive için OAuth istemcisi proje sahibinin hesabında açılır. |
| Arka plan kilidinde bekleme süresi | 18 | Kullanıcının seçtiği kısa süre (30 sn, 1 dk), varsayılan "hemen". |
| Gizli olmayan alanlarda normal klavye | 18 | Ad, site, klasör ve aramada büyük harf ve adres klavyesi. Bugün bütün kutular bilerek `visiblePassword` açıyor, çünkü klavyelerin çoğu öğrenme kapatma isteğini ancak böyle uyguluyor; normal klavyede kayıt adları ve siteler klavyenin sözlüğüne girebilir. Ayar olarak gelir ([ayrıntı](docs/kullanici-gozuyle.md#proje-sahibinin-kararına-bırakılanlar)). |
| Toplu seçim | 18 | Çoklu silme ve klasöre taşıma. |
| Steam Guard kodları | 18 | 2FA tarafı için. |
| Navbar'da yalnızca simgeler | Tamamlandı (1.8.1) | Proje sahibinin notu (2026-11-21): navbar yalnızca seçili sekmenin adını, o da sığarsa gösteriyor; beş sekmeyle telefonda yalnızca "2FA" sığdığı için tutarsız görünüyor. Görünen adlar kalkar, ekran okuyucu adları okumaya devam eder. Sonraki sürüme küçük bir düzeltme olarak girer ([#163](https://github.com/aaudraa/KeyKey/issues/163)). |
| KeePass (`.kdbx`) içe aktarma | 20 | KDBX çoğunlukla Argon2d kullanır, libsodium'da yok; ayrı ve incelenmiş bir uygulama gerekir. |
| Uygulama ve site eşleştirme | 25 | 2026-11-22'de eklendi. İnternetsizken uygulamanın sitesi doğrulanamıyordu; Digital Asset Links ile kendiliğinden eşleşme. |
| Passkey ve Credential Manager sağlayıcısı | 21 | Android 14 ve üstü. Passkey'ler çoğunlukla P-256 (ES256) ister, libsodium'da yok; Android'in kendi kripto sağlayıcısı kullanılır. |
| İşlemciye göre bölünmüş APK | 22 | Evrensel APK 80 MB. Bölünmüş APK'lar evrenselin yanına eklenir; Obtainium işlemciye uygun olanı seçebilir. |
| Kendi F-Droid deposu | 22 | F-Droid istemcisine eklenebilen kendi depomuz (`fdroid repo`, örneğin GitHub Pages'te). Ana depoya girmeden F-Droid kullanıcılarına güncelleme verir; imza bizim. |
| KeyKey klavyesi | 23 | Giriş kutularını doldurma sistemine bildirmeyen uygulamalarda da doldurmak için kendi klavyesi (KeePassDX'teki gibi). Klavyenin kendisi de güvenlik incelemesi ister. Çıkış noktası: [#94](https://github.com/aaudraa/KeyKey/issues/94), [doldurma sistemine katılmayan ekranlar](docs/guvenlik-tasarimi.md#doldurma-sistemine-katılmayan-ekranlar). |
| Windows | 24 | Windows derlemesi için araçlar hazır; otomatik doldurma yok, kasa ve 2FA var. iOS ve tarayıcı eklentisi planda değil (iOS için Mac gerekir). |
| IzzyOnDroid | — | Başvurulmuyor (2026-11-17): yapay zekâyla yazılmış kodu kabul etmiyor, APK başına 30 MB sınırı var. Ayrıntılar: [F-Droid tasarımı](docs/f-droid.md#izzyondroid-neden-yok). |
| F-Droid ana deposu | — | İlk başvuru 2026-11-18'de kabul edilmedi ([fdroiddata!57995](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/57995)): 3 aydan yeni ve "benzersiz özellik yok". 2027-02-04'ten sonra yeniden başvurulabilir; passkey ve senkron ikinci gerekçeye cevap olabilir. İnternet özellikleri gelince F-Droid kayda `NonFreeNet` gibi bir uyarı ekleyebilir. Tarif ve süreç [başvuru belgesinde](f-droid/basvuru.md). F-Droid kaynaktan derler, derleme bizimkiyle birebir aynıysa bizim imzamızla yayımlar ([yeniden üretilebilir derleme](docs/yayin.md#yeniden-üretilebilir-derleme)). |
| Play Store | — | Şimdilik yok (2026-11-09 kararı). 25 $ ücret ve kimlik, yeni hesaplarda 12 kişilik 14 günlük kapalı test; Google kendi imza anahtarını kullandığı için Play sürümü GitHub sürümünün üstüne kurulamaz. |
| Google'ın geliştirici doğrulaması | — | 30 Eylül 2026'da dört ülkede başladı, 2027'den sonra yayılacak; Türkiye henüz kapsamda değil. Kapsama girince kayıtsız geliştiricinin uygulaması Play dışında yalnızca "gelişmiş kurulum" adımlarıyla kurulabilecek. O zaman yeniden değerlendirilecek. |
| Dışarıdan inceleme çağrısı | — | [#90](https://github.com/aaudraa/KeyKey/issues/90): metin hazır, ama proje sahibi 2026-11-19'da şimdilik bırakmayı seçti. |

## Riskler

| Risk | Etkisi | Önlem |
|---|---|---|
| libsodium'un Windows'ta Android için derlenmesi kırılgan olabilir | Derleme bozulur | Bu bilgisayarda doğrulandı, gereken araçlar [belgelendi](#geliştirme-ortamı). CI Linux'ta derler, proje yolu kısa tutulur. |
| Otomatik doldurma tarayıcıya ve üreticiye göre farklı davranır | Bazı yerlerde doldurmaz | Dört sürümlük test düzeni, saf işlevlerle alan tespiti, Faz 8'de gerçek cihaz. |
| Android, kaydetme sırasında hedef uygulamayı KeyKey'e kendiliğinden göstermiyor | Ana ekranda simgesi olmayan uygulamada ilk kayıt uygulamaya bağlanmazdı | 1.11.0'dan beri `QUERY_ALL_PACKAGES` ile bütün uygulamalar görünür; proje sahibinin kararı (2026-11-24, [#71](https://github.com/aaudraa/KeyKey/issues/71)). Liste cihazdan çıkmaz; imza yine okunamazsa kayıt bağlanmadan kaydedilir ve ekran söyler. |
| Otomatik doldurma ekranında Flutter'ın yavaş açılması | Kullanım zorlaşır | Ayrı ve hafif giriş noktası, Faz 6 başında süre ölçümü. |
| Kasa göçü veya biçim hatası | Veri kaybı | Biçim sürümleri, örnek dosyalı uyumluluk testleri, Faz 8'e kadar gerçek veri yok. |
| Bağımlılık kaynaklı güvenlik sorunu | Tedarik zinciri saldırısı | Az paket, `pubspec.lock`, Dependabot, SHA'ya sabit Action'lar. |
| Emülatör gerçek cihazı tam temsil etmiyor | Keystore ve biyometri farkları gözden kaçar | Faz 8'de gerçek ARM telefon zorunlu. |
| Bağımsız güvenlik denetimi yok | Gözden kaçan tasarım hatası | Açık kaynak, ayrıntılı tasarım belgesi, Faz 8'de dış inceleme çağrısı, README'de açık uyarı. |

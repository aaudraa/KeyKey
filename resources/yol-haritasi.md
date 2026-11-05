# KeyKey Yol Haritası

KeyKey, Android için çevrimdışı ve açık kaynak bir parola yöneticisi ve 2FA doğrulama uygulaması. Bu belge neyi, hangi sırayla ve neden yaptığımızın tek kaynağıdır. Her faz bittiğinde güncellenir.

**Son güncelleme:** 2026-11-05 · **Şu anki faz:** Faz 3

> [!IMPORTANT]
> **Gerçek parolalarını Faz 8 bitene kadar KeyKey'e koyma.** Kasa biçimi o zamana kadar değişebilir ve güvenlik denetimi henüz yapılmadı.

**Bu belgede:** [Durum](#durum) · [Temel kararlar](#temel-kararlar) · [Teknoloji seçimleri](#teknoloji-seçimleri) · [Mimari](#mimari) · [Güvenlik tasarımı](#güvenlik-tasarımı) · [Çalışma düzeni](#çalışma-düzeni) · [Fazlar](#fazlar) · [1.0 sonrası](#10-sonrası) · [Riskler](#riskler)

## Durum

| Faz | Konu | Büyüklük | Önce bitmeli | Branch | Durum |
|---|---|---|---|---|---|
| 0 | Repo ve GitHub altyapısı | S | — | `faz/0-repo-altyapisi` | Tamamlandı |
| 1 | Flutter iskeleti ve CI | M | 0 | `faz/1-flutter-iskeleti` | Tamamlandı |
| 2 | Kripto çekirdeği | L | 1 | `faz/2-kripto-cekirdegi` | Tamamlandı |
| 3 | Kasa, kilit ve biyometri | L | 2 | `faz/3-kasa-ve-kilit` | Sırada |
| 4 | Parola kasası | L | 3 | `faz/4-parola-kasasi` | Bekliyor |
| 5 | 2FA doğrulayıcı | M | 3 | `faz/5-2fa-dogrulayici` | Bekliyor |
| 6 | Otomatik doldurma | XL | 4 | `faz/6-otomatik-doldurma` | Bekliyor |
| 7 | Yedekleme, içe ve dışa aktarma | L | 4, 5 | `faz/7-yedekleme` | Bekliyor |
| 8 | Güvenlik sertleştirme ve denetim | L | 6, 7 | `faz/8-guvenlik-denetimi` | Bekliyor |
| 9 | 1.0 yayını | M | 8 | `faz/9-yayin` | Bekliyor |

Büyüklük göreli iş miktarını gösterir, takvim sözü değildir. Faz 4 ve 5 aynı anda ilerleyebilir. İlerlemeyi [milestone'lardan](https://github.com/aaudraa/KeyKey/milestones) da izleyebilirsin.

## Temel kararlar

| Konu | Karar | Neden |
|---|---|---|
| Platform | Önce yalnızca Android | Test ortamı hazır ve otomatik doldurma en çok telefonda işe yarıyor. iOS için Mac gerekiyor; o ve Windows sürümü 1.0 sonrasına kaldı. |
| En düşük sürüm | Android 11 (API 30) | Elimizdeki en eski emülatör bu ve test edemediğimiz sürümü desteklemek istemiyoruz. Satır içi otomatik doldurma önerileri de bu sürümle geldi. |
| Veri | Yalnızca cihazda; sunucu ve hesap yok | Saldırı yüzeyi küçülür, sunucu maliyeti olmaz, başkasının verisini koruma yükü doğmaz. |
| İnternet | Yayın sürümünde `INTERNET` izni yok | İzin yoksa uygulama veriyi dışarı gönderemez. CI her PR'da bunu denetler. |
| Cihazlar arası geçiş | Kullanıcının kaydettiği şifreli yedek dosyası | Android dosya seçicisiyle Drive'a bile kaydedilebilir ve internet izni gerektirmez. Otomatik senkron 1.0 sonrasına kaldı. |
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
| QR okuma | `flutter_zxing` | 3.1.0 | MIT | Açık kaynak, tamamen cihazda çalışıyor. |
| Dart-Kotlin köprüsü | `pigeon` | 29.1.0 | BSD-3 | Elle yazılan kanallara göre tür güvenli. |
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
| `sqlite3_flutter_libs` | Kullanım ömrü bitti, `sqlite3` paketi yerel kütüphaneyi artık kendisi sağlıyor. Derlemede GitHub'dan hazır dosya indiriyor ve paketin içindeki SHA-256 ile doğruluyor. Aynı yayıncının Dart kodu zaten uygulamanın içinde çalıştığı için bu, güvenmemiz gereken kişiyi değiştirmiyor. Kaynaktan derlemeye Faz 9'da geçilecek. |

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

| Senaryo | KeyKey korur mu? | Nasıl |
|---|---|---|
| Telefon kilitli haldeyken çalındı veya kayboldu | Evet | Kasa diskte şifreli, anahtar ana paroladan türetiliyor ve diskte durmuyor. |
| Yedek dosyası başkasının eline geçti | Parola güçlüyse evet | Argon2id deneme yanılmayı çok yavaşlatır, ama zayıf bir parola yine de kırılabilir. |
| Başka bir uygulama kasayı okumaya çalışıyor | Evet | Android uygulama yalıtımı ve kasa şifrelemesi. |
| Sahte uygulama veya site parolayı istiyor | Büyük ölçüde | Uygulama imzası ve alan adı eşleştirmesi, doldurmadan önce kullanıcı onayı. |
| Ekran görüntüsü ve ekran kaydı | Evet | `FLAG_SECURE`. |
| Başka bir uygulama panoyu okuyor | Kısmen | Pano bir süre sonra temizlenir ve hassas olarak işaretlenir. Kopyalama anında aktif bir klavye veya kötü amaçlı uygulama yine görebilir. |
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

Emülatörlerde ekran kilidi yok. Parmak izi testleri için Faz 3'te kilit gerekecek. Kilit varken soğuk açılıştan sonra PIN girilene kadar uygulama başlatılamaz ve `adb` `Activity class does not exist` hatası verir; bu bir uygulama hatası değildir.

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
- [ ] Kasa oluşturma ekranları: ana parola, güç göstergesi, parolanın geri alınamayacağı uyarısı
- [ ] Kurtarma anahtarını gösterme ve geri yazdırarak doğrulama
- [ ] Ana parolayla açma; hatalı denemelerde artan bekleme
- [ ] Otomatik kilit: arka plana geçince ve süre dolunca; kilitte anahtarlar ve çözülmüş veri temizlenir
- [ ] Kotlin köprüsü: Keystore anahtarı, `BiometricPrompt`, `CryptoObject`
- [ ] Parmak iziyle açma; yeni parmak izi eklenince geçersiz olma
- [ ] Ana parola değiştirme ve kurtarma anahtarıyla erişim
- [ ] Metin kutularında otomatik düzeltme ve klavye öğrenmesini kapatma

**Bitti sayılması için:** Uygulama kapatılınca kasa kilitli açılıyor; yanlış parola içeri almıyor; parmak izi `adb emu finger touch` ile emülatörde çalışıyor; yeni parmak izi eklenince ana parola isteniyor; parola değişince tüm kayıtlar okunabilir kalıyor.

### Faz 4 — Parola kasası

**Amaç:** Parolaların saklandığı, arandığı ve üretildiği ana ekran.

- [ ] Kayıt modeli: ad, kullanıcı adı, parola, birden çok URL, not, özel alanlar
- [ ] Liste, arama, favoriler, klasörler ve sıralama (arama çözülmüş veri üzerinde bellekte yapılır)
- [ ] Ekleme, düzenleme, çöp kutusu ve parola geçmişi
- [ ] Parola üretici: rastgele parola ve parola cümlesi, libsodium'un güvenli rastgele üreticisiyle
- [ ] Kendi güç ölçerimiz: entropi, yaygın parola listesi ve desen kontrolü
- [ ] Güvenli pano: hassas işareti (Android 13+) ve 30 saniye sonra otomatik temizleme
- [ ] Parolayı göster/gizle ve kilit durumuyla uyumlu ekran davranışı

**Bitti sayılması için:** 1000 kayıtla liste ve arama akıcı; pano uygulama arka plandayken de temizleniyor; düzenleme sonrası eski parola geçmişte; hiçbir kayıt düz metin olarak diske yazılmıyor (veritabanı dosyası incelenerek doğrulanır).

### Faz 5 — 2FA doğrulayıcı

**Amaç:** Uygulamanın doğrulama kodu üreten yarısı.

- [ ] TOTP (RFC 6238) ve HOTP (RFC 4226); SHA-1, SHA-256, SHA-512; 6-8 hane; özel süre
- [ ] RFC test vektörleriyle doğrulama
- [ ] `otpauth://` ayrıştırıcı ve hatalı girdi testleri
- [ ] Kamera ve görselden QR okuma (`flutter_zxing`); kamera izni yalnızca tarama sırasında istenir
- [ ] Elle anahtar girişi
- [ ] Kod listesi: geri sayım, dokununca kopyalama, sıradaki kodu gösterme, arama
- [ ] Parola kaydıyla 2FA hesabını eşleştirme
- [ ] Google Authenticator (`otpauth-migration://`), Aegis ve 2FAS'tan içe aktarma
- [ ] İsteğe bağlı ek onay: kodları görmek için parmak izi
- [ ] Cihaz saati yanlışsa kodların tutmayacağına dair yardım metni

**Bitti sayılması için:** RFC vektörleri geçiyor; üretilen kod gerçek bir servisteki test hesabında kabul ediliyor; bozuk QR uygulamayı düşürmüyor.

### Faz 6 — Otomatik doldurma

**Amaç:** Parolayı kopyala-yapıştır yapmadan güvenle doldurmak. Projenin en zor ve güvenlik açısından en hassas parçası.

**Tasarım:** Kasa kilitliyken sistem yalnızca "KeyKey ile doldur" seçeneğini görür. Kullanıcı seçince KeyKey açılır, kilit çözülür ve eşleşen kayıt onaylanır. Kullanıcı onayı olmadan hiçbir veri servise veya hedef uygulamaya verilmez.

- [ ] Kotlin `AutofillService` ve manifest kaydı
- [ ] Alan tespiti: autofill ipuçları, giriş türü, HTML nitelikleri, Türkçe ve İngilizce alan adları (test edilebilir saf Kotlin işlevleri olarak)
- [ ] Kilit akışı: yanıt düzeyinde kimlik doğrulama ile KeyKey ekranını açmak
- [ ] Hızlı açılan, ayrı bir Flutter giriş noktası (`autofillMain`)
- [ ] Uygulama eşleştirme: paket adı ve imza sertifikası özeti birlikte
- [ ] Web eşleştirme: gömülü Public Suffix List ile alan adı; `webDomain` yalnızca güvenilen tarayıcılardan kabul edilir
- [ ] Şüpheli eşleşmede açık uyarı ve ek onay
- [ ] Satır içi öneriler (Android 11+)
- [ ] Yeni parola kaydetme akışı
- [ ] Doldurma sonrası 2FA kodunu panoya kopyalama seçeneği
- [ ] Kurulum yönlendirmesi: sistem ayarına doğrudan geçiş ve Chrome 135+ için [gereken "Autofill using another service" ayarına](https://android-developers.googleblog.com/2025/02/chrome-3p-autofill-services-update.html) doğrudan bağlantı
- [ ] Saldırı testleri: aynı paket adıyla farklı imzalı uygulama, sahte `webDomain`, WebView içeren uygulama (2023'te yayımlanan AutoSpill senaryosu)

**Bitti sayılması için:** Dört emülatörde Chrome'daki bir giriş formu ve örnek bir uygulama dolduruluyor; yeni parola kaydediliyor; kilitliyken hiçbir kayıt adı görünmüyor; saldırı testlerinin hepsinde parola sahte hedefe verilmiyor.

### Faz 7 — Yedekleme, içe ve dışa aktarma

**Amaç:** Telefon kaybolsa bile verinin kurtarılabilmesi ve başka uygulamalardan kolay geçiş.

- [ ] Sürümlü `.keykey` biçimi: Argon2id ve libsodium `secretstream`
- [ ] Android dosya seçicisiyle kaydetme: Drive gibi konumlar internet izni olmadan çalışır
- [ ] Geri yükleme: önce doğrulama, sonra birleştirme veya değiştirme seçeneği; hata olursa mevcut kasaya dokunulmaz
- [ ] Yedek hatırlatıcısı ve "son yedek" bilgisi
- [ ] İçe aktarma: Bitwarden (JSON, CSV), Chrome (CSV), KeePassXC (CSV), Aegis ve 2FAS
- [ ] Düz metin kaynak dosyasını silmeyi hatırlatma
- [ ] Çift onaylı ve uyarılı düz metin dışa aktarma
- [ ] Biçim uyumluluğu testleri

**Bitti sayılması için:** API 36'da alınan yedek API 30'da aynen açılıyor; bozuk dosya temiz bir hata veriyor ve veri kaybettirmiyor; yanlış parola dosyayı açmıyor.

### Faz 8 — Güvenlik sertleştirme ve denetim

**Amaç:** 1.0 öncesi son güvenlik ve kalite geçişi. Gerçek veriyle kullanım ancak bu fazdan sonra düşünülebilir.

- [ ] [OWASP MASVS](https://mas.owasp.org/MASVS/) maddelerini tek tek denetlemek ve sonucu `resources/docs/guvenlik-denetimi.md` dosyasına yazmak
- [ ] Tehdit modeli ve tüm kayıt (log) çıktılarının gözden geçirilmesi
- [ ] Dokunma korsanlığı koruması: `setHideOverlayWindows` ve gizlenmiş dokunuşları filtreleme
- [ ] R8 ayarları ve yayın derlemesi testi (`debuggable` kapalı, gizli sembol yok)
- [ ] Çevrimdışı parola raporu: zayıf ve tekrar eden parolalar
- [ ] Bağımlılık ve lisans denetimi; gereksiz paketlerin çıkarılması
- [ ] Gerçek ARM telefonda test: StrongBox, biyometri, performans
- [ ] Erişilebilirlik: TalkBack, büyük yazı boyutu, kontrast
- [ ] Deneme verisiyle uzun süreli günlük kullanım
- [ ] Dışarıdan inceleme çağrısı: tasarım belgesini güvenlik topluluklarıyla paylaşmak

**Bitti sayılması için:** Açık `güvenlik` issue'su yok; denetim belgesi tamamlandı; gerçek cihaz testleri geçti.

### Faz 9 — 1.0 yayını

**Amaç:** İlk kararlı sürümü imzalı ve doğrulanabilir şekilde yayımlamak.

- [ ] Uygulama simgesi ve açılış ekranı; kaynak dosyalar `resources/design/` altında
- [ ] Yayın anahtarı: repoya girmez, yedeği ayrı ve güvenli bir yerde tutulur, CI'da GitHub Secrets ile kullanılır
- [ ] Yayın otomasyonu: etiket atılınca imzalı APK ve AAB, SHA-256 özetleri, GitHub Release
- [ ] `CHANGELOG.md` ve sürüm numaralandırma
- [ ] Yeniden üretilebilir derleme denemesi; `sqlite3`'ü hazır dosya yerine kaynaktan derlemek (F-Droid de bunu gerektiriyor)
- [ ] Dağıtım kararı: GitHub Releases ile başlamak; F-Droid ve Play Store'u değerlendirmek
- [ ] Kullanım kılavuzu ve ekran görüntüleri (`resources/docs/kullanim.md`, `resources/design/`)
- [ ] `v0.x` sürümünden 1.0'a yükseltme testi: veri kaybı olmamalı

**Bitti sayılması için:** GitHub Release'teki APK dört emülatöre ve gerçek telefona kuruluyor; önceki sürümden yükseltmede veri korunuyor; README son durumu anlatıyor.

## 1.0 sonrası

Bu fikirlerin hiçbiri henüz planlanmış değil. Sırası kullanıma göre belirlenecek.

| Fikir | Not |
|---|---|
| Otomatik senkron (Google Drive, WebDAV) | Uçtan uca şifreli olur ama `INTERNET` izni gerektirir. "İnternete çıkmaz" sözünü değiştirdiği için ayrı bir karardır; ayrı bir sürüm olarak da sunulabilir. |
| Sızıntı kontrolü (Have I Been Pwned) | k-anonimlik ile parolayı göndermeden çalışır, yine de internet gerektirir. |
| Passkey ve Credential Manager sağlayıcısı | Android 14 ve üstü. |
| Kart ve güvenli not kayıtları | Kayıt modeli türlere açık tasarlanacak. |
| Steam Guard kodları, Wear OS | 2FA tarafı için. |
| Windows, iOS, tarayıcı eklentisi | Windows derlemesi için araçlar hazır, iOS için Mac gerekir. |

## Riskler

| Risk | Etkisi | Önlem |
|---|---|---|
| libsodium'un Windows'ta Android için derlenmesi kırılgan olabilir | Derleme bozulur | Bu bilgisayarda doğrulandı, gereken araçlar [belgelendi](#geliştirme-ortamı). CI Linux'ta derler, proje yolu kısa tutulur. |
| Otomatik doldurma tarayıcıya ve üreticiye göre farklı davranır | Bazı yerlerde doldurmaz | Dört sürümlük test düzeni, saf işlevlerle alan tespiti, Faz 8'de gerçek cihaz. |
| Otomatik doldurma ekranında Flutter'ın yavaş açılması | Kullanım zorlaşır | Ayrı ve hafif giriş noktası, Faz 6 başında süre ölçümü. |
| Kasa göçü veya biçim hatası | Veri kaybı | Biçim sürümleri, örnek dosyalı uyumluluk testleri, Faz 8'e kadar gerçek veri yok. |
| Bağımlılık kaynaklı güvenlik sorunu | Tedarik zinciri saldırısı | Az paket, `pubspec.lock`, Dependabot, SHA'ya sabit Action'lar. |
| Emülatör gerçek cihazı tam temsil etmiyor | Keystore ve biyometri farkları gözden kaçar | Faz 8'de gerçek ARM telefon zorunlu. |
| Bağımsız güvenlik denetimi yok | Gözden kaçan tasarım hatası | Açık kaynak, ayrıntılı tasarım belgesi, Faz 8'de dış inceleme çağrısı, README'de açık uyarı. |

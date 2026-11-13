# KeyKey Yol Haritası

KeyKey, Android için çevrimdışı ve açık kaynak bir parola yöneticisi ve 2FA doğrulama uygulaması. Bu belge neyi, hangi sırayla ve neden yaptığımızın tek kaynağıdır. Her faz bittiğinde güncellenir.

**Son güncelleme:** 2026-11-13 · **Şu anki faz:** Faz 9

> [!IMPORTANT]
> **Gerçek parolalarını 1.0'a kadar KeyKey'e koyma.** Projenin kendi güvenlik denetimi tamamlandı, ama yayımlanmış bir sürüm yok ve bağımsız bir denetim yapılmadı.

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
| 9 | 1.0 yayını | M | 8 | `faz/9-yayin` | Sürüyor |

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
| QR okuma | `flutter_zxing` | 3.1.0 | MIT; içindeki zxing-cpp Apache-2.0, zint BSD-3 | Açık kaynak, tamamen cihazda çalışıyor. Gömülü C++ kitaplıklarının lisansları uygulamanın lisans sayfasına elle eklenir. |
| Kamera | `camera` | 0.12.2 | BSD-3 | Flutter ekibinin paketi, `flutter_zxing` tarama için kullanıyor. Eklediği mikrofon ve depolama izinleri manifestte kaldırılır. |
| Görsel ve dosya seçme | `image_picker`, `file_selector` | 1.2.4 / 1.1.0 | BSD-3 | Flutter ekibinin paketleri. Android'in seçicilerini açar, depolama izni gerekmez. |
| Dart-Kotlin köprüsü | `pigeon` | 29.1.0 | BSD-3 | Elle yazılan kanallara göre tür güvenli. |
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
- [ ] Gizlilik bildirimi: seçilen mağazaların istediği açıklamalar (Play Store veri güvenliği formu, F-Droid); MASVS-PRIVACY denetiminden
- [ ] Tasarım incelemesi: bütün ekranların baştan gözden geçirilmesi, uygulama simgesi ve açılış ekranı; kaynak dosyalar `resources/design/` altında. Deneme (#89) boyunca biriken arayüz notları ve ertelenen fikirler (örneğin otomatik doldurma ekranının yarım yükseklikte açılması) buraya girer. İlk tur kodda bitti (#103, [ilk tasarım belgesi](docs/tasarim-yenileme.md)) ama kullanıcı görünümü beğenmedi; ikinci tur: [cam tasarım belgesi](docs/tasarim-cam.md). Telefonda kullanıcıyla deneme 1.0 etiketinden önce.
- [ ] Kullanım kılavuzu ve ekran görüntüleri (`resources/docs/kullanim.md`, `resources/design/`)
- [ ] Dışarıdan inceleme çağrısı (#90, Faz 8'den taşındı): gönderiyi kullanıcı paylaşır; gelen geri bildirimler 1.0 etiketinden önce issue'lara dönüştürülür

**Sıra:** Önce görünümü değiştirmeyen işler (yayın otomasyonu, derleme, sürüm, yükseltme testi). Tasarım incelemesi fazın sonunda yapılır, çünkü deneme bitmeden arayüzü değiştirmek denenen sürümü değiştirir. Kılavuz ve ekran görüntüleri tasarımdan sonra gelir; önce çekilirse tasarım değişince yeniden çekmek gerekir. Kullanıcının kararı (2026-11-09).

**Durum (2026-11-09):** Faz başladı, görevler #96-#104. Biten: sürüm kuralı ve [değişiklik günlüğü](CHANGELOG.md) (#98), [gizlilik bildirimi](docs/gizlilik.md) (#102, mağaza yanıtları dağıtım kararını bekliyor). Yayın iş akışı (#96, [yayın belgesi](docs/yayin.md)) deneme anahtarıyla GitHub'da sınandı: etiketten taslak ön sürüm, özetler ve imza doğru. Gerçek anahtar #97'yi bekliyor. SQLite artık repodaki kaynaktan derleniyor; aynı yolda yapılan iki derleme, yayın iş akışındakiler dahil, bayt bayt aynı; farklı yolda Flutter'ın gömdüğü mutlak yol yüzünden ayrılıyor (#99, [ayrıntılar](docs/yayin.md#yeniden-üretilebilir-derleme)). Yükseltme denemesi (#101) fazın son derlemesiyle yapılacak.

**Durum (2026-11-10):** Kalıcı yayın anahtarı oluşturuldu, sertifika özeti README'de ve [yayın belgesinde](docs/yayin.md) (#97). Dağıtım kararı verildi (#100, yukarıda). Faz 8 [#105](https://github.com/aaudraa/KeyKey/pull/105) ile kapandı; dış inceleme çağrısı (#90) bu faza taşındı. Yükseltme testi (#101) emülatörde iki yolla geçti: aynı imzayla üstüne kurulum ve farklı imzada yedekle taşıma ([ayrıntılar](docs/yayin.md#eski-sürümlerden-geçiş)). Bilgisayarda Windows Smart App Control, Flutter'ın 32 bit ARM aracını (`gen_snapshot`) engellemeye başladı; yerel derlemeler `--target-platform android-x64,android-arm64` ile yapılıyor, CI etkilenmiyor. Kalan sıra: tasarım incelemesi (#103), kullanım kılavuzu (#104), ardından 1.0.

**Durum (2026-11-11):** Tasarım yenilemesi (#103) kodda bitti: yeni tema ve renkler, aynı boy kartlar, yüzen alt menü, gruplu ayarlar, alttan açılan pencereler, yeni simge ve açılış ekranı, yarım pencerede otomatik doldurma ve tek kesin eşleşmenin sorulmadan doldurulması. Entegrasyon testleri Android 11, 14 ve 17 emülatörlerinde geçti; Android 16 emülatörü bozuk durumda (hiçbir KeyKey sürümü açılmıyor, tasarımdan önceki sürüm de), yeniden kurulacak. Kalan: telefonda kullanıcıyla deneme, kılavuz (#104), dış inceleme çağrısı (#90).

**Durum (2026-11-12):** Kullanıcı ilk turun görünümünü telefonda birkaç gün kullandıktan sonra beğenmedi ("sadece renkler değişmiş", cam fark edilmiyor, yeni parola ekranı korkutucu). Tasarım incelemesi yeniden açıldı. Örnek ekranlar üzerinden yeni yön kararlaştırıldı: renkli yumuşak zemin, cam kartlar, ucunda "+" olan cam menü, sade formlar, yumuşak hareketler ([cam tasarım belgesi](docs/tasarim-cam.md), [örnek ekranlar](design/cam-tasarim-ornekleri.html)). İlk turun otomatik doldurma davranışı, simge ve açılış ekranı kalıyor. Kullanıcı belgeyi aynı gün onayladı; [uygulama planı](docs/tasarim-cam-plani.md) yazıldı (15 görev). Sıra: kullanıcının plan onayı, uygulama, telefonda deneme; kılavuz (#104) bunun arkasında.

**Durum (2026-11-13):** Cam tasarım planının 15 görevi kodda bitti (#103). Bütün ekranlar renkli zemin ve cam kartlarla çiziliyor; tek "+", listeden kopyalama, sade formlar, ayarlarda yedek kartı, hareketli kilit ekranı, cam doldurma penceresi ve tahmini geri hareketi eklendi. Bir tarama testi düz `Scaffold`, düz alt pencere ve `AlertDialog` kalmadığını denetliyor. Birim testleri (1099) ve entegrasyon testleri Android 11, 14 ve 17 emülatörlerinde geçti. Tahmini geri hareketi Android 17 emülatöründe elle denendi: "+" kutusu açıkken geri kutuyu kapatıyor, değişmiş formda soru çıkıyor, kökte geri uygulamayı arka plana alıyor.

Ölçüm: 1000 kayıtlı listede beş savurma (debug, aynı Android 14 emülatörü) cam öncesi 15,2-15,5 sn, cam sonrası 17,0-18,0 sn sürdü. Karttaki gölgeyi kapatmak 16,6 sn, alt menünün bulanıklığını kapatmak 17,1 sn verdi; kalan fark kart başına daha çok bileşenden. Emülatörde profil modu olmadığı için karar telefondaki denemeye bırakıldı; takılma görülürse önce gölge ucuzlatılır. Yazılımsal grafikli emülatör (`-gpu swiftshader_indirect` ve `guest`) bulanık yüzeylerde qemu erişim ihlaliyle çöktü; testler `-gpu host` ile çalıştırıldı. KeyKey ekran görüntüsünü engellediği için emülatörde görsel karşılaştırma yapılamadı; görsel denetim telefondaki denemede. Kalan: telefonda kullanıcıyla deneme, kılavuz (#104), dış inceleme çağrısı (#90).

**Durum (2026-11-13, öğleden önce):** Kullanıcı cam tasarımı telefonda denedi: cam ve hareketler hoşuna gitti ama turuncu fazla, yazı ve düğmeler büyük geldi. Üçüncü tur konuşuldu: siyah-beyaz zemin ve simgeler, turuncu yalnızca dört yerde (K logosu, "+", ekranın ana düğmesi, 2FA halkası), cam korunuyor, ölçüler küçülüyor, ayarlarda (i) anahtarın solunda, kayıt simgeleri kutusuz; ayrıca dört katmanlı bir hareket planı ([siyah-beyaz tasarım belgesi](docs/tasarim-siyah-beyaz.md), [örnek ekranlar](design/siyah-beyaz-tasarim-ornekleri.html)). Açık sorular aynı gün yanıtlandı: küçülen başlık ve hata titreşimi eklenecek, simgesiz kayıtta harf ince daire içinde, güç çubuğu renksiz. Kullanıcı hareketlerin yalnızca ilk girişte kalmayıp kullanım boyunca sürmesini istedi; belgeye her dönüşte giriş hareketi ve bütün ekranlarda yavaş kayan zemin eklendi. Sıra: uygulama planı, uygulama (altı aşama, üç telefon denemesi); kılavuz (#104) bunun arkasında.

**Durum (2026-11-13, gece):** Siyah-beyaz tasarım ve hareket planının 15 görevi kodda bitti (#103, [belge](docs/tasarim-siyah-beyaz.md)). Turuncu yalnızca dört yerde; kartlar beyaz, alt menü buzlu cam; ölçüler küçüldü. Hareketler dört katmanda: yavaş kayan zemin, kaydırınca küçülen başlık ve kaydırdıkça gelen kartlar; basınca küçülme, kopyalayınca onay işareti, hatada titreme ve titreşim, kaydedince onay işareti ve parlayan kart; listelerde silinen kartın kayıp kapanması; parolanın sırayla açılması, 2FA rakamlarının kayması, halkanın son saniyelerde atması; kilit ekranında logo, nefes alan parmak izi, kilit açılışında solan K; yedek kartının atması, kurulumda kayan adımlar, nefes alan QR çerçevesi. "Animasyonları kaldır" açıkken hepsi anında biter. Birim testleri (1193) geçti. Entegrasyon testleri Android 14 emülatöründe hepsi geçti; Android 11'de ilk dört dosya geçti, bilgisayarın belleği yetmediği için koşu yarıda durduruldu; Android 17 koşulmadı. 11 ve 17 koşuları 1.0'dan önce tamamlanacak. Telefonda birinci deneme yapıldı; ikinci ve üçüncü deneme sürümleri taslak yayında, proje sahibini bekliyor. #103 onun onayıyla kapanır.

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
| IzzyOnDroid | 1.0'dan hemen sonra. GitHub'daki imzalı APK'yı F-Droid uygulamasında listeler; imza bizim anahtarımız kalır. |
| F-Droid ana deposu | IzzyOnDroid'den sonra. F-Droid kaynaktan derler, derleme bizimkiyle birebir aynıysa bizim imzamızla yayımlar. Bunun için CI'ın F-Droid'in derleme yolunda (`/home/vagrant/build/io.github.aaudraa.keykey`) derlemesi gerekiyor; yol farkı `libapp.so`'yu değiştiriyor ([yeniden üretilebilir derleme](docs/yayin.md#yeniden-üretilebilir-derleme)). |
| Play Store | Şimdilik yok (2026-11-09 kararı). 25 $ ücret ve kimlik, yeni hesaplarda 12 kişilik 14 günlük kapalı test; Google kendi imza anahtarını kullandığı için Play sürümü GitHub sürümünün üstüne kurulamaz. |
| Google'ın geliştirici doğrulaması | 30 Eylül 2026'da dört ülkede başladı, 2027'den sonra yayılacak; Türkiye henüz kapsamda değil. Kapsama girince kayıtsız geliştiricinin uygulaması Play dışında yalnızca "gelişmiş kurulum" adımlarıyla kurulabilecek. O zaman yeniden değerlendirilecek. |
| KeyKey klavyesi | Giriş kutularını doldurma sistemine bildirmeyen uygulamalarda da doldurmak için kendi klavyesi (KeePassDX'teki gibi). Erişilebilirlik servisi kullanmadan her uygulamada çalışır, ama büyük bir iş ve klavyenin kendisi de güvenlik incelemesi ister. Çıkış noktası: [#94](https://github.com/aaudraa/KeyKey/issues/94), [doldurma sistemine katılmayan ekranlar](docs/guvenlik-tasarimi.md#doldurma-sistemine-katılmayan-ekranlar). |
| Windows, iOS, tarayıcı eklentisi | Windows derlemesi için araçlar hazır, iOS için Mac gerekir. |

## Riskler

| Risk | Etkisi | Önlem |
|---|---|---|
| libsodium'un Windows'ta Android için derlenmesi kırılgan olabilir | Derleme bozulur | Bu bilgisayarda doğrulandı, gereken araçlar [belgelendi](#geliştirme-ortamı). CI Linux'ta derler, proje yolu kısa tutulur. |
| Otomatik doldurma tarayıcıya ve üreticiye göre farklı davranır | Bazı yerlerde doldurmaz | Dört sürümlük test düzeni, saf işlevlerle alan tespiti, Faz 8'de gerçek cihaz. |
| Android, kaydetme sırasında ana ekranda simgesi olmayan uygulamayı KeyKey'e göstermiyor | O uygulamada ilk kayıt uygulamaya bağlanmaz, ilk doldurmada uyarı çıkar | Kayıt yine kaydedilir ve ekran durumu söyler; uygulama ilk doldurmada bir dokunuşla bağlanır. Faz 8'in telefon denemesinde böyle bir uygulama çıkmadı; gerçek bir örnek çıkarsa 1.0 sonrasında çözülecek: [#71](https://github.com/aaudraa/KeyKey/issues/71). |
| Otomatik doldurma ekranında Flutter'ın yavaş açılması | Kullanım zorlaşır | Ayrı ve hafif giriş noktası, Faz 6 başında süre ölçümü. |
| Kasa göçü veya biçim hatası | Veri kaybı | Biçim sürümleri, örnek dosyalı uyumluluk testleri, Faz 8'e kadar gerçek veri yok. |
| Bağımlılık kaynaklı güvenlik sorunu | Tedarik zinciri saldırısı | Az paket, `pubspec.lock`, Dependabot, SHA'ya sabit Action'lar. |
| Emülatör gerçek cihazı tam temsil etmiyor | Keystore ve biyometri farkları gözden kaçar | Faz 8'de gerçek ARM telefon zorunlu. |
| Bağımsız güvenlik denetimi yok | Gözden kaçan tasarım hatası | Açık kaynak, ayrıntılı tasarım belgesi, Faz 8'de dış inceleme çağrısı, README'de açık uyarı. |

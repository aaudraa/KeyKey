# KeyKey Güvenlik Denetimi

KeyKey'in [OWASP MASVS](https://mas.owasp.org/MASVS/) v2 kontrolleriyle karşılaştırılması ve 1.0 öncesi denetimin sonuçları. Faz 8'de ([#20](https://github.com/aaudraa/KeyKey/issues/20)) yazıldı. Tasarımın kendisi [güvenlik tasarımı belgesinde](guvenlik-tasarimi.md), neyi kimden koruduğumuz [tehdit modelinde](guvenlik-tasarimi.md#tehdit-modeli).

Bu, projenin kendi denetimidir; bağımsız bir denetim değildir.

**Durum:** Tamamlandı (2026-11-09, [#91](https://github.com/aaudraa/KeyKey/issues/91)). Bütün kontroller değerlendirildi. Karşılanmayan kısımlar ya bilinçli olarak kapsam dışı ya da [güvenlik tasarımındaki bilinen sınırlarda](guvenlik-tasarimi.md#bilinen-sınırlar) kabul edilen risk olarak yazılı. Denetimde bulunan tek açık (deep link ile ekran açtırma) düzeltildi.

**Durumlar:** *Karşılanıyor*: kontrolün istediği yapılıyor ve kanıtı var. *Kısmen*: yapılıyor, ama kabul edilmiş bir sınırı var. *Kapsam dışı*: kontrol KeyKey'e uymuyor ya da bilinçli olarak uygulanmıyor; gerekçe yanında.

**Deneme ortamı.** Cihaz denemeleri sürüm derlemesiyle yapıldı (R8 açık, `debuggable` kapalı). Uygulama verisini ve belleğini okumak root gerektirdiği için depolama ve bellek taramaları Google API'li (Play Store'suz) Android 16 emülatöründe `adb root` ile yapıldı. Bu, telefonu çalınmış ve kilidi kırılmış ya da root'lanmış bir cihazdaki saldırganın göreceğini gösterir.

## Özet

| Kontrol | Konu | Durum | Gerekçe ve kanıt |
|---|---|---|---|
| MASVS-STORAGE-1 | Hassas verinin güvenli saklanması | Karşılanıyor | Kayıtlar tek tek şifreli; diskte düz metin yok. [Depolama](#depolama) |
| MASVS-STORAGE-2 | Hassas verinin sızmasının önlenmesi | Kısmen | Kayıt, yedekleme, pano, ekran görüntüsü ve klavye kapalı ya da sınırlı. Sınır: kilitten sonra bellekte kalan dizeler. [Kayıtlar](#kayıtlar-logcat), [Bellek](#bellek), [Sızıntı yolları](#sızıntı-yolları) |
| MASVS-CRYPTO-1 | Güncel ve güçlü kriptografi | Karşılanıyor | libsodium: Argon2id, XChaCha20-Poly1305, HKDF-SHA256. Bütün rastgelelik işletim sisteminin güvenli kaynağından. [Kriptografi](#kriptografi) |
| MASVS-CRYPTO-2 | Anahtar yönetimi | Karşılanıyor | Anahtar hiyerarşisi, korumalı bellek, parmak izi anahtarı Keystore'da (telefonda StrongBox). [Kriptografi](#kriptografi), [Gerçek telefon](#gerçek-telefon) |
| MASVS-AUTH-1 | Uzak kimlik doğrulama | Kapsam dışı | Sunucu ve hesap yok |
| MASVS-AUTH-2 | Yerel kimlik doğrulama | Karşılanıyor | Ana parola kasayı kriptografik olarak açar; parmak izi bir olay değil, Keystore anahtarıyla bağlı. [Kimlik doğrulama](#kimlik-doğrulama) |
| MASVS-AUTH-3 | Hassas işlemlerde ek doğrulama | Karşılanıyor | Şifresiz dışa aktarma, 2FA kodlarını gösterme (ayar açıksa), ek onayı kapatma ve parola değiştirme yeniden doğrulama ister. [Kimlik doğrulama](#kimlik-doğrulama) |
| MASVS-NETWORK-1 | Güvenli ağ trafiği | Kapsam dışı | `INTERNET` izni yok; uygulama ağa çıkamaz. CI'da denetleniyor. [Ağ](#ağ) |
| MASVS-NETWORK-2 | Kimlik sabitleme | Kapsam dışı | Bağlanılan sunucu yok. [Ağ](#ağ) |
| MASVS-PLATFORM-1 | Süreçler arası iletişim | Karşılanıyor | Dışa açık bileşenler korumalı. Denetimde deep link ile ekran açtırma bulundu, düzeltildi. [Süreçler arası iletişim](#süreçler-arası-iletişim) |
| MASVS-PLATFORM-2 | WebView | Kapsam dışı | WebView kullanılmıyor. [WebView](#webview) |
| MASVS-PLATFORM-3 | Arayüzün güvenliği | Kısmen | `FLAG_SECURE`, bindirme gizleme, gizli dokunuş filtresi, Android 14+ hassas pencere. Sınır: Android 11-13'te erişilebilirlik servisleri. [Arayüz koruması](#arayüz-koruması), [Erişilebilirlik](#erişilebilirlik) |
| MASVS-CODE-1 | Güncel platform sürümü | Karşılanıyor | `targetSdk` 36, `minSdk` 30 (Android 11). [Kod ve platform](#kod-ve-platform) |
| MASVS-CODE-2 | Güncelleme zorunluluğu | Kapsam dışı | Ağ olmadığı için sunucudan zorunlu güncelleme yapılamaz; bilinçli. [Kod ve platform](#kod-ve-platform) |
| MASVS-CODE-3 | Bilinen açığı olmayan bileşenler | Karşılanıyor | OSV taraması temiz (Guava açığı kapatıldı); Dependabot haftalık. [Bağımlılıklar](bagimliliklar.md#bilinen-açıklar) |
| MASVS-CODE-4 | Güvenilmeyen girdinin doğrulanması | Karşılanıyor | Bütün dosya ve bağlantı okuyucuları sınırlı, kendi hata türleriyle; rastgele bozulmuş girdiyle sınanıyor. [Güvenilmeyen girdi](#güvenilmeyen-girdi) |
| MASVS-RESILIENCE-1..4 | Platform bütünlüğü, kurcalama, analiz | Kapsam dışı | Bilinçli: açık kaynak; güvenlik kodun gizliliğine değil kriptoya dayanıyor. [Yayın derlemesi](#yayın-derlemesi), [Dayanıklılık](#dayanıklılık) |
| MASVS-PRIVACY-1..4 | Gizlilik | Karşılanıyor | Veri cihazdan çıkmaz; izleme, reklam, kimlik yok. Gizlilik bildirimi Faz 9'da. [Gizlilik](#gizlilik) |

## Kayıtlar (logcat)

**İlgili kontrol:** MASVS-STORAGE-2. **Görev:** [#82](https://github.com/aaudraa/KeyKey/issues/82). **Tarih:** 2026-11-08.

**Kod taraması.** KeyKey'in Dart kodunda `print`, `debugPrint` veya `log` çağrısı, Kotlin kodunda `Log` veya `println` çağrısı yok. Tek `Log.e` çağrıları Flutter'ın ürettiği eklenti kayıt dosyasında (`GeneratedPluginRegistrant`) ve yalnızca bir eklenti yüklenemezse eklentinin adını yazıyor.

**Cihaz denemesi.** [`logcat-scan.sh`](../scripts/logcat-scan.sh) cihazın bütün kaydını alır (yalnızca KeyKey'inkini değil; otomatik doldurma ve klavye gibi sistem parçaları da kayıt yazar) ve [`deneme-degerleri.txt`](../scripts/deneme-degerleri.txt) dosyasındaki deneme parolalarını, kurtarma anahtarını, 2FA gizli anahtarını, kullanıcı adlarını ve adresleri arar. Betiğin bir değeri gerçekten bulabildiği, kayıtta bilinen bir metinle ayrıca denendi.

| Deneme | Emülatör | Kayıt | Sonuç |
|---|---|---|---|
| Entegrasyon testlerinin hepsi (kasa, 2FA, yedek, içe aktarma, pano, biyometri, QR, performans) | Android 17 | 51 525 satır, baştan sona | Temiz |
| Sürüm derlemesiyle elle: yedekten kurulum (kurtarma anahtarıyla), parolamı unuttum, örnek uygulamada kaydetme ve doldurma (satır içi öneri, eşleşmeyen kayıt uyarısı, 2FA kodu kopyalama), 2FA kodu kopyalama, parolayı gösterip kopyalama, yedek alma, şifresiz dışa aktarma, Bitwarden içe aktarma | Android 17 | 34 300 satır, baştan sona | Temiz |

Android 17 emülatöründe otomatik doldurma altyapısı ayrıntılı kayıt tutuyor (`AutofillManager`, `AutofillSession`), ama yalnızca alan kimliklerini ve durumları yazıyor. Klavye (Gboard) alanın parola alanı olduğunu kaydediyor, içeriğini yazmıyor.

**Gerçek telefonda tekrar.** Üreticilerin değiştirdiği sistemler farklı kayıt tutabildiği için deneme Samsung telefonda da yapıldı: temiz ([Gerçek telefon](#gerçek-telefon)).

## Arayüz koruması

**İlgili kontrol:** MASVS-PLATFORM-3. **Görev:** [#83](https://github.com/aaudraa/KeyKey/issues/83). **Tarih:** 2026-11-08. **Tasarım:** [Arayüz koruması](guvenlik-tasarimi.md#arayüz-koruması).

[`tapjacking-device-test.sh`](../scripts/tapjacking-device-test.sh), sürüm derlemesi ve [saldırgan deneme uygulamasıyla](../test-apps/saldirgan): ekranı kaplayan, dokunuşları geçiren 0,5 opaklıkta bir bindirme penceresi ve kendini erişilebilirlik aracı olarak bildirmeyen bir servis.

**Korumadan önce (Android 17):** Bindirme KeyKey'in üstünde görünüyordu (`isOnScreen=true`, ekran görüntüsünde KeyKey'in siyah güvenli içeriğinin üstünde kırmızı örtü). Servis `FLAG_SECURE`'a rağmen kilit ekranından 14 düğüm ve 4 metin okudu ("KeyKey is locked", "Show", "Open" ...).

| Emülatör | Bindirme | Bindirmenin altındaki dokunuş | Erişilebilirlik servisi |
|---|---|---|---|
| Android 11 (API 30) | Gizlenemiyor (platformda yok) | Düşürüldü; KeyKey'in uyarısı (Toast) çıktı. Bindirme kapanınca dokunuş çalıştı | Okuyabildi: 6 olayda en fazla 9 metin. Bilinen sınır |
| Android 14 (API 34) | Gizlendi | Çalıştı | Hiçbir şey okuyamadı |
| Android 16 (API 36) | Gizlendi | Çalıştı | Hiçbir şey okuyamadı |
| Android 17 (API 37) | Gizlendi (`mIsForceHiddenNonSystemOverlayWindow=true`); ana ekrana dönünce yeniden göründü | Çalıştı | Hiçbir şey okuyamadı; aynı sırada başlatıcıdan, sistem arayüzünden ve klavyeden olay aldı |

`uiautomator` sistem tarafından araç sayıldığı için korumalı pencereyi okumaya devam ediyor; cihaz test betikleri bu yüzden etkilenmedi. Değişiklikten sonra Android 11'de bütün cihaz testleri (entegrasyon, parmak izi, pano, kamera), Android 16'da parmak izi ve kamera testleri geçti.

TalkBack'in korumalı pencerede çalışmaya devam ettiği [Erişilebilirlik](#erişilebilirlik) bölümünde ([#87](https://github.com/aaudraa/KeyKey/issues/87)). Android 11-13'te erişilebilirlik servislerine karşı koruma yok; tasarım belgesinde sınır olarak yazıyor.

## Yayın derlemesi

**İlgili kontroller:** MASVS-RESILIENCE, MASVS-CODE. **Görev:** [#84](https://github.com/aaudraa/KeyKey/issues/84). **Tarih:** 2026-11-08.

[`check-release-apk.sh`](../scripts/check-release-apk.sh) her PR'da CI'da çalışır ve şunları denetler:

| Denetim | Sonuç |
|---|---|
| İzinler yalnızca izin listesindekiler; `INTERNET` yok | Tamam |
| `debuggable` kapalı, `allowBackup` kapalı, `dataExtractionRules` tanımlı | Tamam |
| R8 açık: kendi paketimizden adı korunan sınıflar yalnızca manifestteki dört bileşen (`MainActivity`, `AutofillActivity`, `KeyKeyAutofillService`, `ClipboardClearReceiver`); geri kalanların adı kısaltılmış | Tamam |
| Yerel kütüphanelerde (`libapp`, `libflutter`, `libsodium`, `libsqlite3`, `libflutter_zxing` ve diğerleri, 3 mimari, 24 dosya) hata ayıklama bölümü (`.debug_*`) ve tam sembol tablosu (`.symtab`) yok. Kalan dinamik semboller kütüphanenin Dart'tan çağrılabilmesi için gerekli | Tamam |
| Anahtar deposu, `.env`, `.keykey` yedeği, test fixture'ı veya `DebugProbesKt.bin` yok | `DebugProbesKt.bin` (kotlinx-coroutines'in hata ayıklama dosyası) vardı, paketten çıkarıldı |
| [Deneme değerlerinden](../scripts/deneme-degerleri.txt) (test parolaları, kurtarma anahtarı, 2FA anahtarı, kullanıcı adları) hiçbiri APK'nın hiçbir dosyasında yok | Tamam |

Ayrıca açılmış APK üzerinde gitleaks (8.30.1, `dir` kipi) çalıştırıldı: bulgu yok. APK'nın varlıkları yalnızca Public Suffix List, parola sözcük listeleri ve lisans metinleri. Android Gradle eklentisinin eklediği `META-INF/version-control-info.textproto` derlemenin git commit'ini taşır; açık kaynak bir projede zararsızdır ve yeniden üretilebilir derlemede işe yarar.

**R8 ayarları.** Derleme dosyasında açıkça yazılı (`isMinifyEnabled`, `isShrinkResources`). Kendi `keep` kuralımız yok; gerekenler kütüphanelerin kendi kurallarından ve Flutter'dan geliyor.

**Kod karartma kararı.** Dart kodu `--obfuscate` ile karartılmıyor. KeyKey açık kaynak; kaynak kod zaten herkese açık olduğu için karartma bir şey gizlemez, yalnızca hata raporlarındaki yığın izlerini sembol dosyası olmadan okunmaz yapar ve yeniden üretilebilir derlemeyi (Faz 9) zorlaştırır. R8'in Kotlin adlarını kısaltması varsayılan olduğu ve APK'yı küçülttüğü için kalıyor; her sürümün `mapping.txt` dosyası Faz 9'da sürümle birlikte yayımlanabilir. MASVS-RESILIENCE'ın tersine mühendisliği zorlaştırma kontrolleri bu yüzden bilinçli olarak kapsam dışı; güvenlik kodun gizliliğine değil, kriptoya ve platform korumalarına dayanır.

**Sürüm derlemesinde denenen akışlar (R8 açık).** Android 17: yedekten kurulum, parolamı unuttum, otomatik doldurmada kaydetme ve doldurma, 2FA kodu kopyalama, parola kopyalama, yedek alma, şifresiz dışa aktarma, Bitwarden içe aktarma ([Kayıtlar](#kayıtlar-logcat)). Android 16: yedekten kurulum ve yedek alma. Android 11, 14, 16 ve 17: açılış, kilit ekranı ve dokunuşlar ([Arayüz koruması](#arayüz-koruması)). Entegrasyon testleri sürüm derlemesinde çalıştırılamıyor: Flutter test eklentisini sürüm derlemesine koymuyor. Parmak izi ve şifreli Aegis içe aktarma sürüm derlemesiyle gerçek telefonda denendi ([Gerçek telefon](#gerçek-telefon)).

## Gerçek telefon

**İlgili kontroller:** MASVS-AUTH-2, MASVS-CRYPTO-2, MASVS-STORAGE-2. **Görev:** [#88](https://github.com/aaudraa/KeyKey/issues/88). **Tarih:** 2026-11-08.

**Cihaz:** Samsung Galaxy S20 FE (SM-G780G, Snapdragon 865), Android 13. Parmak izi adımlarını kullanıcı telefonda elle yaptı; ölçümler ve kayıtlar USB üzerinden alındı.

**Anahtarın yeri: StrongBox.** Parmak izi anahtarı (`keykey_biometric_v1`) ilk denemede StrongBox'ta oluşturuldu; TEE'ye geri düşme olmadı. Anahtarın her kullanımında Snapdragon'un ayrı güvenlik işlemcisinin (SPU) kanalı (`sec_nvm_sp_keymaster`) çalıştı, TEE keymaster'ı (`keymaster_tee`) KeyKey için hiç çalışmadı. Bu sonuç bir API'den değil, Samsung'un sistem kayıtlarından çıkarıldı.

**Parmak izi (sürüm derlemesi).**

| Adım | Sonuç |
|---|---|
| Ayarlardan parmak iziyle açmayı açma | Çalıştı |
| Kilit ekranında parmak iziyle açma | Çalıştı |
| 2FA kodlarını göstermek için yeniden doğrulama | Parmak izi istendi, çalıştı |
| Telefona yeni parmak izi ekleme | Anahtar geçersiz oldu, parmak iziyle açma kapandı, ana parola istendi |

**Süreler.**

| Ölçüm | Derleme | Süre | Kaynak |
|---|---|---|---|
| Argon2id, taban (64 MiB, 3 geçiş) | Debug | 229–247 ms | `crypto_test.dart`, `KKOLCUM` |
| Argon2id, kalibrasyonun seçtiği 12 geçiş (yeni kasanın açılışı) | Debug | 864 ms | Aynı test |
| Soğuk açılış (ilk ekran çizilene kadar) | Sürüm | 720–860 ms | `ActivityTaskManager: Displayed` |
| Doldurma ekranının açılışı (klavye önerisine dokunduktan sonra) | Sürüm | 164–199 ms | Aynı kayıt, üç ölçüm |
| 1000 kayıt: yükleme ve çözme | Debug | 310 ms | `performance_test.dart`, `KKPERF` |
| 1000 kayıt: dört arama, toplam | Debug | 26 ms | Aynı test |
| 1000 kayıt: arama kutusuna yazıp listenin süzülmesi | Debug | 363 ms | Aynı test |

Kasa açma hedefi 1 saniye; 864 ms bu aralıkta, parametreler değişmedi. Argon2id libsodium'un yerel kodunda çalıştığı için debug ve sürüm derlemesinde aynı sürer. Liste ölçümleri debug derlemesinde alındı; sürüm derlemesinde daha hızlı olmaları beklenir.

**Diğer.**

- Bütün entegrasyon testleri telefonda geçti.
- Şifreli Aegis yedeği sürüm derlemesiyle içe aktarıldı.
- Bu oturumun 38 bin satırlık logcat kaydında hiçbir [deneme değeri](../scripts/deneme-degerleri.txt) yok. Samsung pencereler ve oyun modu hakkında çok kayıt tutuyor, ama içerik yazmıyor.

**Sınır.** Tek bir cihaz ölçüldü; 2020'nin üst seviye çipini taşıyor. Düşük donanımlı telefonlarda kasa açma hedef süreyi aşabilir ([Ölçülen süreler](guvenlik-tasarimi.md#ölçülen-süreler)). StrongBox'ı olmayan telefonlarda anahtar TEE'de tutulur; bu yol gerçek bir cihazda denenmedi (emülatörlerin anahtar deposu yazılımla çalışır).

## Günlük kullanım denemesi

**Görev:** [#89](https://github.com/aaudraa/KeyKey/issues/89). **Tarih:** 2026-11-09 - 2026-11-10.

**Kurulum.** Aynı telefona (Galaxy S20 FE, Android 13) `v0.8.0` sürüm derlemesi sıfırdan kuruldu ve KeyKey otomatik doldurma servisi seçildi. Deneme sırasında güvenlik ya da veri kaybı sorunu çıkarsa hemen düzeltilip yeni sürüm kurulacaktı, küçük sorunlar toplu düzeltilecekti. #95'in düzeltmesi kasa korunarak üstüne kuruldu (`adb install -r`).

**Süre.** İki hafta planlandı (2026-11-23'e kadar); kullanıcı denemeyi 2026-11-10'da bitirdi. Kısa sürdüğü için uzun süreli kullanımda ortaya çıkacak sorunları (birikmiş kayıtlar, sistem güncellemeleri, uzun aralıklı yedekler) kapsamıyor.

**Bulgular.**

| Bulgu | Tür | Sonuç |
|---|---|---|
| [#94](https://github.com/aaudraa/KeyKey/issues/94) HoYoLAB'ın giriş ekranında doldurma ve kaydetme önerisi çıkmıyor | Uyumluluk | Ekran giriş kutularını doldurma sistemine bildirmiyor; KeyKey'e hiç istek gelmiyor. [Bilinen sınır](guvenlik-tasarimi.md#doldurma-sistemine-katılmayan-ekranlar) olarak yazıldı. |
| [#95](https://github.com/aaudraa/KeyKey/issues/95) Firefox'un parola dışa aktarması içe aktarılamıyor | Eksik özellik | Firefox CSV biçimi eklendi, testleri yazıldı. Telefonda Firefox'tan alınmış gerçek bir dosyayla içe aktarma başarılı. |

Güvenlik ya da veri kaybı sorunu çıkmadı.

## Erişilebilirlik

**Görev:** [#87](https://github.com/aaudraa/KeyKey/issues/87). **Tarih:** 2026-11-08. MASVS'in bir kontrolü değil. Ama gizli değerlerin ekran okuyucuya nasıl verildiği ve hassas işaretli pencere (MASVS-PLATFORM-3) güvenlikle ilgili olduğu için burada.

**Otomatik denetim.** [`accessibility_test.dart`](../../test/accessibility/accessibility_test.dart) ana ekranları gerçek telefon boyutunda (1080x2400) açar. Ekranlar: kasa, kayıt ekleme, ayrıntı ve düzenleme, parola raporu, çöp kutuları, 2FA listesi ve ekleme, kodlar gizliyken 2FA, içe aktarmalar, ayarlar, parola değiştirme, parola üretici, kilit, kurtarma, kurulum ve yedekten kurulum. Otomatik doldurmanın kilit, liste ve kaydetme ekranları [`autofill_screens_test.dart`](../../test/features/autofill/autofill_screens_test.dart)'ta. Her biri açık ve koyu temada, normal ve %200 yazı boyutunda Flutter'ın üç kuralıyla denetlenir:
- `androidTapTargetGuideline`: dokunma hedefleri en az 48x48 dp.
- `labeledTapTargetGuideline`: her dokunulabilir öğenin adı var.
- `textContrastGuideline`: metin kontrastı WCAG AA.

%200'de taşma olursa Flutter hata verir ve test düşer.

| Bulgu | Düzeltme |
|---|---|
| Parola içe aktarma ekranı %200 yazıda taşıyordu: bilgi kartları kaymayan bir sütundaydı | Kartlar listeyle birlikte kayıyor |
| 2FA geri sayımı ilerleme çubuğu rolündeydi ve değeri her saniye değişiyordu; TalkBack bu satırdayken sürekli konuşabilirdi | İlerleme çubuğu rolü kaldırıldı; kalan süre etikette, satıra odaklanınca bir kez okunuyor |
| 2FA kodu sayı olarak okunuyordu ("dört yüz yetmiş yedi bin ...") | Rakamlar tek tek okunuyor; henüz üretilmemiş sayaçlı kod "Henüz kod yok" |
| Ayrıntı ekranında gizli parola "nokta nokta ..." diye okunuyordu | "Gizli" okunuyor; gösterilince değer okunuyor |
| Kayıt listesinde baş harf rozeti okunuyordu ("P, Posta, ...") | Rozet ekran okuyucudan gizlendi; favori yıldızı "Favori" diye okunuyor |

Ekran okuyucu davranışları ayrıca testle sabitlendi (`ekran okuyucu` grubu). Parola ve kurtarma anahtarı kutuları Android'in parola kutusu olarak bildirilir. TalkBack bunları, kullanıcının "parolaları seslendir" ayarına göre okur.

**Android 14+ hassas işaretli pencere.** KeyKey'in pencereleri `accessibilityDataSensitive` ile işaretli ([Arayüz koruması](#arayüz-koruması)). Android bu pencereleri yalnızca kendini erişilebilirlik aracı olarak bildiren servislere açar; TalkBack böyle bir servis. Android 17 emülatöründe TalkBack açıkken erişilebilirlik odağı KeyKey penceresinin içindeydi (`dumpsys accessibility`: "Accessibility Focused Window" KeyKey). Saldırgan deneme servisi ise aynı pencereden hiçbir şey okuyamadı.

**Elle deneme.** Emülatörde TalkBack adb ile sürülemedi. Kaydırma, klavye kısayolları ve dokunuşlar odağı ilerletmedi, konuşma çıktısı da okunamadı. Bu yüzden ana akışlar gerçek telefonda kullanıcıyla kulakla denendi: Samsung Galaxy S20 FE, Android 13, Samsung TalkBack, sürüm derlemesi 5484def.

| Adım | Duyulan | Sonuç |
|---|---|---|
| Kilit ekranı | Parola kutusu "Ana parola"; parolayla açıldı | Tamam |
| Kasa listesi | "Posta, ali@example.com"; baş harf yok | Tamam |
| Kayıt ayrıntısı | "Parola, Gizli"; "Göster"den sonra parolanın kendisi | Tamam |
| 2FA | "GitHub, ali", kod rakam rakam, kalan süre, "Kodu kopyala"; sürekli konuşmadı | Tamam |

Telefonun metin okuma dili İngilizce olduğu için TalkBack'in kendi sözleri ve rakamlar İngilizce okundu. KeyKey'in metinleri Türkçe okundu.

Telefon Android 13 olduğu için hassas işaretli pencere orada yok. Android 14+ için kanıt yukarıdaki emülatör gözlemi: TalkBack'in odağı KeyKey penceresindeydi, araç olmayan servis ise hiçbir şey okuyamadı. Bu pencerede TalkBack ayrıca kulakla denenmedi.

**Gözlem (Android 13).** Denemedeki telefonda TalkBack dışında iki erişilebilirlik servisi daha açıktı: bir uzaktan kontrol uygulaması ve bir otomatik tıklayıcı. Android 13'te KeyKey bu servislere kendini kapatamaz ([Arayüz koruması](#arayüz-koruması)). Kullanıcıya, gerçek veriyle kullanmadan önce gerekmeyenleri kapatması önerildi. Bu, tehdit modelindeki "erişilebilirlik izni almış uygulama" satırının gerçek bir örneği.

## Depolama

**İlgili kontroller:** MASVS-STORAGE-1, MASVS-STORAGE-2. **Görev:** [#91](https://github.com/aaudraa/KeyKey/issues/91). **Tarih:** 2026-11-09. **Tasarım:** [Depolama](guvenlik-tasarimi.md#depolama).

[`storage-scan.sh`](../scripts/storage-scan.sh) root'lu emülatörde uygulamanın üç klasörünü bilgisayara alır: iç klasör (`/data/data`), cihaz kilidi açılmadan erişilebilen klasör (`/data/user_de`) ve dış klasör (`/sdcard/Android/data`). Her dosyada [deneme değerlerini](../scripts/deneme-degerleri.txt) UTF-8 ve UTF-16 olarak, büyük küçük harf ayırmadan arar. Betiğin gerçekten bulabildiği, veritabanı şemasındaki bilinen sözcüklerle ayrıca denendi.

**Deneme.** Sürüm derlemesi, Android 16. Kasa kuruldu; parola kaydı, 2FA hesabı ve otomatik doldurmayla kaydedilmiş kayıtla kullanıldı. Tarama kasa açıkken ve kilitliyken yapıldı.

| Bulgu | Sonuç |
|---|---|
| Dosyalar | `keykey.db` ve Android'in derleme profili dosyaları. Dış klasör ve `user_de` boş; `shared_prefs` yok; önbellekte içe aktarma veya yedek kopyası kalmamış |
| `keykey.db` | SQLite; şema ve şifresiz alanlar ([tasarımdaki liste](guvenlik-tasarimi.md#depolama)) okunuyor, kayıtların içeriği şifreli |
| Deneme değerleri (ana parola, kayıt parolaları, kurtarma anahtarı, 2FA anahtarı, kullanıcı adları, adresler) | Hiçbiri yok |

**Android yedeklemesi.** `allowBackup` kapalı ve `dataExtractionRules` bulut yedeğini ve cihaz aktarımını dışarıda bırakıyor ([Yayın derlemesi](#yayın-derlemesi)). Emülatörde `bmgr backupnow` KeyKey için "Backup is not allowed" döndü.

## Bellek

**İlgili kontrol:** MASVS-STORAGE-2. **Görev:** [#91](https://github.com/aaudraa/KeyKey/issues/91). **Tarih:** 2026-11-09. **Tasarım:** [Bellek](guvenlik-tasarimi.md#bellek).

[`memory-scan.sh`](../scripts/memory-scan.sh) çalışan sürecin yazılabilir bellek bölgelerini `/proc/<pid>/mem` üzerinden döker (yaklaşık 450 MB) ve [`memory-search.mjs`](../scripts/memory-search.mjs) ile deneme değerlerini UTF-8 ve UTF-16 olarak arar. Değerin kendisi yazılmaz, deneme değerleri dosyasındaki satırı yazılır.

**Deneme.** Sürüm derlemesi, Android 16. Kasa ana parolayla açıldı, bir kaydın parolası gösterildi, 2FA ekranı açıldı. Sonra kasa kilitlendi ve uygulama açık bırakıldı. Sayılar UTF-8 ve UTF-16 kopyaların toplamıdır.

| An | Ana parola | Gösterilen kayıt parolası | Kullanıcı adları ve adresler | Kurtarma anahtarı, 2FA anahtarı, gösterilmeyen parolalar |
|---|---|---|---|---|
| Kasa açık | 14 kopya | 1 kopya | 3 değer, 7 kopya | Yok |
| Kilitten 15 saniye sonra | 4 kopya | 1 kopya | Var | Yok |
| Kilitten 2,5 dakika sonra | 4 kopya | 1 kopya | 2 değer, birer kopya | Yok |

**Sonuç.** Anahtarlar libsodium'un korumalı belleğinde durduğu için kurtarma anahtarı ve 2FA anahtarı düz metin olarak bulunmadı. Ama metin kutusundan gelen ana parola ve ekranda gösterilmiş değerler kilitten sonra da Dart'ın henüz toplanmamış dizelerinde kalıyor. Bu, tasarımda yazılı olan sınırın ölçülmüş halidir: Dart `String`'leri silinemez. Belleği okumak root ya da aynı süreçte kod çalıştırmayı gerektirir; böyle bir saldırgan ana parolayı yazılırken de görebilir. Kabul edilen risk olarak [bilinen sınırlara](guvenlik-tasarimi.md#bilinen-sınırlar) eklendi.

## Sızıntı yolları

**İlgili kontrol:** MASVS-STORAGE-2. **Görev:** [#91](https://github.com/aaudraa/KeyKey/issues/91).

| Yol | Durum | Kanıt |
|---|---|---|
| Sistem kaydı (logcat) | Kayıt yazılmıyor | [Kayıtlar](#kayıtlar-logcat) |
| Android yedeği ve cihaz aktarımı | Kapalı | [Depolama](#depolama) |
| Ekran görüntüsü, son uygulamalar önizlemesi, ekran kaydı | `FLAG_SECURE` | [Arayüz koruması](#arayüz-koruması) |
| Pano | Hassas işaretli, 30 saniyede temizleniyor | [Pano](guvenlik-tasarimi.md#pano), pano cihaz testi |
| Klavyenin öğrenmesi | Gizli alanlarda öneri ve kişiselleştirilmiş öğrenme kapalı | `secret_field.dart`; kötü niyetli klavyeye karşı koruma yok ([tehdit modeli](guvenlik-tasarimi.md#tehdit-modeli)) |
| Şifresiz dışa aktarma ve içe aktarma dosyaları | Kullanıcının isteğiyle; dışa aktarma ek doğrulama ister, içe aktarmadan sonra kaynak dosyayı silmesi hatırlatılır | [Düz metin dışa aktarma](guvenlik-tasarimi.md#düz-metin-dışa-aktarma) |
| Bildirimler | KeyKey bildirim göndermiyor; bildirim izni yok | `check-release-apk.sh` izin listesi |

## Kriptografi

**İlgili kontroller:** MASVS-CRYPTO-1, MASVS-CRYPTO-2. **Görev:** [#91](https://github.com/aaudraa/KeyKey/issues/91). **Tasarım:** [Algoritmalar](guvenlik-tasarimi.md#algoritmalar), [Anahtar hiyerarşisi](guvenlik-tasarimi.md#anahtar-hiyerarşisi).

- **Algoritmalar.** Kasanın bütün kriptografisi libsodium'da: Argon2id, XChaCha20-Poly1305, HKDF-SHA256 (yalnızca expand), BLAKE2b. Kendi şifreleme ilkelimiz yok. Kendi kodumuz olan scrypt ve PBKDF2 yalnızca başka uygulamaların dosyalarını içe aktarırken çalışır ve RFC vektörleriyle sınanır.
- **Rastgelelik.** Kod taraması: Dart'ta bütün tuz, nonce, anahtar, kayıt kimliği ve parola üretici rastgeleliği libsodium'un `randombytes` ve `secureRandom` işlevlerinden geliyor; `dart:math`'in `Random`'u hiç kullanılmıyor. Kotlin'de IV'leri Keystore ve Android'in şifreleme kitaplığı üretiyor.
- **Android tarafı.** Parmak izi anahtarı AES-256-GCM; Keystore'da üretilir ve dışarı çıkmaz: kullanıcı doğrulaması zorunlu, yalnızca güçlü biyometri, yeni parmak izinde geçersizleşme, varsa StrongBox (`BiometricVault.kt`). İçe aktarmadaki AES-GCM Android'in kendi kitaplığıyla (`ImportCrypto.kt`). SHA-256 yalnızca karşılaştırma için özet çıkarır (pano, uygulama imzası).
- **Anahtar ömrü.** Kasa anahtarı ve alt anahtarlar korumalı bellekte, kilitte silinir. Parola baytları türetmeden sonra sıfırlanır; metin kutusundan gelen `String` için [Bellek](#bellek) bölümündeki sınır geçerli.
- **Kanıt.** Bağımsız test vektörleri, olumsuz testler ve sabit biçim dosyaları ([Test yaklaşımı](guvenlik-tasarimi.md#test-yaklaşımı)); Argon2id parametreleri telefonda ölçüldü ([Gerçek telefon](#gerçek-telefon)).

## Kimlik doğrulama

**İlgili kontroller:** MASVS-AUTH-2, MASVS-AUTH-3. **Görev:** [#91](https://github.com/aaudraa/KeyKey/issues/91). **Tasarım:** [Kilit](guvenlik-tasarimi.md#kilit), [Biyometri](guvenlik-tasarimi.md#biyometri).

- **Ana parola** bir karşılaştırma değil: kasa anahtarı ancak paroladan türetilen anahtarla açılır. Hatalı denemelerde bekleme uygulanır; sayaç şifresiz olduğu için bu yalnızca uygulamanın kuralıdır (bilinen sınır 6).
- **Parmak izi** bir "başarılı" olayına güvenmez. Kasa anahtarının bir kopyası Keystore anahtarıyla sarılır; o anahtar yalnızca parmak iziyle kullanılabilir ve yeni parmak izi eklenince geçersizleşir. Telefonda denendi ([Gerçek telefon](#gerçek-telefon)).
- **Otomatik kilit.** Uygulama arka plana geçince kasa kilitlenir; otomatik doldurma ekranı kendi kilidini ister.
- **Ek doğrulama isteyen işlemler:** şifresiz dışa aktarma, 2FA kodlarını gösterme (ayar açıksa), bu ayarı kapatma (açmak istemez) ve parola değiştirme (mevcut parola). Kasa açıkken kayıt parolasını göstermek ve yedek almak ek doğrulama istemez: kasa zaten açıktır ve arka plana geçince kilitlenir; yedek ana parolayla şifrelidir.

## Ağ

**İlgili kontroller:** MASVS-NETWORK-1, MASVS-NETWORK-2. **Görev:** [#91](https://github.com/aaudraa/KeyKey/issues/91).

KeyKey'in `INTERNET` izni yok; Android bu izin olmadan soket açtırmaz. [`check-release-apk.sh`](../scripts/check-release-apk.sh) birleştirilmiş manifestteki izinleri izin listesiyle karşılaştırır ve her PR'da CI'da çalışır; bir bağımlılık bu izni eklerse derleme düşer. Bu yüzden ağ trafiğinin güvenliği ve sertifika sabitleme kontrolleri uygulanamaz. Otomatik senkron gibi internet isteyen özellikler [1.0 sonrası](../yol-haritasi.md#10-sonrası) ayrı bir karar olarak duruyor; o zaman bu iki kontrol yeniden değerlendirilmeli.

## Süreçler arası iletişim

**İlgili kontrol:** MASVS-PLATFORM-1. **Görev:** [#91](https://github.com/aaudraa/KeyKey/issues/91). **Tarih:** 2026-11-09.

**Bileşenler** (sürüm APK'sının birleştirilmiş manifesti):

| Bileşen | Dışa açık | Koruma |
|---|---|---|
| `MainActivity` | Evet (başlatıcı) | Yalnızca `MAIN`/`LAUNCHER` filtresi; aşağıdaki deep link düzeltmesi |
| `KeyKeyAutofillService` | Evet | `BIND_AUTOFILL_SERVICE` izni: yalnızca sistem bağlanabilir |
| `AutofillActivity` | Hayır | Yalnızca servisin `PendingIntent`'iyle açılır |
| `ClipboardClearReceiver` | Hayır | Yalnızca kendi alarmımız; yaptığı tek şey panoda hâlâ bizim kopyamız varsa silmek |
| `androidx.profileinstaller.ProfileInstallReceiver` | Evet | `DUMP` izni: yalnızca adb ve sistem |

İçerik sağlayıcı (`provider`) yok. Emülatörde kabuk kullanıcısıyla denendi: `AutofillActivity` "Permission Denial ... not exported" ile reddedildi.

**Bulgu: deep link ile ekran açtırma (düzeltildi).** Flutter, `MainActivity`'ye gelen niyetteki adresin yolunu uygulamanın yönlendiricisine verir (`flutter_deeplinking_enabled` varsayılan olarak açık). Niyet filtresi olmasa da açık bir niyet bunu tetikliyordu: `am start -n .../.MainActivity -a android.intent.action.VIEW -d https://ornek.example/ayarlar/parola` ile kasa açıkken KeyKey parola değiştirme ekranına gitti. Herhangi bir uygulama aynı niyeti gönderebilir. Etkisi sınırlıydı: ekranlar yine kilit yönlendirmesinin arkasında ve hassas işlemler ek doğrulama istiyor. Ama kullanıcıyı beklemediği bir ekrana götürmek arayüz aldatmacasına kapı açar.

- **Düzeltme:** `MainActivity` ve `AutofillActivity`'de `flutter_deeplinking_enabled` kapalı. `check-release-apk.sh` her etkinlikte bu ayarın kapalı olduğunu denetler.
- **Doğrulama (sürüm derlemesi, Android 16):** Kasa açıkken iki adresle (`https://...` ve `keykey:///...`) gönderilen niyet ekranı değiştirmedi. Uygulama kapalıyken aynı niyetle açılınca kilit ekranı geldi, kilit açılınca kasaya gidildi.

**Otomatik doldurma.** Doldurma isteğindeki uygulama ve alan adı başka bir uygulamadan gelen güvenilmeyen veridir; eşleştirme imza sertifikası ve güvenilen tarayıcı listesiyle yapılır ([Eşleştirme](guvenlik-tasarimi.md#eşleştirme)). Saldırı denemeleri Faz 6'da dört emülatörde yapıldı.

## WebView

**İlgili kontrol:** MASVS-PLATFORM-2. **Görev:** [#91](https://github.com/aaudraa/KeyKey/issues/91).

KeyKey WebView kullanmıyor. Sürüm APK'sının dex dosyalarında `android.webkit` paketinden yalnızca `MimeTypeMap` (dosya türü tablosu) geçiyor; `WebView` sınıfına başvuru yok. Lisanslar Flutter'ın kendi ekranlarında gösteriliyor.

## Kod ve platform

**İlgili kontroller:** MASVS-CODE-1, MASVS-CODE-2, MASVS-CODE-3. **Görev:** [#91](https://github.com/aaudraa/KeyKey/issues/91).

- **Platform sürümü.** `targetSdk` 36 (Flutter'ın varsayılanı, Android 16), `minSdk` 30 (Android 11). Android 11 öncesi bilinçli olarak desteklenmiyor. Cihaz testleri Android 11, 14, 16 ve 17'de çalışıyor.
- **Güncelleme zorunluluğu.** KeyKey ağa çıkmadığı için sunucudan zorunlu güncelleme yapılamaz; bu, "internete çıkmaz" kararının sonucudur. Güncellemeler GitHub Releases (ileride belki F-Droid ya da Play Store) üzerinden dağıtılacak; güvenlik düzeltmeleri sürüm notlarında duyurulacak (Faz 9). Açık bildirme yolu [`SECURITY.md`](../../.github/SECURITY.md).
- **Bileşenler.** [Bağımlılık belgesi](bagimliliklar.md): 104 Dart paketi ve Gradle kütüphaneleri OSV'de tarandı; bulunan tek açık (Guava) kapatıldı. Dependabot pub, Gradle ve GitHub Actions bağımlılıklarını haftalık denetliyor.
- **Sürüm numarası.** Şu an `0.1.0+1`; sürüm numaralandırma Faz 9'da.

## Güvenilmeyen girdi

**İlgili kontrol:** MASVS-CODE-4. **Görev:** [#91](https://github.com/aaudraa/KeyKey/issues/91).

| Girdi | Kaynak | Koruma |
|---|---|---|
| `otpauth://` bağlantısı, QR | Kamera, kullanıcı | Sıkı ayrıştırıcı; desteklenmeyen değerler reddedilir ([`otpauth://` bağlantıları](guvenlik-tasarimi.md#otpauth-bağlantıları)) |
| Google Authenticator dışa aktarması | QR | Kendi protobuf okuyucumuz; rastgele bozulmuş girdiyle sınanıyor |
| Aegis, 2FAS dosyaları | Belge seçici | En fazla 10 MB; scrypt bellek ve iş sınırları; bozuk hesap atlanır ([İçe aktarma](guvenlik-tasarimi.md#içe-aktarma)) |
| Bitwarden, Chrome, Firefox, KeePassXC dosyaları | Belge seçici | RFC 4180 CSV okuyucu; bilinmeyen alanlar yok sayılır, bozuk satır atlanır ([Parola içe aktarma](guvenlik-tasarimi.md#parola-içe-aktarma)) |
| `.keykey` yedeği | Belge seçici | Yapı denetlenir; her kayıt çözülüp doğrulanmadan hiçbir şey yazılmaz ([Geri yükleme](guvenlik-tasarimi.md#geri-yükleme)) |
| Kasa dosyası | Disk | Her kayıt kimliği ve türüyle bağlı (AD); değiştirilmiş kayıt açılmaz |
| Doldurma isteği | Başka uygulama, tarayıcı | İmza ve güvenilen tarayıcı denetimi, şüpheli durumda uyarı ([Şüpheli durumlar](guvenlik-tasarimi.md#şüpheli-durumlar)) |
| Niyetler | Başka uygulama | [Deep link düzeltmesi](#süreçler-arası-iletişim) |

Okuyucular yalnızca kendi hata türlerini fırlatır; bozuk dosyanın uygulamayı düşürmediği testlerle sabit. Veritabanı sorguları drift ile parametreli; metinden SQL ya da kod üreten bir yol yok.

## Dayanıklılık

**İlgili kontroller:** MASVS-RESILIENCE-1..4. **Görev:** [#91](https://github.com/aaudraa/KeyKey/issues/91).

Bilinçli olarak kapsam dışı: root ve emülatör tespiti, kurcalama denetimi, hata ayıklayıcı tespiti ve karartma yok. Gerekçe:

- KeyKey açık kaynak; tersine mühendisliği zorlaştırmak, gizlenecek bir şey olmadığı için koruma sağlamaz ([Yayın derlemesi](#yayın-derlemesi)).
- Root tespiti root'lu cihazdaki saldırganı durdurmaz; atlatılabilir ve yalnızca kendi cihazını root'layan kullanıcıyı cezalandırır. Root'lu cihazda kilitli kasa yine şifrelidir; açık kasanın belleği ise korunamaz ([Bellek](#bellek)).
- Verinin bütünlüğü kasanın kriptografisinden gelir: değiştirilmiş kayıt ve üst bilgi açılmaz. APK'nın bütünlüğü Android'in imza doğrulamasından, Faz 9'da ayrıca SHA-256 özetlerinden ve yeniden üretilebilir derlemeden gelecek.

`debuggable` kapalı ve hata ayıklama sembolü yok; bunlar CI'da denetleniyor.

## Gizlilik

**İlgili kontroller:** MASVS-PRIVACY-1..4. **Görev:** [#91](https://github.com/aaudraa/KeyKey/issues/91).

- **En az veri.** KeyKey yalnızca kullanıcının girdiği kayıtları tutar; hesap, kimlik, reklam kimliği, analitik ve hata raporu gönderimi yok. Ağ izni olmadığı için hiçbir veri cihazdan çıkamaz ([Ağ](#ağ)).
- **İzinler.** Kamera (yalnızca QR taramada istenir), biyometri ve bindirme gizleme. Bütün paketleri görme izni (`QUERY_ALL_PACKAGES`) istenmez; yalnızca ana ekranda simgesi olan uygulamalar görünür. İzin listesi CI'da denetleniyor.
- **Kullanıcının denetimi.** Kullanıcı bütün verisini şifreli yedek ya da şifresiz dosya olarak dışa aktarabilir; kayıtları kalıcı olarak silebilir; uygulama kaldırılınca bütün veri silinir (bulut yedeği kapalı).
- **Şeffaflık.** README "internete çıkmaz" diyor; bu, manifestten doğrulanabilir. Mağaza için gizlilik bildirimi (Play Store veri güvenliği formu, F-Droid açıklaması) Faz 9'daki dağıtım kararıyla birlikte yazılacak.

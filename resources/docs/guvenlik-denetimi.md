# KeyKey Güvenlik Denetimi

KeyKey'in [OWASP MASVS](https://mas.owasp.org/MASVS/) v2 kontrolleriyle karşılaştırılması ve 1.0 öncesi denetimin sonuçları. Faz 8'de ([#20](https://github.com/aaudraa/KeyKey/issues/20)) yazılıyor. Tasarımın kendisi [güvenlik tasarımı belgesinde](guvenlik-tasarimi.md), neyi kimden koruduğumuz [tehdit modelinde](guvenlik-tasarimi.md#tehdit-modeli).

Bu, projenin kendi denetimidir; bağımsız bir denetim değildir.

**Durum:** Sürüyor. Değerlendirilmeyen kontroller "Bekliyor" olarak duruyor.

## Özet

| Kontrol | Konu | Durum | Ayrıntı |
|---|---|---|---|
| MASVS-STORAGE-1 | Hassas verinin güvenli saklanması | Bekliyor | [#91](https://github.com/aaudraa/KeyKey/issues/91) |
| MASVS-STORAGE-2 | Hassas verinin sızmasının önlenmesi | Kısmen değerlendirildi | [Kayıtlar](#kayıtlar-logcat); geri kalanı #91 |
| MASVS-CRYPTO-1 | Güncel ve güçlü kriptografi | Bekliyor | #91 |
| MASVS-CRYPTO-2 | Anahtar yönetimi | Bekliyor | #91 |
| MASVS-AUTH-1 | Uzak kimlik doğrulama | Kapsam dışı | Sunucu ve hesap yok |
| MASVS-AUTH-2 | Yerel kimlik doğrulama | Bekliyor | #91, gerçek telefon [#88](https://github.com/aaudraa/KeyKey/issues/88) |
| MASVS-AUTH-3 | Hassas işlemlerde ek doğrulama | Bekliyor | #91 |
| MASVS-NETWORK-1 | Güvenli ağ trafiği | Bekliyor | #91; `INTERNET` izni yok |
| MASVS-NETWORK-2 | Kimlik sabitleme | Bekliyor | #91 |
| MASVS-PLATFORM-1 | Süreçler arası iletişim | Bekliyor | #91 |
| MASVS-PLATFORM-2 | WebView | Bekliyor | #91 |
| MASVS-PLATFORM-3 | Arayüzün güvenliği | Kısmen değerlendirildi | [Arayüz koruması](#arayüz-koruması); geri kalanı #91 |
| MASVS-CODE-1 | Güncel platform sürümü | Bekliyor | #91 |
| MASVS-CODE-2 | Güncelleme zorunluluğu | Bekliyor | #91 |
| MASVS-CODE-3 | Bilinen açığı olmayan bileşenler | Bekliyor | Bağımlılık denetimi [#86](https://github.com/aaudraa/KeyKey/issues/86) |
| MASVS-CODE-4 | Güvenilmeyen girdinin doğrulanması | Bekliyor | #91 |
| MASVS-RESILIENCE-1..4 | Platform bütünlüğü, kurcalama, analiz | Kısmen değerlendirildi | [Yayın derlemesi](#yayın-derlemesi): karartma bilinçli olarak yok; geri kalanı #91 |
| MASVS-PRIVACY-1..4 | Gizlilik | Bekliyor | #91 |

## Kayıtlar (logcat)

**İlgili kontrol:** MASVS-STORAGE-2. **Görev:** [#82](https://github.com/aaudraa/KeyKey/issues/82). **Tarih:** 2026-11-08.

**Kod taraması.** KeyKey'in Dart kodunda `print`, `debugPrint` veya `log` çağrısı, Kotlin kodunda `Log` veya `println` çağrısı yok. Tek `Log.e` çağrıları Flutter'ın ürettiği eklenti kayıt dosyasında (`GeneratedPluginRegistrant`) ve yalnızca bir eklenti yüklenemezse eklentinin adını yazıyor.

**Cihaz denemesi.** [`logcat-scan.sh`](../scripts/logcat-scan.sh) cihazın bütün kaydını alır (yalnızca KeyKey'inkini değil; otomatik doldurma ve klavye gibi sistem parçaları da kayıt yazar) ve [`deneme-degerleri.txt`](../scripts/deneme-degerleri.txt) dosyasındaki deneme parolalarını, kurtarma anahtarını, 2FA gizli anahtarını, kullanıcı adlarını ve adresleri arar. Betiğin bir değeri gerçekten bulabildiği, kayıtta bilinen bir metinle ayrıca denendi.

| Deneme | Emülatör | Kayıt | Sonuç |
|---|---|---|---|
| Entegrasyon testlerinin hepsi (kasa, 2FA, yedek, içe aktarma, pano, biyometri, QR, performans) | Android 17 | 51 525 satır, baştan sona | Temiz |
| Sürüm derlemesiyle elle: yedekten kurulum (kurtarma anahtarıyla), parolamı unuttum, örnek uygulamada kaydetme ve doldurma (satır içi öneri, eşleşmeyen kayıt uyarısı, 2FA kodu kopyalama), 2FA kodu kopyalama, parolayı gösterip kopyalama, yedek alma, şifresiz dışa aktarma, Bitwarden içe aktarma | Android 17 | 34 300 satır, baştan sona | Temiz |

Android 17 emülatöründe otomatik doldurma altyapısı ayrıntılı kayıt tutuyor (`AutofillManager`, `AutofillSession`), ama yalnızca alan kimliklerini ve durumları yazıyor. Klavye (Gboard) alanın parola alanı olduğunu kaydediyor, içeriğini yazmıyor.

**Sınır.** Deneme emülatörde yapıldı. Üreticilerin değiştirdiği sistemler (ör. Samsung) farklı kayıt tutabilir; gerçek telefonda tekrarı [#88](https://github.com/aaudraa/KeyKey/issues/88) kapsamında.

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

**Açık kalan:** TalkBack'in korumalı pencereyi okuyabildiği emülatörde elle denenecek ([#87](https://github.com/aaudraa/KeyKey/issues/87)). Android 11-13'te erişilebilirlik servislerine karşı koruma yok; tasarım belgesinde sınır olarak yazıyor.

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

**Sürüm derlemesinde denenen akışlar (R8 açık).** Android 17: yedekten kurulum, parolamı unuttum, otomatik doldurmada kaydetme ve doldurma, 2FA kodu kopyalama, parola kopyalama, yedek alma, şifresiz dışa aktarma, Bitwarden içe aktarma ([Kayıtlar](#kayıtlar-logcat)). Android 16: yedekten kurulum ve yedek alma. Android 11, 14, 16 ve 17: açılış, kilit ekranı ve dokunuşlar ([Arayüz koruması](#arayüz-koruması)). Entegrasyon testleri sürüm derlemesinde çalıştırılamıyor: Flutter test eklentisini sürüm derlemesine koymuyor. Parmak izi ve şifreli Aegis içe aktarma sürüm derlemesiyle gerçek telefonda denenecek ([#88](https://github.com/aaudraa/KeyKey/issues/88)).

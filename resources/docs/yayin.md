# Yayın

KeyKey sürümleri GitHub Actions'ta, `v` ile başlayan bir etiket gönderilince derlenir ve imzalanır ([`.github/workflows/yayin.yml`](../../.github/workflows/yayin.yml)). Derleme F-Droid'in derleme imajında ve derleme yolunda yapılır; aynı commit'i F-Droid'in kendi aracı da derler ve iki APK karşılaştırılır ([F-Droid tasarımı](f-droid.md)). İş akışı taslak bir GitHub Release oluşturur; taslağı yayımlamak elle yapılır.

## Yayın anahtarı

- Anahtar repoya girmez. GitHub'daki `yayin` ortamının gizli değerlerinde durur:

  | Gizli değer | İçerik |
  |---|---|
  | `KEYKEY_KEYSTORE_BASE64` | Anahtar deposu (`.jks`), base64 |
  | `KEYKEY_KEYSTORE_PASSWORD` | Deponun parolası |
  | `KEYKEY_KEY_ALIAS` | Anahtarın adı |
  | `KEYKEY_KEY_PASSWORD` | Anahtarın parolası |

- `yayin` ortamı yalnızca `v*` etiketlerine açıktır. Bir dal ya da PR'daki iş akışı anahtara erişemez.
- Ortamın onaylayıcısı proje sahibidir (`aaudraa`). Etiket gönderilince iş akışı GitHub'da onay bekler; GitHub hesabı ele geçirilip sahte bir etiket atılsa bile onaysız imzalı sürüm çıkmaz.
- Derleme anahtara hiç erişmez: APK ve AAB imzasız derlenir, anahtar yalnızca ayrı bir işte [`imzala.sh`](../scripts/imzala.sh) ile, `apksigner` (APK) ve `jarsigner` (AAB) imza atarken kullanılır. `apksigner` zip içeriğine dokunmaz, yalnızca imza bloğunu ekler; F-Droid bu yüzden imzayı kendi imzasız derlemesine kopyalayıp doğrulayabilir. İş akışı, sertifikası F-Droid tarifindeki `AllowedAPKSigningKeys` değerinden farklı bir APK'yı kabul etmez (yanlış anahtar ya da debug anahtarı).
- Yerel derlemede Gradle anahtarı `KEYKEY_KEYSTORE` ve yanındaki ortam değişkenlerinden okur ([`android/app/build.gradle.kts`](../../android/app/build.gradle.kts)); değişkenler yoksa yayın derlemesi debug anahtarıyla imzalanır (telefon denemeleri için).
- İş akışı anahtar dosyasını imzaladıktan hemen sonra siler. Önbellek kullanmaz, böylece yayın derlemesine başka işlerin yazdığı bir önbellek karışmaz.

### Kalıcı anahtar

| | |
|---|---|
| Sertifika SHA-256 | `66ff7b5c0c009a8530d0a55dd1d80a3af35de48bd0667c456a0cf86a6d1129a0` |
| Anahtar | RSA 4096, `CN=KeyKey`, 30 yıl geçerli (2026-11-09) |
| Takma ad | `keykey` |

Anahtar 2026-11-09'da [`yayin-anahtari-olustur.sh`](../scripts/yayin-anahtari-olustur.sh) ile proje sahibinin bilgisayarında oluşturuldu. Betik anahtarın parolasını rastgele üretir ve ekrana yazmaz; anahtarı ve parolasını AES-256 şifreli bir 7z arşivine koyar, arşivi doğrulayıp kopyalar, GitHub'a yükler ve şifresiz dosyayı siler. Parolalar bu çalışmada kullanılan yapay zekâ asistanından da geçmedi.

Yedekler (3-2-1 kuralı: üç kopya, iki farklı ortam, biri evden uzakta):

- Şifreli arşiv bir USB bellekte, bilgisayarın ikinci diskinde, Google Drive'da ve proje sahibinin telefonunda.
- Arşivin parolası kâğıtta, arşivlerden ayrı yerde. Arşiv parolası olmadan yedekler açılamaz, anahtar ancak GitHub'daki kopyayla kullanılabilir ama oradan geri okunamaz.

Anahtar sızarsa ya da kaybolursa: [Anahtar Döndürme](https://source.android.com/docs/security/features/apksigning/v3#key-rotation) (APK İmza Şeması v3) yalnızca eski anahtar elde varken yapılabilir. Kaybolursa kullanıcılar şifreli yedek alıp uygulamayı silmeli ve yeni imzalı sürümü kurmalıdır; bu README'de ve sürüm notlarında duyurulur.

**İlk yayında parola hatası (2026-11-16).** `v1.0.0`'ın ilk derlemesi imzalamada "keystore password was incorrect" ile durdu. Sebep: betik parolayı Git Bash'teki openssl ile üretmişti; o openssl satırı CR LF ile bitirir, betik yalnızca LF'yi sildi. Anahtar deposu sonunda görünmez bir CR olan parolayla kilitlendi. Bilgi dosyasına parola CR'siyle yazıldı, gh ise GitHub'a yüklerken sondaki CR'yi kırptı. Betiğin kendi denetimi aynı CR'li parolayı kullandığı için hatayı görmedi.

Onarım [`yayin-anahtari-onar.sh`](../scripts/yayin-anahtari-onar.sh) ile proje sahibinin bilgisayarında yapıldı. Betik arşivi açtı, depoyu CR'li parolanın açtığını buldu ve aynı anahtarı (sertifika aynı, `66ff7b5c…29a0`) CR'siz parolayla yeniden paketleyip GitHub'a yükledi. Yeniden çalıştırılan derleme bu anahtarla imzalandı. Arşivler değişmedi:

- Arşivdeki `.jks` dosyası, bilgi dosyasındaki parolanın sonuna CR eklenmiş haliyle açılır.
- GitHub'daki kopya aynı anahtarın CR'siz parolayla paketlenmiş halidir.
- GitHub'daki kopya yeniden yüklenecekse onarma betiği iki durumu da kendisi ayırt eder.

Oluşturma betiği artık CR'yi de siliyor. Git Bash'in "/" ile başlayan değerleri yol sanıp çevirmesini de kapatıyor; bu ikinci tuzak bu sefer tetiklenmemişti. İş akışı da parolaları derlemeden önce `keytool` ile deniyor; yanlışsa derlemeye başlamadan duruyor.

Deneme: iş akışı önce bir deneme anahtarıyla (sertifika `baa13a57…af3f9`, `CN=KeyKey Deneme Anahtari`, artık kullanılmıyor), hiçbir dala girmeyen bir deneme commit'inde (`v1.0.0-deneme.1`) sınandı: taslak ön sürüm dört dosyayla oluştu, özetler ve imza yerelde `sha256sum -c` ve `apksigner` ile doğrulandı. Deneme etiketi ve taslak sonra silindi.

### Eski sürümlerden geçiş

`v0.x` sürümleri hata ayıklama anahtarıyla imzalıydı. Android farklı imzalı bir APK'yı üstüne kurmaz; 1.0'a geçmek için KeyKey'den şifreli yedek al, eski uygulamayı kaldır, 1.0'ı kur ve yedeği geri yükle. Kaldırma bütün veriyi siler, yedeği önce başka bir yere kopyala. Geri yüklenen kasa aynı ana parola ve kurtarma anahtarıyla açılır; parmak iziyle açma kaldırmayla silinir, Ayarlar'dan yeniden açılmalıdır.

**Deneme (2026-11-10, [#101](https://github.com/aaudraa/KeyKey/issues/101)).** Android 16 emülatöründe (`KeyKey_API_36`), `v0.8.0` ile kurulan kasada bir parola kaydı, ona bağlı bir 2FA hesabı (bilinen anahtarla) ve parmak iziyle açma vardı. İki yol denendi:

| Yol | Sonuç |
|---|---|
| Aynı imzalı yeni sürüm üstüne kuruldu (`adb install -r`, hata ayıklama anahtarı) | Kasa parmak iziyle ve ana parolayla açıldı. Kayıt, parola, 2FA kodu (bilgisayarda hesaplananla aynı), kayıtla 2FA bağı ve son yedek tarihi korundu. SQLite'ın hazır dosyadan repodaki kaynağa geçmesi ([#99](https://github.com/aaudraa/KeyKey/issues/99)) mevcut veritabanını etkilemedi. |
| Farklı imzalı yeni sürüm (bir deneme anahtarıyla) | Üstüne kurulum `INSTALL_FAILED_UPDATE_INCOMPATIBLE` ile reddedildi. Yukarıdaki yol izlendi: yedek dosyası kaldırmadan sonra İndirilenler'de kaldı, ilk ekrandan ana parolayla geri yüklendi, bütün veri ve bağ yerindeydi. Parmak iziyle açma kapalı geldi, yeniden açıldı ve çalıştı. |

Gerçek yayın anahtarı yerine deneme anahtarı kullanıldı; Android için ikisi de "farklı imza" olduğundan sonuç aynıdır. Biçim uyumluluğu ayrıca birim testlerinde örnek dosyalarla sınanıyor (`test/fixtures/storage`, `vault`, `backup`). 1.0 etiketinden önce fazın son derlemesiyle aynı-imza yolu kısaca tekrarlanacak.

**Son derlemeyle tekrar (2026-11-16).** Android 16 emülatörü bozuk olduğu için Android 17 emülatöründe (`Medium_Phone_API_37.0`) yapıldı. `v0.8.0` (`0.1.0+1`) ile yeni kasa kuruldu: bir parola kaydı, ona bağlı bir 2FA hesabı (bilinen anahtarla), parmak iziyle açma ve bir yedek. Üstüne `main`'deki son derleme (`4fd40b3`, `1.0.0-dev+2`, aynı hata ayıklama anahtarı) `adb install -r` ile kuruldu. Kasa olduğu için tanıtım çıkmadı. Kasa parmak iziyle ve kilitledikten sonra ana parolayla açıldı. Kayıt ve parolası, 2FA bağı ve kodu (bilgisayarda hesaplananla aynı), "son yedek" bilgisi ve parmak izi ayarı korundu.

## Sürüm numarası

`pubspec.yaml`'daki `version: <ad>+<derleme numarası>` satırı iki şey belirler:

- **Ad** (`versionName`) [anlamsal sürümdür](https://semver.org/lang/tr/): `BÜYÜK.KÜÇÜK.YAMA`. Kasa veya yedek biçimini eskisiyle açılamayacak şekilde değiştiren sürüm büyük numarayı artırır, yeni özellik küçük numarayı, yalnızca düzeltme yama numarasını. `1.0.0`'dan önce her faz küçük numarayı artırdı.
- **Derleme numarası** (`versionCode`) her yayında 1 artar ve hiç azalmaz. Android daha küçük numaralı bir APK'yı üstüne kurmaz. Telefon denemesine verilen etiketsiz derlemeler de numara alabilir; numara yalnızca ileri gider.
- Fazın ortasında ad, gidilen sürümün `-dev` ekli halidir (`1.0.0-dev`). Yayın commit'i eki kaldırır. Sürüm adında `-` olan etiketler ön sürüm sayılır.
- Değişiklikler [değişiklik günlüğüne](../CHANGELOG.md) "Yayımlanmamış" başlığı altında yazılır; yayında başlık sürümün adını ve tarihini alır.

`v0.8.0`'a kadar `pubspec.yaml` `0.1.0+1`'de kaldı; etiketler fazları işaretledi. Faz 9'da `1.0.0-dev+2`, yayın commit'inde `1.0.0+3` oldu.

## Sürüm çıkarmak

1. `pubspec.yaml`'daki `version` satırını güncelle ve değişiklik günlüğündeki "Yayımlanmamış" başlığını sürümün adıyla değiştir. Etiket, bu satırdaki sürümün başına `v` eklenmiş hali olmalı: `version: 1.0.0+3` için `v1.0.0`. Uyuşmazsa iş akışı durur.
2. F-Droid için iki dilde kısa değişiklik notu ekle: `fastlane/metadata/android/{en-US,tr-TR}/changelogs/<derleme numarası>.txt` (en çok 500 bayt). F-Droid notları etiketin commit'inden okur; etiketten **önce** girmeli. Yoksa CI'daki `check-fastlane.py` durur.
3. Değişikliği `main`'e birleştir.
4. Etiketi at ve gönder: `git tag v1.0.0 && git push origin v1.0.0`. İş akışını GitHub'da onayla (Actions → çalışma → "Review deployments").
5. Taslak, iş akışının "F-Droid karşılaştırması" yeşil olunca oluşur; gözden geçir ve yayımla. Karşılaştırma kırmızıysa taslak oluşmaz: F-Droid bu sürümü bizim imzamızla alamaz; nedeni bulunur, düzeltme bir sonraki sürüme girer. Taslağı uzun süre bekletme: F-Droid yeni etiketi görünce APK'yı yayının adresinden indirmeye çalışır. Sürüm adında `-` varsa (`v1.1.0-beta.1` gibi) taslak ön sürüm olarak işaretlenir ve F-Droid onu almaz.

İş akışının yaptıkları:

1. Etiketin `pubspec.yaml` ile uyuştuğunu denetler.
2. APK ve AAB'yi F-Droid'in derleme imajında, `/home/vagrant/build/io.github.aaudraa.keykey` yolunda, tarifteki adımlarla imzasız derler ([`f-droid-yolunda-derle.sh`](../scripts/f-droid-yolunda-derle.sh)); aynı derlemeden işlemciye özel üç APK'yı çıkarır ve evrenselin alt kümesi olduklarını denetler ([işlemciye özel APK'lar](#işlemciye-özel-apklar)). Onay gelince dördünü de yayın anahtarıyla imzalar.
3. Her APK'yı [`check-release-apk.sh`](../scripts/check-release-apk.sh) ile denetler: izinler, dışa açık bileşenler, R8, semboller, deneme değerleri.
4. Her APK'nın imzasını `apksigner` ile doğrular ([`imza-ozeti.sh`](../scripts/imza-ozeti.sh)); sertifika F-Droid tarifindeki `AllowedAPKSigningKeys` değeri değilse durur ([imza denetimi](#imza-denetimi)).
5. Aynı commit'i F-Droid'in kendi aracıyla, imajın güncel haliyle derler ([`f-droid-derle.sh`](../scripts/f-droid-derle.sh)) ve imzalı APK'yla karşılaştırır ([`f-droid-karsilastir.sh`](../scripts/f-droid-karsilastir.sh)).
6. Karşılaştırma yeşilse taslağa şunları koyar: `keykey-<sürüm>.apk` (evrensel), `keykey-<sürüm>-arm64-v8a.apk`, `keykey-<sürüm>-armeabi-v7a.apk`, `keykey-<sürüm>-x86_64.apk`, `keykey-<sürüm>.aab`, `keykey-<sürüm>-mapping.txt` (R8'in ad tablosu, yığın izlerini okumak için) ve hepsinin SHA-256 özetlerini içeren `SHA256SUMS`. Notlara evrensel APK'nın, işlemciye özel APK'ların ve imza sertifikasının özetini yazar.
7. Taslak yayımlanınca [F-Droid deposu](#f-droid-deposu) iş akışı depoyu yeniden kurar.

Yayın zincirinin tamamı (AAB dahil derleme, imzalama, APK denetimi, imza denetimi, karşılaştırma) her PR'da ve haftada bir [`f-droid.yml`](../../.github/workflows/f-droid.yml)'da tek kullanımlık bir anahtarla denenir; etiket bu yüzden ilk kez çalışan bir zinciri tetiklemez.

### İmza denetimi

İmzalı APK'nın sertifika özetini [`imza-ozeti.sh`](../scripts/imza-ozeti.sh) okur. `apksigner`'ın çıktısı sürüme göre değişiyor: build-tools 36 `Signer #1 certificate SHA-256 digest: …`, 37 her imza şeması için ayrı `V3.0 Signer: certificate SHA-256 digest: …` yazıyor. Betik ikisini de okur; bütün imzalayanlar aynı sertifikayı kullanmıyorsa durur. Okuyuşu [`imza-ozeti-test.sh`](../scripts/imza-ozeti-test.sh) iki biçimin gerçek örnekleriyle sınar; prova her PR'da ikisini de çalıştırır.

2026-11-17'de bu denetim iş akışının içinde, yalnızca eski biçimi okuyan bir satırdı ve provada yoktu. GitHub'ın Ubuntu imajı build-tools 37'ye geçince `v1.1.0`'ın ilk denemesi, APK doğru anahtarla imzalandığı halde "imza sertifikası ''" hatasıyla durdu. `v1.0.1`'in bekleyen çalışması da aynı satırı taşıdığı için iptal edildi; 1.0.1 yayımlanmadı, değişiklikleri 1.1.0'da. `v1.1.0` etiketi düzeltmenin commit'ine taşındı (sürüm hiç yayımlanmamıştı).

### Derleme imajını güncellemek

Bizim derleme F-Droid imajının sabit bir özetiyle yapılır (`yayin.yml`'daki `derle`, `f-droid.yml`'daki `bizim` işi; ikisi aynı olmalı). F-Droid'in karşılaştırma derlemesi imajın güncel halini kullanır. Haftalık `f-droid.yml` çalışması kırmızı olur ve fark ortamdan geliyorsa (JDK, NDK, araçlar) özet güncellenir: başarılı bir çalışmanın F-Droid işinin günlüğündeki `Digest: sha256:…` satırı yeni özettir. İki dosyada değiştirilip PR açılır; PR'daki `f-droid.yml` çalışması yeşil olmalı.

## İşlemciye özel APK'lar

Evrensel APK üç işlemcinin yerel kodunu (Flutter motoru, libsodium, Argon2) birlikte taşıyor. 1.12.0'dan beri her sürümde yanında `arm64-v8a`, `armeabi-v7a` ve `x86_64` APK'ları da var; her biri yalnızca kendi işlemcisinin kodunu taşıdığı için evrenselin üçte biri kadar.

- Aynı derlemeden çıkarlar: `f-droid-yolunda-derle.sh` evrenseli derledikten sonra aynı klasörde `flutter build apk --split-per-abi -Pforce-version-code-ignoring-abi=true` çalıştırır. Sürüm kodları evrenselinkiyle aynıdır; böylece biri kurulu telefona öteki güncelleme olarak gelir.
- F-Droid evrenseli doğruluyor, işlemciye özel olanları değil. Bu yüzden [`abi-apk-denetle.sh`](../scripts/abi-apk-denetle.sh) her birinin evrenselin alt kümesi olduğunu denetler: `META-INF/` dışındaki her dosya evrenselde aynı baytlarla var, evrenseldeki her dosya da (başka işlemcilerin `lib/` klasörleri hariç) onda var. Böylece yeniden üretilebilirlik güvencesi onlara da geçer. Betiği [`abi-apk-denetle-test.sh`](../scripts/abi-apk-denetle-test.sh) yapay APK'larla sınar.
- Yayında ve her PR'da dördü aynı anahtarla imzalanır, `check-release-apk.sh` ve imza denetiminden geçer.

Obtainium (1.7.4) bir sürümde birden çok APK görünce telefonun işlemcisine uyanı kendisi seçiyor ("Attempt to filter APKs by CPU architecture", varsayılan açık). 2026-11-25'te x86_64 emülatörde var olan bir kayıtla denendi: `keykey-<sürüm>-x86_64.apk`'yı seçip kurulum ekranına geldi.

## F-Droid deposu

KeyKey'in kendi F-Droid deposu: `https://aaudraa.github.io/KeyKey/fdroid/repo`. Tasarım: [dağıtım](dagitim.md).

- **İş akışı:** [`fdroid-deposu.yml`](../../.github/workflows/fdroid-deposu.yml). Bir sürüm yayımlanınca (ön sürümler hariç) [`fdroid-deposu-kur.sh`](../scripts/fdroid-deposu-kur.sh) yayımlanmış son üç sürümün APK'larını indirir, her birinin `SHA256SUMS`'a uyduğunu ve yayın anahtarıyla imzalı olduğunu denetler, `fdroid update` ile depoyu baştan kurar ve indeksi depo anahtarıyla imzalar. [`fdroid-deposu-dogrula.sh`](../scripts/fdroid-deposu-dogrula.sh) indeksin imzasını, APK özetlerini ve siteye yapılandırma ya da anahtar girmediğini denetler; site GitHub Pages'e yüklenir. Saklanan durum yok: depo her seferinde sürümlerden yeniden üretilir.
- **Prova:** Her PR'da `f-droid.yml`'daki "Depo provası" aynı betikleri tek kullanımlık bir anahtarla, gerçek yayımlanmış sürümlerle ve PR'ın kendi APK'larıyla çalıştırır; yayımlamaz.
- **Elle çalıştırmak:** Actions → "F-Droid deposu" → "Run workflow", dal olarak son `v*` etiketi seçilir. Ortamlar (`fdroid-deposu`, `github-pages`) yalnızca `v*` etiketlerine açık.
- **Depo anahtarı:** Yayın anahtarından ayrı; APK'yı değil depo indeksini imzalar. Proje sahibinin bilgisayarında [`depo-anahtari-olustur.sh`](../scripts/depo-anahtari-olustur.sh) ile oluşturulur. Betik yayın anahtarınınkiyle aynı kuralları izler: rastgele parola, AES-256 şifreli arşiv, E: ve D: kopyaları, üçüncü kopya Google Drive. Betik anahtarı GitHub'daki `fdroid-deposu` ortamına (`FDROID_KEYSTORE_BASE64`, `FDROID_KEYSTORE_PASSWORD`, `FDROID_KEY_PASSWORD`, `FDROID_KEY_ALIAS`) yükler ve `FDROID_DEPOSU_HAZIR` depo değişkenini koyar. Bu değişken yoksa iş akışı kırmızıya düşmek yerine atlanır.
- **Anahtar kaybolursa:** Depo yeni bir anahtarla kurulur, kullanıcılar depoyu yeni parmak iziyle yeniden ekler. Uygulama ve veri etkilenmez, çünkü APK'lar yayın anahtarıyla imzalı.
- **Anahtar sızarsa:** Sızdıran kişi sahte bir indeks imzalayabilir, ama kurulu KeyKey'e başka anahtarla imzalı bir güncelleme kurulamaz. Yeni kurulumlar için risk var: anahtar değiştirilir ve README'deki parmak izi güncellenir.

## İndirilen APK'yı doğrulamak

1. Özeti karşılaştır: `sha256sum keykey-1.0.0.apk` çıktısı, sürüm notlarındaki ve `SHA256SUMS` dosyasındaki değerle aynı olmalı. İşlemciye özel APK'ların özetleri de ikisinde var.
2. İmzayı denetle: `apksigner verify --print-certs keykey-1.0.0.apk` çıktısındaki "certificate SHA-256 digest" değeri şu olmalı: `66ff7b5c0c009a8530d0a55dd1d80a3af35de48bd0667c456a0cf86a6d1129a0`. Telefonda kurulu uygulama için [AppVerifier](https://github.com/soupslurpr/AppVerifier) gibi bir araç aynı özeti gösterir.

Aynı özet README'de ve [güvenlik özetinde](security-summary.md#release-signing) de yayımlıdır; üçü birbirini tutmalı.

## Yeniden üretilebilir derleme

Amaç: herkes aynı koddan aynı APK'yı derleyip yayındaki APK'nın gerçekten bu koddan çıktığını görebilsin. Deneme 2026-11-09'da Windows 11'de, Flutter 3.47.9 ile yapıldı (#99).

| Deneme | Sonuç |
|---|---|
| Aynı klasörde iki temiz derleme (`flutter clean` arasında) | Zip içeriği ve v2 imzası aynı. Tek fark, Android Gradle eklentisinin APK'nın imza bloğuna gömdüğü şifreli bağımlılık listesiydi; her derlemede farklı şifreleniyor. Kapatıldı (`dependenciesInfo`), sonra iki derleme bayt bayt aynı. |
| Farklı klasörde temiz klon (`C:\KeyKey` ve `C:\KK2`) | 460 dosyadan 6'sı farklı: üç işlemci türü için `libapp.so` ve `libdartjni.so`. |
| Yayın iş akışında aynı commit'ten iki derleme (GitHub, Ubuntu 24.04, deneme etiketi `v1.0.0-deneme.1`) | APK, AAB ve `mapping.txt` bayt bayt aynı; imzalar da aynı (RSA imzası belirlenimci). |
| F-Droid'in derleme imajında bizim derleme ve `fdroid build` (Faz 10, 2026-11-17, [`f-droid.yml`](../../.github/workflows/f-droid.yml)) | Dokuzuncu denemede aynı: F-Droid'in derlemesi bizim imzamızı kabul etti (`apksigcopier compare`). Yolda giderilenler: imajda `make` yok (libsodium); F-Droid'in tarayıcısı `sodium` paketindeki libsodium kaynak arşivini siliyordu (`scanignore`); Debian'ın `apksigner`'ı v1 imzası ekliyordu ve zaten hizalı girdileri yeniden hizalıyordu (`--v1-signing-enabled false`, `--alignment-preserved true`). Girdilerin içeriği her denemede bayt bayt aynıydı. |

Klasöre bağlı farkların nedenleri:

- `libapp.so` (Dart kodunun derlenmiş hali), Flutter'ın ürettiği `dart_plugin_registrant.dart` dosyasının mutlak yolunu içeriyor. Bu Flutter'ın davranışı, projeden değiştirilemiyor.
- `libdartjni.so` (`jni` paketi) yalnızca 20 baytlık derleme kimliğinde (`NT_GNU_BUILD_ID`) ayrılıyor. Kimlik, derlemedeki dosya yollarından hesaplanıyor.

Sonuç: **Aynı kod, aynı araç sürümleri ve aynı klasör yolu aynı APK'yı veriyor.** Bu yüzden `v1.0.1`'den beri yayın derlemesi F-Droid'in derleme imajında (`registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie`: Debian OpenJDK 21, `/opt/android-sdk`, NDK r28c) ve F-Droid'in derleme yolunda (`/home/vagrant/build/io.github.aaudraa.keykey`, Flutter `/home/vagrant/build/srclib/flutter`) yapılıyor. Doğrulamak için:

1. Aynı imajda, yayının commit'iyle [`f-droid-yolunda-derle.sh`](../scripts/f-droid-yolunda-derle.sh)'yi çalıştır (imzasız APK verir) ya da F-Droid'in kendi aracını [`f-droid-derle.sh`](../scripts/f-droid-derle.sh) ile.
2. Yayındaki APK'nın imzasını kendi derlemene kopyalayıp doğrula: `apksigcopier compare keykey-<sürüm>.apk --unsigned <senin-derlemen>.apk` ([`f-droid-karsilastir.sh`](../scripts/f-droid-karsilastir.sh) aynısını yapar, tutmazsa farklı dosyaları listeler). `v1.0.0` eski yolda (`/home/runner/work/KeyKey/KeyKey`, Temurin JDK 21) derlendi.

[`check-release-apk.sh`](../scripts/check-release-apk.sh) imza bloğunda imzalar ve dolgu dışında bir şey bulursa durur ([`imza-blogu.mjs`](../scripts/imza-blogu.mjs)); şifreli bağımlılık listesi yanlışlıkla geri gelirse yakalanır.

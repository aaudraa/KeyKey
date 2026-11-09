# Yayın

KeyKey sürümleri GitHub Actions'ta, `v` ile başlayan bir etiket gönderilince derlenir ve imzalanır ([`.github/workflows/yayin.yml`](../../.github/workflows/yayin.yml)). İş akışı taslak bir GitHub Release oluşturur; taslağı yayımlamak elle yapılır.

## Yayın anahtarı

- Anahtar repoya girmez. GitHub'daki `yayin` ortamının gizli değerlerinde durur:

  | Gizli değer | İçerik |
  |---|---|
  | `KEYKEY_KEYSTORE_BASE64` | Anahtar deposu (`.jks`), base64 |
  | `KEYKEY_KEYSTORE_PASSWORD` | Deponun parolası |
  | `KEYKEY_KEY_ALIAS` | Anahtarın adı |
  | `KEYKEY_KEY_PASSWORD` | Anahtarın parolası |

- `yayin` ortamı yalnızca `v*` etiketlerine açıktır. Bir dal ya da PR'daki iş akışı anahtara erişemez.
- Gradle anahtarı yalnızca `KEYKEY_KEYSTORE` ve yanındaki ortam değişkenlerinden okur ([`android/app/build.gradle.kts`](../../android/app/build.gradle.kts)). Değişkenler yoksa yerel yayın derlemesi debug anahtarıyla imzalanır; iş akışı debug anahtarıyla imzalı bir APK'yı kabul etmez.
- İş akışı anahtar dosyasını derlemeden hemen sonra siler. Önbellek kullanmaz, böylece yayın derlemesine başka işlerin yazdığı bir önbellek karışmaz.

Kalıcı anahtar henüz oluşturulmadı (#97). O zamana kadar ortamdaki değerler yalnızca iş akışını sınamak için kullanılan bir deneme anahtarıdır (sertifika özeti `baa13a57…af3f9`, `CN=KeyKey Deneme Anahtari`). Bu anahtarla imzalı bir APK yayımlanmaz.

İş akışı 2026-11-09'da hiçbir dala girmeyen bir deneme commit'inde (`v1.0.0-deneme.1`) sınandı: taslak ön sürüm dört dosyayla oluştu, özetler ve imza yerelde `sha256sum -c` ve `apksigner` ile doğrulandı. Deneme etiketi ve taslak sonra silindi.

## Sürüm numarası

`pubspec.yaml`'daki `version: <ad>+<derleme numarası>` satırı iki şey belirler:

- **Ad** (`versionName`) [anlamsal sürümdür](https://semver.org/lang/tr/): `BÜYÜK.KÜÇÜK.YAMA`. Kasa veya yedek biçimini eskisiyle açılamayacak şekilde değiştiren sürüm büyük numarayı artırır, yeni özellik küçük numarayı, yalnızca düzeltme yama numarasını. `1.0.0`'dan önce her faz küçük numarayı artırdı.
- **Derleme numarası** (`versionCode`) her yayında 1 artar ve hiç azalmaz. Android daha küçük numaralı bir APK'yı üstüne kurmaz. Telefon denemesine verilen etiketsiz derlemeler de numara alabilir; numara yalnızca ileri gider.
- Fazın ortasında ad, gidilen sürümün `-dev` ekli halidir (`1.0.0-dev`). Yayın commit'i eki kaldırır. Sürüm adında `-` olan etiketler ön sürüm sayılır.
- Değişiklikler [değişiklik günlüğüne](../CHANGELOG.md) "Yayımlanmamış" başlığı altında yazılır; yayında başlık sürümün adını ve tarihini alır.

`v0.8.0`'a kadar `pubspec.yaml` `0.1.0+1`'de kaldı; etiketler fazları işaretledi. Faz 9'da `1.0.0-dev+2` oldu.

## Sürüm çıkarmak

1. `pubspec.yaml`'daki `version` satırını güncelle ve değişiklik günlüğündeki "Yayımlanmamış" başlığını sürümün adıyla değiştir. Etiket, bu satırdaki sürümün başına `v` eklenmiş hali olmalı: `version: 1.0.0+3` için `v1.0.0`. Uyuşmazsa iş akışı durur.
2. Değişikliği `main`'e birleştir.
3. Etiketi at ve gönder: `git tag v1.0.0 && git push origin v1.0.0`.
4. İş akışı bitince GitHub'daki taslağı gözden geçir ve yayımla. Sürüm adında `-` varsa (`v1.1.0-beta.1` gibi) taslak ön sürüm olarak işaretlenir.

İş akışının yaptıkları:

1. Etiketin `pubspec.yaml` ile uyuştuğunu denetler.
2. APK ve AAB derler, yayın anahtarıyla imzalar.
3. APK'yı [`check-release-apk.sh`](../scripts/check-release-apk.sh) ile denetler: izinler, dışa açık bileşenler, R8, semboller, deneme değerleri.
4. İmzayı `apksigner` ile doğrular; debug anahtarıyla imzalıysa durur.
5. Taslağa şunları koyar: `keykey-<sürüm>.apk`, `keykey-<sürüm>.aab`, `keykey-<sürüm>-mapping.txt` (R8'in ad tablosu, yığın izlerini okumak için) ve hepsinin SHA-256 özetlerini içeren `SHA256SUMS`. Notlara APK'nın ve imza sertifikasının özetini yazar.

## İndirilen APK'yı doğrulamak

1. Özeti karşılaştır: `sha256sum keykey-1.0.0.apk` çıktısı, sürüm notlarındaki ve `SHA256SUMS` dosyasındaki değerle aynı olmalı.
2. İmzayı denetle: `apksigner verify --print-certs keykey-1.0.0.apk` çıktısındaki "certificate SHA-256 digest" değeri, README'de yayımlanan sertifika özetiyle aynı olmalı. Telefonda kurulu uygulama için [AppVerifier](https://github.com/soupslurpr/AppVerifier) gibi bir araç aynı özeti gösterir.

Sertifika özeti kalıcı anahtar oluşturulunca README'ye ve [güvenlik tasarımına](guvenlik-tasarimi.md) yazılacak (#97).

## Yeniden üretilebilir derleme

Amaç: herkes aynı koddan aynı APK'yı derleyip yayındaki APK'nın gerçekten bu koddan çıktığını görebilsin. Deneme 2026-11-09'da Windows 11'de, Flutter 3.47.9 ile yapıldı (#99).

| Deneme | Sonuç |
|---|---|
| Aynı klasörde iki temiz derleme (`flutter clean` arasında) | Zip içeriği ve v2 imzası aynı. Tek fark, Android Gradle eklentisinin APK'nın imza bloğuna gömdüğü şifreli bağımlılık listesiydi; her derlemede farklı şifreleniyor. Kapatıldı (`dependenciesInfo`), sonra iki derleme bayt bayt aynı. |
| Farklı klasörde temiz klon (`C:\KeyKey` ve `C:\KK2`) | 460 dosyadan 6'sı farklı: üç işlemci türü için `libapp.so` ve `libdartjni.so`. |
| Yayın iş akışında aynı commit'ten iki derleme (GitHub, Ubuntu 24.04, deneme etiketi `v1.0.0-deneme.1`) | APK, AAB ve `mapping.txt` bayt bayt aynı; imzalar da aynı (RSA imzası belirlenimci). |

Klasöre bağlı farkların nedenleri:

- `libapp.so` (Dart kodunun derlenmiş hali), Flutter'ın ürettiği `dart_plugin_registrant.dart` dosyasının mutlak yolunu içeriyor. Bu Flutter'ın davranışı, projeden değiştirilemiyor.
- `libdartjni.so` (`jni` paketi) yalnızca 20 baytlık derleme kimliğinde (`NT_GNU_BUILD_ID`) ayrılıyor. Kimlik, derlemedeki dosya yollarından hesaplanıyor.

Sonuç: **Aynı kod, aynı araç sürümleri ve aynı klasör yolu aynı APK'yı veriyor.** F-Droid de doğrulama derlemelerini sabit bir yolda yapar. Doğrulamak için:

1. Yayının commit'ini, yayın iş akışının kullandığı yola klonla. GitHub'ın Ubuntu makinesinde bu yol `/home/runner/work/KeyKey/KeyKey`.
2. İş akışındaki sürümlerle derle: Flutter 3.47.9, Temurin JDK 21, NDK'yı Flutter seçer. Komut: `flutter build apk --release`.
3. İmzalar farklı anahtarla atıldığı için APK'nın tamamı değil, içindeki dosyalar karşılaştırılır: `unzip -v` çıktısındaki CRC'ler ya da [apksigcopier](https://github.com/obfusk/apksigcopier) ile yayındaki imzayı kendi derlemene kopyalayıp özeti karşılaştırmak.

[`check-release-apk.sh`](../scripts/check-release-apk.sh) imza bloğunda imzalar ve dolgu dışında bir şey bulursa durur ([`imza-blogu.mjs`](../scripts/imza-blogu.mjs)); şifreli bağımlılık listesi yanlışlıkla geri gelirse yakalanır.

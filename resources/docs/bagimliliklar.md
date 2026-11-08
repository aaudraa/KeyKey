# KeyKey Bağımlılıkları

Uygulamaya giren her paketin neden orada olduğu, sürümü, lisansı ve derlemede nereden geldiği. Faz 8'de ([#86](https://github.com/aaudraa/KeyKey/issues/86)) yazıldı. **Tarih:** 2026-11-08. **Flutter:** 3.47.9 (stable).

KeyKey GPL-3.0 ile yayımlanır. Bu yüzden içine giren her şeyin lisansı GPL-3.0 ile birlikte dağıtılabilir olmalı.

## Özet

| Konu | Sonuç |
|---|---|
| Lisans uyumu | Uyumlu. Kodların hepsi izin veren lisanslarla geliyor: BSD-2/3-Clause, MIT, Apache-2.0, ISC; SQLite kamu malı. GPL'li, LGPL'li ya da lisanssız paket yok. Apache-2.0 GPL-3.0 ile uyumlu (GPL-2.0 ile uyumlu olmazdı). |
| Veri dosyaları | Public Suffix List MPL-2.0; GPL ile birlikte dağıtılabilir, dosya değiştirilmeden gömülü. EFF sözcük listesi CC BY 3.0, atıf istiyor. SecLists parola listesi MIT. Üçü de kod değil, uygulamanın okuduğu veri. Atıfları Lisanslar ekranında. |
| Kullanılmayan paket | Yok. Doğrudan bağımlılıkların hepsi kodda kullanılıyor (aşağıdaki tablo). |
| Güncellik | Doğrudan bağımlılıkların hepsi son kararlı sürümde, biri hariç: `androidx.biometric`'in 1.1.0'dan yeni kararlı sürümü yok. Bekleyen dolaylı paketler ve nedenleri [Güncellik](#güncellik) bölümünde. |
| Derlemede indirilen | Yalnızca SQLite'ın hazır kütüphanesi (`sqlite3` paketi); özeti paketin içinde sabit. Ayrıntı: [Derlemede indirilenler](#derlemede-indirilenler). |
| Lisanslar ekranı | Android kütüphaneleri ve SQLite eksikti, eklendi. Ayrıntı: [Lisanslar ekranı](#lisanslar-ekranı). |
| Bilinen açıklar | Bir tane vardı (Guava), düzeltilmiş sürüme geçildi. Şu an bilinen açık yok. Ayrıntı: [Bilinen açıklar](#bilinen-açıklar). |

## Doğrudan Dart bağımlılıkları

| Paket | Sürüm | Lisans | Neden |
|---|---|---|---|
| `sodium` | 4.1.2+1 | BSD-3-Clause; içindeki libsodium 1.0.22 ISC | Bütün kriptografi: Argon2id, XChaCha20-Poly1305, rastgele sayı, korumalı bellek |
| `sqlite3` | 3.9.1 | MIT; SQLite kamu malı | Veritabanı motoru |
| `drift` | 2.35.3 | MIT | Veritabanı şeması, sorgular ve göçler |
| `crypto` | 3.0.8 | BSD-3-Clause | 2FA kodları için HMAC-SHA1/256/512; içe aktarmada anahtar türetme |
| `flutter_riverpod` | 3.5.0 | MIT | Uygulama durumunun yönetimi |
| `go_router` | 18.1.3 | BSD-3-Clause | Ekranlar arası geçiş |
| `intl` | 0.20.3 | BSD-3-Clause | Tarih ve sayı biçimleri, çeviriler (`flutter_localizations` ile) |
| `camera` | 0.12.2 | BSD-3-Clause | 2FA QR kodunu kamerayla okuma |
| `flutter_zxing` | 3.1.0 | MIT; içindeki zxing-cpp Apache-2.0, zint BSD-3-Clause | QR kodunu çözme |
| `image_picker` | 1.2.4 | BSD-3-Clause, Apache-2.0 | QR kodunu galerideki görselden okuma |
| `file_selector` | 1.1.0 | BSD-3-Clause | Yedek ve içe aktarma dosyası seçme, dışa aktarmayı kaydetme |
| `path_provider` | 2.1.6 | BSD-3-Clause | Kasa dosyasının uygulama klasöründeki yeri |
| `flutter`, `flutter_localizations` | SDK | BSD-3-Clause | Arayüz çerçevesi |

Geliştirme bağımlılıkları uygulamaya girmez: `build_runner` ve `drift_dev` (drift kodu üretimi), `pigeon` (Dart-Kotlin köprüsünün üretimi), `very_good_analysis` (kod kuralları), `flutter_test` ve `integration_test`.

## Bütün Dart paketleri

Uygulamanın normal bağımlılıklarından ulaşılan 104 paket. Liste [`dart-lisanslari.mjs`](../scripts/dart-lisanslari.mjs) betiğiyle üretilir:

```sh
flutter pub deps --json > deps.json
node resources/scripts/dart-lisanslari.mjs deps.json
```

Okurken bilinmesi gerekenler:

- Paketlerin bir kısmı başka platformlar içindir (`_ios`, `_web`, `_windows`, `objective_c` ...). Listede görünürler, ama Android derlemesine kodları girmez.
- `hooks`, `code_assets`, `native_toolchain_c` ve `archive` derleme sırasında yerel kütüphaneleri hazırlamak için çalışır; uygulamada kullanılmaz.
- `flutter_test` ve onun getirdikleri (`leak_tracker`, `matcher`, `test_api` ...) `flutter_riverpod`'un bağımlılığı olduğu için listede. KeyKey kodu bunları kullanmadığı için Dart derleyicisi onları uygulamaya koymaz.

| Paket | Sürüm | Tür | Lisans |
|---|---|---|---|
| `archive` | 4.6.0 | dolaylı | MIT |
| `args` | 2.7.0 | dolaylı | BSD-3-Clause |
| `async` | 2.13.1 | dolaylı | BSD-3-Clause |
| `boolean_selector` | 2.1.2 | dolaylı | BSD-3-Clause |
| `camera` | 0.12.2 | doğrudan | BSD-3-Clause |
| `camera_android_camerax` | 0.7.6+1 | dolaylı | BSD-3-Clause |
| `camera_avfoundation` | 0.11.1 | dolaylı | BSD-3-Clause |
| `camera_platform_interface` | 2.15.0 | dolaylı | BSD-3-Clause |
| `camera_web` | 0.3.6 | dolaylı | BSD-3-Clause |
| `characters` | 1.4.1 | dolaylı | BSD-3-Clause |
| `clock` | 1.1.3 | dolaylı | Apache-2.0 |
| `code_assets` | 2.2.0 | dolaylı | BSD-3-Clause |
| `collection` | 1.19.1 | dolaylı | BSD-3-Clause |
| `convert` | 3.1.2 | dolaylı | BSD-3-Clause |
| `cross_file` | 0.3.5+5 | dolaylı | BSD-3-Clause |
| `crypto` | 3.0.8 | doğrudan | BSD-3-Clause |
| `csslib` | 1.0.2 | dolaylı | BSD-3-Clause |
| `cupertino_ui` | 1.1.6 | dolaylı | BSD-3-Clause |
| `drift` | 2.35.3 | doğrudan | MIT |
| `fake_async` | 1.3.3 | dolaylı | Apache-2.0 |
| `ffi` | 2.2.0 | dolaylı | BSD-3-Clause |
| `file` | 7.0.1 | dolaylı | BSD-3-Clause |
| `file_selector` | 1.1.0 | doğrudan | BSD-3-Clause |
| `file_selector_android` | 0.5.2+11 | dolaylı | BSD-3-Clause, Apache-2.0 |
| `file_selector_ios` | 0.5.3+7 | dolaylı | BSD-3-Clause |
| `file_selector_linux` | 0.9.4+1 | dolaylı | BSD-3-Clause |
| `file_selector_macos` | 0.9.5+2 | dolaylı | BSD-3-Clause |
| `file_selector_platform_interface` | 2.7.0 | dolaylı | BSD-3-Clause |
| `file_selector_web` | 0.9.5 | dolaylı | BSD-3-Clause |
| `file_selector_windows` | 0.9.3+6 | dolaylı | BSD-3-Clause |
| `fixnum` | 1.1.1 | dolaylı | BSD-3-Clause |
| `flutter` | 0.0.0 | doğrudan | BSD-3-Clause (Flutter SDK) |
| `flutter_localizations` | 0.0.0 | doğrudan | BSD-3-Clause (Flutter SDK) |
| `flutter_plugin_android_lifecycle` | 2.0.35 | dolaylı | BSD-3-Clause |
| `flutter_riverpod` | 3.5.0 | doğrudan | MIT |
| `flutter_test` | 0.0.0 | dolaylı | BSD-3-Clause (Flutter SDK) |
| `flutter_web_plugins` | 0.0.0 | dolaylı | BSD-3-Clause (Flutter SDK) |
| `flutter_zxing` | 3.1.0 | doğrudan | MIT |
| `freezed_annotation` | 3.1.0 | dolaylı | MIT |
| `glob` | 2.2.0 | dolaylı | BSD-3-Clause |
| `go_router` | 18.1.3 | doğrudan | BSD-3-Clause |
| `hooks` | 2.2.0 | dolaylı | BSD-3-Clause |
| `html` | 0.15.7 | dolaylı | MIT |
| `http` | 1.6.0 | dolaylı | BSD-3-Clause |
| `http_parser` | 4.1.2 | dolaylı | BSD-3-Clause |
| `image` | 4.12.0 | dolaylı | MIT |
| `image_picker` | 1.2.4 | doğrudan | BSD-3-Clause, Apache-2.0 |
| `image_picker_android` | 0.8.13+25 | dolaylı | BSD-3-Clause, Apache-2.0 |
| `image_picker_for_web` | 3.1.1 | dolaylı | BSD-3-Clause |
| `image_picker_ios` | 0.8.13+15 | dolaylı | BSD-3-Clause, Apache-2.0 |
| `image_picker_linux` | 0.2.2 | dolaylı | BSD-3-Clause |
| `image_picker_macos` | 0.2.2+1 | dolaylı | BSD-3-Clause |
| `image_picker_platform_interface` | 2.11.2 | dolaylı | BSD-3-Clause |
| `image_picker_windows` | 0.2.2 | dolaylı | BSD-3-Clause |
| `intl` | 0.20.3 | doğrudan | BSD-3-Clause |
| `jni` | 1.1.2 | dolaylı | BSD-3-Clause |
| `jni_flutter` | 1.0.4+1 | dolaylı | BSD-3-Clause |
| `jni_util` | 1.0.0 | dolaylı | BSD-3-Clause |
| `json_annotation` | 4.12.0 | dolaylı | BSD-3-Clause |
| `leak_tracker` | 11.0.2 | dolaylı | BSD-3-Clause |
| `leak_tracker_flutter_testing` | 3.0.10 | dolaylı | BSD-3-Clause |
| `leak_tracker_testing` | 3.0.2 | dolaylı | BSD-3-Clause |
| `listen` | 1.0.1 | dolaylı | BSD-3-Clause |
| `logging` | 1.3.0 | dolaylı | BSD-3-Clause |
| `matcher` | 0.12.20 | dolaylı | BSD-3-Clause |
| `material_color_utilities` | 0.13.0 | dolaylı | Apache-2.0 |
| `material_ui` | 1.10.0 | dolaylı | BSD-3-Clause |
| `meta` | 1.19.0 | dolaylı | BSD-3-Clause |
| `mime` | 2.1.0 | dolaylı | BSD-3-Clause |
| `native_toolchain_c` | 0.19.6 | dolaylı | BSD-3-Clause |
| `objective_c` | 9.6.3 | dolaylı | BSD-3-Clause |
| `package_config` | 3.0.0 | dolaylı | BSD-3-Clause |
| `path` | 1.9.1 | dolaylı | BSD-3-Clause |
| `path_provider` | 2.1.6 | doğrudan | BSD-3-Clause |
| `path_provider_android` | 2.3.1 | dolaylı | BSD-3-Clause |
| `path_provider_foundation` | 2.6.0 | dolaylı | BSD-3-Clause |
| `path_provider_linux` | 2.2.2 | dolaylı | BSD-3-Clause |
| `path_provider_platform_interface` | 2.1.3 | dolaylı | BSD-3-Clause |
| `path_provider_windows` | 2.3.0 | dolaylı | BSD-3-Clause |
| `platform` | 3.2.0 | dolaylı | BSD-3-Clause |
| `plugin_platform_interface` | 2.1.8 | dolaylı | BSD-3-Clause |
| `posix` | 6.5.4 | dolaylı | MIT |
| `process` | 5.0.6 | dolaylı | BSD-3-Clause |
| `pub_semver` | 2.2.1 | dolaylı | BSD-3-Clause |
| `record_use` | 1.1.1 | dolaylı | BSD-3-Clause |
| `riverpod` | 3.5.0 | dolaylı | MIT |
| `sky_engine` | 0.0.0 | dolaylı | BSD-3-Clause (Flutter SDK) |
| `sodium` | 4.1.2+1 | doğrudan | BSD-3-Clause, ISC |
| `source_span` | 1.10.2 | dolaylı | BSD-3-Clause |
| `sqlite3` | 3.9.1 | doğrudan | MIT |
| `stack_trace` | 1.12.2 | dolaylı | BSD-3-Clause |
| `state_notifier` | 1.0.0 | dolaylı | MIT |
| `stream_channel` | 2.1.4 | dolaylı | BSD-3-Clause |
| `stream_transform` | 2.1.2 | dolaylı | BSD-3-Clause |
| `string_scanner` | 1.4.1 | dolaylı | BSD-3-Clause |
| `term_glyph` | 1.2.2 | dolaylı | BSD-3-Clause |
| `test_api` | 0.7.12 | dolaylı | BSD-3-Clause |
| `typed_data` | 1.4.0 | dolaylı | BSD-3-Clause |
| `uuid` | 4.6.0 | dolaylı | MIT |
| `vector_math` | 2.4.4 | dolaylı | BSD-3-Clause |
| `vm_service` | 15.4.0 | dolaylı | BSD-3-Clause |
| `web` | 1.1.2 | dolaylı | BSD-3-Clause |
| `xdg_directories` | 1.1.0 | dolaylı | BSD-3-Clause |
| `yaml` | 3.1.4 | dolaylı | MIT |

## Android (Gradle) bağımlılıkları

Sürüm derlemesinin `releaseRuntimeClasspath` yapılandırmasındaki kütüphaneler (`./gradlew :app:dependencies --configuration releaseRuntimeClasspath`). Flutter motoru dışında hepsi Apache-2.0. R8, kullanılmayan kodlarını yayın APK'sından atar.

| Kütüphane | Sürüm | Getiren | Neden |
|---|---|---|---|
| `androidx.biometric:biometric` | 1.1.0 | KeyKey | Parmak iziyle açma (`BiometricPrompt`, `CryptoObject`) |
| `androidx.autofill:autofill` | 1.3.0 | KeyKey | Otomatik doldurmanın klavye şeridindeki öneri görünümü |
| `org.jetbrains.kotlinx:kotlinx-coroutines-android` | 1.11.0 | KeyKey | Pigeon köprüsünün eşzamansız çağrıları |
| `org.jetbrains.kotlin:kotlin-stdlib` | 2.4.21 | KeyKey | Kotlin |
| `io.flutter:*` | motor `89c39edf` | Flutter | Flutter motoru (BSD-3-Clause) |
| CameraX (`androidx.camera:*`) | 1.6.2 | `camera_android_camerax` | Kamera |
| `androidx.media3:*`, Guava (33.8.0'a zorlanıyor, [Bilinen açıklar](#bilinen-açıklar)), Dagger, ReLinker, `javax.inject`, `jakarta.inject`, atomicfu | | `camera_android_camerax` | CameraX'in kendi bağımlılıkları. Video kaydı kısmı kullanılmıyor, R8 atar |
| `androidx.exifinterface` | 1.4.2 | `image_picker_android`, CameraX | Görselin yönü |
| `androidx.fragment`, `appcompat`, `activity`, `lifecycle`, `core` ve diğer AndroidX | | biometric, eklentiler | Ortak Android altyapısı |
| JSpecify, Error Prone, J2ObjC, AutoValue ve JetBrains notasyonları | | çeşitli | Yalnızca derleme notasyonları |

Testlerde kullanılan `junit` (EPL-1.0) uygulamaya girmez.

## Yerel kütüphaneler

| Kütüphane | Lisans | Nereden |
|---|---|---|
| libsodium 1.0.22 | ISC | `sodium` paketinin içindeki kaynak arşivinden, derleme sırasında NDK ile derlenir |
| SQLite (`libsqlite3.so`) | Kamu malı | `sqlite3` paketinin derleme kancası hazır kütüphaneyi indirir |
| zxing-cpp, zint (`libflutter_zxing.so`) | Apache-2.0, BSD-3-Clause | `flutter_zxing` paketinin içindeki kaynaktan, CMake ile derlenir |
| Flutter motoru (`libflutter.so`) | BSD-3-Clause ve motorun üçüncü taraf lisansları | Flutter aracının indirdiği motor dosyaları |
| Dart kodu (`libapp.so`) | KeyKey ve paketler | Derlemenin kendisi |

## Derlemede indirilenler

Derleme şunları internetten alır. Her biri bir sürüme ya da özete sabit:

| Ne | Nereden | Doğrulama |
|---|---|---|
| Dart paketleri | pub.dev | `pubspec.lock`'taki SHA-256 özetleri; `pub` uyuşmayan paketi reddeder |
| SQLite hazır kütüphanesi | GitHub, `simolus3/sqlite3.dart` deposunun `sqlite3-3.9.1` sürümü | Paketin içindeki `asset_hashes.dart`'ta her dosyanın SHA-256 özeti sabit; uyuşmazsa derleme durur. CI'da bir kez geçici bir indirme hatasında bu denetim derlemeyi durdurdu, yeniden denemede geçti. |
| Flutter motoru ve Dart SDK'sı | Google'ın Flutter depolaması | Flutter sürümüne bağlı motor sürümü (`89c39edf`) |
| Gradle, Android eklentisi ve Gradle kütüphaneleri | Google Maven, Maven Central, Gradle | Gradle sarmalayıcısının ve kütüphanelerin sürümü sabit. Gradle'ın özet doğrulaması (`verification-metadata.xml`) açık değil; yeniden üretilebilir derlemeyle birlikte Faz 9'da ele alınacak. |

libsodium'un ve zxing-cpp'nin kaynağı derleme sırasında indirilmez, paketlerin içinde gelir. `flutter_zxing`'in CMake dosyalarında başka kütüphaneleri indirebilen bir yol (`FetchContent`) var. Ama KeyKey'in derlemesinde zint, paketin içindeki kaynaktan derleniyor ve hiçbir şey indirilmiyor.

## Lisanslar ekranı

Ayarlar'daki "Lisanslar" ekranı Flutter'ın `LicenseRegistry`'sini gösterir. Flutter, Dart paketlerinin `LICENSE` dosyalarını derlemede kendisi toplar (`NOTICES`). Yayın APK'sındaki `NOTICES` dosyası bu listeyle karşılaştırıldı:

- **Dart paketleri:** Hepsinin lisans metni var.
- **Yanlış başlık:** Üç eklentinin lisans metni kendi adının altında görünmüyor, çünkü `LICENSE` dosyaları Flutter'ın beklediği biçimde değil. `file_selector_android`'inki "Copyright 2013 The Flutter Authors" başlığı altında, `image_picker_android` ve `image_picker_ios`'unki `image_picker` altında. Metinler eksiksiz; sorun eklentilerin kendi dosyasında.
- **Elle eklenenler** ([`licenses.dart`](../../lib/app/licenses.dart)): EFF sözcük listesi, SecLists, Public Suffix List, zxing-cpp, zint, SQLite ve Android kütüphaneleri.
- **Eksikti, eklendi:**
  - Gradle'dan gelen Android kütüphaneleri hiç yoktu, çünkü Flutter yalnızca Dart paketlerini topluyor. Şimdi "Android libraries" başlığı altında, Apache-2.0 metniyle birlikte listeleniyor.
  - SQLite'ın kamu malı olduğunu belirten kayıt.

## Güncellik

Bu denetimde güncellenenler: `flutter_riverpod` 3.4.3 → 3.5.0, `sqlite3` 3.9.0 → 3.9.1, `pigeon` 29.1.0 → 29.1.1 (üretilen köprüde yalnızca sürüm satırı değişti), `androidx.autofill` 1.1.0 → 1.3.0, Guava 33.5.0 → 33.8.0 ve bunlarla gelen dolaylı paketler. Yerel kütüphanelerden libsodium (1.0.22) ve SQLite (3.54.1) son sürümde.

Bekleyenler:

| Paket | Kullanılan | Son | Neden bekliyor |
|---|---|---|---|
| `androidx.biometric` | 1.1.0 | 1.4.0-beta01 | 1.1.0'dan sonra kararlı sürüm yok; alfa ve beta sürümleri kullanılmıyor |
| `cross_file` | 0.3.5+5 | 0.4.0 | `file_selector` ve `image_picker` henüz 0.4'e izin vermiyor |
| `material_color_utilities`, `test_api` | 0.13.0, 0.7.12 | 0.13.1, 0.7.15 | Flutter SDK'sı bu sürümlere sabitliyor; Flutter güncellenince gelir |
| `built_collection` | 5.1.2 | 6.0.0 | Yalnızca kod üretim araçlarında; uygulamaya girmez |

## Bilinen açıklar

Bütün Dart paketleri (104) ve Gradle kütüphaneleri (84), sürümleriyle birlikte [OSV](https://osv.dev/) veritabanında sorgulandı (`api.osv.dev/v1/querybatch`, 2026-11-08).

- **Bulunan:** Guava 33.5.0'da [GHSA-xxph-c9ww-hj94](https://osv.dev/vulnerability/GHSA-xxph-c9ww-hj94) (yüksek). Bazı koleksiyonlar Java serileştirmesiyle okunurken saldırganın verdiği boyutta bellek ayırıyor ve uygulama çöküyor. Guava'yı KeyKey değil CameraX eklentisi getiriyor. KeyKey Java serileştirmesi (`ObjectInputStream`) kullanmadığı için açık tetiklenemez. Yine de `build.gradle.kts`'te düzeltilmiş 33.8.0 sürümü zorlandı.
- **Sonra:** Bulgu yok.
- **Sınır:** OSV yerel kütüphaneleri (libsodium, SQLite, zxing-cpp) paket olarak kapsamıyor. Bunların son sürümde olduğuna ayrıca bakıldı.

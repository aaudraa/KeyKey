# KeyKey Bağımlılıkları

Uygulamaya giren her paketin neden orada olduğu, sürümü, lisansı ve derlemede nereden geldiği. Faz 8'de ([#86](https://github.com/aaudraa/KeyKey/issues/86)) yazıldı. **Tarih:** 2026-11-08. **Lisans denetimi yenilendi:** 2026-11-17 ([aşağıda](#lisans-denetimi-2026-11-17)). **Flutter:** 3.47.9 (stable).

KeyKey GPL-3.0 ile yayımlanır. Bu yüzden içine giren her şeyin lisansı GPL-3.0 ile birlikte dağıtılabilir olmalı.

## Özet

| Konu | Sonuç |
|---|---|
| Lisans uyumu | Uyumlu. Kodların hepsi izin veren lisanslarla geliyor: BSD-2/3-Clause, MIT, Apache-2.0, ISC; SQLite kamu malı. GPL'li, LGPL'li ya da lisanssız paket yok. Apache-2.0 GPL-3.0 ile uyumlu (GPL-2.0 ile uyumlu olmazdı). |
| Veri dosyaları | Public Suffix List MPL-2.0; GPL ile birlikte dağıtılabilir, dosya değiştirilmeden gömülü. EFF sözcük listesi CC BY 3.0, atıf istiyor. SecLists parola listesi MIT. Üçü de kod değil, uygulamanın okuduğu veri. Atıfları Lisanslar ekranında. |
| Kullanılmayan paket | Yok. Doğrudan bağımlılıkların hepsi kodda kullanılıyor (aşağıdaki tablo). |
| Güncellik | Doğrudan bağımlılıkların hepsi son kararlı sürümde, biri hariç: `androidx.biometric`'in 1.1.0'dan yeni kararlı sürümü yok. Bekleyen dolaylı paketler ve nedenleri [Güncellik](#güncellik) bölümünde. |
| Derlemede indirilen | Uygulamaya giren hazır yerel kütüphane yok. SQLite, Faz 9'dan beri repodaki kaynaktan derleniyor (#99). Ayrıntı: [Derlemede indirilenler](#derlemede-indirilenler). |
| Lisanslar ekranı | Android kütüphaneleri ve SQLite eksikti, eklendi. Ayrıntı: [Lisanslar ekranı](#lisanslar-ekranı). |
| Ağ (1.6.0, 1.8.0) | Hiçbir bağımlılık ağa çıkmıyor. Ağ kodu KeyKey'in kendi iki dosyasında, Dart'ın `dart:io` `HttpClient`'ıyla: `lib/core/network/pwned_passwords_client.dart` (sızıntı kontrolü) ve 1.8.0'dan beri `lib/core/network/webdav_client.dart` (senkron). Senkron için yalnızca XML okuyucu `xml` eklendi (saf Dart). Başka yerde ağ kodu olmadığını `test/core/network/network_audit_test.dart` denetler. Pwned Passwords verisi uygulamaya gömülmez; atıfı (CC BY 4.0) parola raporunda. |
| Bilinen açıklar | Bir tane vardı (Guava), düzeltilmiş sürüme geçildi. Şu an bilinen açık yok. Ayrıntı: [Bilinen açıklar](#bilinen-açıklar). |

## Doğrudan Dart bağımlılıkları

| Paket | Sürüm | Lisans | Neden |
|---|---|---|---|
| `sodium` | 4.1.2+1 | BSD-3-Clause; içindeki libsodium 1.0.22 ISC | Bütün kriptografi: Argon2id, XChaCha20-Poly1305, rastgele sayı, korumalı bellek |
| `sqlite3` | 3.9.1 | MIT; SQLite kamu malı | Veritabanı motoru |
| `drift` | 2.35.4 | MIT | Veritabanı şeması, sorgular ve göçler |
| `crypto` | 3.0.8 | BSD-3-Clause | 2FA kodları için HMAC-SHA1/256/512; içe aktarmada anahtar türetme; sızıntı kontrolünde parolanın SHA-1 özeti; KeePass dosyalarında SHA-256, SHA-512 ve HMAC |
| `pointycastle` | 4.0.0 | MIT | KeePass dosyalarının şifre çözmesi: AES-256-CBC, Twofish, ChaCha20, Salsa20 (1.9.0). Saf Dart, yerel kod ve bağımlılık getirmiyor, ağa çıkmıyor. Yalnızca kullanıcının verdiği dosyayı açmak için; kasanın şifrelemesinde kullanılmaz. Ağır anahtar türetme bunda değil, telefonun yerel kodunda (aşağıda, Argon2) |
| `flutter_riverpod` | 3.5.0 | MIT | Uygulama durumunun yönetimi |
| `go_router` | 18.1.4 | BSD-3-Clause | Ekranlar arası geçiş |
| `intl` | 0.20.3 | BSD-3-Clause | Tarih ve sayı biçimleri, çeviriler (`flutter_localizations` ile) |
| `camera` | 0.12.2 | BSD-3-Clause | 2FA QR kodunu kamerayla okuma |
| `flutter_zxing` | 3.1.1 | MIT; içindeki zxing-cpp Apache-2.0, zint BSD-3-Clause | QR kodunu çözme |
| `image_picker` | 1.2.4 | BSD-3-Clause, Apache-2.0 | QR kodunu galerideki görselden okuma |
| `file_selector` | 1.1.0 | BSD-3-Clause | Yedek ve içe aktarma dosyası seçme, dışa aktarmayı kaydetme |
| `path_provider` | 2.1.6 | BSD-3-Clause | Kasa dosyasının uygulama klasöründeki yeri |
| `xml` | 7.1.0 | MIT; getirdiği `petitparser` 7.1.0 MIT | Senkronda WebDAV klasör listesinin (`PROPFIND` yanıtı) okunması (1.8.0); KeePass dosyalarının ve anahtar dosyalarının XML'i (1.9.0). Saf Dart, ağa çıkmaz, yerel kod yok |
| `flutter`, `flutter_localizations` | SDK | BSD-3-Clause | Arayüz çerçevesi |

Geliştirme bağımlılıkları uygulamaya girmez: `build_runner` ve `drift_dev` (drift kodu üretimi), `pigeon` (Dart-Kotlin köprüsünün üretimi), `very_good_analysis` (kod kuralları), `flutter_test` ve `integration_test`.

## Bütün Dart paketleri

Uygulamanın normal bağımlılıklarından ulaşılan 106 paket. Liste [`dart-lisanslari.mjs`](../scripts/dart-lisanslari.mjs) betiğiyle üretilir:

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
| `archive` | 4.7.1 | dolaylı | MIT |
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
| `cupertino_ui` | 1.1.7 | dolaylı | BSD-3-Clause |
| `drift` | 2.35.4 | doğrudan | MIT |
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
| `flutter_zxing` | 3.1.1 | doğrudan | MIT |
| `freezed_annotation` | 3.1.0 | dolaylı | MIT |
| `glob` | 2.2.0 | dolaylı | BSD-3-Clause |
| `go_router` | 18.1.4 | doğrudan | BSD-3-Clause |
| `hooks` | 2.2.0 | dolaylı | BSD-3-Clause |
| `html` | 0.15.7 | dolaylı | MIT |
| `http` | 1.6.0 | dolaylı | BSD-3-Clause |
| `http_parser` | 4.1.2 | dolaylı | BSD-3-Clause |
| `image` | 4.13.1 | dolaylı | MIT |
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
| `material_ui` | 1.11.1 | dolaylı | BSD-3-Clause |
| `meta` | 1.19.0 | dolaylı | BSD-3-Clause |
| `mime` | 2.1.0 | dolaylı | BSD-3-Clause |
| `native_toolchain_c` | 0.19.6 | dolaylı | BSD-3-Clause |
| `objective_c` | 9.6.4 | dolaylı | BSD-3-Clause |
| `package_config` | 3.0.0 | dolaylı | BSD-3-Clause |
| `path` | 1.9.1 | dolaylı | BSD-3-Clause |
| `path_provider` | 2.1.6 | doğrudan | BSD-3-Clause |
| `path_provider_android` | 2.3.1 | dolaylı | BSD-3-Clause |
| `path_provider_foundation` | 2.6.0 | dolaylı | BSD-3-Clause |
| `path_provider_linux` | 2.2.2 | dolaylı | BSD-3-Clause |
| `path_provider_platform_interface` | 2.1.3 | dolaylı | BSD-3-Clause |
| `path_provider_windows` | 2.3.0 | dolaylı | BSD-3-Clause |
| `petitparser` | 7.1.0 | dolaylı | MIT |
| `platform` | 3.2.0 | dolaylı | BSD-3-Clause |
| `plugin_platform_interface` | 2.1.8 | dolaylı | BSD-3-Clause |
| `pointycastle` | 4.0.0 | doğrudan | MIT |
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
| `xml` | 7.1.0 | doğrudan | MIT |
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
| SQLite 3.54.1 (`libsqlite3.so`) | Kamu malı | Repodaki kaynaktan ([`android/third_party/sqlite`](../../android/third_party/sqlite/README.md)), `sqlite3` paketinin derleme kancasıyla NDK ile derlenir |
| zxing-cpp, zint (`libflutter_zxing.so`) | Apache-2.0, BSD-3-Clause | `flutter_zxing` paketinin içindeki kaynaktan, CMake ile derlenir |
| Argon2 başvuru uygulaması `20190702` (`libkeykey_argon2.so`, 1.9.0) | CC0 1.0 ya da Apache-2.0 | Repodaki kaynaktan ([`android/third_party/argon2`](../../android/third_party/argon2/README.md), değiştirilmeden), uygulama modülünün CMake'iyle NDK ile derlenir. KeePass dosyalarının Argon2d/Argon2id'si; küçük bir JNI dosyası (`android/app/src/main/cpp/argon2_jni.c`) Kotlin'e bağlar |
| Flutter motoru (`libflutter.so`) | BSD-3-Clause ve motorun üçüncü taraf lisansları | Flutter aracının indirdiği motor dosyaları |
| Dart kodu (`libapp.so`) | KeyKey ve paketler | Derlemenin kendisi |

## Derlemede indirilenler

Derleme şunları internetten alır. Her biri bir sürüme ya da özete sabit:

| Ne | Nereden | Doğrulama |
|---|---|---|
| Dart paketleri | pub.dev | `pubspec.lock`'taki SHA-256 özetleri; `pub` uyuşmayan paketi reddeder |
| SQLite hazır kütüphanesi (yalnızca bilgisayardaki testler) | GitHub, `simolus3/sqlite3.dart` deposunun `sqlite3-3.9.1` sürümü | Paketin içindeki `asset_hashes.dart`'ta her dosyanın SHA-256 özeti sabit; uyuşmazsa derleme durur. Uygulamaya girmez: Android derlemesi SQLite'ı repodaki kaynaktan derler. Kaynağın kendisi sqlite.org'un yayımladığı SHA3-256 özetiyle doğrulandı; `bash resources/scripts/sqlite-guncelle.sh --denetle` bunu yeniden yapar. |
| Flutter motoru ve Dart SDK'sı | Google'ın Flutter depolaması | Flutter sürümüne bağlı motor sürümü (`89c39edf`) |
| Gradle, Android eklentisi ve Gradle kütüphaneleri | Google Maven, Maven Central, Gradle | Gradle sarmalayıcısının ve kütüphanelerin sürümü sabit. Gradle'ın özet doğrulaması (`verification-metadata.xml`) açık değil; yeniden üretilebilir derlemeyle birlikte Faz 9'da ele alınacak. |

Yayın derlemesi F-Droid'in derleme imajında (`registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie`) yapılır ve imaj **özetiyle sabittir** (`yayin.yml` ve `f-droid.yml`, güncellemesi [yayın belgesinde](yayin.md#derleme-imajını-güncellemek)). Android SDK ve NDK r28c (`28.2.13676358`) imajdan gelir; OpenJDK 21, `make` ve `sudo` derleme sırasında Debian'ın deposundan kurulur, bu yüzden imaj özeti onları sabitlemez (Debian paketleri imzalıdır, sürümleri trixie'nin güvenlik güncellemeleriyle değişebilir). Karşılaştırma işi F-Droid'in `fdroidserver` aracını (fdroiddata CI'ı gibi ana dalın güncel hali) ve `apksigcopier`'ı da kullanır ve F-Droid derlemesini imajın **güncel haliyle** yapar: F-Droid'in ortamı bizimkinden ayrılırsa karşılaştırma kırmızı olur. Bunlar yalnızca CI'da çalışır, uygulamaya girmez ([F-Droid tasarımı](f-droid.md)).

libsodium'un ve zxing-cpp'nin kaynağı derleme sırasında indirilmez, paketlerin içinde gelir. Argon2'nin kaynağı repoda. `flutter_zxing`'in CMake dosyalarında başka kütüphaneleri indirebilen bir yol (`FetchContent`) var. Ama KeyKey'in derlemesinde zint, paketin içindeki kaynaktan derleniyor ve hiçbir şey indirilmiyor.

## Lisanslar ekranı

Ayarlar → Hakkında → Lisanslar, Flutter'ın `LicenseRegistry`'sindeki bütün metinleri gösterir, ama Flutter'ın hazır sayfasıyla değil (2026-11-17'den beri). Hazır sayfa yaklaşık 200 adı tek listede gösteriyordu: geliştirme araçları (`analyzer`, `build_runner`; Flutter `package_config`'teki her paketi topluyor), Flutter motorunun üçüncü taraf parçaları ve bozuk başlıklar. Proje sahibi "çok karışık" dedi.

Yeni ekran ([`licenses_screen.dart`](../../lib/features/settings/presentation/licenses_screen.dart)) üç bölümden oluşur:

1. **KeyKey:** GPL-3.0, özgürlükler, "hiçbir garanti olmadan" ve telif satırı (© 2026 KeyKey geliştiricileri); lisansın tam metni.
2. **KeyKey'in kullandıkları:** libsodium, SQLite, Flutter, zxing-cpp ve zint, kamera eklentisi, Barlow Condensed, EFF sözcük listesi, SecLists, Public Suffix List, Argon2 ve `pointycastle` (KeePass dosyaları, 1.9.0) ve Android kütüphaneleri; her biri ne işe yaradığı ve lisans türüyle.
3. **Bütün paketler:** baş harflerine göre gruplanmış tam liste; her metin eksiksiz.

Lisans türü metinden tanınır ([`license_catalog.dart`](../../lib/features/settings/data/license_catalog.dart)); yol göstermek içindir, metnin kendisi esastır. Başka lisansları anan metinler (OFL'deki MIT cümlesi, GPL'nin sonundaki LGPL, MPL'deki ikincil lisanslar) doğru tanınır; APK'daki 204 girdiyle denendi. Tanınan bir lisansın yanında "diğer" gösterilmez: motorun tanınmayan metinleri çoğunlukla lisans gövdesi olmayan telif satırlarıdır.

- **Bozuk başlıklar:** Bazı eklentilerin `LICENSE` dosyası Flutter'ın beklediği biçimde olmadığı için metin bir satır parçasının ("-", "Copyright 2013 The Flutter Authors") altında görünüyordu (ör. `file_selector_android`). Bu metinler "Adı belirtilmemiş metinler" başlığında toplanır, kaybolmaz.
- **Elle eklenenler** ([`licenses.dart`](../../lib/app/licenses.dart)): EFF sözcük listesi, SecLists, Barlow Condensed yazı tipi (SIL OFL 1.1), Public Suffix List, zxing-cpp, zint, SQLite, Argon2 (1.9.0) ve Android kütüphaneleri (Flutter yalnızca Dart paketlerini topluyor).

## Lisans denetimi (2026-11-17)

Proje sahibi "sonra dava yemeyelim" diye lisanslara yeniden bakılmasını istedi. Yapılanlar:

| Konu | Sonuç |
|---|---|
| Dart paketleri | Uygulamaya giren 139 paketin lisans dosyası yeniden sınıflandırıldı: 106 BSD, 16 MIT, 4 Apache-2.0, 4 Apache-2.0 ve BSD, 1 BSD ve ISC (`sodium`, içindeki libsodium), 8 SDK. GPL, LGPL, AGPL ya da lisanssız paket yok. |
| Android kütüphaneleri | `releaseRuntimeClasspath` yeniden listelendi; hepsi "Android libraries" kaydının kapsadığı Apache-2.0 kütüphaneleri (AndroidX, CameraX, Kotlin, Guava, Dagger, ReLinker ve notasyonlar). Yeni ya da eksik grup yok. |
| APK'daki `NOTICES` | libsodium'un ISC metni var. Tek GPL metni KeyKey'in kendisi. |
| Veri ve yazı tipi | EFF (CC BY 3.0, atıf var), SecLists (MIT), Public Suffix List (MPL-2.0, değiştirilmeden), Barlow Condensed (OFL 1.1, yazı tipiyle birlikte dağıtılabilir) ekranda. |
| KeyKey'in kendi bildirimi | **Eksikti, eklendi.** Telif satırı ve "garanti yoktur" bildirimi hiçbir yerde yoktu. GPL-3.0 etkileşimli programların bunu göstermesini öneriyor; şimdi Lisanslar ekranında, kullanım koşullarında ve README'de. |
| Kullanım koşulları | **Eklendi** ([kosullar.md](kosullar.md)): verilerin nerede durduğu, nasıl korunduğu, kullanıcının sorumlulukları, yapay zekâ ile yazıldığı, bağımsız denetimden geçmediği ve garanti olmadığı; ilk açılışta onay. |
| Ad | Aramada kayıtlı bir "KeyKey" markası çıkmadı. Mac için aynı adlı, ücretli bir klavye eğitimi uygulaması var (başka bir ürün türü). Kesin sonuç için TÜRKPATENT'te ve hedef ülkelerin marka kayıtlarında arama gerekir; bu bir hukuk danışmanlığı değildir. |

**Sınır:** Bu bir hukuki görüş değil. Garanti ve sorumluluk reddi "yürürlükteki hukukun izin verdiği ölçüde" geçerlidir; örneğin Türk Borçlar Kanunu (m. 115) ağır kusur ve kast için önceden sorumsuzluk anlaşmasını geçersiz sayar. KeyKey ücretsiz ve ticari olmayan bir açık kaynak proje; ücretli sürüm, bağış karşılığı hizmet ya da şirket kurulursa bir hukukçuya danışılmalı.

## Güncellik

Bu denetimde güncellenenler: `flutter_riverpod` 3.4.3 → 3.5.0, `sqlite3` 3.9.0 → 3.9.1, `pigeon` 29.1.0 → 29.1.1 (üretilen köprüde yalnızca sürüm satırı değişti), `androidx.autofill` 1.1.0 → 1.3.0, Guava 33.5.0 → 33.8.0 ve bunlarla gelen dolaylı paketler. Yerel kütüphanelerden libsodium (1.0.22) ve SQLite (3.54.1) son sürümde.

1.0'dan sonraki bakımda (2026-11-16) güncellenenler: `drift` 2.35.3 → 2.35.4, `go_router` 18.1.3 → 18.1.4, `flutter_zxing` 3.1.0 → 3.1.1, `pigeon` 29.1.1 → 29.2.0 (üretilen Kotlin köprüsünde enum değeri artık sıra numarasıyla bulunuyor; KeyKey'in üç enum'unda değerler sıra numarasıyla aynı) ve bunlarla gelen dolaylı paketler; Gradle 9.8.2 → 9.9.0, Android eklentisi 9.5.0 → 9.5.1, `actions/setup-java` 6.1.0 → 6.2.0.

2026-11-18'deki bakımda `pigeon` 29.2.0 → 30.0.4 güncellendi. Büyük sürümün kıran değişikliği yalnızca "Native Interop" kaydını etkiliyor; KeyKey'in köprüsü klasik kanallarla çalıştığı için etkilenmiyor. Yeniden üretilen köprüde yalnızca sürüm satırı değişti. Fark: `pigeon` 30 ürettiği Dart dosyasını artık kendisi biçimlendirmiyor, bu yüzden köprü `dart run pigeon --input pigeons/platform_api.dart` ve ardından `dart format lib/core/platform/platform_api.g.dart` ile üretilir; yoksa CI'daki biçim kontrolü takılır.

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

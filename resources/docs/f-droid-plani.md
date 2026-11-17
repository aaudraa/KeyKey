# F-Droid ve Obtainium uygulama planı

> **Uygulayan için:** superpowers:executing-plans ya da superpowers:subagent-driven-development ile görev görev yürütülür. Adımlar `- [ ]` kutularıyla izlenir.

**Amaç:** KeyKey'i F-Droid ana deposuna bizim imzamızla (birebir aynı derleme) başvurmaya hazır hale getirmek, 1.0.1'i bu düzenle yayımlamak ve README'ye Obtainium bağlantısı koymak.

**Mimari:** Yayın APK'sı F-Droid'in derleme yollarında derlenir. F-Droid'in kendi `fdroidserver` imajı aynı commit'i bizim tarif dosyamızla derler; `apksigcopier` bizim imzamızı onun imzasız APK'sına kopyalayıp doğrular. Bu karşılaştırma hem elle/PR'da çalışan bir deneme iş akışında (tek kullanımlık anahtarla) hem de yayın iş akışında (gerçek APK'yla, taslak yayımlanmadan önce) yapılır.

**Araçlar:** GitHub Actions, Flutter 3.47.9, fdroidserver, apksigcopier, Python 3 (PIL yerelde), Fastlane klasör düzeni.

**Tasarım:** [f-droid.md](f-droid.md)

## Genel kısıtlar

- Uygulama kimliği `io.github.aaudraa.keykey`; yayın sertifikası SHA-256 `66ff7b5c0c009a8530d0a55dd1d80a3af35de48bd0667c456a0cf86a6d1129a0`.
- Tek evrensel APK; işlemci türüne göre bölme yok.
- Derleme yolu `/home/vagrant/build/io.github.aaudraa.keykey`, Flutter `/home/vagrant/build/srclib/flutter` (etiket 3.47.9), `PUB_CACHE=<proje>/.pub-cache`.
- Yayın varlık adı `keykey-<sürüm>.apk` değişmez; tarifte `Binaries: https://github.com/aaudraa/KeyKey/releases/download/v%v/keykey-%v.apk`.
- F-Droid'e giren ilk sürüm `1.0.1+4`.
- Gerçek yayın anahtarı yalnızca `yayin` ortamında ve yalnızca `v*` etiketinde kullanılır; deneme derlemeleri tek kullanımlık anahtarla imzalanır.
- F-Droid'in kendi imzasıyla ikinci bir KeyKey'e gidilmez; birebir aynılık tutmazsa durulur, kullanıcıya sorulur.
- Kısa açıklama ≤ 80 karakter, uzun açıklama ≤ 4000 karakter, her changelog ≤ 500 bayt; simge 512×512 PNG; ekran görüntüleri PNG.
- Açıklamalar ve başvuru metni kodun büyük kısmının bir yapay zekâ asistanıyla yazıldığını söyler.
- `INTERNET` izni yok; uygulama kodu (`lib/`, `android/app/src`) bu fazda değişmez.
- Commit/issue/belge Türkçe; F-Droid başvuru metni ve `en-US` açıklamaları İngilizce.

## Gözden geçirmede dikkat

1. **Deneme ya da ön sürüm etiketleri** (`v1.0.1-deneme.1`, `v1.1.0-rc.1`) F-Droid'in güncelleme denetimine takılmamalı → Görev 3'teki denetim, tarifteki etiket desenini bu örneklerle sınar.
2. **Yeni sürümde changelog unutulması** → Görev 3'teki denetim, `pubspec.yaml`'daki versionCode için iki dilde de changelog yoksa CI'ı kırar.
3. **Varlık adı ya da sürüm biçimi değişirse** `Binaries` adresi kırılır → Görev 3'teki denetim `yayin.yml`'daki `keykey-${VERSION}.apk` ile tarifteki `Binaries` desenini karşılaştırır.
4. **Bağımlılık güncellemesi (Dependabot) birebir aynılığı sessizce bozar** → Görev 4'teki deneme iş akışı `pubspec.lock`, `android/**` ve iş akışı dosyalarına dokunan PR'larda da çalışır.
5. **Yerel deneme APK'ları imzasız kalabilir** → F-Droid'deki imzasızlık yalnızca tarifteki `prebuild` adımıyla yapılır, `build.gradle.kts` değişmez; Görev 4'te yerel `flutter build apk --release` çıktısının hâlâ hata ayıklama anahtarıyla imzalı olduğu görülür.

---

### Görev 1: Faz kayıtları

**Dosyalar:**
- Değiştir: `resources/yol-haritasi.md` (Durum tablosu, Faz 9'dan sonra "Faz 10 — F-Droid" bölümü, "1.0 sonrası"ndaki IzzyOnDroid ve F-Droid satırları)

- [ ] **Adım 1:** Durum tablosuna `| 10 | F-Droid ve Obtainium | M | 9 | faz/10-f-droid | Sürüyor |` satırı; Faz 10 bölümü (amaç, tasarım/plan bağlantıları, bu plandaki görevlerin kutulu listesi).
- [ ] **Adım 2:** "1.0 sonrası" tablosunda IzzyOnDroid satırı: "Başvurulmuyor (2026-11-17): yapay zekâ politikası ve 30 MB sınırı, bkz. [f-droid.md](docs/f-droid.md#izzyondroid-neden-yok)". F-Droid satırı "Faz 10'da" olarak güncellenir.
- [ ] **Adım 3:** GitHub: `Faz 10 — F-Droid` milestone'u; issue'lar (etiketler mevcut olanlardan): Obtainium bağlantısı, Fastlane açıklamaları, F-Droid tarifi ve doğrulama iş akışı, yayın iş akışında F-Droid karşılaştırması, 1.0.1 yayını, F-Droid başvurusu. Issue numaraları yol haritasındaki kutulara yazılır.
- [ ] **Adım 4:** Commit `belge(yol-haritası): Faz 10 F-Droid başlıyor`, push.

### Görev 2: Obtainium bağlantısı

**Dosyalar:**
- Değiştir: `README.md` (8. satırdaki yayın kutusu), `resources/docs/kullanim.md:27`

- [ ] **Adım 1:** Bağlantıyı Python'la üret ve geri çözerek denetle:
  `https://apps.obtainium.imranr.dev/redirect?r=obtainium://app/` + `urllib.parse.quote(json.dumps({"id":"io.github.aaudraa.keykey","url":"https://github.com/aaudraa/KeyKey","author":"aaudraa","name":"KeyKey"}, separators=(",",":")), safe="")`. Çözülen JSON'un dört alanı birebir bu değerler olmalı.
- [ ] **Adım 2:** README'deki yayın kutusuna "… [son sürümü indir](…) ya da [Obtainium'a ekle](<bağlantı>), yeni sürümler kendiliğinden gelsin." Düz metin, rozet yok.
- [ ] **Adım 3:** `kullanim.md:27`'deki paragrafa aynı bağlantı ("tek dokunuşla eklemek için").
- [ ] **Adım 4:** Commit `belge(dağıtım): README'ye Obtainium bağlantısı (#<issue>)`, push. Issue, Görev 8'deki telefon denemesinden sonra kapanır.

### Görev 3: Fastlane açıklamaları ve denetimi

**Dosyalar:**
- Oluştur: `fastlane/metadata/android/en-US/{title.txt,short_description.txt,full_description.txt,changelogs/3.txt,images/icon.png,images/phoneScreenshots/*.png}`, aynısı `tr-TR/` altında
- Oluştur: `resources/scripts/check-fastlane.py`
- Oluştur: `resources/f-droid/io.github.aaudraa.keykey.yml` (Görev 4'te doldurulur; burada en az `Binaries`, `UpdateCheckMode`, `UpdateCheckData` satırlarıyla)
- Değiştir: `.github/workflows/ci.yml` (kalite işine adım)

**Arayüzler:**
- Üretir: `python3 resources/scripts/check-fastlane.py` → hata yoksa çıkış 0, her hata için `HATA: <dosya>: <neden>` ve çıkış 1. Görev 7 ve sonraki sürümler buna dayanır.

- [ ] **Adım 1: Denetim betiği.** `check-fastlane.py` şunları denetler:
  - `en-US` ve `tr-TR` var; her birinde `title.txt` (≤ 30 karakter), `short_description.txt` (1–80 karakter), `full_description.txt` (1–4000 karakter), `images/icon.png` (PNG, 512×512), `images/phoneScreenshots/` içinde en az 4 PNG/JPG.
  - Her `changelogs/*.txt` ≤ 500 bayt; `pubspec.yaml`'daki `version: x.y.z+N` için iki dilde de `changelogs/N.txt` var.
  - `yayin.yml` APK'yı `keykey-${VERSION}.apk` adıyla kopyalıyor ve tarifteki `Binaries` satırı `.../releases/download/v%v/keykey-%v.apk`.
  - Tarifteki `UpdateCheckMode: Tags <desen>` deseni `v1.0.1`, `v12.3.4` ile eşleşiyor; `v1.0.1-deneme.1`, `v1.1.0-rc.1`, `deneme-siyah-beyaz-1` ile eşleşmiyor.
  PIL kullanmaz (CI'da yok): PNG boyutu IHDR'den okunur. YAML için kütüphane yok; satırlar düzenli ifadeyle okunur.
- [ ] **Adım 2: Kırmızıyı gör.** Klasörler boşken betik çalışır; eksik dosyaların hepsi `HATA:` satırı olarak listelenir, çıkış 1.
- [ ] **Adım 3: Metinler.** `en-US` İngilizce, `tr-TR` Türkçe. Uzun açıklama: ne olduğu (çevrimdışı parola yöneticisi + 2FA), `INTERNET` izni yok, otomatik doldurma, şifreli yedek, içe aktarma (Bitwarden, KeePass/KeePassXC CSV, Aegis, 2FAS, Google Authenticator… — liste `kullanim.md`'den alınır, uydurulmaz), açık kaynak GPL-3.0, sonda: "Much of KeyKey's code was written with an AI coding assistant. The project went through its own security review but has not been independently audited. Keep encrypted backups." (Türkçesi tr-TR'de). `changelogs/3.txt`: 1.0.0'ın kısa özeti (CHANGELOG'dan).
- [ ] **Adım 4: Görseller.** `icon.png`: `resources/design/keykey-simge.svg` headless Edge ile 512×512 PNG'ye (gerekirse `--virtual-time-budget`), PIL ile boyut denetlenir. Ekran görüntüleri: `resources/design/kilavuz/` içinden `03-kilit-ekrani, 04-kasa-listesi, 05-kayit-ayrintisi, 08-parola-uretici, 09-2fa-kodlari, 13-ayarlar-doldurma, 15-koyu-tema` PIL ile `1.png`…`7.png`; aynı dosyalar iki dilde.
- [ ] **Adım 5: Tarif iskeleti.** `resources/f-droid/io.github.aaudraa.keykey.yml` içine şimdilik `Binaries` ve `UpdateCheckMode: Tags ^v[0-9]+\.[0-9]+\.[0-9]+$` ve `UpdateCheckData: pubspec.yaml|version:\s.+\+(\d+)|.|version:\s(.+)\+`.
- [ ] **Adım 6: Yeşili gör.** Betik çıkış 0. Sonra `title.txt`'yi geçici olarak 31 karaktere uzat → `HATA` ve çıkış 1 → geri al.
- [ ] **Adım 7: CI.** `ci.yml` kalite işine `- name: Mağaza açıklamaları` / `run: python3 resources/scripts/check-fastlane.py`.
- [ ] **Adım 8:** Commit `altyapı(dağıtım): F-Droid için Fastlane açıklamaları ve denetimi`, push; CI'daki adım yeşil.

### Görev 4: F-Droid tarifi ve deneme iş akışı

Bu görev keşif içerir: ilk çalıştırmalar büyük ihtimalle kırmızı olacak. Her deneme bir commit + push, sonuç ve neden `resources/docs/yayin.md`'deki yeniden üretilebilir derleme bölümüne bir satır olarak yazılır.

**Dosyalar:**
- Oluştur: `resources/scripts/f-droid-yolunda-derle.sh` — bizim derlememiz
- Oluştur: `resources/scripts/f-droid-karsilastir.sh` — F-Droid derlemesi + karşılaştırma
- Oluştur: `.github/workflows/f-droid.yml`
- Doldur: `resources/f-droid/io.github.aaudraa.keykey.yml`

**Arayüzler:**
- Üretir: `f-droid-yolunda-derle.sh` — kaynağı `/home/vagrant/build/io.github.aaudraa.keykey`'e kopyalar, Flutter 3.47.9'u `/home/vagrant/build/srclib/flutter`'a klonlar, `PUB_CACHE`'i proje içine ayarlar, `flutter build apk --release` çalıştırır, APK'yı `$1` yoluna kopyalar. İmza `KEYKEY_KEYSTORE`/`KEYKEY_*` ortam değişkenlerinden (bugünkü Gradle yolu). Görev 5'te yayın iş akışı da bunu çağırır.
- Üretir: `f-droid-karsilastir.sh <imzalı-apk> <commit>` — tarifi kopyalayıp son derleme bloğunun `commit`, `versionName`, `versionCode` alanlarını o commit'teki `pubspec.yaml`'dan doldurur, `fdroid build` çalıştırır, `apksigcopier compare <imzalı-apk> --unsigned <fdroid-imzasız-apk>` yapar. Tutmazsa `unzip -v` CRC farklarını listeler ve çıkış 1. Görev 5 bunu çağırır.

- [ ] **Adım 1: İmajı tanı.** F-Droid'in resmî derleme imajının adını fdroiddata'nın `.gitlab-ci.yml`'ından al (beklenen: `registry.gitlab.com/fdroid/fdroidserver:buildserver…`). İmajın içindeki JDK, Android SDK yolu, `apksigcopier` varlığı ve `fdroid build`'in proje/srclib yolları not edilir; `flutter` srclib tanımı (`srclibs/flutter.yml`) fdroiddata'dan alınır.
- [ ] **Adım 2: Tarif.** Tasarımın 5. maddesindeki alanlar; derleme bloğu: `srclibs: [flutter@3.47.9]`, `rm: [ios, linux, macos, web, windows]` (var olanlar), `prebuild`: `export PUB_CACHE=$(pwd)/.pub-cache`, `$$flutter$$/bin/flutter config --no-analytics`, `$$flutter$$/bin/flutter pub get --enforce-lockfile`, `sed -i -e '/signingConfig = /d' android/app/build.gradle.kts`; `scandelete: [.pub-cache]`; `build`: `$$flutter$$/bin/flutter build apk --release`; `output: build/app/outputs/flutter-apk/app-release.apk`; gerekiyorsa `ndk:` Flutter'ın `ndkVersion`'u. `AllowedAPKSigningKeys` ve `Binaries` tasarımdaki değerler.
- [ ] **Adım 3: İş akışı.** `f-droid.yml`: tetikleyiciler `workflow_dispatch`, `pull_request` (main'e; yollar `pubspec.lock`, `pubspec.yaml`, `android/**`, `.github/workflows/**`, `resources/f-droid/**`, `resources/scripts/f-droid-*`), ve faz boyunca geçici `push: branches: [faz/10-f-droid]`. İşler: `bizim` (ubuntu-24.04; `keytool -genkeypair` ile tek kullanımlık anahtar, `f-droid-yolunda-derle.sh`, APK'yı artifact olarak yükle), `f-droid` (imajın içinde F-Droid derlemesi, imzasız APK'yı yükle), `karsilastir` (ikisini indir, `apksigcopier compare`). İzinler `contents: read`; gizli değer kullanılmaz.
- [ ] **Adım 4: Döngü.** Push → sonuç. Kırmızıysa farklı dosyalara göre: yol (`libapp.so`, `libdartjni.so`) → yol/PUB_CACHE; `classes*.dex` → JDK farkı, `bizim` işini de F-Droid imajında çalıştır; `.so` genel → NDK sürümü; tarayıcı hatası → nedeni yazılı `scanignore`/`scandelete`. Üç denemede ilerleme yoksa dur, bulguyu kullanıcıya yaz.
- [ ] **Adım 5: Yeşil.** `karsilastir` işi yeşil ve günlükte F-Droid'in APK'sının `/home/vagrant/build/io.github.aaudraa.keykey`'de derlendiği görülüyor. `fdroid lint io.github.aaudraa.keykey` ve `fdroid rewritemeta` tarifte değişiklik önermiyor (önerirse uygulanır).
- [ ] **Adım 6: Yerel imza değişmedi.** Yerelde `flutter build apk --release` → `apksigner verify --print-certs` çıktısında `CN=Android Debug`.
- [ ] **Adım 7:** `yayin.md`'nin yeniden üretilebilir derleme bölümü: yeni yollar, doğrulama adımları `f-droid-karsilastir.sh` ile, deneme tablosuna sonuç. Commit `altyapı(dağıtım): F-Droid derlemesiyle birebir aynılık denetimi`, push.

### Görev 5: Yayın iş akışı F-Droid yolunda

**Dosyalar:**
- Değiştir: `.github/workflows/yayin.yml`

**Arayüzler:**
- Kullanır: `f-droid-yolunda-derle.sh`, `f-droid-karsilastir.sh` (Görev 4).

- [ ] **Adım 1:** "APK ve AAB" adımı APK'yı `f-droid-yolunda-derle.sh` ile derler; AAB aynı proje klasöründe `flutter build appbundle --release` ile. `subosito/flutter-action` yayın işinden çıkar (Flutter betikte klonlanıyor). `check-release-apk.sh`, imza denetimi ve "Dosyaları topla" yeni çıktı yollarını kullanır.
- [ ] **Adım 2:** `dist/keykey-${VERSION}.apk` artifact olarak yüklenir; yeni iş `f-droid` (`needs: yayin`, `yayin` ortamı yok, `contents: read`) Görev 4'teki `f-droid` + `karsilastir` adımlarını bu APK ve `GITHUB_SHA` ile çalıştırır.
- [ ] **Adım 3:** Taslak notlarına bir satır: "F-Droid karşılaştırması bu iş akışının `f-droid` işinde; yeşil olmadan yayımlama."
- [ ] **Adım 4:** `actionlint` (yoksa kur) temiz; `check-fastlane.py` yeşil (varlık adı denetimi).
- [ ] **Adım 5:** `yayin.md` yayın adımlarına: changelog etiketten önce; dağıtım onayından sonra `f-droid` işi yeşil olunca taslağı yayımla, bekletme. Commit `altyapı(yayın): yayın derlemesi F-Droid yolunda ve F-Droid karşılaştırması`, push. Gerçek sınama Görev 8'de.

### Görev 6: Belgeler

**Dosyalar:**
- Değiştir: `resources/docs/gizlilik.md:58` (F-Droid satırı), `resources/docs/bagimliliklar.md` (yeni araçlar: fdroidserver imajı, apksigcopier — yalnızca CI'da), `CLAUDE.md` yok; `README.md` Windows/derleme bölümü değişmez.

- [ ] **Adım 1:** gizlilik.md: "F-Droid: başvuru Faz 10'da; beklenen anti-özellik yok; birebir aynı derleme, bizim imzamız."
- [ ] **Adım 2:** bagimliliklar.md: CI araçları tablosuna fdroidserver imajı (sürüm/özetle sabitlenmiş) ve apksigcopier.
- [ ] **Adım 3:** Commit `belge(dağıtım): F-Droid için gizlilik ve bağımlılık notları`, push.

### Görev 7: 1.0.1 hazırlığı ve faz PR'ı

**Dosyalar:**
- Değiştir: `pubspec.yaml:4`, `CHANGELOG.md`, `.github/workflows/f-droid.yml` (geçici `push` tetikleyicisi çıkar), `resources/yol-haritasi.md`
- Oluştur: `fastlane/metadata/android/{en-US,tr-TR}/changelogs/4.txt`

- [ ] **Adım 1:** `version: 1.0.1+4`; CHANGELOG'da "Yayınlanmamış" → "1.0.1 (<tarih>)" ve F-Droid/Obtainium maddeleri; `changelogs/4.txt` iki dilde.
- [ ] **Adım 2:** `check-fastlane.py` yeşil; `4.txt` silinince kırmızı (geri al).
- [ ] **Adım 3:** Kontroller: `dart format --output=none --set-exit-if-changed lib test integration_test`, `flutter analyze`, `flutter test`, `flutter test integration_test -d <emülatör>` (bir emülatör yeter, uygulama kodu değişmedi).
- [ ] **Adım 4:** Geçici `push` tetikleyicisini çıkar; commit `altyapı(sürüm): 1.0.1`, push. Deneme iş akışı son bir kez yeşil (elle değil, PR'da).
- [ ] **Adım 5:** PR `faz/10-f-droid` → `main` ("Faz 10: F-Droid ve Obtainium", Closes ile Görev 2 dışındaki hazırlık issue'ları). CI ve F-Droid deneme işi yeşil. **Birleştirme yalnızca kullanıcının bu PR için açık onayıyla**, CLAUDE.md'deki komutla.

### Görev 8: v1.0.1 yayını

- [ ] **Adım 1:** Birleşmiş `main`'de `git tag v1.0.1 && git push origin v1.0.1`.
- [ ] **Adım 2:** Kullanıcı Actions'ta `yayin` dağıtımını onaylar. `yayin` ve `f-droid` işleri yeşil. `f-droid` kırmızıysa taslak yayımlanmaz; neden bulunur, kullanıcıya yazılır (sonraki sürüm 1.0.2 olur).
- [ ] **Adım 3:** Kullanıcı taslağı yayımlar. İndirilen `keykey-1.0.1.apk`'nın sertifikası `66ff7b5c…`.
- [ ] **Adım 4:** Telefon: önce "telefonu bağlar mısın" diye sorulur. README'deki Obtainium bağlantısına dokununca Obtainium'un ekleme ekranı açılıyor ve yalnızca `.apk` seçiliyor. Obtainium bağlantısı issue'su kapanır.

### Görev 9: F-Droid başvurusu

**Dosyalar:**
- Değiştir: `resources/f-droid/io.github.aaudraa.keykey.yml` (derleme bloğu `versionName: 1.0.1`, `versionCode: 4`, `commit: <v1.0.1'in tam özeti>`, `CurrentVersion`/`CurrentVersionCode`)
- Oluştur: `resources/f-droid/basvuru.md` (İngilizce birleştirme isteği metni + kullanıcı için Türkçe adımlar)

- [ ] **Adım 1:** Tarifi `v1.0.1` için doldur; `f-droid.yml`'ı `main`'de elle çalıştır (`gh workflow run f-droid.yml`), yeşil.
- [ ] **Adım 2:** `basvuru.md`: İngilizce metin (ne olduğu, lisans, birebir aynı derleme ve kendi CI'ımızdaki karşılaştırma, imza sertifikası, `INTERNET` yok, kodun büyük kısmının yapay zekâ asistanıyla yazıldığı, iletişim = GitHub issue'ları); Türkçe adımlar: GitLab hesabı, `fdroid/fdroiddata` çatalı, `io.github.aaudraa.keykey` dalı, `metadata/io.github.aaudraa.keykey.yml`, commit "New App: io.github.aaudraa.keykey", birleştirme isteği.
- [ ] **Adım 3:** Commit `belge(dağıtım): F-Droid başvurusu` aynı faz dalında (`main` birleştirilerek güncellenmiş); ikinci, küçük faz PR'ı `main`'e, birleştirme kullanıcının açık onayıyla.
- [ ] **Adım 4:** Kullanıcı birleştirme isteğini açar; bağlantısı başvuru issue'suna yazılır. Kabul ve README'ye F-Droid bağlantısı için ayrı bir issue açılır.
- [ ] **Adım 5:** Yol haritası: Faz 10 "Tamamlandı", milestone kapanır.

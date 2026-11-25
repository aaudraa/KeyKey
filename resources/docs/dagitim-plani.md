# Dağıtım (Faz 22) uygulama planı

> **Uygulayıcılar için:** Görevler sırayla, her biri kendi testiyle yürür. Adımlar `- [ ]` ile işaretlenir.

**Amaç:** Her sürümde işlemciye özel APK'lar ve GitHub Pages'te imzalı kendi F-Droid deposu (1.12.0).

**Mimari:** İşlemciye özel APK'lar evrenselle aynı derleme işinde, aynı yolda üretilir ve evrenselin alt kümesi olduğu denetlenir. Depo, yayımlanan sürümlerden her seferinde baştan `fdroid update` ile kurulur, depo anahtarıyla imzalanır, Pages'e yüklenir.

**Teknoloji:** Flutter `--split-per-abi`, bash betikleri, GitHub Actions, `fdroidserver` imajı, GitHub Pages.

**Tasarım:** [`dagitim.md`](dagitim.md) (uygulayıcı ikisini birlikte okur).

## Genel kısıtlar

- Evrensel APK'nın adı `keykey-<sürüm>.apk` kalır (F-Droid tarifinin `Binaries` alanı).
- Bütün APK'lar aynı sürüm kodunu taşır: `-Pforce-version-code-ignoring-abi=true`.
- İşlemciye özel adlar: `keykey-<sürüm>-arm64-v8a.apk`, `keykey-<sürüm>-armeabi-v7a.apk`, `keykey-<sürüm>-x86_64.apk`.
- Sertifika `66ff7b5c0c009a8530d0a55dd1d80a3af35de48bd0667c456a0cf86a6d1129a0`; değeri tarifteki `AllowedAPKSigningKeys`'ten okunur, betiklere gömülmez.
- Depo adresi `https://aaudraa.github.io/KeyKey/fdroid/repo`; depoda son 3 yayımlanmış sürüm (taslak ve ön sürüm hariç).
- Depo anahtarı yalnızca `fdroid-deposu` ortamında; ortam ve `github-pages` yalnızca `v*` etiketlerine açık.
- Commit, belge ve yorumlar Türkçe; betik ve iş adları mevcut Türkçe düzene uyar.
- Sürüm 1.12.0+19.

## İnceleme odağı

1. **Eski sürüm kodlu APK'yla güncelleme:** 1.11.1 evrensel (kod 18) kurulu telefona 1.12.0 `arm64-v8a` (kod 19) kurulabilmeli; tersi de. Görev 1 sürüm kodunu `aapt2 dump badging` ile denetler.
2. **Yanlış işlemcinin dosyası sızarsa:** `arm64-v8a` APK'sında `lib/x86_64/` olmamalı. Görev 1'in alt küme testi bunu da reddeder.
3. **Depoya taslak girmesi:** taslak ya da ön sürüm, depo betiğinin sürüm listesine girmemeli. Görev 4 testi.
4. **Depo anahtarının sızması:** iş akışı anahtar dosyasını her durumda (`if: always()`) siler; betik parolaları komut satırına yazmaz. Görev 5'te `grep` denetimi.
5. **Obtainium'un var olan kaydı:** 1.11.1 evrenselle eklenmiş kayıt 1.12.0'ı soru sormadan güncellemeli. Görev 3 bunu gerçek yolda dener.

---

### Görev 1: İşlemciye özel APK'lar ve alt küme denetimi

**Dosyalar:**
- Değiştir: `resources/scripts/f-droid-yolunda-derle.sh` (evrenselden sonra `--split-per-abi`, çıktıları `<çıktı-klasörü>/imzasiz-<abi>.apk` olarak kopyalar)
- Oluştur: `resources/scripts/abi-apk-denetle.sh`, `resources/scripts/abi-apk-denetle-test.sh`
- Değiştir: `.github/workflows/f-droid.yml` ("bizim" işi denetimi ve testi çalıştırır)

**Arayüzler:**
- Üretir: `abi-apk-denetle.sh <evrensel-apk> <abi> <abi-apk>`; çıkış 0 = uygun. Kural: `AndroidManifest.xml`, `classes*.dex`, `resources.arsc`, `res/**`, `assets/**`, `lib/<abi>/**` iki APK'da bayt bayt aynı; ABI APK'sında `lib/` altında başka işlemci klasörü yok; `META-INF/` yok sayılır. Ayrıca `aapt2 dump badging` sürüm kodu iki APK'da aynı (aapt2 yoksa bu kısım atlanır ve söylenir; CI'da var).
- Üretir: derleme betiği, `out/imzasiz.apk` yanına `out/imzasiz-arm64-v8a.apk`, `out/imzasiz-armeabi-v7a.apk`, `out/imzasiz-x86_64.apk` yazar.

- [ ] **Adım 1:** `abi-apk-denetle-test.sh`'ı yaz (`imza-ozeti-test.sh` düzeninde). `zip` ile sentetik APK'lar kurar; durumlar: uygun ABI APK'sı → 0; `classes.dex` farklı → hata; ABI APK'sında `lib/x86_64/a.so` fazladan → hata; `lib/arm64-v8a/a.so` farklı → hata; `META-INF/X.SF` farklı → 0.
- [ ] **Adım 2:** Testi çalıştır, betik olmadığı için düştüğünü gör: `bash resources/scripts/abi-apk-denetle-test.sh`.
- [ ] **Adım 3:** `abi-apk-denetle.sh`'ı yaz (`unzip -Z1` ile liste, `unzip -p | sha256sum` ile içerik).
- [ ] **Adım 4:** Test geçer.
- [ ] **Adım 5:** Derleme betiğine split derlemesini ekle; `f-droid.yml` "bizim" işi üç APK'yı denetler ve testi çalıştırır.
- [ ] **Adım 6:** Commit, push, PR'ı aç (taslak). CI'da "bizim" işi yeşil, denetim üç APK'da geçmeli. Yeniden üretilebilirlik için F-Droid işinin evrensel karşılaştırması da yeşil kalmalı.

### Görev 2: İmza, denetim ve yayın dosyaları

**Dosyalar:**
- Değiştir: `.github/workflows/yayin.yml` (yayin işi: üç APK daha imzalanır, `check-release-apk.sh` ve sertifika denetimi dördünde, `dist/` adları ve `SHA256SUMS`; taslak notunda her APK'nın özeti)
- Değiştir: `.github/workflows/f-droid.yml` ("İmza ve denetim (tek kullanımlık anahtar)" işi aynı adımları dört APK'da)

**Arayüzler:**
- Tüketir: Görev 1'in `out/imzasiz-<abi>.apk` dosyaları.
- Üretir: `dist/keykey-<sürüm>.apk`, `dist/keykey-<sürüm>-<abi>.apk` (üç), `.aab`, `-mapping.txt`, `SHA256SUMS` (Görev 3 zip kararını verirse ABI APK'ları `dist/keykey-<sürüm>-abi.zip` içinde).

- [ ] **Adım 1:** `imzala.sh`'ı her ABI APK'sı için iki argümanla çağıran adımı ekle (betik değişmez).
- [ ] **Adım 2:** `check-release-apk.sh` ve imza denetimini döngüyle dört APK'ya uygula.
- [ ] **Adım 3:** Taslak notu: "APK'ların SHA-256 özetleri" altında dört satır (`<özet>  <dosya>`), sertifika özeti aynen.
- [ ] **Adım 4:** PR'da tek kullanımlık anahtar işi yeşil; çıktı listesinde dört imzalı APK.
- [ ] **Adım 5:** Commit.

### Görev 3: Obtainium'un gerçek yolda denenmesi

Kod yazmadan önce karar. Emülatör: `Medium_Phone_API_37.0` (x86_64). Deneme, bu reponun `deneme-obtainium-1` etiketli bir **ön sürümünde** yapılır: `v` ile başlamadığı için yayın iş akışını tetiklemez, ön sürüm olduğu için depo betiğine girmez. Dosyalar PR'daki tek kullanımlık anahtar işinin dört imzalı APK'sı. İmza 1.11.1'den farklı olduğu için kurulum sonda reddedilir; deneme yalnızca Obtainium'un hangi APK'yı seçtiğine ve soru sorup sormadığına bakar.

- [ ] **Adım 1:** Emülatöre Obtainium'u kur, 1.11.1 evrenselle README bağlantısından KeyKey'i ekle.
- [ ] **Adım 2:** Deneme ön sürümünü (dört APK, `gh release create deneme-obtainium-1 --prerelease`) yayımla; Obtainium'da "ön sürümleri dahil et"i aç, güncellemeyi denetle. Not et: soru soruyor mu, hangi APK'yı seçiyor.
- [ ] **Adım 3:** Kararı uygula ve [`dagitim.md`](dagitim.md)'ye sonucu yaz:
  - Soru sormuyorsa: APK'lar ayrı kalır; README bağlantısına `apkFilterRegEx` eklenir.
  - Soruyorsa: Görev 2'nin `dist/` adımı ABI APK'larını `keykey-<sürüm>-abi.zip`'e koyar (zip `-X -D`, dosya sırası sabit); `SHA256SUMS` zip'i ve içindeki APK'ları da listeler.
- [ ] **Adım 4:** Deneme ön sürümünü ve etiketini sil. Commit.

### Görev 4: Depo kurma betiği

**Dosyalar:**
- Oluştur: `resources/scripts/fdroid-deposu-kur.sh`, `resources/scripts/fdroid-deposu-kur-test.sh`
- Oluştur: `resources/f-droid/depo/config.yml.sablon` (depo adı "KeyKey", açıklama Türkçe ve İngilizce, `repo_url`, `archive_older: 0`)

**Arayüzler:**
- Üretir: `fdroid-deposu-kur.sh --surumler <sayı> --apk-klasoru <klasör> --cikti <klasör>`; ortam: `FDROID_KEYSTORE`, `FDROID_KEY_ALIAS`, `FDROID_KEYSTORE_PASSWORD`, `FDROID_KEY_PASSWORD`. Çıktı: `<çıktı>/fdroid/repo/` (index-v1.jar, index-v2.json, entry.jar, APK'lar, simgeler).
- Üretir: `fdroid-deposu-kur.sh --surum-listesi` (yalnızca seçilecek etiketleri yazar; test bunu kullanır).
- Kural: sürümler `gh release list --exclude-drafts --exclude-pre-releases` ile, en yeni 3; her APK'nın sertifikası tarifteki değer ve özeti o sürümün `SHA256SUMS`'ına uyar, uymazsa betik durur.
- Uygulama bilgisi: tarif dosyası, `Builds:` bloğundan sonrası atılarak `metadata/io.github.aaudraa.keykey.yml`; açıklamalar `fastlane/metadata/android/<dil>/` → `metadata/io.github.aaudraa.keykey/<dil>/`.

- [ ] **Adım 1:** Test: sahte `gh` (PATH'e konan betik) taslak, ön sürüm ve 5 normal sürüm döndürür; `--surum-listesi` en yeni 3 normal sürümü verir. Sertifikası farklı APK → betik hata.
- [ ] **Adım 2:** Testin düştüğünü gör.
- [ ] **Adım 3:** Betiği yaz. Aynı sürüm kodlu ABI APK'ları `fdroid update`'te sorun çıkarırsa yalnızca evrenseli koy ve [`dagitim.md`](dagitim.md)'ye bilinen sınır olarak yaz (tasarımın yedek yolu).
- [ ] **Adım 4:** Test geçer. `fdroidserver` imajında tek kullanımlık anahtarla gerçek bir kurulum: `docker` yoksa CI'daki prova (Görev 5) bunun yerine geçer.
- [ ] **Adım 5:** Commit.

### Görev 5: Depo iş akışı, prova ve anahtar betiği

**Dosyalar:**
- Oluştur: `.github/workflows/fdroid-deposu.yml` (olaylar: `release: published`, `workflow_dispatch` girişi `etiket`; iş `kur`: `fdroid-deposu` ortamı, fdroidserver imajı, anahtarı gizli değerden yazar, betiği çalıştırır, `if: always()` ile anahtarı siler, `actions/upload-pages-artifact`; iş `yayimla`: `github-pages` ortamı, `actions/deploy-pages`; izinler `pages: write`, `id-token: write`)
- Değiştir: `.github/workflows/f-droid.yml` (yeni iş "Depo provası": `keytool` ile tek kullanımlık anahtar, betik son 3 sürümle çalışır, `jarsigner -verify` ile `entry.jar` ve `index-v1.jar`, `index-v2.json`'da paket adı ve en yeni sürüm adı denetlenir; yayımlamaz)
- Oluştur: `resources/scripts/depo-anahtari-olustur.sh` (`yayin-anahtari-olustur.sh`'ın düzeni: rastgele parolalar, CR temizliği, `MSYS2_ARG_CONV_EXCL`, 7z AES-256 arşiv, E: ve D:'ye kopya, `gh secret set --env fdroid-deposu` ile dört gizli değer, parmak izini yazdırır, şifresiz dosyaları siler; var olan arşivin üstüne yazmaz)

- [ ] **Adım 1:** Depo provası işini yaz; PR'da yeşil olmalı (Görev 4'ün betiğini gerçek sürümlerle sınar).
- [ ] **Adım 2:** Yayın iş akışını yaz; `actionlint` temiz; `grep` ile hiçbir adımda parolanın komut satırına yazılmadığını denetle.
- [ ] **Adım 3:** Anahtar betiğini yaz; `bash -n` temiz. (Çalıştırmak proje sahibinin işi.)
- [ ] **Adım 4:** Repo ayarları (ben, `gh api` ile): Pages açılır (`build_type=workflow`); `fdroid-deposu` ortamı oluşturulur, `v*` etiket kuralı; `github-pages` ortamına `v*` etiket kuralı eklenir.
- [ ] **Adım 5:** Commit.

### Görev 6: Belgeler ve sürüm

**Dosyalar:** `README.md`, `resources/docs/kullanim.md`, `resources/docs/yayin.md`, `resources/docs/guvenlik-tasarimi.md`, `resources/CHANGELOG.md`, `fastlane/metadata/android/{tr-TR,en-US}/changelogs/19.txt`, `pubspec.yaml` (1.12.0+19), `resources/yol-haritasi.md` (Faz 22 "Sürüyor (1.12.0)").

- [ ] **Adım 1:** README ve kılavuz: hangi APK'yı seçmeli; F-Droid deposu bölümü (bağlantı ve parmak izi; parmak izi anahtar gelince doldurulur, gelmezse bölüm ayrı PR'a kalır, tasarımdaki karar).
- [ ] **Adım 2:** `yayin.md`: yeni dosyalar, alt küme denetimi, depo iş akışı, depo anahtarı ve yedekleri; `guvenlik-tasarimi.md`: dağıtım kanalları ve depo anahtarının tehdit modelindeki yeri.
- [ ] **Adım 3:** Değişiklik günlüğü ve sürüm notları (500 karakter sınırı, `check-fastlane.py`).
- [ ] **Adım 4:** `dart format`, `flutter analyze`, `flutter test`, `python3 resources/scripts/check-fastlane.py` temiz. Commit.

### Görev 7: Son gözden geçirme ve yayın

- [ ] **Adım 1:** Taze bir alt ajanla dalın bütününün incelemesi; bulgular düzeltilir ya da issue'ya yazılır.
- [ ] **Adım 2:** Faz PR'ı; bütün kontroller (F-Droid karşılaştırması ve depo provası dahil) yeşil → birleştir.
- [ ] **Adım 3:** `v1.12.0` etiketi; proje sahibi onaylar ve yayımlar; depo iş akışı çalışır.
- [ ] **Adım 4:** Emülatörde F-Droid istemcisi: depoyu README'deki bağlantıyla ekle, KeyKey'in göründüğünü ve doğru APK'nın (x86_64 emülatörde) kurulduğunu gör.
- [ ] **Adım 5:** Yol haritası PR'ı, faz sonu repo kontrolü.

# Dağıtım: işlemciye göre APK ve kendi F-Droid deposu (Faz 22)

Durum: uygulandı (2026-11-25, 1.12.0). Proje sahibi önerilen sırayla devam etmemi istedi; kararlar benim, proje sahibine kalan adımlar ayrıca yazılı. Plan: [`dagitim-plani.md`](dagitim-plani.md). Uygulamada değişen kararlar "Uygulamada" notlarında.

## Amaç

- **İndirme küçülsün.** Bugün her sürüm dört işlemci türünün kodunu taşıyan tek bir evrensel APK (yaklaşık 80 MB). Telefonların neredeyse hepsi `arm64-v8a`; yalnız ona ait APK bunun yaklaşık üçte biri olur.
- **F-Droid kullanıcıları ana depoyu beklemeden güncelleme alsın.** F-Droid ana deposuna başvuru 2027-02-04'te yeniden yapılacak (proje sahibinin kararı). O zamana kadar ve sonrasında da F-Droid istemcisine eklenebilen kendi depomuz olur; imza bizim, güncellemeler GitHub sürümüyle aynı gün gelir.

## Hedefler

- Her sürümde evrenselin yanında `arm64-v8a`, `armeabi-v7a` ve `x86_64` APK'ları; hepsi aynı anahtarla imzalı, aynı sürüm koduyla.
- İşlemciye özel APK'nın içeriği, F-Droid'in doğruladığı evrensel APK'nınkiyle aynı (aşağıda "Doğrulanabilirlik").
- `https://aaudraa.github.io/KeyKey/fdroid/repo` adresinde imzalı bir F-Droid deposu; sürüm yayımlanınca kendiliğinden güncellenir.
- README'de ve kılavuzda depo bağlantısı ve parmak izi; Obtainium'da doğru APK'nın seçildiği gerçek yol üzerinde denenmiş.

## Hedef olmayanlar

- Google Play.
- F-Droid ana deposunda işlemciye göre derleme (başvuru tarifi evrensel APK'yla kalır).
- Eski sürümleri depoya geriye dönük doldurmak: depo ilk yayımlandığı sürümle başlar.

## Başarısızlık sayılacaklar

- Bugün Obtainium ya da elle kurulumla güncelleyen birinin güncellemesinin kırılması (dosya adı, imza ya da sürüm kodu değişirse olur).
- İşlemciye özel APK ile evrensel APK arasında geçişte "sürüm düşürme" hatası.
- Depo imza anahtarının repoya, günlüğe ya da bir artifact'e düşmesi.
- Yayımlanmamış (taslak) bir sürümün depoya girmesi.

## Kısıtlar

- F-Droid tarifinin `Binaries` alanı `keykey-%v.apk` adını bekliyor; evrensel APK'nın adı değişmez.
- Yayın derlemesi F-Droid'in imajında ve yolunda yapılıyor ve F-Droid'in kendi derlemesiyle bayt bayt karşılaştırılıyor; bu bozulmamalı.
- Android, imzası farklı ya da sürüm kodu düşük bir APK'yı üstüne kurmaz.
- Yayın anahtarı yalnızca `yayin` ortamında ve onayla kullanılır (bkz. [yayın](yayin.md)).

## Yaklaşımlar

### Sürüm kodları

- **A) Bütün APK'larda aynı sürüm kodu (seçildi).** Flutter `--split-per-abi` ile her APK'nın koduna `1000 × ABI` ekler; `force-version-code-ignoring-abi=true` bunu kapatır. Evrensel ile işlemciye özel arasında her yöne geçiş olur, Obtainium'un ve elle kurulumun sürüm karşılaştırması bozulmaz.
- **B) İşlemciye göre farklı kod (Flutter'ın varsayılanı).** Play için gerekir, bizim için değil. Bedeli: `arm64` APK'sını (kod 2018) kuran biri evrensel 19'a geçemez. Elendi.

### Doğrulanabilirlik

- **Her APK'yı F-Droid'in aracıyla ayrıca derlemek.** F-Droid derleme süresi dört katına çıkar; F-Droid ana deposu bu APK'ları zaten derlemeyecek. Elendi.
- **İşlemciye özel APK'nın evrenselin alt kümesi olduğunu denetlemek (seçildi).** Aynı derleme işinde üretilen her APK'nın `AndroidManifest.xml`, `classes*.dex`, `resources.arsc`, `res/` ve `assets/` dosyaları ile kendi işlemcisinin `lib/<abi>/*.so` dosyaları evrensel APK'dakilerle bayt bayt aynı olmalı. Evrensel APK F-Droid'in derlemesiyle aynı çıktığına göre, işlemciye özel APK da doğrulanmış koddan oluşur. Denetim yayın iş akışında ve PR'larda çalışır; tutmazsa yayın durur.

### Kendi deponun barındırılması

- **GitHub Pages, durumsuz yeniden kurma (seçildi).** Sürüm yayımlanınca bir iş, son üç sürümün APK'larını GitHub Release'ten indirir, `fdroid update` ile depoyu baştan kurar, indeksi depo anahtarıyla imzalar ve Pages'e yükler. Ayrı bir dal ya da saklanan durum yok; depo her seferinde sürümlerden yeniden üretilir.
- **`gh-pages` dalında biriken depo.** Durum dalda birikir, bozulursa elle onarılır, repo büyür. Elendi.
- **Ayrı bir repo ya da sunucu.** Hesap ve bakım ister; misyon gereği sunucu yok. Elendi.

## Tasarım

### 1. İşlemciye özel APK'lar

- `f-droid-yolunda-derle.sh` evrensel APK'dan sonra aynı klasörde `flutter build apk --release --split-per-abi -Pforce-version-code-ignoring-abi=true` çalıştırır. Çıktı: `keykey-<sürüm>-arm64-v8a.apk`, `keykey-<sürüm>-armeabi-v7a.apk`, `keykey-<sürüm>-x86_64.apk`.
- Yeni betik `abi-apk-denetle.sh`: yukarıdaki alt küme denetimi (imzasız APK'lar üzerinde, `unzip` ve `sha256sum` ile). Yayın iş akışında derlemeden sonra, PR'lardaki F-Droid iş akışında "bizim" derlemeden sonra çalışır.
- `imzala.sh` dört APK'yı da imzalar; `check-release-apk.sh` (izinler, bileşenler, deep link, yerel semboller) dördünde de çalışır; `SHA256SUMS` hepsini içerir; sürüm notundaki doğrulama bölümü her APK'nın özetini yazar.
- README ve kılavuz: "Telefonların çoğu için `arm64-v8a`; emin değilsen evrensel APK'yı al."

### 2. Obtainium

- Obtainium'un bir sürümde birden çok APK görünce işlemciye göre süzüp süzmediği belgelerden kesinleşmedi. Uygulama sırasında emülatörde (Android 17, `arm64` olmayan emülatörde `x86_64`) gerçek yoldan denenir: var olan bir Obtainium kaydı yeni sürümü nasıl görüyor, yeni ekleme hangi APK'yı seçiyor.
- ~~README'deki bağlantıya evrenseli seçen bir `apkFilterRegEx` eklenir.~~ **Uygulamada (2026-11-25):** gerekmedi. Obtainium 1.7.4 var olan bir kayıtta ("Attempt to filter APKs by CPU architecture" varsayılan açık) x86_64 emülatörde `keykey-<sürüm>-x86_64.apk`'yı kendisi seçip kurulum ekranına geldi; soru sormadı. İşlemciye özel APK'lar Release'e ayrı `.apk` olarak konuyor, evrensel süzme çalışmayan cihazlar için duruyor.
- **Var olan kayıtlar (benim kararım):** Bugünkü bir Obtainium kullanıcısına her güncellemede "hangi APK?" diye sorulması kırılma sayılır. Denemede böyle çıkarsa işlemciye özel APK'lar Release'e ayrı `.apk` olarak konmaz: tek bir `keykey-<sürüm>-abi.zip` içinde gider (Obtainium yalnızca `.apk`'lara bakar) ve ayrı ayrı yalnızca F-Droid deposunda sunulur. Depo iş akışı onları bu zip'ten alır.

### 3. Kendi F-Droid deposu

- **Adres:** `https://aaudraa.github.io/KeyKey/fdroid/repo`. Eklemek için bağlantı: `fdroidrepos://aaudraa.github.io/KeyKey/fdroid/repo?fingerprint=<parmak izi>`; README'de bağlantı ve parmak izi, kılavuzda adım adım ekleme.
- **İş akışı** `.github/workflows/fdroid-deposu.yml`: `release: published` olayında ve elle (`workflow_dispatch`) çalışır. Taslaklar `published` olayı üretmez.
  1. Son üç yayımlanmış sürümün (`gh release list`, taslak ve ön sürüm hariç) APK'larını indirir; her birinin imza sertifikasının `66ff7b5c…` olduğunu ve `SHA256SUMS`'a uyduğunu denetler.
  2. F-Droid'in imajında `fdroid update` çalıştırır. Uygulama bilgisi tarif dosyasından (`Builds` bloğu atılarak), açıklamalar ve ekran görüntüleri `fastlane/`'den gelir.
  3. İndeksi depo anahtarıyla imzalar; anahtar dosyası iş biter bitmez silinir.
  4. `actions/upload-pages-artifact` ve `actions/deploy-pages` ile yayımlar.
- **Hangi APK'lar:** F-Droid istemcisi işlemciyi APK'nın `nativecode` bilgisinden seçer. Uygulayıcı önce işlemciye özel üç APK'yı aynı sürüm koduyla depoya koymayı dener; `fdroid update` aynı sürüm kodlu birden çok APK'yı kabul etmez ya da istemci yanlış seçerse depo yalnızca evrensel APK'yla kurulur ve bu belgede bilinen sınır olarak yazılır.
- **Depo anahtarı:** Yayın anahtarından ayrı, yeni bir anahtar (depo indeksini imzalar, APK'yı değil). APK'lar yine yayın anahtarıyla imzalı olduğu için depo anahtarı sızarsa bile kurulu KeyKey'e başka imzalı bir güncelleme kurulamaz; yeni kurulumlar için risk vardır, bu yüzden anahtar yayın anahtarı gibi korunur.
  - Proje sahibinin bilgisayarında yeni betik `depo-anahtari-olustur.sh` ile oluşturulur (yayın anahtarı betiğinin aynısı: rastgele parola, AES-256 şifreli arşiv, CR temizliği). Parmak izi belgeye ve README'ye yazılır.
  - GitHub'da yeni `fdroid-deposu` ortamının gizli değerlerinde durur; ortam yalnızca `v*` etiketlerine açıktır. Ayrı bir onay istemez: depoya girecek sürümü proje sahibi zaten taslağı yayımlayarak seçiyor.
  - Yedekler yayın anahtarınınkiyle aynı kurala uyar (üç kopya, iki ortam, biri evden uzakta).
- **Pages:** Repo ayarında Pages, kaynak "GitHub Actions" olarak açılır. Repo kökünde Pages'e giden başka bir şey yok; yalnızca `fdroid/` yayımlanır.

- **Prova (benim kararım):** `release: published` ve elle çalıştırma iş akışını etiketin commit'inden okur; etikete girmiş bir hata yeni etiket atmadan düzeltilemez. Bu yüzden depo kurulumu PR'larda tek kullanımlık bir anahtarla prova edilir: aynı betik son yayımlanmış sürümlerin APK'larıyla `fdroid update`'i çalıştırır, indeksin imzasını ve içeriğini (paket, sürüm, APK özetleri) doğrular, yayımlamaz. Depo anahtarının ortamı yalnızca `v*` etiketlerine açık kalır.
- İmzalama `fdroid-deposu`, yayımlama `github-pages` ortamında, iki ayrı işte olur (bir iş tek ortama bağlanır). `github-pages` ortamı da `v*` etiketlerine açılır.

### 4. Sürüm

- Faz 1.12.0 olarak çıkar. İlk depo kurulumu depo anahtarı gelince olur ve yayımlanmış son üç sürümü alır; 1.12.0'dan öncekilerde (1.11.1, 1.11.0) yalnızca evrensel APK var.
- **Depo anahtarı gecikirse (benim kararım):** 1.12.0 beklemez, işlemciye özel APK'larla çıkar. Anahtar gelince depo iş akışı `v1.12.0` etiketinde elle çalıştırılır ve depo 1.12.0'la kurulur; README'deki depo bölümü o zaman ayrı bir belge PR'ıyla eklenir.

### 5. Belgeler

- [`yayin.md`](yayin.md): yeni dosyalar, alt küme denetimi, depo iş akışı, depo anahtarı ve yedekleri.
- [`guvenlik-tasarimi.md`](guvenlik-tasarimi.md): dağıtım kanalları ve depo anahtarının tehdit modelindeki yeri.
- README, `kullanim.md`, değişiklik günlüğü, sürüm notları.

## Proje sahibine kalanlar

- `depo-anahtari-olustur.sh`'ı kendi bilgisayarında çalıştırmak (arşiv parolasını seçmek ve kâğıda yazmak) ve arşivi yedeklemek. Betik gizli değerleri GitHub'a kendisi yükler.
- 1.12.0'ın yayın onayı ve taslağı yayımlamak (her sürümde olduğu gibi).
- İsterse telefonuna depoyu ekleyip ilk güncellemeyi denemek.

## Uygulayıcıya kalanlar

- `flutter build apk --split-per-abi`'nin F-Droid yolunda yeniden üretilebilir olup olmadığı (iki derleme karşılaştırılır) ve alt küme denetiminin `resources.arsc`'yi kapsayıp kapsayamayacağı.
- Depoda aynı sürüm kodlu işlemciye özel APK'ların çalışıp çalışmadığı (yukarıda yedek yol var).
- Son üç sürüm sayısı ve depo adı, açıklaması, simgesi. Pages boyutu üç sürümle yaklaşık 500 MB, sınır 1 GB.

## Riskler

- **Obtainium'un davranışı:** emülatörde denendi, işlemciye uyan APK'yı kendisi seçiyor (bkz. §2).
- **Depo anahtarı kaybolursa:** kullanıcılar depoyu yeni parmak iziyle yeniden eklemek zorunda kalır; uygulama ve veri etkilenmez.
- **GitHub Pages kesintisi:** depo güncellemesi gecikir; GitHub sürümü ve Obtainium etkilenmez.

# F-Droid ve Obtainium tasarımı

Durum: onaylandı ve uygulandı (2026-11-17). Faz 10, dal `faz/10-f-droid`. Uygulamada değişenler: deneme iş akışı (`f-droid.yml`) yayın zincirinin tek kullanımlık anahtarla tam provası oldu (AAB, imzalama betiği [`imzala.sh`](../scripts/imzala.sh), APK denetimi); PR'larda ve haftada bir çalışır. Bizim derleme imajın sabit özetiyle, F-Droid derlemesi imajın güncel haliyle yapılır; F-Droid'in ortamı ayrılırsa karşılaştırma bunu gösterir. Yayında taslak, F-Droid karşılaştırması yeşil olmadan oluşmaz.

## Amaç

KeyKey bugün yalnızca GitHub Releases'tan elle indiriliyor. Hedef kitle (gizliliğe önem veren Android kullanıcıları) açık kaynak uygulamaları önce F-Droid'de arıyor. Amaç:

1. KeyKey'i **F-Droid ana deposunda, bizim imzamızla** yayımlatmak. F-Droid kaynaktan kendisi derler, derlemesi GitHub'daki APK'mızla birebir aynı çıkarsa bizim imzalı APK'mızı dağıtır. Böylece tek bir KeyKey olur: GitHub'dan, Obtainium'dan ya da F-Droid'den kuran aynı imzayı alır, biri ötekinin üstüne güncellenir.
2. README'ye **Obtainium'a tek dokunuşla ekleme bağlantısı** koymak. Obtainium bugün de çalışıyor; bağlantı yalnızca adresi elle yazma zahmetini kaldırır.

## IzzyOnDroid neden yok

İlk plan IzzyOnDroid'di (yol haritası, #100). [Kabul kuralları](https://izzyondroid.org/docs/general/AppInclusionPolicy/) "AI policy" bölümünde yapay zekâyla yazılmış kodu kabul etmiyor ("Vibe-coded apps will be rejected"; kodda LLM çıktısı olmamalı; saklandığı anlaşılırsa uygulama reddedilir). KeyKey'in kodu büyük ölçüde bir yapay zekâ asistanıyla yazıldı ve bunu açıkça söylüyoruz. Ayrıca APK başına 30 MB sınırı var, APK'mız 77 MB. Bu yüzden IzzyOnDroid'e başvurulmuyor. [F-Droid'in kabul kurallarında](https://f-droid.org/docs/Inclusion_Policy/) yapay zekâ hakkında bir madde yok (2026-11-17 itibarıyla).

## Hedefler

- KeyKey f-droid.org'da listelensin ve indirilen APK bizim yayın anahtarımızla imzalı olsun (sertifika SHA-256 `66ff7b5c0c009a8530d0a55dd1d80a3af35de48bd0667c456a0cf86a6d1129a0`).
- Yeni bir `v*` etiketi yayımlandığında F-Droid sürümü kendiliğinden alsın (otomatik güncelleme).
- Birebir aynı derlemenin tuttuğunu F-Droid'e başvurmadan önce **kendi CI'ımızda** görelim.
- README'de çalışan bir Obtainium bağlantısı olsun.

## Hedef olmayanlar

- APK'yı işlemci türüne göre bölmek. Tek evrensel APK kalıyor (kullanıcı kararı, 2026-11-17: seçenek A). Bölme sonra ayrı bir iş olarak eklenebilir.
- Play Store, IzzyOnDroid, kendi F-Droid depomuz.
- Uygulamanın davranışında değişiklik.

## Başarısızlık sayılacaklar

- F-Droid'in kendi anahtarıyla imzaladığı ikinci bir KeyKey. Birebir aynı derleme tutturulamazsa bu yola **gidilmez**; durup kullanıcıya sorulur.
- Yapay zekâ kullanımının başvuruda saklanması. Başvuru metni bunu açıkça yazar.
- `INTERNET` izni ya da ağ erişimi eklenmesi.
- Yayın anahtarının ya da parolalarının yayın ortamı (`yayin`) dışına çıkması.

## Kısıtlar

- Kodun içine derleme klasörünün yolu giriyor: `libapp.so` Flutter'ın ürettiği `dart_plugin_registrant.dart` dosyasının mutlak yolunu, `libdartjni.so` dosya yollarından hesaplanan bir derleme kimliğini taşıyor ([yayin.md](yayin.md#yeniden-üretilebilir-derleme)). Aynı kod + aynı araç sürümleri + aynı yol = aynı APK; bu 2026-11-09'da gösterildi.
- F-Droid uygulamayı `/home/vagrant/build/io.github.aaudraa.keykey` altında derler. Flutter SDK'yı srclib olarak (`/home/vagrant/build/srclib/flutter`) getirir. Pub önbelleğinin yolu da paket kaynaklarının yolunu belirler.
- `v1.0.0` GitHub'ın `/home/runner/work/KeyKey/KeyKey` yolunda derlendi, F-Droid'in derlemesiyle aynı çıkamaz. **F-Droid'e giren ilk sürüm yeni bir sürüm olacak: 1.0.1 (versionCode 4).**
- F-Droid derlemesi imzasız APK bekler. Bizim Gradle ayarımız anahtar yokken sürüm derlemesini hata ayıklama anahtarıyla imzalıyor (`android/app/build.gradle.kts`, `signingConfig ... else "debug"`); F-Droid derlemesinde bu imza olmamalı.
- Özgür olmayan bağımlılık yok (Google servisleri, ML Kit, Firebase yok; QR için zxing). libsodium ve SQLite kaynaktan derleniyor, derlemede bir şey indirilmiyor ([bagimliliklar.md](bagimliliklar.md)). Flutter SDK'nın hazır parçaları F-Droid kurallarında izinli.
- AGP'nin şifreli bağımlılık listesi zaten kapalı (`dependenciesInfo`).
- F-Droid'e başvuru GitLab'da `fdroid/fdroiddata` deposuna birleştirme isteği (merge request) ile yapılır. Kullanıcının GitLab hesabı gerekir; gönderen kullanıcıdır.
- Repo kuralı "kod olmayan her şey `resources/` altına". F-Droid uygulama açıklamalarını ve görselleri repo kökündeki `fastlane/metadata/android/` altında arar; bu, kökte olmak zorunda olan bir klasör.

## Yaklaşımlar

### APK düzeni

- **A) Tek evrensel APK (seçildi).** F-Droid her sürüm için tek bir derleme yapar. Yayın iş akışı ve sürüm numaraları değişmez. Bedeli: herkes dört işlemci türünün kodunu indirir (77 MB).
- **B) İşlemci türüne göre üç APK.** İndirme ~25-30 MB'a iner. Ama her sürüm için üç derleme tanımı, üç birebir aynı APK, değişen sürüm kodu düzeni. İlk adım için iş üçe katlanıyor.

Kullanıcı A'yı seçti: önce birebir aynı derleme tek APK'yla oturtulacak.

### Birebir aynılığı nerede sınayacağız

- **F-Droid'in incelemesinde deneme yanılma.** Her başarısız deneme gönüllülerin kuyruğunda günler alır.
- **Kendi CI'ımızda F-Droid'in derleme aracıyla (seçildi, benim kararım).** F-Droid'in resmî `fdroidserver` derleme imajı GitHub Actions'ta bizim taslak tarif dosyamızla çalıştırılır, çıkan imzasız APK yayındaki APK'yla karşılaştırılır. Başvurudan önce sonucu biliriz; sonraki her sürümde de bozulma hemen görünür.

### Obtainium bağlantısı

GitHub README'de `obtainium://` bağlantıları tıklanmıyor; Obtainium'un yönlendirme sayfası kullanılır: `https://apps.obtainium.imranr.dev/redirect?r=obtainium://app/<URL kodlu JSON>`, JSON `{"id":"io.github.aaudraa.keykey","url":"https://github.com/aaudraa/KeyKey","author":"aaudraa","name":"KeyKey"}` ([Obtainium deep links](https://wiki.obtainium.imranr.dev/deep_links/)). Rozet resmi yerine düz metin bağlantı (benim kararım: Obtainium resmi kendi barındırmamızı istiyor, metin yeterli).

## Tasarım

### 1. Obtainium bağlantısı

- README'deki "KeyKey 1.0 yayında" kutusuna ve kurulum bölümüne "Obtainium'a ekle" bağlantısı.
- `kullanim.md`'deki Obtainium paragrafına aynı bağlantı.
- Yayında `.apk` dışında `.aab`, `mapping.txt` ve `SHA256SUMS` de var; Obtainium'un yalnızca `.apk`'yı seçtiği gerçek bir telefonda ya da emülatörde denenir.

### 2. Uygulama açıklamaları (Fastlane)

Repo kökünde `fastlane/metadata/android/`:

```
en-US/                     (zorunlu yedek dil)
  title.txt                KeyKey
  short_description.txt    ≤ 80 karakter
  full_description.txt     ≤ 4000 karakter
  images/icon.png          512×512, resources/design/keykey-simge.svg'den
  images/phoneScreenshots/ PNG
  changelogs/4.txt         ≤ 500 karakter (1.0.1)
tr-TR/
  (aynı dosyalar, Türkçe)
```

- Açıklama: çevrimdışı, `INTERNET` izni yok, açık kaynak, parola + 2FA + otomatik doldurma + şifreli yedek, içe aktarma. Sonunda dürüst iki cümle: kodun büyük kısmı bir yapay zekâ asistanıyla yazıldı; proje kendi güvenlik denetiminden geçti, bağımsız bir denetimden geçmedi.
- Ekran görüntüleri `resources/design/kilavuz/*.webp`'den PNG'ye çevrilir (F-Droid PNG/JPG istiyor). Kılavuzdaki 15 görüntüden 6-8'i seçilir. Görüntüler Türkçe arayüzü gösteriyor; İngilizce arayüzden ayrı görüntü almak bu işin parçası değil (benim kararım, sonra eklenebilir).
- Her sürümde `changelogs/<versionCode>.txt` etiketten **önce** eklenir; F-Droid açıklamaları etiketin olduğu commit'ten okur. Bu kural `yayin.md`'deki sürüm adımlarına yazılır.

### 3. Yayın derlemesi F-Droid'in yolunda

`yayin.yml` APK'yı F-Droid'in derleyeceği yerlerde derler:

- proje: `/home/vagrant/build/io.github.aaudraa.keykey`
- Flutter SDK: F-Droid'in `flutter` srclib'inin açıldığı yer, aynı etiket (bugün 3.47.9)
- pub önbelleği ve gerekiyorsa JDK/NDK sürümü: F-Droid derlemesindekiyle aynı

Kesin yollar ve sürümler tahmin edilmez; 4. maddedeki iş F-Droid imajının içinde ne kullanıldığını gösterir ve yayın iş akışı ona göre ayarlanır. AAB ve `mapping.txt` aynı derlemeden çıkmaya devam eder.

### 4. F-Droid doğrulama işi

F-Droid'in resmî `fdroidserver` derleme imajında, repodaki tarif dosyasıyla `fdroid build` çalıştırılır; çıkan imzasız APK'ya bizim APK'mızın imzası kopyalanır ([apksigcopier](https://github.com/obfusk/apksigcopier), F-Droid'in kullandığı yöntem) ve imzanın doğrulandığı görülür. Tutmazsa farklı dosyalar listelenir (`diffoscope` ya da `unzip -v` CRC karşılaştırması). İmza kopyalama hangi anahtarla atılmış olursa olsun aynılığı kanıtlar. İki yerde çalışır (benim kararım):

- **Deneme iş akışı** (ör. `.github/workflows/f-droid.yml`, elle başlatılır, herhangi bir dalda): yayın iş akışıyla aynı adımlarla APK derler ama **o an üretilen tek kullanımlık bir anahtarla** imzalar, sonra yukarıdaki karşılaştırmayı yapar. Etiket, taslak sürüm, sürüm numarası değişikliği ve gerçek yayın anahtarı gerekmez. Tarif dosyasındaki commit yerine iş akışının çalıştığı commit kullanılır. Faz boyunca bütün denemeler bununla yapılır.
- **Yayın iş akışında ikinci iş:** `v*` etiketinde imzalı APK derlendikten sonra aynı karşılaştırma bu APK'yla, taslak yayımlanmadan **önce** yapılır (APK işler arasında iş akışı dosyası olarak aktarılır, taslağın indirme bağlantısı gerekmez). Tutmazsa iş kırmızı olur ve kullanıcı taslağı yayımlamaz; yayımlanmış ama F-Droid'in alamayacağı bir sürüm oluşmaz. Bu iş `yayin` ortamını ve anahtarı kullanmaz.

1.0 öncesindeki `v1.0.0-deneme.1` gibi deneme etiketlerine gerek kalmıyor: `yayin` ortamında artık yalnızca gerçek anahtar var, atılacak bir deneme derlemesini onunla imzalamak istemiyoruz.

### 5. F-Droid tarif dosyası

`resources/f-droid/io.github.aaudraa.keykey.yml`: fdroiddata'ya gönderilecek dosyanın kopyası, 4. maddedeki işin de girdisi. İçeriği:

- `License: GPL-3.0-only`, kategoriler (güvenlik / parola), `SourceCode`, `IssueTracker`, `Changelog`, `AuthorName`
- `RepoType: git`, `Repo: https://github.com/aaudraa/KeyKey.git`
- `Binaries: https://github.com/aaudraa/KeyKey/releases/download/v%v/keykey-%v.apk`
- `AllowedAPKSigningKeys: 66ff7b5c0c009a8530d0a55dd1d80a3af35de48bd0667c456a0cf86a6d1129a0`
- Derleme bloğu: `versionName`/`versionCode`, tam commit özeti, `srclibs: flutter@<sürüm>`, kullanılmayan platform klasörlerinin silinmesi, `pub get`, imzasız `flutter build apk --release`, `output`
- `AutoUpdateMode: Version`, `UpdateCheckMode: Tags` (deneme etiketleri dışarıda kalacak bir desenle), `pubspec.yaml`'dan sürüm okuyan `UpdateCheckData`

İmzasız çıktı için F-Droid tarifinde imza satırını silen bir `prebuild` adımı mı, yoksa Gradle'da "anahtar yoksa imzalama" seçeneği mi kullanılacağı uygulayıcıya kalıyor. Yerel deneme APK'ları bugünkü gibi hata ayıklama anahtarıyla imzalanmaya devam etmeli.

### 6. 1.0.1 sürümü

- İçerik: "Yayınlanmamış" altındaki bağımlılık güncellemeleri, F-Droid yolu, Fastlane klasörü. Uygulamanın davranışı değişmiyor.
- `pubspec.yaml` `1.0.1+4`, CHANGELOG başlığı, `fastlane/.../changelogs/4.txt`.
- Akış 1.0.0'daki gibi: faz PR'ı → birleştirme → `v1.0.1` etiketi → kullanıcı Actions'ta dağıtımı onaylar → yayın iş akışındaki F-Droid karşılaştırması yeşil → kullanıcı taslağı yayımlar.
- Taslak, etiketten sonra uzun süre yayımlanmadan beklememeli: F-Droid yeni etiketi görünce APK'yı `Binaries` adresinden indirmeye çalışır, taslağın adresi açık değildir.

### 7. Başvuru

- Tarif dosyası ve başvuru metni (İngilizce, F-Droid topluluğu İngilizce çalışıyor) hazırlanır. Metinde: imza anahtarı, birebir aynı derlemenin kendi CI'ımızda doğrulandığı, internet izni olmadığı, **kodun büyük kısmının bir yapay zekâ asistanıyla yazıldığı**.
- Kullanıcı GitLab'da `fdroid/fdroiddata`'yı çatallar ve birleştirme isteğini açar; adımlar ona yazılı verilir. İncelemede gelen sorular birlikte yanıtlanır.
- Kabul edilince README'ye F-Droid bağlantısı eklenir.

### 8. Belgeler ve takip

- Yol haritası: Faz 10 bölümü ve durum satırı; "1.0 sonrası"ndaki IzzyOnDroid satırı nedeniyle güncellenir.
- `yayin.md`: doğrulama adımlarındaki yol, sürüm çıkarırken changelog kuralı.
- `gizlilik.md`: F-Droid satırı.
- GitHub: "Faz 10" milestone'u ve işler için issue'lar.

## Fazın sınırı

F-Droid'in kabulü haftalar sürebilir ve bizim elimizde değil. Bu yüzden Faz 10 **başvurunun gönderilmesiyle** biter (benim kararım):

1. Dalda: Obtainium bağlantısı, Fastlane klasörü, tarif dosyası, deneme iş akışı yeşil, yayın iş akışında F-Droid işi, 1.0.1 sürüm numarası, belgeler.
2. Faz PR'ı `main`'e (tek PR), birleştirme, `v1.0.1` yayını, yayın iş akışındaki F-Droid işi yeşil.
3. Başvuru metni hazır, kullanıcı birleştirme isteğini açtı. Faz burada kapanır.

İnceleme soruları ve kabulden sonra README'ye eklenecek F-Droid bağlantısı ayrı, küçük işler olarak yapılır (açık bir issue'da izlenir).

## Başarı ölçütü

- Faz için: `v1.0.1` için yayın iş akışındaki F-Droid karşılaştırması yeşil; fdroiddata'ya birleştirme isteği açıldı; README'deki Obtainium bağlantısı telefonda Obtainium'un ekleme ekranını açıyor.
- Sonrası için: birleştirme isteği birleşti, KeyKey f-droid.org'da, indirilen APK'nın sertifikası `66ff7b5c…`.

## Riskler

- F-Droid imajındaki JDK, NDK ya da araçlar bizimkinden farklı olabilir ve yol dışında başka farklar çıkabilir. Doğrulama işi bunu başvurudan önce gösterir. Çözülemezse durulur, kullanıcıya sorulur.
- İnceleme kuyruğu haftalar sürebilir; incelemeci yapay zekâ konusunda itiraz edebilir.
- F-Droid'in tarayıcısı paketlerdeki arşivleri (libsodium kaynağı gibi) ya da Gradle sarmalayıcısını işaretleyebilir; gerekirse `scanignore`/`scandelete` gerekçesiyle yazılır.

## Uygulayıcıya kalanlar

- F-Droid imajının adı ve sürümü, içindeki kesin yollar ve araç sürümleri.
- İmzasız derlemenin nasıl alınacağı (5. madde).
- Ekran görüntüsü seçimi, açıklama metinleri, F-Droid kategori adları.
- Tarayıcı istisnaları.

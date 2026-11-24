# KeePass içe aktarma

Faz 20'nin tasarımı. Hedef sürüm `1.9.0`. Takip: [#177](https://github.com/aaudraa/KeyKey/issues/177).

Proje sahibi 2026-11-19'da "1.0 sonrası" listesindeki bütün fikirleri onayladı ve 2026-11-22'de işe devam edilmesini istedi. Aşağıdaki seçimler benim; proje sahibi soru sorulmadan ilerlenmesini istiyor, "hangi sistem daha iyi ve sağlamsa onu kullanmayı tercih ederim" dedi. Her seçimin gerekçesi yanında yazılı.

## Neden

KeePass ailesi (KeePass 2, KeePassXC, KeePassDX, Keepass2Android, Strongbox) en yaygın açık kaynak parola yöneticisi. Kullanıcıları KeyKey'e bugün yalnızca KeePassXC'in CSV dışa aktarmasıyla geçebiliyor: önce bilgisayarda bütün parolaları şifresiz bir dosyaya yazmak, sonra o dosyayı telefona taşımak gerekiyor. Telefonda KeePassDX ya da Keepass2Android kullanan biri CSV bile alamıyor; bu uygulamalar dışa aktarmıyor, yalnızca `.kdbx` dosyasının kendisini tutuyor.

`.kdbx` dosyasını doğrudan açmak bu iki sorunu da kaldırır: dosya zaten telefonda, şifreli ve kullanıcı ana parolasını biliyor. Düz metin hiçbir yere yazılmaz.

## Hedefler

- "Parolaları içe aktar" ile seçilen `.kdbx` dosyası tanınır; ana parola ve isteğe bağlı anahtar dosyası istenir, dosya açılır, kayıtlar bugünkü önizleme ekranında gösterilir.
- Desteklenen biçimler bugünkü KeePass uygulamalarının yazdığı her şeyi kapsar: KDBX 2.x, 3.x ve 4.x; AES-KDF, Argon2d ve Argon2id; AES-256, ChaCha20 ve Twofish; sıkıştırmalı ve sıkıştırmasız.
- Gruplar klasör, TOTP alanları bağlı 2FA hesabı, ek alanlar özel alan olur. Çöp kutusundaki kayıtlar alınmaz.
- Yanlış parola, desteklenmeyen biçim ve bozuk dosya birbirinden ayrı ve anlaşılır biçimde söylenir.

## Hedef olmayanlar

- **KeePass'a yazmak ya da `.kdbx` ile eşitlemek.** Yalnızca içe aktarma. KeyKey'in kendi senkronu var.
- **KeePass 1 (`.kdb`).** KeePass 2 bunu açıp yeni biçimde kaydedebilir. Dosya tanınır ve kullanıcıya bu söylenir.
- **YubiKey (challenge-response) ve Windows kullanıcı hesabı ile korunan dosyalar.** İkisi de anahtarın bir parçasını dosyanın dışından, cihazdan alır. Dosya bunları ayırt ettirmez; yanlış parola mesajı bu ihtimali de anar.
- **Ekler.** KeyKey'de dosya eki yok. Eki olan kayıtların sayısı önizlemede söylenir, ekler alınmaz.
- **Kayıt geçmişi, simgeler, etiketler, son kullanma tarihleri, otomatik yazma ayarları.** KeyKey'de karşılıkları yok ya da başka anlamdalar. Kayıtlar eklendikleri anın tarihiyle oluşur (bugünkü bütün içe aktarmalar gibi).
- **Kart.** KeePass'ta kart türü yok; KeePassXC kartları düz kayıt olarak tutar. Kayıt giriş kaydı olarak gelir.

## Karşı hedefler

Bunlardan biri olursa iş çalışsa bile başarısızdır:

- Dosyanın ya da çözülmüş içeriğin diske, önbelleğe, günlüğe yazılması.
- Yanlış parolayla açılmış gibi davranmak: bozuk ya da değiştirilmiş bir dosyadan anlamsız kayıtlar göstermek. Açma ya tamamen doğrulanır ya da hiç kayıt gösterilmez.
- Bozuk ya da kötü niyetli bir dosyanın uygulamayı düşürmesi, belleği tüketmesi ya da arayüzü dondurması.
- Ana parolanın ya da anahtar dosyasının kasaya, ayarlara ya da başka bir yere kaydedilmesi.
- Bugün çalışan CSV ve JSON içe aktarmalarının bozulması.

## Yaklaşımlar

İşin zor kısmı anahtar türetme. KDBX 4'ün varsayılanı Argon2d, libsodium'da yok. libsodium'un Argon2id'si de KeePass'ın kullandığı paralellik (lanes > 1), gizli anahtar ve ek veri parametrelerini almıyor. AES-KDF ise AES'i milyonlarca kez art arda çalıştırıyor; KeePassXC tur sayısını "bilgisayarda 1 saniye sürsün" diye ayarlıyor.

2026-11-22'de geliştirme bilgisayarında ölçtüm (Dart AOT, `pointycastle` 4.0.0): Argon2d 64 MiB tek geçiş 300 ms, AES-KDF bir milyon tur 1,1 saniye. Telefon bunun iki ya da üç katı yavaş. KeePassXC'in varsayılan ayarıyla oluşturulmuş bir dosya saf Dart'ta telefonda 15 saniyeden, AES-KDF'li bir dosya bir dakikadan uzun sürebilir.

1. **Her şey saf Dart (`pointycastle`).** Tek bağımlılık, bilgisayardaki testlerle telefondaki kod aynı. Ama yukarıdaki süreler kabul edilemez, Argon2 da tek iş parçacığında kalıyor.
2. **Ağır iki işlem telefonda yerel kodla, gerisi Dart'ta.** Argon2, Argon2'nin yazarlarının başvuru uygulamasıyla (C, [P-H-C/phc-winner-argon2](https://github.com/P-H-C/phc-winner-argon2), CC0 ya da Apache 2.0) çok iş parçacıklı çalışır. AES-KDF, Android'in donanım hızlandırmalı AES'iyle (`javax.crypto`) Kotlin'de çalışır. Başlık çözme, bütünlük doğrulama, şifre çözme ve XML Dart'ta kalır. Bilgisayardaki testlerde anahtar türetme `pointycastle` ile yapılır; telefondaki uygulama aynı test dosyalarıyla ve Argon2'nin standart test vektörleriyle cihaz testinde sınanır.
3. **Bütün kripto Kotlin'de, Bouncy Castle ile.** Tek yerde ve olgun bir kitaplıkla. Ama Bouncy Castle'ın Argon2'si belleği Java yığınında ayırıyor; Android uygulamalarının yığını çoğu telefonda 256–512 MiB ile sınırlı, 256 MiB ve üstü Argon2 belleği olan dosyalar açılamaz. Argon2 de tek iş parçacıklı.

**Seçim: 2.** Hızı ve bellek sınırı gerçek kullanıcı dosyalarının açılıp açılmayacağını belirliyor; 1 ve 3 bunlardan birinde düşüyor. Argon2'nin başvuru uygulaması algoritmanın kendi yazarlarından ve RFC 9106'nın test vektörlerini üretmiş kod; yol haritasındaki "ayrı ve incelenmiş bir uygulama" koşulunu karşılıyor. Dart'ta kalan şifre çözme işleri (birkaç megabayt) için `pointycastle` yeterince hızlı.

## Tasarım

### Akış

1. Kullanıcı bugünkü gibi Ayarlar → Yedekleme → **Parolaları içe aktar**'a dokunur ve bir dosya seçer.
2. Dosyanın ilk 8 baytı KDBX imzasıysa (`03 D9 A2 9A 67 FB 4B B5`) **KeePass dosyasını aç** ekranı açılır. Değilse bugünkü CSV/JSON okuyucusuna gider. KeePass 1 imzası (`03 D9 A2 9A 65 FB 4B B5`) bu ekranı açmaz, "eski bir KeePass biçimi" mesajı çıkar.
3. Ekranda ana parola kutusu (gizli, öğrenme kapalı; kasadaki parola kutularıyla aynı bileşen), **Anahtar dosyası seç** düğmesi (seçilince "Anahtar dosyası seçildi" ve kaldırma düğmesi görünür; belge seçici dosya adını vermiyor) ve **Aç** düğmesi var. Parola boş bırakılabilir; anahtar dosyası yalnız da kullanılabilir ([Anahtar](#anahtar)).
4. **Aç**'a basılınca anahtar türetilir. Ekranda ilerleme ve "KeePass dosyaları parola denemelerini yavaşlatmak için bilerek yavaş açılır" yazar. Geri tuşu beklemeyi bırakır; arka planda süren hesap bitince sonucu atılır.
5. Açılınca bugünkü önizleme ekranı (`LoginImportScreen`) gelir. Kaynak adı "KeePass (KDBX)" olur, KeePass'a özgü bilgi kartları eklenir (eki olan kayıtlar, çöp kutusu).
6. Yanlış anahtarda ekranda kalınır, kutunun altında "Parola ya da anahtar dosyası yanlış" yazar; dosya YubiKey ya da Windows hesabı istiyorsa bunun desteklenmediği de eklenir.

Dosya ekran açıkken bellekte durur (yanlış parolada yeniden seçmek gerekmesin diye) ve ekrandan çıkınca sıfırlanır. Anahtar dosyasının baytları bileşik anahtar hesaplanınca hemen sıfırlanır; ekranda yalnızca dosya adı kalır, yeniden denemede anahtar dosyası yeniden okunmaz, hesaplanmış 32 baytlık özeti bellekte tutulur ve ekrandan çıkınca sıfırlanır.

İçe aktarmanın sonundaki "düz metin kaynak dosyasını sil" hatırlatması `.kdbx` için gösterilmez: dosya şifreli.

### Biçim

| | KDBX 2.x ve 3.x | KDBX 4.0 / 4.1 |
|---|---|---|
| Başlık alanı uzunluğu | 2 bayt | 4 bayt |
| Anahtar türetme | AES-KDF (`TransformSeed`, `TransformRounds`) | `KdfParameters` sözlüğü: AES-KDF, Argon2d, Argon2id |
| Doğru anahtarın kanıtı | Çözülen verinin ilk 32 baytı `StreamStartBytes` | Başlığın HMAC-SHA-256'sı |
| Bütünlük | Blok başına SHA-256 (`HashedBlockStream`) | Blok başına HMAC-SHA-256, şifreli veri üzerinde |
| Korumalı değerler | Salsa20 | ChaCha20 (iç başlıkta) |
| Ekler | XML'de `Meta/Binaries` | İç başlıkta |

- Sürüm: ana sürüm 2, 3 ya da 4 kabul edilir, başka ana sürüm "desteklenmeyen sürüm" olur. 2.x ve 3.x'in yapısı aynı, aynı okuyucuyla açılır (KeePassXC de böyle yapıyor; onun anahtar dosyası test örnekleri 2.4 sürümünde). Aradaki farklar okumayı etkilemez.
- Şifre: AES-256-CBC (`31c1f2e6-…`), ChaCha20 (`d6038a2b-…`, 12 baytlık IETF nonce), Twofish-CBC (`ad68f29f-…`). Başka bir şifre "desteklenmeyen şifre" olur.
- Anahtar türetme: AES-KDF (`c9d9f39a-…`), Argon2d (`ef636ddf-…`), Argon2id (`9e298b19-…`). KDBX 4'te AES-KDF sözlükte `R` ve `S`'dir.
- Sıkıştırma: yok ya da gzip. Başka değer bozuk dosyadır.
- İç akış: Salsa20 (2) ve ChaCha20 (3). Eski ArcFour (1) "desteklenmeyen biçim" olur; 0 (koruma yok) kabul edilir.
- Korumalı değerler belge sırasıyla çözülür. Kural, öğenin adına bakmaksızın `Protected="True"` niteliği taşıyan her öğedir; kayıt geçmişindeki değerler de akıştan pay alır. Geçmiş alınmasa da çözülür, yoksa sonraki değerler yanlış çıkar.
- **Doğrulama sırası.** KDBX 4'te önce başlığın SHA-256'sı (bozuk dosya), sonra HMAC'i (yanlış anahtar) denetlenir; her blok şifresi çözülmeden önce HMAC'iyle doğrulanır. KDBX 3.1'de CBC dolgusu ve `StreamStartBytes` yanlış anahtarı, blok özetleri bozulmayı yakalar. XML'deki `Meta/HeaderHash` varsa başlığın SHA-256'sıyla karşılaştırılır; tutmazsa dosya bozuk sayılır.
- Hiçbir kayıt, bütün dosya doğrulanmadan gösterilmez.

### Anahtar

- **Bileşik anahtar:** `SHA-256(SHA-256(parola UTF-8) ‖ anahtar dosyasının anahtarı)`; bileşenlerden biri olmayabilir. Boş parola "parola yok" ile aynı değildir: boş parola da `SHA-256("")` bileşeni ekler. Kullanıcı bunu ayırt edemez, bu yüzden:
  - Kutu doluysa parola bileşeni eklenir.
  - Kutu boş ve anahtar dosyası yoksa boş parola bileşeni eklenir (KeePassXC uyarıyla da olsa boş parolalı kasaya izin veriyor). **Aç** hep etkindir.
  - Kutu boş ve anahtar dosyası varsa önce yalnızca anahtar dosyasıyla denenir, tutmazsa boş parola bileşeniyle bir kez daha. İkinci deneme yeni bir anahtar türetmesi demektir, süre iki katına çıkar; bu durum nadir.
- **Anahtar dosyası** KeePass'ın kuralıyla:
  1. XML ve `KeyFile/Meta/Version` 1.0: `Key/Data` Base64, 32 bayt.
  2. XML ve 2.0: `Key/Data` onaltılık (boşluklar atılır), 32 bayt; `Hash` niteliği SHA-256'nın ilk 4 baytı, tutmazsa "anahtar dosyası bozuk".
  3. Tam 32 bayt: olduğu gibi.
  4. Tam 64 onaltılık karakter: çözülür.
  5. Başka her şey: dosyanın SHA-256'sı.

  Anahtar dosyası en çok 16 MiB okunur.

### Kripto nerede

| İş | Yer | Gerekçe |
|---|---|---|
| SHA-256, SHA-512, HMAC-SHA-256 | Dart, `crypto` (bugün de var) | |
| AES-256-CBC, Twofish-CBC, ChaCha20, Salsa20 | Dart, `pointycastle` (yeni bağımlılık, MIT) | Birkaç megabaytlık iş; bilgisayardaki testlerle telefon aynı kod. |
| AES-KDF | Kotlin, `javax.crypto` `AES/ECB/NoPadding` | İşlemcinin AES komutlarıyla; saf Dart'tan çok daha hızlı. |
| Argon2d, Argon2id | C, Argon2 başvuru uygulaması, JNI ile | Çok iş parçacıklı; bellek Java yığınının dışında. |

- Kotlin tarafı Pigeon'daki `ImportCryptoApi`'ye eklenen iki çağrıdır: `aesKdf(seed, key, rounds)` ve `argon2(type, password, salt, iterations, memoryKiB, parallelism, version, secret, associatedData)`. İkisi de Pigeon'un arka plan iş kuyruğunda çalışır (`@TaskQueue`); ana iş parçacığı donmaz. İkisi de 32 bayt döndürür. AES-KDF dönüşü KeePass'ın tanımıyla zaten SHA-256'dan geçmiştir.
- Argon2 kaynağı `android/third_party/argon2/` altına değiştirilmeden konur (yalnızca `src/argon2.c`, `core.c`, `ref.c`, `thread.c`, `encoding.c`, `blake2/` ve `include/argon2.h`). Hangi sürüm olduğu, kaynağın özeti ve lisansı yanındaki `README.md`'de yazar (SQLite'taki gibi). Uygulama modülünde CMake ile derlenir; küçük bir JNI dosyası (`argon2_jni.c`) `argon2_ctx`'i çağırır. İş parçacığı sayısı `min(parallelism, işlemci sayısı)`; sonuç iş parçacığı sayısından bağımsızdır.
- Kotlin Argon2'nin hata kodunu ayırır: bellek ayrılamadıysa (`ARGON2_MEMORY_ALLOCATION_ERROR`) ya da Java belleği yetmediyse (`OutOfMemoryError`) Dart'a "bellek yetmedi" olarak gelir. İş parçacığı açılamadıysa (`ARGON2_THREAD_FAIL`) ya da yerel kütüphane yüklenemediyse (`LinkageError`) "bu telefonda açılamadı" (`KdbxDeviceFailure`) denir; bunlar dosyanın değil telefonun sorunu. Yalnızca dosyadan gelen geçersiz parametre bozuk dosyadır (1.11.0, [#180](https://github.com/aaudraa/KeyKey/issues/180)).
- `KdbxKdf` diye bir Dart arayüzü vardır. Uygulamada `PlatformKdbxKdf` (Pigeon), bilgisayardaki testlerde `pointycastle` ile çalışan `DartKdbxKdf` verilir. `DartKdbxKdf` yalnızca `test/` altındadır, uygulamaya girmez; `pointycastle` ise uygulamada da şifre çözmede kullanıldığı için normal bağımlılıktır.

### Sınırlar

Dosya güvenilmeyen veridir; kötü niyetli bir dosya cihazı dakikalarca meşgul edememeli ve belleği tüketememelidir.

| Değer | Sınır | Neden |
|---|---|---|
| `.kdbx` dosyası | 32 MiB | Eki çok olan kasalar 10 MiB'ı aşabiliyor. CSV/JSON'un 10 MiB sınırı değişmez. Gözden geçirmede 64 MiB'tan indirildi: dosya Kotlin'den Pigeon'la geçerken Java yığınında birkaç kopya olur (yığın sınırı 192 MB olan telefonlar). |
| Açılmış XML | 64 MiB | gzip bombası. |
| Argon2 belleği | 1 GiB | KeePassXC'in arayüzündeki en büyük değer 4 GiB ama telefonlar bunu ayıramaz; 1 GiB'ı aşan dosya "telefon için fazla bellek istiyor" mesajıyla açılmaz. |
| Argon2 geçiş sayısı | 1–1000 | |
| Argon2 paralellik | 1–64 | |
| AES-KDF turu | 1–1.000.000.000 | Telefonda yaklaşık on dakika. KeePass'ın "1 saniye" ayarı bugünkü bilgisayarlarda on milyonlarca tur verir. |
| Başlık alanı, sözlük değeri | 1 MiB | |
| Blok | 64 MiB | |

Sınırı aşan değer "bu dosya telefonda açılamayacak kadar ağır ayarlanmış" olarak söylenir, bozuk dosya diye değil.

### Kayıtlar

- **Kayıt adı** `Title`; boşsa adresin alan adı, o da yoksa kullanıcı adı, o da yoksa "Adsız".
- **Kullanıcı adı** `UserName`, **parola** `Password`, **not** `Notes` (satır sonları `\n`).
- **Adresler:** `URL`, sonra KeePassXC ve Keepass2Android'in ek adres alanları (`KP2A_URL`, `KP2A_URL_1`, …) sırasıyla. Bugünkü kural sürer: `androidapp://` gibi uygulama adresleri alınmaz.
- **Klasör:** grubun yolu, kök grup atılarak `/` ile birleştirilir (KeePassXC CSV'sindeki kural). Kök gruptaki kayıtların klasörü yoktur.
- **Çöp kutusu:** `Meta/RecycleBinEnabled` doğruysa `Meta/RecycleBinUUID` grubu ve alt grupları alınmaz; sayıları önizlemede söylenir.
- **2FA:** sırayla ilk bulunan alınır, kullanılan alanlar özel alan olarak tekrar eklenmez.
  1. `otp` (KeePassXC, KeePassDX): `otpauth://` bağlantısı.
  2. KeePass 2.47+'nın `TimeOtp-Secret-Base32` (ya da `-Hex`, `-Base64`, `TimeOtp-Secret`) ile `TimeOtp-Algorithm` (`HMAC-SHA-1/256/512`), `TimeOtp-Length`, `TimeOtp-Period`. Bunlardan `otpauth://` bağlantısı kurulur.
  3. Eski KeePassXC'in `TOTP Seed` ve `TOTP Settings` (`30;6`, ya da Steam için `30;S`).

  Okunamayan 2FA bugünkü kuralla sayılır ve önizlemede söylenir. 2FA hesabı kayda bağlanır.
- **Özel alanlar:** yukarıdakiler dışındaki her `String` alanı özel alan olur; `Protected="True"` ise gizli. KeePassXC'in iç alanları (`KPEX_…`, `_etm_…`) alınmaz.
- **Alan başvuruları:** `{REF:<alan>@I:<UUID>}` biçimindeki başvurular (KeePass'ın aynı parolayı iki kayıtta tutma yolu) aynı dosyadaki kaydın alanıyla değiştirilir; `<alan>` T, U, P, A ya da N olabilir. Başka arama türleri (`@T:`, `@U:` …) ve çözülemeyen başvurular olduğu gibi kalır. Başvuru zinciri en çok 10 adım izlenir. Her (kayıt, alan) bir kez çözülür ve sonucu saklanır; 64 KiB'ı aşan sonuç yerine başvurunun kendisi kalır, böylece hazırlanmış bir dosya üstel iş yaptıramaz. Parolaya başvuran (`{REF:P@…}`) korumasız bir alan da gizli alan olur. Gizli alanı olan, yalnızca notu olan kayıt güvenli not değil kayıt olarak gelir: güvenli notta gizli alan yok, değer not metninde açık görünürdü (1.11.0).
- **Güvenli not:** kullanıcı adı, parola, adres ve 2FA'sı olmayan ama notu olan kayıt güvenli not olur (ad ve metin). Hiçbir alanı olmayan kayıt atlanır ve atlananlara sayılır.
- Bugünkü kurallar aynen geçerli: yinelenen kayıtların seçilmemiş gelmesi, 64 KiB'ı aşan notun atlanması, kayıtların ekleme anında şifrelenmesi.

### Bellek

- Dosyanın baytları, anahtar dosyası, bileşik anahtar, dönüştürülmüş anahtar, ana anahtar, HMAC anahtarları ve çözülmüş veri `Uint8List` olarak tutulur ve işi bitince sıfırlanır. Kotlin'de de dizi dönmeden önce kopyalar sıfırlanır; C tarafında Argon2'nin kendi silme bayrakları (`ARGON2_FLAG_CLEAR_PASSWORD`, `ARGON2_FLAG_CLEAR_SECRET`) açıktır, bellek bloğu Argon2'nin kendisi tarafından silinir.
- XML ayrıştırıcısı ve kayıt alanları Dart `String`'dir; bugünkü sınır (güvenlik tasarımı, [Bellek](guvenlik-tasarimi.md#bellek)) burada da geçerli.
- Hiçbir şey diske yazılmaz; anahtar dosyası da `.kdbx` de önbelleğe kopyalanmadan belge seçiciden doğrudan okunur.

### Hata türleri

`KdbxException` alt türleri, her biri kendi mesajıyla:

| Tür | Ne zaman | Mesaj (kısa) |
|---|---|---|
| `KdbxWrongKey` | HMAC, `StreamStartBytes` ya da dolgu tutmadı | Parola ya da anahtar dosyası yanlış (YubiKey / Windows hesabı notuyla) |
| `KdbxUnsupported` | Eski biçim, bilinmeyen şifre, KDF, iç akış | Bu KeePass dosyası desteklenmeyen bir ayar kullanıyor: <ne> (dile bağlı olmayan ad: `KDBX 5`, `Argon2 0x11`, UUID; iç akış için "iç akış şifresi 4" ekranın dilinde) |
| `KdbxDeviceFailure` | Yerel kod çalışmadı (kütüphane, iş parçacığı) | Bu dosya bu telefonda açılamadı … |
| `KdbxTooHeavy` | Sınırı aşan KDF ya da boyut | Telefonda açılamayacak kadar ağır ayarlanmış |
| `KdbxOutOfMemory` | Argon2 bellek ayıramadı | Telefonun belleği yetmedi |
| `KdbxCorrupt` | Başka her şey | Dosya bozuk |
| `KdbxKeyFileCorrupt` | 2.0 anahtar dosyasının özeti tutmadı | Anahtar dosyası bozuk |

### Testler

- **Gerçek dosyalar.** [pykeepass](https://github.com/libkeepass/pykeepass) (GPL-3.0) ve [KeePassXC](https://github.com/keepassxreboot/keepassxc) (GPL-2.0 ya da GPL-3.0) test klasörlerindeki dosyalar `test/fixtures/kdbx/` altına değiştirilmeden konur; kaynak commit'i, özetleri ve parolaları yanındaki `KAYNAKLAR.md`'de. Bunlarla bütün şifre, KDF, sıkıştırma ve anahtar dosyası türleri kapsanır. Ayrıca KeePassXC'in kendi komut satırı aracıyla gruplar, çöp kutusu, TOTP, ek alan, korumalı alan, alan başvurusu ve ek içeren bir dosya oluşturulur (oluşturma adımları da `KAYNAKLAR.md`'de).
- **Saf işlevler:** başlık, sözlük, blok akışları, anahtar dosyası, kayıt eşleme ayrı ayrı sınanır.
- **Bozuk girdi:** her test dosyasının her baytı tek tek bozulunca okuyucu ya doğru hata türüyle reddeder ya da (başlığın korunmayan, yorum gibi bir alanıysa) aynı sonucu verir; hiçbir zaman başka bir istisna fırlatmaz ve sınırların üstünde bellek ayırmaz. Rastgele dosyalar da.
- **Cihaz testi:** `PlatformKdbxKdf`, RFC 9106'nın Argon2d ve Argon2id test vektörleriyle, KeePass'ın AES-KDF'si bilinen değerle ve test dosyalarının hepsiyle sınanır (Android 11 ve 17 emülatörleri). Bir de arayüzden: dosya seç, parola yaz, aç, önizleme, ekle.
- Bilgisayardaki `DartKdbxKdf` RFC 9106 vektörleriyle sınanır; iki uygulamanın aynı sonucu verdiği böylece iki ayağıyla bağlanır.

### Belgeler

- Güvenlik tasarımı: "Parola içe aktarma" tablosuna KeePass satırı, KDBX okuyucusunun kuralları ve sınırları; tehdit modelinde değişiklik yok (yeni ağ, izin ya da dışa açık bileşen yok).
- Bağımlılıklar: `pointycastle`, Argon2 başvuru uygulaması. Lisanslar ekranına Argon2'nin lisansı.
- Kılavuz (`kullanim.md`): KeePass'tan geçiş.
- CHANGELOG ve yol haritası.

## Uygulayana kalanlar

- Ekran metinlerinin son hâli (Türkçe ve İngilizce).
- `pointycastle`'ın hangi sınıflarının kullanılacağı (`AESEngine` ya da `AESFastEngine`, `CBCBlockCipher`, `ChaCha7539Engine`, `Salsa20Engine`, `TwofishEngine`); hız gerekmediği için sabit zamanlı olan tercih edilir.
- JNI ve CMake ayrıntıları; F-Droid derlemesinin yine bayt bayt aynı çıktığı yayın iş akışında denetlenir.
- Ölçülürse anahtar türetme süresine göre ilerleme metninin ayarlanması.

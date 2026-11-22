# KeyKey Güvenlik Tasarımı

Bu belge KeyKey'in verileri nasıl şifrelediğini bayt düzeyinde anlatır. Kod bu belgeye göre yazılır; ikisi çelişirse bu bir hatadır. Dışarıdan inceleyenler için de başlangıç noktasıdır, eleştirileri [özel güvenlik bildirimiyle](https://github.com/aaudraa/KeyKey/security/advisories/new) veya tasarım sorusuysa issue ile iletebilirsin.

**Durum:** Biçim sürümü 1, KeyKey 1.0 ile yayınlandı. Bağımsız bir denetimden geçmedi. Biçim bundan sonra değişirse eski dosyalar okunmaya devam etmeli; bu, 1.0'dan sonraki her biçim değişikliğinin şartıdır.

## Hedefler

**Korumak istediklerimiz** (tam liste [tehdit modelinde](#tehdit-modeli)):

- Kasa dosyası veya yedek ele geçse bile, ana parola güçlüyse içerik okunamamalı.
- Dosyayı ele geçiren hangi sitelerde hesabın olduğunu görememeli.
- Dosya değiştirilirse bu fark edilmeli; bir kaydın şifreli verisi başka bir kaydın yerine konamamalı.

**Korumadıklarımız:** Kasa açıkken root yetkili veya zararlı yazılım bulaşmış cihaz; zayıf ana parola; ana parola ve kurtarma anahtarının birlikte kaybı.

**İlke:** Kendi kriptomuzu yazmıyoruz. Bütün temel işlemler [libsodium](https://libsodium.org) 1.0.22'den gelir, biz yalnızca onları birleştiririz.

## Tehdit modeli

### Korunan varlıklar

| Varlık | Nerede durur |
|---|---|
| Kayıtlar: parolalar, kullanıcı adları, notlar, 2FA gizli anahtarları, adresler, kart bilgileri, güvenli notlar | Diskte şifreli; kasa açıkken çözülmüş halde bellekte |
| Ana parola | Hiçbir yerde saklanmaz; yazılırken klavyeden ve bellekten geçer |
| Kurtarma anahtarı | Kullanıcının kâğıdında ya da kendi seçtiği yerde (dosya, başka bir parola yöneticisi); uygulamada saklanmaz |
| Kasa anahtarı | Diskte yalnızca sarılmış halde; kasa açıkken korumalı bellekte |
| Kopyalanan değer | Panoda en fazla 30 saniye ([Pano](#pano)) |
| Yedek dosyası | Kullanıcının seçtiği konumda (Drive gibi), şifreli |
| Hangi sitelerde hesap olduğu | Kayıtların içinde şifreli; kayıt sayısı ve zamanları görünür ([bilinen sınırlar](#bilinen-sınırlar)) |

### Saldırganlar

| Saldırgan | Ne yapabilir | KeyKey'in koruması | Sonuç |
|---|---|---|---|
| Kilitli telefonu bulan veya çalan | Ekran kilidini aşamaz; adli araçlarla diski kopyalayabilir | Android dosya şifrelemesinin üstüne kasa şifrelemesi; anahtar ana paroladan türetilir, diskte durmaz | Korunur |
| Kilidi açık telefonu kısa süre eline geçiren, KeyKey kilitli | Uygulamayı açar, parola dener, yeni parmak izi ekleyebilir | Ana parola veya parmak izi gerekir; hatalı denemede artan bekleme; yeni parmak izi eklenince parmak iziyle açma kapanır | Korunur, parola güçlüyse |
| Kilidi açık telefonu eline geçiren, KeyKey açık | Ekrandaki kayıtları ve parolaları görür, kopyalar | Arka plana geçince hemen (kullanıcı seçtiyse 30 saniye ya da 1 dakika sonra), 5 dakika dokunulmazsa kilitlenir. Ana parolayı değiştirmek mevcut parolayı, şifresiz dışa aktarma kimlik doğrulamayı ister; 2FA kodları için ek onay isteğe bağlıdır | Kısmen: açık kasadaki parolalar görülebilir |
| Yedek dosyasını ele geçiren (ör. Drive hesabı ele geçmiş) | Dosyayı kendi bilgisayarında sınırsız deneyebilir | Argon2id; kayıtlar dosyanın içinde de ayrıca şifreli; kayıt sayısı ve türleri gizli | Korunur, parola güçlüyse. Eski yedekler eski parolayla açılır |
| Diskteki kasa dosyasına yazabilen | Dosyayı okur, değiştirir, eskisiyle değiştirir | Her kayıt kimliğine ve türüne bağlı şifreli; değiştirilen kayıt açılmaz | Okuyamaz; ama geri alma ve silme fark edilmez ([bilinen sınırlar](#bilinen-sınırlar)) |
| Cihazdaki izinsiz zararlı uygulama | Kendi alanında çalışır, araya girmeye çalışır | Android uygulama yalıtımı; kasa dosyası uygulamanın özel klasöründe; dışa açık bileşen yalnızca ana ekran ve sistemin bağlandığı doldurma servisi | Korunur |
| Panoyu okuyan uygulama | Kopyalanan parolayı okumaya çalışır | Android 10'dan beri arka plandaki uygulamalar panoyu okuyamaz; değer hassas işaretli, 30 saniye sonra silinir | Kısmen: etkin klavye ve o an öndeki uygulama görebilir |
| Ağdaki saldırgan: aynı Wi-Fi, otelin giriş sayfası, internet sağlayıcısı | Sızıntı kontrolünün ve senkronun trafiğini görür, engeller ya da değiştirmeye çalışır | Trafikte parola yok, yalnızca 5 karakterlik önekler; senkronda yalnızca şifreli dosya, Basic kimlik bilgisi yalnızca TLS içinde; yalnızca HTTPS ve sistem sertifikaları; https dışı adres reddedilir; yönlendirme izlenmez; biçime uymayan yanıt hata verir, "sızıntı yok" sayılmaz ([Sızıntı kontrolü](#sızıntı-kontrolü), [Senkron](#senkron)) | Korunur. Denetimi ya da eşitlemeyi engelleyebilir: sonuç "denetlenemedi" ya da eşitleme hatası olur |
| Have I Been Pwned ya da önündeki Cloudflare | IP adresini, sorulan önekleri ve zamanı görür; yanlış yanıt verebilir | k-anonimlik: yalnızca özetin ilk 5 karakteri; dolgulu yanıt; kullanıcı dokunmadan istek yok; hesap, çerez ya da kimlik yok | Kısmen: önek kümesi bir kasanın parmak izi olabilir; yanlış "görülmedi" yanıtı fark edilemez ([bilinen sınır 9](#bilinen-sınırlar)) |
| WebDAV sunucusu ya da sunucuyu ele geçiren | Dosya adlarını (cihaz kimlikleri), boyutları, değişme zamanlarını ve IP adresini görür; dosyaları silebilir, eskileriyle değiştirebilir, saklayabilir; ana parolayı çevrimdışı deneyebilir | Dosya yedekle aynı biçimde şifreli (Argon2id, XChaCha20-Poly1305); birleştirme yalnızca daha yeniyi uygular ve silme kayıtları yerelde durur; 24 saatten ileri tarihli dosya alınmaz ([Senkron](#senkron)) | Korunur, parola güçlüyse. Eski ya da saklanan dosya yalnızca değişikliklerin yayılmasını geciktirir ([bilinen sınır 12](#bilinen-sınırlar)) |
| Kullanılmayan bir telefonun senkron dosyası ya da sunucunun dosya geçmişi | Eski üst bilgiyle, yani eski parolayla açılır ve kasa anahtarını verir; o anahtar sonraki dosyaları da açar | Kasa anahtarı parola değişince dönmez ([bilinen sınır 5](#bilinen-sınırlar)) | **Korunmuyor**: parola değişikliği iptal değildir ([bilinen sınır 13](#bilinen-sınırlar)) |
| Çalınan ya da kaybolan telefon, kasası açılmış, senkron açık | Senkron bilgileri kasada olduğu için eşitlemeye devam eder, yeni kayıtları alır | Otomatik kilit; o telefonun uygulama parolası sunucuda iptal edilince eşitleme durur ([kılavuz](kullanim.md)) | Kısmen: iptal edilene kadar yeni kayıtları alır |
| Kötü niyetli doldurma hedefi: sahte uygulama, sahte site, WebView içeren uygulama | Kayıtlı parolayı kendine doldurtmaya çalışır | Uygulamada paket adı ve imza, web'de Public Suffix List ile alan adı; `webDomain` yalnızca güvenilen tarayıcılardan; şüpheli durumda uyarı ve ek onay ([Otomatik doldurma](#otomatik-doldurma)) | Büyük ölçüde korunur |
| Ekran görüntüsü, ekran kaydı, son uygulamalar önizlemesi | Ekranı kaydeder | `FLAG_SECURE`; son uygulamalarda önizleme kapalı | Korunur |
| Bindirme (overlay) izni olan uygulama | Saydam pencereyle kullanıcıya istemediği bir şeye dokundurur (tapjacking) | Android 12+: KeyKey ekrandayken bindirmeler gizlenir. Android 11: örtülü noktadaki dokunuş düşürülür ([Arayüz koruması](#arayüz-koruması)) | Korunur |
| Erişilebilirlik izni olan zararlı uygulama | Ekrandaki metni okur, dokunuş üretir; `FLAG_SECURE` bunu engellemez | Android 14+: pencere hassas işaretli, yalnızca erişilebilirlik araçları okuyabilir ([Arayüz koruması](#arayüz-koruması)) | Android 14+ korunur; **11-13 korunmaz** |
| Kötü niyetli klavye | Yazılan her şeyi, ana parola dahil, görür | Gizli alanlarda öneri ve öğrenme kapalı; bu yalnızca dürüst klavyeleri etkiler. "Normal klavye" ayarı açıksa adlar ve siteler dürüst klavyenin sözlüğüne de girebilir ([Klavye](#klavye)) | **Korunmuyor** |
| Root yetkili veya zararlı yazılım bulaşmış cihaz, kasa açık | Belleği okur | Anahtarlar korumalı bellekte, ama çözülmüş kayıtlar Dart belleğinde ([Bellek](#bellek)) | **Korunmuyor** |
| Ana parola ve kurtarma anahtarı birlikte kayboldu | — | Bilinçli olarak arka kapı yok | Veri geri gelmez |
| Bağımlılık veya derleme ortamı ele geçmiş (tedarik zinciri) | Uygulamaya kötü kod sokar | Kilitli bağımlılık sürümleri; `sqlite3` hazır kütüphanesi sabit özetle denetlenir; CI'da gizli bilgi taraması; denetim [#86](https://github.com/aaudraa/KeyKey/issues/86), yeniden üretilebilir derleme Faz 9 | Kısmen |

**Kapsam dışı:** Zorla parola söyletme, omuz üstünden bakma, işletim sistemindeki açıklar ve donanım saldırıları.

**Ağ:** 1.0-1.5'in `INTERNET` izni yoktu. 1.6.0'dan beri kullanıcının başlattığı [sızıntı kontrolü](#sızıntı-kontrolü), 1.8.0'dan beri kullanıcının açtığı [senkron](senkron.md) ağa çıkar; senkronda sunucuya yalnızca uçtan uca şifreli dosya gider. Ağ kodu iki dosyada durur ve bunu bir test denetler. Kasa, yedek, otomatik doldurma, pano ve diğer bütün özellikler ağa çıkmaz; hesap ve sunucu yoktur.

## Algoritmalar

| Amaç | Algoritma | Parametre |
|---|---|---|
| Paroladan anahtar | Argon2id (`crypto_pwhash`) | Tuz 16 bayt, çıktı 32 bayt |
| Şifreleme | XChaCha20-Poly1305 IETF | Anahtar 32, nonce 24, etiket 16 bayt |
| Alt anahtar | HKDF-SHA256, yalnızca expand aşaması | Çıktı 32 bayt |
| Sağlama toplamı | BLAKE2b (`crypto_generichash`) | Kurtarma anahtarı metni için |
| Rastgelelik | `randombytes` | İşletim sisteminin güvenli kaynağı |

XChaCha20'nin 24 baytlık nonce'u rastgele üretim için yeterince uzundur, tekrar olasılığı pratikte yok sayılabilir. Bu yüzden sayaç tutmak gerekmez.

## Anahtar hiyerarşisi

```text
Ana parola ── Argon2id ──────────► Parola anahtarı ─────┐
Kurtarma anahtarı ── HKDF ───────► Kurtarma anahtarı KEK ┼─ sarar ─► Kasa anahtarı
Parmak izi ── Android Keystore ─────────────────────────┘                │
(Faz 3)                                                             HKDF-SHA256
                                                             ┌───────────┴──────────┐
                                                       Kayıt anahtarı          2FA anahtarı
```

**Kasa anahtarı:** Kasa oluşturulurken üretilen rastgele 32 bayt. Diskte yalnızca sarılmış halde durur ve hiç değişmez. Parola değişince yalnızca o sarmalama yenilenir, kayıtlar yeniden şifrelenmez.

**Alt anahtarlar:** Kasa anahtarı doğrudan veri şifrelemede kullanılmaz. Kasa anahtarı zaten düzgün dağılımlı olduğu için HKDF'nin extract aşaması atlanır:

| Anahtar | HKDF bağlamı |
|---|---|
| Kayıt anahtarı | `keykey/v1/records` |
| 2FA anahtarı | `keykey/v1/otp` |

### Argon2id parametreleri

| | Bellek | Geçiş |
|---|---|---|
| **Taban** (altına inilmez) | 64 MiB | 3 |
| **Tavan** (üstü dosya okunurken reddedilir) | 1 GiB | 32 |

- libsodium'da paralellik her zaman 1'dir.
- Kalibrasyon, kasa oluşturulurken tabanla bir ölçüm yapar. Cihaz hedef süreden (1 saniye) çok hızlıysa geçiş sayısını en fazla 12'ye kadar artırır, belleğe dokunmaz. Bellek sabit tutulur, çünkü otomatik doldurma ekranı da aynı parametrelerle çalışacak ve düşük bellekli cihazlarda uygulamanın kapatılmaması gerekiyor.
- Tavan, değiştirilmiş bir dosyanın uygulamayı belleksiz bırakmasını engeller.
- Parametreler üst bilgide saklanır, yani kasa oluşturulduğu cihazdan bağımsız açılır.

Parola, UTF-8 baytları olarak olduğu gibi kullanılır, Unicode normalleştirmesi yapılmaz. Android klavyeleri Türkçe harfleri tek karakter olarak üretir. iOS sürümü gündeme gelirse bu karar yeni bir KDF sürümüyle gözden geçirilmeli.

#### Ölçülen süreler

Taban parametrelerle (64 MiB, 3 geçiş) cihaz başına üç ölçüm yapıldı. Değerler `integration_test/crypto_test.dart` testinin `KKOLCUM` çıktısından alındı.

| Cihaz | Android | Süre (ms) | Kalibrasyonun seçtiği geçiş |
|---|---|---|---|
| Samsung Galaxy S20 FE (SM-G780G, Snapdragon 865) | 13 | 233, 233, 235 | 12 |
| Emülatör `KeyKey_API_30` | 11 | 117, 131, 152 | 12 |
| Emülatör `KeyKey_API_34` | 14 | 104, 102, 106 | 12 |
| Emülatör `KeyKey_API_36` | 16 | 102, 106, 114 | 12 |
| Emülatör `Medium_Phone_API_37.0` | 17 | 97, 102, 98 | 12 |

- S20 FE'de kalibrasyonun seçtiği 12 geçiş 864 ms sürdü ([denetim belgesi](guvenlik-denetimi.md#gerçek-telefon)); hedef 1 saniyenin altında.
- Emülatörler bilgisayarın `x86_64` işlemcisinde çalıştığı için telefon süresini göstermez.
- Gerçek telefon ölçümü tek bir cihazdan geliyor. Bu cihaz 2020'nin üst seviye çipini taşıyor ve test debug derlemesiyle çalıştı. Düşük donanımlı telefonlar ölçülmedi. Kalibrasyon tabanın altına inmediği için çok yavaş cihazlarda kasa açmak hedef süreyi aşabilir.
- Bu ölçüm yalnızca Argon2id süresini kapsar. Android Keystore ve biyometrinin gerçek telefondaki davranışı [denetim belgesinde](guvenlik-denetimi.md#gerçek-telefon).

### Kurtarma anahtarı

Rastgele 32 bayt. Kasa oluşturulurken bir kez gösterilir, uygulama saklamaz.

**Metin biçimi:** `anahtar (32 bayt) || sağlama (2 bayt)`, Crockford Base32 ile kodlanır ve 5'erli gruplanır. Toplam 55 karakterdir.

- **Sağlama:** `BLAKE2b-256("keykey/v1/recovery-checksum" || anahtar)` sonucunun ilk 2 baytı. Yazım hatalarını kriptoya hiç ulaşmadan yakalar. Anahtarın gücünü azaltmaz, çünkü anahtarın kendisi zaten metnin içindedir.
- **Okuma kolaylığı:** Boşluk ve tire yok sayılır, büyük küçük harf ayrımı yapılmaz. `O` → `0`, `I`/`L` → `1` kabul edilir. Türkçe klavye için `ı` ve `İ` de `1` sayılır.
- **KEK:** `HKDF-Expand(anahtar, "keykey/v1/kek/recovery", 32)`.

**Yenileme:** Kasa açıkken Ayarlar → Güvenlik → **Yeni kurtarma anahtarı** ile yenisi üretilir. Tasarım ve gerekçeler: [yeni kurtarma anahtarı](kurtarma-anahtari-yenileme.md).

1. Ana parola kilit ekranının yolundan doğrulanır: hatalı deneme sayacı ve bekleme burada da işler. Kilidi açık telefonu eline alan biri, ana parolayı bilmeden kasayı açan kalıcı bir sır alamamalı.
2. Rastgele 32 baytlık yeni anahtar üretilir ve kasa anahtarı onunla, yeni nonce'la, aynı AD ile sarılır. Yeni yuva yalnızca bellekte durur, anahtar bir kez gösterilir.
3. Kullanıcı anahtarı geri yazar; yuva gerçekten açılarak doğrulanır. Ancak o zaman üst bilgi tek bir yazmayla güncellenir. Yazılan üst bilgi oturumdaki güncel üst bilgiden kurulur, yalnızca `slots.recovery` değişir.
4. Vazgeçilirse ya da kasa kilitlenirse hiçbir şey yazılmaz. Kasa anahtarı, parola yuvası ve parmak izi yuvası değişmez; üst bilgi biçimi aynıdır.

## Ek doğrulama verisi (AD)

Şifreli veri, ait olduğu bağlama AEAD'in ek doğrulama verisiyle bağlanır. AD alanları belirsizlik kalmasın diye uzunluk önekiyle birleştirilir:

```text
AD = alan1 || alan2 || ...
alan = uzunluk (4 bayt, büyük uçlu) || içerik
```

Sayılar 8 baytlık büyük uçlu olarak yazılır, metinler UTF-8'dir.

## Kasa üst bilgisi

Üst bilgi kasanın açılması için gereken her şeyi tutar ve JSON olarak saklanır. JSON seçildi, çünkü ek ayrıştırıcı kodu gerektirmez ve denetleyen biri tarafından okunabilir. İkili alanlar Base64'tür (dolgulu, RFC 4648).

```json
{
  "version": 1,
  "vaultId": "<16 bayt>",
  "kdf": {
    "algorithm": "argon2id13",
    "opsLimit": 3,
    "memLimit": 67108864,
    "salt": "<16 bayt>"
  },
  "slots": {
    "password": { "nonce": "<24 bayt>", "cipherText": "<48 bayt>" },
    "recovery": { "nonce": "<24 bayt>", "cipherText": "<48 bayt>" }
  }
}
```

Okurken doğrulama katıdır: bilinmeyen `version` ve `algorithm`, eksik alan, yanlış uzunluk, taban altı veya tavan üstü parametre reddedilir. Bilinmeyen ek alanlar da reddedilir.

**Sarmalama:** `XChaCha20-Poly1305(KEK, rastgele nonce, kasa anahtarı, AD)`

| Yuva | AD alanları |
|---|---|
| `password` | `keykey/v1/wrap`, `vaultId`, `password`, `argon2id13`, `opsLimit`, `memLimit`, `salt` |
| `recovery` | `keykey/v1/wrap`, `vaultId`, `recovery` |

KDF parametreleri ve tuz AD'de olduğu için üst bilgide değiştirilirlerse parola yuvası açılmaz.

## Kayıt biçimi

Veritabanında şifresiz kalan alanlar yalnızca kayıt kimliği, tür, zaman damgaları ve biçim sürümüdür. Başlık, kullanıcı adı ve URL dahil geri kalan her şey şifreli verinin içindedir.

```text
kayıt = sürüm (1 bayt, 0x01) || nonce (24 bayt) || şifreli metin ve etiket
```

- **Düz metin:** Şifrelemeden önce 256 baytlık blok katlarına dolgulanır (`sodium_pad`). Böylece şifreli verinin uzunluğu parolanın uzunluğunu ele vermez.
- **Anahtar:** Tür `otp` ise 2FA anahtarı, diğerlerinde kayıt anahtarı.
- **AD alanları:** `keykey/v1/record`, `vaultId`, kayıt kimliği (16 bayt), tür.

### Parola kaydının içeriği

Tür `login` olan kayıtların düz metni, şifrelemeden önce şu JSON'dur:

```json
{
  "version": 2,
  "name": "Örnek",
  "username": "kullanici@example.com",
  "password": "...",
  "urls": ["https://example.com"],
  "apps": [{ "package": "com.example.app", "certsSha256": ["<64 onaltılık hane>"] }],
  "notes": "",
  "customFields": [{ "name": "PIN", "value": "...", "hidden": true }],
  "favorite": false,
  "folder": null,
  "trashedAt": null,
  "passwordHistory": [{ "password": "...", "changedAt": 1730000000000 }]
}
```

- Favori, klasör, çöp kutusu ve geçmiş de şifreli içeriktedir. Dosyayı ele geçiren biri kayıtların nasıl düzenlendiğini göremez. Klasörlerin ayrı bir tablosu yoktur, klasör listesi kayıtlardan çıkarılır.
- Zaman değerleri 1970'ten beri geçen milisaniyedir.
- Okurken doğrulama katıdır: bilinmeyen `version`, eksik alan, fazla alan veya yanlış tür reddedilir.
- **Sürüm 2** (Faz 6) `apps` alanını ekledi: kaydın doldurulabileceği Android uygulamaları. Her uygulama paket adı ve imza sertifikalarının SHA-256 özetleriyle (küçük harf onaltılık, birden fazla imzacı varsa hepsi) tutulur; eşleşme için hepsi tutmalıdır. Ayrıntılar [Otomatik doldurma](#otomatik-doldurma) bölümünde. Sürüm 1 kayıtlar okunmaya devam eder ve `apps` boş sayılır; kayıt bir sonraki yazılışta sürüm 2 olur. Sürüm 1 okuyan eski bir uygulama sürüm 2 kaydı açamaz.
- **Parola geçmişi:** Parola değişince eskisi başa eklenir, en fazla 10 tane tutulur.
- **Çöp kutusu:** Silinen kayıt önce çöp kutusuna gider ve 30 gün sonra kasa açıkken kalıcı olarak silinir. Kalıcı silme de `secure_delete` ile yapılır.
- **Okunamayan kayıt:** Bir kayıt açılamazsa liste düşmez. Kayda dokunulmaz, kullanıcıya kaç kaydın okunamadığı söylenir.

### 2FA kaydının içeriği

Tür `otp` olan kayıtlar 2FA anahtarıyla şifrelenir. Düz metin şu JSON'dur:

```json
{
  "version": 1,
  "kind": "totp",
  "issuer": "Örnek",
  "account": "kullanici@example.com",
  "secret": "JBSWY3DPEHPK3PXP",
  "algorithm": "SHA1",
  "digits": 6,
  "period": 30,
  "counter": null,
  "loginId": null,
  "notes": "",
  "favorite": false,
  "trashedAt": null
}
```

| Alan | Kural |
|---|---|
| `kind` | `totp`, `hotp` veya `steam` (1.7.0). |
| `secret` | Gizli anahtar, RFC 4648 Base32, büyük harf ve dolgusuz. 1-256 bayt. |
| `algorithm` | `SHA1`, `SHA256` veya `SHA512`. |
| `digits` | 6, 7 veya 8; `steam` için tam olarak 5. |
| `period` | `totp` için 1-3600 saniye, `steam` için tam olarak 30, `hotp` için `null`. |
| `counter` | `hotp` için sıradaki sayaç değeri (0 veya daha büyük), `totp` ve `steam` için `null`. |
| `algorithm` (`steam`) | Tam olarak `SHA1`. Steam'in değerleri sabittir; farklı bir değer kaydı okunamaz yapar. |
| `loginId` | Eşleştirilen parola kaydının kimliği (32 karakter, küçük harf onaltılık) veya `null`. |

- Okurken doğrulama parola kaydındaki kadar katıdır. Ayrıca Base32 metni yazdığımız biçimde olmalıdır: küçük harf, dolgu, boşluk veya fazladan bit reddedilir.
- Çöp kutusu ve okunamayan kayıt kuralları parola kaydıyla aynıdır. Yanlışlıkla silinen 2FA hesabı servise girişi engelleyebileceği için hemen silinmez.
- `loginId`'nin gösterdiği kayıt silinmişse eşleşme yok sayılır.
- **Uyumluluk:** `steam` kaydını 1.6.0 ve öncesi tanımaz. 1.7.0 yedekleri [içerik sürümü 3](#yedek-biçimi) ile yazıldığı için eski sürüm onları "daha yeni yedek" diye açmaz, kullanıcıya güncellemesini söyler. Kasadaki kaydı ise okunamayan kayıt sayar ve dokunmaz. Kılavuz ve değişiklik günlüğü bunu söyler.

### Kart kaydının içeriği

Tür `card` olan kayıtlar (1.4.0) kayıt anahtarıyla şifrelenir. Düz metin şu JSON'dur:

```json
{
  "version": 1,
  "name": "Maaş kartı",
  "cardholder": "AD SOYAD",
  "number": "4111111111111111",
  "expMonth": 12,
  "expYear": 2028,
  "securityCode": "123",
  "pin": "",
  "notes": "",
  "favorite": false,
  "folder": null,
  "trashedAt": null
}
```

| Alan | Kural |
|---|---|
| `number` | Yalnızca rakam, gruplanmadan, en çok 19 hane. Boş olabilir. Luhn denetimi formda yalnızca uyarıdır; tutmayan numara da kaydedilir, çünkü bazı kartlar (yerel kartlar, eski numaralar) ona uymaz. |
| `expMonth`, `expYear` | İkisi birlikte sayı ya da ikisi de `null`. Ay 1-12, yıl dört haneli 2000-2099. Kart, son kullanma ayının sonunda süresi dolmuş sayılır. |
| `securityCode` | Yalnızca rakam, en çok 4 hane. Boş olabilir. |
| `pin` | Yalnızca rakam, en çok 12 hane. Boş olabilir. |

- Marka (Visa, Mastercard, American Express, Troy, Discover, JCB, UnionPay, Maestro, Diners Club) saklanmaz; her gösterimde numaranın ilk hanelerinden çıkarılır. İçe aktarılan yanlış bir marka bilgisi böylece kayda girmez.
- Okurken doğrulama parola kaydındaki kadar katıdır; kurala uymayan değer de reddedilir. Uygulama kurala uymayan bir kaydı yazamaz.
- Listede tam numara görünmez: marka, son dört hane ve son kullanma. Ayrıntıdaki kart görünümü de yalnızca son dört haneyi gösterir. Numara, güvenlik kodu ve PIN ayrıntı ekranında gizli gelir; kopyalanınca [pano](#pano) kuralı geçerlidir.
- Çöp kutusu ve okunamayan kayıt kuralları parola kaydıyla aynıdır.

### Not kaydının içeriği

Tür `note` olan kayıtlar (1.4.0) kayıt anahtarıyla şifrelenir. Düz metin şu JSON'dur:

```json
{
  "version": 1,
  "name": "Ev Wi-Fi",
  "text": "...",
  "favorite": false,
  "folder": null,
  "trashedAt": null
}
```

- `text` en çok 64 KiB'tır (UTF-8 bayt). Form sınırı aşan girişi kabul etmez ve bunu kullanıcıya söyler; okurken daha uzunu reddedilir.
- Listede not metni gösterilmez; not çoğu zaman sırrın kendisidir. Arama yalnızca ada ve klasöre bakar.
- Ayrıntı ekranında metin seçilebilir. Seçim menüsünde yalnızca **Kopyala** ve **Tümünü seç** vardır ve kopyalama [pano](#pano) kuralından geçer. Sistemin menüsü (Paylaş, Çevir, Ara gibi) gösterilmez, çünkü metni başka uygulamalara gönderir ve panoya süresiz yazar.
- Okurken doğrulama ve çöp kutusu kuralları parola kaydıyla aynıdır.

## Depolama

Kasa, uygulamanın özel klasöründe tek bir SQLite dosyasında (`keykey.db`) durur. Android yedeklemesi ve cihaz aktarımı kapalıdır. Dosyanın tamamı şifrelenmez, koruma kayıt düzeyindeki şifrelemeden gelir. Bu yüzden SQLCipher gerekmiyor ve şifresiz kalan alanlar yukarıdaki listeyle sınırlı kalıyor.

Kasanın dışında iki küçük dosya daha vardır, ikisi de şifresizdir ve kasayla ilgili hiçbir şey içermez:

- **Tema seçimi** (`theme`, içeriği `system`, `light` ya da `dark`): kilit ekranı da seçilen temayla açılsın diye. Okuyan biri yalnızca seçilen temayı öğrenir. Gerekçe [tema seçimi](tema-secimi.md) belgesinde.
- **Kullanım koşullarının kabulü** (`terms`, içeriği kabul edilen koşul sürümünün numarası, ör. `1`): koşullar kasa kurulmadan ve kilit açılmadan önce sorulduğu için kasanın içinde tutulamaz. Okuyan biri yalnızca koşulların kabul edildiğini öğrenir; bunu kasa dosyasının varlığı da zaten söyler. Dosya silinirse ya da bozulursa koşullar yeniden sorulur, başka bir şey değişmez. Koşullar: [kullanım koşulları](kosullar.md).

| Tablo | Alanlar | Not |
|---|---|---|
| `vault_meta` | `id` (her zaman 1), `header`, `password_changed_at`, `recovery_changed_at` | Üst bilgi, yukarıdaki JSON biçiminde. İki zaman (şema 2) parola ve kurtarma yuvasının son değiştiği an; [senkron](senkron.md) yuvaları bunlara bakarak birleştirir. 1.8.0'dan beri değişmediyse boştur. |
| `records` | `id` (16 bayt), `type`, `blob`, `created_at`, `updated_at` | `blob`, yukarıdaki kayıt biçimidir. |
| `tombstones` | `id` (16 bayt), `deleted_at` | Silme kayıtları (şema 2), aşağıda. |
| `biometric_slot` | `id` (her zaman 1), `iv` (12 bayt), `cipher_text` (48 bayt) | Yalnızca parmak izi açıksa satır vardır. |
| `unlock_state` | `id` (her zaman 1), `failed_attempts`, `last_failed_at` | Hatalı deneme sayacı. |

- **Tek işlem:** Üst bilgi değişiklikleri tek SQLite işleminde yazılır. Yarıda kalırsa eski üst bilgi geçerli kalır.
- **Silinen veri:** `secure_delete` açık ve `journal_mode` `DELETE`'tir, böylece eski sarmalama satırları dosyanın boş alanında kalmaz. Flash bellekte fiziksel silme yine de garanti edilemez, bu yüzden [bilinen sınırlardaki](#bilinen-sınırlar) sarmalama maddesi geçerlidir.
- **Silme kayıtları:** Bir kayıt kalıcı silinince (kalıcı silme, çöpü boşaltma, 30 günlük temizlik) satırla aynı işlemde kimliği ve silinme anı yazılır; aynı kimlikte daha yenisi varsa o kalır. İçerik, tür ve ad taşımaz. Senkron açık olmasa da yazılır, böylece senkron sonradan açılınca geçmiş silmeler bilinir; senkronda başka telefonun dosyası silinen kaydı geri getiremez. Silme kayıtları silinmez. Ayar kaydı için yazılmaz. Kasa yedekten değiştirilince eski kasanın silme kayıtları da silinir. Kayıtların zaman damgaları gibi şifresizdir: veritabanını okuyan, kaç kaydın ne zaman silindiğini görür ([bilinen sınırlar](#bilinen-sınırlar)).
- **İki ayrı sürüm:** Üst bilgi biçimi (`version`) ve veritabanı şeması (`schemaVersion`) birbirinden bağımsızdır. Şema 1.8.0'da 2 oldu (silme kayıtları ve yuva zamanları); şema 1 dosyası açılırken göç edilir, daha yeni şemadaki dosya açılmaz. Şema göçleri testlerle doğrulanır.

## Kasa oluşturma

1. Ana parola iki kez girilir. En az 10 karakter (Unicode kod noktası) olmalıdır, geri alınamayacağı ayrıca söylenir.
2. Güç göstergesi yalnızca kaba bir tahmindir: uzunluk, karakter çeşitliliği ve kısa bir sık kullanılan parola listesi. `zxcvbn` Dart 3 ile uyumlu olmadığı için kullanılmıyor.
3. Kalibrasyondan sonra kasa anahtarı ve yuvalar üretilir. Bu sonuç **yalnızca bellekte** tutulur.
4. Kurtarma anahtarı bir kez gösterilir ve kullanıcıya geri yazdırılır. Doğrulama metin karşılaştırmasıyla değil, yazılan anahtarla kurtarma yuvası gerçekten açılarak yapılır.
   - 55 karakteri elle yazmak zor olduğu için anahtar **kopyalanabilir** ve **metin dosyası olarak kaydedilebilir** (2026-11-17). Kopyalama güvenli panoyu kullanır: Android 13+ önizlemede göstermez, pano 30 saniye sonra temizlenir. Dosyayı Android'in belge oluşturma ekranıyla kullanıcı nereye isterse oraya kaydeder; ilk satırı anahtarı bulanın kasayı açabileceğini söyler, kaydedince "telefonda bırakma" uyarısı çıkar. Doğrulama adımı yapıştırmayı ve kaydedilen dosyadan okumayı kabul eder; dosyadan okunan baytlar okununca sıfırlanır.
   - **Ödün:** Telefonda bırakılan dosya ya da panodan başka bir uygulamaya yapıştırılan anahtar, kâğıttan daha kolay ele geçer. Anahtarın tek başına kasayı açtığı uyarıda açıkça yazar; KeyKey anahtarı yine hiçbir yerde saklamaz.
5. Doğrulama geçince `vault_meta` satırı yazılır ve kasa açık hale gelir.

**Yarım kasa olmaz:** Akış herhangi bir yerde yarıda kalırsa diskte hiçbir şey kalmaz, kullanıcı baştan başlar. `vault_meta` satırının varlığı, kasanın kurulu olduğunu gösteren tek işarettir.

Kurulum sırasında otomatik kilit çalışmaz, çünkü henüz kasa yoktur ve kurtarma anahtarını not etmek için başka uygulamaya geçmek normaldir.

## Kilit

Kasa üç durumdan birindedir: **kurulmamış**, **kilitli** veya **açık**. Kasa anahtarı yalnızca açıkken bellekte durur.

### Hatalı parola beklemesi

| Art arda hatalı deneme | Sonraki denemeden önce bekleme |
|---|---|
| 1-3 | Yok |
| 4 | 5 saniye |
| 5 | 15 saniye |
| 6 | 30 saniye |
| 7 | 1 dakika |
| 8 | 5 dakika |
| 9 ve üstü | 15 dakika |

- Sayaç Argon2id başlamadan **önce** artırılıp diske yazılır ve yalnızca başarılı açmada sıfırlanır. Böylece işlemin ortasında uygulamayı öldürerek deneme kazanılamaz.
- Bekleme uygulama yeniden başlayınca da sürer. Saat geri alınmışsa (şu an < `last_failed_at`) `last_failed_at` şu ana çekilir ve bekleme baştan başlar.
- Kasa hiçbir zaman kendiliğinden silinmez. Yanlışlıkla veya başkası tarafından veri kaybettirilmesi, denemeleri sınırlamaktan daha büyük bir risktir.
- Bekleme yalnızca parola için geçerlidir. Kurtarma anahtarı 256 bit rastgele olduğu için tahmin edilemez, parmak izi denemelerini Android sınırlar.

**Sınır:** Bu bir hız sınırıdır, kilit değildir. Sayaç şifresizdir ve uygulamanın kuralıdır. Saati ileri almak beklemeyi kısaltır, dosyayı ele geçiren biri ise bu kuralı hiç uygulamaz. Asıl koruma Argon2id ve parolanın gücüdür.

### Otomatik kilit

- Uygulama arka plana geçince (`hidden` veya `paused`) varsayılan olarak hemen kilitlenir. `inactive` kilitlemez, çünkü parmak izi penceresi ve sistem diyalogları da onu tetikler.
- **Bekleme süresi (1.7.0):** Ayarlar → Güvenlik'te "Arka planda kilitlenme" Hemen (varsayılan), 30 saniye ya da 1 dakika olabilir. Ayar şifreli kasa ayarlarında durur; okunamazsa "Hemen" sayılır. Süre seçiliyse arka plana geçiş anı iki saatle kaydedilir: duvar saati (`DateTime.now`) ve telefonun açılışından beri geçen süre (`CLOCK_BOOTTIME`, libc'nin `clock_gettime`'ı FFI ile okunur). Arka planda bir zamanlayıcı süre dolunca kilitler. Android önbellekteki uygulamayı dondurabilir ve telefon uyurken zamanlayıcılar işlemez; bu yüzden dönüşte (`resumed`) süre yeniden denetlenir: iki saatten biri süreyi geçtiyse ya da duvar saati geri gittiyse kasa önce kilitlenir. `CLOCK_BOOTTIME` telefon uyurken de ilerler ve ayarlanamaz; duvar saati ek bir denetimdir. Dart'ın `Stopwatch`'ı kullanılmaz: o `CLOCK_MONOTONIC`'tir ve uykuda durur, uyku ile saati geri almak bir araya gelince süre uzardı (son gözden geçirmenin bulgusu). Bir cihaz testi saatin açılıştan beri saydığını `/proc/uptime` ile karşılaştırır.
- Dönüşte dokunmama süresi de aynı iki saatle son dokunuştan beri denetlenir; bekleme süresi dokunmama kilidini uzatmaz. Kurtarma akışı (`VaultRecovering`) ve dosya seçicisi istisnası bekleme süresini kullanmaz. `detached` her zaman hemen kilitler.
- Bekleme süresinde kasa açık kaldığı için, dönüşte parola listesi diskten yeniden okunur: bu arada doldurma ekranı bir parola eklemiş ya da değiştirmiş olabilir. Ekranlarda açık kalan eski kopyalar da onu ezmez: favori, çöp kutusu, klasör ve geri yükleme kaydın listedeki en son hâline yazılır; açık kalan düzenleme formu kaydedilince yalnızca kullanıcının formda değiştirdiği alanlar en son hâle taşınır, ötekiler (örneğin doldurmanın kaydettiği yeni parola) kalır. Kullanıcı parolayı da değiştirdiyse doldurmanınki geçmişe girer.
- **Bedeli:** Süre boyunca telefonu eline alan biri KeyKey'i açık bulur. Varsayılan bu yüzden "Hemen"; açıklama ayarın yanında yazar.
- **İstisna:** KeyKey'in kendi açtığı belge seçici, belge oluşturma ekranı ve fotoğraf seçici ayrı birer etkinliktir ve uygulamayı arka plana alır. Bunlar açıkken arka plan kilidi en fazla 3 dakika ertelenir; yoksa kullanıcı dosyayı seçip döndüğünde kasa kilitli olur ve işlem sonuçsuz kalır. Süre dolunca kasa, seçici hâlâ açık olsa bile kilitlenir. Dokunmama kilidi bu sırada da çalışır. Zamanlayıcılar telefon uyurken durduğu için seçici açılırken arka plana geçiş anı kaydedilir; dönüşte 3 dakika ve dokunmama süresi iki saatle yeniden denetlenir. Bedeli: seçici açıkken kullanıcı telefonu bırakırsa kasa en fazla 3 dakika açık kalır. Sistem ayarlarına giden bağlantılar bu istisnaya girmez.
- Ekrana 5 dakika dokunulmazsa kilitlenir.
- Kilitlenince kasa ve alt anahtarlar `dispose` edilir, çözülmüş veri tutan durumlar sıfırlanır, yönlendirme kilit ekranına gider ve önceki ekranlar yığından çıkarılır.
- Kilit açılınca kilitlenmeden önceki sekmeye ya da açık olan kasa kaydının ayrıntısına dönülür. Yalnızca bu yol bellekte tutulur; ekranlar yeniden kurulur, gösterilen parolalar gizli açılır, formlar ve tek seferlik ekranlar geri gelmez.

## Biyometri

Parmak izi üçüncü kapıdır ve isteğe bağlıdır. Yuvası üst bilgide değil ayrı tabloda durur, çünkü yalnızca bu cihazın Keystore anahtarıyla açılır ve yedekte işe yaramaz. Böylece üst bilgi biçimi v1 değişmez.

**Keystore anahtarı** (`keykey_biometric_v1`):

| Ayar | Değer | Neden |
|---|---|---|
| Algoritma | AES-256-GCM, 128 bit etiket | IV'yi Keystore üretir (12 bayt). |
| `setUserAuthenticationRequired` | `true` | Doğrulama olmadan anahtar kullanılamaz. |
| `setUserAuthenticationParameters` | `0`, `AUTH_BIOMETRIC_STRONG` | Her kullanımda doğrulama; süre penceresi ve cihaz PIN'i yok. |
| `setInvalidatedByBiometricEnrollment` | `true` | Yeni parmak izi eklenince anahtar geçersiz olur. |
| `setIsStrongBoxBacked` | Varsa `true` | Yoksa cihazın güvenli ortamına (TEE) düşer. |

**Sarmalama:** `AES-256-GCM(Keystore anahtarı, iv, kasa anahtarı, AD)`. AD alanları: `keykey/v1/wrap`, `vaultId`, `biometric`.

Şifreleme ve çözme `BiometricPrompt` ile `CryptoObject` üzerinden yapılır, yani doğrulama yalnızca "evet" cevabı değil, anahtarın kullanılabilmesinin şartıdır. Yalnızca `BIOMETRIC_STRONG` kabul edilir, olumsuz düğme ana parola ekranına döner.

| Durum | Davranış |
|---|---|
| Parmak izini açma | Kasa açıkken yapılır. Sarmalama da doğrulama gerektirdiği için parmak izi istenir. |
| Parmak iziyle açma | Başarılıysa hatalı deneme sayacı sıfırlanır. |
| Yeni parmak izi eklendi, tüm parmak izleri silindi veya ekran kilidi kaldırıldı | Anahtar geçersizdir. Yuva ve anahtar silinir, ana parola istenir, özellik sonra yeniden açılabilir. |
| Parmak izini kapatma | Önce yuva satırı, sonra Keystore anahtarı silinir. Arada kesilirse kalan anahtar sarılmış bir şey açamaz. |
| Ana parola değişti | Yuva değişmez, çünkü kasa anahtarı aynıdır. |

**Katman istisnası:** Kasa anahtarının ham bayta döndüğü tek yer bu köprüdür. Dart ile Kotlin arasında geçerken Dart ve JVM belleğinde kopyalar oluşur. Sarmalarken Kotlin aldığı diziyi, Dart da gönderdiği kopyayı sıfırlar. Açarken ise kopyalar sıfırlanamaz: Kotlin'in çözdüğü diziyi köprü fonksiyon döndükten sonra kodlar, Dart'a gelen kanal tamponu da salt okunurdur. Bu kopyalar çöp toplayıcı silene kadar JVM ve Dart belleğinde kalabilir. Yalnızca kasa açılırken veya açıkken oluşurlar; o sırada anahtar zaten bellektedir ve root yetkili cihaz tehdit modelinin dışındadır.

## Arayüz koruması

Ana uygulama ve doldurma ekranı aynı korumayı kullanır (`WindowProtection`).

| Tehdit | Koruma | Android sürümü |
|---|---|---|
| Ekran görüntüsü, ekran kaydı | `FLAG_SECURE` | Hepsi |
| Son uygulamalar önizlemesi | `FLAG_SECURE`, ayrıca `setRecentsScreenshotEnabled(false)` | Hepsi; ikincisi 13+ |
| Bindirme penceresiyle dokunma korsanlığı (tapjacking) | KeyKey ekrandayken başka uygulamaların bindirme pencereleri gizlenir (`setHideOverlayWindows`, `HIDE_OVERLAY_WINDOWS` izni). Sistemin kendi pencereleri etkilenmez | 12+ |
| Aynı saldırı, gizleme olmadan | Dokunulan noktanın üstünde başka bir uygulamanın penceresi varsa (`FLAG_WINDOW_IS_OBSCURED`) dokunuş düşürülür ve kullanıcıya nedeni söylenir | 11 |
| Erişilebilirlik servisinin ekranı okuması | Pencere erişilebilirlik için hassas işaretlenir (`setAccessibilityDataSensitive`). Ekranı yalnızca kendini erişilebilirlik aracı olarak bildiren servisler (TalkBack, Switch Access gibi) okuyabilir ve kullanabilir | 14+ |

**Android 11'in bedeli:** Ekran filtresi (mavi ışık, karartma) gibi ekranın tamamını kaplayan bir uygulama açıkken KeyKey'e dokunulamaz; kullanıcı her denemede "başka bir uygulama KeyKey'in üstünde görünüyor" uyarısını görür. Yalnızca dokunulan noktayı örten pencereler sayılır; ekranın başka bir yerindeki yüzen pencere dokunuşu engellemez. Android 12 ve sonrasında pencereler zaten gizlendiği için dokunuş süzülmez; böylece sistemin büyüteci gibi kendi pencereleri KeyKey'i kullanılmaz hale getirmez. Android 12 ayrıca, opaklığı 0,8'den yüksek başka uygulama pencerelerinden geçen dokunuşları kendisi engeller.

**Sınırlar:**

1. Android 11-13'te erişilebilirlik izni verilmiş zararlı bir uygulama ekrandaki metni okuyabilir. Bu sürümlerde bunu önleyecek bir platform özelliği yok.
2. Kendini erişilebilirlik aracı olarak bildiren bir servis Android 14+'ta da okuyabilir. Google Play bu bildirimi gerçek erişilebilirlik araçlarına sınırlar; başka kaynaktan kurulan uygulamalar için böyle bir denetim yok.
3. Erişilebilirlik izni ve bindirme izni kullanıcının kendisinin vermesi gereken izinlerdir; KeyKey bu izinleri kimin aldığını göremez.

### Klavye

Bütün metin kutuları öneri, otomatik düzeltme ve kişisel öğrenme isteği kapalı açılır (`enableSuggestions`, `autocorrect`, `enableIMEPersonalizedLearning: false`). Bu son istek yalnızca bir istektir, birçok klavye onu yok sayar. Bu yüzden kutular varsayılan olarak `visiblePassword` klavyesiyle açılır; neredeyse her klavye bu türde öneriyi ve öğrenmeyi gerçekten kapatır. Bedeli: büyük harf ve adres tuşları yok.

**Normal klavye ayarı (1.7.0, varsayılan kapalı):** Açıksa gizli olmayan kutular normal klavyeyle açılır: kayıt adı, klasör, kasa ve 2FA araması, 2FA servis adı ve yeni klasör adı normal klavye ve kelime başı büyük harfle (`TextInputType.text`), web adresi adres klavyesiyle (`TextInputType.url`). Otomatik düzeltme ve öğrenme isteği yine kapalıdır, ama **öneri açıktır**: Flutter Android'de öneriyi kapatan her kutuya `TYPE_TEXT_VARIATION_VISIBLE_PASSWORD` ekliyor (motorun `TextInputPlugin`'i), o zaman ne büyük harf ne adres tuşları gelir. Bu cihaz denemesinde `dumpsys input_method` ile görüldü: öneri kapalıyken ad kutusu `0x82091`, web adresi `0x80091` (görünür parola) aldı; öneri açıkken `0x2001` (metin, kelime başı büyük harf) ve `0x11` (adres). Klavye öneri şeridini gösterir; öğrenme isteğine uymayabilir: bu kutulara yazılanlar (hangi bankayı, hangi siteyi kullandığın) klavyenin sözlüğüne ve bulut eşitlemesine girebilir. Açıklama ayarın yanında yazar.

Gizli kutular her ayarda `visiblePassword` (ya da kendi rakam klavyeleri) kalır: kullanıcı adı, parola, notlar, not metni, kart sahibi, numara, son kullanma, güvenlik kodu, PIN, 2FA hesap adı ve anahtarı, özel alanlar, ana parola ve kurtarma ekranları. Bir kutu ancak kodda açıkça "gizli değil" diye işaretlenirse normal klavyeyle açılabilir; işaretlenmemiş yeni bir kutu güvenli tarafta kalır. Doldurma ekranları ayarı okumaz.

**Deneme:** [`tapjacking-device-test.sh`](../scripts/tapjacking-device-test.sh), [`resources/test-apps/saldirgan`](../test-apps/saldirgan) uygulamasıyla dener: ekranı kaplayan, dokunuşları geçiren 0,5 opaklıkta bir bindirme penceresi (Android 12'nin kendi engelinden geçen en zor durum) ve kendini araç olarak bildirmeyen bir erişilebilirlik servisi. Korumadan önceki sürümde bindirme KeyKey'in üstünde görünüyordu ve servis kilit ekranındaki metinleri okuyabiliyordu. Sonuçlar [denetim belgesinde](guvenlik-denetimi.md#arayüz-koruması).

## Pano

- Parola kayıt ayrıntısından ve kasa listesindeki kopyala düğmesinden kopyalanabilir; ikisi de aynı yoldan geçer ve aşağıdaki kurallar ikisinde de aynıdır.
- Kopyalanan parola hassas olarak işaretlenir (`EXTRA_IS_SENSITIVE`, Android 13+), böylece sistem önizlemede göstermez. Android 11 ve 12'de bu işaret yoktur.
- Pano 30 saniye sonra temizlenir. Bunu önce zamanlayıcı yapar. Süreç durdurulduysa veya dondurulduysa, 10 saniye paylı kurulan bir `AlarmManager` alarmı yapar. Pay olmadan Android 11'de alarm zamanlayıcıdan önce çalıştı ve kullanıcının yeni kopyasını sildi.
- Pano okunabiliyorsa yalnızca hâlâ bizim kopyamızı taşıyorsa silinir. Bunu anlamak için kopyalanan metnin kendisi değil, SHA-256 özeti tutulur. Panonun zaman damgası bu iş için güvenilir çıkmadı, cihaz testinde eşleşmedi. Okunamıyorsa, örneğin uygulama arka plandaysa veya Android o an izin vermiyorsa, silinir. Android 14 emülatöründe uygulama öndeyken de zaman zaman okunamadı.
- Yeni bir kopyalama öncekinin süresini sıfırlar.
- Metin kutularında (düzenleme ekranları, açılmış gizli kutular) uzun basınca açılan menüde yalnızca kes, kopyala, yapıştır ve tümünü seç vardır; kes ve kopyala da bu yoldan geçer. Sistemin kendi menüsü panoya hassas işaret ve süre olmadan yazar; paylaş, ara ve çevir gibi düğmeler metni başka uygulamalara verir. Gizli (noktalı) kutuda kes ve kopyala hiç çıkmaz. Notun seçilebilir metninde de menü yalnızca "Kopyala" ve "Tümünü seç"tir.
- Kasa kilitlenince pano temizlenmez. Parolayı kopyalayıp tarayıcıya geçmek uygulamayı arka plana alır ve kasayı kilitler, temizlemek kopyalamayı işe yaramaz hale getirirdi.

**Sınırlar:**

1. Android arka plandaki uygulamaya panoyu okutmaz. Kullanıcı bu sürede başka bir şey kopyaladıysa onu da silebiliriz.
2. Alarm tam zamanında çalışmayabilir. Android, kesin alarm izni olmadan onu geciktirebilir. Cihaz testi, süreç ayaktayken arka planda temizlendiğini doğruluyor; sürecin kapatıldığı durum yalnızca alarma dayanıyor ve otomatik test edilmedi. Bu izni almıyoruz, çünkü parolanın panoda birkaç dakika daha kalması, izin listesini büyütmeye değmez.
3. O sürede panoyu okuyan etkin klavye veya kötü amaçlı uygulama parolayı görebilir. Bu, [tehdit modelinde](#tehdit-modeli) "kısmen" olarak yazıyor.
4. Donanım klavyesindeki Ctrl+C ve klavye uygulamasının kendi kopyala düğmesi bu menüden geçmez; seçili metni sistemin panosuna doğrudan yazar.
5. Android 11 ve 12'de klavye kopyalanan metni işleyebilir. Android 11 emülatöründe Gboard kopyalanan kart numarasını sistemin metin sınıflandırıcısına verdi, sınıflandırıcı da onu bir hata metninde logcat'e yazdı ([denetim](guvenlik-denetimi.md#kayıtlar-logcat)). KeyKey hassas işaretini bu sürümlerde de koyuyor ama Gboard ona bakmıyor. Logcat'i yalnızca sistem ve adb okuyabilir.

## Tarayıcıda açma

Kayıt ayrıntısındaki **Siteyi aç** ve Hakkında'daki bağlantılar adresi `ACTION_VIEW` ve `CATEGORY_BROWSABLE` ile sisteme devreder; sayfayı tarayıcı ya da o siteyi açtığını bildiren uygulama (örneğin GitHub uygulaması) açar. Sayfayı KeyKey yüklemez.

- **Yalnızca web sayfası:** Adres hem Dart'ta hem Kotlin'de denetlenir; http ve https dışındaki şemalar (`intent:`, `javascript:`, `file:`, `content:`, `androidapp://`) açılmaz. Böylece içe aktarılmış ya da yazılmış bir adres başka bir uygulamanın bileşenini başlatamaz. Şeması olmayan adrese `https://` eklenir (`nas.example:5001` gibi port taşıyan ad şema sayılmaz).
- **Yanıltıcı adresler:** Kullanıcı bilgisi taşıyan adres (`https://banka.example@baska.example`) açılmaz; ekranda banka gibi okunur ama tarayıcı başka siteyi açardı. ASCII dışı harfli alan adları da açılmaz, çünkü benzer görünen alan adlarıyla karıştırılabilir; bu kayıtlarda adres kopyalanıp tarayıcıya yapıştırılır.
- **Yalnızca dokununca:** Adres kendiliğinden hiçbir yere gönderilmez; tarayıcıya yalnızca o adres gider.
- **Kilit:** Tarayıcı açılınca KeyKey arka plana geçer ve her zamanki gibi kilitlenir; kilit açılınca aynı kayda dönülür.

## Parola üretici ve güç tahmini

- Bütün rastgelelik `randombytes_uniform` ile üretilir, modülo eğilimi yoktur.
- **Rastgele parola:** Seçilen her karakter sınıfından en az bir karakter bulunur. Bu, sonucu çok az daraltır, gösterilen entropi hesabı bunu göz ardı eder.
- **Parola cümlesi:** [EFF büyük sözcük listesi](https://www.eff.org/dice) (7776 İngilizce sözcük, CC BY 3.0), sözcük başına yaklaşık 12,9 bit. Varsayılan 6 sözcük, yaklaşık 77 bit. Denetlenmiş bir Türkçe liste bulamadığımız için Türkçe seçenek yok.
- **Güç tahmini:** Uzunluk ve karakter çeşitliliğinden kaba bir entropi hesaplanır. Yaygın parola listesi, klavye dizileri, ardışık karakterler, tekrarlar ve tarihler bunu düşürür. Yaygın parola listesi [SecLists](https://github.com/danielmiessler/SecLists) (MIT) kaynaklıdır. Bu yine bir tahmindir, gerçek gücü ölçmez.

### Parola raporu

Kasa ekranındaki "Parola raporu" zayıf ve birden çok kayıtta kullanılan parolaları gösterir; kullanıcı isterse parolaların sızıntılarda görülüp görülmediğini de denetler ([Sızıntı kontrolü](#sızıntı-kontrolü)).

- **Zayıf:** Kayıt düzenleme ekranındaki güç göstergesiyle aynı kural (`PasswordPolicy.strengthOf`, yaygın parola listesiyle). "Çok kısa" (10 karakterden az) ve "zayıf" çıkanlar rapora girer. Parola üreticisi eşik değil, bit sayısı gösterir; ürettiği parola düzenleme ekranında aynı göstergeden geçer.
- **Tekrar eden:** Parolası birebir aynı olan kayıtlar gruplanır.
- **Kapsam:** Çöp kutusundaki ve parolası boş kayıtlar sayılmaz.
- **Gizlilik:** Rapor, kasa açıkken zaten bellekte duran çözülmüş kayıtlardan hesaplanır. Zayıf ve tekrar eden parolalar için ağa çıkılmaz. Sonuç kasaya ve diske yazılmaz. Ekranda parolalar gösterilmez, yalnızca kayıt adları ve kullanıcı adları. Rapor ekranı kapanınca hesaplanan rapor atılır (`autoDispose`); kasa kilitlenince kayıtlarla birlikte bellekten çıkar.
- **Kayda gitme:** Kayda dokununca düzenleme ekranı açılır; parola değişince rapor kendiliğinden güncellenir.

### Sızıntı kontrolü

1.6.0'dan beri raporun en üstünde. Parolaların bilinen veri sızıntılarında görülüp görülmediğini [Have I Been Pwned](https://haveibeenpwned.com/Passwords)'ın Pwned Passwords hizmetine k-anonimlikle sorar. Tasarım ve gerekçeler: [internet ve sızıntı kontrolü](internet-ve-sizinti.md).

- **Yalnızca dokununca:** Ağa çıkan tek yol **İnternetten denetle** düğmesidir. Rapor açılınca, kasa açılınca ya da arka planda hiçbir istek gitmez; sonuç kaydedilmediği için kendiliğinden yinelenen bir denetim de yoktur.
- **Ne gider:** Etkin (çöpte olmayan, parolası boş olmayan) kayıtların parolalarının SHA-1 özeti (UTF-8, büyük harfli onaltılık) alınır, ilk 5 karaktere göre gruplanır. Her önek bir kez sorulur: `GET https://api.pwnedpasswords.com/range/{önek}`. Parola, özetin geri kalan 35 karakteri ve kaydın hiçbir alanı gitmez. Yanıttaki sonekler telefonda karşılaştırılır.
- **İstemci:** Dart'ın `dart:io` `HttpClient`'ı, yeni bağımlılık yok. Adres sabit; https dışı adres kurulurken reddedilir (yalnızca yerel test sunucusu hariç). Yönlendirme izlenmez, bağlantı kalıcı tutulmaz, çerez yok, `User-Agent: KeyKey`, `Add-Padding: true` (yanıt boyu öneki ele vermesin diye dolgu). Bağlanma 10, istek 30 saniyede zaman aşımına uğrar; yanıt 1 MiB'ı aşarsa reddedilir.
- **Sırası ve hızı:** Önekler karışık sırayla, aynı anda en çok 4 istek olarak gider; sıra kayıtların sırasını ele vermez. Her önek bir kez yeniden denenir.
- **Yanıt:** Her satır `^[0-9A-F]{35}:[0-9]+$` biçiminde olmalı; sayısı 0 olan satırlar dolgudur. Biçime uymayan tek satır bütün denetimi hata yapar: bir otelin giriş sayfası gibi HTML yanıtı "sızıntı yok" sayılmaz. Yarım sonuç gösterilmez.
- **Sonuç:** Yalnızca bellekte, özet → görülme sayısı olarak. Ekranda kayıt adı, kullanıcı adı ve görülme sayısı; parolanın kendisi gösterilmez. Parolası sonradan değişen kayıt listeden kendiliğinden düşer, çünkü yeni parolası denetlenmemiştir. Kasaya, ayarlara ve diske hiçbir şey yazılmaz.
- **Kilit ve ekrandan çıkma:** Denetim rapor ekranıyla yaşar (`autoDispose`). Ekran kapanınca ya da kasa kilitlenince yeni istek başlamaz, süren isteklerin yanıtı atılır ve sonuç bellekten çıkar.
- **Ağ kodu iki yerde:** `lib/core/network/pwned_passwords_client.dart` ve senkronun `lib/core/network/webdav_client.dart` dosyası dışında `lib` ve Kotlin kaynaklarında ağ arayüzü (`HttpClient`, soket, `package:http`, `java.net.URL`, OkHttp…) kullanılamaz; `test/core/network/network_audit_test.dart` bunu her derlemede denetler.
- **WebDAV istemcisi** ([senkron](senkron.md#webdav-istemcisi)): yalnızca https ve sistemin güvendiği sertifikalar; http yalnızca bu telefonun kendi adresinde (`127.0.0.1`, `localhost`, `::1`). Adreste kullanıcı bilgisi, sorgu ve parça olamaz. Yönlendirme izlenmez (3xx hata olur, kimlik bilgisi başka sunucuya gitmez), çerez tutulmaz; her istekte HTTP Basic kimlik ve `User-Agent: KeyKey`. Bağlanma 10, istek 60 saniyede zaman aşımına uğrar. Klasör listesi 1 MiB, dosya yedek kapsayıcısının sınırı (64 MiB) kadar okunur; aşan yanıt hata olur. Dosya önce `.tmp` ekli ara adla yazılır, geri okunup bayt bayt karşılaştırılır, sonra son adına taşınır. Hata mesajları adres yolunu, kullanıcı adını ve parolayı taşımaz.
- **Sertifika sabitleme yok:** Sistemin güvendiği sertifika yetkilileri kullanılır. Bunu ağ güvenliği yapılandırması değil Dart sağlar: Dart'ın istemcisi Android'in sistem sertifika klasörünü kendisi okur, kullanıcının eklediği sertifikaları yüklemez. Sabitlemek, hizmet sertifikasını değiştirince denetimi bozardı; trafikte parola olmadığı için kazancı küçük.
- **Android ayarları:** `INTERNET` izni; `usesCleartextTraffic="false"` ve yalnızca sistem sertifikalarına güvenen ağ güvenliği yapılandırması. **Bulgu (1.6.0):** Flutter 3.47 bu kuralı Dart'ın `HttpClient`'ına uygulamıyor (motor `domainNetworkPolicy` değerini boş geçiyor); emülatörde `http://` isteği reddedilmedi. Bu ayarlar platform kodunu korur; Dart tarafında https'i istemcinin kendisi zorlar.
- **Atıf:** Veri CC BY 4.0; rapor ekranında "Veri: Have I Been Pwned (CC BY 4.0)" bağlantısı.

## 2FA kodları

### Kod üretimi

- **HOTP** (RFC 4226): `HMAC(gizli anahtar, sayaç)` hesaplanır, sayaç 8 baytlık büyük uçlu yazılır. Son baytın düşük 4 biti bir konum gösterir, o konumdaki 4 bayttan en üst bit atılır ve sonuç `10^hane`'ye göre kalanı alınarak önüne sıfır eklenir.
- **TOTP** (RFC 6238): Sayaç `floor(unix zamanı / period)`'dur, başlangıç zamanı 0'dır. SHA-256 ve SHA-512 için de aynı kesme yöntemi kullanılır.
- **Steam Guard** (1.7.0): TOTP'nin SHA1 ve 30 saniyeyle bulunan 31 bitlik sayısı, `23456789BCDFGHJKMNPQRTVWXY` alfabesiyle 5 kez `sayı mod 26` karakterine çevrilir ve her adımda `sayı = sayı div 26` yapılır. Kod gruplanmadan gösterilir. Test değerleri Steam'in kendi uygulamasının ürettiği kodlardır (KeePassXC'nin testlerinden; bağımsız bir Python hesabıyla da doğrulandı).
- HMAC için `package:crypto` kullanılır. libsodium'da SHA-1 yok, HMAC-SHA256 ve HMAC-SHA512'si ise yalnızca 32 baytlık anahtar alıyor.
- **HOTP sayacı:** Kod, kullanıcı istediğinde üretilir. Sayaç önce bir artırılıp diske yazılır, kod ondan sonra gösterilir. Böylece uygulama yarıda kapansa da aynı kod iki kez görünmez. Gösterilen kod kayıttaki eski sayaç değeriyle hesaplanır, yani `counter` her zaman sıradaki kullanılacak değerdir. Bu RFC 4226'daki tanıma uyar.
- **Sıradaki kod:** TOTP süresinin bitmesine az kaldığında bir sonraki kod da gösterilir. Kullanıcı yazarken süre dolarsa kodu yeniden okumak zorunda kalmaz.
- **Saat:** TOTP cihaz saatine dayanır. Uygulama internet kullanmadığı için saati kendisi doğrulayamaz. Kodlar tutmazsa saat ayarını gösteren bir yardım metni vardır.
- Kodlar kopyalanırken parolalarla aynı [pano](#pano) kuralları geçerlidir.

### `otpauth://` bağlantıları

Biçim [Google Authenticator'ın Key Uri Format'ıdır](https://github.com/google/google-authenticator/wiki/Key-Uri-Format): `otpauth://totp/Servis:hesap?secret=...&issuer=Servis`.

- Şema ve tür büyük küçük harf ayırmaz. `totp`, `hotp` ve `steam` dışındaki türler, örneğin `yandex`, desteklenmiyor diye reddedilir.
- **Steam:** `otpauth://steam/…` ya da `otpauth://totp/…?encoder=steam` Steam hesabıdır. `algorithm`, `digits` ve `period` yazılmışsa (Aegis yazar) SHA1, 5 ve 30 olmalıdır. Başka bir `encoder` değeri yanlış kod üreteceği için reddedilir; 1.7.0'dan önce `encoder` parametresi yok sayılıyordu. KeyKey Steam hesabını `otpauth://steam/…` olarak, bütün değerleri açıkça yazarak dışa verir; yalnızca [Bitwarden biçimli dışa aktarma](#düz-metin-dışa-aktarma) `steam://ANAHTAR` yazar.
- `secret` zorunludur. Kullanıcıların elle yazdığı veya kopyaladığı metinlere uymak için Base32 okunurken küçük harf, boşluk, tire ve dolgu kabul edilir; Türkçe klavyenin `ı` ve `İ` harfleri `I` sayılır. Artan bitler atılır.
- `issuer` parametresi varsa etiketteki `Servis:` önekinden önce gelir. Etiketteki iki noktadan sonraki boşluklar atılır. Servis adında da iki nokta olabileceği için, `issuer` etiketin başında geçiyorsa etiket tam oradan bölünür.
- Servis ve hesap adlarından denetim karakterleri ve metnin yönünü değiştiren karakterler (örneğin U+202E) atılır. Bunlar bir adı ekranda başka bir servisin adı gibi gösterebilir.
- Yüzde kodlaması kendi çözücümüzle açılır. Sorgu kısmında `+` boşluktur, etikette değildir.
- `algorithm`, `digits` ve `period` verilmezse SHA1, 6 ve 30 kullanılır (Steam'de 5 hane). `hotp` için `counter` zorunludur.
- Bilinen bir parametre iki kez geçerse veya değeri kurallara uymazsa bağlantı reddedilir. Bilinmeyen parametreler, örneğin `image`, yok sayılır. `image` adresine bağlanılmaz.
- 4096 karakterden uzun metin okunmaz.
- Ayrıştırıcı yalnızca kendi hata türünü fırlatır. Hata mesajı hangi kuralın bozulduğunu söyler, gizli anahtarı içermez. Bozuk girdi testleri rastgele metinlerle de çalıştırılır.

### QR okuma

- Kamera görüntüsü ve seçilen görsel `flutter_zxing` ile cihazda çözülür. Görüntü hiçbir yere kaydedilmez.
- Kamera izni yalnızca kullanıcı taramayı başlattığında istenir. Reddedilirse elle giriş ve görselden okuma çalışmaya devam eder.
- Görsel Android'in fotoğraf seçicisiyle seçilir, depolama izni gerekmez. `image_picker` görseli uygulamanın önbelleğine kopyalar; görselde gizli anahtar olduğu için kopya okunur okunmaz silinir.
- Okunan hesap hemen kaydedilmez. Servis ve hesap adı gösterilir, kullanıcı onaylayınca kaydedilir.
- **İzinler:** Yayın APK'sına yeni izin olarak yalnızca `CAMERA` girer. Kamera ve görsel seçici kütüphanelerinin eklediği `RECORD_AUDIO`, `WRITE_EXTERNAL_STORAGE`, `READ_EXTERNAL_STORAGE` ve `ACCESS_NETWORK_STATE` manifestte kaldırılır, `check-release-apk.sh` bunu denetler. Kamerası olmayan cihazlar da uygulamayı kurabilir.

### İçe aktarma

| Kaynak | Biçim | Şifreli dosya |
|---|---|---|
| Google Authenticator | Dışa aktarma QR'ı: `otpauth-migration://offline?data=...`, içinde Base64 ile kodlanmış protobuf. Büyük dışa aktarmalar birkaç QR'a bölünür, her biri ayrı okunur. | Yok. |
| Aegis | Dışa aktarılan JSON dosyası. | Her parola yuvası scrypt (dosyadaki N, r, p ve tuzla) türetilen anahtarla ana anahtarı sarar; kasa ana anahtarla AES-256-GCM ile şifrelidir. |
| 2FAS | Dışa aktarılan `.2fas` dosyası. | PBKDF2-HMAC-SHA256 (10 000 tur, dosyadaki tuz) ve AES-256-GCM. |

- **Şifre çözme:** AES-256-GCM için Android'in `javax.crypto` kitaplığı kullanılır. scrypt ve PBKDF2 kendi Dart kodumuzdur: `sodium` paketi scrypt'i sunmuyor, libsodium'da PBKDF2 hiç yok. İkisi RFC 7914'teki test vektörleriyle doğrulanır, ayrıca Aegis'in örnek dosyaları Node'un (OpenSSL) kriptosuyla açılıp aynı anahtarların üretildiği karşılaştırılır. Bu kod yalnızca kullanıcının verdiği dosyayı açmak için çalışır, kasanın şifrelemesinde kullanılmaz; bir hata dosyanın açılmamasına yol açar, kasayı zayıflatmaz.
- **Sınırlar:** Kötü niyetli bir dosya cihazı belleksiz bırakmasın diye scrypt en fazla 128 MiB bellek (N ve p bloklarının toplamı), p ≤ 16 ve Aegis varsayılanının 32 katı iş (128·r·N·p ≤ 1 GiB) ile çalışır, dosya en fazla 10 MB olabilir. Türetme ayrı isolate'te yapılır, ekran donmaz.
- Dosya Android'in belge seçicisiyle seçilir, depolama izni gerekmez. `file_selector` dosyayı önbelleğe kopyalar; kopya okunur okunmaz silinir.
- Dosyalar güvenilmeyen veri sayılır. Başka uygulamaların biçimi oldukları için bilinmeyen alanlar yok sayılır, ama bozuk bir hesap atlanır ve bozuk dosya uygulamayı düşürmez. Bozuk girdi testleri rastgele değiştirilmiş dosyalarla da çalıştırılır.
- Steam hesapları (Aegis `steam`, 2FAS `STEAM`) 1.7.0'dan beri içe aktarılır; değerleri SHA1, 5 ve 30 değilse hesap bozuk sayılır. Desteklenmeyen hesaplar, örneğin Yandex veya Steam dışındaki 5 haneli kodlar, atlanır ve kullanıcıya sayısı söylenir. Gizli anahtarı zaten kayıtlı olan hesap, çöp kutusunda bile olsa, işaretlenir ve tekrar eklenmez.
- Hesaplar kaydedilmeden önce liste halinde gösterilir, kullanıcı hangilerinin ekleneceğini seçer.
- Aegis'in 2019'dan eski, `repaired` işareti olmayan parola yuvaları farklı bir parola kodlamasıyla türetilmişti. Bu yuvalar desteklenmez; parola yanlış görünür.

### Kodları görmek için ek onay

İsteğe bağlı bir ayardır. Açıksa 2FA ekranı ve parola kaydındaki eşleşmiş kod, kasa açık olsa bile kodları göstermeden önce parmak izi, parmak izi kapalıysa ya da vazgeçilirse ana parola ister. Onay, kasa kilitlenene kadar geçerlidir. Uygulama arka plana geçince kasa kilitlenir; kullanıcı bir [bekleme süresi](#otomatik-kilit) seçtiyse ve süre dolmadan dönerse kasa da onay da açık kalır. O sürede telefonu eline alan biri parolaları da görür; onayı ayrıca sıfırlamak bir şey kazandırmaz.

- **Doğrulama gerçekten kasayı açar.** Parmak izi, Keystore anahtarının kasa anahtarını açabildiğiyle; ana parola, parola yuvasının açılabildiğiyle doğrulanır. Açılan kopya hemen silinir. Ana parolada hatalı denemeler kilit ekranındaki sayaca eklenir ve aynı bekleme uygulanır, yani bu pencere parola denemek için kullanılamaz.
- **Kapatmak doğrulama ister,** açmak istemez. Yoksa kilidi açık telefonu eline alan biri önce ayarı kapatabilirdi.
- Ayarlar henüz okunmadıysa kodlar gösterilmez.

**Ayar kaydı:** Ayarlar kasanın içinde, tür `settings` olan tek bir kayıtta durur. Kimliği 16 sıfır bayttır; tür ek doğrulama verisinde olduğu için başka bir kaydın yerine konamaz. Kayıt anahtarıyla şifrelenir. Düz metin:

```json
{
  "version": 7,
  "otpRequireAuth": false,
  "autofillCopyOtp": true,
  "lastBackupAt": 1730000000000,
  "backupReminderSnoozedUntil": null,
  "vaultSort": "name",
  "generator": {
    "passphrase": false,
    "length": 20,
    "lowercase": true,
    "uppercase": true,
    "digits": true,
    "symbols": true,
    "words": 6
  },
  "autoBackupFolder": {
    "uri": "content://com.android.externalstorage.documents/tree/primary%3AKeyKey",
    "name": "KeyKey"
  },
  "backgroundLockSeconds": 0,
  "plainKeyboard": false,
  "sync": {
    "folder": "https://bulut.example.com/remote.php/dav/files/furkan/KeyKey",
    "username": "furkan",
    "appPassword": "<uygulama parolası>",
    "lastSyncAt": 1730000000000,
    "lastDigest": "<64 onaltılık karakter>"
  }
}
```

- `autofillCopyOtp` sürüm 2 ile geldi ve [doldurmadan sonra 2FA kodunu kopyalamayı](#2fa-kodu) açar. Sürüm 1 kaydı okunmaya devam eder; o zaman bu ayar açık sayılır.
- `lastBackupAt` ve `backupReminderSnoozedUntil` sürüm 3 ile geldi: son yedeğin zamanı ve [yedek hatırlatıcısının](#yedek-hatırlatıcısı) susturulduğu son an, 1970'ten beri geçen milisaniye ya da `null`. Daha eski kayıtlarda ikisi de `null` sayılır.
- `vaultSort` (`name` ya da `recent`) ve `generator` sürüm 4 ile geldi: kasa listesinin sıralaması ve parola üreticisinin son **kullanılan** seçenekleri (uzunluk 8–64, en az bir karakter türü, cümlede 4–12 sözcük). Üretilen parola yazılmaz. Daha eski kayıtlarda ada göre sıralama ve varsayılan üretici kullanılır. Sınır dışı bir değer kaydın tamamını okunamaz yapar (aşağıdaki kural). Sürüm 4 kaydını içeren bir yedek KeyKey'in eski bir sürümünde açılırsa ayar kaydı okunamaz sayılır, ek onay açık gelir.
- `autoBackupFolder` sürüm 5 ile geldi: [otomatik yedeğin](#otomatik-yedek) klasörü ya da `null`. Tam iki alan taşır; `uri` `content://` ile başlar, `name` boş olamaz. Daha eski kayıtlarda otomatik yedek kapalı sayılır. Sürüm 5 kaydını içeren bir yedek eski bir sürümde açılırsa yine ayar kaydı okunamaz sayılır.
- `backgroundLockSeconds` (0, 30 ya da 60) ve `plainKeyboard` sürüm 6 (1.7.0) ile geldi: [arka planda kilitlenmeden önceki bekleme](#otomatik-kilit) ve gizli olmayan kutularda normal klavye. Başka bir saniye değeri ya da yanlış tür kaydın tamamını okunamaz yapar. Daha eski kayıtlarda "Hemen" ve öğrenmesiz klavye kullanılır. 1.7.0 yedekleri [içerik sürümü 3](#yedek-biçimi) ile yazılır, eski sürümler onları "daha yeni yedek" diye reddeder.
- `sync` sürüm 7 (1.8.0) ile geldi: [senkronun](senkron.md) bu telefondaki bilgileri ya da `null`. Tam beş alan taşır: WebDAV klasörünün adresi (`https`, ya da bu telefonun kendi adresinde `http`; adreste kullanıcı bilgisi, sorgu ve parça olamaz), kullanıcı adı ve uygulama parolası (boş olamaz), son eşitlemenin zamanı ve son yüklenen dosyanın özeti (64 küçük onaltılık karakter ya da `null`). Uymayan alan kaydın tamamını okunamaz yapar. Uygulama parolası yalnızca burada, kasanın içinde şifreli durur; ayar kaydı senkron dosyasına girmez, elle ve otomatik yedeğe girer. Daha eski kayıtlarda senkron kapalı sayılır. 1.8.0 yedekleri içerik sürümü 4 ile yazılır.
- Kayıt yoksa ek onay kapalıdır. Kayıt var ama okunamıyorsa, biçime uymuyorsa veya türü farklıysa ek onay **açık** sayılır: dosyayı değiştiren biri ayarı böyle kapatamasın. Kod kopyalama ise kapalı sayılır. Kullanıcı doğrulayıp ek onayı kapatabilir. Kaydın tamamen silinmesi ise [kayıt silme sınırına](#bilinen-sınırlar) girer.

**Sınır:** Bu, kasa anahtarını değiştirmez. 2FA anahtarı yine kasa anahtarından türetilir, çünkü ana parola ve kurtarma anahtarı da 2FA kayıtlarını açabilmelidir. Ayar, kilidi açık telefonu eline alan birine karşı koruma sağlar, cihazdaki zararlı yazılıma karşı korumaz.

## Otomatik doldurma

Android'in otomatik doldurma çerçevesiyle (`AutofillService`) çalışır. Temel kural: **kullanıcı KeyKey ekranında onaylamadan hiçbir veri hedef uygulamaya veya sisteme verilmez.**

### Akış

1. Sistem bir giriş formu için `onFillRequest` çağırır. Kotlin'deki servis formu çözümler: kullanıcı adı, parola, yeni parola ve tek kullanımlık kod alanlarını, ödeme formunda kart alanlarını bulur ([Kart doldurma](#kart-doldurma)). Doldurulacak alan yoksa yanıt vermez. KeyKey'in kendi formlarına ve cihazın kendi kilit bilgilerine (Ayarlar ve sistem arayüzü: `com.android.settings`, `com.android.systemui`, `android`) hiç yanıt vermez; ne doldurur ne kaydetmeyi önerir. Android 14'te Ayarlar'daki PIN onayı otomatik doldurmaya açık ve KeyKey cihaz PIN'ini kaydetmeyi öneriyordu.
2. Servis **kasaya hiç dokunmaz**: kasa açık olsa bile kayıt adlarını bilmez. Yanıtta giriş alanları için tek bir öneri vardır, "KeyKey ile doldur"; ödeme formunun kart alanları için ayrıca "KeyKey ile kart doldur". Öneri değer taşımaz ve kimlik doğrulama ister (`Dataset.setAuthentication`): öneriye dokunulunca KeyKey'in doldurma ekranı açılır. Doğrulama öneri düzeyindedir, yanıt düzeyinde değil; çünkü yanıt düzeyinde ekranın döndürdüğü tek bir `Dataset` sistemce yok sayılıyor ve öneri yeniden açılıyor (Android 16 emülatöründe görüldü). Kilitliyken de açıkken de kayıt adı görünmez.
3. Doldurma ekranı (`AutofillActivity`), ana uygulamadan ayrı bir Flutter giriş noktasıyla (`autofillMain`) çalışır. Kendi kasa oturumunu açar: parmak izi veya ana parola. Hatalı parola beklemesi ana uygulamayla aynı sayacı kullanır.
4. Ekran eşleşen kayıtları gösterir. Kullanıcı birini seçer. Şüpheli bir durum varsa önce açık bir uyarı ve ek onay gelir. **Tek kesin eşleşme** sorulmadan doldurulur, liste açılmaz. Bunun için üçü birlikte geçerli olmalı: tam olarak bir kayıt eşleşiyor; eşleşme kesin (uygulama hedefinde imza tutuyor, ya da güvenilen tarayıcıda kayıt edilebilir alan adı tutuyor); hiçbir uyarı yok (WebView ya da web sayfası gösteren uygulama değil, sitede bağlantı `https` (tarayıcı bağlantı türünü bildirmezse liste açılır), başka bir kayıtta imza tutmuyor değil). Kullanıcı isteğini zaten iki kez göstermiştir: öneriye dokunmuş ve kilidi açmıştır. Yanlış uygulamaya ya da sahte siteye doldurma riski seçme adımında değil, eşleştirme kurallarında karşılanır.
5. Seçilen kaydın kullanıcı adı ve parolası Kotlin'e verilir. Kotlin bunlardan bir `Dataset` kurup sisteme döndürür; sistem onu hemen doldurur. Yalnızca giriş parolası alanları doldurulur, yeni parola alanları doldurulmaz. Ekran kapanınca kasa oturumu kapatılır, anahtarlar silinir. Doldurmadan sonra kısa bir sistem bildirimi (`Toast`) kaydın adını gösterir: "GitHub dolduruldu". Kullanıcı adı ve parola bildirime girmez. Bildirim her doldurmada çıkar, listeden seçilende de.

Ekran son uygulamalar listesinde görünmez ve ekran görüntüsü alınamaz (`FLAG_SECURE`).

### Eşleştirme

**Uygulamalar:** Paket adı tek başına güvenilmez. Aynı paket adını taşıyan başka bir uygulama farklı bir anahtarla imzalanmış olabilir. Kayıtta paket adıyla birlikte imza sertifikasının SHA-256 özeti tutulur. Eşleşme `PackageManager.hasSigningCertificate` ile denetlenir; bu, imza anahtarı döndürülmüş uygulamaların sertifika geçmişini de kabul eder.

**Web siteleri:** Formun `webDomain` değeri yalnızca **güvenilen bir tarayıcıdan** geliyorsa kullanılır. Güvenilen tarayıcı, paket adı ve imza özeti gömülü listede olan uygulamadır. Liste, Google'ın Credential Manager için yayımladığı [ayrıcalıklı uygulamalar listesinden](https://www.gstatic.com/gpm-passkeys-privileged-apps/apps.json) alınır. Yalnızca yayın sürümlerinin imzaları alınır. Test sürümlerinin (`userdebug`) imzaları alınmaz. Tarayıcı olmayan uygulamalar da alınmaz: Google Play Hizmetleri ve listedeki kimlik bilgisi sağlayıcıları. Liste uygulamaya gömülüdür, internetten güncellenmez. Yeni sürümlerle `resources/scripts/trusted-browsers.mjs` betiğiyle yeniden üretilir; kaynağın özeti `resources/assets/autofill/KAYNAKLAR.md`'de durur. Alan adı, gömülü [Public Suffix List](https://publicsuffix.org/) ile kayıt edilebilir alan adına indirgenir: `giris.banka.com.tr` ile `banka.com.tr` eşleşir, `banka.com.tr` ile `sahte-banka.com.tr` eşleşmez. Listenin özel bölümü de kullanılır; böylece `ali.github.io` ile `veli.github.io` ayrı sitedir. Uluslararası alan adları karşılaştırmadan önce ASCII'ye (punycode) çevrilir. IP adresleri yalnızca tam eşleşir. Tam alan adı eşleşmesi önce gösterilir. Liste yalnızca web hedefinde yüklenir.

**Gömülü çerçeveler:** Sayfa başka kökenli bir çerçeve (reklam, yorum kutusu) içerebilir ve tarayıcı onun alanlarını da aynı forma koyabilir. Her alanın çerçevesi, kendisinin ya da en yakın atasının `webDomain` değeridir. Eşleştirme parola alanının çerçevesindeki alan adıyla yapılır; başka çerçevelerdeki kullanıcı adı ve parola alanları doldurulmaz. Giriş formu bütünüyle bir çerçevedeyse (başka bir sitenin giriş kutusu) eşleştirme o çerçevenin alan adıyla yapılır, çünkü parola oraya gider. Kart alanları süzülmez: ödeme sağlayıcısının çerçevesinde durmaları olağandır ve kart bir siteye bağlı değildir.

**Kayıttaki adresler:** Şema yalnızca adresin başında tanınır ve yalnızca `http` ile `https` alan adı verir; şeması olmayan adres `https` sayılır. `androidapp://` gibi bir paket adı alan adı sayılsaydı `com.amazon.mShop.android.shopping` kayıtlı alan adı olarak `android.shopping`'e indirgenirdi; o siteyi alan herkes eşleşirdi.

Tarayıcıda kayda bağlı uygulamalar dikkate alınmaz, yalnızca adresler karşılaştırılır. Eşleşen kayıtlar listenin üstünde, diğerleri altında gösterilir; kullanıcı aramayla bütün kayıtlara ulaşabilir.

**WebView içeren uygulamalar:** Tarayıcı olmayan bir uygulamanın formunda `webDomain` olsa da bu değer eşleştirmede kullanılmaz. Uygulama içindeki bir web sayfasına doldurulan parolayı, sayfayı barındıran uygulama da okuyabilir (2023'te yayımlanan AutoSpill). Böyle bir formda yalnızca o uygulamaya bağlı kayıtlar eşleşir. Bazı WebView sürümleri alan adını hiç bildirmiyor (Android 14 emülatöründe görüldü); bu yüzden formda WebView ya da HTML alanı varsa da web sayfası sayılır ve aynı uyarı verilir.

### Şüpheli durumlar

Şu durumlarda kayıt doldurulmadan önce ne olduğunu anlatan bir uyarı gösterilir ve ayrıca onay istenir:

- **Eşleşme yok:** Kullanıcı kaydı listeden kendisi seçer. Uygulamanın adı, paket adı ve imza özeti gösterilir. Kullanıcı isterse uygulama kayda bağlanır. Böylece sonraki doldurmada eşleşme kendiliğinden olur.
- **WebView:** Tarayıcı olmayan bir uygulama web sitesi kaydı istiyor.
- **Şifresiz bağlantı:** Sayfa `http` ile açılmış.
- **İmza tutmuyor:** Kayıtta bağlı uygulamanın paket adı aynı ama imzası farklı. Bu durumda kayıt eşleşmiş sayılmaz. Kullanıcı yine de seçerse uyarı özellikle "bu uygulama sahte olabilir" der. Bu durumda bağlama önerilmez; yoksa sahte uygulamanın imzası kayda girerdi.

Birden fazla durum aynı anda geçerliyse hepsi tek pencerede yazılır. Uygulama hedeflerinde pencere uygulamanın adını, paket adını ve imza sertifikasının tam SHA-256 özetini gösterir; tarayıcıda bunun yerine adres çubuğuna bakılması söylenir. Bağlama yalnızca imzası okunabilen, tarayıcı olmayan bir uygulama için, kutu işaretlenirse yapılır; varsayılan kapalıdır. Eşleşen ve `https` olan kayıt sorulmadan doldurulur. Uyarısız tek bir eşleşme varsa liste hiç açılmadan doldurulur ([Akış](#akış), 4. adım); şüpheli durumlardan biri varsa bu yapılmaz, liste ve uyarı gelir.

### Yeni parola kaydetme

Yanıtta bir `SaveInfo` bulunur. Kullanıcı formu gönderince sistem kaydetmeyi önerir ve `onSaveRequest` çağrılır. Servis yine kasaya dokunmaz; formdaki değerleri kendi kaydetme ekranına verir ve ekranı kendisi açar. `SaveCallback.onSuccess(IntentSender)` kullanılmaz: sistem o başlatıcıyı formun ekranı üzerinden açıyor ve giriş ekranı kapanmışsa (çoğu uygulama girişten sonra kapatır) hiçbir şey açılmıyor; Android 11 emülatöründe görüldü. Sistemin bağladığı doldurma servisi arka plandan ekran açabilir. Kullanıcı kasayı açar, kaydı görür, gerekirse düzenler ve kaydeder. Kaydettikten sonra kasa kilitlenir ve ekran kapanır. Kaydetme ekranı da dışarıya açık değildir ve verileri başka bir yere yazmaz.

- **Hangi alanlar:** Formda yeni parola alanı varsa (kayıt veya parola değiştirme formu) kaydedilen parola odur, yoksa giriş parolasıdır. Kullanıcı adı ve eski parola alanları isteğe bağlıdır. Parola alanı olmayan formda kaydetme önerilmez.
- **Değerler niyete konmaz.** Niyetler sistem sürecinden geçer ve orada tutulur. Servis ile ekran aynı süreçte çalıştığından değerler bellekte rastgele bir anahtarla bekler; niyet yalnızca anahtarı taşır. Ekran açılınca değerleri alır ve bekleyen kopyayı siler. Süreç kapanırsa değerler de gider.
- **Bağlama:** Güvenilen tarayıcıda sitenin adresi kayda eklenir. Başka bir uygulamada uygulamanın paket adı ve imza özetleri eklenir. WebView'ın bildirdiği alan adı doğrulanamadığı için eklenmez; kayıt uygulamaya bağlanır ve ekran bunu söyler. İmzası okunamayan uygulama bağlanmaz ve ekran bunu da söyler; kullanıcı uygulamayı ilk doldurmada bağlayabilir.
- **Paket görünürlüğü:** Android 11'den beri bir uygulama diğerlerini ancak izin verilirse görür. Doldurma ekranını hedef uygulama başlattığı için Android KeyKey'e o uygulamayı gösterir. Kaydetme ekranını ise servis başlatır; ek bir sorgu olmasa KeyKey o uygulamada daha önce doldurma yapmadıysa uygulamanın adı ve imzası okunamazdı. Bu yüzden manifestteki `<queries>` iki şey bildirir:

  - Ana ekranda simgesi olan uygulamalar (`MAIN`/`LAUNCHER` niyeti). KeyKey böylece bu uygulamaları görebilir. İnternet izni olmadığı için bu bilgi cihazdan çıkamaz. Bütün paketleri görme izni (`QUERY_ALL_PACKAGES`) istenmez.
  - Güvenilen tarayıcılar, adıyla. Bu liste `trusted-browsers.mjs` ile tarayıcı listesiyle birlikte üretilir ve bir test ikisinin aynı kaldığını denetler.

  Ana ekranda simgesi olmayan bir uygulamanın imzası yine okunamayabilir; o zaman kayıt bağlanmadan kaydedilir ve ekran bunu söyler.

  Aynı görünürlükle kayda bağlı uygulamanın simgesi de okunur ve kartta silik olarak gösterilir. Simge `PackageManager`dan o an alınır, diske yazılmaz ve yalnızca onu gösteren ekran açıkken bellekte durur; görünmeyen uygulamada çizgi simge çıkar.
- **Var olan kayıt:** Bu hedefle zaten eşleşen ve aynı kullanıcı adını taşıyan bir kayıt varsa, ekran onun parolasını güncellemeyi önerir; eski parola geçmişe girer. Eşleşmeyen bir kaydın parolası önerilmez; böylece sahte bir uygulama başka bir kaydın parolasını değiştirtemez. Parola da aynıysa ekran kaydın zaten var olduğunu söyler.

### Satır içi öneriler

Android 11+ klavyelerde öneri şerit halinde gösterilebilir. Klavye satır içi öneri isterse yanıtta yalnızca satır içi görünüm dikkate alınır; bu yüzden öneri her iki görünümle de verilir. KeyKey'in şeridinde de yalnızca "KeyKey ile doldur" yazar. Şerit, açılır listeyle aynı kimlik doğrulama akışını başlatır.

### 2FA kodu

Doldurulan kayıtla eşleşmiş bir 2FA hesabı varsa, ayar açıksa, güncel kod doldurmadan sonra [güvenli panoya](#pano) kopyalanır. Ayar varsayılan olarak açıktır.

- Kod, kasa kilitlenmeden önce hesaplanır ve ekran kapanmadan panoya yazılır. Kopyalama başarısız olursa doldurma yine yapılır.
- Yalnızca TOTP hesapları kopyalanır. HOTP'de kod üretmek sayacı ilerletir; bunu kullanıcı istemeden yapmamak gerekir.
- Birden çok hesap bağlıysa en eski olanın kodu kopyalanır. Çöp kutusundaki hesaplar kullanılmaz.
- Kullanıcı kasayı doldurma ekranında az önce açtığı için [ek onay](#kodları-görmek-için-ek-onay) ayarı burada yeniden sorulmaz.

### Kart doldurma

Ödeme formlarında kart da doldurulur. Akış girişle aynıdır: servis kasaya dokunmaz, öneri değer taşımaz, kart KeyKey'in ekranında kasa açıldıktan sonra seçilir. Tasarım: [kart doldurma](kart-doldurma.md).

**Alan tanıma.** Kart alanları (numara, kart sahibi, son kullanma, güvenlik kodu) giriş alanlarından önce tanınır. Güçlü kanıt alanın kart olduğunu tek başına söyler: Android ipuçları (`creditCardNumber` vb.), HTML `autocomplete` (`cc-number` vb.), Chrome'un HTML niteliklerinde gönderdiği kendi tahmini (`computed-autofill-hints`) ve güvenlik kodunun kendine özgü adları (`cvv`, `cvc`, `csc`). Alanda kart dışı bir geliştirici ipucu varsa alan kart sayılmaz; Android 14 ve sonrasının ipucusuz gizli kutulara kendiliğinden eklediği `passwordAuto` ise geliştirici ipucu sayılmaz, yoksa gizli rakam CVV kutusu yeniden parola sanılır. Türkçe ve İngilizce sözcükler zayıf kanıttır: ancak formda numara, son kullanma ve güvenlik kodundan en az iki grup birlikte görülünce sayılır. Böylece kart numarasıyla giriş yapılan bir banka formu giriş formu kalır, kart önerisi çıkmaz. Yalnızca zayıf kanıtla karar verilecekken formda kart dışı bir parola kutusu ya da kart şifresi varsa form yine giriş formudur: çevrim içi ödeme PIN istemez, "güvenlik kodu" ise banka girişinde captcha ya da SMS kodu olabilir. Aynı yeri tutan güçlü kanıtlı bir alan varsa sözcükle bulunan tahmin geçersizdir ve o alan doldurulmaz (ipuçlu numara kutusunun yanındaki ikinci "numara", tek kutulu son kullanmanın yanındaki "Ay" listesi). Kart türü adları ("kredi kartı") tek başına numara sayılmaz; hediye ve üyelik kartları, taksit seçimi ve SMS kodları kart sayılmaz.

**Güvenlik kodu parola değildir.** Güvenlik kodu kutuları çoğunlukla gizli rakam kutusudur. 1.4.0'a kadar servis onları parola sanıyordu: ödeme formunda parola önerisi çıkıyor ve form gönderilince güvenlik kodunu parola diye kaydetmek öneriliyordu. Artık kart sayılan alan giriş tanımaya girmez; kaydetme önerisi de yalnızca giriş alanlarından kurulur. Ödeme formu sayılmayan bir formda da güvenlik kodu sözcükleriyle bulunan gizli kutu parola sayılmaz. Ödeme formunda "kart şifresi" ya da "card PIN" diyen kutu kart PIN'i sayılır ve hiçbir zaman doldurulmaz.

**İki öneri.** Formda hem giriş hem kart alanı varsa (misafir alışverişi) iki öneri ayrı ayrı döner; her biri yalnızca kendi alanlarını kapsar. Android bir öneriyi yalnızca odaktaki alana değer veren öneriler arasında gösterir, kullanıcı hangi kutuya dokunduysa onun önerisini görür. İki önerinin niyetleri eylemleriyle (`FILL_LOGIN`, `FILL_CARD`) ayrılır; ekran isteğin türünü buradan bilir. Kotlin her çağrıyı isteğin türüne göre denetler: kart isteğine parola, giriş isteğine kart doldurulmaz.

**Kart seçimi.** Kart bir siteye ya da uygulamaya bağlı olmadığı için eşleştirme yoktur. Çöp kutusunda olmayan bütün kartlar listelenir ve kart her zaman listeden seçilir, tek kart olsa da. Başlık kartın nereye gideceğini söyler: güvenilen tarayıcıda sitenin adı, başka her yerde uygulamanın adı; WebView'ın bildirdiği alan adı gösterilmez. Arama ada, kart sahibine ve markaya bakar; numaraya ve güvenlik koduna bakmaz.

**Uyarı.** Güvenilen tarayıcıda sayfa `http` ile açılmışsa kart doldurulmadan önce uyarılır ve onay istenir. WebView uyarısı kartta verilmez: girişteki uyarının nedeni bir siteye ait parolanın o siteyi taklit eden uygulamaya gitmesidir; kart bir siteye ait değildir ve kullanıcı kartı hangi uygulamaya verdiğini başlıkta görür.

**Değerler.** Seçilen kartın numarası, kart sahibi, son kullanma ayı ve yılı ve güvenlik kodu Kotlin'e verilir; PIN köprüden hiç geçmez. Kotlin her alanın değerini alanın türüne göre biçimler (tek kutuda AA/YY ya da ipucunun istediği biçim, açılır listede ayla ya da yılla eşleşen seçenek, tarih alanında ayın 1'i öğlen UTC) ve değeri olmayan alanı boş bırakır. Kasa, değerler forma verilmeden önce kilitlenir. Kart doldurmada panoya hiçbir şey kopyalanmaz. Bildirim kartın adını gösterir; adı boşsa marka ve son dört haneyi ("Visa •••• 1111 dolduruldu"). Son dört hane kasa listesinde ve fişlerde de görünen bilgidir; numaranın kalanı, son kullanma ve güvenlik kodu bildirime girmez.

**Kaydetme yok.** Forma elle yazılan kart KeyKey'e kaydedilmez; kaydetme önerisi yalnızca girişler içindir.

### Chrome

Chrome 135'ten beri parolaları başka bir doldurma servisine bırakması için kullanıcının Chrome ayarlarında "Autofill using another service" seçeneğini açması gerekir. KeyKey'in kurulum ekranı bu ayara doğrudan götürür (`ACTION_APPLICATION_PREFERENCES`, `CATEGORY_APP_BROWSER`, `CATEGORY_PREFERENCE`). Ayarın açık olup olmadığını okumak `READ_USER_DICTIONARY` izni ve paket sorgusu istediği için okunmaz. Kullanıcıya, seçimden sonra Chrome'un gösterdiği "Chrome'u yeniden başlat" düğmesine dokunması söylenir; dokunmazsa seçim kaybolur. Kurulu Chrome 135'ten eskiyse bağlantı gösterilmez, güncellemesi istenir.

### Samsung Internet

Samsung Internet 30 (Samsung Galaxy S20 FE, Android 13) KeyKey'i seçili doldurma servisi olarak görüyor, ama giriş formunda servise hiç istek göndermiyor. Yalnızca kendi kayıtlı parolalarını, profillerini ve Samsung Pass'i öneriyor; tarayıcının kendi doldurma ayarları kapatılınca da istek gelmiyor. Chrome'daki gibi başka bir servise bırakma ayarı yok, ayar niyetine de yanıt vermiyor. Bu tarayıcıda KeyKey'in yapabileceği bir şey olmadığı için desteklenmiyor; parola KeyKey'den kopyalanarak girilebilir. Aynı telefonda Samsung klavyesiyle uygulamalarda doldurma ve kaydetme çalışıyor. Öneri ilk dokunuşta klavye şeridinde çıkıyor; kutudaki yazı silinince klavye şerit isteğini yinelemediği için sistem aynı öneriyi kutunun altındaki listede gösteriyor. İki görünüm de aynı kilitli öneri, değer taşımıyor.

Ayarlar ekranı KeyKey'in seçili servis olup olmadığını da gösterir (`AutofillManager.hasEnabledAutofillServices`). Dokununca sistemin servis seçimi açılır (`ACTION_REQUEST_SET_AUTOFILL_SERVICE`). Sistem, niyetteki paketin isteyen uygulama olduğunu `getCallingPackage` ile denetler ve bu yalnızca sonuç beklenen başlatmada dolu olduğu için niyet `startActivityForResult` ile açılır. Ayara gitmek uygulamayı arka plana aldığı için kasa kilitlenir; dönüşte durum yeniden okunur. Eski uyumluluk modu (`compatibilityPackages`) kullanılmaz; Chrome onu 2025'te kaldırdı.

### Doldurma sistemine katılmayan ekranlar

Bazı uygulamalar giriş kutularını Android'in doldurma sistemine bildirmiyor. Kutuya dokunulunca klavye açılıyor ama sistem doldurma oturumu açmıyor ve hiçbir servise istek göndermiyor. Bu ekranlarda KeyKey'in yanında Google Otomatik Doldurma ya da Samsung Pass da çalışmaz. Doldurma önerisi gelmediği gibi kaydetme önerisi de gelmez, çünkü ikisi de aynı yanıtla verilir.

Örnek: HoYoLAB 4.21.0'ın giriş ekranı (Samsung Galaxy S20 FE, Android 13, 2026-11-09, #94). Ekran Jetpack Compose ile yazılmış, iki kutuya dokununca da `dumpsys autofill` oturum göstermedi. Aynı uygulamanın klasik View'larla yazılmış parola değiştirme ekranı ise KeyKey'e istek gönderiyor ve orada kaydetme önerisi çıkıyor.

Bu ekranlarda kullanıcı adı ve parola KeyKey'den kopyalanarak girilir; pano kısa süre sonra kendiliğinden temizlenir. Erişilebilirlik servisiyle doldurma bilerek yapılmaz: böyle bir servis her uygulamanın ekranını okuyabilir ve KeyKey bu servisleri [tehdit modelinde](#tehdit-modeli) korunmayanlar arasında sayıyor. KeyKey'in kendi klavyesi 1.0 sonrası fikirler arasında.

### Eşzamanlılık

Ana uygulama ve doldurma ekranı aynı süreçte, aynı veritabanı dosyasına iki ayrı bağlantıyla erişebilir. SQLite dosya kilidini kullanır. Aynı anda yazma olursa bağlantı hemen hata vermesin diye `busy_timeout` beş saniyedir. Ana uygulama arka plana geçince kilitlenir; kullanıcı bir bekleme süresi seçtiyse kasa açık kalabilir, o zaman dönüşte parola listesi yeniden okunur ([Otomatik kilit](#otomatik-kilit)). Kilitlendiyse liste kasa yeniden açılınca okunur.

### Sınırlar

1. Doldurulan değer hedef uygulamaya verildikten sonra onu korumak bizim elimizde değildir.
2. Kötü amaçlı bir erişilebilirlik servisi veya klavye, doldurulan alanı okuyabilir. [Tehdit modelinde](#tehdit-modeli) bunlar korunmayanlar arasında.
3. Güvenilen tarayıcıların kendileri doğru alan adını bildirmek zorundadır; bir tarayıcı açığı burada da açık olur.
4. İlk bağlamada kullanıcı onay verir: sahte bir uygulamayı gerçek uygulama sanıp kayda bağlarsa, sonraki doldurmalar o sahte uygulamaya da eşleşir. Uyarı bunu önlemeye çalışır, garanti edemez.
5. Kart bir siteye ya da uygulamaya bağlı olmadığı için KeyKey kartın gideceği yeri doğrulayamaz. Kart yalnızca kullanıcı listeden seçince doldurulur ve başlık hedefi söyler; kartı ödeme yapmak istemediği bir uygulamaya vermemek kullanıcıya kalır.
6. Kart alanlarını tanımak bir tahmindir. Alanları anlamsız adlandırılmış, ipucusuz bir formda kart önerisi çıkmayabilir; tuhaf adlandırılmış bir formda bir değer yanlış kutuya gidebilir. Kullanıcı formu göndermeden önce görür.

## Yedekleme

Sunucu olmadığı için telefon kaybolursa tek kopya kullanıcının aldığı yedektir. Yedek, kasanın bütününü taşıyan tek bir `.keykey` dosyasıdır ve ayrı bir parola istemez: alındığı andaki ana parolayla veya kurtarma anahtarıyla açılır.

**Neden ayrı bir yedek parolası yok:** İkinci bir parola unutulmaya açıktır, unutulursa yedek işe yaramaz. Kurtarma anahtarı zaten kâğıtta durduğu için yeni telefonda ana parola hatırlanmasa bile yedek açılabilir. Bedeli [bilinen sınırlardaki](#bilinen-sınırlar) beşinci madde: ana parola değişse de eski yedekler eski parolayla açılmaya devam eder.

### Yedek biçimi

```text
dosya   = sihir (8 bayt, ASCII "KEYKEYBK") || sürüm (1 bayt, 0x01)
          || üst bilgi uzunluğu (4 bayt, büyük uçlu) || üst bilgi
          || akış başlığı (24 bayt) || parça || parça || ...
parça   = uzunluk (4 bayt, büyük uçlu) || şifreli parça
```

- **Üst bilgi:** Kasanın [üst bilgisi](#kasa-üst-bilgisi), aynı JSON biçiminde ve aynı katı kurallarla okunur. Parola ve kurtarma yuvalarını, Argon2id parametrelerini ve tuzu taşır, kayıt içermez. En fazla 4096 bayttır.
- **Yedek anahtarı:** `HKDF-Expand(kasa anahtarı, "keykey/v1/backup", 32)`. Kasa anahtarı yuvalardan biri açılarak elde edilir, yani yedek kasayla aynı yolla açılır.
- **Şifreleme:** libsodium `crypto_secretstream_xchacha20poly1305`. Akış başlığı her yedekte rastgele üretilir, bu yüzden aynı anahtarla alınan yedekler birbirine benzemez.
- **Ek doğrulama verisi:** Her parçada `keykey/v1/backup` ve dosyanın başından üst bilginin sonuna kadarki baytlar ([AD biçiminde](#ek-doğrulama-verisi-ad)). Üst bilgide tek bir bayt değişirse ilk parça açılmaz.
- **Parçalar:** Düz metin en fazla 64 KiB'lık parçalara bölünür. Son parça `FINAL`, diğerleri `MESSAGE` etiketiyle şifrelenir. Dosya kesilirse son parça eksik kalır; son parçadan sonra veri gelirse dosya reddedilir. Parçaların sırası değiştirilemez, çünkü akışın durumu her parçada ilerler.

**Düz metin** şu JSON'dur:

```json
{
  "version": 2,
  "createdAt": 1730000000000,
  "records": [
    {
      "id": "<16 bayt>",
      "type": "login",
      "createdAt": 1730000000000,
      "updatedAt": 1730000000000,
      "blob": "<şifreli kayıt>"
    }
  ]
}
```

- Kayıtlar veritabanındaki halleriyle, yani [kayıt biçiminde](#kayıt-biçimi) şifreli olarak taşınır. Yedek bu yüzden iki katmanlıdır: dosyayı açan biri bile kayıtları ayrıca kasa anahtarının alt anahtarlarıyla çözmek zorundadır. Kayıt sayısı, türleri ve zaman damgaları da dış katmanda gizli kalır; veritabanı dosyasından farklı olarak yedek bunları ele vermez.
- **İçerik sürümü.** Sürüm 1'de `type` yalnızca `login`, `otp` veya `settings` olabilir. Sürüm 2 (1.4.0) `card` ve `note` türlerini ekledi. 1.4.0-1.6.0, kart ya da not yoksa içeriği yine sürüm 1 olarak yazar; böylece kartsız yedekler 1.4.0 öncesi sürümlerle de açılır. 1.3.0 ve öncesi, sürüm 2 bir yedeği "bozuk ya da değiştirilmiş" diye reddeder. Sürüm 3 (1.7.0) yeni tür eklemez; ayar kaydının sürüm 6'sı ve Steam hesapları (`kind: steam`) için gelir. Kayıtlar şifreli olduğundan yedek yazılırken içleri görünmez; bu yüzden 1.7.0'dan itibaren her yedek sürüm 3 ile yazılır. Sürüm 4 (1.8.0) ayar kaydının sürüm 7'si ve senkron dosyasının `sync` nesnesi için gelir; 1.8.0'dan itibaren her yedek sürüm 4 ile yazılır. Sürüm 1, 2, 3 ve 4 okunmaya devam eder. 1.4.0'dan sonra daha yeni bir dosya ya da içerik sürümü ayrı bir hatayla (`NewerBackupException`) ayrılır ve kullanıcıya uygulamayı güncellemesi söylenir. İçerik sürümü, JSON'un alanları denetlenmeden önce okunur; sonraki bir sürüm kök alanlarını değiştirse de "daha yeni" diye bildirilir. Sürüm 1 içerikte `card` ya da `note` türü reddedilir.
- **Kayıt içeriği sürümü değişirse yedeğin içerik sürümü de artar.** Eski bir sürüm tanımadığı kayıt içeriğini "bozuk" diye reddeder; içerik sürümü artarsa "daha yeni yedek" der. 1.4.0 öncesinde parola (sürüm 2) ve ayar (sürüm 5) kayıtları bu kural olmadan değişti; o dönemin eski sürümleri yeni yedekleri "bozuk" diye reddediyor. Bir test, kayıt içerik sürümlerini yedeğin içerik sürümüyle birlikte sabitliyor; biri değişince test kırılır ve bu adım hatırlanır.
- **Senkron dosyası:** Aynı biçimde, içerik sürümü 4 ve kökte bir `sync` nesnesiyle yazılır ([senkron](senkron.md#senkron-dosyası)): `device` (altı küçük onaltılık karakter), `deviceName` (en çok 64 karakter ya da `null`), `passwordChangedAt` ve `recoveryChangedAt` (yuva zamanları ya da `null`), `deleted` (silme kayıtları: `id` ve `deletedAt`; kimlik tekrarlanamaz). Bütün alanlar zorunludur. `sync` yalnızca sürüm 4'te bulunabilir. Senkron dosyası ayar kaydı taşıyamaz. Kayıtlar ve silme kayıtları 100 000 sınırına birlikte sayılır. Geri yükleme senkron dosyasını yedek gibi açar ve `sync` nesnesini kullanmaz.
- İkili alanlar Base64'tür.
- Parmak izi yuvası ve hatalı deneme sayacı yedeğe girmez. Parmak izi yalnızca o cihazın Keystore anahtarıyla açılır, sayaç da cihaza aittir.
- **Okurken doğrulama katıdır:** Sihir, sürüm, uzunluklar, üst bilgi ve JSON alanları tek tek denetlenir. Bilinmeyen sürüm, eksik veya fazla alan, yinelenen kayıt kimliği ve yanlış tür reddedilir.
- **Sınırlar:** Dosya en fazla 64 MiB, kayıt sayısı en fazla 100 000 olabilir. Argon2id parametreleri kasadaki tavanla sınırlıdır; böylece değiştirilmiş bir dosya cihazı belleksiz bırakamaz.
- **Yazarken boyut denetimi:** Notlar 64 KiB'a kadar olabildiği için kasa sınırı aşabilir. Dosyanın boyutu şifrelemeden önce kesin olarak hesaplanır (baş kısım, akış başlığı, düz metin, her parçanın uzunluk alanı ve etiketi); 64 MiB'ı aşarsa yedek yazılmaz (`BackupTooLargeException`). Bir test tam 64 MiB'lık yedeğin yazılıp okunduğunu, bir bayt fazlasının yazılmadığını denetler. Elle yedekte kullanıcıya sebebi söylenir, otomatik yedekte "yazılamadı" durumu gösterilir. Okunamayacak bir dosya böylece hiç üretilmez.

### Yedek alma

- Dosya Android'in belge oluşturma ekranıyla (`ACTION_CREATE_DOCUMENT`) kaydedilir. Kullanıcı konumu seçer; Drive gibi bulut konumları kendi uygulamaları üzerinden çalışır. KeyKey'e depolama veya internet izni gerekmez ve uygulamanın klasörüne hiçbir şey yazılmaz.
- Önerilen dosya adı `keykey-yedek-YYYY-AA-GG.keykey` biçimindedir.
- Yedek, kasa açıkken bellekte üretilir; seçici açıkken yalnızca şifreli baytlar bekler. Seçici açıkken kasa [otomatik kilit istisnasıyla](#otomatik-kilit) açık kalır.
- Yazılan dosya hemen geri okunur ve bayt bayt karşılaştırılır. Tutmazsa yarım dosya silinmeye çalışılır ve kullanıcıya hata gösterilir. Yazılan baytlar işi bitince bellekte sıfırlanır.
- Son yedeğin zamanı [ayar kaydında](#kodları-görmek-için-ek-onay), yani kasanın içinde şifreli tutulur ve Ayarlar'da gösterilir.

### Otomatik yedek

Kullanıcı bir klasör seçerse, kasa açıkken kayıtlar değiştikçe o klasöre kendiliğinden yedek yazılır. Tasarım, seçilmeyen yaklaşımlar ve gerekçeler: [otomatik yedek](otomatik-yedek.md).

- **Biçim ve anahtar elle yedekle aynı.** Dosya `BackupService` ile, [yedek biçiminde](#yedek-biçimi) üretilir; alındığı andaki ana parola veya kurtarma anahtarıyla açılır. Kripto çekirdeğinde değişiklik yoktur.
- **Yalnızca kasa açıkken.** Yedek kasa anahtarı gerektirdiği için arka planda çalışan bir iş ve kasa dışında saklanan bir anahtar yoktur. Parola, 2FA, kart veya not kayıtları değişince (5 sn sonra, peş peşe değişiklikler tek yedekte), kasa açılınca (değişiklik son yedekten yeniyse), ana parola değişince (kurtarma anahtarıyla yeni parola belirlenince de), kurtarma anahtarı yenilenince ve kasaya birleştirerek geri yüklenince yazılır. Parola ya da kurtarma anahtarı değiştiği anda kasa kilitlenirse yedek, kasa yeniden açılınca yazılır. Kasa kilitlenince bekleyen yedek iptal olur.
- **Klasör.** Android'in klasör seçicisiyle (`ACTION_OPEN_DOCUMENT_TREE`) seçilir; KeyKey yalnızca o klasör için kalıcı okuma ve yazma izni alır, depolama veya internet izni gerekmez. Klasörün adresi [ayar kaydında](#kodları-görmek-için-ek-onay), kasanın içinde şifreli durur. Otomatik yedek kapatılınca veya klasör değişince izin bırakılır; klasördeki dosyalar silinmez. İzin cihaza bağlı olduğu için açık kasanın yerine yedek konunca bu cihazın klasörü korunur.
- **Yazma.** Her yedek yeni bir dosyadır (`keykey-otomatik-YYYY-AA-GG-SSddss-<cihaz>.keykey`, İngilizce arayüzde `keykey-auto-…`). `<cihaz>` bu kurulumun kasanın dışında tutulan, rastgele altı onaltılık karakterlik kimliğidir; gizli değildir, yedekle taşınmaz. Dosya önce `.part` ekli bir ara adla yazılır, geri okunup karşılaştırılır ve ancak tutarsa son adına çevrilir; tutmazsa silinir ve eski yedeklere dokunulmaz. Sağlayıcı yeniden adlandırmayı desteklemiyorsa son adla doğrudan yazılır. Sağlayıcı dosyaya başka bir ad verdiyse (`… (1)`) dosya silinir ve yazma başarısız sayılır. Yazmadan önce kalıcı izin denetlenir; başka telefondan gelen bir klasör adresi için izin yoktur ve durum kullanıcıya gösterilir.
- **Budama.** Yalnızca yeni dosya doğrulandıktan sonra ve yalnızca adı otomatik yedek kalıbına tam uyan, bu kurulumun cihaz kimliğini taşıyan dosyalar: en yeni 5 dosya ve en yeni 14 günün her birinin en yenisi kalır. Bu kurulumun yarım kalmış ara dosyaları da silinir; alt klasörlere dokunulmaz. Aynı klasörü kullanan başka bir kurulumun yedekleri silinmez. Elle alınan yedekler ve başka dosyalar hiç silinmez.
- **Kopya sayısı.** Klasördeki her dosya, ele geçiren birinin ana parolayı çevrimdışı deneyebileceği bir kopyadır ([bilinen sınır 4](#bilinen-sınırlar)); eşitleme uygulaması bunları başka cihazlara da taşır. Kullanıcıya açarken söylenir.

### Geri yükleme

1. Dosya belge seçiciyle seçilir ve yapısı denetlenir. Kasanın kendisine henüz dokunulmaz.
2. Kullanıcı yedeğin alındığı andaki ana parolayı veya kurtarma anahtarını girer. Yanlışsa `WrongSecretException`.
3. Bütün parçalar çözülür, ardından **her kayıt** yedeğin kasa anahtarıyla tek tek çözülüp biçimi doğrulanır. Tek bir kayıt bile açılmazsa geri yükleme durur ve hiçbir şey yazılmaz.
4. Yazma tek SQLite işleminde yapılır. Yarıda kalırsa kasa eski halinde kalır.

| Durum | Ne olur |
|---|---|
| İlk kurulum (kasa yok) | Yedeğin üst bilgisi ve kayıtları olduğu gibi yazılır. Kasa, yedeği alan kasanın aynısı olur; aynı ana parola ve kurtarma anahtarıyla açılır. Kullanıcı yedeği açarken parolayı zaten girdiği için kasa hemen açık gelir. Parmak izi yeniden açılmalıdır. |
| Senkrondan kurulum (kasa yok) | Klasördeki en son değişen senkron dosyası açılır. Üst bilgi, kayıtlar, silme kayıtları ve yuva zamanları dosyadan yazılır; ayar kaydı varsayılan ayarlar ve bu telefonun senkron bilgileriyle oluşturulur. Kasa açık gelir ve eşitlenir. |
| Açık kasaya **birleştirme** | Yedeğin kayıtları çözülür ve açık kasanın anahtarıyla yeniden şifrelenir. Kayıt kimlikleri korunur, böylece 2FA hesaplarının parola kayıtlarıyla bağı kopmaz. Aynı kimlikte kayıt varsa `updatedAt` değeri yeni olan kalır. Eklenen ya da güncellenen kaydın silme kaydı kaldırılır; senkron açıksa bu kayıtların `updatedAt` değeri şimdi yapılır, böylece öteki telefonlardaki daha eski silmeler onları yeniden silmez. Ayar kaydı alınmaz, açık kasanın ayarları korunur. |
| Açık kasayı **değiştirme** | Ek onay ister. Kasanın bütün kayıtları ve silme kayıtları silinir, yedeğin üst bilgisi ve kayıtları yazılır. Parmak izi yuvası ve hatalı deneme sayacı silinir, kasa kilitlenir ve yedeğin ana parolası istenir. Senkron bilgileri, otomatik yedek klasörü gibi, bu telefonunkidir: yedek aynı kasanınsa senkron açık kalır ve kayıtların `updatedAt` değeri şimdi yapılır (yedekte olmayan kayıtlar eşitlemede öteki telefonlardan geri gelir); başka kasanınsa senkron kapanır. |

Senkron dosyası Geri yükle'de yedek gibi açılır; içindeki `sync` nesnesi (silme kayıtları, yuva zamanları) kullanılmaz.

Geri yükleme bir yedeğin parolasını denemek için kullanılsa da kasanın hatalı deneme sayacına eklenmez: dosyayı ele geçiren biri onu zaten uygulama dışında deneyebilir.

Son yedek zamanı dosya kaydedildikten sonra yazıldığı için yedeğin içindeki ayar kaydında eski kalır. İlk kurulumda ve değiştirmede ayar kaydındaki bu zaman, daha yeni değilse yedeğin alındığı an yapılır; kasa o yedeğin kendisidir, hatırlatıcı "hiç yedek yok" dememelidir. Ayarları hiç değiştirilmemiş bir kasanın ilk yedeğinde ayar kaydı yoktur; o zaman varsayılan ayarlarla ve bu zamanla yeni bir ayar kaydı eklenir.

### Yedek hatırlatıcısı

- Son yedekten sonra değişmiş bir parola, 2FA, kart veya not kaydı varsa ve son yedek 14 günden eskiyse (ya da hiç yedek alınmadıysa) kasa ekranında bir hatırlatma çıkar. Değişiklik, veritabanındaki şifresiz `updatedAt` değerinden anlaşılır; ayar kaydı sayılmaz.
- "Sonra" seçilirse hatırlatma 7 gün susar. Bildirim izni istenmez, hatırlatma yalnızca uygulama içindedir.
- Son yedek zamanı ve susturma süresi ayar kaydında tutulur (ayar kaydı biçimi sürüm 3).

### Parola içe aktarma

| Kaynak | Biçim | Not |
|---|---|---|
| Bitwarden | Şifresiz JSON ve CSV dışa aktarma | Giriş, kart ve güvenli not kayıtları alınır (aşağıda). `totp` alanı 2FA hesabı olarak eklenir ve kayda bağlanır; `steam://ANAHTAR` (1.7.0) Steam hesabı olur. Metin ve gizli özel alanlar alınır. CSV'deki `login_uri` alanı, Bitwarden'ın okuyucusundaki gibi kendi içinde bir CSV satırıdır. Parola korumalı veya hesaba bağlı şifreli JSON desteklenmez; kullanıcıya şifresiz dışa aktarması söylenir. Örneklerden biri 2026-11'de alınmış gerçek bir JSON dışa aktarmasıdır; kişisel değerleri sahteleriyle değiştirildi. |
| Chrome | Parolalar CSV'si (`name,url,username,password,note`) | Android'de Chrome'un parola yöneticisi `name` sütununa kayıt adı yerine alan adını yazar. Örneklerden biri Android Chrome 145'in gerçek dışa aktarmasıdır. |
| Firefox | Parolalar CSV'si (`url,username,password,httpRealm,formActionOrigin,guid,timeCreated,timeLastUsed,timePasswordChanged`) | Kayıt adı yoktur, ad adresin alan adından gelir. Yalnızca adres, kullanıcı adı ve parola alınır; `httpRealm`, `formActionOrigin`, `guid` ve zaman sütunları yok sayılır. Biçim, Chrome'dan ayrılması için `httpRealm` ve `formActionOrigin` sütunlarından tanınır. |
| KeePassXC | CSV dışa aktarma | `TOTP` sütunu 2FA hesabı olarak eklenir. Grubun yolu, kök grup atılarak klasör olur; kök grubun adı KeePassXC'in arayüz diline göre değişir. Örnek, KeePassXC 2.8.0'ın kendi komut satırı aracıyla alınmış gerçek bir dışa aktarmadır. |
| KeePass 2, KeePassXC, KeePassDX, Keepass2Android | Şifreli `.kdbx` dosyasının kendisi (1.9.0) | Ana parola ve/veya anahtar dosyasıyla açılır; kurallar aşağıda, [KeePass dosyaları](#keepass-dosyaları). |

- Biçim, dosyanın ilk satırındaki sütun adlarından veya JSON yapısından anlaşılır.
- CSV okuyucu kendi kodumuzdur ve RFC 4180'e uyar: tırnak içinde virgül ve satır sonu, `""` kaçışı, isteğe bağlı UTF-8 BOM. Rastgele bozulmuş girdilerle de sınanır.
- Notlardaki satır sonları `\n` olur; Windows'ta alınan dışa aktarmalar CRLF yazar.
- Dosyalar güvenilmeyen veri sayılır: bilinmeyen sütunlar ve alanlar yok sayılır, bozuk satır atlanır, bozuk dosya uygulamayı düşürmez. 2FA bağlantıları [`otpauth://` kurallarıyla](#otpauth-bağlantıları) okunur.
- Kimlik ve SSH anahtarı gibi desteklenmeyen kayıtlar atlanır ve sayısı söylenir. Uygulama adresleri (Bitwarden'ın `androidapp://`, Chrome'un `android://` adresleri) alınmaz, çünkü KeyKey uygulama bağlarken imza sertifikası da ister.
- Kayıtlar eklenmeden önce liste halinde gösterilir. Adresi, kullanıcı adı ve parolası kasadaki bir kayıtla aynı olan satırlar yinelenen diye işaretlenir ve varsayılan olarak seçilmez. Kartta ad ve numara, notta ad ve metin kasadakiyle aynıysa o da yinelenendir.

**Kart ve not (1.4.0).** Bitwarden JSON'da tür 3 kart, tür 2 güvenli not olur; CSV'de `type` sütunu `note` olan satırlar not olur (Bitwarden CSV kart taşımaz). Klasör ve favori iki türde de alınır.

- Kart alanları `cardholderName`, `number`, `expMonth`, `expYear`, `code`'dur. Bitwarden'ın `brand` alanı yok sayılır; marka numaradan çıkarılır.
- **Biçime uymayan değer atılmaz.** Numarada boşluk ve tireden başka karakter varsa ya da 19 haneyi aşıyorsa, ay ya da yıl okunamıyorsa (ya da yalnızca biri varsa), güvenlik kodu rakam dışıysa ya da 4 haneden uzunsa o alan boş kalır; ham değer etiketiyle (`Kart numarası: …`, `Son kullanma: ay/yıl`, `Güvenlik kodu: …`; etiketler arayüz dilinde) kartın notuna eklenir. Önizleme bunu kartın satırında söyler. Ay ve yıl metin ya da sayı olabilir; iki haneli yıla 2000 eklenir. Numara, güvenlik kodu ve kart sahibi de sayı olarak yazılmışsa okunur. Başka türde bir değer (ör. `true`, `1.5`) metne çevrilir: numara, güvenlik kodu ya da tarihse aynı kuralla nota taşınır; kart sahibinin biçim kuralı olmadığı için orada metin olarak kalır. 2^53'ten büyük sayıların rakamları kesin olmadığı için uydurulmaz, olduğu gibi yazılır.
- **PIN:** Bitwarden kartında PIN alanı yoktur. Adı `PIN` olan (büyük küçük harf fark etmez), rakamdan oluşan ve en çok 12 haneli ilk özel alan PIN olur. Kalan özel alanlar (metin, gizli, onay kutusu) `ad: değer` satırları olarak notun sonuna eklenir; nottaki özel alanlar da öyle.
- 64 KiB'ı aşan not ve hiçbir alanı dolu olmayan kart ya da not atlanır ve atlananlara sayılır.
- Dosya [2FA içe aktarmadaki](#içe-aktarma) gibi belge seçiciyle seçilir ve önbelleğe kopyalanmadan doğrudan okunur; baytlar okunduktan sonra bellekte sıfırlanır. İşlem bitince kullanıcıya düz metin kaynak dosyasını silmesi hatırlatılır; KeyKey o dosyayı silemez, çünkü yalnızca bir kez okuma izni almıştır.

#### KeePass dosyaları

1.9.0'dan beri. Tasarım ve gerekçeler: [KeePass içe aktarma](keepass-ice-aktarma.md).

- **Biçimler:** KDBX 2.x, 3.x ve 4.x. Şifre AES-256-CBC, ChaCha20 ya da Twofish-CBC; anahtar türetme AES-KDF, Argon2d ya da Argon2id; gzip ya da sıkıştırmasız; korumalı değerler Salsa20 ya da ChaCha20. KeePass 1 (`.kdb`), ArcFour ve başka şifreler tanınır ve "desteklenmiyor" denir. YubiKey ve Windows hesabıyla korunan dosyalar açılamaz; dosya bunu ayırt ettirmediği için yanlış parola mesajı bu ihtimali anar.
- **Anahtar:** Bileşik anahtar `SHA-256(SHA-256(parola) ‖ anahtar dosyası)`. Anahtar dosyası KeePass'ın kuralıyla okunur (XML 1.0 ve 2.0, 32 bayt, 64 onaltılık, yoksa dosyanın SHA-256'sı); 2.0 dosyasının özeti tutmazsa reddedilir. Parola kutusu boşken anahtar dosyası varsa önce yalnız onunla, sonra boş parolayla denenir.
- **Anahtar türetme telefonun yerel kodunda:** Argon2, algoritmanın yazarlarının başvuru uygulamasıyla (C, `android/third_party/argon2`, değiştirilmeden; CMake ile derlenir, JNI ile bağlanır) çok iş parçacıklı çalışır; bellek Java yığınının dışında ayrılır, Argon2 kendi belleğini ve parolayı siler. AES-KDF Android'in `javax.crypto` AES'iyle: sıfırlardan oluşan veri AES-CBC ile şifrelenir, bu AES'i art arda uygulamakla aynıdır ve binlerce tur tek çağrıda yapılır. İkisi de Pigeon'un arka plan kuyruğunda; ana iş parçacığı donmaz. libsodium'da Argon2d yok, Argon2id'si de KeePass'ın paralellik, gizli anahtar ve ek veri parametrelerini almıyor.
- **Şifre çözme Dart'ta:** `pointycastle` (AES, Twofish, ChaCha20, Salsa20) ve `crypto` (SHA-256, SHA-512, HMAC). Şifre çözme ve XML ayrı bir isolate'te çalışır.
- **Doğrulama:** Hiçbir kayıt, dosyanın tamamı doğrulanmadan gösterilmez. KDBX 4'te başlığın SHA-256'sı (bozuk) ve HMAC-SHA-256'sı (yanlış anahtar), her blok şifresi çözülmeden önce kendi HMAC'iyle denetlenir. KDBX 2 ve 3'te gövdenin ilk iki bloğu (kesik dosyada da çözülebilir) `StreamStartBytes` ile anahtarı doğrular; sonra gelen uzunluk ya da dolgu hatası, blok özetleri ve `Meta/HeaderHash` bozulmayı yakalar. Yarım inmiş bir dosya böylece "yanlış parola" değil "bozuk" diye söylenir. gzip'in sonundaki boyut alanı da denetlenir (Dart'ın çözücüsü kesik akışı hata vermeden kabul ediyor).
- **Sınırlar:** Dosya 32 MiB (seçilen dosya Kotlin'den Pigeon'la geçerken Java yığınında birkaç kopya olur; yığın sınırı 192 MB olan telefonlarda 64 MiB uygulamayı düşürebilirdi), açılmış XML ve tek blok 64 MiB, başlık alanı ve sözlük değeri 1 MiB, anahtar dosyası 16 MiB. Argon2 belleği en çok 1 GiB, geçiş 1000, paralellik 64; AES-KDF turu en çok bir milyar. Aşan dosya "telefonda açılamayacak kadar ağır" diye reddedilir, bellek ayrılmadan. Argon2 bellek ayıramazsa ayrı bir mesaj çıkar. CSV ve JSON'un 10 MiB sınırı değişmedi.
- **Kayıtlar:** Grubun yolu (kök hariç) klasör; `otp` (`otpauth://` ya da KeeOtp biçimi), KeePass 2'nin `TimeOtp-*` ve eski KeePassXC'in `TOTP Seed`/`TOTP Settings` alanları bağlı 2FA hesabı; `KP2A_URL*` ek adresler; kalan alanlar özel alan, korumalılar gizli. `{REF:<alan>@I:<UUID>}` başvuruları en çok 10 adım çözülür. Yalnızca notu olan kayıt güvenli not olur. Çöp kutusu, ekler, geçmiş, simgeler, etiketler ve son kullanma tarihleri alınmaz; çöp kutusundaki ve eki olan kayıtların sayısı önizlemede söylenir. Uygulama adresleri bugünkü kuralla alınmaz.
- **Bellek:** Dosya, anahtar dosyası, bileşik, dönüştürülmüş ve ana anahtarlar, HMAC anahtarları ve çözülmüş veri `Uint8List`'tir ve işi bitince sıfırlanır (Kotlin'de Pigeon'dan gelen anahtar ve parola dizileri de); Pigeon'un kanal tamponları uygulama kodundan sıfırlanamaz; dosya ekran kapanınca sıfırlanır. Parola ve kayıt alanları Dart `String`'i olduğu için [Bellek](#bellek) bölümündeki sınır geçerlidir. Hiçbir şey diske yazılmaz; dosya şifreli olduğu için "kaynak dosyayı sil" hatırlatması gösterilmez.

### Düz metin dışa aktarma

Başka bir parola yöneticisine geçmek için. Dosya **şifresizdir**; bu yüzden iki adımlı onay ister.

- Önce biçim seçilir (CSV ya da JSON), sonra dosyanın şifresiz olduğu ve kimlerin okuyabileceği açıkça anlatılır. Ardından ana parola veya parmak iziyle [kimlik doğrulanır](#kodları-görmek-için-ek-onay).
- **CSV:** Bitwarden'ın CSV sütunları (`folder,favorite,type,name,notes,fields,reprompt,login_uri,login_username,login_password,login_totp`); çoğu parola yöneticisi bu biçimi okur. Bağlı 2FA hesabı `login_totp` sütununa `otpauth://` bağlantısı olarak yazılır. Steam hesabı (1.7.0) Bitwarden'ın tanıdığı `steam://ANAHTAR` biçimiyle yazılır; Bitwarden `otpauth://steam/…` bağlantısında 5 haneli sayı, yani yanlış kod üretir. Bir kayda bağlı olmayan 2FA hesapları ayrı satırlara yazılır. Bağlı uygulamalar `androidapp://` adresi olarak eklenir. Notlar `type=note` satırlarıdır. Bitwarden CSV kart taşıyamadığı için kartlar yazılmaz; kasada kart varsa biçim penceresi bunu söyler.
- **JSON (1.4.0):** Bitwarden'ın şifresiz JSON biçimi (`encrypted: false`, `folders`, `items`; tür 1 giriş, 2 güvenli not, 3 kart). Kartlar dahil her şeyi taşır; Bitwarden, KeePassXC ve Proton Pass içe alabiliyor. Öğe kimliği kayıt kimliğinin UUID biçimidir, klasör kimlikleri sırayla üretilir. 2FA hesapları CSV'deki kuralla yazılır. Kartın PIN'i `PIN` adlı gizli bir özel alandır; marka Bitwarden'ın adlarıyla yazılır (Troy onda olmadığı için `Other`). Boş alanlar `null` olur. Dosya `.json` uzantısıyla, `application/json` türüyle kaydedilir.
- Çöp kutusundaki kayıtlar ve parola geçmişi dışa aktarılmaz.
- Dosya `ACTION_CREATE_DOCUMENT` ile kaydedilir, uygulamanın klasöründe kopya kalmaz. Kaydedilen baytlar bellekte sıfırlanır.
- Hücreler formül kaçışından geçirilmez. `=` ile başlayan bir parola olduğu gibi yazılır; dosya tablo programında açılmak için değil, başka bir parola yöneticisine verilmek içindir.
- KeyKey kendi dışa aktarmasını geri okur (iki biçim için de gidiş-dönüş testi). CSV'nin taşıyamadıkları: kartlar, özel alanların gizli işareti, uygulama imza özetleri (KeyKey `androidapp://` adreslerini içe almaz) ve parola geçmişi. JSON gizli işareti ve kartın bütün alanlarını (PIN dahil) taşır; uygulama imza özetleri ve parola geçmişi onda da yoktur. İki biçimde de bağlı olmayan 2FA hesapları geri okununca 2FA hesabı bağlı birer kayıt olur.

## Senkron

Tasarımın tamamı [senkron tasarımında](senkron.md); burada güvenlikle ilgili kurallar var.

- **Uçtan uca şifreli:** Sunucuya her telefonun bir dosyası (`keykey-sync-<6 onaltılık>.keykey`) yazılır. Dosya [yedek biçimindedir](#yedek-biçimi): Argon2id ile sarılmış kasa anahtarı, XChaCha20-Poly1305 ile şifreli parçalar, içinde ayrıca şifreli kayıtlar. Ayar kaydı ve uygulama parolası dosyaya girmez. Sunucu dosya adını, boyutunu ve zamanını görür, içeriği göremez.
- **Uygulama parolası** yalnızca kasanın içinde, ayar kaydında şifreli durur; kasa açıkken bellekte. Elle ve otomatik yedeğe girer (yedek şifreli). Günlüğe ve hata mesajlarına girmez. Ağ istemcisinin kuralları [Sızıntı kontrolü](#sızıntı-kontrolü) bölümünde.
- **Birleştirme kayıt kayıt:** Uzak dosyadaki her kayıt açık kasanın anahtarıyla çözülür ve biçimi doğrulanır; tek kayıt açılmazsa o telefonun dosyası bütünüyle yok sayılır. Aynı kimlikte `updatedAt` değeri yeni olan kalır; silme kaydı, zamanı kaydınkinden yeni ya da aynıysa kazanır. Bir dosyada 24 saatten ileri tarihli tek bir zaman varsa dosya alınmaz. Kaybeden parola, kazanan kaydın parola geçmişine kurtarılır.
- **Ana parola ve kurtarma anahtarı:** Parola yuvası ve kurtarma yuvası ayrı ayrı, kendi değişme zamanlarına göre birleşir. Başka telefonda değişen parola bu telefona gelince kullanıcıya bir kez söylenir. Eski parola iptal edilmez ([bilinen sınır 13](#bilinen-sınırlar)).
- **Kasa kimliği:** Klasörde başka bir kasanın dosyası varsa senkron açılmaz ve eşitleme durur; kullanıcı ancak o kasanın ana parolasıyla ya da kurtarma anahtarıyla bu telefonu o kasaya katabilir. Katılınca bu telefonun kayıtları yeni anahtarla şifrelenip tek işlemde birleştirilir, parmak izi yuvası silinir, bu telefonun eski ana parolası ve kurtarma anahtarı geçmez.
- **Geri yükleme ve senkron:** Yukarıdaki [Geri yükleme](#geri-yükleme) tablosunda. Geri yükleme senkron üzerinden hiçbir kaydı silmez.

## Hata davranışı

| Durum | Hata | Anlamı |
|---|---|---|
| Parola yuvası açılmadı | `WrongSecretException` | Yanlış parola, veya üst bilgi değiştirilmiş. Bu ikisi kriptografik olarak ayırt edilemez. |
| Kurtarma yuvası açılmadı | `WrongSecretException` | Yanlış anahtar veya değiştirilmiş üst bilgi. |
| Kurtarma metni geçersiz | `InvalidRecoveryKeyException` | Yanlış karakter, uzunluk veya sağlama. |
| Üst bilgi okunamadı | `InvalidVaultHeaderException` | Bozuk dosya veya desteklenmeyen sürüm. |
| Kayıt açılmadı | `CorruptedDataException` | Değiştirilmiş, bozulmuş veya yanlış bağlamdaki kayıt. |
| Yedek dosyası okunamadı | `InvalidBackupException` | Yedek değil, desteklenmeyen sürüm, sınır dışı boyut veya bozuk yapı. |
| Yedek daha yeni bir sürümden | `NewerBackupException` (`InvalidBackupException`'ın alt türü) | Dosya ya da içerik sürümü bu uygulamanınkinden büyük. Kullanıcıya uygulamayı güncellemesi söylenir. |
| Yedek sınırı aşıyor | `BackupTooLargeException` | Yazılacak dosya 64 MiB'tan büyük; dosya yazılmaz. |
| Yedeğin içeriği açılmadı | `CorruptedDataException` | Parola doğru ama dosya kesilmiş, değiştirilmiş veya sonuna veri eklenmiş. |
| Keystore anahtarı kullanılamıyor | `BiometricInvalidated` sonucu | Yeni parmak izi eklenmiş veya ekran kilidi kaldırılmış. Yuva silinir, ana parola istenir. |
| Parmak izi yuvası açılmadı | `BiometricFailed` sonucu | Yuva bozulmuş, değiştirilmiş veya başka bir kasaya ait. Ana parola çalışmaya devam eder. |

Hata mesajlarına hiçbir zaman parola, anahtar veya düz metin yazılmaz.

## Bellek

- Anahtarlar libsodium'un korumalı belleğinde (`SecureKey`) tutulur, kullanım sonrası `dispose` ile silinir.
- Parola baytları kullanıldıktan sonra sıfırlanır.

Kasa açıkken arama yapılabilsin diye kayıtların tamamı çözülüp bellekte tutulur. Kilitlenince bunlara ait bütün durumlar bırakılır.

2FA gizli anahtarları da çözülmüş kayıtla birlikte Dart belleğinde durur; kod her hesaplandığında kullanılır. HMAC `package:crypto` ile hesaplandığı için anahtar korumalı belleğe alınamaz. İçe aktarmada türetilen anahtarlar ve çözülen düz metin, işi bitince sıfırlanır. Pigeon'un Android'den getirdiği baytlar değiştirilemez olduğu için önce kopyalanır.

**Sınır:** Düz metne çözülen kayıtlar ve metin kutusundan gelen ana parola Dart `String` olarak bellekte kalır. Dart `String`'leri değiştirilemez ve çöp toplayıcı ne zaman sileceğini garanti etmez. Ömürlerini kısa tutarız, ama silindiklerini garanti edemeyiz. Güvenlik denetiminde bu [ölçüldü](guvenlik-denetimi.md#bellek): kilitten dakikalar sonra da bulunuyorlar ([bilinen sınır 7](#bilinen-sınırlar)).

## Bilinen sınırlar

1. **Geri alma fark edilmez.** Diske yazma yetkisi olan biri bir kaydı aynı kaydın eski haliyle veya tüm kasayı eski bir kopyasıyla değiştirebilir. Çünkü AD eski kopyada da geçerlidir. Bunu önlemek için dosya dışında güvenilir bir sayaç gerekir, yerel bir uygulamada yoktur.
2. **Kayıt silme fark edilmez.** Bir kayıt satırı silinirse uygulama bunu şifreleme düzeyinde anlayamaz. Bu saldırı veri okutmaz, yalnızca veri kaybettirir.
3. **Üst veri sızıntısı.** Kayıt sayısı, türleri, zaman damgaları ve 256 baytlık dolgu blok sayısı görünür. Türler `card` ve `note`'u da kapsadığı için veritabanı dosyasını okuyan biri kaç kartın ve kaç notun olduğunu görür; yedekte bunlar dış katmanda gizlidir. Uzun bir notun dolgu blok sayısı metnin kabaca uzunluğunu verir.
4. **Parola gücü esastır.** Argon2id denemeyi yavaşlatır, ama zayıf bir parolayı güçlendiremez. Yedek dosyası da aynı sınıra tabidir.
5. **Sarmalama anahtarı dönmez.** Parola değişse de kasa anahtarı aynı kalır. Eski parolayı ve o zamanki üst bilgiyi birlikte ele geçiren biri kasa anahtarına ulaşabilir, eski yedekler de eski parolayla açılmaya devam eder. Otomatik yedekler de buna dahildir: parola değişince yeni yedek hemen yeni parolayla yazılır, ama klasördeki eskiler budanana kadar eski parolayla açılır. Kurtarma anahtarı yenilenince de aynı: eski anahtar bu cihazdaki kasayı açmaz, ama eski yedekleri ve kasa dosyasının eski kopyalarını açar.
6. **Hatalı deneme beklemesi yalnızca uygulamanın kuralıdır.** Sayaç şifresizdir ve kopyalanmış bir kasa dosyası üzerindeki denemeleri sınırlamaz. Ayrıntılar [Kilit](#kilit) bölümünde.
7. **Kilitten sonra bellekte kalan dizeler.** Yazılan ana parola ve ekranda gösterilmiş değerler (parola, kullanıcı adı) kilitten sonra da Dart'ın henüz toplanmamış dizelerinde kalabilir; denetimde kilitten 2,5 dakika sonra bile bulundular ([ölçüm](guvenlik-denetimi.md#bellek)). Anahtarlar, kurtarma anahtarı ve 2FA anahtarları bulunmadı. Bu ölçüm, kurtarma anahtarını kasa açıkken gösteren yeni kurtarma anahtarı ekranından önce yapıldı: o ekranda gösterilen ve yazılan anahtar da bir Dart dizesidir; ekran kilitte kendi kopyalarını bırakır, ama toplanmamış dizeler aynı şekilde kalabilir. Bu belleği okumak root ya da süreçte kod çalıştırmayı gerektirir; böyle bir saldırgan ana parolayı yazılırken de görebileceği için risk kabul edildi. Ayrıntılar [Bellek](#bellek) bölümünde.
8. **Doldurma bildirimi güvenli pencerenin dışında.** Doldurmadan sonraki bildirim kaydın adını taşır ve KeyKey'in `FLAG_SECURE` penceresinin dışında görünür: ekran kaydına girer, erişilebilirlik servislerine bildirilir. Bildirimden önce kayıt adı KeyKey dışında hiç görünmüyordu. Kayıt adı genelde zaten ekranda olan uygulamanın ya da sitenin adı olduğu ve kullanıcı adı ile parola bildirime girmediği için bu kabul edildi.
9. **Sızıntı kontrolü karşı tarafa güvenir ve iz bırakır.** Have I Been Pwned (ve önündeki Cloudflare) IP adresini, sorulan önekleri ve zamanı görür. Bir IP'den gelen önek kümesi o kasanın parmak izi gibi kullanılabilir; tek başına parolayı ele vermez. Rastgele üretilmiş bir parolanın 5 karakterlik öneki 20 bit verir, geriye 140 bit kalır; zayıf bir parolanın öneki ise bir sözlükle aday listesini daraltır (zayıf parola zaten raporun diğer bölümünde). Hizmet yanlış yanıt verirse yanlış bir "görülmedi" fark edilemez; "sızıntılarda görülmedi" zaten "güvenli" demek değildir. Denetim sırasında özetler, parolaların kendisi gibi, Dart belleğinde durur ([Bellek](#bellek)).
10. **Senkron saate güvenir.** Yeni olan kazanır kuralı telefonların saatine bakar; 24 saatten ilerisi alınmaz, ama 24 saatin içindeki bir saat farkı yanlış sürümü kazandırabilir. Aynı kayıt iki telefonda eşitlemeler arasında değişirse eski olan değişiklik kaybolur; yalnızca parola, kaydın parola geçmişine kurtarılır.
11. **Silme kayıtları şifresiz ve yayılır.** Sayıları ve zamanları veritabanında görünür ([Depolama](#depolama)). Veritabanına yazabilen biri 24 saate kadar ileri tarihli bir silme kaydı ya da kayıt sürümüyle o kaydı senkron üzerinden bütün telefonlarda etkileyebilir; senkrondan önce yalnızca o telefonu etkiliyordu ([bilinen sınır 1 ve 2](#bilinen-sınırlar)).
12. **Sunucu geciktirebilir.** Sunucu bir telefonun dosyasını saklayarak, silerek ya da eskisiyle değiştirerek değişikliklerin öteki telefonlara yayılmasını geciktirebilir. Eski dosya, kendisinden yeni değişiklikleri geri alamaz; birleştirme yalnızca daha yeniyi uygular.
13. **Parola değişikliği iptal değildir.** Kullanılmayan bir telefonun senkron dosyası ve sunucunun dosya geçmişi eski üst bilgiyle, yani eski parolayla açılır; kasa anahtarı aynı kaldığı için sonraki dosyaları da açar ([bilinen sınır 5](#bilinen-sınırlar)). Kaybolan ya da çalınan bir telefonu durdurmanın yolu, onun uygulama parolasını sunucuda iptal etmektir. Ana parolası sızan kullanıcıya önerilen, kasayı yeni bir kasaya taşımaktır: yedek alıp yeni ana parolayla yeni kasa kurmak, yedeği birleştirerek almak ve senkron için yeni ya da boş bir klasör kullanmak (eski klasörde eski kasanın dosyaları olduğu için senkron "başka bir kasa" der); [kılavuzda](kullanim.md#senkron) adım adım yazar.

## Test yaklaşımı

- **Bağımsız vektörler:** Argon2id ve XChaCha20-Poly1305, libsodium'un kendi test vektörleriyle doğrulanır. HKDF sonuçları `package:crypto` ile ayrı hesaplanan HMAC-SHA256 ile karşılaştırılır.
- **Olumsuz testler:** Yanlış parola, tek bit değişimi, yer değiştirilmiş kayıt, değiştirilmiş parametre.
- **Biçim uyumluluğu:** `test/fixtures/crypto/` ve `test/fixtures/vault/` altındaki sabit dosyalar her sürümde açılabilmelidir. Bu dosyalar yalnızca deneme verisi ve deneme parolası içerir.
- **2FA:** HOTP ve TOTP, RFC 4226 ve RFC 6238 eklerindeki bütün vektörlerle; Base32, RFC 4648 vektörleriyle doğrulanır. `otpauth://` ayrıştırıcısı, Google Authenticator okuyucusu ve dosya okuyucuları rastgele bozulmuş girdilerle de çalıştırılır; yalnızca kendi hata türlerini fırlatmaları beklenir.
- **KeePass:** pykeepass ve KeePassXC'in test dosyaları (`test/fixtures/import/kdbx/`, bütün biçim, şifre, anahtar türetme ve anahtar dosyası türleri) ve pykeepass'ın yazıcısıyla üretilmiş bir örnek. Argon2 RFC 9106 vektörleriyle, AES-KDF pycryptodome ile, dönüştürülmüş anahtarlar ve kayıtlar pykeepass ile karşılaştırılır: telefondaki ve testteki uygulamadan bağımsız üçüncü bir uygulama. Her test dosyasının her baytı bozulunca okuyucu yalnızca kendi hata türlerini fırlatır. Telefondaki anahtar türetme aynı değerlerle Android 11 ve 17 emülatörlerinde sınanır.
- **İçe aktarma:** scrypt ve PBKDF2-HMAC-SHA256, RFC 7914 vektörleriyle doğrulanır. Aegis projesinin testlerindeki örnek dışa aktarmalar (`test/fixtures/import/`) Node'un OpenSSL kriptosuyla açılarak ara değerler çıkarıldı; bizim türettiğimiz anahtarlar bunlarla karşılaştırılır. Android'in AES-GCM'i aynı değerlerle cihazda sınanır.
- **Ağ:** Pwned Passwords istemcisi bilgisayarda yerel bir test sunucusuna karşı (yol, başlıklar, yönlendirme, hata, büyük yanıt, zaman aşımı, https dışı adres) sınanır; sızıntı denetimi sahte kaynakla (dolgu, geçersiz satır, eşzamanlılık, yeniden deneme, iptal). WebDAV istemcisi yerel bir sahte WebDAV sunucusuna karşı (Nextcloud, Apache ve rclone biçiminde klasör listesi, yazma sırası, taşıma desteklenmeyince doğrudan yazma, geri okuma tutmazsa ara dosyanın silinmesi, durum kodları, yönlendirme, zaman aşımı, büyük yanıt, https dışı adres, her istekte kimlik başlığı, mesajda kimlik ve yol olmaması) sınanır. Ağ kodunun iki dosyada kaldığını bir test denetler. Cihazda gerçek hizmete karşı bir entegrasyon testi çalışır.
- **Cihaz testleri:** Aynı işlemler dört emülatörde çalıştırılır. Faz 2'de bir gerçek telefonda da çalıştırıldı; Faz 5 sonunda uygulama içi cihaz testleri ve pano testi aynı telefonda geçti. Parmak izi ve kamera betikleri emülatör komutları kullandığı için telefonda elle denendi.

# KeyKey Güvenlik Tasarımı

Bu belge KeyKey'in verileri nasıl şifrelediğini bayt düzeyinde anlatır. Kod bu belgeye göre yazılır; ikisi çelişirse bu bir hatadır. Dışarıdan inceleyenler için de başlangıç noktasıdır, eleştirileri [özel güvenlik bildirimiyle](https://github.com/aaudraa/KeyKey/security/advisories/new) veya tasarım sorusuysa issue ile iletebilirsin.

**Durum:** Biçim sürümü 1, geliştirme aşamasında. Bağımsız bir denetimden geçmedi. 1.0'a kadar biçim değişebilir.

## Hedefler

**Korumak istediklerimiz** (tam liste [yol haritasındaki tehdit modelinde](../yol-haritasi.md#tehdit-modeli)):

- Kasa dosyası veya yedek ele geçse bile, ana parola güçlüyse içerik okunamamalı.
- Dosyayı ele geçiren hangi sitelerde hesabın olduğunu görememeli.
- Dosya değiştirilirse bu fark edilmeli; bir kaydın şifreli verisi başka bir kaydın yerine konamamalı.

**Korumadıklarımız:** Kasa açıkken root yetkili veya zararlı yazılım bulaşmış cihaz; zayıf ana parola; ana parola ve kurtarma anahtarının birlikte kaybı.

**İlke:** Kendi kriptomuzu yazmıyoruz. Bütün temel işlemler [libsodium](https://libsodium.org) 1.0.22'den gelir, biz yalnızca onları birleştiririz.

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

- S20 FE'de 12 geçişin yaklaşık 0,9 saniye sürmesi beklenir. Bu değer ölçülmedi, sürenin geçiş sayısıyla doğru orantılı olduğu varsayılarak 233 ms'den hesaplandı.
- Emülatörler bilgisayarın `x86_64` işlemcisinde çalıştığı için telefon süresini göstermez.
- Gerçek telefon ölçümü tek bir cihazdan geliyor. Bu cihaz 2020'nin üst seviye çipini taşıyor ve test debug derlemesiyle çalıştı. Düşük donanımlı telefonlar ölçülmedi. Kalibrasyon tabanın altına inmediği için çok yavaş cihazlarda kasa açmak hedef süreyi aşabilir.
- Bu ölçüm yalnızca Argon2id süresini kapsar. Android Keystore ve biyometri davranışı için Faz 8'deki gerçek telefon testi yine gereklidir.

### Kurtarma anahtarı

Rastgele 32 bayt. Kasa oluşturulurken bir kez gösterilir, uygulama saklamaz.

**Metin biçimi:** `anahtar (32 bayt) || sağlama (2 bayt)`, Crockford Base32 ile kodlanır ve 5'erli gruplanır. Toplam 55 karakterdir.

- **Sağlama:** `BLAKE2b-256("keykey/v1/recovery-checksum" || anahtar)` sonucunun ilk 2 baytı. Yazım hatalarını kriptoya hiç ulaşmadan yakalar. Anahtarın gücünü azaltmaz, çünkü anahtarın kendisi zaten metnin içindedir.
- **Okuma kolaylığı:** Boşluk ve tire yok sayılır, büyük küçük harf ayrımı yapılmaz. `O` → `0`, `I`/`L` → `1` kabul edilir. Türkçe klavye için `ı` ve `İ` de `1` sayılır.
- **KEK:** `HKDF-Expand(anahtar, "keykey/v1/kek/recovery", 32)`.

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

## Depolama

Kasa, uygulamanın özel klasöründe tek bir SQLite dosyasında (`keykey.db`) durur. Android yedeklemesi ve cihaz aktarımı kapalıdır. Dosyanın tamamı şifrelenmez, koruma kayıt düzeyindeki şifrelemeden gelir. Bu yüzden SQLCipher gerekmiyor ve şifresiz kalan alanlar yukarıdaki listeyle sınırlı kalıyor.

| Tablo | Alanlar | Not |
|---|---|---|
| `vault_meta` | `id` (her zaman 1), `header` | Üst bilgi, yukarıdaki JSON biçiminde. |
| `records` | `id` (16 bayt), `type`, `blob`, `created_at`, `updated_at` | `blob`, yukarıdaki kayıt biçimidir. |
| `biometric_slot` | `id` (her zaman 1), `iv` (12 bayt), `cipher_text` (48 bayt) | Yalnızca parmak izi açıksa satır vardır. |
| `unlock_state` | `id` (her zaman 1), `failed_attempts`, `last_failed_at` | Hatalı deneme sayacı. |

- **Tek işlem:** Üst bilgi değişiklikleri tek SQLite işleminde yazılır. Yarıda kalırsa eski üst bilgi geçerli kalır.
- **Silinen veri:** `secure_delete` açık ve `journal_mode` `DELETE`'tir, böylece eski sarmalama satırları dosyanın boş alanında kalmaz. Flash bellekte fiziksel silme yine de garanti edilemez, bu yüzden [bilinen sınırlardaki](#bilinen-sınırlar) sarmalama maddesi geçerlidir.
- **İki ayrı sürüm:** Üst bilgi biçimi (`version`) ve veritabanı şeması (`schemaVersion`) birbirinden bağımsızdır. Şema göçleri testlerle doğrulanır.

## Kasa oluşturma

1. Ana parola iki kez girilir. En az 10 karakter (Unicode kod noktası) olmalıdır, geri alınamayacağı ayrıca söylenir.
2. Güç göstergesi yalnızca kaba bir tahmindir: uzunluk, karakter çeşitliliği ve kısa bir sık kullanılan parola listesi. `zxcvbn` Dart 3 ile uyumlu olmadığı için kullanılmıyor.
3. Kalibrasyondan sonra kasa anahtarı ve yuvalar üretilir. Bu sonuç **yalnızca bellekte** tutulur.
4. Kurtarma anahtarı bir kez gösterilir ve kullanıcıya geri yazdırılır. Doğrulama metin karşılaştırmasıyla değil, yazılan anahtarla kurtarma yuvası gerçekten açılarak yapılır.
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

- Uygulama arka plana geçince (`hidden` veya `paused`) hemen kilitlenir. `inactive` kilitlemez, çünkü parmak izi penceresi ve sistem diyalogları da onu tetikler.
- Ekrana 5 dakika dokunulmazsa kilitlenir.
- Kilitlenince kasa ve alt anahtarlar `dispose` edilir, çözülmüş veri tutan durumlar sıfırlanır, yönlendirme kilit ekranına gider ve önceki ekranlar yığından çıkarılır.

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

## Hata davranışı

| Durum | Hata | Anlamı |
|---|---|---|
| Parola yuvası açılmadı | `WrongSecretException` | Yanlış parola, veya üst bilgi değiştirilmiş. Bu ikisi kriptografik olarak ayırt edilemez. |
| Kurtarma yuvası açılmadı | `WrongSecretException` | Yanlış anahtar veya değiştirilmiş üst bilgi. |
| Kurtarma metni geçersiz | `InvalidRecoveryKeyException` | Yanlış karakter, uzunluk veya sağlama. |
| Üst bilgi okunamadı | `InvalidVaultHeaderException` | Bozuk dosya veya desteklenmeyen sürüm. |
| Kayıt açılmadı | `CorruptedDataException` | Değiştirilmiş, bozulmuş veya yanlış bağlamdaki kayıt. |
| Keystore anahtarı kullanılamıyor | `BiometricInvalidated` sonucu | Yeni parmak izi eklenmiş veya ekran kilidi kaldırılmış. Yuva silinir, ana parola istenir. |
| Parmak izi yuvası açılmadı | `BiometricFailed` sonucu | Yuva bozulmuş, değiştirilmiş veya başka bir kasaya ait. Ana parola çalışmaya devam eder. |

Hata mesajlarına hiçbir zaman parola, anahtar veya düz metin yazılmaz.

## Bellek

- Anahtarlar libsodium'un korumalı belleğinde (`SecureKey`) tutulur, kullanım sonrası `dispose` ile silinir.
- Parola baytları kullanıldıktan sonra sıfırlanır.

**Sınır:** Düz metne çözülen kayıtlar ve metin kutusundan gelen ana parola Dart `String` olarak bellekte kalır. Dart `String`'leri değiştirilemez ve çöp toplayıcı ne zaman sileceğini garanti etmez. Ömürlerini kısa tutarız, ama silindiklerini garanti edemeyiz.

## Bilinen sınırlar

1. **Geri alma fark edilmez.** Diske yazma yetkisi olan biri bir kaydı aynı kaydın eski haliyle veya tüm kasayı eski bir kopyasıyla değiştirebilir. Çünkü AD eski kopyada da geçerlidir. Bunu önlemek için dosya dışında güvenilir bir sayaç gerekir, yerel bir uygulamada yoktur.
2. **Kayıt silme fark edilmez.** Bir kayıt satırı silinirse uygulama bunu şifreleme düzeyinde anlayamaz. Bu saldırı veri okutmaz, yalnızca veri kaybettirir.
3. **Üst veri sızıntısı.** Kayıt sayısı, türleri, zaman damgaları ve 256 baytlık dolgu blok sayısı görünür.
4. **Parola gücü esastır.** Argon2id denemeyi yavaşlatır, ama zayıf bir parolayı güçlendiremez. Yedek dosyası da aynı sınıra tabidir.
5. **Sarmalama anahtarı dönmez.** Parola değişse de kasa anahtarı aynı kalır. Eski parolayı ve o zamanki üst bilgiyi birlikte ele geçiren biri kasa anahtarına ulaşabilir, eski yedekler de eski parolayla açılmaya devam eder.
6. **Hatalı deneme beklemesi yalnızca uygulamanın kuralıdır.** Sayaç şifresizdir ve kopyalanmış bir kasa dosyası üzerindeki denemeleri sınırlamaz. Ayrıntılar [Kilit](#kilit) bölümünde.

## Test yaklaşımı

- **Bağımsız vektörler:** Argon2id ve XChaCha20-Poly1305, libsodium'un kendi test vektörleriyle doğrulanır. HKDF sonuçları `package:crypto` ile ayrı hesaplanan HMAC-SHA256 ile karşılaştırılır.
- **Olumsuz testler:** Yanlış parola, tek bit değişimi, yer değiştirilmiş kayıt, değiştirilmiş parametre.
- **Biçim uyumluluğu:** `test/fixtures/crypto/` altındaki sabit dosyalar her sürümde açılabilmelidir. Bu dosyalar yalnızca deneme verisi ve deneme parolası içerir.
- **Cihaz testleri:** Aynı işlemler dört emülatörde çalıştırılır. Faz 2'de bir gerçek telefonda da çalıştırıldı.

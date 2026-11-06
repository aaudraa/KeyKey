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

### Parola kaydının içeriği

Tür `login` olan kayıtların düz metni, şifrelemeden önce şu JSON'dur:

```json
{
  "version": 1,
  "name": "Örnek",
  "username": "kullanici@example.com",
  "password": "...",
  "urls": ["https://example.com"],
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
| `kind` | `totp` veya `hotp`. |
| `secret` | Gizli anahtar, RFC 4648 Base32, büyük harf ve dolgusuz. 1-256 bayt. |
| `algorithm` | `SHA1`, `SHA256` veya `SHA512`. |
| `digits` | 6, 7 veya 8. |
| `period` | `totp` için 1-3600 saniye, `hotp` için `null`. |
| `counter` | `hotp` için sıradaki sayaç değeri (0 veya daha büyük), `totp` için `null`. |
| `loginId` | Eşleştirilen parola kaydının kimliği (32 karakter, küçük harf onaltılık) veya `null`. |

- Okurken doğrulama parola kaydındaki kadar katıdır. Ayrıca Base32 metni yazdığımız biçimde olmalıdır: küçük harf, dolgu, boşluk veya fazladan bit reddedilir.
- Çöp kutusu ve okunamayan kayıt kuralları parola kaydıyla aynıdır. Yanlışlıkla silinen 2FA hesabı servise girişi engelleyebileceği için hemen silinmez.
- `loginId`'nin gösterdiği kayıt silinmişse eşleşme yok sayılır.

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

## Pano

- Kopyalanan parola hassas olarak işaretlenir (`EXTRA_IS_SENSITIVE`, Android 13+), böylece sistem önizlemede göstermez. Android 11 ve 12'de bu işaret yoktur.
- Pano 30 saniye sonra temizlenir. Bunu önce zamanlayıcı yapar. Süreç durdurulduysa veya dondurulduysa, 10 saniye paylı kurulan bir `AlarmManager` alarmı yapar. Pay olmadan Android 11'de alarm zamanlayıcıdan önce çalıştı ve kullanıcının yeni kopyasını sildi.
- Pano okunabiliyorsa yalnızca hâlâ bizim kopyamızı taşıyorsa silinir. Bunu anlamak için kopyalanan metnin kendisi değil, SHA-256 özeti tutulur. Panonun zaman damgası bu iş için güvenilir çıkmadı, cihaz testinde eşleşmedi. Okunamıyorsa, örneğin uygulama arka plandaysa veya Android o an izin vermiyorsa, silinir. Android 14 emülatöründe uygulama öndeyken de zaman zaman okunamadı.
- Yeni bir kopyalama öncekinin süresini sıfırlar.
- Kasa kilitlenince pano temizlenmez. Parolayı kopyalayıp tarayıcıya geçmek uygulamayı arka plana alır ve kasayı kilitler, temizlemek kopyalamayı işe yaramaz hale getirirdi.

**Sınırlar:**

1. Android arka plandaki uygulamaya panoyu okutmaz. Kullanıcı bu sürede başka bir şey kopyaladıysa onu da silebiliriz.
2. Alarm tam zamanında çalışmayabilir. Android, kesin alarm izni olmadan onu geciktirebilir. Cihaz testi, süreç ayaktayken arka planda temizlendiğini doğruluyor; sürecin kapatıldığı durum yalnızca alarma dayanıyor ve otomatik test edilmedi. Bu izni almıyoruz, çünkü parolanın panoda birkaç dakika daha kalması, izin listesini büyütmeye değmez.
3. O sürede panoyu okuyan etkin klavye veya kötü amaçlı uygulama parolayı görebilir. Bu, [tehdit modelinde](../yol-haritasi.md#tehdit-modeli) "kısmen" olarak yazıyor.

## Parola üretici ve güç tahmini

- Bütün rastgelelik `randombytes_uniform` ile üretilir, modülo eğilimi yoktur.
- **Rastgele parola:** Seçilen her karakter sınıfından en az bir karakter bulunur. Bu, sonucu çok az daraltır, gösterilen entropi hesabı bunu göz ardı eder.
- **Parola cümlesi:** [EFF büyük sözcük listesi](https://www.eff.org/dice) (7776 İngilizce sözcük, CC BY 3.0), sözcük başına yaklaşık 12,9 bit. Varsayılan 6 sözcük, yaklaşık 77 bit. Denetlenmiş bir Türkçe liste bulamadığımız için Türkçe seçenek yok.
- **Güç tahmini:** Uzunluk ve karakter çeşitliliğinden kaba bir entropi hesaplanır. Yaygın parola listesi, klavye dizileri, ardışık karakterler, tekrarlar ve tarihler bunu düşürür. Yaygın parola listesi [SecLists](https://github.com/danielmiessler/SecLists) (MIT) kaynaklıdır. Bu yine bir tahmindir, gerçek gücü ölçmez.

## 2FA kodları

### Kod üretimi

- **HOTP** (RFC 4226): `HMAC(gizli anahtar, sayaç)` hesaplanır, sayaç 8 baytlık büyük uçlu yazılır. Son baytın düşük 4 biti bir konum gösterir, o konumdaki 4 bayttan en üst bit atılır ve sonuç `10^hane`'ye göre kalanı alınarak önüne sıfır eklenir.
- **TOTP** (RFC 6238): Sayaç `floor(unix zamanı / period)`'dur, başlangıç zamanı 0'dır. SHA-256 ve SHA-512 için de aynı kesme yöntemi kullanılır.
- HMAC için `package:crypto` kullanılır. libsodium'da SHA-1 yok, HMAC-SHA256 ve HMAC-SHA512'si ise yalnızca 32 baytlık anahtar alıyor.
- **HOTP sayacı:** Kod, kullanıcı istediğinde üretilir. Sayaç önce bir artırılıp diske yazılır, kod ondan sonra gösterilir. Böylece uygulama yarıda kapansa da aynı kod iki kez görünmez. Gösterilen kod kayıttaki eski sayaç değeriyle hesaplanır, yani `counter` her zaman sıradaki kullanılacak değerdir. Bu RFC 4226'daki tanıma uyar.
- **Sıradaki kod:** TOTP süresinin bitmesine az kaldığında bir sonraki kod da gösterilir. Kullanıcı yazarken süre dolarsa kodu yeniden okumak zorunda kalmaz.
- **Saat:** TOTP cihaz saatine dayanır. Uygulama internet kullanmadığı için saati kendisi doğrulayamaz. Kodlar tutmazsa saat ayarını gösteren bir yardım metni vardır.
- Kodlar kopyalanırken parolalarla aynı [pano](#pano) kuralları geçerlidir.

### `otpauth://` bağlantıları

Biçim [Google Authenticator'ın Key Uri Format'ıdır](https://github.com/google/google-authenticator/wiki/Key-Uri-Format): `otpauth://totp/Servis:hesap?secret=...&issuer=Servis`.

- Şema ve tür büyük küçük harf ayırmaz. `totp` ve `hotp` dışındaki türler, örneğin `steam`, desteklenmiyor diye reddedilir.
- `secret` zorunludur. Kullanıcıların elle yazdığı veya kopyaladığı metinlere uymak için Base32 okunurken küçük harf, boşluk, tire ve dolgu kabul edilir. Artan bitler atılır.
- `issuer` parametresi varsa etiketteki `Servis:` önekinden önce gelir. Etiketteki iki noktadan sonraki boşluklar atılır. Servis adında da iki nokta olabileceği için, `issuer` etiketin başında geçiyorsa etiket tam oradan bölünür.
- Servis ve hesap adlarından denetim karakterleri ve metnin yönünü değiştiren karakterler (örneğin U+202E) atılır. Bunlar bir adı ekranda başka bir servisin adı gibi gösterebilir.
- Yüzde kodlaması kendi çözücümüzle açılır. Sorgu kısmında `+` boşluktur, etikette değildir.
- `algorithm`, `digits` ve `period` verilmezse SHA1, 6 ve 30 kullanılır. `hotp` için `counter` zorunludur.
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
- Desteklenmeyen hesaplar, örneğin Steam veya 5 haneli kodlar, atlanır ve kullanıcıya sayısı söylenir. Gizli anahtarı zaten kayıtlı olan hesap, çöp kutusunda bile olsa, işaretlenir ve tekrar eklenmez.
- Hesaplar kaydedilmeden önce liste halinde gösterilir, kullanıcı hangilerinin ekleneceğini seçer.
- Aegis'in 2019'dan eski, `repaired` işareti olmayan parola yuvaları farklı bir parola kodlamasıyla türetilmişti. Bu yuvalar desteklenmez; parola yanlış görünür.

### Kodları görmek için ek onay

İsteğe bağlı bir ayardır. Açıksa 2FA ekranı ve parola kaydındaki eşleşmiş kod, kasa açık olsa bile kodları göstermeden önce parmak izi, parmak izi kapalıysa ya da vazgeçilirse ana parola ister. Onay, kasa kilitlenene kadar geçerlidir; uygulama arka plana geçince kasa zaten kilitlenir.

- **Doğrulama gerçekten kasayı açar.** Parmak izi, Keystore anahtarının kasa anahtarını açabildiğiyle; ana parola, parola yuvasının açılabildiğiyle doğrulanır. Açılan kopya hemen silinir. Ana parolada hatalı denemeler kilit ekranındaki sayaca eklenir ve aynı bekleme uygulanır, yani bu pencere parola denemek için kullanılamaz.
- **Kapatmak doğrulama ister,** açmak istemez. Yoksa kilidi açık telefonu eline alan biri önce ayarı kapatabilirdi.
- Ayarlar henüz okunmadıysa kodlar gösterilmez.

**Ayar kaydı:** Ayarlar kasanın içinde, tür `settings` olan tek bir kayıtta durur. Kimliği 16 sıfır bayttır; tür ek doğrulama verisinde olduğu için başka bir kaydın yerine konamaz. Kayıt anahtarıyla şifrelenir. Düz metin:

```json
{ "version": 1, "otpRequireAuth": false }
```

- Kayıt yoksa ek onay kapalıdır. Kayıt var ama okunamıyorsa, biçime uymuyorsa veya türü farklıysa ek onay **açık** sayılır: dosyayı değiştiren biri ayarı böyle kapatamasın. Kullanıcı doğrulayıp kapatabilir. Kaydın tamamen silinmesi ise [kayıt silme sınırına](#bilinen-sınırlar) girer.

**Sınır:** Bu, kasa anahtarını değiştirmez. 2FA anahtarı yine kasa anahtarından türetilir, çünkü ana parola ve kurtarma anahtarı da 2FA kayıtlarını açabilmelidir. Ayar, kilidi açık telefonu eline alan birine karşı koruma sağlar, cihazdaki zararlı yazılıma karşı korumaz.

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

Kasa açıkken arama yapılabilsin diye kayıtların tamamı çözülüp bellekte tutulur. Kilitlenince bunlara ait bütün durumlar bırakılır.

2FA gizli anahtarları da çözülmüş kayıtla birlikte Dart belleğinde durur; kod her hesaplandığında kullanılır. HMAC `package:crypto` ile hesaplandığı için anahtar korumalı belleğe alınamaz. İçe aktarmada türetilen anahtarlar ve çözülen düz metin, işi bitince sıfırlanır. Pigeon'un Android'den getirdiği baytlar değiştirilemez olduğu için önce kopyalanır.

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
- **Biçim uyumluluğu:** `test/fixtures/crypto/` ve `test/fixtures/vault/` altındaki sabit dosyalar her sürümde açılabilmelidir. Bu dosyalar yalnızca deneme verisi ve deneme parolası içerir.
- **2FA:** HOTP ve TOTP, RFC 4226 ve RFC 6238 eklerindeki bütün vektörlerle; Base32, RFC 4648 vektörleriyle doğrulanır. `otpauth://` ayrıştırıcısı, Google Authenticator okuyucusu ve dosya okuyucuları rastgele bozulmuş girdilerle de çalıştırılır; yalnızca kendi hata türlerini fırlatmaları beklenir.
- **İçe aktarma:** scrypt ve PBKDF2-HMAC-SHA256, RFC 7914 vektörleriyle doğrulanır. Aegis projesinin testlerindeki örnek dışa aktarmalar (`test/fixtures/import/`) Node'un OpenSSL kriptosuyla açılarak ara değerler çıkarıldı; bizim türettiğimiz anahtarlar bunlarla karşılaştırılır. Android'in AES-GCM'i aynı değerlerle cihazda sınanır.
- **Cihaz testleri:** Aynı işlemler dört emülatörde çalıştırılır. Faz 2'de bir gerçek telefonda da çalıştırıldı.

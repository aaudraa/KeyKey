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

## Hata davranışı

| Durum | Hata | Anlamı |
|---|---|---|
| Parola yuvası açılmadı | `WrongSecretException` | Yanlış parola, veya üst bilgi değiştirilmiş. Bu ikisi kriptografik olarak ayırt edilemez. |
| Kurtarma yuvası açılmadı | `WrongSecretException` | Yanlış anahtar veya değiştirilmiş üst bilgi. |
| Kurtarma metni geçersiz | `InvalidRecoveryKeyException` | Yanlış karakter, uzunluk veya sağlama. |
| Üst bilgi okunamadı | `InvalidVaultHeaderException` | Bozuk dosya veya desteklenmeyen sürüm. |
| Kayıt açılmadı | `CorruptedDataException` | Değiştirilmiş, bozulmuş veya yanlış bağlamdaki kayıt. |

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

## Test yaklaşımı

- **Bağımsız vektörler:** Argon2id ve XChaCha20-Poly1305, libsodium'un kendi test vektörleriyle doğrulanır. HKDF sonuçları `package:crypto` ile ayrı hesaplanan HMAC-SHA256 ile karşılaştırılır.
- **Olumsuz testler:** Yanlış parola, tek bit değişimi, yer değiştirilmiş kayıt, değiştirilmiş parametre.
- **Biçim uyumluluğu:** `test/fixtures/crypto/` altındaki sabit dosyalar her sürümde açılabilmelidir. Bu dosyalar yalnızca deneme verisi ve deneme parolası içerir.
- **Cihaz testleri:** Aynı işlemler emülatörlerde de çalıştırılır.

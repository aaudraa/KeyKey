# Passkey sağlayıcısı

Faz 21'in tasarımı. Hedef sürüm `1.11.0`. Takip: Faz 21 milestone'u.

Proje sahibi 2026-11-19'da 1.0 sonrası listesindeki bütün fikirleri onayladı; 2026-11-24'te "faz 21'i ve küçük işlerin tamamını halledelim" dedi. Aşağıdaki seçimler benim, gerekçeleri yanlarında. Proje sahibi soru sorulmadan ilerlenmesini istiyor.

## Neden

Passkey, parolanın yerine geçen bir WebAuthn kimlik bilgisidir: site kullanıcıya özel bir açık anahtar saklar, giriş sırasında telefon özel anahtarla bir meydan okumayı imzalar. Parola sızdırılamaz, sahte siteye girilemez (imza sitenin adına bağlıdır). GitHub, Google, Microsoft, Amazon, PayPal gibi siteler passkey'e geçiyor.

Android 14'ten beri parola yöneticileri Credential Manager üzerinden passkey sağlayıcısı olabiliyor. Bugün KeyKey kullanıcısı passkey'lerini Google Parola Yöneticisi'nde tutmak zorunda; KeyKey'e geçmek "her şey tek yerde" sözünü bozuyor. F-Droid'in ilk başvuruda dediği "benzersiz özellik yok" itirazına da en güçlü cevap bu: hesapsız, sunucusuz, açık kaynak bir passkey sağlayıcısı az.

## Hedefler

- Android 14 ve üstünde KeyKey'i passkey sağlayıcısı olarak seçmek.
- **Oluşturma:** Bir site ya da uygulama passkey istediğinde KeyKey kasayı açtırır, ne oluşturulacağını gösterir, onayla oluşturur ve kasaya yazar.
- **Giriş:** Passkey istendiğinde KeyKey sistem penceresinde "KeyKey'in kilidini aç" seçeneği verir; kasa açılınca o sitenin passkey'leri aynı pencerede listelenir, seçilen hesapla imzalanır. Kasa bir kez açılır.
- Passkey'ler kasanın içinde şifreli durur: yedekle, otomatik yedekle ve senkronla taşınır, yeni telefona geçer.
- Kayıt ekranında passkey'ler görünür ve silinebilir.
- Bitwarden JSON ve KeePassXC (`.kdbx`) içe aktarmalarındaki passkey'ler alınır.

## Hedef olmayanlar

- **Android 13 ve öncesi.** Sağlayıcı API'si Android 14'te geldi; eski sürümlerde passkey ekranı ve ayar gösterilmez, içe aktarılan passkey'ler kasada durur.
- **Credential Manager üzerinden parola vermek.** Parolalar bugünkü doldurma servisiyle gelir; Credential Manager'ın parola seçeneği (`GetPasswordOption`) ayrı bir iş.
- **Tek dokunuşla biyometrik giriş** (Android 15'in `BiometricPromptData`'sı). Kasa her seferinde KeyKey'in kendi kilit ekranıyla açılır.
- **Başka cihaza QR ile passkey vermek** (hybrid/caBLE). Bunu Android'in kendisi yapar.
- **Passkey'i düz metin dışa aktarmak.** Özel anahtar düz metin dosyaya yazılmaz; düz metin dışa aktarma passkey'leri atlar ve bunu söyler.
- **Bağımsız onay (attestation).** Her zaman `none`.
- **Kayıt ekranında passkey düzenlemek.** Yalnızca görme ve silme.

## Karşı hedefler

- Kasa kilitliyken bir sitenin passkey'lerinin, hatta varlığının, dışarıdan görülebilmesi. Kilitliyken servis hiçbir kasa bilgisi okumaz.
- Bir uygulamanın, kullanıcı onaylamadan ya da kullanıcının göremeyeceği bir siteyle passkey kullanması.
- Özel anahtarın kasanın dışında (diskte, niyette, kayıtta) şifresiz kalması.
- Başka bir sitenin passkey'iyle imza atılması: `rpId` kurala uymayan istek reddedilir.
- Eski sürümlü bir telefonun passkey taşıyan kaydı sessizce bozması.

## Yaklaşımlar

### Nerede saklanır

| Yaklaşım | Artısı | Eksisi |
|---|---|---|
| **Parola kaydının içinde** (`LoginContent.passkeys`) | Kullanıcı aynı hesabın parolasını ve passkey'ini bir arada görür. Bitwarden ve KeePassXC de böyle. İçe aktarma doğrudan eşlenir. Çöp, klasör, favori, senkron hazır. | Parola kaydının sürümü artar; eski telefonlar senkronda "daha yeni KeyKey" der. |
| Ayrı kayıt türü (`passkey`) | Parola kaydı değişmez. | Aynı hesap iki ayrı kayıt olur; listede, aramada, çöpte, senkronda yeni bir türün her şeyi yeniden yazılır. Yedek sürümü yine artar. |

**Seçim: parola kaydının içinde.** Sürüm artışı iki yolda da kaçınılmaz.

### Kriptonun yeri

| Yaklaşım | Artısı | Eksisi |
|---|---|---|
| **P-256 Kotlin'de (Android'in sağlayıcısı), WebAuthn mantığı Dart'ta** | Anahtar üretimi ve imza incelenmiş bir sağlayıcıda (Conscrypt/BoringSSL). Kasaya erişen kod zaten Dart'ta; biçimler `flutter test` ile sınanır. | Pigeon ile iki çağrı. |
| Her şey Dart'ta (`pointycastle`) | Tek dil. | Saf Dart ECDSA'nın sabit zamanlı olmaması; yol haritası Android'in sağlayıcısını öngörüyor. |
| Her şey Kotlin'de | Credential Manager'a yakın. | Kasa Dart'ta; biçim kodu ikiye bölünür, testler zorlaşır. |

**Seçim: ilki.** `pointycastle` yalnızca testlerde imzayı doğrulamak için kullanılır.

### Girişte kilit

Sistem, sağlayıcıdan istek gelir gelmez (kasa açılmadan) hangi hesapları göstereceğini sorar. Üç yol:

| Yaklaşım | Artısı | Eksisi |
|---|---|---|
| **"KeyKey'in kilidini aç" eylemi** (`AuthenticationAction`), açılınca hesaplar aynı pencerede | Android'in öngördüğü yol; kilitliyken hiçbir şey sızmaz. | Kasa açılınca imzalar hesap seçilmeden hesaplanır (aşağıda). |
| Kilitliyken de hesap listesi (şifresiz bir dizin) | Tek dokunuş. | Hangi sitelerde passkey olduğu kasanın dışında durur: karşı hedef. |
| Tek sahte giriş ("KeyKey'den seç"), seçim KeyKey'in kendi ekranında | Tek kilit açma. | Her passkey isteğinde, passkey'i olmayan sitelerde bile, KeyKey satırı çıkar. |

**Seçim: ilki.** Kilit açılınca KeyKey, istekteki meydan okumayla o sitenin her uygun passkey'i için yanıtı hazırlar ve yalnızca yanıtları (özel anahtarı değil) süreç belleğinde 2 dakikalığına tutar. Sistem hesapları gösterir; kullanıcı birini seçince hafif bir ekran (Flutter'sız) o yanıtı verir ve hepsini siler. Kasa ikinci kez açılmaz, özel anahtar Dart dışında yalnızca imza çağrısı süresince bulunur. İmza sayacı her zaman 0 olduğu için önceden hesaplamak bir şey değiştirmez; kullanıcı yine bir hesap seçmeden hiçbir site imza almaz.

## Tasarım

### Saklama

`LoginContent` sürüm 3, yeni alan `passkeys` (liste, en çok 20). Her passkey:

| Alan | Tür | Not |
|---|---|---|
| `credentialId` | base64url | 16 rastgele bayt (içe aktarılanlarda kaynağınki, en çok 255 bayt) |
| `rpId` | dize | Geçerli ASCII alan adı, küçük harf |
| `userHandle` | base64url | Sitenin verdiği, en çok 64 bayt |
| `userName` | dize | |
| `userDisplayName` | dize | |
| `privateKey` | base64 | P-256, PKCS#8 DER |
| `createdAt` | zaman | |

- Sürüm 1 ve 2 okunmaya devam eder (`passkeys` boş). Yazılan her kayıt sürüm 3.
- Kayıt içerik sürümü artınca yedeğin içerik sürümü de artar (bir test sabitliyor): **yedek ve senkron dosyası 6**. Senkron dosyası 5 olamaz: 1.10 içerik sürümü 5'i zaten okuyor, ona "daha yeni" demez ve sürüm 3 kaydı okumaya çalışırdı. 1.11, 1.8-1.10'un sürüm 4 senkron dosyalarını okumaya devam eder. 1.10 ve öncesi yedeğe ve senkron dosyasına "daha yeni KeyKey" der; kasadaki kaydı okunamayan sayar ve dokunmaz. Kılavuz ve değişiklik günlüğü "bütün telefonları güncelle" der.
- Birleştirmede passkey'ler kaydın diğer alanları gibi davranır (kazanan sürüm).
- Kayıt düzenlenince (`applyEdit`) passkey'ler korunur.

### Anahtar ve imza (Kotlin, `PasskeyCryptoApi`)

- `generate()`: `KeyPairGenerator("EC")`, `secp256r1`; dönen: PKCS#8 özel anahtar, açık noktanın `x` ve `y`'si (32'şer bayt).
- `sign(privateKeyPkcs8, data)`: `SHA256withECDSA`, DER imza.
- Android Keystore kullanılmaz: anahtar kasaya yazılıp senkronla taşınacak, dışa alınabilir olmalı. Kotlin'e gelen özel anahtar baytları çağrıdan sonra sıfırlanır.

### WebAuthn (Dart)

- **İstek:** Credential Manager'ın verdiği JSON (`PublicKeyCredentialCreationOptionsJSON` / `RequestOptionsJSON`). Katı ama bilinmeyen alanlara açık okunur (siteler eklenti ekler).
- **rpId kuralı:** `rpId` geçerli bir alan adı, public suffix değil. Tarayıcıda origin `https://` ve ana bilgisayarı `rpId`'ye eşit ya da onun alt alanı.
- **authenticatorData:** `SHA-256(rpId)` · bayraklar `UP|UV|BE|BS` (+ oluşturmada `AT`) · sayaç 0 · oluşturmada AAGUID + kimlik + COSE anahtarı. UV: kasa ana parola ya da parmak iziyle açıldı. BE/BS: passkey yedeklenebilir ve kasayla taşınır.
- **AAGUID:** KeyKey'in sabiti `b3c1e1d0-6b2a-4f3e-9c7a-4b6579b4b579` (rastgele üretildi). Topluluğun AAGUID listesine eklenmesi ayrı bir iş.
- **Onay:** `fmt: "none"`, `attStmt: {}`. Küçük bir CBOR yazıcısı (eşlem, tamsayı, bayt dizisi, metin; kanonik sıra).
- **Algoritma:** Yalnızca ES256 (`-7`). İstekte yoksa "desteklenmiyor".
- **excludeCredentials:** Kasada (çöp dışı) o `rpId` için listedeki bir kimlik varsa "bu hesap için zaten passkey var".
- **clientDataJSON:** `{"type","challenge","origin","crossOrigin":false}`. Tarayıcı `clientDataHash` verdiyse imzada o kullanılır (tarayıcı kendi JSON'unu koyar).
- **Yanıt:** `RegistrationResponseJSON` / `AuthenticationResponseJSON`; `authenticatorAttachment: "platform"`, `transports: ["internal","hybrid"]`, `clientExtensionResults: {"credProps":{"rk":true}}` (oluşturmada). `userHandle` girişte döner; passkey'in kullanıcı kimliği yoksa (bazı KeePassXC passkey'leri) alan hiç yazılmaz.
- **Meydan okuma:** 1-1024 bayt. WebAuthn'in 16 baytı yalnızca öneri; tarayıcılar daha kısasını reddetmediği için KeyKey de reddetmez.

### Origin ve çağıranın doğrulanması (Kotlin + Dart)

- **Güvenilen tarayıcı:** `CallingAppInfo.getOrigin(liste)` ile. Liste, KeyKey'in gömülü güvenilen tarayıcı listesinden (paket + imza özetleri) Credential Manager'ın biçiminde üretilir. Origin'i `rpId` kuralına uymayan istek reddedilir.
- **Başka bir uygulama:** origin `android:apk-key-hash:<base64url(SHA-256(imza))>`; çok imzacılı uygulama desteklenmez. Uygulamanın `rpId` sitesine ait olduğu Faz 25'in kurallarıyla denetlenir: Android'in doğruladığı alan adları, ayar açıksa `assetlinks.json` (`get_login_creds`). Doğrulanamazsa ekran uyarır ("Bu uygulamanın github.com'a ait olduğu doğrulanamadı") ve onay ister. Site sunucusu origin'deki imza özetini zaten denetler; uyarı kullanıcının sahte bir uygulamada passkey kullanmasını zorlaştırır.
- **Güvenilmeyen tarayıcı:** Origin alınamaz, uygulama gibi davranılır; sitenin sunucusu `apk-key-hash` origin'ini reddeder.

### Akış

```
Oluşturma
  site/uygulama ──createCredential──▶ Android ──onBeginCreate──▶ KeyKeyCredentialService
     (kilitliyken)                                ◀── CreateEntry("KeyKey") ──
  kullanıcı KeyKey'i seçer ──▶ PasskeyActivity (Flutter, passkeyMain)
     kilit ekranı → onay: site, hesap, uygulama/tarayıcı, uyarılar, hangi kayda
     → generate → kasaya yaz → yanıt → kilitle → kapat

Giriş
  site/uygulama ──getCredential──▶ Android ──onBeginGet──▶ servis
                                   ◀── AuthenticationAction("KeyKey'in kilidini aç")
  kullanıcı dokunur ──▶ PasskeyActivity: kilit ekranı (uyarılar varsa onay)
     → o rpId'nin passkey'leri (allowCredentials süzgeci) → her biri için yanıt
     → yanıtlar bellekte (2 dk) → BeginGetCredentialResponse(hesaplar) → kilitle → kapat
  Android hesapları gösterir; kullanıcı seçer ──▶ PasskeyResponseActivity (Flutter'sız)
     → bekleyen yanıtı verir, hepsini siler
```

- **Hangi kayda:** Oluşturmada aynı sitenin (`rpId` sitesi) adresini taşıyan ve kullanıcı adı `userName` olan çöp dışı kayıt varsa passkey ona eklenir; yoksa yeni kayıt: ad `rp.name` (yoksa `rpId`), kullanıcı adı `userName`, adres `https://<rpId>`. Birden çok aday varsa ekran seçtirir. Uygulamadan oluşturulduysa uygulama da kayda bağlanır (doğrulanmışsa).
- **Kasa:** Her işlemden sonra kilitlenir (doldurma ekranı gibi).
- Passkey isteği yoksa (yalnız parola istendi) servis boş yanıt verir.

### Arayüz

- **Kayıt ayrıntısı:** "Passkey'ler" bölümü: site, kullanıcı adı, oluşturulma tarihi; uzun basınca/menüyle "Passkey'i sil" (onaylı). Listede passkey'li kayıtta küçük bir anahtar simgesi.
- **Ayarlar → Otomatik doldurma:** Android 14+'ta "Passkey sağlayıcısı" satırı: açıklama ve sistemin sağlayıcı ayarına giden düğme (`Settings.ACTION_CREDENTIAL_PROVIDER`).
- **Passkey penceresi:** Doldurma penceresinin görünümü (alttan açılan cam pencere, içinde kilit ekranı). Onayda: sitenin adı, hesap, "<uygulama> için" ya da "<tarayıcı> içinde", varsa uyarılar, "Passkey oluştur" / "Vazgeç".
- **Hatalar:** Desteklenmeyen algoritma, zaten var, geçersiz istek, kasa kurulmamış: pencerede açık bir mesaj; Credential Manager'a uygun hata türü döner.

### İçe aktarma

- **Bitwarden JSON:** `login.fido2Credentials[]`: `credentialId` (GUID ya da `b64.` önekli), `keyType: "public-key"`, `keyAlgorithm: "ECDSA"`, `keyCurve: "P-256"`, `keyValue` (base64url PKCS#8), `rpId`, `userHandle`, `userName`, `userDisplayName`, `creationDate`. Başka algoritma atlanır ve sayılır.
- **KeePassXC:** `KPEX_PASSKEY_CREDENTIAL_ID`, `KPEX_PASSKEY_PRIVATE_KEY_PEM`, `KPEX_PASSKEY_RELYING_PARTY`, `KPEX_PASSKEY_USERNAME`, `KPEX_PASSKEY_USER_HANDLE`. Bugün `KPEX_` alanları atılıyor; passkey alanları artık passkey'e dönüşür.
- Önizleme passkey sayısını söyler. Özel anahtar geçerli bir P-256 anahtarı değilse o passkey atlanır.

### Bağımlılık

`androidx.credentials:credentials:1.6.0` (Apache 2.0, AOSP; Google Play hizmetleri gerektirmez, `credentials-play-services-auth` eklenmez). Yeni izin yok: servis `BIND_CREDENTIAL_PROVIDER_SERVICE` ile korunur, bu kullanıcıdan istenen bir izin değil. APK izin denetimi bunu doğrular.

## Testler

- Dart: CBOR yazıcısı (bilinen vektörler), authenticatorData, clientDataJSON, istek okuma (gerçek sitelerin örnek istekleri), `rpId`/origin kuralı, kayıt seçimi, `LoginContent` sürüm 3 (eski sürümleri okuma, sınırlar), yedek/senkron sürüm sabitleri, içe aktarma; oluşturma ve giriş yanıtlarının imzası `pointycastle` ile doğrulanır.
- Widget: passkey penceresi (kilit, onay, uyarılar, hatalar), kayıt ayrıntısındaki bölüm, ayar satırı.
- Kotlin: tarayıcı listesinden Credential Manager listesi, `apk-key-hash` origin'i, anahtar üretimi ve imzanın doğrulanması.
- Cihaz (Android 17 emülatörü): örnek giriş uygulamasına Credential Manager ile "passkey oluştur / passkey ile gir" eklenir (`giris.example.com`, Faz 25'teki gibi doğrulanmış alan adı); Chrome'da webauthn.io ile oluşturma ve giriş. Entegrasyon testleri yeniden.

## Builder'a kalanlar

- Pencerenin metinleri ve ikonları; Flutter giriş noktasının doldurma uygulamasıyla ne kadar kod paylaşacağı.
- Bekleyen yanıtların süresinin tam değeri (2 dakika önerisi).
- Sitelerin örnek istekleri (webauthn.io, GitHub) test verisi olarak.

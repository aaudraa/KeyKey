# Passkey sağlayıcısı uygulama planı

> **Yürütme:** superpowers:executing-plans ile, satır içinde (proje sahibinin tercihi). Adımlar `- [ ]` ile izlenir.

**Amaç:** Android 14+'ta KeyKey'i passkey sağlayıcısı yapmak: oluşturma, giriş, kasada saklama, görme/silme, içe aktarma.

**Mimari:** `androidx.credentials` sağlayıcı servisi (Kotlin) yalnızca yapıştırıcı: istekleri Flutter'daki passkey penceresine taşır, yanıtları sisteme verir. P-256 anahtar üretimi ve imza Kotlin'de (Android'in sağlayıcısı). WebAuthn biçimleri, kurallar ve kasa Dart'ta.

**Teknoloji:** Flutter/Dart, Riverpod, Pigeon, Kotlin, `androidx.credentials:credentials:1.6.0`, testte `pointycastle`.

**Tasarım:** [`passkey.md`](passkey.md). Dal: `faz/21-passkey`.

## Genel kısıtlar

- Yalnızca Android 14 (API 34) ve üstünde servis etkin; minSdk 30 kalır.
- `LoginContent.currentVersion = 3`, `BackupCodec.payloadVersion = 6`, senkron dosyası da 6 ile yazılır (4 ve 5 okunur).
- Kayıt başına en çok 20 passkey; `credentialId` en çok 255 bayt, `userHandle` en çok 64 bayt.
- Yalnızca ES256 (`-7`); `fmt: "none"`; sayaç 0; bayraklar `UP|UV|BE|BS` (+`AT`).
- AAGUID `b3c1e1d0-6b2a-4f3e-9c7a-4b6579b4b579`.
- Bekleyen giriş yanıtları süreç belleğinde en çok 2 dakika.
- Yeni kullanıcı izni yok; `check-release-apk.sh` listesi değişmez.
- Metinler Türkçe ve İngilizce ARB'de; kod adları İngilizce, yorumlar Türkçe.

## İnceleme odağı

1. Kasa kilitliyken servisin kasa bilgisi okuması ya da göstermesi: servis hiçbir zaman kasaya dokunmaz (Görev 4 testi: servis yanıtı kasa dosyası yokken de aynı).
2. `rpId` origin'e uymayan ya da public suffix olan istek (`com`, `github.io` alt alanı olmayan): reddedilir (Görev 3).
3. Aynı site için oluşturmada eşleşen birden çok kayıt ya da çöpteki kayıt: çöptekine eklenmez, birden çoksa seçtirilir (Görev 6).
4. Kullanıcı hesap seçmeden pencereyi kapatırsa bekleyen yanıtlar silinir; 2 dakika sonra da silinir (Görev 5).
5. Eski sürüm yedeği (sürüm 5) ve sürüm 2 kaydı okunmaya devam eder; sürüm 3 kaydı passkey'lerini yitirmeden düzenlenir (Görev 1).

---

### Görev 1: Kayıt modeli ve sürümler

**Dosyalar:** `lib/features/vault/data/login_passkey.dart` (yeni), `lib/features/vault/data/login_content.dart`, `lib/core/backup/backup_codec.dart`, testler `test/features/vault/data/login_passkey_test.dart`, `test/features/vault/login_content_test.dart` (var olan), `test/core/backup/backup_codec_test.dart`.

**Üretir:** `final class LoginPasskey { new({required Uint8List credentialId, required String rpId, required Uint8List userHandle, required String userName, required String userDisplayName, required Uint8List privateKey, required DateTime createdAt}); Map<String,Object?> toJson(); static LoginPasskey fromJson(Object?) }`; `LoginContent.passkeys: List<LoginPasskey>`, `copyWith(passkeys:)`.

- [ ] Testler: v3 gidiş-dönüş; v2 ve v1 okunur (`passkeys` boş); 21 passkey, 256 baytlık kimlik, 65 baytlık `userHandle`, geçersiz `rpId`, fazla alan reddedilir; `applyEdit` passkey'leri korur; sürüm sabitleri testi `login: 3, payload: 6`; senkron dosyası 6 yazılır, 4 okunur, 7 "daha yeni".
- [ ] Kırmızıyı gör, uygula, yeşili gör, `flutter analyze`.
- [ ] Commit: `özellik(kasa): parola kaydında passkey alanı, kayıt sürümü 3`.

### Görev 2: WebAuthn biçimleri

**Dosyalar:** `lib/features/passkey/domain/cbor.dart`, `lib/features/passkey/domain/webauthn.dart`, testler `test/features/passkey/cbor_test.dart`, `test/features/passkey/webauthn_test.dart`, örnek istekler `test/features/passkey/fixtures/*.json`.

**Üretir:**
- `Uint8List cborEncode(Object? value)` (int, Uint8List, String, bool, List, Map; eşlem anahtarları kanonik sırada).
- `CreationOptions.parse(String json)` (`rpId`, `rpName`, `userId`, `userName`, `userDisplayName`, `challenge`, `algorithms`, `excludeCredentialIds`); `RequestOptions.parse(String json)` (`rpId`, `challenge`, `allowCredentialIds`). Hata: `PasskeyRequestException(PasskeyError kind)`; `enum PasskeyError { invalidRequest, unsupportedAlgorithm, alreadyExists, rpIdMismatch, noPasskeys }`.
- `typedef PasskeySigner = Future<Uint8List> Function(Uint8List privateKey, Uint8List data)`.
- `String buildClientDataJson({required String type, required Uint8List challenge, required String origin})`.
- `Future<String> registrationResponse({required CreationOptions options, required Uint8List credentialId, required Uint8List publicX, required Uint8List publicY, required String origin, Uint8List? clientDataHash})`.
- `Future<String> assertionResponse({required RequestOptions options, required LoginPasskey passkey, required String origin, Uint8List? clientDataHash, required PasskeySigner sign})`.
- `rpId` yoksa origin'in ana bilgisayarı kullanılır (WebAuthn kuralı); uygulama origin'inde `rpId` zorunlu.

- [ ] Testler: CBOR RFC 8949 ek A vektörlerinden (0, 23, 24, 255, 65536, -1, -500, `h''`, `"a"`, `[1,[2,3]]`, `{1:2,3:4}`); COSE anahtarı `{1:2,3:-7,-1:1,-2:x,-3:y}` baytları; authData uzunluğu ve bayrakları (`0x5D` oluşturma, `0x1D` giriş); `clientDataHash` verilince imzalanan veri `authData ‖ hash`; giriş yanıtının imzası `pointycastle` ile açık anahtarla doğrulanıyor; webauthn.io ve GitHub örnek istekleri okunuyor; ES256'sız istek `unsupportedAlgorithm`.
- [ ] Kırmızı → uygula → yeşil → commit `özellik(passkey): WebAuthn biçimleri ve CBOR`.

### Görev 3: rpId, origin ve çağıranın doğrulanması

**Dosyalar:** `lib/features/passkey/domain/passkey_caller.dart`, test `test/features/passkey/passkey_caller_test.dart`.

**Tüketir:** `PublicSuffixList`, `DomainName` (otomatik doldurma), `checkSitesOnline`, `AppDomain` (Faz 25).

**Üretir:**
- `final class PasskeyCaller { new({required String packageName, required List<String> certsSha256, String? browserOrigin, String? appLabel}); bool get isBrowser; String origin(); }` — uygulama origin'i `android:apk-key-hash:<base64url(sha256)>`; çok imzacılıda `origin()` `PasskeyRequestException(invalidRequest)`.
- `bool rpIdAllowed(String rpId, PasskeyCaller caller, PublicSuffixList psl)`.
- `Future<bool> appBelongsToRp({required PasskeyCaller caller, required String rpId, required List<AppDomain> domains, required bool verifyOnline, required AssetLinksSource source, required SignatureCheck check, required PublicSuffixList psl})`.

- [ ] Testler: `https://github.com` → `github.com` ve `www.github.com` değil reddedilmez, `evil.com` reddedilir; `http://` reddedilir; `rpId = "com"`, `"github.io"` reddedilir; uygulamada `rpId` serbest ama `appBelongsToRp` Android'in doğruladığı alan adıyla `true`, ayar kapalı ve doğrulanmamışsa `false` ve ağa çıkılmaz; bilinen bir imza özetinin origin metni.
- [ ] Kırmızı → uygula → yeşil → commit `özellik(passkey): origin ve rpId kuralları`.

### Görev 4: Android sağlayıcı servisi, kripto ve manifest

**Dosyalar:** `android/app/build.gradle.kts` (bağımlılık), `pigeons/platform_api.dart` (+üretilen), `android/.../passkey/PasskeyCrypto.kt`, `android/.../passkey/KeyKeyCredentialService.kt`, `android/.../passkey/PrivilegedBrowsers.kt`, `android/app/src/main/res/xml/credential_provider.xml`, `android/app/src/main/res/values/bools.xml` + `values-v34/bools.xml`, manifest, Kotlin testleri `android/app/src/test/.../passkey/*Test.kt`.

**Üretir:** Pigeon `@HostApi PasskeyCryptoApi { PasskeyKeyPair generate(); Uint8List sign(Uint8List privateKey, Uint8List data); }` (`PasskeyKeyPair { Uint8List privateKey; Uint8List x; Uint8List y; }`); `PrivilegedBrowsers.allowlistJson(): String` (TrustedBrowserList'ten, `{"apps":[{"type":"android","info":{"package_name":…,"signatures":[{"build":"release","cert_fingerprint_sha256":"AA:…"}]}}]}`); servis: `onBeginCreateCredentialRequest` → `CreateEntry("KeyKey")` (PendingIntent → `PasskeyActivity`, eylem `CREATE`), `onBeginGetCredentialRequest` → passkey seçeneği varsa `AuthenticationAction` (eylem `UNLOCK`), yoksa boş; `onClearCredentialStateRequest` → başarı.

- [ ] Kotlin testleri: üretilen anahtarla imza `Signature.verify` ile doğrulanıyor; `x`,`y` 32 bayt; allowlist JSON'u Chrome'u içeriyor ve özetler iki nokta ile büyük harf; servis yanıtı kasa olmadan kurulabiliyor (kasa sınıflarına bağımlılık yok).
- [ ] Manifest: servis `android:permission="android.permission.BIND_CREDENTIAL_PROVIDER_SERVICE"`, `android:enabled="@bool/passkeys_supported"`, `exported=true`, eylem `android.service.credentials.CredentialProviderService`, meta-data `android.credentials.provider` → `credential_provider.xml` (`android.credentials.TYPE_PUBLIC_KEY_CREDENTIAL`).
- [ ] `:app:testDebugUnitTest` yeşil, `flutter analyze` yeşil, commit `özellik(passkey): Credential Manager servisi ve P-256`.

### Görev 5: Passkey ekranları (Kotlin tarafı) ve köprü

**Dosyalar:** `pigeons/platform_api.dart`, `android/.../passkey/PasskeyActivity.kt` (FlutterFragmentActivity, giriş noktası `passkeyMain`, `WindowProtection`), `android/.../passkey/PasskeyResponseActivity.kt` (saydam, Flutter'sız), `android/.../passkey/PendingAssertions.kt`, `lib/features/passkey/application/passkey_bridge.dart`, Kotlin testi `PendingAssertionsTest.kt`.

**Üretir:** Pigeon
- `PasskeyRequestInfo { String kind /* create|get */; String requestJson; String packageName; List<String> certsSha256; String? appLabel; String? browserOrigin; Uint8List? clientDataHash; }`
- `@HostApi PasskeyApi { PasskeyRequestInfo? request(); void finishCreate(String responseJson); void finishGet(List<PasskeyAssertion> assertions); void fail(String error); void cancel(); }`, `PasskeyAssertion { String credentialIdB64; String userName; String displayName; String responseJson; }`
- Dart: `abstract interface class PasskeyBridge` aynı işlemlerle, `PigeonPasskeyBridge`, `passkeyBridgeProvider`.
- `PendingAssertions.put(list): String token`, `take(token, credentialId): String?` (alınca hepsi silinir), 2 dk sonra kendiliğinden silinir.

- [ ] `PendingAssertionsTest`: alınan yanıt bir kez verilir; ikinci kez `null`; süre dolunca `null` (sahte saat).
- [ ] `finishGet` → `PublicKeyCredentialEntry` (kullanıcı adı, görünen ad, PendingIntent → `PasskeyResponseActivity` + token + kimlik) ile `BeginGetCredentialResponse`; `fail` → `CreateCredentialUnknownException` / `GetCredentialUnknownException` ya da türüne göre (`alreadyExists` → `CreatePublicKeyCredentialDomException(InvalidStateError)`, `unsupportedAlgorithm` → `NotSupportedError`).
- [ ] Derle, commit `özellik(passkey): passkey ekranları ve köprü`.

### Görev 6: Passkey penceresi (Flutter)

**Dosyalar:** `lib/main.dart` (`passkeyMain`), `lib/features/passkey/presentation/passkey_app.dart`, `passkey_create_screen.dart`, `passkey_get_screen.dart`, `lib/features/passkey/application/passkey_service.dart`, ARB'ler, testler `test/features/passkey/passkey_screens_test.dart`, `passkey_service_test.dart`.

**Tüketir:** Görev 1-3, 5; `AutofillSheetFrame`, `LockScreen`, `loginsControllerProvider`, `publicSuffixListProvider`, `assetLinksSourceProvider`.

**Üretir:** `PasskeyService` (Riverpod): `Future<String> create({required PasskeyCaller caller, required CreationOptions options, required LoginItem? target})` (anahtar üretir, kasaya yazar: hedef kayda ekler ya da yeni kayıt; uygulama doğrulanmışsa uygulamayı bağlar), `List<LoginItem> createTargets(rpId, userName)` (çöp dışı, aynı site + aynı kullanıcı adı), `Future<List<PasskeyAssertion>> assertions({caller, options})`.

- [ ] Testler: kilitliyken kilit ekranı ve alt başlık "github.com için passkey"; açınca onay: site, hesap, uyarı (doğrulanmamış uygulama), "Passkey oluştur" yeni kayıt açıyor ve passkey ekliyor, aynı site + kullanıcı adı kaydına ekliyor, iki aday varsa seçtiriyor, çöptekine eklemiyor; `excludeCredentials` eşleşirse "zaten var" ve `fail(alreadyExists)`; giriş: kilit açılınca o sitenin iki passkey'i için yanıt `finishGet`'e gidiyor, `allowCredentials` süzüyor, passkey yoksa "Bu site için passkey yok" ve `finishGet([])`; işlemden sonra kasa kilitli; vazgeç `cancel`.
- [ ] Kırmızı → uygula → yeşil → commit `özellik(passkey): passkey penceresi`.

### Görev 7: Kasadaki görünüm ve ayar

**Dosyalar:** `lib/features/vault/presentation/login_detail_screen.dart` (+ `passkey_section.dart`), liste kartı (`vault_entry_tiles.dart`), `lib/features/autofill/presentation/autofill_setup_section.dart` + `AutofillSetupApi` (`openCredentialProviderSettings()`, `passkeysSupported()`), ARB'ler, testler `vault_screens_test.dart`, `settings` testleri.

- [ ] Testler: passkey'li kayıtta bölüm, site, kullanıcı adı, tarih; "Passkey'i sil" onaylanınca kayıttan çıkıyor, vazgeçince kalıyor; listede anahtar simgesi ve ekran okuyucu etiketi "passkey var"; ayar satırı yalnızca destekleniyorsa ve düğme köprüyü çağırıyor.
- [ ] Kırmızı → uygula → yeşil → commit `özellik(passkey): kayıtta passkey'ler ve sağlayıcı ayarı`.

### Görev 8: İçe aktarma ve düz metin dışa aktarma

**Dosyalar:** `lib/features/backup/data/import/login_import.dart` (Bitwarden `fido2Credentials`, `ImportedLogin.passkeys`), `kdbx/kdbx_import.dart` (`KPEX_PASSKEY_*`, PEM → PKCS#8), `lib/features/backup/application/login_import_plan.dart` (passkey sayısı), düz metin dışa aktarma (passkey'ler atlanır, ekranda söylenir), test verileri ve testler.

- [ ] Testler: Bitwarden örneği (GUID ve `b64.` kimlik) passkey'e dönüşüyor; P-256 olmayan atlanıp sayılıyor; KeePassXC örnek `.kdbx`'i (KeePassXC 2.7 komut satırıyla ya da elle kurulmuş XML) passkey veriyor ve `KPEX_PASSKEY_*` özel alana düşmüyor; önizleme "3 passkey"; dışa aktarma ekranında "Passkey'ler dışa aktarılmaz" notu.
- [ ] Kırmızı → uygula → yeşil → commit `özellik(içe-aktarma): passkey'ler`.

### Görev 9: Belgeler ve sürüm

- [ ] Güvenlik tasarımı: "Passkey" bölümü (saklama, kripto, origin, akış, bilinen sınırlar), kayıt biçimi sürüm 3, yedek sürüm 6, senkron 5; tehdit modeline sağlayıcı.
- [ ] Gizlilik (TR/EN): passkey'ler kasada, hiçbir şey gönderilmez; koşullar değişmez (gerekirse sürüm 5).
- [ ] Kılavuz (`kullanim.md`): passkey sağlayıcısını seçmek, oluşturma, giriş, "bütün telefonları güncelle".
- [ ] Bağımlılıklar ve lisanslar (`androidx.credentials`), değişiklik günlüğü, mağaza sürüm notu, `pubspec.yaml` 1.11.0, yol haritası Faz 21 bölümü.
- [ ] Commit `belge(passkey): …` ve `sürüm: 1.11.0`.

### Görev 10: Cihazda deneme

- [ ] Örnek giriş uygulamasına (`resources/test-apps/ornek-giris`) "Passkey oluştur / Passkey ile gir" (`CredentialManager`, `rpId = giris.example.com`) ve yanıtı doğrulayan küçük bir denetim.
- [ ] Android 17 emülatörü (`-gpu host`, tek emülatör): KeyKey'i sağlayıcı seç; örnek uygulamada oluştur → gir; Chrome'da webauthn.io'da oluştur → gir; kasa kilitliyken hiçbir hesap görünmüyor.
- [ ] `flutter test integration_test -d <emülatör>` (10 dakikalık parçalar), Gradle ve emülatör kapatılır.

### Görev 11: Son gözden geçirme ve yayın

- [ ] Taze bir alt ajanla (Opus) dalın bütününe gözden geçirme; önemli bulgular düzeltilir, küçükler issue'ya.
- [ ] `main` dala birleştirilir, PR açılır, bütün denetimler yeşil olunca birleştirilir, `v1.11.0` etiketi, yayın onayı proje sahibinde, yol haritası PR'ı.

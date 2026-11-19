# İnternet ve sızıntı kontrolü uygulama planı

> **Yürütenler için:** superpowers:executing-plans ile görev görev uygulanır (proje sahibi soru istemiyor, yürütme bu oturumda). Adımlar `- [ ]` ile izlenir.

**Amaç:** KeyKey'e `INTERNET` izni ve parola raporunda Have I Been Pwned sızıntı kontrolü eklemek; bütün "internet yok" metinlerini aynı sürümde değiştirmek.

**Mimari:** Tek ağ dosyası (`PwnedPasswordsClient`, Dart `HttpClient`) yalnızca 5 karakterlik önek gönderir. `BreachChecker` özetleri öneklere göre gruplar, sorar ve sonuçları telefonda eşleştirir. Raporun yeni bölümü bir Riverpod denetleyicisiyle çalışır; sonuç yalnızca bellekte.

**Teknoloji:** Flutter/Dart (`dart:io`, `package:crypto` zaten bağımlılık), Riverpod, Android manifest ve ağ güvenliği yapılandırması, bash denetim betiği.

**Tasarım:** [`internet-ve-sizinti.md`](internet-ve-sizinti.md)

## Genel kurallar

- Tek adres: `https://api.pwnedpasswords.com/range/{önek}`; önek tam 5 karakter, `0-9A-F`. Başlıklar `Add-Padding: true`, `User-Agent: KeyKey`. Yönlendirme izlenmez. Bağlantı 10 sn, istek 30 sn, yanıt en çok 1 MiB.
- Eşzamanlı en çok 4 istek, önekler karışık sırayla, her önek bir kez yeniden denenir; bir önek yine olmazsa denetimin tamamı hatadır, yarım sonuç gösterilmez.
- Yanıt satırı `^[0-9A-F]{35}:[0-9]+$`; sayısı 0 olan (dolgu) atılır.
- Yeni bağımlılık eklenmez. Ağ kodu yalnızca `lib/core/network/pwned_passwords_client.dart`'ta.
- Sonuç kasaya, ayarlara, diske ve kayda yazılmaz; kilitte sıfırlanır.
- Kullanım koşulları sürüm 2. Uygulama sürümü `1.6.0+10`.
- Commit'ler Türkçe, `<tür>(<alan>): …`, sonunda `Refs #152`.

## Gözden geçirmede bakılacaklar

Tasarımın açıkça söylemediği ama kullanıcıyı yakabilecek durumlar; her birinin testi sahibi olan göreve eklendi:

1. **Yüzlerce kayıt** (300 farklı parola): denetim biter, aynı anda en çok 4 istek, ilerleme 300/300'e varır (Görev 2).
2. **Türkçe harfli ve emojili parolalar:** özet UTF-8 baytlarından alınır; `şifre` → `F03EA60F6F5B83B64103EBFF11C5249ACAE2E687` (Görev 2).
3. **Telefon internete bağlı görünüp yanıt HTML dönüyor** (otel, kafe giriş sayfası, 200 yanıt): yanıt geçersiz sayılır, ekran "Sızıntı yok" demez, hata gösterir (Görev 2 ve 3).
4. **Denetim sürerken ekrandan çıkma ya da kilitleme:** çökme yok, yeni istek başlamaz, sonuç atılır (Görev 3).
5. **Denetimden sonra parolası değiştirilen kayıt:** sızanlar listesinden düşer; yeni parolası denetlenmemiş sayılır (Görev 3).

---

### Task 1: Ağ istemcisi ve ağ denetimi testi

**Dosyalar:**
- Oluştur: `lib/core/network/pwned_passwords_client.dart`
- Test: `test/core/network/pwned_passwords_client_test.dart`, `test/core/network/network_audit_test.dart`

**Arayüzler:**
- Üretir:
  - `abstract interface class PwnedRangeSource { Future<String> fetchRange(String prefix); }`
  - `final class PwnedPasswordsClient implements PwnedRangeSource` — `new({Uri? baseUri, Duration connectTimeout = const Duration(seconds: 10), Duration requestTimeout = const Duration(seconds: 30)})`; `baseUri` varsayılanı `https://api.pwnedpasswords.com/range/` (yalnızca testler değiştirir, `@visibleForTesting` açıklamasıyla).
  - `final class PwnedPasswordsException implements Exception` (`message` alanı; parola ya da önek taşımaz).
  - `final Provider<PwnedRangeSource> pwnedRangeSourceProvider`.
  - Geçersiz önekte `ArgumentError` (ağa çıkmadan).

- [ ] **Adım 1: Başarısız testleri yaz.** İstemci testleri `HttpServer.bind(InternetAddress.loopbackIPv4, 0)` ile:
  - `sorguYalnızcaÖnekGönderir`: `fetchRange('5BAA6')` gövdeyi döndürür; sunucu `GET /range/5BAA6` gördü, sorgu dizesi yok, `add-padding: true`, `user-agent: KeyKey`.
  - `geçersizÖnekAğaÇıkmaz`: `'5baa6'`, `'5BAA'`, `'5BAA61'`, `'5BA/6'`, `''` için `ArgumentError`; sunucuya istek gelmedi.
  - `yönlendirmeİzlenmez`: 302 → `PwnedPasswordsException`, sunucuya tek istek.
  - `başarısızYanıtHata`: 503 → `PwnedPasswordsException`.
  - `büyükYanıtReddedilir`: 1 MiB + 1 bayt gövde → `PwnedPasswordsException`.
  - `zamanAşımı`: sunucu yanıt vermez, `requestTimeout: 200 ms` → `PwnedPasswordsException`.
  - Ağ denetimi: `lib/**/*.dart` ve `android/app/src/main/**/*.kt` taranır; `\b(HttpClient|HttpServer|WebSocket|RawSocket|SecureSocket|Socket|RawDatagramSocket|HttpURLConnection|URLConnection)\b`, `package:http/`, `java.net.URL`, `okhttp` yalnızca istemci dosyasında bulunabilir. Ayrıca denetleyicinin örnek bir `HttpClient()` satırını yakaladığı bir öz-sınama.
- [ ] **Adım 2:** `flutter test test/core/network` → derleme hatasıyla düşer (dosya yok).
- [ ] **Adım 3:** İstemciyi yaz: `followRedirects = false`, `maxRedirects = 0`, bağlantı zaman sınırı, `timeout(requestTimeout)`, gövdeyi en çok 1 MiB okuyup UTF-8 çöz; her hatayı (`SocketException`, `HandshakeException`, `TimeoutException`, `HttpException`) `PwnedPasswordsException`'a çevir; `HttpClient` her istekte `close()`.
- [ ] **Adım 4:** `flutter test test/core/network` → geçer.
- [ ] **Adım 5:** commit `özellik(ağ): Pwned Passwords istemcisi ve ağ kodu denetimi`.

### Task 2: Sızıntı denetimi

**Dosyalar:**
- Oluştur: `lib/features/vault/application/breach_check.dart`
- Test: `test/features/vault/breach_check_test.dart`

**Arayüzler:**
- Tüketir: `PwnedRangeSource`, `PwnedPasswordsException` (Görev 1); `LoginItem` (`content.password`, `content.isTrashed`, `content.name`).
- Üretir:
  - `String pwnedHash(String password)` — SHA-1, UTF-8, büyük harfli onaltılık 40 karakter.
  - `Map<String, int> parsePwnedRange(String body)` — sonek → sayı (yalnızca > 0); geçersiz satırda `FormatException`.
  - `final class BreachResult { const new({required Map<String, int> counts, required Set<String> checked}); int? countFor(String password); }` — denetlenmemiş özette `null`, temizse `0`.
  - `final class BreachCheckCancelled implements Exception`.
  - `final class BreachChecker { new(PwnedRangeSource source, {int concurrency = 4, Random? random}); Future<BreachResult> check(Iterable<LoginItem> items, {void Function(int done, int total)? onProgress, bool Function()? isCancelled}); }` — hata `PwnedPasswordsException` ya da `FormatException` olarak çıkar.
  - `List<(LoginItem, int)> leakedLogins(Iterable<LoginItem> items, BreachResult result)` — çöpte olmayan ve sayısı > 0 olanlar; sayı azalan, eşitse `foldForSearch(name)`.

- [ ] **Adım 1: Başarısız testleri yaz:**
  - `özetDeğerleri`: `password` → `5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8`, `abc` → `A9993E364706816ABA3E25717850C26C9CD0D89D`, `şifre` → `F03EA60F6F5B83B64103EBFF11C5249ACAE2E687`.
  - `yanıtOkuma`: `"1E4C9B93F3F0682250B6CF8331B7EE68FD8:9659365\r\n0018A45C4D1DEF81644B54AB7F969B88D65:0\r\n\r\n"` → `{'1E4C9B93F3F0682250B6CF8331B7EE68FD8': 9659365}`; `"1e4c…:1"` (küçük harf), `"XYZ:1"`, `"<html>"`, `"…:abc"` → `FormatException`.
  - `sızanParolaSayısı`: sahte kaynak `5BAA6` için `password`'ün sonekini 10 sayısıyla döndürür → `countFor('password') == 10`, aynı önekte olmayan sağlam parola için `0`, hiç verilmemiş parola için `null`.
  - `aynıParolaBirKezSorulur`: aynı parola üç kayıtta → kaynak tek çağrı.
  - `çöpVeBoşParolaAtlanır`: çöp kutusundaki ve parolası boş kayıt için çağrı yok, `checked` içinde değil.
  - `yüzlerceParola`: 300 farklı parola, kapılı sahte kaynak → aynı anda en çok 4 çağrı, `onProgress` son çağrısı `(n, n)` (n = farklı önek sayısı).
  - `birKezYenidenDener`: bir önek ilk seferde hata, ikincide başarılı → sonuç; iki kez hata → `PwnedPasswordsException`.
  - `htmlYanıtHata`: kaynak `<html>…` döndürür → `FormatException` (sonuç dönmez).
  - `iptal`: ilk yanıttan sonra `isCancelled` true → `BreachCheckCancelled`, sonra yeni çağrı yok.
  - `sızanlarSırası`: `leakedLogins` sayı azalan, eşitse ada göre; çöpteki kayıt yok.
- [ ] **Adım 2:** `flutter test test/features/vault/breach_check_test.dart` → düşer.
- [ ] **Adım 3:** Uygula. Önekler `random` ile karıştırılır; en çok `concurrency` iş çalıştıran bir kuyruk; her önek için `fetchRange` hata verirse bir kez daha.
- [ ] **Adım 4:** Test geçer.
- [ ] **Adım 5:** commit `özellik(kasa): parolaları Have I Been Pwned'da k-anonimlikle denetle`.

### Task 3: Raporda sızıntı kontrolü bölümü

**Dosyalar:**
- Oluştur: `lib/features/vault/application/breach_check_controller.dart`
- Değiştir: `lib/features/vault/presentation/password_report_screen.dart`, `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`
- Test: `test/features/vault/password_report_screen_test.dart` (yeni `group('sızıntı')`), erişilebilirlik testi

**Arayüzler:**
- Tüketir: `BreachChecker`, `BreachResult`, `leakedLogins`, `pwnedRangeSourceProvider`, `loginsControllerProvider`.
- Üretir: `sealed class BreachCheckState` (`BreachIdle`, `BreachRunning(done, total)`, `BreachDone(result)`, `BreachFailed`); `breachCheckProvider` (`NotifierProvider.autoDispose`); `BreachCheckController.start()`. Kasa kilitlenince (kayıt listesi `LoginsLoaded` değilse) durum `BreachIdle` olur ve süren denetim iptal edilir.
- Metinler (TR; EN karşılıkları açıklamalarıyla): `breachTitle` "Sızıntı kontrolü", `breachIntro` (tasarımdaki metin), `breachSource` "Veri: Have I Been Pwned (CC BY 4.0)", `breachCheck` "İnternetten denetle", `breachProgress` "{done} / {total} önek", `breachFailed` "Denetlenemedi. İnternet bağlantını kontrol et.", `breachRetry` "Yeniden dene", `breachClean` "Sızıntılarda görülen parola yok.", `breachRecheck` "Yeniden denetle", `breachFoundTitle` "{count, plural, other{Sızıntılarda görülen parolalar ({count})}}", `breachSeen` "Sızıntılarda {count} kez görüldü" (`count` dile göre biçimlenmiş metin), `breachFoundHint` (tasarımdaki metin); `reportInfo` yeni metin.

- [ ] **Adım 1: Başarısız widget testleri yaz** (`extraOverrides` ile sahte `pwnedRangeSourceProvider`):
  - `açıklamaVeDüğme`: rapor açılınca `breachIntro`, kaynak satırı ve "İnternetten denetle" görünür; kaynağa hiç çağrı yok.
  - `sızanParolalarListelenir`: ortak parola 1234 kez → "Sızıntılarda görülen parolalar (2)", "Posta" ve "Forum" satırlarında "Sızıntılarda 1.234 kez görüldü"; çöpteki "Eski Oyun" yok. İngilizcede "Seen 1,234 times in breaches".
  - `temizSonuç`: yalnızca dolgu → "Sızıntılarda görülen parola yok." ve "Yeniden denetle".
  - `hataVeYenidenDene`: kaynak hata → "Denetlenemedi…"; "Yeniden dene" ile sahte kaynak düzelince sonuç.
  - `htmlYanıtTemizDemez`: kaynak `<html>` → hata metni, "Sızıntılarda görülen parola yok." yok.
  - `kilitlenincSıfırlanır`: denetim sürerken kasa kilitlenir → çökme yok; yeniden açılınca düğme, sonuç yok; kaynağa yeni çağrı gitmemiş.
  - `parolasıDeğişenKayıtDüşer`: sonuçtan sonra "Posta"nın parolası depoda değişir → listede yalnızca "Forum".
  - `parolaYoksaDüğmeKapalı`: kasada parolalı etkin kayıt yok → açıklama görünür, düğme kapalı.
  - Erişilebilirlik testine denetim sonrası durum eklenir (iki tema, iki yazı boyutu).
- [ ] **Adım 2:** testler düşer.
- [ ] **Adım 3:** Denetleyici ve bölümü yaz (kart, ilerleme, hata, temiz, liste; atıf `openWebPage` ile `https://haveibeenpwned.com/Passwords`). Sayı `NumberFormat.decimalPattern(locale)` ile.
- [ ] **Adım 4:** `flutter gen-l10n` (ya da derleme), testler geçer; `flutter analyze` temiz.
- [ ] **Adım 5:** commit `özellik(kasa): parola raporunda sızıntı kontrolü`.

### Task 4: Android izni, şifresiz trafik ve APK denetimi

**Dosyalar:**
- Değiştir: `android/app/src/main/AndroidManifest.xml`, `resources/scripts/check-release-apk.sh`
- Oluştur: `android/app/src/main/res/xml/network_security_config.xml`, `integration_test/breach_test.dart`

- [ ] **Adım 1:** Entegrasyon testini yaz: gerçek istemciyle `BreachChecker` → `countFor('password')` > 0; Flutter'ın `HttpClient`'ıyla `http://example.com` isteği "Insecure HTTP" hatasıyla reddedilir.
- [ ] **Adım 2:** Manifest: `INTERNET`; `<application android:usesCleartextTraffic="false" android:networkSecurityConfig="@xml/network_security_config">`. Yapılandırma: `<base-config cleartextTrafficPermitted="false"><trust-anchors><certificates src="system"/></trust-anchors></base-config>`.
- [ ] **Adım 3:** Betik: `INTERNET` izin listesine gerekçesiyle; `aapt2 dump xmltree --file AndroidManifest.xml` çıktısında `usesCleartextTraffic` false ve `networkSecurityConfig` yoksa hata. Yerelde sürüm APK'sına karşı çalıştırılır (yerelde derlenemezse CI'da).
- [ ] **Adım 4:** Entegrasyon testi Android 17 emülatöründe geçer.
- [ ] **Adım 5:** commit `özellik(android): internet izni, şifresiz trafik kapalı`.

### Task 5: Metinler, koşullar sürüm 2, gizlilik

**Dosyalar:** `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`, `lib/features/onboarding/data/terms_acceptance.dart`, `resources/docs/kosullar.md`, `resources/docs/terms.md`, `resources/docs/gizlilik.md`, `resources/docs/privacy.md`, `README.md`, `fastlane/metadata/android/*/full_description.txt`, `fastlane/metadata/android/en-US/short_description.txt`, `resources/f-droid/io.github.aaudraa.keykey.yml`, `resources/docs/f-droid.md`, `resources/docs/bagimliliklar.md`
- Test: `test/l10n/offline_claims_test.dart`, mevcut `terms_docs_test.dart`, `terms_test.dart`

- [ ] **Adım 1:** Başarısız test: arb, README, fastlane ve gizlilik/koşul belgelerinde "internet izni yok", "İnternet izni yok", "internete çıkmaz", "internete bağlanmadığı", "internete çıkmadığı", "no internet permission", "never goes online", "works without the internet" geçmez. Koşullar sürümü 2 bekleyen testler (`terms_docs_test` belge sürümünü `currentTermsVersion`'la karşılaştırıyor).
- [ ] **Adım 2:** test düşer.
- [ ] **Adım 3:** Metinleri tasarımın "Metinler" bölümüne göre değiştir; `currentTermsVersion = 2`; koşul belgeleri "Sürüm: 2", tarih 2026-11-20; gizlilik bildiriminde İzinler tablosuna İnternet satırı, "Sızıntı kontrolü" bölümü, mağaza formu yanıtları; F-Droid tarifine `AntiFeatures: NonFreeNet` (en-US açıklamasıyla).
- [ ] **Adım 4:** `flutter test` (bütün takım; koşul ekranı testleri yeni sürümle), `python resources/scripts/check-fastlane.py`.
- [ ] **Adım 5:** commit `belge(internet): koşullar sürüm 2, gizlilik ve metinler`.

### Task 6: Cihaz denemeleri

- [ ] **Adım 1:** Hata ayıklama APK'sı, Android 17 emülatörü; 1.5.0 koşulları kabul edilmiş kasanın üstüne kur → koşullar yeniden sorulur.
- [ ] **Adım 2:** `password` parolalı bir kayıtla raporda "İnternetten denetle": gerçek sonuç ve sayı; uçak modunda hata ve yeniden dene.
- [ ] **Adım 3:** Kayıt taraması (deneme parolaları; `5BAA6` öneki ve tam özet kayıtta olmamalı).
- [ ] **Adım 4:** Bütün entegrasyon testleri Android 17 ve 11'de; Android 11'de rapor denetimi.
- [ ] **Adım 5:** Bulgular kayıt defterine; gerekiyorsa düzeltmeler önce testle.

### Task 7: Belgeler ve sürüm

**Dosyalar:** `resources/docs/guvenlik-tasarimi.md`, `resources/docs/security-summary.md`, `resources/docs/guvenlik-denetimi.md`, `resources/docs/kullanim.md`, `resources/CHANGELOG.md`, `fastlane/metadata/android/*/changelogs/10.txt`, `resources/yol-haritasi.md`, `pubspec.yaml`

- [ ] **Adım 1:** Güvenlik tasarımı: tehdit modelinde ağdaki saldırgan ve Have I Been Pwned; "Sızıntı kontrolü" bölümü; bilinen sınırlar (IP, önek kümesi, "görülmedi ≠ güvenli"); otomatik doldurmanın ağa çıkmadığı. Denetim: MASVS-NETWORK, cihaz sonuçları.
- [ ] **Adım 2:** Kılavuz, İngilizce özet, değişiklik günlüğü (1.6.0, **Önemli:** internet izni ve koşulların yeniden sorulması), mağaza sürüm notu, yol haritası Faz 16 bölümü, `version: 1.6.0+10`.
- [ ] **Adım 3:** commit `belge(internet): güvenlik belgeleri, kılavuz, sürüm 1.6.0`.

### Task 8: Son gözden geçirme ve yayın

- [ ] **Adım 1:** Taze bir gözden geçirici bütün dalı tasarım ve bu planla karşılaştırır; bulgular doğrulanıp test önce düzeltilir.
- [ ] **Adım 2:** Bütün kontroller ve entegrasyon testleri; PR, CI yeşil, birleştirme (`gh pr merge --merge --author-email …`); `v1.6.0` etiketi, yayın.

# Uygulama ve site eşleştirme: uygulama planı

> **Ajanlar için:** Bu plan görev görev uygulanır (superpowers:executing-plans). Adımlar `- [ ]` ile izlenir.

**Amaç:** Tarayıcı olmayan bir uygulamada, kayda bağlı olmasa bile, uygulamanın doğrulanmış sitesini taşıyan kayıt eşleşsin; doldurulunca uygulama kayda kendiliğinden bağlansın.

**Mimari:** Kotlin, Android 12+ `DomainVerificationManager`'dan uygulamanın alan adlarını ve doğrulanma durumlarını verir. Dart'ta saf işlevler doğrulanmış siteleri, internet adaylarını ve `assetlinks.json` kararını üretir; `matchLogins` yeni `verifiedSite` türünü tanır. `autofillMatchesProvider` bunları birleştirir; ağ yalnızca ayar açıkken, yeni `asset_links_client.dart` ile.

**Teknoloji:** Flutter/Dart, Riverpod, Pigeon 30, Kotlin.

**Tasarım:** [uygulama-site-eslestirme.md](uygulama-site-eslestirme.md). Uygulayan ikisini birlikte okur.

**Dal:** `faz/25-uygulama-site`. Hedef sürüm `1.10.0`. Takip: [#178](https://github.com/aaudraa/KeyKey/issues/178).

## Genel kısıtlar

- Yalnızca `DOMAIN_STATE_VERIFIED` doğrulanmış sayılır; `SELECTED` sayılmaz.
- Kabul edilen ilişkiler: `delegate_permission/common.get_login_creds`, `delegate_permission/common.handle_all_urls`; `namespace` `android_app`.
- İnternet: en fazla 4 site, toplam bekleme 5 sn, bağlanma 3 sn, gövde en fazla 128 KiB, yönlendirme yok, `User-Agent: KeyKey`, yalnızca `https` (testte yalnızca yerel sunucuya `http`).
- Ayar `autofillVerifySites`, varsayılan kapalı, `AppSettings` sürüm 8; okunamazsa kapalı.
- İmza tutmuyor her zaman kazanır: `signatureMismatches`teki kayıt `verifiedSite` olmaz.
- Metinler Türkçe ve İngilizce (`app_tr.arb`, `app_en.arb`); kod adları İngilizce.
- Pigeon: `dart run pigeon --input pigeons/platform_api.dart`, ardından `dart format lib/core/platform/platform_api.g.dart`.
- Her görev sonunda: `dart format --output=none --set-exit-if-changed lib test integration_test`, `flutter analyze`, ilgili testler.

## Gözden geçirmede bakılacaklar

1. Aynı sitede iki kayıt (iki hesap): ikisi de `verifiedSite`, liste açılır, seçilen bağlanır; ötekine sonraki doldurmada yeniden ağa çıkılmaz (önbellek), çünkü ekran kapanır. Test: Görev 5.
2. Kayıt adresi şemasız ya da `androidapp://` ise: bugünkü `DomainName.hostOfUrl` kuralı; `androidapp://` alan adı vermez, eşleşmez. Test: Görev 2.
3. Bağlamadan sonra sağlayıcı yeniden hesaplanır (`loginsControllerProvider` değişir): ağa yeniden çıkılmamalı. Test: Görev 5.
4. Ağ hatası, zaman aşımı, bozuk JSON: ekran normal listeye düşer, hata göstermez. Test: Görev 3 ve 5.
5. Uygulama hem bağlı (imzası tutan) hem doğrulanmış sitede: tür `app` kalır, kayıt iki kez listelenmez. Test: Görev 2.

---

### Görev 1: Kotlin'den uygulamanın alan adları

**Dosyalar:**
- Oluştur: `android/app/src/main/kotlin/io/github/aaudraa/keykey/autofill/AppDomains.kt`
- Değiştir: `pigeons/platform_api.dart` (`AutofillApi`), `lib/core/platform/platform_api.g.dart` ve `PlatformApi.g.kt` (üretilir), `AutofillActivity.kt` (uygulaması), `lib/features/autofill/application/autofill_bridge.dart` (arayüz ve Pigeon uygulaması), `test/features/autofill/autofill_screens_test.dart` (`FakeAutofillBridge`)
- Test: `android/app/src/test/kotlin/io/github/aaudraa/keykey/autofill/AppDomainsTest.kt`

**Arayüzler:**
- Üretir (Pigeon): `class AppDomain { String host; bool verified; }`, `AutofillApi.appDomains(String packageName) -> List<AppDomain>`.
- Üretir (Dart): `AutofillBridge.appDomains(String packageName) -> Future<List<AppDomain>>`.
- Üretir (Kotlin): `object AppDomains { fun of(context: Context, packageName: String): List<AppDomain>; internal fun fromStates(states: Map<String, Int>): List<Pair<String, Boolean>> }`.

- [ ] **Adım 1:** `AppDomainsTest`: `fromStates(mapOf("GitHub.com" to VERIFIED, "*.github.io" to NONE, "x.com" to SELECTED))` → `[("github.com", true), ("*.github.io", false), ("x.com", false)]` (küçük harf, sıralı); boş harita → boş.
- [ ] **Adım 2:** `./gradlew :app:testDebugUnitTest --tests '*AppDomainsTest*'` → derlenmez (FAIL).
- [ ] **Adım 3:** `AppDomains` yaz. `of`: API < 31 → boş; `context.getSystemService(DomainVerificationManager::class.java).getDomainVerificationUserState(pkg)`; `null`, `NameNotFoundException` ve `SecurityException` → boş; yoksa `fromStates(state.hostToStateMap)`. Sabitler `DomainVerificationUserState.DOMAIN_STATE_*`.
- [ ] **Adım 4:** Pigeon tanımı + üretim; `AutofillActivity` `appDomains`'i `AppDomains.of(this, packageName)` ile uygular; Dart köprüsü ve sahte köprü (`domains` alanı, varsayılan boş).
- [ ] **Adım 5:** Kotlin testi PASS; `flutter analyze` temiz; `flutter test test/features/autofill` PASS.
- [ ] **Adım 6:** Commit `özellik(otomatik-doldurma): uygulamanın alan adları ve doğrulama durumu (#178)`.

### Görev 2: Doğrulanmış site eşleşmesi

**Dosyalar:**
- Oluştur: `lib/features/autofill/domain/app_sites.dart`
- Değiştir: `lib/features/autofill/domain/login_matcher.dart`
- Test: `test/features/autofill/app_sites_test.dart`, `test/features/autofill/domain_matching_test.dart`

**Arayüzler:**
- Tüketir: `AppDomain` (Görev 1), `PublicSuffixList.registrableDomain`, `DomainName.normalize`, `DomainName.hostOfUrl`.
- Üretir:
  - `Set<String> verifiedSites(Iterable<AppDomain> domains, PublicSuffixList suffixes)`: `verified` olanların joker atılmış kayıt edilebilir alan adları.
  - `String? siteFromPackageName(String packageName, PublicSuffixList suffixes)`: parçalar ters, TLD'den başlayıp `registrableDomain(x) == x` olan ilk önek.
  - `LoginMatchKind.verifiedSite` (`app` ile `exactHost` arasında).
  - `matchLogins(..., Set<String> verifiedSites = const {})`: uygulama hedefinde, hedef pakete bağlı olmayan kayıtta adreslerden birinin kayıt edilebilir alan adı kümedeyse `verifiedSite`. Küme boş değilse `suffixes` gerekir.
  - `LoginMatchKind? LoginMatches.kindOf(LoginItem item)`.

- [ ] **Adım 1:** Testler (`app_sites_test.dart`): `verifiedSites` → `login.github.com` doğrulanmış → `{github.com}`; `*.ornek.com` doğrulanmış → `{ornek.com}`; `*.github.io` (kamu soneki) → `{}`; doğrulanmamış atılır; `siteFromPackageName('com.github.android')` → `github.com`, `'tr.com.garanti.cep'` → `garanti.com.tr`, `'com.google.android.apps.foo'` → `google.com`, `'tek'` → `null`, `'com'` → `null`.
- [ ] **Adım 2:** Testler (`domain_matching_test.dart`): bağlı olmayan `https://github.com/login` kaydı `{github.com}` ile `verifiedSite`; `giris.github.com` de; `gitlab.com` eşleşmez; `androidapp://com.github.android` eşleşmez; aynı pakete imzası tutan bağlı kayıt `app` kalır ve bir kez listelenir; imzası tutmayan bağlı kayıt `signatureMismatches`te kalır, `verifiedSite` olmaz; sıralama `app` < `verifiedSite`; web hedefinde `verifiedSites` yok sayılır.
- [ ] **Adım 3:** `flutter test test/features/autofill/app_sites_test.dart test/features/autofill/domain_matching_test.dart` → FAIL.
- [ ] **Adım 4:** Uygula.
- [ ] **Adım 5:** Testler PASS; `fill_warnings_test.dart` de PASS (kesin eşleşme kuralı değişmeden `verifiedSite`i kapsar, çünkü `matches.matches` içindedir).
- [ ] **Adım 6:** Commit `özellik(otomatik-doldurma): doğrulanmış site eşleşmesi (#178)`.

### Görev 3: `assetlinks.json` istemcisi ve kararı

**Dosyalar:**
- Oluştur: `lib/core/network/asset_links_client.dart`, `lib/features/autofill/domain/asset_links.dart`
- Değiştir: `test/core/network/network_audit_test.dart` (`_allowed`'a ekle, test adları "üç dosya")
- Test: `test/core/network/asset_links_client_test.dart`, `test/features/autofill/asset_links_test.dart`

**Arayüzler:**
- Üretir:
  - `abstract interface class AssetLinksSource { Future<String?> fetch(String host); }` (hata, zaman aşımı, 200 dışı, büyük gövde → `null`).
  - `final class AssetLinksClient implements AssetLinksSource` — `new({Uri Function(String host)? locate, Duration connectTimeout = 3 sn, Duration requestTimeout = 5 sn})`; varsayılan adres `https://$host/.well-known/assetlinks.json`; adres `isSecureServiceUrl` ile denetlenir; host `DomainName.normalize` ile aynı olmalı, IP adresi ve `:` içeren reddedilir (ağa çıkmadan `null`). `maxResponseBytes = 128 * 1024`. `followRedirects = false`.
  - `final assetLinksSourceProvider = Provider<AssetLinksSource>`.
  - `List<String> assetLinkFingerprints(String json, String packageName)`: kabul edilen ilişkilerden biri ve `android_app` + paket adı tutan ifadelerin özetleri, küçük harf ve ayraçsız 64 hane; bozuk JSON ya da dizi olmayan kök → boş.

- [ ] **Adım 1:** `asset_links_test.dart`: `get_login_creds` ifadesi → özet döner (`'AB:CD:…'` → `'abcd…'`); `handle_all_urls` da; başka ilişki → boş; başka paket → boş; `web` namespace → boş; 63 haneli özet atılır; `'{}'`, `'['`, `'null'` → boş.
- [ ] **Adım 2:** `asset_links_client_test.dart` (yerel `HttpServer`, `locate: (h) => Uri.parse('http://127.0.0.1:$port/...')`): 200 gövde döner; 301 → `null` ve hedefe istek gitmez; 404 → `null`; 129 KiB → `null`; geciken yanıt kısa zaman aşımıyla `null`; `User-Agent` `KeyKey`; `fetch('1.2.3.4')` ve `fetch('a.com:8443')` sunucuya istek atmadan `null`; varsayılan `locate` `http` değil `https` üretir.
- [ ] **Adım 3:** Testler FAIL.
- [ ] **Adım 4:** Uygula; `PwnedPasswordsClient`'ın kalıbı (çerez yok, gövde sınırı akarken sayılır).
- [ ] **Adım 5:** Bu testler ve `network_audit_test.dart` PASS.
- [ ] **Adım 6:** Commit `özellik(ağ): assetlinks.json istemcisi (#178)`.

### Görev 4: Ayar

**Dosyalar:**
- Değiştir: `lib/features/settings/data/app_settings.dart`, `lib/features/settings/application/settings_controller.dart`, `lib/features/settings/presentation/settings_screen.dart` (`AutofillSetupSection`'a ikinci `KkSwitchTile`), `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`, güvenlik tasarımındaki ayar biçimi
- Test: mevcut ayar testleri (`test/features/settings/` altında `AppSettings` biçim testi), ayar ekranı testi

**Arayüzler:**
- Üretir: `AppSettings.autofillVerifySites` (bool, varsayılan `false`, `copyWith`), `currentVersion = 8`, `SettingsController.setAutofillVerifySites({required bool value})`, metinler `settingsAutofillVerifySites` ("Uygulamanın sitesini internetten doğrula" / "Verify the app's website online") ve `settingsAutofillVerifySitesHelp` (tasarımdaki açıklama).

- [ ] **Adım 1:** Testler: sürüm 8 gidiş-dönüş; sürüm 7 okunur ve `false`; değer bool değilse kayıt reddedilir (diğer alanlarla aynı katılık); `requireAuth` ve `defaults`ta `false`; ekranda anahtar görünür ve dokununca kaydedilir.
- [ ] **Adım 2:** FAIL.
- [ ] **Adım 3:** Uygula; simge `Icons.travel_explore_rounded`.
- [ ] **Adım 4:** PASS; `flutter gen-l10n` sonrası analiz temiz.
- [ ] **Adım 5:** Commit `özellik(ayarlar): uygulamanın sitesini internetten doğrulama ayarı (#178)`.

### Görev 5: Birleştirme, doldurma ekranı ve kendiliğinden bağlama

**Dosyalar:**
- Oluştur: `lib/features/autofill/application/app_site_check.dart`
- Değiştir: `lib/features/autofill/application/autofill_matches.dart`, `lib/features/autofill/presentation/autofill_pick_screen.dart`, arb dosyaları
- Test: `test/features/autofill/app_site_check_test.dart`, `test/features/autofill/autofill_screens_test.dart`

**Arayüzler:**
- Tüketir: Görev 1-4'ün hepsi; `SignatureCheck`.
- Üretir:
  - `Future<Set<String>> checkSitesOnline({required String packageName, required List<String> certsSha256, required List<String> hosts, required AssetLinksSource source, required SignatureCheck hasSigningCertificates, Duration budget = const Duration(seconds: 5)})`: adayları birlikte sorar, süre dolunca biteni döndürür; tek imzacıda özetlerden biri `hasSigningCertificates(pkg, [özet])` ile tutarsa, çok imzacıda `certsSha256` listede tümüyle varsa sitenin kayıt edilebilir alan adı kümeye girer.
  - `List<String> onlineCandidates({required String packageName, required Iterable<AppDomain> domains, required Iterable<LoginItem> unmatched, required PublicSuffixList suffixes})`: doğrulanmamış alan adları (joker atılmış) + `siteFromPackageName`; kayıt edilebilir alan adı `unmatched` kayıtlardan birinin adresiyle aynı olanlar; site başına bir; alfabetik; en fazla 4.
  - `final siteCheckCacheProvider` (Notifier, `Map<String, bool>` host → sonuç; ekran ömrünce).
  - `final siteCheckInProgressProvider` (Notifier<bool>).
  - Metin `autofillVerifyingSite` ("Uygulamanın sitesi doğrulanıyor" / "Verifying the app's website").

- [ ] **Adım 1:** `app_site_check_test.dart`: aday üretimi (süzme, site başına bir, 4 sınırı, joker, kayıt yoksa boş); `checkSitesOnline` tek imzacı tutar/tutmaz, çok imzacı alt küme, kaynak `null` → boş, süre dolunca yanıt vermeyen düşer ve diğeri kalır.
- [ ] **Adım 2:** `autofill_screens_test.dart`: sahte köprüde `github.com` doğrulanmış, tek `github.com` kaydı → liste açılmadan doldurulur ve kayıt `apps`'e uygulamayı ekler; iki kayıt → liste, seçilen bağlanır, uyarı yok; ayar kapalı → sahte kaynak hiç çağrılmaz; ayar açık, doğrulanmamış alan adı, kaynak tutan dosya döner → eşleşir; kaynak `null` → "Eşleşme yok" uyarısı; bağlamadan sonra kaynak ikinci kez çağrılmaz; sorgu sürerken `autofillVerifyingSite` görünür; imzası tutmayan bağlı kayıt doğrulanmış sitede de "sahte olabilir" uyarısı verir.
- [ ] **Adım 3:** FAIL.
- [ ] **Adım 4:** `autofillMatchesProvider`: hedef uygulama (`!isWeb`) ve `certsSha256` doluysa `appDomains` al; alan adı varsa ya da ayar açıksa PSL yükle; `verifiedSites` ile eşleştir; ayar açıksa (`settingsRepositoryFactoryProvider` ile okunur, hata → kapalı) eşleşmeyen ve imzası tutmuyor olmayan kayıtlar için adayları üret, önbellekte olmayanları `checkSitesOnline` ile sor (sürerken `siteCheckInProgressProvider` true), sonuçları önbelleğe yaz, eklenen sitelerle yeniden eşleştir.
- [ ] **Adım 5:** Ekran: yükleniyor görünümünün altına `siteCheckInProgressProvider` true iken metin; `_pick` ve doğrudan doldurmada seçilen kaydın türü `verifiedSite` ise `_fill`den önce `_bindApp`.
- [ ] **Adım 6:** PASS; bütün `flutter test` PASS.
- [ ] **Adım 7:** Commit `özellik(otomatik-doldurma): uygulamanın sitesi doğrulanınca eşleşme ve bağlama (#178)`.

### Görev 6: Belgeler, cihaz denemesi, sürüm

**Dosyalar:** `resources/docs/guvenlik-tasarimi.md` (Eşleştirme, Şüpheli durumlar, tehdit modeli satırı, ayar biçimi sürüm 8, Ağ bölümünde üçüncü dosya), `gizlilik.md`, `privacy.md`, `kullanim.md`, `resources/yol-haritasi.md`, `pubspec.yaml` (`1.10.0`), sürüm notu yeri yol haritasının gösterdiği yer.

- [ ] **Adım 1:** Belgeleri güncelle.
- [ ] **Adım 2:** Emülatör (API 34 ya da 36): Wikipedia uygulaması kurulu, `adb shell pm get-app-links org.wikipedia` doğrulanmış alan adını gösteriyor; `wikipedia.org` kaydı; gerçek yol: uygulamanın giriş kutusu → "KeyKey ile doldur" → kilit aç → doğrudan doldurma ve kayıtta bağlı uygulama. Ayar açıkken doğrulanmamış bir alan adıyla internet yolu da denenir (uygun uygulama bulunursa). Sonuç güvenlik denetimi belgesine.
- [ ] **Adım 3:** Bütün kontroller; integration testleri emülatörde.
- [ ] **Adım 4:** Commit, PR, CI yeşil, birleştir, etiket, yayın.

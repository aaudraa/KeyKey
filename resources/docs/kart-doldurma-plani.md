# Kart doldurma: uygulama planı

> **Uygulayan için:** Bu plan görev görev uygulanır (superpowers:executing-plans). Adımlar `- [ ]` ile işaretlenir.

**Amaç:** Doldurma servisinin ödeme formlarındaki kart alanlarını tanıması ve seçilen kartla doldurması.

**Mimari:** Kart alanlarını Kotlin'de yeni `CardClassifier` tanır; `FormParser` ödeme formu kuralını uygular ve kart alanlarını giriş tanımadan ayırır. Servis ayrı bir kilitli kart önerisi kurar. Flutter'daki doldurma ekranı kart isteğinde kart listesini açar, seçilen kartın değerlerini `fillCard` ile Kotlin'e verir. Kotlin her alan için değeri `CardFill` ile biçimler.

**Teknoloji:** Kotlin (Android autofill çerçevesi, JUnit), Flutter, Riverpod 3, Pigeon 30.

**Tasarım:** [`kart-doldurma.md`](kart-doldurma.md). Plan tasarımdan yola çıkar; uygulayan ikisini birlikte okur.

## Genel kurallar

- Commit biçimi `<tür>(<alan>): <açıklama>`, Türkçe; her commit `Refs #149` taşır. Commit'ten önce gitleaks (`--pre-commit --staged`), çıkış kodu 0 değilse commit yok.
- Kod adları İngilizce, yorumlar Türkçe. Arayüz metinleri `app_tr.arb` ve `app_en.arb`'ye birlikte girer, ardından `flutter gen-l10n`. Android metinleri `values/strings.xml` ve `values-tr/strings.xml`'e birlikte girer.
- Pigeon: `dart run pigeon --input pigeons/platform_api.dart`, ardından `dart format lib/core/platform/platform_api.g.dart`.
- Kotlin testleri: `cd android && ./gradlew :app:testDebugUnitTest`.
- Her görevin sonunda: `dart format --output=none --set-exit-if-changed lib test integration_test`, `flutter analyze`, ilgili testler.
- Kart değerleri (numara, güvenlik kodu, son kullanma) günlüğe, istisna mesajına, `toString`'e, niyete ya da bildirime girmez. PIN köprüden geçmez.
- Sürüm `1.5.0+9`.

## Gözden geçirmede bakılacaklar

Tasarımın açıkça söylemediği ama kullanıcıyı yakabilecek durumlar; her birinin testi sahibi olan göreve eklendi:

1. **Hem giriş hem kart alanı olan form** (misafir alışverişi: e-posta, parola, kart). Giriş önerisi kart kutularını, kart önerisi giriş kutularını kapsamamalı (Görev 1).
2. **Açılır ay listesinin ilk seçeneği "Ay" ya da "Month"**. Seçilen sıra numarası bu boş seçeneği de saymalı; Aralık için 12. sıra seçilmeli, 11. değil (Görev 2).
3. **Ay adları büyük harfle ve Türkçe harflerle** ("ŞUBAT", "AĞU", "NİSAN", "Eyl"). Eşleşmeli (Görev 2).
4. **Kartta son kullanma yok ya da güvenlik kodu boş.** O alanlar boş kalmalı, diğerleri dolmalı; hiçbir alan dolmuyorsa ekran sessizce kapanmalı (Görev 2 ve 3).
5. **Kart isteğiyle açılan ekrana giriş çağrısı gelir, ya da tersi.** Kotlin hiçbir şey doldurmadan kapatmalı (Görev 3).

---

## Dosya düzeni

| Dosya | Sorumluluk |
|---|---|
| `android/.../autofill/FieldClassifier.kt` | `FieldKind`'a kart türleri, `FieldInfo`'ya `options` ve `maxLength`, `FormParser`'da ödeme formu kuralı, `ParsedForm.hasCard` |
| `android/.../autofill/CardClassifier.kt` (yeni) | Tek bir alanın kart türü ve kanıtın gücü |
| `android/.../autofill/CardFill.kt` (yeni) | Kart değerlerinin alan türüne göre biçimlenmesi |
| `android/.../autofill/StructureParser.kt` | Seçenekleri ve uzunluk sınırını okumak; `cardIds` |
| `android/.../autofill/KeyKeyAutofillService.kt` | İki kilitli öneri |
| `android/.../autofill/AutofillActivity.kt`, `AutofillRequests.kt` | İsteğin türü, `fillCard` |
| `pigeons/platform_api.dart` | `forCard`, `CardFillValues`, `fillCard` |
| `lib/features/autofill/application/autofill_bridge.dart` | `AutofillTarget.forCard`, `AutofillCard`, `AutofillBridge.fillCard` |
| `lib/features/autofill/presentation/autofill_card_pick_screen.dart` (yeni) | Kart listesi, arama, http uyarısı, doldurma |
| `lib/features/autofill/presentation/autofill_app.dart` | Kart isteğinde kilit alt başlığı ve kart ekranı |
| `resources/test-apps/ornek-giris/` | Üç kart formu |

---

### Task 1: Kart alanlarını tanımak

**Dosyalar:**
- Oluştur: `android/app/src/main/kotlin/io/github/aaudraa/keykey/autofill/CardClassifier.kt`
- Değiştir: `android/app/src/main/kotlin/io/github/aaudraa/keykey/autofill/FieldClassifier.kt`
- Test: `android/app/src/test/kotlin/io/github/aaudraa/keykey/autofill/CardClassifierTest.kt` (yeni), `FieldClassifierTest.kt`

**Arayüzler:**
- Üretir:
  - `enum class FieldKind { USERNAME, PASSWORD, NEW_PASSWORD, OTP, CARD_NUMBER, CARD_HOLDER, CARD_HOLDER_GIVEN, CARD_HOLDER_FAMILY, CARD_EXPIRY, CARD_EXP_MONTH, CARD_EXP_YEAR, CARD_SECURITY_CODE }` ve `val FieldKind.isCard: Boolean`.
  - `FieldInfo`'ya `options: List<String> = emptyList()` ve `maxLength: Int = 0` (0: bilinmiyor).
  - `data class CardGuess(val kind: FieldKind, val strong: Boolean)`; `object CardClassifier { fun classify(field: FieldInfo): CardGuess? }`.
  - `ParsedForm.hasCard: Boolean`; `hasCredentials` değişmez.
- `FieldClassifier.classify` (giriş tanıma) değişmez.

- [ ] **Adım 1: Başarısız testleri yaz.** `CardClassifierTest`:
  - `androidIpuçlarıGüçlü`: `creditCardNumber` → `CardGuess(CARD_NUMBER, true)`; `creditCardSecurityCode` → `CARD_SECURITY_CODE`; `creditCardExpirationDate` → `CARD_EXPIRY`; `…Month` → `CARD_EXP_MONTH`; `…Year` → `CARD_EXP_YEAR`; `creditCardExpirationDay` → `null`.
  - `htmlAutocompleteGüçlü`: `cc-number`, `cc-name` → `CARD_HOLDER`, `cc-given-name`, `cc-family-name`, `cc-exp`, `cc-exp-month`, `cc-exp-year`, `cc-csc`; `autocomplete="billing cc-number"` de tanınır.
  - `chromeTahminiGüçlü`: `computed-autofill-hints` = `CREDIT_CARD_VERIFICATION_CODE` olan `type=password` kutusu → `CARD_SECURITY_CODE`; `computed` `UNKNOWN_TYPE` iken `crowdsourcing-autofill-hints` = `CREDIT_CARD_NUMBER` → `CARD_NUMBER`; `ua-autofill-hints` = `CREDIT_CARD_EXP_4_DIGIT_YEAR` → `CARD_EXP_YEAR`.
  - `güvenlikKoduAdlarıGüçlü`: `numberPassword` ve `idEntry = "et_cvv"` → `(CARD_SECURITY_CODE, true)`; `hint = "CVC2"` → güçlü; `label = "CSC"` → güçlü.
  - `sözcüklerZayıf`: `hint = "Kart numarası"` → `(CARD_NUMBER, false)`; `"Son kullanma (AA/YY)"` → `CARD_EXPIRY`; `"MM/YY"` → `CARD_EXPIRY`; `"Kart sahibi"` → `CARD_HOLDER`; `"Güvenlik kodu"` → `(CARD_SECURITY_CODE, false)`; `idEntry = "spinner_month"` → `(CARD_EXP_MONTH, false)`; `hint = "Yıl"` → `CARD_EXP_YEAR`; `hint = "Doğum yılı"` → `null`.
  - `metinOlmayanAlanlar`: `CARD_NUMBER` ipuçlu ama `autofillType = 3` (liste) → `null`; `cc-exp-month` ve `autofillType = 3` → `CARD_EXP_MONTH`; tarih türü (`4`) `CARD_EXPIRY` → kabul; görünmeyen alan → `null`.

  `FieldClassifierTest`'e `FormParser.parse` testleri:
  - `kartNumarasıylaGirişFormuGirişKalır`: `[text, hint "Kart numarası"]`, `[numberPassword, hint "Şifre"]` → `hasCard == false`, `of(USERNAME) == [0]`, `of(PASSWORD) == [1]`.
  - `cvvliFormÖdemeFormu`: `[hint "Kart numarası"]`, `[hint "AA/YY"]`, `[numberPassword, hint "CVV"]` → `of(CARD_NUMBER)==[0]`, `of(CARD_EXPIRY)==[1]`, `of(CARD_SECURITY_CODE)==[2]`, `hasCredentials == false`.
  - `yalnızCvvKutusu`: `[numberPassword, idEntry "cvv"]` → `hasCard`, `!hasCredentials`.
  - `karışıkForm` (Gözden geçirme 1): `[textEmail]`, `[textPassword, idEntry "password"]`, `[creditCardNumber ipucu]`, `[cc-csc]` → `of(USERNAME)==[0]`, `of(PASSWORD)==[1]`, kart türleri 2 ve 3; giriş türlerinde 2 ve 3 yok.
  - `ayVeYılKelimeleriTekBaşınaÖdemeFormuYapmaz`: `[hint "Ay"]`, `[hint "Yıl"]`, `[textPassword]` → `hasCard == false`.
  - `kartSahibiTekBaşınaÖdemeFormuYapmaz`: `[hint "Kart sahibi"]`, `[textPassword]` → `hasCard == false`.
  - Var olan `başkaBirIpucuVarsaTahminEdilmiyor` testi giriş tanıma için geçerli kalır.

- [ ] **Adım 2:** `./gradlew :app:testDebugUnitTest --tests '*CardClassifierTest*' --tests '*FieldClassifierTest*'` → derleme hatasıyla FAIL.
- [ ] **Adım 3: Uygula.** Kanıt sırası tasarımdaki gibi: Android ipucu, `autocomplete`, Chrome tahmini (`computed` → `crowdsourcing` → `ua`; `UNKNOWN_TYPE`, `NO_SERVER_DATA`, `EMPTY_TYPE` ve boş değer atlanır), güvenlik kodu adları, sözcükler. Sözcükler `FieldClassifier.normalize` ile aranır; kaynaklar `idEntry`, `hint`, HTML `name`, `id`, `placeholder`, `label`. "ay"/"yıl" gibi kısa sözcükler alt dize değil, sözcük olarak aranır (`[^a-z0-9ığüşöç]` ile bölünmüş). `FormParser.parse`: önce kart tahminleri; ödeme formu = güçlü kanıt var ya da zayıf kanıtlar {numara, son kullanma (tek kutu, ay, yıl), güvenlik kodu} gruplarından en az ikisini kapsıyor. Ödeme formunda kart tahmini olan alanlar giriş tanımaya girmez ve kullanıcı adı tahmininde aday olmaz; değilse alanlar bugünkü gibi tanınır.
- [ ] **Adım 4:** aynı komut → PASS; ardından bütün `testDebugUnitTest` → PASS.
- [ ] **Adım 5:** commit `özellik(doldurma): ödeme formlarında kart alanlarını tanı`.

### Task 2: Değerleri biçimlemek

**Dosyalar:**
- Oluştur: `android/app/src/main/kotlin/io/github/aaudraa/keykey/autofill/CardFill.kt`
- Test: `android/app/src/test/kotlin/io/github/aaudraa/keykey/autofill/CardFillTest.kt`

**Arayüzler:**
- Tüketir: Görev 1'deki `FieldInfo`, `ParsedForm`, `FieldKind`.
- Üretir:
  - `data class CardValues(val number: String, val cardholder: String, val expMonth: Int?, val expYear: Int?, val securityCode: String)`; `toString` değer göstermez.
  - `sealed interface FillValue { data class Text(val text: String); data class ListIndex(val index: Int); data class Date(val millis: Long) }`.
  - `object CardFill { fun values(fields: List<FieldInfo>, form: ParsedForm, card: CardValues): Map<Int, FillValue> }`; anahtar alanın `fields` içindeki sırası.

- [ ] **Adım 1: Başarısız testleri yaz** (`expYear` dört hane tutulur, örn. 2028):
  - `numaraYalnızRakam`: `CARD_NUMBER` → `Text("4111111111111111")`.
  - `bölünmüşNumara`: dört `CARD_NUMBER` alanı, `maxLength` 4'er → `"4111"`, `"1111"`, `"1111"`, `"1111"`; `maxLength`'i 0 olan bir alan varsa yalnızca ilk alana tam numara.
  - `adVeSoyad`: `"DENEME KİŞİ YILMAZ"` → given `"DENEME KİŞİ"`, family `"YILMAZ"`; tek sözcük `"DENEME"` → given `"DENEME"`, family yazılmaz.
  - `tekKutuSonKullanma`: varsayılan `"12/28"`; `hint "AA/YYYY"` → `"12/2028"`; `maxLength 4` → `"1228"`; `maxLength 7` → `"12/2028"`; `hint "MM-YY"` → `"12-28"`; `computed-autofill-hints = CREDIT_CARD_EXP_DATE_4_DIGIT_YEAR` → `"12/2028"`; ay 3 → `"03/28"`.
  - `ayrıAyVeYılMetin`: ay `"03"`; yıl `"2028"`; yıl `maxLength 2` → `"28"`; yıl `hint "YY"` → `"28"`; `computed = CREDIT_CARD_EXP_2_DIGIT_YEAR` → `"28"`.
  - `listeler` (Gözden geçirme 2 ve 3): `["Ay","01","02",…,"12"]` ve ay 12 → `ListIndex(12)`; `["Ocak","Şubat",…]` ve ay 2 → `1`; `["OCA","ŞUB",…]` → `1`; `["01 - Ocak", …]` → doğru sıra; `["Jan","Feb",…]`; `["NİSAN"]` ay 4 → `0`; yıl `["Yıl","2027","2028"]` → `2`; yıl `["27","28"]` → `1`; eşleşme yoksa alan haritada yok.
  - `tarihAlanı`: `CARD_EXPIRY`, `autofillType 4` → `Date(2028-12-01T12:00Z ms)`.
  - `eksikDeğerler` (Gözden geçirme 4): `expMonth == null` iken son kullanma alanları yok, numara var; güvenlik kodu boşsa `CARD_SECURITY_CODE` yok; kart boşsa harita boş.
- [ ] **Adım 2:** `--tests '*CardFillTest*'` → FAIL.
- [ ] **Adım 3: Uygula.** Ay adları Türkçe ve İngilizce, tam ve üç harfli; karşılaştırma `FieldClassifier.normalize` ile değil, büyük-küçük harf ve Türkçe `İ/I` farkı giderilmiş ilk sözcükle. Tasarımdaki biçim kuralları.
- [ ] **Adım 4:** → PASS, bütün Kotlin testleri PASS.
- [ ] **Adım 5:** commit `özellik(doldurma): kart değerlerini alan türüne göre biçimle`.

### Task 3: Servis, ekran ve köprü

**Dosyalar:**
- Değiştir: `StructureParser.kt`, `KeyKeyAutofillService.kt`, `AutofillActivity.kt`, `AutofillRequests.kt`, `res/values/strings.xml`, `res/values-tr/strings.xml`, `pigeons/platform_api.dart`, `lib/features/autofill/application/autofill_bridge.dart`, `test/features/autofill/autofill_screens_test.dart` (sahte köprü)

**Arayüzler:**
- Tüketir: Görev 1 ve 2.
- Üretir:
  - Pigeon: `AutofillRequestInfo.forCard` (`bool`, zorunlu); `class CardFillValues { String number; String cardholder; int? expMonth; int? expYear; String securityCode; }`; `AutofillApi.fillCard(CardFillValues values, String notice)`.
  - Dart: `AutofillTarget.forCard` (`bool`, varsayılan `false`); `@immutable final class AutofillCard { const new({required number, required cardholder, expMonth, expYear, required securityCode}); factory AutofillCard.of(CardContent content) }`; `AutofillBridge.fillCard({required AutofillCard card, required String notice})`.
  - Kotlin: `AutofillActivity.ACTION_FILL_LOGIN`, `ACTION_FILL_CARD`; `ParsedStructure.cardIds`; `R.string.autofill_fill_card_with_keykey` ("KeyKey ile kart doldur" / "Fill card with KeyKey").

- [ ] **Adım 1:** `AutofillCard.of` için Dart testi (`test/features/autofill/autofill_card_test.dart`): son kullanması olmayan kartta ay ve yıl `null`; PIN'i olan kartın `AutofillCard`'ında PIN alanı yok (sınıfta alan olmadığı derleme ile güvencede; test numara, sahip, ay, yıl ve kodu doğrular). FAIL.
- [ ] **Adım 2: Uygula.**
  - `StructureParser`: `options = node.autofillOptions?.map { it.toString() }`, `maxLength = node.maxTextLength` (≤0 ise HTML `maxlength`), HTML `label` niteliği zaten `htmlAttributes`'ta.
  - Servis: giriş alanı varsa giriş önerisi (`ACTION_FILL_LOGIN`, `credentialIds`), kart alanı varsa kart önerisi (`ACTION_FILL_CARD`, `cardIds`); ikisi de yoksa `null`. Satır içi görünüm: `specs.getOrNull(i) ?: specs.lastOrNull()`. `SaveInfo` değişmez.
  - Ekran: `forCard = intent.action == ACTION_FILL_CARD`; kart isteğinde `hasCard`, giriş isteğinde `hasCredentials` yoksa istek yok. `fill` kart isteğinde, `fillCard` giriş isteğinde `cancel()` (Gözden geçirme 5). `fillCard`: `CardFill.values` boşsa `cancel()`; değilse `Dataset`, bildirim, `RESULT_OK`.
  - Pigeon üret, biçimle; `PigeonAutofillBridge`'e `forCard` ve `fillCard`; sahte köprüye `AutofillCard? card` ve `fillCard` kaydı.
- [ ] **Adım 3:** `flutter analyze`, `flutter test test/features/autofill`, `./gradlew :app:testDebugUnitTest :app:compileDebugKotlin` → PASS.
- [ ] **Adım 4:** commit `özellik(doldurma): kart önerisi ve fillCard köprüsü`.

### Task 4: Kart seçme ekranı

**Dosyalar:**
- Oluştur: `lib/features/autofill/presentation/autofill_card_pick_screen.dart`
- Değiştir: `autofill_app.dart`, `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`
- Test: `test/features/autofill/autofill_screens_test.dart` (yeni `group('kart')`)

**Arayüzler:**
- Tüketir: `cardsControllerProvider` (`RecordsLoaded<CardContent>`), `IndexedEntry`, `filterEntries`, `cardSummary`, `cardTitle`, `AutofillCard.of`, `AutofillBridge.fillCard`, `autofillDoneProvider`, `vaultControllerProvider`.
- Üretir: `AutofillCardPickScreen({required AutofillTarget target})`.
- Yeni metinler (TR / EN):
  - `autofillCardFor`: "{target} için kart" / "Card for {target}"
  - `autofillCardEmpty`: "Kasada henüz kart yok. Kartı KeyKey'de Kasa sekmesinden ekleyebilirsin." / "There are no cards in the vault yet. You can add one in KeyKey's Vault tab."
  - `autofillCardSearch`: "Kart ara" / "Search cards"
  - `autofillWarnInsecureCard`: "Bağlantı şifresiz (http). Kart bilgileri ağda açık gider." / "The connection is not encrypted (http). Card details travel over the network in the clear."
  - `autofillWarnCard`: "Seçilen kart: {name}" / "Selected card: {name}"
  - `autofillCardFilledUnnamed`: "Kart dolduruldu" / "Card filled"

- [ ] **Adım 1: Başarısız testleri yaz** (`forCard: true` hedefle):
  - `kilitliyken alt başlık kart için`: "örnek.com için kart".
  - `kart isteğinde kartlar listeleniyor, parolalar listelenmiyor`.
  - `çöpteki kart listelenmiyor`.
  - `kasada kart yoksa söyleniyor`: `autofillCardEmpty` metni.
  - `arama kart sahibini buluyor, numarayı bulmuyor`: "DENEME" bulur; "4111" bulmaz.
  - `kart seçilince değerler veriliyor ve kasa kilitleniyor`: `bridge.card` numara, sahip, 12, 2028, "123"; `notice == "Örnek kart dolduruldu"`; kasa kilitli; `bridge.filled == null`.
  - `adsız kartın bildiriminde marka ve son dört hane`: "Visa •••• 1111 dolduruldu".
  - `http sayfada önce uyarı, vazgeçilirse doldurulmuyor`; `onaylanırsa dolduruluyor`; geri tuşu uyarıdan listeye döner.
  - `https sayfada ve uygulamada uyarı yok`.
- [ ] **Adım 2:** `flutter test test/features/autofill/autofill_screens_test.dart` → FAIL.
- [ ] **Adım 3: Uygula.** Ekran `AutofillPickScreen`'in çerçevesini ve düzenini izler (`AutofillSheetFrame`, `AutofillSheetHeader`, cam arama kutusu, `KkCard` satırları; satırda kart simgesi, `cardTitle`, `cardSummary`). Arama ve sıralama `filterEntries([IndexedEntry(CardEntry(item))…], LoginFilter(query: …))`. Doldurma sırası `_fill` ile aynı: değerler alınır, `markDone`, `lock`, `fillCard`. `AutofillHome`: kart isteğinde kilit alt başlığı `autofillCardFor`, açıkken `AutofillCardPickScreen`.
- [ ] **Adım 4:** → PASS; bütün `flutter test` PASS; `flutter analyze` temiz.
- [ ] **Adım 5:** commit `özellik(doldurma): doldurma ekranında kart seçimi`.

### Task 5: Örnek uygulama ve cihaz denemeleri

**Dosyalar:**
- Oluştur: `resources/test-apps/ornek-giris/src/main/java/io/github/aaudraa/ornekgiris/CardActivity.java`, `CardWordsActivity.java`, `CardWebActivity.java`
- Değiştir: `resources/test-apps/ornek-giris/src/main/AndroidManifest.xml`, `resources/scripts/deneme-degerleri.txt`

- [ ] **Adım 1:** Üç form, her biri "Öde" düğmesiyle `SONUC` satırı yazar ve `AutofillManager.commit()` çağırır:
  - `CardActivity`: Android ipuçlu numara, sahip ve güvenlik kodu; ay ve yıl için `Spinner` (ilk seçenek "Ay"/"Yıl").
  - `CardWordsActivity`: ipucusuz; "Kart numarası", "AA/YY", gizli rakam "CVV".
  - `CardWebActivity`: WebView'da `autocomplete`'li HTML form; ay ve yıl `select`, `https://odeme.example.com`.
- [ ] **Adım 2:** Android 17 ve Android 11 emülatörlerinde (`-gpu host`, sırayla): kasaya `4111111111111111` numaralı bir kart eklenir; üç formda öneri → kilit → liste → doldurma; `SONUC` satırında değerler; "Öde"den sonra parola kaydetme önerisi çıkmıyor; `MainActivity`'deki giriş formunda giriş doldurma değişmedi. `logcat-scan.sh baslat/tara` ile cihaz kaydı taranır.
- [ ] **Adım 3:** Bulunan her hata için önce JVM ya da widget testi, sonra düzeltme.
- [ ] **Adım 4:** commit `deneme(doldurma): örnek uygulamada kart formları`.

### Task 6: Belgeler ve sürüm

**Dosyalar:** `resources/docs/guvenlik-tasarimi.md`, `resources/docs/kullanim.md`, `resources/CHANGELOG.md`, `resources/yol-haritasi.md`, `resources/docs/security-summary.md`, mağaza açıklamaları (`fastlane/metadata/android/*/full_description.txt`, varsa), `pubspec.yaml`

- [ ] **Adım 1:** Güvenlik tasarımında "Otomatik doldurma" altına "Kart doldurma": tanıma, ödeme formu kuralı, iki öneri, ekran, uyarı, değer biçimleri, sınırlar. Cihaz denemelerinin sonuçları denetim belgesine.
- [ ] **Adım 2:** Kılavuz, değişiklik günlüğü (1.5.0), yol haritası (Faz 15 bölümü ve tablo), mağaza metni, `version: 1.5.0+9`.
- [ ] **Adım 3:** commit `belge(doldurma): kart doldurma belgeleri, sürüm 1.5.0`.

### Task 7: Son gözden geçirme ve yayın

- [ ] **Adım 1:** Taze bir gözden geçiren alt ajan bütün dalı tasarım ve bu planla karşılaştırır; bulgular doğrulanıp test önce düzeltilir.
- [ ] **Adım 2:** Bütün kontroller ve entegrasyon testleri; PR, CI yeşil, birleştirme (`gh pr merge --merge --author-email …`); `v1.5.0` etiketi, yayın.

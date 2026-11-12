# Tasarım Yenilemesi Uygulama Planı

> **Not (2026-11-13):** Bu planın yerini [cam tasarım planı](tasarim-cam-plani.md) aldı. Bu belge ilk turun kaydı olarak duruyor.

> **Uygulayan için:** Gerekli beceri: superpowers:executing-plans (bu projede tercih edilen; görevleri bu oturumda sırayla uygula). Adımlar `- [ ]` ile işaretlenir.

**Amaç:** KeyKey'i krem zeminli, turuncu ana renkli, aynı boy kartlı, yüzen cam menülü yeni görünüme taşımak; otomatik doldurmayı yarım pencereye almak ve tek kesin eşleşmeyi sorulmadan doldurmak.

**Mimari:** Renkler ve bileşen biçimleri tek bir temada (`lib/app/theme.dart`) toplanır. Ekranlar ortak birkaç bileşeni (`lib/app/ui/`) kullanır. Uygulama simgeleri ve sürüm, yeni bir Pigeon API'siyle Kotlin'den okunur. Doldurmada tek kayıt kuralı saf bir Dart fonksiyonudur; bildirim Kotlin'de `Toast` ile gösterilir; doldurma etkinliği saydam açılır.

**Teknoloji:** Flutter (Material 3), Riverpod, go_router, Pigeon 29, Kotlin. Yeni paket yok.

**Tasarım belgesi:** [`tasarim-yenileme.md`](tasarim-yenileme.md). Bu plan onu uygular; ikisi birlikte okunur.

## Genel kısıtlar

- Dal: `faz/9-yayin`. Commit biçimi `<tür>(<alan>): <açıklama>`, Türkçe; her görev sonunda commit ve push.
- Kontroller her görevden sonra: `dart format --output=none --set-exit-if-changed lib test integration_test`, `flutter analyze`, `flutter test`. Dal değiştirdiysen önce `flutter gen-l10n`.
- Yeni izin yok (`QUERY_ALL_PACKAGES`, `INTERNET` yok). Yeni pub paketi yok.
- Renkler (açık / koyu): zemin `#F6F1E7` / `#1C1A17`; kart `#FFFDF8` kenar `#E7DFCF` / kart `#24211D` kenar `#34302A`; yazı `#2B2A28` / `#EFE8DA`; ikincil yazı `#696356` / `#9B9384`; arama ve kutu zemini `#ECE5D6` / `#2A2723`; vurgu `#B4470F` (üstünde beyaz) / `#FF8A4C` (üstünde `#1C1A17`); simge turuncusu `#F26B1D`.
- Kontrast: normal yazı ≥ 4,5:1 (yukarıdaki değerler hesaplandı: vurgu kremde 4,85, ikincil kremde 5,30).
- Dokunma hedefi ≥ 48 dp; TalkBack etiketleri korunur; %200 yazıda taşma yok.
- `FLAG_SECURE`, bindirme gizleme, gizli dokunuş filtresi ve `accessibilityDataSensitive` her pencerede, saydam doldurma penceresinde de korunur.
- Arayüz simgeleri renksiz çizgi simgedir: Material'ın `*_outlined` simgeleri; dolu simge yalnızca seçili sekmede. Renkli olan yalnızca uygulama simgeleri ve vurgu rengi.
- Tema telefonun ayarını izler (`ThemeMode.system`).
- Yeni metinler `lib/l10n/app_tr.arb` ve `app_en.arb`'a girer.
- Yerel yayın derlemesi: `flutter build apk --release --target-platform android-x64,android-arm64` (Smart App Control 32 bit ARM aracını engelliyor).

## İnceleme odağı

Hiçbir görevin testinin tek başına yakalamadığı, kullanıcıyı en çok yakacak durumlar:

1. **İki kayıt aynı uygulamaya bağlı, biri imzası tutmayan:** imzası tutmayan eşleşme sayılmaz; tek kesin eşleşme olarak doğrudan doldurulmamalı mı? Kural: `signatureMismatches` boş değilse doğrudan doldurma yok, pencere açılır (kullanıcı neden iki kayıt olduğunu görsün). Test Görev 9'da.
2. **Uygulama simgesi okunamayan bağlı kayıt** (uygulama kaldırılmış ya da ana ekranda simgesi yok): kart çizgi simgeye düşmeli, hata göstermemeli. Test Görev 3'te.
3. **Uzun kayıt adı ve boş kullanıcı adı:** kart boyu değişmemeli, ad tek satırda kesilmeli. Test Görev 2'de.
4. **Doldurma penceresi açıkken kilit süresi dolarsa ya da kullanıcı arka plana atarsa:** bugünkü davranış (iptal, kasa kapanır) saydam pencerede de aynı kalmalı. Görev 10'un cihaz denemesinde.
5. **Koyu temada uygulama simgeleri:** silik simge koyu zeminde de görünür ama yazıyı bastırmamalı; kontrast testi metne bakar, simgeye değil. Görev 4'ün ekran görüntüsü denetiminde.

---

### Görev 1: Tema

**Dosyalar:**
- Değiştir: `lib/app/theme.dart`
- Test: `test/app/theme_test.dart` (yeni)

**Arayüzler:**
- Üretir: `AppTheme.light`, `AppTheme.dark` (aynı adlar); `abstract final class KkColors` içinde yukarıdaki renkler `static const Color` olarak (`cream`, `card`, `cardBorder`, `ink`, `inkMuted`, `field`, `accent`, `brandOrange` ve koyu karşılıkları `darkCream`… ya da `KkPalette light/dark` nesnesi; uygulayıcı seçer, ama bütün görevler yalnızca `Theme.of(context).colorScheme` ve `KkColors.brandOrange` kullanır).

- [ ] **Adım 1: Başarısız testi yaz.** `theme_test.dart`:
  - `contrast(Color a, Color b)` yardımcı fonksiyonu (WCAG bağıl parlaklık) testin içinde.
  - Her iki temada `expect(contrast(scheme.onSurface, scheme.surface), greaterThanOrEqualTo(4.5))`, `onSurfaceVariant`/`surface`, `primary`/`surface`, `onPrimary`/`primary` için de.
  - `expect(AppTheme.light.colorScheme.primary, const Color(0xFFB4470F))`, `expect(AppTheme.dark.colorScheme.primary, const Color(0xFFFF8A4C))`, `expect(AppTheme.light.scaffoldBackgroundColor, const Color(0xFFF6F1E7))`.
- [ ] **Adım 2:** `flutter test test/app/theme_test.dart` → FAIL (renkler eski).
- [ ] **Adım 3: Temayı uygula.** `ColorScheme.fromSeed` yerine renkleri elle ver (`ColorScheme(brightness:…, primary:…, surface:…, …)`). Bileşen temaları: `cardTheme` (renk kart, kenar 1 px, köşe 14, gölge 0, kenar boşluğu 0), `inputDecorationTheme` (dolu, `field` rengi, köşe 14, kenarlık yok, odakta 1,5 px vurgu), `filledButtonTheme` (vurgu, köşe 24, en az 48 yükseklik), `switchTheme` (açıkken vurgu), `bottomSheetTheme` (zemin rengi, üst köşeler 24, tutamak göster), `snackBarTheme` (yüzen), `appBarTheme` (zemin rengi, gölge 0, `scrolledUnderElevation` 0).
- [ ] **Adım 4:** `flutter test` → hepsi PASS. Erişilebilirlik testi (`test/accessibility/accessibility_test.dart`) geçmezse renk değil bileşen düzeltilir.
- [ ] **Adım 5: Commit** `özellik(tema): krem zemin ve turuncu ana renk`, `Refs #103`.

### Görev 2: Ortak bileşenler

**Dosyalar:**
- Yeni: `lib/app/ui/kk_card.dart`, `lib/app/ui/kk_sheet.dart`, `lib/app/ui/kk_section.dart`
- Test: `test/app/ui/kk_card_test.dart`, `test/app/ui/kk_sheet_test.dart`

**Arayüzler:**
- Üretir:
  - `class KkCard extends StatelessWidget { const KkCard({required Widget title, Widget? subtitle, Widget? trailing, Widget? watermark, WatermarkSide watermarkSide = WatermarkSide.end, VoidCallback? onTap, String? semanticLabel}) }` — en az yükseklik `KkCard.minHeight = 60` (iki satır); başlık ve alt yazı `maxLines: 1, overflow: TextOverflow.ellipsis`; filigran kartın kenarında taşar ve kırpılır (`ClipRRect`), opaklık 0,2; `enum WatermarkSide { start, end }`.
  - `Future<T?> showKkSheet<T>(BuildContext context, {required WidgetBuilder builder, bool expandable = false})` — alttan açılan pencere, `showModalBottomSheet` üstüne; `expandable` ise `DraggableScrollableSheet` ile yukarı uzar.
  - `Future<bool> showKkConfirm(BuildContext context, {required String title, required String message, required String confirmLabel, required String cancelLabel, bool destructive = false})` — onay penceresi; eski `AlertDialog` onaylarının yerine.
  - `class KkSection extends StatelessWidget { const KkSection({required String title, required List<Widget> children}) }` — ayarlardaki grup başlığı ve aralarında ince çizgi olan satırlar tek kartta.

- [ ] **Adım 1: Başarısız testleri yaz.**
  - `kk_card_test`: "kısa ve uzun adlı kartlar aynı boyda": iki `KkCard` (ad `'A'` ve 200 karakterlik ad, biri alt yazısız) → `tester.getSize` yükseklikleri eşit ve `== KkCard.minHeight`.
  - "yazı %200 olunca kart büyür": `MediaQuery(textScaler: TextScaler.linear(2))` altında yükseklik `> KkCard.minHeight` ve `tester.takeException()` null.
  - "filigran olmayan kart hata vermez".
  - `kk_sheet_test`: `showKkConfirm` onaylanınca `true`, vazgeçilince ve dışına dokununca `false`.
- [ ] **Adım 2:** Testler FAIL (dosyalar yok).
- [ ] **Adım 3:** Bileşenleri yaz.
- [ ] **Adım 4:** `flutter test test/app/ui` → PASS.
- [ ] **Adım 5: Commit** `özellik(arayüz): aynı boy kart, alt pencere ve bölüm bileşenleri`.

### Görev 3: Uygulama simgeleri ve sürüm (Pigeon)

**Dosyalar:**
- Değiştir: `pigeons/platform_api.dart`; yeniden üret: `dart run pigeon --input pigeons/platform_api.dart` (`lib/core/platform/platform_api.g.dart`, `PlatformApi.g.kt`)
- Yeni: `android/app/src/main/kotlin/io/github/aaudraa/keykey/AppPackages.kt`, `lib/app/ui/record_watermark.dart`, `lib/core/platform/app_packages.dart`
- Değiştir: `MainActivity.kt`, `autofill/AutofillActivity.kt` (API kaydı)
- Test: `test/app/ui/record_watermark_test.dart`, `android/app/src/test/kotlin/io/github/aaudraa/keykey/AppPackagesTest.kt`

**Arayüzler:**
- Üretir:
  - Pigeon: `@HostApi() abstract class AppPackagesApi { Uint8List? appIcon(String packageName, int sizePx); String versionName(); }`
  - Kotlin `class AppPackages(context: Context) : AppPackagesApi` — `appIcon`: `packageManager.getApplicationIcon(packageName)` → `sizePx` boyutunda bitmap → PNG baytları; paket görünmüyorsa (`NameNotFoundException`) `null`. `versionName`: `BuildConfig.VERSION_NAME`.
  - Dart `final appIconProvider = FutureProvider.family<Uint8List?, String>` — kasa kilitlenince düşer (`ref.watch` ile kasa durumuna bağlı); diske yazılmaz.
  - `final appVersionProvider = FutureProvider<String>`.
  - `class RecordWatermark extends ConsumerWidget { const RecordWatermark({required LoginContent? login, String? fallbackUrl}) }` — `login.apps` boş değilse ilk uygulamanın simgesi; simge `null` ise ya da uygulama yoksa çizgi simge: sitesi varsa `Icons.language_outlined`, yoksa `Icons.key_outlined`.

- [ ] **Adım 1: Başarısız testleri yaz.**
  - `record_watermark_test` (sahte `AppPackagesApi` ile): "bağlı uygulamanın simgesi gösterilir" (`find.byType(Image)`), "simge okunamazsa küre çizgi simgesi" (API `null` döner, kayıtta URL var → `find.byIcon(Icons.language_outlined)`), "uygulama ve site yoksa anahtar simgesi".
  - `AppPackagesTest.kt` (Robolectric, mevcut testlerin düzeninde): bilinmeyen paket → `null`; kendi paketi → boş olmayan PNG (ilk baytlar `0x89 'P' 'N' 'G'`).
- [ ] **Adım 2:** FAIL.
- [ ] **Adım 3:** Pigeon tanımını ekle, üret, Kotlin ve Dart tarafını yaz, iki etkinlikte `AppPackagesApi.setUp`.
- [ ] **Adım 4:** `flutter test` ve `cd android && ./gradlew :app:testDebugUnitTest --tests '*AppPackagesTest*'` → PASS.
- [ ] **Adım 5:** `resources/docs/guvenlik-tasarimi.md`: uygulama simgelerinin yalnızca bellekte, kasa açıkken okunduğunu bir cümleyle yaz. **Commit** `özellik(kasa): bağlı uygulamanın simgesi ve sürüm bilgisi`.

### Görev 4: Yüzen cam alt menü

**Dosyalar:**
- Değiştir: `lib/app/app_shell.dart`
- Yeni: `lib/app/ui/glass_nav_bar.dart`
- Test: `test/app/ui/glass_nav_bar_test.dart`; etkilenen: `test/features/settings/settings_test.dart`, `test/features/vault/vault_screens_test.dart`, `integration_test/app_test.dart` (yalnızca `NavigationBar`/`NavigationDestination` arayan satırlar)

**Arayüzler:**
- Üretir: `class GlassNavBar extends StatelessWidget { const GlassNavBar({required int selectedIndex, required ValueChanged<int> onSelected, required List<GlassNavItem> items}) }`, `class GlassNavItem { const GlassNavItem({required IconData icon, required IconData selectedIcon, required String label}) }`. `GlassNavBar.height = 56`, genişlik içerik kadar (öğe başına 64), ekranın altından 16 dp yukarıda ortada; `BackdropFilter(ImageFilter.blur(sigmaX: 16, sigmaY: 16))`, zemin kart renginin %55 opaklığı, ince kenar. Seçili simge dolu ve vurgu renginde, altında 4 dp nokta. Her öğe `Semantics(label: …, selected: …, button: true)` ile "Kasa, sekme 1/3" okunur (bugünkü `NavigationBar` metniyle aynı; mevcut testler bunu arıyorsa değişmesin).
- `AppShell`: `Scaffold(extendBody: true, bottomNavigationBar: GlassNavBar(…))`; bugünkü `maybePop` davranışı aynen. Listeler alta `GlassNavBar.height + 32` boşluk bırakır (Görev 5 ve 6 bunu kullanır: `const kNavClearance = GlassNavBar.height + 32`).

- [ ] **Adım 1: Başarısız test.** `glass_nav_bar_test`: üç öğe, dokununca `onSelected(1)`; `meetsGuideline(androidTapTargetGuideline)` ve `labeledTapTargetGuideline`; seçili öğenin semantiğinde `isSelected`.
- [ ] **Adım 2:** FAIL.
- [ ] **Adım 3:** Bileşeni yaz, `AppShell`'e tak, etkilenen testlerdeki tür aramalarını `GlassNavBar`/semantik etikete çevir.
- [ ] **Adım 4:** `flutter test` → PASS (erişilebilirlik testi dahil).
- [ ] **Adım 5: Commit** `özellik(arayüz): yüzen buzlu cam alt menü`.

### Görev 5: Kasa, kayıt ayrıntısı, düzenleme

**Dosyalar:** `lib/features/vault/presentation/vault_screen.dart`, `login_detail_screen.dart`, `login_edit_screen.dart`, `password_report_screen.dart`, `trash_screen.dart`, `lib/features/backup/presentation/backup_reminder_banner.dart`; testler `test/features/vault/vault_screens_test.dart`.

**Arayüzler:** Tüketir `KkCard`, `RecordWatermark`, `showKkConfirm`, `kNavClearance`.

- [ ] **Adım 1: Test ekle/uyarla.** `vault_screens_test`: "kasa satırları aynı boyda" (kısa ve uzun adlı iki kayıt → kart yükseklikleri eşit); "bağlı uygulamalı kayıtta filigran var" (sahte API ile). Var olan testlerin `ListTile` aramaları metne göre aramaya çevrilir.
- [ ] **Adım 2:** FAIL.
- [ ] **Adım 3:** Ekranlar: kasa listesi `KkCard` + sağda `RecordWatermark`; arama kutusu temadan; ayrıntı ekranında her alan ayrı `KkCard` (kopyala ve göster çizgi simge düğmeleri); düzenleme ekranında kutular temadan, Kaydet `FilledButton`; silme ve atma onayları `showKkConfirm`; yedek hatırlatması bir `KkCard`.
- [ ] **Adım 4:** `flutter test` → PASS.
- [ ] **Adım 5: Commit** `özellik(kasa): yeni görünüm`.

### Görev 6: 2FA ekranları

**Dosyalar:** `lib/features/authenticator/presentation/authenticator_screen.dart`, `otp_code_tile.dart`, `linked_otp_tile.dart`, `otp_edit_screen.dart`, `otp_trash_screen.dart`, `confirm_identity.dart`, `login_picker.dart`, `otp_import_screen.dart`, `qr_scan_screen.dart`; testler `test/features/authenticator/*`, `integration_test/otp_flow_test.dart`.

**Arayüzler:** Tüketir `KkCard(watermarkSide: WatermarkSide.start)`, `RecordWatermark` (bağlı parola kaydı varsa onun uygulaması), `showKkSheet`, `showKkConfirm`.

- [ ] **Adım 1: Test.** "kod tek parça ve kalan süre halkası var" (`find.byType(CircularProgressIndicator)` ya da halka bileşeni; semantik etiket bugünkü "25 saniye kaldı" metniyle); "HOTP kartı TOTP kartıyla aynı boyda ve 'Kod üret' düğmesi var".
- [ ] **Adım 2:** FAIL.
- [ ] **Adım 3:** Kart: solda filigran ve ad, sağda kod (eşit aralıklı, 21 sp, iki üçlü grup) ve 22 dp vurgu renkli halka. Dokununca kopyalar (bugünkü gibi). Bugünkü ekran okuyucu davranışı (rakam rakam, geri sayımın susması) korunur. Diyaloglar alt pencereye.
- [ ] **Adım 4:** `flutter test` → PASS.
- [ ] **Adım 5: Commit** `özellik(2fa): yeni görünüm`.

### Görev 7: Ayarlar

**Dosyalar:** `lib/features/settings/presentation/settings_screen.dart`, `change_password_screen.dart`, `lib/features/backup/presentation/backup_section.dart`, `plaintext_export.dart`, `restore_screen.dart`, `login_import_screen.dart`, `lib/features/autofill/presentation/autofill_setup_section.dart`; `lib/l10n/app_*.arb`; testler `test/features/settings/settings_test.dart`, `test/features/backup/*`.

**Arayüzler:** Tüketir `KkSection`, `showKkSheet`, `appVersionProvider`. Yeni metinler: `settingsGroupSecurity` "Güvenlik"/"Security", `settingsGroupBackup` "Yedek ve aktarım"/"Backup and transfer", `settingsGroupAutofill` "Otomatik doldurma"/"Autofill", `settingsGroupAbout` "Hakkında"/"About", `settingsVersion` "Sürüm"/"Version", `settingsMoreInfo` "Açıklama"/"More info".

- [ ] **Adım 1: Test.** "ayarlar dört grup başlığını gösterir"; "parmak izi satırında açıklama satırda değil, (i) ile açılan pencerede" (`find.text(l10n.settingsBiometricHint)` önce yok, (i)'ye dokununca var); "sürüm satırı sahte API'nin döndürdüğü sürümü gösterir".
- [ ] **Adım 2:** FAIL.
- [ ] **Adım 3:** Grupları tasarım belgesindeki sırayla kur; satırlar aynı boy (`KkCard.minHeight`); uzun açıklamalar (`settingsBiometricHint`, `settingsOtpRequireAuthHelp`, `settingsAutofillCopyOtpHelp`, yedek açıklaması) (i) penceresine. Kısa durum metinleri ("Son yedek: …", "KeyKey seçili") alt yazı olarak kalır.
- [ ] **Adım 4:** `flutter test` → PASS.
- [ ] **Adım 5: Commit** `özellik(ayarlar): gruplu ve derli toplu ayarlar`.

### Görev 8: Kilit, kurulum ve kalan ekranlar

**Dosyalar:** `lib/features/lock/presentation/*.dart`, `lib/features/onboarding/presentation/onboarding_screen.dart`, `lib/features/generator/presentation/*.dart`, `lib/app/licenses.dart`; yeni `lib/app/ui/keykey_logo.dart`; testler `test/features/lock/*`, `test/features/onboarding/*`.

**Arayüzler:** Üretir `class KeyKeyLogo extends StatelessWidget { const KeyKeyLogo({double size = 96}); static const String pathData = 'M24 14h16v30l28-30h20L57 47l33 39H69L46 58l-6 6v22H24z'; }` — beyaz daire içinde `#F26B1D` K, yol 100×100 kutuda; `CustomPainter` yolu bu dizeden çizer (küçük bir SVG yol ayrıştırıcısı yalnızca `M h v l H L z` komutlarını destekler). Semantik etiket "KeyKey". Görev 11 aynı dizeyi kullanır.

- [ ] **Adım 1: Test.** "kilit ekranında logo ve tek parola kutusu var"; logo için `find.bySemanticsLabel('KeyKey')`.
- [ ] **Adım 2:** FAIL.
- [ ] **Adım 3:** Kilit ekranı: ortada `KeyKeyLogo`, altında parola kutusu ve "Aç". Kurulum, kurtarma ve yeni parola ekranları aynı düzen. Parola üretici zaten alt pencere; temadan biçim alır.
- [ ] **Adım 4:** `flutter test` → PASS.
- [ ] **Adım 5: Commit** `özellik(kilit): yeni görünüm ve logo`.

### Görev 9: Tek kaydın doğrudan doldurulması ve bildirim

**Dosyalar:**
- Değiştir: `lib/features/autofill/domain/fill_warnings.dart`, `lib/features/autofill/application/autofill_bridge.dart`, `pigeons/platform_api.dart` (yeniden üret), `autofill/AutofillActivity.kt`, `lib/features/autofill/presentation/autofill_pick_screen.dart`, `lib/l10n/app_*.arb`, `resources/docs/guvenlik-tasarimi.md`
- Test: `test/features/autofill/fill_warnings_test.dart` (var olan dosyaya ekle), `test/features/autofill/autofill_pick_screen_test.dart`

**Arayüzler:**
- Üretir: `LoginItem? directFillCandidate({required AutofillTarget target, required LoginMatches matches})` — `matches.matches.length == 1`, `matches.signatureMismatches.isEmpty`, `!target.showsWebPage` ve `fillWarnings(target: target, item: tek, matches: matches).isEmpty` ise o kayıt; değilse `null`.
- Pigeon `AutofillApi.fill(String username, String password, String notice)`; `AutofillBridge.fill({required String username, required String password, required String notice})`. Kotlin `fill` sonucu döndürmeden önce `Toast.makeText(applicationContext, notice, Toast.LENGTH_SHORT).show()`.
- Metin: `autofillFilledNotice` "{name} dolduruldu" / "{name} filled"; ad boşsa `autofillFilledNoticeUnnamed` "Kayıt dolduruldu" / "Login filled".

- [ ] **Adım 1: Başarısız testler.** `fill_warnings_test` grubu `directFillCandidate`:
  - uygulama hedefi, imzası tutan tek kayıt → o kayıt;
  - güvenilen tarayıcı, `https`, alan adı tutan tek kayıt → o kayıt;
  - iki eşleşme → `null`;
  - tek eşleşme ama `http` → `null`;
  - tek eşleşme ama `showsWebPage` → `null`;
  - tek eşleşme ve başka bir kayıtta imza tutmuyor (`signatureMismatches` dolu) → `null`;
  - eşleşme yok → `null`.
  - `autofill_pick_screen_test`: tek kesin eşleşmede ekran liste göstermeden sahte köprünün `fill`'ini çağırır ve `notice == 'GitHub dolduruldu'`; listeden seçilen doldurmada da `notice` dolu.
- [ ] **Adım 2:** FAIL.
- [ ] **Adım 3:** Fonksiyonu yaz; doldurma ekranında eşleşmeler yüklenince aday varsa doğrudan `fill` çağır (bir kez; yeniden kurulumda iki kez çağrılmasın). Pigeon'u güncelle, Kotlin'de bildirimi göster.
- [ ] **Adım 4:** `flutter test` → PASS; `./gradlew :app:testDebugUnitTest` → PASS.
- [ ] **Adım 5:** `guvenlik-tasarimi.md` "Akış" 4. madde ve "Şüpheli durumlar" son cümlesine tek kayıt kuralını, "Bilinen ödünler"e bildirimdeki kayıt adını (güvenli pencere dışında, ekran kaydına ve erişilebilirlik olaylarına girer; yalnızca ad, kullanıcı adı ve parola yok) yaz. **Commit** `özellik(otomatik-doldurma): tek kesin eşleşme sorulmadan dolduruluyor`.

### Görev 10: Saydam doldurma penceresi

**Dosyalar:**
- Değiştir: `android/app/src/main/AndroidManifest.xml` (`AutofillActivity` teması), `android/app/src/main/res/values/styles.xml` ve `values-night/styles.xml` (yeni `AutofillTheme`: `windowIsTranslucent`, saydam pencere zemini, başlıksız), `autofill/AutofillActivity.kt` (`getBackgroundMode() = BackgroundMode.transparent`), `lib/features/autofill/presentation/autofill_app.dart`, `autofill_pick_screen.dart`, `autofill_save_screen.dart`, `fill_confirm_dialog.dart`, `lib/features/lock/presentation/lock_screen.dart` (doldurmada kompakt biçim)
- Test: `test/features/autofill/autofill_pick_screen_test.dart`, `test/features/autofill/autofill_save_screen_test.dart`

**Arayüzler:** Tüketir `showKkSheet`, `KkCard`, `RecordWatermark`. Üretir `class AutofillSheetFrame extends StatelessWidget { const AutofillSheetFrame({required Widget child, required VoidCallback onDismiss, bool expanded = false}) }` — karartılmış zemin (`Colors.black` %35) + alttan yuvarlak köşeli pencere; zemine dokunmak ya da aşağı kaydırmak `onDismiss` (= `bridge.cancel()`).

- [ ] **Adım 1: Test.** "seçim penceresi yalnızca eşleşenleri ve arama kutusunu gösterir; aramaya dokununca bütün kayıtlarda arar"; "zemine dokunmak iptal eder (sahte köprüde `cancel` çağrıldı)"; "uyarı ve onay pencerenin içinde" (`fillWarnings` dolu bir kayıt seçilince uyarı metni görünür, `AlertDialog` yok); "kaydetme ekranı da `AutofillSheetFrame` içinde".
- [ ] **Adım 2:** FAIL.
- [ ] **Adım 3:** Kotlin teması ve saydam arka plan; Flutter tarafında `AutofillHome` her durumu (`LockScreen` kompakt, seçim, kaydetme) `AutofillSheetFrame` içinde gösterir. Pencere korumaları (`WindowProtection`) değişmeden uygulanır.
- [ ] **Adım 4:** `flutter test` → PASS. **Cihaz:** Android 11, 14, 16, 17 emülatörlerinde Chrome'da ve bir uygulamada doldurma: tek kayıt → doğrudan dolar ve bildirim; iki kayıt → yarım pencere; eşleşme yok → arama ve uyarı; zemine dokunma → iptal; arka plana atma → iptal ve kasa kapalı; ekran görüntüsü alınamıyor; `tapjacking-device-test.sh` doldurma penceresinde de geçer.
- [ ] **Adım 5: Commit** `özellik(otomatik-doldurma): doldurma ve kaydetme yarım pencerede`.

### Görev 11: Uygulama simgesi ve açılış ekranı

**Dosyalar:**
- Yeni: `resources/design/keykey-simge.svg` (108×108 tuval, beyaz zemin, K güvenli alanın 66 dp dairesi içinde), `android/app/src/main/res/drawable/ic_launcher_foreground.xml`, `drawable/ic_launcher_monochrome.xml`, `mipmap-anydpi-v26/ic_launcher.xml` (arka plan `@color/ic_launcher_background` = `#FFFFFF`, ön katman, `monochrome`), `values/colors.xml`, `values-v31/styles.xml` ve `values-night-v31/styles.xml` (`windowSplashScreenBackground` `#F6F1E7` / `#1C1A17`, `windowSplashScreenAnimatedIcon` ön katman)
- Değiştir: `drawable/launch_background.xml`, `drawable-v21/launch_background.xml` (krem zemin ortasında simge; Android 11 için), `values-night` karşılıkları
- Sil: `mipmap-*dpi/ic_launcher.png` (minSdk 30, uyarlanabilir simge yeterli)

- [ ] **Adım 1: Başarısız test.** `test/app/logo_path_test.dart`: `KeyKeyLogo.pathData` (Görev 8'deki yol dizesi, `static const String`) `resources/design/keykey-simge.svg` içindeki K yolunun `d` değeriyle aynı. SVG'de yol 100×100 kutudaki koordinatlarla yazılır ve 108 tuvale bir `<g transform="…">` ile yerleştirilir, böylece dize birebir aynı kalır.
- [ ] **Adım 2:** FAIL (SVG yok).
- [ ] **Adım 3:** SVG ve Android kaynaklarını yaz. Ön katmanda K, 108 tuvalde 66 dp güvenli alanı aşmayacak ölçekte; tek renkli katman aynı yol.
- [ ] **Adım 4:** `flutter test` → PASS; sürüm derlemesi, `check-release-apk.sh` temiz; emülatörde ana ekranda simge (yuvarlak ve köşeli-yuvarlak maske), Android 13+ temalı simge, açılış ekranı açık ve koyu temada, Android 11'de de.
- [ ] **Adım 5: Commit** `özellik(simge): beyaz zeminde turuncu K ve açılış ekranı`.

### Görev 12: Kapanış

- [ ] **Adım 1:** Bütün kontroller; entegrasyon testleri dört emülatörde (`it.sh <seri> a`, `b`); `biometric-device-test.sh`, `tapjacking-device-test.sh`, `logcat-scan.sh` en az Android 17'de.
- [ ] **Adım 2:** Telefona sürüm derlemesi (önce "telefonu bağlar mısın"); kullanıcıyla doldurma (tek kayıt, iki kayıt), koyu tema, simge ve TalkBack ile kısa deneme.
- [ ] **Adım 3:** `resources/CHANGELOG.md` "Değişenler"e tasarım yenilemesi ve doldurma kuralı; `resources/yol-haritasi.md` Faz 9 listesinde tasarım maddesi `[x]` ve durum; `resources/docs/bagimliliklar.md` değişmedi (yeni paket yok) — denetle.
- [ ] **Adım 4: Commit** `belge(tasarım): tasarım yenilemesi tamamlandı`, `Closes #103`.

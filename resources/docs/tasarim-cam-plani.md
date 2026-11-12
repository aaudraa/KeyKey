# Cam Tasarım Uygulama Planı

> **Uygulayan için:** Gerekli beceri: superpowers:executing-plans (bu projede tercih edilen; görevleri bu oturumda sırayla uygula). Adımlar `- [ ]` ile işaretlenir.

**Amaç:** KeyKey'in bütün ekranlarını renkli yumuşak zemin, cam kartlar, "+" düğmeli cam alt menü, sade formlar ve yumuşak hareketlerden oluşan yeni görünüme taşımak.

**Mimari:** Renkler ve cam ölçüleri tek temada (`lib/app/theme.dart`) ve bir tema eklentisinde (`KkGlass`) durur. Her ekran zeminini kendisi çizen ortak bir iskelet (`KkScaffold`) ve birkaç ortak bileşen (`lib/app/ui/`) kullanır. "+" kutusu `AppShell`'in içinde, uygulamanın kendi penceresinde çizilir. Form ekranları kök gezgine taşınır; böylece alt menünün üstünü kendiliğinden örterler.

**Teknoloji:** Flutter (Material 3), Riverpod, go_router. Yeni paket yok; Kotlin tarafında yalnızca açılış rengi ve geri hareketi ayarı değişir.

**Tasarım belgesi:** [`tasarim-cam.md`](tasarim-cam.md). Bu plan onu uygular; ikisi birlikte okunur. Örnek ekranlar: [`../design/cam-tasarim-ornekleri.html`](../design/cam-tasarim-ornekleri.html).

## Genel kısıtlar

- Dal: `faz/9-yayin`. Commit biçimi `<tür>(<alan>): <açıklama>`, Türkçe, `Refs #103`; her görev sonunda commit ve push.
- Her görevden sonra: `dart format --output=none --set-exit-if-changed lib test integration_test`, `flutter analyze`, `flutter test`. Dal değiştirdiysen önce `flutter gen-l10n`. Bir görevin testleri yeşil olmadan sonrakine geçilmez.
- Yeni izin yok (`QUERY_ALL_PACKAGES`, `INTERNET` yok). Yeni pub paketi yok. Site logosu, indirilen ya da gömülen yazı tipi yok.
- `FLAG_SECURE`, bindirme gizleme, gizli dokunuş filtresi ve hassas pencere işaretlerine dokunulmaz. Otomatik doldurmanın eşleşme, uyarı ve onay kuralları değişmez; o ekranlarda yalnızca görünüm değişir.
- Kontrast: normal yazı ≥ 4,5:1, simge ve büyük yazı ≥ 3:1; zeminin en kötü noktasında, hem çıplak zeminde hem cam kartın üstünde.
- Dokunma hedefi ≥ 48 dp; TalkBack etiketleri korunur; %200 yazıda taşma ve kesilme yok.
- Gerçek bulanıklaştırma (`BackdropFilter`) yalnızca: alt menü, "+" kutusu ve karartması, üç nokta menüsü, alttan açılan pencereler, bildirim. Liste kartlarında yok.
- Telefonda "animasyonları kaldır" açıksa (`MediaQuery.disableAnimationsOf`) bütün süreler sıfırdır ve sürekli hareketler durur.
- Yeni metinler `lib/l10n/app_tr.arb` ve `app_en.arb`'a girer. Kod adları İngilizce, yorumlar Türkçe.
- Kullanılmayan kod bırakılmaz: ilk turun filigranı, yalnızca simgeli menüsü ve ayrı "Ekle" düğmeleri silinir.
- Yerel yayın derlemesi: `flutter build apk --release --target-platform android-x64,android-arm64`.

### Renkler (hesaplanmış değerler)

Tasarım belgesindeki tonlar en kötü zemin noktasında okunmadığı için ayarlandı. Yanlarındaki oranlar o renkle ölçülen en düşük değerdir.

| Rol | Açık | Koyu |
|---|---|---|
| Zemin (`ground`) | `#F3EEF4` | `#0C0B10` |
| Lekeler (şeftali, lila, pembe) | `#FF9A5A`, `#B48CFF`, `#FF6FA3`; merkezde %36 | `#F26B1D`, `#6B3BFF`, `#E0336E`; merkezde %38 |
| Yazı (`onSurface`) | `#1B1A1F` | `#F5F2F8` |
| İkincil yazı (`onSurfaceVariant`) | `#55515E` (4,96) | `#C4BFCD` (4,76) |
| Vurgulu yazı (`primary`) | `#9A3A08` (4,53) | `#FFA873` (4,53) |
| Vurgulu simge ve çizim (`KkGlass.accent`) | `#C2470C` (3,22) | `#FF9457` (3,93) |
| Hata | `#A1201A` | `#FFB4AB` |
| Ana düğme | geçiş `#FF9A52` → `#EC5512`, üstünde `#1B1A1F` (4,84) | aynı |
| Cam kart (`fill`) | beyaz %50, kenar beyaz %70 | beyaz %8, kenar beyaz %17 |
| Güçlü cam (`fillStrong`: menü, kutu, pencere) | beyaz %62 | beyaz %12 |
| Seçili sekme kapsülü (`capsule`) | beyaz %72 | beyaz %16 |
| Vurgu zemini (`accentContainer`) | `accent` %12 | `accent` %18 |
| Karartma (`scrim`) | siyah %18 | siyah %40 |
| Opak yüzey (`surface`; Material bileşenleri için) | `#F9F6FA` | `#1F1E23` |

Kural: **vurgu renkli yazı `colorScheme.primary`, vurgu renkli simge ve çizim `KkGlass.accent` kullanır.** Ana düğmede beyaz değil koyu yazı vardır (karar: turuncu soldurulmadı). Seçili sekmenin adı `onSurface`, simgesi `accent` rengindedir (koyu temada vurgulu yazı kapsülde 4,5'i tutmuyor).

Baş harf kutularının renk takımı (üstünde beyaz harf, hepsi ≥ 5,0): `#C2410C`, `#2563EB`, `#0F766E`, `#7C3AED`, `#BE185D`, `#15803D`, `#B45309`, `#475569`, `#B91C1C`, `#0E7490`.

### Ölçüler ve süreler

- Köşeler: kart 22, grup ve kutu 26, pencere üst köşeleri 30, düğme ve arama tam yuvarlak. Bulanıklık sigma 20.
- Kart yükseklikleri (normal yazıda en az): kasa 64, 2FA 72, ayar satırı 64. Simge kutusu 42, köşe 13.
- Alt menü: yükseklik 64, alttan boşluk 16, "+" çapı 48.
- Süreler (`KkMotion`): `fast` 150 ms, `base` 250 ms, `panelOpen` 400 ms, `panelClose` 200 ms; yay eğrisi `Cubic(0.2, 1.35, 0.4, 1.0)`.

## İnceleme odağı

Tasarım belgesinin söylemediği ama kullanıcıyı en çok yakacak durumlar. Her birinin testi ilgili görevdedir.

1. **Dar ekran ve %200 yazıda alt menü:** 320 dp genişlikte ve %200 yazıda şerit ekrana sığmalı, "+" görünür kalmalı; sığmıyorsa seçili sekmenin adı gizlenir. Görev 4.
2. **"+ → Parola"ya hızlı çift dokunma:** iki form açılmamalı. Kutu açıkken kasa kilitlenirse, kilit açıldığında kutu kapalı gelmeli. Görev 5.
3. **Listeden kopyalama:** kopyala düğmesi kaydı açmamalı; parolası boş kayıtta düğme olmamalı; kopyalama sırasında kasa kilitlenirse hata gösterilmeden geçilmeli. Görev 6.
4. **Düzenlemede kaldırılan dolu alan:** dolu bir ek alanın (not, klasör) kaldırma düğmesi veriyi sessizce silmemeli: alan kaldırılınca form "değişti" sayılır, kaydetmeden çıkışta soru sorulur, kaydedince alan boş kaydedilir. Görev 8.
5. **Adı boş, rakamla ya da emojiyle başlayan kayıt:** baş harf kutusu çökmemeli; boş adda `?`, emojide emojinin tamamı (yarım karakter değil). Görev 2.

---

### Görev 1: Tema, zemin ve cam yüzey

**Dosyalar:**
- Değiştir: `lib/app/theme.dart`; `android/app/src/main/res/` altında `F6F1E7` ve `1C1A17` geçen açılış renkleri → `F3EEF4`, `0C0B10`
- Yeni: `lib/app/ui/kk_glass.dart`, `lib/app/ui/kk_backdrop.dart`, `lib/app/ui/kk_motion.dart`
- Test: `test/app/theme_test.dart` (yeniden yaz), `test/app/ui/kk_backdrop_test.dart` (yeni)

**Arayüzler (üretir):**
- `KkColors`: yukarıdaki tablo `static const Color` olarak (`ground`, `ink`, `inkMuted`, `accentText`, `accent`, `error`, `darkGround`…, `blobsLight`, `blobsDark`, `ctaStart`, `ctaEnd`, `onCta`, `avatarPalette`); `brandOrange` kalır. Eski krem adları silinir.
- `AppTheme.light`, `AppTheme.dark` (adlar aynı). `scaffoldBackgroundColor` saydam; `appBarTheme` saydam, `centerTitle: false`, başlık `titleLarge` kalın; `filledButtonTheme` en az 52 yükseklik, tam yuvarlak, `backgroundBuilder` ile turuncu geçiş (etkisizken `fill`), yazı `onCta`; `cardTheme` rengi `fill`, köşe 22, gölge yok; `inputDecorationTheme` dolgu `fill`, köşe 22, kenar yok, odakta 1,5 px `accent`; `chipTheme` cam; `switchTheme` açıkken `accent`; `bottomSheetTheme` saydam zemin (camı pencere çizer); `snackBarTheme` yüzen, saydam, gölgesiz; `popupMenuTheme` saydam; `dividerTheme` kenar rengi; `pageTransitionsTheme` şimdilik dokunulmaz (Görev 15).
- `class KkGlass extends ThemeExtension<KkGlass>`: `fill`, `fillStrong`, `capsule`, `border`, `highlight`, `shadow`, `scrim`, `accent`, `accentContainer`, `onCta`, `ctaGradient` (`LinearGradient`), `ground`, `blobs` (`List<Color>`), `blobAlpha`; `static KkGlass of(BuildContext)`; `List<Color> worstGrounds()` → zemin ve her lekenin `blobAlpha` ile zemine karışmış hali.
- `class GlassSurface extends StatelessWidget`: `({required Widget child, BorderRadius borderRadius = 22, bool blur = false, bool strong = false, EdgeInsetsGeometry? padding})`; `static const double blurSigma = 20`. `blur: false` iken ağaçta `BackdropFilter` yoktur.
- `class KkBackdrop extends StatelessWidget`: `({bool drifting = false})`. Üç leke `CustomPainter` içinde `RadialGradient` ile çizilir (merkezler ekranın oranı olarak: şeftali (0,10; 0,08), lila (1,00; 0,45), pembe (0,05; 0,95); yarıçap genişliğin 0,75 / 0,70 / 0,70 katı), `RepaintBoundary` içinde. Lekeler üst üste binip tek lekenin en koyu noktasını aşmaz.
- `class KkScaffold extends StatelessWidget`: `({PreferredSizeWidget? appBar, required Widget body, Widget? bottomNavigationBar, bool extendBody = false, bool? resizeToAvoidBottomInset, bool driftingBackdrop = false})` → `Stack[KkBackdrop, Scaffold(saydam)]`.
- `abstract final class KkMotion`: yukarıdaki süreler ve `spring`; `static Duration of(BuildContext, Duration)` (animasyonlar kapalıysa `Duration.zero`).
- `final ambientMotionProvider = Provider<bool>((_) => true)` (`kk_motion.dart`): sürekli hareketleri (kilit ekranı) açar; testler `false` verir.

- [ ] **Adım 1: Başarısız testleri yaz.**
  - `theme_test.dart`: `contrast(a, b)` ve `over(bg, fg)` (alfa karıştırma) yardımcıları. Her iki tema için: her `worstGrounds()` rengi `g` ve hem `g` hem `over(g, fill)` üstünde `onSurface`, `onSurfaceVariant`, `primary`, `error` ≥ 4,5; `KkGlass.accent` ≥ 3,0; `onCta` ile `ctaStart` ve `ctaEnd` ≥ 4,5; `avatarPalette`'in her rengi beyazla ≥ 4,5. Sabit değerler: `AppTheme.light.colorScheme.primary == Color(0xFF9A3A08)`, koyu `0xFFFFA873`, `KkGlass.ground` `0xFFF3EEF4` / `0xFF0C0B10`.
  - `kk_backdrop_test.dart`: `KkBackdrop` 360×800'de iki temada resme çevrilir (`RepaintBoundary.toImage`, `tester.runAsync`); her pikselin bağıl parlaklığı `worstGrounds()` parlaklıklarının en küçüğü ile en büyüğü arasında (±0,01). `drifting: false` iken `pump` sonrası `tester.binding.hasScheduledFrame == false`; `drifting: true` ve `disableAnimations: true` iken de `false`.
- [ ] **Adım 2:** `flutter test test/app` → FAIL.
- [ ] **Adım 3: Uygula.** `ColorScheme` elle verilir (`surface` opak yüzey rengi, `primary` vurgulu yazı, `outlineVariant` kenar). `test/support/fake_vault_service.dart` içindeki `pumpKeyKey` ve entegrasyon testlerindeki `ProviderScope`'lar `ambientMotionProvider.overrideWithValue(false)` alır.
- [ ] **Adım 4:** `flutter test` → PASS. Ekranlar henüz `KkScaffold` kullanmadığı için düz zeminle görünür; saydam `scaffoldBackgroundColor` yüzünden siyah kalan ekran olmaması için bu görevde `MaterialApp.builder` içine geçici olarak `ColoredBox(color: ground)` konur ve Görev 13'ün sonunda kaldırılır.
- [ ] **Adım 5: Commit** `özellik(tema): cam renkleri, zemin ve cam yüzey`.

### Görev 2: Kart, simge kutusu, grup ve liste girişi

**Dosyalar:**
- Değiştir: `lib/app/ui/kk_card.dart`, `lib/app/ui/kk_section.dart`
- Yeni: `lib/app/ui/record_avatar.dart`, `lib/app/ui/kk_entrance.dart`
- Sil: `lib/app/ui/record_watermark.dart`, `test/app/ui/record_watermark_test.dart`
- Test: `test/app/ui/kk_card_test.dart` (yeniden yaz), `test/app/ui/record_avatar_test.dart`, `test/app/ui/kk_entrance_test.dart`

**Arayüzler:**
- Tüketir: `GlassSurface`, `KkGlass`, `KkMotion`.
- Üretir:
  - `KkCard({required Widget title, Widget? subtitle, Widget? leading, Widget? trailing, VoidCallback? onTap, VoidCallback? onLongPress, String? semanticLabel, double minHeight = 64})`. Cam yüzey, dalga efekti, basılıyken 0,98'e küçülme (`KkMotion.fast`). `watermark` parametreleri yok.
  - `String avatarInitial(String name)`: kırpılmış adın ilk karakter kümesi (`Characters`), büyük harf; boşsa `'?'`.
  - `Color avatarColorFor(String name)`: kırpılmış ve küçük harfe çevrilmiş adın FNV-1a 32 bit özeti `% avatarPalette.length`.
  - `RecordAvatar({required LoginContent? login, required String name, double size = 42})`: bağlı uygulamanın simgesi (`appIconProvider`, tam renkli) ya da baş harf kutusu. `ExcludeSemantics` içinde.
  - `KkSection({required String title, required List<Widget> children})` aynı ad; grup tek cam kart (köşe 26), başlık `onSurfaceVariant`. `KkRowSubtitle`, `KkInfoRow` aynı kalır.
  - `KkIconBox({required IconData icon, double size = 36})`: `accentContainer` zeminli, `accent` simgeli kutu (ayar satırları ve "+" kutusu için).
  - `KkEntranceScope({required Widget child})` ve `KkEntrance({required int index, required Widget child})`: kapsamın ilk karesinde kurulan ve `index < 8` olan öğeler 40 ms arayla belirir (saydamlık 0→1, 12 dp yukarı kayma, `KkMotion.base`); sonradan kurulanlar (kaydırma) hareketsizdir.

- [ ] **Adım 1: Başarısız testleri yaz.**
  - `kk_card_test`: normal yazıda yükseklik 64; uzun başlık tek satırda kesilir ve yükseklik değişmez; `textScaler` 2,0'da taşma yok ve kart büyür; `find.byType(BackdropFilter)` → `findsNothing`; `onTap` çağrılır; `trailing` içindeki düğmeye dokunmak `onTap`'i çağırmaz.
  - `record_avatar_test`: `avatarInitial('  posta ') == 'P'`, `avatarInitial('') == '?'`, `avatarInitial('9gag') == '9'`, `avatarInitial('👨‍👩‍👧 aile') == '👨‍👩‍👧'`; `avatarColorFor('GitHub') == avatarColorFor(' github ')`; sonuç hep `avatarPalette` içinde; uygulama simgesi sağlayıcısı bayt verince `Image` çizilir, hata verince baş harfe düşülür; anlam ağacında baş harf yok.
  - `kk_entrance_test`: ilk karede kurulan öğe `pump(KkMotion.base + 400 ms)` sonunda tam görünür; kapsam kurulduktan sonra eklenen öğe ilk karede tam görünür; `disableAnimations` ile hepsi ilk karede tam görünür.
- [ ] **Adım 2:** `flutter test test/app/ui` → FAIL.
- [ ] **Adım 3: Uygula.** `RecordWatermark` kullanan iki yer (`vault_screen.dart`, `otp_code_tile.dart`) bu görevde `leading: RecordAvatar(...)` ile derlenir hale getirilir; görünümleri Görev 6 ve 9'da tamamlanır.
- [ ] **Adım 4:** `flutter test` → PASS.
- [ ] **Adım 5: Commit** `özellik(arayüz): cam kart, kayıt simge kutusu ve liste girişi`.

### Görev 3: Pencere, bildirim, menü ve alt düğme

**Dosyalar:**
- Değiştir: `lib/app/ui/kk_sheet.dart`, `lib/features/generator/presentation/generator_sheet.dart` (`showModalBottomSheet` → `showKkSheet`)
- Yeni: `lib/app/ui/kk_snack.dart`, `lib/app/ui/kk_menu.dart`, `lib/app/ui/kk_bars.dart`
- Test: `test/app/ui/kk_sheet_test.dart` (güncelle), `test/app/ui/kk_snack_test.dart`, `test/app/ui/kk_menu_test.dart`, `test/app/ui/kk_bars_test.dart`

**Arayüzler (üretir):**
- `showKkSheet`, `KkSheetContent`, `showKkConfirm`: imzalar aynı. Pencere güçlü cam ve gerçek bulanıklıkla çizilir, üst köşeler 30, tutamak var; açılış `KkMotion.panelOpen` ve yay eğrisi, kapanış `panelClose` (`sheetAnimationStyle`). Sürükleme Flutter'ın kendi davranışıdır (parmağı izler).
- `void showKkSnack(BuildContext context, String message, {SnackBarAction? action})`: önce `hideCurrentSnackBar`, sonra cam bildirim (gerçek bulanıklık, tam yuvarlak).
- `Future<void> copySensitive(BuildContext context, WidgetRef ref, String value)`: `sensitiveClipboardProvider` ile kopyalar, `showKkSnack(l10n.copiedWillClear(30))` gösterir. `VaultLockedException` yutulur (yönlendirme kilit ekranına gidiyor).
- `KkMenuItem<T>({required T value, required String label, IconData? icon, bool checked = false, bool enabled = true})` ve `KkMenuButton<T>({required String tooltip, required List<KkMenuItem<T>> items, required ValueChanged<T> onSelected, IconData icon = Icons.more_vert_rounded})`: cam daire düğme; açılan menü güçlü cam ve gerçek bulanıklık, köşe 20. Nasıl kurulacağı uygulayıcıya bırakıldı (saydam `PopupMenuButton` içinde tek cam gövde ya da kendi `PopupRoute`'u); geri tuşu kapatır.
- `KkCircleButton({required IconData icon, required String tooltip, required VoidCallback? onPressed, double size = 44})`: cam daire, dokunma alanı en az 48.
- `PreferredSizeWidget kkRootAppBar(BuildContext, {required String title, List<Widget> actions})`: `toolbarHeight` 72, başlık `headlineMedium` ağırlık 800, solda. `PreferredSizeWidget kkAppBar(BuildContext, {String? title, List<Widget> actions, Widget? titleTrailing})`: geri gidilebiliyorsa solda `KkCircleButton(Icons.arrow_back_rounded, tooltip: MaterialLocalizations.backButtonTooltip)`.
- `KkBottomAction({required String label, required VoidCallback? onPressed, bool busy = false})`: tam genişlikte `FilledButton`, yanlardan 16, alttan `viewInsets.bottom + 16` ve güvenli alan; `busy` iken düğmede ilerleme halkası ve `onPressed` etkisiz.

- [ ] **Adım 1: Başarısız testleri yaz.**
  - `kk_sheet_test`: var olan testler kalır; ek: pencerede `BackdropFilter` var; `disableAnimations` ile `pump()` sonrası pencere yerinde.
  - `kk_snack_test`: ikinci çağrı birincinin yerini alır (tek `SnackBar`); `copySensitive` sahte panoya değeri yazar ve "Kopyalandı. Pano 30 saniye sonra temizlenecek." gösterir; pano `VaultLockedException` atarsa hata fırlamaz ve bildirim çıkmaz.
  - `kk_menu_test`: düğme `tooltip` ile bulunur ve ≥ 48×48; dokununca öğeler metinle bulunur; `checked` öğede onay simgesi; öğeye dokunmak `onSelected(value)` çağırır ve menüyü kapatır; `enabled: false` öğe çağırmaz; menü açıkken `BackdropFilter` var.
  - `kk_bars_test`: `kkAppBar` kökte geri düğmesi göstermez, itilmiş sayfada gösterir ve dokununca `maybePop` çalışır; `KkBottomAction` klavye açıkken (`viewInsets.bottom = 300`) klavyenin üstünde durur (`getRect(button).bottom <= 800 - 300`); `busy` iken dokunuş çağırmaz.
- [ ] **Adım 2:** `flutter test test/app/ui` → FAIL.
- [ ] **Adım 3: Uygula.**
- [ ] **Adım 4:** `flutter test` → PASS (üretici penceresi testleri dahil).
- [ ] **Adım 5: Commit** `özellik(arayüz): cam pencere, bildirim, menü ve alt düğme`.

### Görev 4: Alt menü

**Dosyalar:**
- Değiştir: `lib/app/ui/glass_nav_bar.dart`
- Test: `test/app/ui/glass_nav_bar_test.dart` (yeniden yaz)

**Arayüzler (üretir):**
- `GlassNavItem` aynı. `GlassNavBar({required int selectedIndex, required ValueChanged<int> onSelected, required List<GlassNavItem> items, required VoidCallback onAdd, required bool addOpen, required String addLabel, required String closeLabel})`.
- `GlassNavBar.height = 64`, `bottomGap = 16`, `pillKey` (aynı), `addKey = Key('glass-nav-add')`. `kNavClearance` ve `navClearance(context)` yeni yüksekliğe göre aynı adlarla kalır.
- Düzen: güçlü cam, gerçek bulanıklık, tam yuvarlak şerit; sekmeler, 1 dp dikey ayraç, sonda 48 dp turuncu geçişli yuvarlak "+" (simge `onCta`). Seçili sekme `capsule` zeminli kapsülde simge (`accent`) ve ad (`onSurface`, kalın); diğerleri yalnızca simge. Seçim değişince kapsül ve genişlikler `KkMotion.base` ile kayar. `addOpen` iken "+" 45° döner (`KkMotion.base`).
- Anlam: sekmeler bugünkü gibi `"<ad>\nSekme i/3"`, `selected`, `button`; "+" düğmesi `button`, etiketi `addOpen ? closeLabel : addLabel`.
- Ad, `MediaQuery.textScalerOf(context).scale(10) > 13` ise ya da şerit ekrana sığmıyorsa gizlenir.

- [ ] **Adım 1: Başarısız testleri yaz.** Seçili sekmenin adı görünür, diğerlerinin görünmez; seçim değişince `pumpAndSettle` sonrası yeni sekmenin adı görünür; şerit yüksekliği 64 ve alttan 16 + sistem boşluğu; her sekme ve "+" ≥ 48×48; anlam etiketleri `Kasa\nSekme 1/3` ve "+" için `Ekle`, `addOpen: true` iken `Kapat`; `onAdd` çağrılır; şeritte `BackdropFilter` var; **320×640 ekranda ve `textScaler` 2,0'da** şerit ekranın içinde (`pill.left >= 0`, `pill.right <= 320`), "+" görünür ve taşma hatası yok; açık ve koyu temada `meetsGuideline(textContrastGuideline)`.
- [ ] **Adım 2:** `flutter test test/app/ui/glass_nav_bar_test.dart` → FAIL.
- [ ] **Adım 3: Uygula.** `AppShell` bu görevde yeni parametrelerle derlenir (`onAdd` boş, `addOpen: false`); kutu Görev 5'te bağlanır.
- [ ] **Adım 4:** `flutter test` → PASS (`settings_test` içindeki menü boşluğu testi dahil).
- [ ] **Adım 5: Commit** `özellik(menü): adlı kapsül ve "+" düğmeli cam alt menü`.

### Görev 5: "+" kutusu, kabuk ve yönlendirme

**Dosyalar:**
- Yeni: `lib/app/ui/add_panel.dart`
- Değiştir: `lib/app/app_shell.dart`, `lib/app/router.dart`, `lib/features/vault/presentation/vault_screen.dart` (FAB silinir), `lib/features/authenticator/presentation/authenticator_screen.dart` (FAB, `_AddOption`, `_showAddOptions` silinir), `lib/l10n/app_tr.arb`, `app_en.arb`
- Test: `test/app/add_panel_test.dart` (yeni), `test/app/app_test.dart`; "Ekle"ye dokunan testler güncellenir: `vault_screens_test`, `authenticator_screens_test`, `import_screen_test`, `qr_scan_test`, `generator_sheet_test`, `integration_test/otp_flow_test.dart`, `vault_flow_test.dart` ve "Ekle" kullanan diğer entegrasyon testleri

**Arayüzler:**
- Tüketir: `GlassNavBar` (Görev 4), `GlassSurface`, `KkIconBox`, `KkMotion`, `readQrFromImage(context, ref, replace: false)`, `importFromFile(context, ref)`.
- Üretir:
  - `enum AddChoice { password, otpScan, otpImage, otpManual, otpImport }`
  - `AddPanel({required bool passwordEnabled, required bool otpEnabled, required ValueChanged<AddChoice> onChosen, required VoidCallback onDismiss})`: karartma (siyah `scrim` ve gerçek bulanıklık, dokununca `onDismiss`) ve menünün hemen üstünde güçlü cam kutu. İlk sayfa: **Parola** / **2FA kodu** satırları (tam genişlik, `KkIconBox`, ad, kısa açıklama, en az 64 dp). "2FA kodu" kutunun içeriğini ikinci sayfaya kaydırır: başlıkta geri oku (`tooltip: addBack`) ve dört satır (bugünkü `otpAddScan`, `otpAddImage`, `otpAddManual`, `otpAddImport` metinleri). Açılış `panelOpen` + yay, satırlar 40 ms arayla belirir, kapanış `panelClose`. Kutu `Semantics(scopesRoute: true, namesRoute: true, label: addTitle)`.
  - `AppShell`: `ConsumerStatefulWidget`. Sekme değişince içerik `KkMotion.fast` süresinde saydamlık 0,6 → 1 ile belirir. Kutu açıkken gövde ve sekmeler `ExcludeSemantics` içindedir; `BackButtonListener` ve `PopScope(canPop: !open)` geri tuşuyla kutuyu kapatır. Seçim işlenirken ikinci seçim yok sayılır (`_handling` bayrağı).
  - Seçim → eylem (`GoRouter.of(context)`): `password` → `go(AppRoutes.vaultNew)`; `otpManual` → `go(AppRoutes.authenticatorNew)`; `otpScan` → `go(AppRoutes.authenticatorScan)`; `otpImage` → `go(AppRoutes.authenticator)` sonra `readQrFromImage`; `otpImport` → `go(AppRoutes.authenticator)` sonra `importFromFile`. `go` ilgili sekmeye geçer ve o sekmeyi listesine indirir; form kapanınca listeye dönülür.
  - `passwordEnabled` = `loginsControllerProvider is LoginsLoaded`; `otpEnabled` = `otpsControllerProvider is OtpsLoaded`.
  - `router.dart`: `GoRouter(navigatorKey: rootNavigatorKey)`; şu yollar `parentNavigatorKey: rootNavigatorKey` alır (alt menünün üstünü örterler): `/kasa/yeni`, `/kasa/kayit/:id/duzenle`, `/2fa/yeni`, `/2fa/hesap/:id/duzenle`, `/2fa/ice-aktar`, `/ayarlar/parola`, `/ayarlar/ice-aktar`. Diğerleri kabukta kalır.
  - Yeni metinler (TR / EN): `addTitle` "Ne eklemek istiyorsun?" / "What do you want to add?"; `addPassword` "Parola" / "Password"; `addPasswordHint` "Site ya da uygulama girişi" / "A site or app sign-in"; `addOtp` "2FA kodu" / "2FA code"; `addOtpHint` "QR tara, elle gir ya da içe aktar" / "Scan a QR code, type it in or import"; `addBack` "Geri" / "Back"; `addClose` "Kapat" / "Close". "+" etiketi var olan `vaultAdd` ("Ekle").

- [ ] **Adım 1: Başarısız testleri yaz** (`add_panel_test.dart`, `pumpKeyKey` ile):
  - Üç sekmenin her birinde "Ekle"ye dokununca "Parola" ve "2FA kodu" satırları görünür; "+" etiketi "Kapat" olur.
  - Kasa, 2FA ve Ayarlar sekmesinden "Parola" → konum `/kasa/yeni`, `GlassNavBar` ekranda yok; geri → `/kasa`, seçili sekme Kasa.
  - "2FA kodu" → dört satır; "Anahtarı elle gir" → `/2fa/yeni`; "QR kodu tara" → `/2fa/tara`; "Geri" oku ilk iki satıra döner.
  - Karartmaya dokunmak, "Kapat" ve geri tuşu (`tester.binding.handlePopRoute()`) kutuyu kapatır; konum değişmez. Ayrıntı ekranı açıkken geri tuşu önce kutuyu kapatır, ayrıntı ekranı açık kalır.
  - Kayıtlar yüklenmemişken (`LoginsLoading`) "Parola" satırı etkisiz; hesaplar yüklenmemişken "2FA kodu" etkisiz.
  - "Parola"ya art arda iki `tap` (arada `pump` yok) → yığında tek `LoginEditScreen`.
  - Kutu açıkken kasa kilitlenir, yeniden açılır → kutu kapalı.
  - Kutu açıkken anlam ağacında liste öğeleri yok, kutunun satırları ve "Kapat" var.
  - `disableAnimations` ile kutu tek `pump()` sonrası tam açık.
  - Form yolları (yukarıdaki yedi yol) açıkken `find.byType(GlassNavBar)` → `findsNothing`; `/kasa/rapor`, `/kasa/cop`, `/2fa/tara` açıkken `findsOneWidget`.
- [ ] **Adım 2:** `flutter test test/app` → FAIL.
- [ ] **Adım 3: Uygula.** Listelerdeki `navClearance(context) + 72` → `navClearance(context)` (ayrı düğme kalmadı).
- [ ] **Adım 4: Eski testleri güncelle.** `find.text('Ekle')` ile form açan her test "Ekle" (anlam etiketi) → "Parola" ya da "2FA kodu" → ilgili satır yolunu izler; bunun için `test/support/` altına `Future<void> openAddPassword(WidgetTester)` ve `openAddOtp(WidgetTester, String way)` yardımcıları eklenir, entegrasyon testlerinde aynısı kullanılır.
- [ ] **Adım 5:** `flutter test` → PASS.
- [ ] **Adım 6: Commit** `özellik(ekleme): her sekmede tek "+" ve tür seçimi`.

### Görev 6: Kasa ekranı

**Dosyalar:**
- Değiştir: `lib/features/vault/presentation/vault_screen.dart`, `lib/features/backup/presentation/backup_reminder_banner.dart`, `resources/docs/guvenlik-tasarimi.md` ("Pano" bölümüne bir cümle: parola kasa listesinden de kopyalanabilir, aynı kurallarla), arb dosyaları
- Test: `test/features/vault/vault_screens_test.dart`, `test/features/backup/backup_reminder_test.dart` (görünüm değişirse)

**Arayüzler:**
- Tüketir: `KkScaffold`, `kkRootAppBar`, `KkMenuButton`, `KkCard`, `RecordAvatar`, `KkEntranceScope`/`KkEntrance`, `copySensitive`.
- Üretir: Hero etiketi `'login-avatar-<idHex>'` (Görev 7 ayrıntı ekranında aynısını kullanır). Yeni metinler: `vaultSearchCount` "{count} kayıtta ara" / "Search {count} items" (çoğul kuralıyla), `vaultCopyPassword` "Parolayı kopyala" / "Copy password", `screenMore` "Diğer işlemler" / "More actions".

Davranış:
- Üst: `kkRootAppBar(title: navVault)`, sağda tek `KkMenuButton` (`tooltip: screenMore`): "Ada göre sırala" ve "Son değişene göre sırala" (seçili olanda onay), "Parola raporu" (kayıtlar yüklenmeden etkisiz), "Çöp kutusu".
- Arama kutusu tam yuvarlak cam; etiketi kayıt varken `vaultSearchCount(n)` (çöptekiler sayılmaz), yokken `vaultSearch`.
- Süzgeç satırı yalnızca çöpte olmayan en az bir favori ya da en az bir klasör varken çizilir. "Favoriler" yongası yalnızca favori varken, klasör yongaları klasör varken. Etkin süzgecin dayanağı kalmazsa (son favori kaldırıldı, klasör boşaldı) süzgeç sıfırlanır.
- Kart: `KkCard(minHeight: 64)`, `leading: Hero(RecordAvatar)`, başlık ad (favoriyse yanında 14 dp `accent` yıldız, `semanticLabel: favoriteMark`), alt yazı kullanıcı adı, `trailing`: parola boş değilse `IconButton(Icons.copy_rounded, tooltip: vaultCopyPassword)` → `copySensitive(context, ref, content.password)`.
- Yedek uyarısı ve okunamayan kayıt uyarısı listenin üstünde cam kart; uyarı simgesi `error` renginde. İlk açılışta kartlar `KkEntrance` ile belirir.

- [ ] **Adım 1: Başarısız testleri yaz / güncelle.**
  - Menü: "Diğer işlemler" → "Çöp kutusu" çöp ekranını açar; "Son değişene göre sırala" sırayı değiştirir ve yeniden açınca onaylı görünür; `find.byTooltip('Çöp kutusu')` artık yok.
  - Arama etiketi: 2 kayıtla "2 kayıtta ara"; boş kasada "Ara".
  - Süzgeç: favori ve klasör yokken `find.byType(FilterChip)` → `findsNothing`; bir kayıt favori olunca "Favoriler" görünür; "Favoriler" seçiliyken son favori kaldırılınca bütün kayıtlar yeniden listelenir.
  - Kopyalama: "Parolayı kopyala"ya dokununca sahte panoda parola var, bildirim görünür ve konum hâlâ `/kasa`; parolası boş kayıtta düğme yok; pano `VaultLockedException` atınca hata yok.
  - Kart yüksekliği 64; favori kayıtta "Favori" anlam etiketi var.
- [ ] **Adım 2:** `flutter test test/features/vault` → FAIL.
- [ ] **Adım 3: Uygula.**
- [ ] **Adım 4:** `flutter test` → PASS (erişilebilirlik testi dahil, dört görünümde).
- [ ] **Adım 5: Commit** `özellik(kasa): cam kartlar, listeden kopyalama ve tek menü`.

### Görev 7: Kayıt ayrıntısı

**Dosyalar:**
- Değiştir: `lib/features/vault/presentation/login_detail_screen.dart`, `lib/features/authenticator/presentation/linked_otp_tile.dart`, arb dosyaları
- Test: `test/features/vault/vault_screens_test.dart`, `test/features/authenticator/otp_link_test.dart`

Davranış:
- `KkScaffold` + `kkAppBar` (başlık yok); sağda `KkCircleButton(Icons.edit_rounded, tooltip: loginEdit)` ve `KkMenuButton` (`screenMore`): "Favorilere ekle" / "Favorilerden çıkar", "Çöp kutusuna taşı".
- Üstte ortada 72 dp `Hero(tag: 'login-avatar-<idHex>', RecordAvatar(size: 72))`, altında ad (`headlineSmall`, kalın) ve ilk site (ikincil yazı).
- Her alan kendi `GlassSurface` kartında: küçük etiket, değer, sağda `IconButton` "Kopyala" (`copySensitive`), gizli alanlarda ayrıca "Göster"/"Gizle". Gizliyken anlam etiketi `secretConcealed` (bugünkü gibi).
- Bağlı 2FA kartı: kod `headlineMedium`, eş aralıklı; süre göstergesi Görev 9'da halkaya çevrilir.
- Parola geçmişi açılır kart olarak kalır. En altta ortalı ikincil yazı: `loginLastChanged` "Son değişiklik: {date}" / "Last changed: {date}" (kaydın güncelleme zamanı, `formatMediumDate`).
- Kayıt bulunamadı ve yükleniyor durumları `KkScaffold` içinde aynı kalır.

- [ ] **Adım 1: Testleri güncelle / yaz.** Favori ve çöp işlemleri menüden yapılır (`byTooltip('Favorilere ekle')` → menü öğesi); "Düzenle" düğmesi form açar ve `GlassNavBar` görünmez; listedeki ve ayrıntıdaki simge kutusu aynı Hero etiketini taşır; "Son değişiklik" metni görünür; kopyalama `copySensitive` yolundan geçer (sahte pano ve bildirim); var olan gizle/göster ve geçmiş testleri geçer.
- [ ] **Adım 2:** FAIL gör. **Adım 3:** Uygula (`_copy` kopyaları silinir). **Adım 4:** `flutter test` → PASS.
- [ ] **Adım 5: Commit** `özellik(kasa): cam kayıt ayrıntısı`.

### Görev 8: Parola formu

**Dosyalar:**
- Yeni: `lib/app/ui/kk_form.dart`
- Değiştir: `lib/features/vault/presentation/login_edit_screen.dart`, `lib/features/generator/presentation/password_strength_meter.dart` (görünüm), arb dosyaları
- Test: `test/app/ui/kk_form_test.dart`, `test/features/vault/vault_screens_test.dart`, `test/features/generator/generator_sheet_test.dart`

**Arayüzler (üretir, Görev 10 da kullanır):**
- `KkFieldCard({required Widget child, VoidCallback? onRemove, String? removeTooltip})`: alanı saran cam kart; `onRemove` verilirse sonda küçük kaldırma düğmesi (48 dp dokunma alanı).
- `KkMoreOptions({required List<KkOption> options})`, `KkOption({required String label, required VoidCallback onAdd})`: "Daha fazla seçenek" satırı (dokununca açılır, `KkMotion.base`); açıkken her seçenek başında "+" olan cam yonga. `options` boşsa hiçbir şey çizmez.
- Yeni metinler: `formMoreOptions` "Daha fazla seçenek" / "More options"; `formFolder` "Klasör" / "Folder"; `formNote` "Not" / "Note"; `formCustomField` "Özel alan" / "Custom field"; `formAnotherSite` "Başka site" / "Another site"; `formRemoveField` "Alanı kaldır" / "Remove field"; `loginGenerate` "Üret" / "Generate".

Davranış:
- `KkScaffold`, `kkAppBar(title: yeni/düzenle başlığı, titleTrailing: RecordAvatar(login: toplanan içerik, name: _name.text, size: 36))` (ad yazıldıkça güncellenir), `bottomNavigationBar: KkBottomAction(label: loginSave, onPressed: ad boşsa null, busy: _saving)`. Üst çubuktaki "Kaydet" silinir.
- Her zaman görünen dört kart: Ad, Kullanıcı adı, Parola (göster düğmesi, "Üret" yazılı vurgu zeminli düğme → `showGeneratorSheet`, altında güç çubuğu), Site (ilk adres).
- Ek alanlar: Klasör, Not, Özel alan (çok), Başka site (çok). Bir ek alan **doluysa ya da kullanıcı yongasından eklediyse** formda görünür. Yongalar: "Klasör" ve "Not" yalnızca o alan görünmüyorken; "Özel alan" ve "Başka site" her zaman.
- Yongaya dokununca alan eklenir ve odak ona geçer. Ek alanın kaldırma düğmesi alanı boşaltır, gizler ve formu "değişti" sayar.
- Bağlı uygulama satırları ve kaldırma düğmeleri bugünkü gibi (cam kartta). Kaydedilmemiş değişiklik sorusu ve `_save` mantığı değişmez.

- [ ] **Adım 1: Başarısız testleri yaz.**
  - `kk_form_test`: kapalıyken yongalar yok; satıra dokununca görünür; yongaya dokununca `onAdd`; boş `options` ile hiçbir şey yok; `textScaler` 2,0'da taşma yok.
  - Yeni kayıt: yalnızca dört alan (`find.text('Klasör')`, `'Notlar'` yok); "Daha fazla seçenek" → "Not" → not alanı görünür ve odaktadır, "Not" yongası kaybolur; "Başka site" iki kez → toplam üç adres alanı.
  - Düzenleme (klasörü ve notu dolu, iki adresli, bir özel alanlı kayıt): hepsi "Daha fazla"ya dokunmadan görünür; yongalarda "Klasör" ve "Not" yok.
  - Kaldırma: dolu notun "Alanı kaldır" düğmesi alanı gizler; geri → kaydedilmemiş değişiklik sorusu; "Kaydet" → kayıtta `notes == ''`.
  - "Kaydet" altta; ad boşken etkisiz; klavye açıkken klavyenin üstünde; `GlassNavBar` yok.
  - "Üret" üretici penceresini açar ve seçilen parola alana yazılır (var olan test yeni düğmeyle).
- [ ] **Adım 2:** FAIL gör. **Adım 3:** Uygula. **Adım 4:** `flutter test` → PASS.
- [ ] **Adım 5: Commit** `özellik(kasa): sade parola formu, ek alanlar istenince`.

### Görev 9: 2FA ekranı ve kartı

**Dosyalar:**
- Yeni: `lib/features/authenticator/presentation/otp_ring.dart`
- Değiştir: `authenticator_screen.dart`, `otp_code_tile.dart`, `otp_gate.dart`, `linked_otp_tile.dart` (halka), arb dosyaları
- Test: `test/features/authenticator/authenticator_screens_test.dart`, `otp_gate_test.dart`

**Arayüzler (üretir):**
- `OtpRing({required Duration remaining, required int period, double size = 34})`: süreyle azalan `accent` halka, ortasında saniye; son 5 saniyede `error` rengi. Anlam: `otpSecondsLeft(seconds)`, ilerleme çubuğu rolü yok (bugünkü kural).
- `OtpTileAction` aynı.

Davranış:
- `kkRootAppBar(title: navAuthenticator)`, `KkMenuButton`: "Kodlar tutmuyor mu?", "Çöp kutusu". Arama kutusu Kasa'daki gibi.
- Kart `KkCard(minHeight: 72)`: `leading` `RecordAvatar(login: bağlı kayıt, name: sağlayıcı ya da hesap)`; üstte küçük "Sağlayıcı · hesap" (favoriyse yıldız), altında büyük eş aralıklı kod (`headlineSmall`, `onSurface`), sıradaki kod bugünkü eşikte küçük yazıyla; `trailing` `OtpRing`. Dokununca `copySensitive`.
- HOTP: kod üretilmemişse kodun yerinde `TextButton` "Kod üret" (`otpGenerate`); üretilmişse kod ve sonda yenileme düğmesi.
- **Kart işlemleri (Düzenle, Favori, Çöp kutusuna taşı):** karttaki üç nokta kalkar; karta uzun basınca cam pencerede açılır. TalkBack için kartta aynı üç işlem `customSemanticsActions` olarak da bulunur (tasarım belgesi, "Davranış değişiklikleri" 8. madde).
- `OtpGate` (kodlar gizli) ortada cam kartta, tek ana düğmeyle. Büyük yazıda (`scale(10) > 13`) kod bugünkü gibi adın altına iner.

- [ ] **Adım 1: Testleri güncelle / yaz.** Kart yüksekliği 72; koda dokunmak kopyalar; halka etiketi "… saniye kaldı"; HOTP'de "Kod üret" metin düğmesi (`byTooltip` → `text`); uzun basınca "Düzenle", "Favorilere ekle", "Çöp kutusuna taşı" görünür ve her biri bugünkü işi yapar; anlam ağacında üç özel işlem var; menüden "Çöp kutusu" ve "Kodlar tutmuyor mu?" açılır; `textScaler` 2,0'da taşma yok.
- [ ] **Adım 2:** FAIL gör. **Adım 3:** Uygula. **Adım 4:** `flutter test` → PASS.
- [ ] **Adım 5: Commit** `özellik(2fa): cam kod kartları ve süre halkası`.

### Görev 10: 2FA formu ve içe aktarma ekranları

**Dosyalar:**
- Değiştir: `otp_edit_screen.dart`, `login_picker.dart`, `otp_import_screen.dart`, `lib/features/backup/presentation/login_import_screen.dart`, `lib/features/settings/presentation/change_password_screen.dart`
- Test: `authenticator_screens_test.dart`, `import_screen_test.dart`, `login_import_screen_test.dart`, `settings_test.dart`

Davranış:
- 2FA formu: `KkScaffold`, `kkAppBar`, altta `KkBottomAction(loginSave)`. Görünen üç kart: Sağlayıcı, Hesap, Gizli anahtar ("Yapıştır" yazılı vurgu zeminli düğme; bugünkü doğrulama ve hata metinleri). `KkMoreOptions`: "Not", "Bağlı kayıt", "Gelişmiş ayarlar" (`otpAdvanced`). Düzenlemede notu dolu, kaydı bağlı ya da varsayılandan farklı gelişmiş ayarı olan hesapta ilgili bölüm doğrudan görünür. QR'dan gelen hesapta (`initial`) varsayılandan farklı ayar varsa gelişmiş bölüm açık gelir (bugünkü `_showAdvanced` kuralı).
- Onay penceresi (`_confirmDiscard`) `showKkConfirm` kullanır (bugün `AlertDialog` düzeninde kalmış).
- İçe aktarma ekranları ve ana parolayı değiştirme: `KkScaffold`, `kkAppBar`, içerik cam kartlarda, ana işlem altta `KkBottomAction`. Akış, metinler ve doğrulamalar değişmez.

- [ ] **Adım 1: Testleri güncelle / yaz.** Yeni 2FA formunda yalnızca üç alan; "Daha fazla seçenek" → "Gelişmiş ayarlar" tür/algoritma/basamak/süre alanlarını açar; HOTP hesabı düzenlenirken gelişmiş bölüm açık; "Kaydet" altta; geçersiz anahtarda bugünkü hata; içe aktarma ve parola değiştirme testleri yeni düğme yerleriyle geçer; yedi form yolunda `GlassNavBar` yok.
- [ ] **Adım 2:** FAIL gör. **Adım 3:** Uygula. **Adım 4:** `flutter test` → PASS.
- [ ] **Adım 5: Commit** `özellik(formlar): sade 2FA formu ve cam içe aktarma ekranları`.

### Görev 11: Ayarlar

**Dosyalar:**
- Değiştir: `settings_screen.dart`, `lib/features/backup/presentation/backup_section.dart`, `lib/features/autofill/presentation/autofill_setup_section.dart`, `lib/app/licenses.dart` (gerekirse), arb dosyaları
- Yeni: `lib/features/backup/presentation/backup_status_card.dart`
- Test: `settings_test.dart`, `backup_section_test.dart`

**Arayüzler (üretir):**
- `BackupStatusCard()`: cam kart; solda `KkIconBox(Icons.cloud_done_rounded` ya da yedek yokken `Icons.cloud_off_rounded)`, metin `backupStatusNever` "Henüz yedek yok" / "No backup yet", `backupStatusToday` "Son yedek bugün" / "Last backup today", `backupStatusDays` "Son yedek {count} gün önce" / "Last backup {count} days ago"; sağda `FilledButton` `backupStatusAction` "Yedekle" / "Back up" → `backUpVault(context, ref)`; çalışırken düğme meşgul. Yanında (i) düğmesi bugünkü `backupHelp` metnini pencerede açar.

Davranış:
- `kkRootAppBar(title: navSettings)`. En üstte `BackupStatusCard`, altında dört `KkSection`. "Yedek ve aktarım" grubundan "Yedek al" satırı çıkar; diğer dört satır kalır.
- Her satır: `leading: KkIconBox(...)`, başlık, sonda Material 3 anahtarı ya da `Icons.chevron_right_rounded`; (i) düğmeleri bugünkü gibi. Satır en az 64 dp.
- Lisanslar sayfası Flutter'ın kendi `Scaffold`'unu kullanır; saydam zeminde siyah kalmaması için opak `ground` verilmiş bir `Theme` içinde açılır (test: sayfadaki `Scaffold`'un zemini saydam değil).

- [ ] **Adım 1: Testleri güncelle / yaz.** Yedek yokken "Henüz yedek yok"; 12 gün önceki yedekle "Son yedek 12 gün önce"; bugünkü yedekle "Son yedek bugün"; "Yedekle" sahte dosya seçiciyle yedek alır ve metin güncellenir; "Yedek ve aktarım" grubunda "Yedek al" satırı yok, diğer dört satır var; satırlar aynı boyda (64); son satır menünün üstünde biter (var olan test, yeni yükseklikle); (i) pencereleri açılır.
- [ ] **Adım 2:** FAIL gör. **Adım 3:** Uygula. **Adım 4:** `flutter test` → PASS.
- [ ] **Adım 5: Commit** `özellik(ayarlar): üstte yedek kartı ve cam gruplar`.

### Görev 12: Kilit, kurulum ve kurtarma

**Dosyalar:**
- Değiştir: `lock_screen.dart`, `recovery_screen.dart`, `new_password_screen.dart`, `new_password_fields.dart`, `unavailable_screen.dart`, `lib/features/onboarding/presentation/onboarding_screen.dart`, `lib/features/backup/presentation/restore_screen.dart`, `lib/app/ui/kk_backdrop.dart` (kayan lekeler)
- Test: `test/features/lock/lock_flow_test.dart`, `onboarding_flow_test.dart`, `restore_screen_test.dart`, `kk_backdrop_test.dart`

Davranış:
- Kilit: `KkScaffold(driftingBackdrop: ambient)`; `ambient = ref.watch(ambientMotionProvider) && !disableAnimations`. Ortada `KeyKeyLogo(size: 88)` (ambient iken 3 s'de 4 dp süzülür), "Kasa kilitli" (`lockTitle`), tek cam parola kutusu, tam genişlik `FilledButton` "Kilidi aç". Parmak izi hazırsa altında 56 dp `KkCircleButton(Icons.fingerprint_rounded, tooltip: lockUseBiometric)`. En altta `TextButton` "Parolamı unuttum". Bekleme süresi ve hata metinleri aynı.
- Yanlış parolada parola kutusu 300 ms yatay titrer (animasyonlar kapalıysa titremez); hata metni bugünkü gibi görünür.
- `KkBackdrop(drifting: true)`: lekeler 24 s'lik döngüde merkezlerinden en çok genişliğin %6'sı kadar kayar; `TickerMode` kapalıyken ve animasyonlar kapalıyken durur.
- `LockScreen(compact: true)` (doldurma penceresindeki kilit) kendi zeminini çizmez, kaymaz.
- Kurulum, yedekten kurulum, kurtarma, yeni parola ve "kullanılamıyor" ekranları: `KkScaffold`, solda büyük başlık, içerik cam kartlarda, tek ana düğme. Adımlar, metinler ve doğrulamalar değişmez.

- [ ] **Adım 1: Testleri güncelle / yaz.** Parmak izi düğmesi `byTooltip` ile bulunur ve açar; yanlış parolada hata metni var ve `pumpAndSettle` biter (titreme sonlu); `ambientMotionProvider` `true` iken kilit ekranında `pump(1 s)` sonrası kare bekleniyor, `disableAnimations` ile beklenmiyor; kilit, kurulum ve kurtarma akış testleri geçer.
- [ ] **Adım 2:** FAIL gör. **Adım 3:** Uygula. **Adım 4:** `flutter test` → PASS.
- [ ] **Adım 5: Commit** `özellik(kilit): cam kilit ekranı ve kurulum ekranları`.

### Görev 13: Kalan ekranlar

**Dosyalar:**
- Değiştir: `password_report_screen.dart`, `trash_screen.dart`, `otp_trash_screen.dart`, `qr_scan_screen.dart`, `generator_sheet.dart`, `plaintext_export.dart`, `confirm_identity.dart`, `scanned_code_handler.dart` (pencereler), `lib/app/app.dart` (Görev 1'deki geçici `ColoredBox` kaldırılır)
- Test: ilgili ekran testleri; `test/accessibility/accessibility_test.dart`

Davranış: her ekran `KkScaffold` + `kkAppBar`; listeler `KkCard`; satır işlemleri bugünkü düğmelerle (çöp kutularındaki "Geri al" ve "Kalıcı olarak sil" ipuçları aynı); onaylar `showKkConfirm`; bildirimler `showKkSnack`. Parola üretici penceresinde üretilen parola büyük, eş aralıklı ve cam kartta; ayarları Material 3 anahtar ve kaydırıcı. QR tarama ekranında kamera görüntüsünün üstündeki açıklama ve düğmeler güçlü cam.

- [ ] **Adım 1: Tarama testi yaz** (`test/app/screens_use_kk_scaffold_test.dart`): `lib/features/**/presentation/*.dart` ve `lib/app/*.dart` dosyalarında `Scaffold(` geçen her satır ya `KkScaffold(` ya da dosya `autofill_sheet_frame.dart` / `kk_backdrop.dart`; `showModalBottomSheet(` yalnızca `kk_sheet.dart` içinde; `AlertDialog` ve `showDialog(` hiçbir yerde; `RecordWatermark` hiçbir yerde.
- [ ] **Adım 2:** FAIL gör. **Adım 3:** Uygula; her ekranın kendi testleri güncellenir.
- [ ] **Adım 4:** `flutter test` → PASS. Erişilebilirlik testinin dört görünümü (açık/koyu × normal/%200) bütün yollar için geçer; geçmezse renk değil bileşen düzeltilir.
- [ ] **Adım 5: Commit** `özellik(arayüz): kalan ekranlar cam dile taşındı`.

### Görev 14: Otomatik doldurma penceresi

**Dosyalar:**
- Değiştir: `autofill_sheet_frame.dart`, `autofill_pick_screen.dart`, `autofill_save_screen.dart`, `fill_confirm.dart`, `autofill_app.dart`
- Test: `test/features/autofill/autofill_screens_test.dart`, `fill_warnings_test.dart`

Davranış:
- Pencere arkadaki uygulamayı bulanıklaştırmaz: kendi opak zeminini (`ground`) ve köşelerine kırpılmış `KkBackdrop`'u çizer; üst köşeler 30. Karartma, boy oranları, kapatma hızı ve `handleKey` aynı.
- Açılış: pencere alttan `panelOpen` ve yay eğrisiyle yükselir (animasyonlar kapalıysa anında). Tutamaç sürüklenirken pencere parmağı izler; bırakınca hız `dismissVelocity`'yi ya da çekme pencerenin yarısını geçtiyse kapanır, yoksa yerine döner.
- Üst satır: tutamaç, 28 dp `KeyKeyLogo`, başlık ("Doldur" / bugünkü başlıklar), sağında eşleşme sayısı (ikincil yazı), kapatma düğmesi. Kayıtlar `KkCard` + `RecordAvatar`; en altta "Başka bir kayıt ara" cam satırı.
- Uyarı, onay, imza ve alan adı kuralları, doğrudan doldurma ve bildirim **değişmez**; Kotlin tarafına dokunulmaz.

- [ ] **Adım 1: Testleri güncelle / yaz.** Var olan 1100 satırlık akış testleri davranış değişmeden geçmeli (yalnızca bileşen türü değişen bulucular güncellenir); ek: pencerede `BackdropFilter` yok; tutamacı yavaşça 40 dp çekip bırakınca pencere yerine döner ve `onDismiss` çağrılmaz; yarıdan fazla çekince çağrılır; açık ve koyu temada `textContrastGuideline`.
- [ ] **Adım 2:** FAIL gör. **Adım 3:** Uygula. **Adım 4:** `flutter test` → PASS.
- [ ] **Adım 5: Commit** `özellik(otomatik-doldurma): cam doldurma penceresi`.

### Görev 15: Geri hareketi, temizlik ve cihaz denemesi

**Dosyalar:**
- Değiştir: `android/app/src/main/AndroidManifest.xml` (`MainActivity`'ye `android:enableOnBackInvokedCallback="true"`), `lib/app/theme.dart` (`pageTransitionsTheme`: Android için `PredictiveBackPageTransitionsBuilder`), `resources/yol-haritasi.md`, `resources/CHANGELOG.md` (yeri farklıysa var olan dosya), `resources/docs/tasarim-yenileme-plani.md` (başına "yerini cam planı aldı" notu)
- Test: `integration_test/*` (yeni düğme yerleri), `integration_test/performance_test.dart`

- [ ] **Adım 1: Geri hareketi.** Ayarı ve geçişi ekle. `flutter test` → PASS. Emülatörde (API 34 ve 37) elle: formda değişiklik varken kenardan geri → soru soruluyor; "+" kutusu açıkken geri → kutu kapanıyor; kökte geri → uygulama arka plana gidiyor. **Bunlardan biri bozulursa** ayar ve geçiş geri alınır, durum yol haritasına ve kullanıcıya yazılır (sessizce bırakılmaz).
- [ ] **Adım 2: Ölü kod taraması.** `grep -rn "watermark\|Watermark\|vault-add\|otp-add\|cream\|darkCream" lib test integration_test` → sonuç yok. `flutter analyze` → sorun yok. Kullanılmayan arb anahtarları (`otpAddTitle` gibi) silinir, `flutter gen-l10n`.
- [ ] **Adım 3: Performans.** `integration_test/performance_test.dart` içinde kasa listesi (200 kayıt) kaydırma ölçümü API 30 emülatöründe çalıştırılır; ortalama kare süresi ilk turdaki değerden kötüyse lekelerin `RepaintBoundary`'si ve karttaki gölge gözden geçirilir. Sonuç yol haritasına yazılır.
- [ ] **Adım 4: Tam kontrol.** `dart format …`, `flutter analyze`, `flutter test` → hepsi temiz. `flutter test integration_test -d <cihaz>` API 30, 34 ve 37 emülatörlerinde (her seferinde tek derleme, zaman sınırıyla; sonra `./gradlew --stop`).
- [ ] **Adım 5: Görsel denetim.** Yayın derlemesi emülatöre kurulur; on örnek ekranın karşılığı açık ve koyu temada ekran görüntüsüyle `cam-tasarim-ornekleri.html` ile karşılaştırılır; "animasyonları kaldır" açıkken bir tur atılır; farklar düzeltilir.
- [ ] **Adım 6: Belgeler.** Yol haritasında Faz 9 durumu ve tarih; CHANGELOG'a "Yeni görünüm" maddeleri (tek "+", listeden kopyalama, sade formlar, ayarlarda yedek kartı).
- [ ] **Adım 7: Commit ve push** `belge(tasarım): cam tasarım kodda tamamlandı`.
- [ ] **Adım 8: Telefon denemesi (kullanıcıyla).** Önce "telefonu bağlar mısın" diye sorulur. Yayın derlemesi verileri koruyarak kurulur (`-r`). Kullanıcı bakar: cam ilk bakışta fark ediliyor mu, kaydırma takılıyor mu, "+" akışı, yeni parola formu, 2FA, ayarlar, başka uygulamada doldurma penceresi, koyu tema. Geri bildirim issue #103'e yazılır; #103 kullanıcı onayıyla kapanır.

---

## Kapsam denetimi

| Tasarım belgesi | Görev |
|---|---|
| Zemin, renkler, kontrast kuralı, cam | 1 |
| Kayıt simgeleri, kartlar, liste girişi | 2 |
| Pencereler, bildirim, üç nokta menüsü, Android başlık ve geri | 3 |
| Alt menü | 4 |
| "+" kutusu, sekme geçişi, formlarda menü yok | 5 |
| Ekran 2 (Kasa), listeden kopyalama, süzgeç kuralı | 6 |
| Ekran 7 (ayrıntı), karttan ayrıntıya geçiş | 6, 7 |
| Ekran 5-6 ve "Formlar" | 8, 10 |
| Ekran 8 (2FA) | 9 |
| Ekran 9 (Ayarlar), yedek kartı | 11 |
| Ekran 1 (Kilit) ve kurulum ekranları | 12 |
| Çizilmeyen ekranlar | 10, 12, 13 |
| Ekran 10 (doldurma penceresi) | 14 |
| Hareket tablosu | 2 (liste, basma), 3 (pencere, bildirim), 4 (kapsül), 5 ("+"), 7 (Hero), 9 (halka), 12 (kilit), 15 (geri hareketi) |
| Kısıtlar: testler, emülatörler, güvenlik belgesi, ölü kod | 6, 13, 15 |

Uygulayıcıya bırakılanlardan bu planda karara bağlananlar: renk tonları ve leke görünürlüğü (yukarıdaki tablo), ana düğmede koyu yazı, baş harf renk takımı ve kuralı, süreler ve eğri, karttan ayrıntıya geçiş (simge kutusunda Hero, sayfa geçişi platformun kendisi), formlarda menünün gizlenmesi (kök gezgin), açılış rengi (düz zemin rengi).

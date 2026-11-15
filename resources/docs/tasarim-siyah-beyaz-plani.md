# Siyah-Beyaz Tasarım Uygulama Planı

> **Uygulayıcıya:** Bu plan oturum içinde, görev görev uygulanır (superpowers:executing-plans). Adımlar `- [ ]` kutularıyla izlenir; her görev ayrı commit ve push.

**Amaç:** Cam tasarımı siyah-beyaza çevirmek (turuncu yalnızca dört yerde), ölçüleri küçültmek ve dört katmanlı hareket planını kurmak.

**Mimari:** Renkler `KkColors` ve `KkGlass` içinde değişir. Turuncu yeni `brand` alanına taşınır, `accent` nötr olur; böylece bugün `accent` kullanan her yer kendiliğinden siyah-beyaza döner. Ölçüler yeni `KkMetrics` sabitlerinde toplanır. Hareketler `KkMotion` değerlerinden ve `lib/app/ui/` altındaki ortak parçalardan gelir; ekranlar süre ya da eğri yazmaz.

**Teknoloji:** Flutter (Material 3), Riverpod, go_router. Yeni bağımlılık yok.

**Belge:** [`tasarim-siyah-beyaz.md`](tasarim-siyah-beyaz.md) (madde numaraları 1.1–4.9 oradaki tablolardan). Belge ile plan çelişirse belge kazanır; plan yalnızca belgenin "Kesin tonları plan belirler" dediği değerleri sabitler.

## Genel kurallar

- Yeni izin, bağımlılık, yazı tipi ya da logo paketi yok. Lottie/Rive yok.
- Turuncu yalnızca: K logosu, "+" düğmesi, ekranın tek ana düğmesi (`FilledButton`), 2FA halkası.
- Kontrast: yazı ≥ 4,5:1, simge ve çizgi ≥ 3:1, lekelerin en kötü noktasında ve cam kartın üstünde.
- Dokunma alanı ≥ 48 dp; küçülen yalnızca görünüş.
- En küçük yazı 11 sp. %200 yazı boyutunda taşma yok.
- Her hareket 150–450 ms, bekletmez, "animasyonları kaldır" açıkken anında biter (`KkMotion.of`), süren hareketler durur.
- Hareket sırasında dokunuş çalışır; yeni hareket eskisini keser.
- Bulanıklık ve gölge canlandırılmaz; yalnızca yer, ölçek, saydamlık, döndürme.
- Gizli veri hareket yüzünden `FLAG_SECURE` dışına çıkmaz; parola gösterme, kimlik onayı gerekiyorsa onaydan sonra başlar.
- Commit, yorum ve belge Türkçe; kod adları İngilizce. Commit biçimi `<tür>(<alan>): <açıklama>`.
- Her görevin sonunda: `dart format --output=none --set-exit-if-changed lib test integration_test`, `flutter analyze`, `flutter test` yeşil.

## Sabitlenen değerler (benim kararlarım, kontrastla hesaplandı)

| Ad | Açık | Koyu | Not |
|---|---|---|---|
| `ground` | `#E6E6E8` | `#000000` | |
| `blobs` | `#FFFFFF`, `#A9A9AE`, `#FFFFFF` | `#5A5A5E`, `#3A3A3E`, `#4A4A4E` | |
| `blobAlpha` | 0,45 | 0,50 | en kötü nokta açıkta `#CBCBCE`, koyuda `#2D2D2F` |
| `ink` | `#111111` | `#F4F4F4` | 11,6:1 / 12,5:1 |
| `inkMuted` | `#525252` | `#ADADAD` | belgedeki `#6B6B6B` 3,3:1 kaldı, koyulaştı; koyuda cam kart üstü 4,9:1 |
| `brand` | `#F26B1D` | `#FF8A4C` | dolgu: "+" ve ana düğme |
| `onBrand` | `#1A0D05` | `#1A0D05` | 6,2:1 / 8,1:1 |
| `brandStroke` | `#C2470C` | `#FF8A4C` | ince çizgi (2FA halkası): gri lekenin üstünde `#F26B1D` 1,9:1, `#C2470C` 3,1:1 |
| `tint` (seçili/basılı zemin) | siyah %6 | beyaz %9 | eski `accentContainer` |
| `error` | `#A1201A` | `#FFB4AB` | değişmez (4,7:1 / 8,1:1) |
| cam kart `fill` | beyaz %88 | beyaz %7 | ilk denemeden sonra (önce %52) |

K logosu marka işaretidir, kontrast kuralından muaftır.

## İnceleme odağı

1. **Turuncu sızıntısı:** `colorScheme.primary` artık mürekkep rengi; `primary` kullanan bir bağlantı ya da seçim turuncu kalmamalı. Görev 1'deki tarama testi `brand` ve `brandStroke` kullanımını dört dosyayla sınırlar.
2. **Dar ekran ve %200 yazı:** küçülen satırlar (46/54 dp) büyük yazıda büyümeli, kesilmemeli. Görev 3'ün testi kartı ve ayar satırını 2,0 ölçekte kurar.
3. **"Animasyonları kaldır" açıkken sürekli hareket:** kayan zemin ve nabız durmalı, testler `pumpAndSettle` ile bitebilmeli. Görev 7 ve 12'deki testler bunu sabitler.
4. **Kaydırırken kayan zemin:** liste kayarken zemin durmalı, bırakınca devam etmeli. Görev 7'nin testi.
5. **Hareket sürerken ikinci dokunuş:** kaydet düğmesinin onay işareti oynarken ikinci dokunuş ikinci kaydı açmamalı; kopyala simgesi dönerken yeniden kopyalama çalışmalı. Görev 9 ve 10'un testleri.

## Dosya haritası

- Değişir: `lib/app/theme.dart`, `lib/app/ui/kk_glass.dart`, `kk_backdrop.dart`, `kk_card.dart`, `kk_bars.dart`, `kk_section.dart`, `kk_form.dart`, `kk_sheet.dart`, `kk_snack.dart`, `kk_menu.dart`, `glass_nav_bar.dart`, `add_panel.dart`, `record_avatar.dart`, `keykey_logo.dart`, `kk_entrance.dart`, `kk_motion.dart`, `lib/app/app.dart`, `lib/app/app_shell.dart` ve belgede adı geçen ekranlar.
- Yeni (`lib/app/ui/`): `kk_metrics.dart`, `kk_switch.dart`, `kk_pressable.dart`, `kk_page_transition.dart`, `kk_ambient.dart`, `kk_copy_icon.dart`, `kk_shake.dart`, `kk_done_mark.dart`, `kk_animated_items.dart`, `kk_secret_text.dart`, `kk_rolling_text.dart`.
- Testler: aynı adla `test/app/ui/` altında; tarama testleri `test/app/`.

---

## Aşama 0: Renkler

### Task 1: Siyah-beyaz tema ve turuncunun dört yere çekilmesi

**Dosyalar:**
- Değişir: `lib/app/theme.dart`, `lib/app/ui/kk_glass.dart`, `lib/app/ui/glass_nav_bar.dart` (`_AddButton`, seçili sekme), `lib/app/ui/kk_sheet.dart` (tutamak, `kkDangerButtonStyle`), `lib/features/authenticator/presentation/otp_ring.dart`, `lib/features/generator/presentation/password_strength_meter.dart`, `lib/features/backup/presentation/backup_status_card.dart`
- Test: `test/app/theme_test.dart`, yeni `test/app/brand_usage_test.dart`

**Arayüzler:**
- Üretir: `KkGlass` alanları: `brand`, `onBrand`, `brandStroke`, `tint` eklenir; `accentContainer`, `onCta`, `ctaGradient` kalkar. `accent` kalır ama değeri `ink`. `KkColors`: yukarıdaki tablonun sabitleri; `ctaStart`, `ctaEnd`, `onCta` kalkar. `kkNeutralButtonStyle(BuildContext) -> ButtonStyle` (`kk_sheet.dart` içinde, `kkDangerButtonStyle`'ın yanında): dolgu `ink`, yazı `ground`.

- [ ] **Adım 1: Testleri yaz.** `theme_test.dart`'ta sabit renk testleri yeni değerlere döner (`ground` `#E6E6E8`/`#000000`, `colorScheme.primary` = `ink`). Kontrast grubunda: `yazı`, `ikincil yazı`, `hata` ≥ 4,5 (rol listesinden `vurgulu yazı` çıkar, `primary` artık `ink`); `brandStroke` her zeminde ≥ 3,0; `onBrand` `brand` üstünde ≥ 4,5; `accent` (nötr) ≥ 3,0; düz SnackBar testi kalır. "ana düğmenin yazısı geçişin iki ucunda" testi `onBrand`/`brand` testiyle değişir. Yeni `brand_usage_test.dart`: `lib/` altındaki `.dart` dosyalarında `.brand`, `brandStroke`, `brandOrange`, `onBrand` geçen dosyalar tam olarak şu kümedir: `lib/app/theme.dart`, `lib/app/ui/kk_glass.dart`, `lib/app/ui/keykey_logo.dart`, `lib/app/ui/glass_nav_bar.dart`, `lib/features/authenticator/presentation/otp_ring.dart`.
- [ ] **Adım 2: Çalıştır, kırmızı.** `flutter test test/app/theme_test.dart test/app/brand_usage_test.dart` → renk ve kontrast testleri FAIL.
- [ ] **Adım 3: Tema.** Değerler yukarıdaki tablodan. `FilledButton` teması: düz `brand` dolgu, `onBrand` yazı/simge, `RoundedRectangleBorder(14)`, `minimumSize: Size(64, 44)`; devre dışıyken `fill` dolgu. `OutlinedButton`: `RoundedRectangleBorder(14)`, `Size(64, 44)`, kenar `border`. `switchTheme`: seçiliyken iz `ink`, topuz `ground`. `chipTheme.checkmarkColor` = `ink`. `kkDangerButtonStyle` aynı 14'lük köşeyi alır. Lekelerin değişmesi `blobs`/`blobAlpha` ile olur, `KkBackdrop` koduna dokunulmaz.
- [ ] **Adım 4: Kullanım yerleri.** "+" düz `brand` daire, simge `onBrand`. Seçili sekme simgesi `ink`, kapsül `tint`. 2FA halkası `brandStroke` (uyarıda yine `error`). Güç çubuğunda dört durumun rengi `onSurface` (renksiz; etiket metni kalır). Pencere tutamağı `onSurface` %35. Yedek kartındaki "Yedekle" `kkNeutralButtonStyle` alır. `accentContainer` kullanan iki "Üret" düğmesi (`login_edit_screen.dart`, `otp_edit_screen.dart`) `tint` zemin, `onSurface` yazı alır.
- [ ] **Adım 5: Çalıştır, yeşil.** Hedef testler PASS; ardından `flutter test` tamamı. Renk değerine bağlı eski testler (ör. avatar, nav) yeni değerlere güncellenir.
- [ ] **Adım 6: Commit + push.** `özellik(tema): siyah-beyaz renkler, turuncu dört yerde`

### Task 2: Kutusuz simgeler ve logo

**Dosyalar:**
- Değişir: `lib/app/ui/record_avatar.dart`, `lib/app/ui/kk_section.dart` (`KkIconBox`), `lib/app/ui/keykey_logo.dart`, `lib/app/theme.dart` (`avatarPalette` kalkar)
- Test: `test/app/ui/record_avatar_test.dart`, `test/app/ui/keykey_logo_test.dart`, `test/app/ui/kk_section_test.dart`

**Arayüzler:**
- Üretir: `RecordAvatar` aynı imza (`size` varsayılanı 34). `avatarColorFor` kalkar, `avatarInitial` kalır. `KkIconBox` adı ve imzası kalır (`size` varsayılanı 22), artık kutusuz `ink` renkli `Icon` çizer.

- [ ] **Adım 1: Testleri yaz.** Avatar: simgesiz kayıtta harf `onSurface` renginde, 1,2 dp `onSurface` kenarlı daire (`ShapeDecoration(CircleBorder)`), dolgu yok; uygulama simgeli kayıtta `Image` bir `ColorFiltered` içinde ve süzgeç doygunluğu sıfırlayan matris; `ClipRRect` yok. `KkIconBox`: ağaçta `Container`/`DecoratedBox` yok, `Icon` rengi `onSurface`. Logo: `_LogoPainter` daire çizmez; boyanan resimde köşe piksel saydam (`toImage` ile). `logo_path_test.dart` aynen geçer.
- [ ] **Adım 2: Çalıştır, kırmızı.**
- [ ] **Adım 3: Uygula.** Gri tonlama matrisi `kk_glass.dart`'taki `_saturation(0)` ile aynı katsayılar; ortak olsun diye `kkSaturation(double amount) -> ColorFilter` adıyla açığa çıkar. Logoda K, kutunun tamamını kullanacak biçimde ölçeklenir (dairenin iç oranı yerine K'nın sınır kutusu %90).
- [ ] **Adım 4: Çalıştır, yeşil;** `flutter test` tamamı.
- [ ] **Adım 5: Commit + push.** `özellik(arayüz): kutusuz kayıt simgeleri ve logo`

## Aşama 1: Ölçüler

### Task 3: Küçük ölçüler

**Dosyalar:**
- Yeni: `lib/app/ui/kk_metrics.dart`
- Değişir: `theme.dart`, `kk_bars.dart`, `kk_card.dart`, `kk_section.dart`, `kk_form.dart`, `kk_sheet.dart`, `glass_nav_bar.dart`, `add_panel.dart`, `vault_screen.dart` ve `otp_code_tile.dart` (avatar ve satır boyu), `lib/app/ui/kk_glass.dart` (`GlassSurface` varsayılan köşesi)
- Test: `test/app/ui/kk_metrics_test.dart`, `test/accessibility/accessibility_test.dart`, mevcut bileşen testleri

**Arayüzler:**
- Üretir: `abstract final class KkMetrics` sabitleri: `rootTitle = 22`, `subTitle = 17`, `cardHeight = 54`, `cardTitle = 13.5`, `cardSubtitle = 11.5`, `rowHeight = 46`, `rowTitle = 13`, `rowSubtitle = 11.5`, `fieldHeight = 52`, `buttonHeight = 44`, `buttonRadius = 14`, `cardRadius = 16`, `navHeight = 52`, `navTab = 40`, `addSize = 40`, `avatar = 34`, `circleButton = 40`, `minTouch = 48`, `minFont = 11`.
- `GlassNavBar.height` = `KkMetrics.navHeight`; `kNavClearance` buna göre kendiliğinden küçülür.

- [ ] **Adım 1: Testleri yaz** (`kk_metrics_test.dart`), normal yazı boyutunda: `KkCard` yüksekliği 54; ayar satırı (`KkSection` içinde `ListTile`, alt yazılı ve alt yazısız) 46; `KkBottomAction` düğmesinin görünen yüksekliği 44, dokunma alanı ≥ 48 (`tester.getSize` + `meetsGuideline(androidTapTargetGuideline)`); "+" görünen 40, dokunma 48; alt menü 52; kök başlık yazısı 22, alt ekran başlığı 17; `KkFieldCard` içindeki `TextField` ≤ 54. `textScaler: TextScaler.linear(2)` ile: kart ve ayar satırı taşma hatası vermez ve yükseklikleri 54/46'dan büyüktür.
- [ ] **Adım 2: Çalıştır, kırmızı.**
- [ ] **Adım 3: Uygula.** Yazılar: kök başlık `w700`, alt ekran başlığı `w700`, kart başlığı `w600`. `kkRootAppBar` `toolbarHeight` 56, `kkAppBar` 52, `KkCircleButton.size` 40. `ListTileTheme.merge` içinde `minTileHeight: rowHeight`, `minVerticalPadding: 4`, `titleTextStyle`/`subtitleTextStyle` `rowTitle`/`rowSubtitle`. `InputDecorationTheme.contentPadding` `EdgeInsets.symmetric(horizontal: 14, vertical: 12)`. Köşeler: kart, bölüm, alan 16; pencere üst köşesi 24; "+" kutusu 20; kutu satırı 52 yükseklik. Nav: sekme kapsülü 40 yükseklik, genişliği 46; "+" 40'lık daire, 48'lik `SizedBox` içinde ortalı.
- [ ] **Adım 4: Çalıştır, yeşil;** sonra `flutter test` tamamı (boya bağlı eski ölçü testleri yeni değerlere çekilir) ve `flutter test test/accessibility`.
- [ ] **Adım 5: Commit + push.** `özellik(arayüz): daha küçük yazı, satır ve düğmeler`

### Task 4: Küçük anahtar ve (i)'nin yeri

**Dosyalar:**
- Yeni: `lib/app/ui/kk_switch.dart`
- Değişir: `kk_section.dart` (`KkInfoRow` kalkar, `KkInfoButton` gelir), `settings_screen.dart`, `generator_sheet.dart`, `autofill_setup_section.dart` (KkInfoRow kullanıyorsa), `theme.dart` (`switchTheme` artık kullanılmıyorsa kalkar)
- Test: `test/app/ui/kk_switch_test.dart`; `SwitchListTile` arayan testler: `test/features/settings/settings_test.dart`, `test/features/authenticator/otp_gate_test.dart`, `integration_test/biometric_test.dart`

**Arayüzler:**
- Üretir: `KkSwitch({required bool value, required ValueChanged<bool>? onChanged})`: görünen iz 36×21, topuz 15, dokunma alanı 48×48, `Semantics(toggled:)`. `KkSwitchTile({required Widget title, required bool value, required ValueChanged<bool>? onChanged, Widget? secondary, Widget? subtitle, String? infoTitle, String? info})`: `ListTile`; dokununca değer değişir; `info` verilirse sondaki satır `[KkInfoButton, KkSwitch]` sırasındadır. `KkInfoButton({required String title, required String info})`: bugünkü (i) penceresini açan `IconButton`.

- [ ] **Adım 1: Testleri yaz.** `KkSwitch`: görünen kutu 36×21, `tester.getSize` dokunma alanı 48×48; dokununca `onChanged(!value)`; `onChanged == null` iken etkisiz ve semantikte `enabled: false`; seçiliyken iz rengi `onSurface`. `KkSwitchTile`: satıra dokunmak değeri çevirir; `info` varken (i) düğmesinin sol kenarı anahtarın sol kenarından küçük ve (i)'ye dokunmak değeri değiştirmez, pencereyi açar; TalkBack'te (i) ayrı düğüm.
- [ ] **Adım 2: Çalıştır, kırmızı.**
- [ ] **Adım 3: Uygula.** Topuz hareketi `AnimatedAlign`, süre `KkMotion.base`, eğri `KkMotion.spring` (madde 1.7); iz rengi `AnimatedContainer` ile. Ayarlardaki üç `KkInfoRow(SwitchListTile)` ve üreticideki dört `SwitchListTile` → `KkSwitchTile`. Ok (chevron) olan satırlarda (i) gerekirse `trailing: Row([KkInfoButton, chevron])`.
- [ ] **Adım 4: Eski testleri güncelle** (`find.byType(SwitchListTile)` → `find.byType(KkSwitchTile)`, `tester.widget<SwitchListTile>(...).value` → `KkSwitchTile.value`).
- [ ] **Adım 5: Çalıştır, yeşil;** `flutter test` tamamı.
- [ ] **Adım 6: Commit + push.** `özellik(ayarlar): küçük anahtar, bilgi düğmesi anahtarın solunda`

### Task 5: Telefonda deneme 1 (görünüm)

- [ ] **Adım 1:** Entegrasyon testleri Android 11, 14, 17 emülatörlerinde (`-gpu host`), `flutter test integration_test -d <cihaz>`; hepsi PASS.
- [ ] **Adım 2:** `flutter build apk --release --target-platform android-arm64` (telefondaki sürümle aynı hata ayıklama imzası; veri korunur). `resources/scripts/check-release-apk.sh` PASS.
- [ ] **Adım 3:** APK'yı Drive'daki **KeyKey** klasörüne `keykey-siyah-beyaz-1.apk` adıyla yükle; önceki deneme APK'sı varsa sil. Kullanıcıya adını ve "imza hatası çıkarsa silme" uyarısını yaz.
- [ ] **Adım 4:** Kullanıcının notlarını #103'e yaz; isteklerini sonraki görevlerden önce uygula (her biri ayrı commit).

## Aşama 2: Hareket altyapısı ve Katman 1

### Task 6: Hareket değerleri ve tarama testi

**Dosyalar:**
- Değişir: `lib/app/ui/kk_motion.dart`, süre yazan dosyalar (`kk_entrance.dart`, `lock_screen.dart`, `qr_scan_screen.dart`)
- Test: `test/app/ui/kk_motion_test.dart`, yeni `test/app/motion_durations_test.dart`

**Arayüzler:**
- Üretir: `KkMotion`'a `enter` (350 ms), `emphasis` (450 ms), `stagger` (40 ms), `staggerMax = 8`, `standard = Curves.easeOutCubic`, `exit = Curves.easeInCubic` eklenir; `fast`, `base`, `panelOpen`, `panelClose`, `spring`, `of` kalır.

- [ ] **Adım 1: Testleri yaz.** Değerler belgedeki tabloya eşit. Tarama testi: `lib/app/ui/` ve `lib/features/**/presentation/` altında `Duration(milliseconds:` ya da `Duration(seconds:` yalnızca `kk_motion.dart`'ta ve bir izin listesinde geçer. İzin listesi hareket olmayan süreler içindir (ör. QR tarayıcı zaman aşımı, kilit sayacı); her kaydın yanında neden yazar.
- [ ] **Adım 2: Çalıştır, kırmızı.**
- [ ] **Adım 3: Uygula;** elle yazılmış hareket süreleri `KkMotion`'a taşınır.
- [ ] **Adım 4: Yeşil;** `flutter test`.
- [ ] **Adım 5: Commit + push.** `yeniden-düzenleme(hareket): ortak hareket değerleri`

### Task 7: Kayan zemin her ekranda (1.11) ve küçülen başlık (1.9)

**Dosyalar:**
- Yeni: `lib/app/ui/kk_ambient.dart`
- Değişir: `kk_backdrop.dart` (`KkScaffold`, `KkBackdrop`), `kk_bars.dart` (`kkRootAppBar`), `lib/app/app.dart`, `lock_screen.dart`
- Test: `test/app/ui/kk_backdrop_test.dart`, `test/app/ui/kk_bars_test.dart`

**Arayüzler:**
- Üretir: `KkAmbient({required bool enabled, required Widget child})` ve `static bool of(BuildContext)`: atada yoksa `false` (temasız testler ve otomatik doldurma penceresi hareketsiz kalır). `app.dart` `MaterialApp.router(builder:)` içinde `KkAmbient(enabled: ref.watch(ambientMotionProvider))` ile sarar. `KkBackdrop({bool lively = false})`: `KkAmbient` açıksa lekeler her zaman kayar; döngü `lively` ise `driftPeriod` (24 sn, kilit ekranı), değilse `calmPeriod` (36 sn). `KkScaffold`'un `driftingBackdrop` parametresi `livelyBackdrop` olur; yalnızca kilit ekranı `true` verir. `KkScaffold` içindeki `NotificationListener<ScrollNotification>` bir `ValueNotifier<double>` kaydırma konumu ve bir `ValueNotifier<bool>` "kayıyor" bilgisi tutar; ikisi `KkScrollState.of(context)` ile okunur.

- [ ] **Adım 1: Testleri yaz.** `KkAmbient` yokken `KkScaffold` lekeleri durgun (`pumpAndSettle` biter). `KkAmbient(enabled: true)` altında denetleyici çalışır; `MediaQuery(disableAnimations: true)` ile durur; `ScrollStartNotification` sonrası ilerlemez, `ScrollEndNotification` sonrası devam eder (iki `pump(1 sn)` arasında boyacı değeri aynı / farklı). Küçülen başlık: kaydırma 0'da başlığın ölçeği 1, kaydırma ≥ 40 dp'de ölçek 17/22, arada doğrusal; başlık hep `Semantics(header: true)`.
- [ ] **Adım 2: Çalıştır, kırmızı.**
- [ ] **Adım 3: Uygula.** Kayma sırasında denetleyici `stop()`, bitince `repeat()` kaldığı yerden. Uygulama arka plandayken kare üretilmez, ek kod gerekmez. Başlık `Transform.scale(alignment: centerStart)`, `ValueListenableBuilder` ile; `AppBar` yüksekliği sabit. Lekelerin süzülmesi kilit ekranındaki ile aynı boyacıdır.
- [ ] **Adım 4: Yeşil;** `flutter test` (bütün ekran testleri `KkAmbient` olmadan çalıştığı için durgun kalır).
- [ ] **Adım 5: Commit + push.** `özellik(hareket): her ekranda yavaş kayan zemin, küçülen başlık`

### Task 8: Katman 1 hareketleri (1.1–1.5, 1.10)

**Dosyalar:**
- Yeni: `lib/app/ui/kk_pressable.dart`, `lib/app/ui/kk_page_transition.dart`
- Değişir: `kk_entrance.dart`, `kk_card.dart`, `kk_bars.dart`, `glass_nav_bar.dart`, `theme.dart` (`pageTransitionsTheme`)
- Test: `test/app/ui/kk_entrance_test.dart`, `kk_pressable_test.dart`, `kk_page_transition_test.dart`, `glass_nav_bar_test.dart`, `theme_test.dart`

**Arayüzler:**
- Üretir: `KkPressable({required Widget child, double pressedScale = 0.965})`: alt ağaçtaki basma durumunu `Listener` ile izler (dokunuşu yutmaz), `AnimatedScale` `fast` + `spring`. Küçük düğmeler `pressedScale: 0.88`. `KkPageTransitionsBuilder`: geri hareketi sürerken (`route.popGestureInProgress`) `PredictiveBackPageTransitionsBuilder`'a devreder; diğer zamanlarda 24 dp sağdan kayma + solma, `enter` + `standard`.

- [ ] **Adım 1: Testleri yaz.**
  - Giriş (1.1): ilk karede öğe 16 dp aşağıda, ölçek 0,96, saydamlık 0; `enter + stagger*min(index, 8)` sonra yerinde.
  - Kaydırınca giriş (1.1, telefon denemesi 1): kaydırırken sonradan kurulan öğe de 0'dan başlar, gecikmesiz, `enter` sonra yerinde; animasyonlar kapalıyken anında.
  - Yeniden oynama (1.10): kapsamın üstündeki `TickerMode` `false → true` olunca görünen öğeler yeniden 0'dan başlar; kapsamın sayfası üstüne itilen sayfa kapanınca (`ModalRoute.secondaryAnimation` `dismissed`) yeniden başlar; animasyonlar kapalıyken oynamaz.
  - Basma (1.3): `KkCard` basılıyken ölçek 0,965, bırakınca 1; `onTap` bir kez çağrılır.
  - Alt menü ve alt düğme (1.2): ilk karede 24 dp aşağıda, `enter` sonra yerinde.
  - Sekme (1.5): seçilen sekmenin simgesi değişimden `base/2` sonra ölçek > 1,1, `base` sonra 1.
  - Geçiş (1.4): itmeden `enter/2` sonra yeni sayfa x > 0 ve saydamlık < 1; tema `KkPageTransitionsBuilder` kullanır.
- [ ] **Adım 2: Çalıştır, kırmızı.**
- [ ] **Adım 3: Uygula.** Yeniden oynama `KkEntranceScope`'ta bir sayaçla (`ValueNotifier<int>`); `KkEntrance` sayaca abone olur ve görünürse denetleyiciyi baştan başlatır. Sekme değişimi go_router'ın dal kabındaki `TickerMode` ile gelir (go_router 18.1, `route.dart` "TickerMode(enabled: isActive)"), `AppShell`'e ek kod gerekmez. `KkPressable` `KkCard`, `KkCircleButton`, nav sekmeleri, "+" ve `KkBottomAction`'a uygulanır; `KkCard`'daki eski `_pressed` kalkar.
- [ ] **Adım 4: Yeşil;** `flutter test`.
- [ ] **Adım 5: Commit + push.** `özellik(hareket): giriş, basma, geçiş ve sekme hareketleri`

## Aşama 3: Katman 2 (geri bildirim)

### Task 9: Kopyalama, kaydetme ve titreme (2.1, 2.2, 2.4, 2.5)

**Dosyalar:**
- Yeni: `kk_copy_icon.dart`, `kk_shake.dart`, `kk_done_mark.dart`
- Değişir: `vault_screen.dart`, `login_detail_screen.dart`, `otp_code_tile.dart`, `kk_snack.dart` (`copySensitive` kopyalandı bilgisini döndürür), `kk_bars.dart` (`KkBottomAction`), `login_edit_screen.dart`, `otp_edit_screen.dart`, `kk_form.dart`, `lock_screen.dart`
- Test: her yeni parça için `test/app/ui/…_test.dart`; `test/features/vault/…`, `test/features/lock/…` ilgili testler

**Arayüzler:**
- Üretir: `copySensitive(...) -> Future<bool>` (kopyalandıysa `true`). `KkCopyIcon({required Future<bool> Function() onCopy, required String tooltip})`: `copy` simgesi; `onCopy` `true` dönerse `check` simgesine `fast` ölçek+solma ile döner, 1 sn sonra geri; dönerken yeniden basmak yeniden kopyalar ve süreyi baştan başlatır. `KkShake({required Widget child})` ve `KkShakeController.shake()`: üç salınım ±8 dp, 300 ms; `HapticFeedback.mediumImpact()` ile birlikte (2.5). `KkDoneMark({required Animation<double> progress, double size})`: çizilerek beliren onay işareti. `KkBottomAction({bool done = false})`: ekran kayıt başarılı olunca `done: true` ile yeniden kurar; yazı `KkDoneMark`'a döner, düğme etkisizleşir, ekran `emphasis` sonra kapanır.
- 2.2'nin "listede bir kez parlayan kart"ı: `KkCard({bool flash = false})`; `true` ile kurulduğunda zemin `tint` %0→%10→%0, `emphasis`. Liste ekranları son kaydedilen kimliği bir sağlayıcıdan (`lastSavedIdProvider`, `StateProvider<String?>`, okununca temizlenir) okur.

- [ ] **Adım 1: Testleri yaz.** Kopyala: dokununca `onCopy` bir kez, `check` simgesi görünür, 1 sn sonra `copy`; dönerken ikinci dokunuş ikinci kez kopyalar. Titreme: `shake()` sonrası `150 ms`'de x ≠ 0, `300 ms`'de 0; `SystemChannels.platform` çağrılarında `HapticFeedback.vibrate` türü görülür; animasyonlar kapalıyken hareket yok ama titreşim var. Kaydet: `done: true` iken `KkDoneMark` görünür ve ikinci dokunuş `onPressed`'i çağırmaz; kayıt ekranında kaydete iki kez hızlı basmak tek kayıt üretir. Kilit ekranında yanlış parola yine titrer (mevcut test `KkShake` ile geçer). Boş zorunlu alanla kaydetmeye basınca alanın kartı titrer.
- [ ] **Adım 2: Kırmızı.**
- [ ] **Adım 3: Uygula;** kilit ekranındaki titreme kodu `KkShake`'e taşınır.
- [ ] **Adım 4: Yeşil;** `flutter test`.
- [ ] **Adım 5: Commit + push.** `özellik(hareket): kopyalama, kaydetme ve hata geri bildirimi`

### Task 10: Liste hareketleri ve "Daha fazla seçenek" (2.3, 2.6, 2.7, 3.6)

**Dosyalar:**
- Yeni: `lib/app/ui/kk_animated_items.dart`
- Değişir: `vault_screen.dart`, `authenticator_screen.dart`, `trash_screen.dart`, `otp_trash_screen.dart`, `kk_form.dart`
- Test: `test/app/ui/kk_animated_items_test.dart`, `test/app/ui/kk_form_test.dart`

**Arayüzler:**
- Üretir: `KkAnimatedItems<T>({required List<T> items, required Object Function(T) keyOf, required Widget Function(BuildContext, T) itemBuilder})`: bir sliver. Yeni ve eski anahtar listelerini karşılaştırır, `SliverAnimatedList` üzerinde ekler/çıkarır. Çıkan öğe sola 24 dp kayar, solar, yüksekliği sıfıra iner (`base` + `exit`); giren öğe solarak ve yükseklik açarak gelir. **Benim kararım:** yer değiştiren öğe (2.7, süzgeç/sıralama) gerçek kaydırma yerine çıkıp yeni yerinde girer; gerçek kaydırma için her kartın konumunu ölçmek gerekir ve 1000 kayıtlı listede pahalıdır. Belgeye not düşülür.
- Arama (3.6) aynı parçayla olur; sonuç yoksa boş durum `KkEntrance` ile 8 dp yükselerek gelir.

- [ ] **Adım 1: Testleri yaz.** Bir öğe çıkarılınca `base/2`'de hâlâ ağaçta ve saydamlığı < 1, `base` sonra yok; eklenince yüksekliği 0'dan büyür; 1000 öğelik listede yalnızca görünenler kurulur (`find.byType(...)` sayısı < 30); animasyonlar kapalıyken değişim anında. "Daha fazla seçenek": açılınca yongalar sırayla belirir (`stagger`), ok 180° döner; yongaya dokununca o yonga kaybolur.
- [ ] **Adım 2: Kırmızı.**
- [ ] **Adım 3: Uygula.** Liste ekranlarında bugünkü `ListView` → `CustomScrollView` + `KkAnimatedItems`; kart ve kaydırma davranışı aynı.
- [ ] **Adım 4: Yeşil;** `flutter test`; `integration_test/performance_test.dart` emülatörde, savurma sayıları cam turuyla karşılaştırılır (ölçüm `resources/docs/tasarim-siyah-beyaz.md`'nin "Denetim" bölümüne yazılır).
- [ ] **Adım 5: Commit + push.** `özellik(hareket): listelerde ekleme, silme ve arama hareketi`

### Task 11: Telefonda deneme 2

Görev 5'in adımları, APK adı `keykey-siyah-beyaz-2.apk`. Takılan ya da fazla gelen hareket madde numarasıyla sadeleştirilir.

## Aşama 4: Katman 3 (içerik)

### Task 12: Gizli metin, üretici, güç çubuğu, 2FA kodu ve sayılar (3.1–3.5, 3.7)

**Dosyalar:**
- Yeni: `kk_secret_text.dart`, `kk_rolling_text.dart`
- Değişir: `login_detail_screen.dart`, `kk_form.dart` (gizli alan), `generator_sheet.dart`, `password_strength_meter.dart`, `otp_display.dart`, `otp_code_tile.dart`, `otp_ring.dart`, liste ekranlarındaki sayılar
- Test: her parça için test dosyası; `otp_ring_test.dart`

**Arayüzler:**
- Üretir: `KkSecretText({required String text, required bool revealed, TextStyle? style})`: gizliyken her karakter için `•`; `revealed` değişince karakterler soldan sağa sırayla döner (karakter başına 12 ms, toplam en çok 300 ms). `KkRollingText({required String text, TextStyle? style, Duration stagger = 20 ms})`: değişen karakter yukarı kayıp solar, yenisi alttan gelir; aynı kalan karakter kıpırdamaz.
- Üretici karışması (3.2): 250 ms boyunca gösterilen metin, `Random()` ile üretilmiş, gerçek parolayla aynı uzunlukta süs karakterlerdir; gerçek parola yalnızca son karede gösterilir. Süs karakterler panoya, semantiğe ve durum kaydına girmez (`ExcludeSemantics`, yalnızca son değer `Semantics(value:)`).
- 2FA halkası nabzı (3.5): son 5 saniyede saniyede bir ölçek 1→1,12→1; `ambient` kapalıyken yok.

- [ ] **Adım 1: Testleri yaz.** `KkSecretText`: `revealed: true` yapıldıktan `12 ms × 3` sonra ilk üç karakter açık, kalanlar `•`; 300 ms içinde tamamı açık; animasyonlar kapalıyken anında. Uzun parolada (100 karakter) toplam süre 300 ms'yi geçmez. `KkRollingText`: `123456 → 123457` değişiminde yalnızca son karakterin hareketli olduğu. Üretici: karışma sırasında semantik değeri hep son parola; 250 ms sonra metin gerçek parolaya eşit. Güç çubuğu: değer değişince genişlik `base` boyunca ara değer alır. Halka: kalan 4 sn'de ölçek döngüsü çalışır, `MediaQuery.disableAnimations` ile çalışmaz.
- [ ] **Adım 2: Kırmızı.**
- [ ] **Adım 3: Uygula.** Kimlik onayı gerektiren gösterme akışında `revealed`, onay geldikten sonra `true` olur (bugünkü akış korunur; hareket ancak o zaman başlar).
- [ ] **Adım 4: Yeşil;** `flutter test`.
- [ ] **Adım 5: Commit + push.** `özellik(hareket): parola, kod ve sayı hareketleri`

## Aşama 5: Katman 4 (özel anlar)

### Task 13: Açılış, kilit ve kilitlenme (4.1–4.4)

**Dosyalar:** `keykey_logo.dart`, `lock_screen.dart`, `app_shell.dart`, `auto_lock_scope.dart`; testler `test/features/lock/…`, `test/app/…`

- [ ] **Adım 1: Testleri yaz.** Kilit ekranı açılışında logo ilk karede ölçek 0,8 ve saydamlık 0, `enter` sonra 1. Parmak izi simgesi `KkAmbient` açıkken nefes alır (ölçek 1↔1,06, 2,4 sn), kapalıyken durur. Kilit açılınca kasa ilk karede kurulmuş ve dokunulabilir (hareket içeriği bekletmez); logo `emphasis` boyunca yukarı kayıp solar. Kilitlenince içerik `fast` içinde saydam olur ve gizli metin ağaçtan kalkar (`find.text(<parola>)` → nothing) hareket bitmeden.
- [ ] **Adım 2: Kırmızı.**
- [ ] **Adım 3: Uygula.** Kilit açılışı geçişi `AppShell`'in üstünde bir `KkUnlockReveal` katmanı olarak: kasa altta hazır çizilir, üstte logo katmanı solar; gezinme yapısı değişmez.
- [ ] **Adım 4: Yeşil;** `flutter test`.
- [ ] **Adım 5: Commit + push.** `özellik(hareket): açılış ve kilit hareketleri`

### Task 14: Yedek, aktarma, kurulum, QR ve otomatik doldurma (4.5–4.9)

**Dosyalar:** `backup_status_card.dart`, `login_import_screen.dart`, `otp_import_screen.dart`, `restore_screen.dart`, `backup_section.dart`, `onboarding_screen.dart`, `new_password_screen.dart`, `recovery_screen.dart`, `qr_scan_screen.dart`, `autofill_sheet_frame.dart`, `autofill_pick_screen.dart`; testleri ilgili `test/features/…` altında

- [ ] **Adım 1: Testleri yaz.** Yedek kartı: yedek 7 günden eskiyse ayarlara girişte bir kez ölçek 1→1,03→1; yenide hareket yok. İşlem bitince ilerleme halkasının yerinde `KkDoneMark` çizilir. Kurulum adımları arası içerik yana kayar ve adım göstergesi dolar. QR çerçevesi `KkAmbient` açıkken nefes alır; kod okununca çerçeve `base` boyunca küçülür. Otomatik doldurma penceresi `panelOpen` + `spring` ile açılır (mevcut davranış testle sabitlenir).
- [ ] **Adım 2: Kırmızı.**
- [ ] **Adım 3: Uygula.**
- [ ] **Adım 4: Yeşil;** `flutter test`.
- [ ] **Adım 5: Commit + push.** `özellik(hareket): yedek, aktarma, kurulum ve QR hareketleri`

### Task 15: Son denetim ve telefonda deneme 3

- [ ] **Adım 1:** Format, analiz, birim testleri; entegrasyon testleri Android 11, 14, 17 emülatörlerinde.
- [ ] **Adım 2:** 1000 kayıtlı listede savurma ölçümü (`performance_test.dart`), sonuç belgeye.
- [ ] **Adım 3:** Görev 5'in APK adımları, ad `keykey-siyah-beyaz-3.apk`. Telefonda: "animasyonları kaldır" açıkken bir tur, TalkBack ile bir tur, %200 yazıyla bir tur.
- [ ] **Adım 4:** Belgenin durumunu "kodda bitti", yol haritasına durum satırı, #103'e özet. #103 yalnızca kullanıcının onayıyla kapanır.
- [ ] **Adım 5: Commit + push.** `belge(tasarım): siyah-beyaz tasarım kodda tamamlandı`

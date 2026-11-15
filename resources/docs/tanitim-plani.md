# Tanıtım ekranları uygulama planı

> **Ajanlar için:** superpowers:executing-plans ile görev görev uygulanır. Adımlar `- [ ]` kutularıyla izlenir.

**Amaç:** Kasa yokken açılışta altı sayfalık, hareketli bir tanıtım; Ayarlar'dan yeniden izlenebilir.

**Mimari:** Yeni `/tanitim` yolu. Kasa yokken yönlendirme kuruluma değil tanıtıma gider; tanıtımdan kuruluma `go` ile geçilir. Kasa açıkken aynı yol Ayarlar'dan `push` ile açılır ve son düğme **Bitti** olur. Sayfalar `PageView`; her sayfanın çizimi kendi `AnimationController`'ıyla, sayfa görününce başlar. Hiçbir şey saklanmaz.

**Teknoloji:** Flutter, go_router, `CustomPainter`, `KkMotion`.

**Tasarım:** [tanitim.md](tanitim.md)

## Genel kurallar

- Süreler `KkMotion.of(context, …)` ile; "Animasyonları kaldır" açıkken çizimler son halleriyle görünür.
- Turuncu yalnızca K logosunda, "+" çiziminde ve son sayfanın ana düğmesinde.
- KeePassXC logosu `resources/assets/logos/keepassxc.png` (256 px), kaynağı `resources/design/keepassxc.svg`; lisans notu `registerDataLicenses`'ta (LGPL-2, Lorenzo Stella; KeePassXC `COPYING` aynı dosyayı Apache-2.0 Pictogrammers kaydında da listeliyor, iki not birden).
- Metinler TR ve EN.

## Gözden geçirmede bakılacaklar

- Kasa yokken uygulama hangi yolla açılırsa açılsın (ilk açılış, geri yüklemeden vazgeçme) tanıtım ya da kurulum gelmeli, boş ekran değil.
- Kurulumdayken geri tuşu tanıtıma dönebilir ama uygulamayı kilitli bir yere sokmamalı.
- Ayarlar'dan açılan tanıtımda Atla ve Bitti Ayarlar'a dönmeli; kasa kilitlenirse kilit ekranına gidilmeli.
- %200 yazı boyutunda sayfalar taşmamalı (kaydırılabilir).
- Hızlı kaydırmada animasyon denetleyicileri atılmış nesneye dokunmamalı.

---

### Görev 1: Yol, sayfa iskeleti, Ayarlar satırı

**Dosyalar:**
- Oluştur: `lib/features/onboarding/presentation/intro_screen.dart`
- Değiştir: `lib/app/router.dart` (`AppRoutes.intro = '/tanitim'`, `vaultRedirect`), `lib/features/settings/presentation/settings_screen.dart`, `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`
- Test: `test/features/onboarding/intro_test.dart`; kasa yokken başlayan testler (`onboarding_flow_test`, `lock_flow_test`, `restore_screen_test`, `accessibility_test`, `integration_test/vault_flow_test.dart`) önce **Atla**'ya dokunur

**Arayüzler:** `class IntroScreen extends StatefulWidget { const new({super.key}); }`; kasa durumu `VaultOpen` ise yeniden izleme kipi. `vaultRedirect`: `VaultNotSetUp` → `intro`, `setup` ve `restore` serbest; `VaultOpen` → `intro` serbest.

- [x] **Adım 1: Başarısız testler.** Kasa yokken açılış "Hoş geldin" sayfasını gösterir; **İleri** sayfayı ilerletir ve noktalar değişir; **Atla** ve son sayfadaki **Kasamı oluştur** kuruluma gider; Ayarlar → Hakkında → **Tanıtımı yeniden göster** tanıtımı açar, son düğme **Bitti**, dokununca Ayarlar'a döner; `vaultRedirect(VaultNotSetUp(), '/kasa') == '/tanitim'`, `('/kurulum') == null`.
- [x] **Adım 2:** Testler düşer.
- [x] **Adım 3:** İskeleti yaz: altı sayfanın başlığı ve metni, çizim yeri boş; `KkScaffold`, üstte Atla, altta noktalar ve düğme. Eski testleri **Atla** ile güncelle.
- [x] **Adım 4:** `flutter test` tümü yeşil.
- [x] **Adım 5:** Commit `özellik(tanıtım): ilk açılışta tanıtım sayfaları`.

### Görev 2: Hareketli çizimler ve KeePassXC logosu

**Dosyalar:**
- Oluştur: `lib/features/onboarding/presentation/intro_art.dart` (altı çizim), `resources/assets/logos/keepassxc.png`, `resources/design/keepassxc.svg`
- Değiştir: `pubspec.yaml` (asset), `lib/app/licenses.dart`, `intro_screen.dart`
- Test: `test/features/onboarding/intro_test.dart`, `test/app/licenses_test.dart` (varsa)

**Arayüzler:** `class IntroArt extends StatefulWidget { const new({required this.page, required this.active}); final int page; final bool active; }`.

- [x] **Adım 1: Başarısız testler.** Üçüncü sayfada dört menü simgesi ve dört açıklama (Kasa, 2FA, Ayarlar, Ekle); beşinci sayfada KeePassXC görseli ve yedi uygulama adı; animasyonlar kapalıyken her sayfa ilk karede son halini gösterir ve bekleyen kare kalmaz; lisanslarda "KeePassXC logo" girdisi; altı sayfa %200 yazıda taşmaz.
- [x] **Adım 2:** Testler düşer.
- [x] **Adım 3:** Çizimler: (1) `KeyKeyLogo.logoPath()` çizgiyle çizilir sonra dolar; (2) telefon simgesi, bulut yukarı kayıp solar, üstüne çizgi çekilir; (3) menü kapsülünün kopyası, simgeler sırayla vurgulanır, yanlarındaki açıklamalar sırayla gelir; (4) giriş kutusu, altından "KeyKey ile doldur" önerisi kalkar, kutular dolar; (5) KeePassXC logosu ve ad rozetleri süzülüp ortadaki K'ye yaklaşır; (6) yedek bulutu yukarı ok ile nefes alır. Sayfa görününce baştan oynar.
- [x] **Adım 4:** Testler ve tüm kontroller yeşil.
- [x] **Adım 5:** Commit `özellik(tanıtım): hareketli çizimler ve KeePassXC logosu`.

### Görev 3: Belgeler ve deneme

- [ ] Kılavuzun "İlk kasa" bölümüne tanıtım; değişiklik günlüğü; yol haritası durumu; `bagimliliklar.md`'ye KeePassXC logosu.
- [ ] Entegrasyon testleri Android 17 emülatöründe; APK, telefon denemesi.
- [ ] Commit `belge(tanıtım): kılavuz ve günlük`.

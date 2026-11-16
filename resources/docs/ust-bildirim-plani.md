# Üstten inen bildirim: uygulama planı

> Ajanlar için: superpowers:executing-plans ile görev görev uygulanır, adımlar `- [ ]` kutularıyla izlenir.

**Amaç:** Uygulama içi bütün bildirimler üstten inen, ortada duran cam bir hap olarak çıkıyor. Yazı 16 punto, w700.

**Mimari:** `showKkSnack` artık bir `OverlayEntry`'yi kök gezginin `Overlay`'ine ekliyor. Ekran kapansa da bildirim yaşıyor, gezginin sonradan açtığı sayfaların da üstünde kalıyor. Dosya düzeyinde tek bir "şu anki bildirim" tutuluyor; yeni bildirim eskisini kaldırıyor. `hideKkSnack()` bağlam istemiyor, uygulamanın kökü kilitlenince onu çağırıyor.

**Teknoloji:** Flutter `Overlay`, mevcut `GlassSurface`, `KkMotion`.

**Tasarım belgesi:** [ust-bildirim.md](ust-bildirim.md)

## Genel kısıtlar

- Yer: durum çubuğunun 8 dp altı, yatayda orta, iki yanda en az 16 dp boşluk.
- Görünüm: `GlassSurface(blur: true, strong: true)`, hap biçimi (yarıçap 28), simge yok, renk yok.
- Yazı: `bodyLarge`, 16 punto, w700, `onSurface`. Düğme yazısı 16 punto, w800, `onSurface`.
- Hareket: giriş `KkMotion.base` + `KkMotion.standard`, çıkış `KkMotion.panelClose` + `KkMotion.exit`; "animasyonları kaldır" açıkken sıfır (`KkMotion.of`).
- Süre: düğmesiz 4 sn (`KkMotion.snack`), düğmeli 6 sn (`KkMotion.snackWithAction`). TalkBack açıkken (`MediaQuery.accessibleNavigationOf`) düğmeli bildirim kendiliğinden kapanmıyor.
- Süreler yalnızca `KkMotion`'da yazılır (tarama testi `motion_durations_test.dart`).
- Kod yorumları Türkçe.

## İnceleme odağı

1. Bildirimi gösteren ekran hemen kapanıyor (kayıt çöpe taşınınca ayrıntı ekranı kapanıyor): bildirim görünür kalmalı, "Geri al" çalışmalı.
2. Bildirim açıkken kasa kilitleniyor: bildirim kapanmalı.
3. Peş peşe iki bildirim: yalnızca ikincisi görünmeli, birincinin zamanlayıcısı ikincisini kapatmamalı.
4. Uzun mesaj (geri yükleme hataları): kesilmeden satıra inmeli, ekrandan taşmamalı.
5. Alttan açılan pencere açıkken bildirim: pencerenin üstünde görünmeli.

---

### Görev 1: Üstten inen bildirim

**Dosyalar:**
- Değiştir: `lib/app/ui/kk_snack.dart`, `lib/app/ui/kk_motion.dart`
- Değiştir: `lib/features/vault/presentation/login_detail_screen.dart`, `lib/features/authenticator/presentation/authenticator_screen.dart` (`SnackBarAction` → `KkSnackAction`, `hideCurrentSnackBar` → `hideKkSnack`)
- Test: `test/app/ui/kk_snack_test.dart`, `test/features/vault/vault_screens_test.dart:900`

**Arayüzler:**
- Üretir: `void showKkSnack(BuildContext context, String message, {KkSnackAction? action})`, `void hideKkSnack()`, `final class KkSnackAction { const KkSnackAction({required String label, required VoidCallback onPressed}); }`, bildirimin kök widget'ı `KkSnack` (testler bunu arar), `KkMotion.snack`, `KkMotion.snackWithAction`.

- [ ] **Adım 1: Başarısız testleri yaz** (`kk_snack_test.dart`, `SnackBar` aramaları `KkSnack`'e döner)
  - `ikinci bildirim birincinin yerini alır`: `find.byType(KkSnack)` bir tane, metin 'iki'.
  - `bildirim cam: arkasını bulanıklaştırır`: `KkSnack` altında bir `BackdropFilter`.
  - `bildirim üstte ve ortada`: hapın `getRect`'i `top >= padding.top + 8`, `top < 200`, merkezin x'i ekran ortası (±1).
  - `yazı 16 punto ve kalın`: mesaj `Text`'inin stili `fontSize == 16`, `fontWeight == FontWeight.w700`.
  - `düğmesiz bildirim 4 saniyede kapanır`: 3.9 sn sonra var, 4 sn + çıkış süresi sonra yok.
  - `düğmeli bildirim 6 saniye kalır, düğme çalışır ve kapatır`: 5.9 sn sonra var; yeni bildirimde düğmeye dokununca `onPressed` bir kez çağrılır ve bildirim kalkar.
  - `TalkBack açıkken düğmeli bildirim kendiliğinden kapanmaz`: `MediaQuery(accessibleNavigation: true)`, 30 sn sonra hâlâ var.
  - `yukarı kaydırınca kapanır`: `tester.drag(find.byType(KkSnack), Offset(0, -60))`, settle sonrası yok.
  - `peş peşe: eskinin zamanlayıcısı yenisini kapatmaz`: 'bir' göster, 3 sn bekle, 'iki' göster, 2 sn bekle → 'iki' görünür.
  - `ekran kapansa da bildirim kalır`: kök gezgine bir sayfa it, o sayfanın bağlamıyla göster, sayfayı kapat → bildirim görünür.
  - `alt pencere açıkken bildirim pencerenin üstünde`: `showModalBottomSheet` aç, göster; `tester.hitTestOnBinding` yerine `find.byType(KkSnack).hitTestable()` bir tane.
  - `hideKkSnack bildirimi kapatır`.
  - `animasyonlar kapalıyken anında görünür`: `MediaQuery(disableAnimations: true)`, tek `pump()` sonrası hap tam opak ve yerinde.
  - Var olan `copySensitive` testleri `KkSnack` ile kalır.
- [ ] **Adım 2: Testleri çalıştır, başarısız olduklarını gör.** `flutter test test/app/ui/kk_snack_test.dart` → FAIL.
- [ ] **Adım 3: Uygula.** `KkMotion.snack = Duration(seconds: 4)`, `KkMotion.snackWithAction = Duration(seconds: 6)`. `showKkSnack`: `Navigator.of(context, rootNavigator: true).overlay!`'e `OverlayEntry` ekler, öncekini anında kaldırır. `KkSnack` bir `StatefulWidget`: kendi `AnimationController`'ı (giriş/çıkış), `Timer` (süre bitince çıkış animasyonu, sonra `entry.remove()`), dikey sürüklemede yukarı 24 dp ya da yukarı hız varsa kapanır. `Semantics(liveRegion: true, container: true)`. Uzun metin satıra iner, `maxLines` yok. `Positioned(top: padding.top + 8, left: 16, right: 16)` içinde `Center` + `IntrinsicWidth` değil, `Align(alignment: topCenter)` ile içerik kadar geniş.
- [ ] **Adım 4: Çağıranları geçir** (`login_detail_screen`, `authenticator_screen`, `vault_screens_test:900`).
- [ ] **Adım 5: Testleri çalıştır.** `flutter test test/app/ui/kk_snack_test.dart test/features/vault test/features/authenticator` → PASS.
- [ ] **Adım 6: Commit** `özellik(arayüz): bildirim üstten iniyor, yazısı büyük ve kalın`

### Görev 2: Bütün bildirimler aynı yoldan

**Dosyalar:**
- Değiştir: `restore_screen.dart`, `settings_screen.dart`, `plaintext_export.dart`, `change_password_screen.dart`, `login_import_screen.dart`, `login_edit_screen.dart`, `backup_section.dart`, `autofill_setup_section.dart`, `autofill_save_screen.dart`, `otp_import_screen.dart`, `scanned_code_handler.dart`, `otp_edit_screen.dart`, `lib/app/theme.dart` (`snackBarTheme` kalkar)
- Test: `test/app/screens_use_kk_scaffold_test.dart` (yeni tarama), `test/app/theme_test.dart:190` (düz SnackBar testi kalkar), `import_screen_test.dart:175`, `qr_scan_test.dart:304`, `backup_section_test.dart:236` (`SnackBar` → `KkSnack`)

**Arayüzler:**
- Tüketir: Görev 1'deki `showKkSnack`, `hideKkSnack`.

- [ ] **Adım 1: Başarısız tarama testi yaz:** `bildirim yalnızca showKkSnack ile`: `lib/app` ve `presentation` altındaki kod satırlarında `SnackBar(`, `showSnackBar`, `hideCurrentSnackBar` geçmiyor (`kk_snack.dart` hariç değil, o da kullanmıyor).
- [ ] **Adım 2: Çalıştır, FAIL gör.**
- [ ] **Adım 3: Geçir.** `await` öncesinde `ScaffoldMessenger.of(context)` saklayan yerler bunun yerine `if (!context.mounted) return;` sonrası `showKkSnack(context, …)` çağırır. Bağlam o arada kapanmış olabiliyorsa (ekran kapanıp bildirim gösteriliyorsa) kök gezginin bağlamı önceden saklanır: `final root = Navigator.of(context, rootNavigator: true).context;`. `hideCurrentSnackBar` + `showSnackBar` çiftleri tek `showKkSnack` olur (yerine geçme zaten var). `snackBarTheme` ve tema testi kalkar.
- [ ] **Adım 4: Çalıştır:** `flutter test` → hepsi PASS, `flutter analyze` temiz.
- [ ] **Adım 5: Commit** `düzeltme(arayüz): bütün bildirimler üstten inen camda`

### Görev 3: Kilitlenince bildirim kapanır

**Dosyalar:**
- Değiştir: `lib/app/app.dart`
- Test: `test/app/app_test.dart`

- [ ] **Adım 1: Başarısız test:** `kilitlenince açık bildirim kapanır`: açık kasayla uygulamayı kur, `showKkSnack` göster, kasayı kilitle (`vaultControllerProvider` üzerinden), settle → `KkSnack` yok.
- [ ] **Adım 2: FAIL gör.**
- [ ] **Adım 3: Uygula:** `KeyKeyApp.build` içinde `ref.listen(vaultControllerProvider, (_, next) { if (next is! VaultOpen) hideKkSnack(); })`.
- [ ] **Adım 4: PASS gör.**
- [ ] **Adım 5: Commit** `düzeltme(arayüz): kilitlenince bildirim kapanıyor`

### Görev 4: Doğrulama ve belgeler

- [ ] `dart format`, `flutter analyze`, `flutter test`, entegrasyon testleri Android 17'de.
- [ ] `ust-bildirim.md` durumu "uygulandı", `tasarim-siyah-beyaz.md`'deki "alttaki cam bildirim" ibaresi güncellenir, yol haritasına durum satırı.
- [ ] Deneme APK'sı `keykey-deneme-15-ust-bildirim.apk` taslak sürüme yüklenir; proje sahibine telefonda denemesi için haber verilir.
- [ ] Commit `belge(tasarım): üstten inen bildirim uygulandı`

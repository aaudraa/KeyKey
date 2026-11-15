# Tema seçimi uygulama planı

> **Ajanlar için:** superpowers:executing-plans ile görev görev uygulanır. Adımlar `- [ ]` kutularıyla izlenir.

**Amaç:** Ayarlar'dan Sistem / Açık / Koyu tema seçilebilsin; seçim kilit ekranı ve otomatik doldurma dahil her yerde geçerli olsun.

**Mimari:** Seçim kasanın dışında, uygulama klasöründeki `theme` dosyasında şifresiz durur. `bootstrap` dosyayı okuyup başlangıç değerini verir; `themeModeProvider` iki `MaterialApp`'e `themeMode` olarak bağlanır; Ayarlar'daki satır alttan pencereyle değiştirir.

**Teknoloji:** Flutter, Riverpod 3, `dart:io`.

**Tasarım:** [tema-secimi.md](tema-secimi.md)

## Genel kurallar

- Dosya: `<getApplicationSupportDirectory>/theme`, içerik tam olarak `system`, `light` ya da `dark`.
- Dosya yok, okunamıyor ya da içerik tanınmıyorsa `ThemeMode.system`.
- Kasa dosyası açılamasa da (`VaultUnavailable` yolu) tema yüklenir.
- Metinler TR ve EN; kod adları İngilizce, yorumlar Türkçe.

## Gözden geçirmede bakılacaklar

- Dosyada boşluk ya da satır sonu varsa (`"dark\n"`) yine koyu okunmalı.
- Dosyaya yazılamazsa seçim yine de o oturumda uygulanmalı, uygulama çökmemeli.
- Otomatik doldurma penceresi ana uygulamadaki seçimi izlemeli (ayrı motor, aynı dosya).
- Pencere seçmeden kapatılırsa tema değişmemeli.
- Seçili tema Ayarlar satırında doğru adla görünmeli.

---

### Görev 1: Tercih dosyası ve sağlayıcı

**Dosyalar:**
- Oluştur: `lib/features/settings/data/theme_preference.dart`
- Oluştur: `lib/features/settings/application/theme_controller.dart`
- Değiştir: `lib/app/bootstrap.dart` (iki dönüş yolu), `lib/app/app.dart`, `lib/features/autofill/presentation/autofill_app.dart`
- Test: `test/features/settings/theme_preference_test.dart`

**Arayüzler:**
- `ThemeMode parseThemeMode(String text)` (boşluk kırpılır, bilinmeyen → system)
- `abstract interface class ThemePreferenceStore { Future<void> write(ThemeMode mode); }`
- `final class FileThemePreferenceStore implements ThemePreferenceStore { new(File file); Future<ThemeMode> read(); }`
- `themePreferenceStoreProvider: Provider<ThemePreferenceStore>` (varsayılan: hiçbir şey yazmayan depo; testler için)
- `initialThemeModeProvider: Provider<ThemeMode>` (varsayılan `ThemeMode.system`)
- `themeModeProvider: NotifierProvider<ThemeModeController, ThemeMode>`; `Future<void> select(ThemeMode mode)` önce durumu değiştirir, sonra yazar; yazma hatası (`FileSystemException`) yutulur, seçim oturumda kalır.

- [x] **Adım 1: Başarısız testler.** `parseThemeMode('light')==light`, `('dark\n')==dark`, `('')==system`, `('mavi')==system`; dosya yokken `read()==system`; `write(dark)` sonra `read()==dark` ve dosya içeriği `'dark'`; denetleyici `select(light)` sonrası durum `light` ve sahte depoya `light` yazılmış; yazamayan depoyla `select(dark)` hata atmaz, durum `dark`.
- [x] **Adım 2:** `flutter test test/features/settings/theme_preference_test.dart` → derleme hatasıyla düşer.
- [x] **Adım 3:** Arayüzleri yaz; `bootstrap` `File('${directory.path}/theme')` ile depoyu ve `await read()` sonucunu iki dönüş yolunda da geçirir (dizin `VaultDatabase` açılmadan önce alınır). `KeyKeyApp` ve `AutofillApp` `themeMode: ref.watch(themeModeProvider)` alır; `AutofillApp` `ConsumerWidget` olur.
- [x] **Adım 4:** Test geçer; `flutter test` tümü yeşil.
- [x] **Adım 5:** Commit `özellik(ayarlar): tema seçimi kasanın dışında saklanıyor`.

### Görev 2: Ayarlar'daki Tema satırı ve belgeler

**Dosyalar:**
- Değiştir: `lib/features/settings/presentation/settings_screen.dart`, `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`, `resources/docs/guvenlik-tasarimi.md`, `resources/yol-haritasi.md`
- Test: `test/features/settings/settings_test.dart`

**Arayüzler:** Görev 1'deki `themeModeProvider` ve `select`.

Metinler (TR / EN): `settingsGroupAppearance` "Görünüm" / "Appearance"; `settingsTheme` "Tema" / "Theme"; `themeSystem` "Sistem" / "System"; `themeLight` "Açık" / "Light"; `themeDark` "Koyu" / "Dark".

- [ ] **Adım 1: Başarısız widget testleri** (`pumpSettings` ile): "Görünüm" grubunda "Tema" satırı ve sağında "Sistem" görünür; satıra dokununca pencerede üç seçenek, seçili olanda `Icons.check_rounded`; "Koyu"ya dokununca pencere kapanır, `MaterialApp.themeMode == ThemeMode.dark`, satırda "Koyu" yazar ve kayıt deposuna `dark` yazılmıştır; pencere dışına dokunup kapatınca tema değişmez.
- [ ] **Adım 2:** `flutter gen-l10n`, test düşer.
- [ ] **Adım 3:** "Hakkında"dan önce `KkSection(title: settingsGroupAppearance)`; `ListTile` (`KkIconBox(icon: Icons.contrast_rounded)`, sağda seçili adın metni ve `chevron_right_rounded`); `showKkSheet<ThemeMode>` içinde `otp_code_tile` düzeninde başlık ve üç `ListTile`, seçilende `trailing: Icon(Icons.check_rounded)`; dönen değer `null` değilse `select`.
- [ ] **Adım 4:** Testler ve tüm kontroller yeşil (`dart format`, `flutter analyze`, `flutter test`).
- [ ] **Adım 5:** `guvenlik-tasarimi.md` dosya bölümüne `theme` dosyası satırı ve şifresiz kalanlar notu; yol haritasına durum satırı.
- [ ] **Adım 6:** Commit `özellik(ayarlar): Ayarlar'da tema seçimi`; push; APK, telefon denemesi.

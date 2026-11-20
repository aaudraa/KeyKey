# Kullanım kolaylıkları: uygulama planı

> **Yürütme:** superpowers:executing-plans (satır içi). Adımlar `- [ ]` ile izlenir. Görev başlıkları betikler için İngilizce "Task N".

**Amaç:** Arka plan kilidinde bekleme süresi, gizli olmayan kutularda normal klavye, Parolalar/Kartlar/Notlar'da toplu seçim ve Steam Guard kodları.

**Mimari:**
- İki yeni ayar şifreli kasa ayarlarına girer (sürüm 6).
- Arka plan kilidi `AutoLockScope`'ta iki saatle ölçülür.
- Klavye `SecretField`'in yeni `plain` parametresiyle seçilir.
- Toplu seçim `VaultScreen`'in yerel durumudur.
- Steam yeni bir `OtpKind`.

**Teknoloji:** Flutter, Riverpod; yeni bağımlılık yok.

**Tasarım:** [kullanim-kolayligi.md](kullanim-kolayligi.md)

## Genel kısıtlar

- Dal `faz/18-kullanim-kolayligi`, issue #157; commit'ler `Refs #157`, PR `Closes #157`.
- Türkçe metin, İngilizce kod adları; commit biçimi `<tür>(<alan>): …`.
- Güvenlik tasarımı her kural değişikliğiyle aynı commit'te güncellenir.
- Dokunma alanları 48 dp'nin altına inmez; %200 yazıda taşma yok.
- Sürüm `1.7.0+11`.

## İnceleme odağı

1. **Telefon uykuda:** 30 sn ayarında telefon 2 dakika uyuyup açılınca kasa kilitli olmalı; tekdüze saat uykuda durabilir.
2. **Saat geri alınınca:** kullanıcı telefon saatini geri alırsa kasa kilitlenmeli, süre uzamamalı.
3. **Gizli kutular sabit:** normal klavye ayarı açıkken parola, kullanıcı adı ve not metni yine `visiblePassword` (ya da kendi türleri) ve öğrenmesiz açılmalı.
4. **Seçim ve arama:** toplu seçimde arama daraltılınca görünmeyen seçili kayıtlar çöpe gitmemeli.
5. **Steam'i okuyamayan sürüm:** Steam hesabı olan yedeği eski sürüm açamaz; bu sessizce veri kaybına dönmemeli, ileti açık olmalı.

---

### Task 1: Ayarlar sürüm 6

**Dosyalar:** `lib/features/settings/data/app_settings.dart`, `lib/features/settings/application/*` (controller), `lib/features/settings/presentation/settings_screen.dart`, arb; testler `test/features/settings/*`.

- **Arayüz:**
  - `AppSettings.backgroundLock` (`BackgroundLock` enum: `immediately`, `seconds30`, `minute1`; `Duration get delay`).
  - `AppSettings.plainKeyboard` (bool).
  - Kayıt anahtarları `backgroundLockSeconds` (0/30/60) ve `plainKeyboard`; `currentVersion = 6`.
- [ ] Test: sürüm 6 yazılır ve okunur.
- [ ] Test: 1-5 sürümleri varsayılanlarla (Hemen, kapalı) okunur.
- [ ] Test: geçersiz saniye (ör. 45) ve yanlış tür okunmaz.
- [ ] Test: ayarlar ekranında iki yeni satır var, seçim kaydediliyor.
- [ ] Uygula, commit `özellik(ayarlar): arka plan kilidi süresi ve klavye ayarı`.

### Task 2: Arka plan kilidi

**Dosyalar:** `lib/features/lock/presentation/auto_lock_scope.dart`, gerekirse saat sağlayıcıları; `resources/docs/guvenlik-tasarimi.md`; testler `test/features/lock/lock_flow_test.dart`.

- **Arayüz:** `AutoLockScope` iki saat alır: `DateTime Function() wallClock` ve tekdüze süre (`Duration Function() monotonic`). Testler ikisini de ayrı ayrı ilerletir.
- [ ] Test: Hemen ayarında `hidden` anında kilitler (bugünkü davranış).
- [ ] Test: 30 sn'de 10 sn sonra `resumed` kasa açık.
- [ ] Test: 31 sn sonra kilitli.
- [ ] Test: tekdüze saat 5 sn, duvar saati 2 dk ilerleyince kilitli (uyku).
- [ ] Test: duvar saati geri gidince kilitli.
- [ ] Test: arka planda zamanlayıcı süre dolunca kilitler.
- [ ] Test: dosya seçicisi istisnası değişmez.
- [ ] Test: dönüşte listeler yeniden okunur.
- [ ] Uygula, güvenlik tasarımı "Otomatik kilit" ve tehdit modeli, commit `özellik(kilit): arka planda kilitlenme süresi`.

### Task 3: Normal klavye

**Dosyalar:** `lib/app/secret_field.dart`, form ekranları (login, card, note, otp edit), `vault_screen.dart` ve `authenticator_screen.dart` aramaları; testler `test/app/secret_field_test.dart` ve form testleri.

- **Arayüz:** `enum PlainKeyboard { text, url }`; `SecretField({PlainKeyboard? plain})`. Ayar açık ve `plain != null` ise `text` → `TextInputType.text` + `TextCapitalization.sentences`, `url` → `TextInputType.url`. Öneri, otomatik düzeltme ve öğrenme kapalı kalır.
- [ ] Test: ayar kapalıyken `plain` verilen kutu da `visiblePassword`.
- [ ] Test: ayar açıkken ad `text` + büyük harf, site `url`.
- [ ] Test: parola, kullanıcı adı, not metni ve 2FA anahtarı değişmiyor.
- [ ] Test: `enableIMEPersonalizedLearning` her durumda `false`.
- [ ] Uygula, güvenlik tasarımı "Arayüz koruması", commit `özellik(arayüz): gizli olmayan kutularda normal klavye`.

### Task 4: Toplu seçim

**Dosyalar:** `lib/features/vault/presentation/vault_screen.dart`, `vault_entry_tiles.dart`, yeni `bulk_move_sheet.dart` (gerekirse), kayıt denetleyicileri (toplu güncelleme), arb; testler `test/features/vault/vault_screens_test.dart`, erişilebilirlik testi.

- **Arayüz:** `VaultScreen` durumunda `Set<VaultEntryId> _selected`; seçim çubuğu; `VaultEntriesController` ya da tür denetleyicilerinde `moveToTrash(ids)`, `restore(ids)`, `moveToFolder(ids, String? folder)`.
- [ ] Test: uzun basma seçimi başlatır; dokunma seçer ya da bırakır; son seçim bırakılınca mod kapanır.
- [ ] Test: "Tümünü seç" süzülmüş görünen listeyi seçer.
- [ ] Test: çöpe taşıma ve "Geri al".
- [ ] Test: klasöre taşı, yeni klasör, klasörden çıkar.
- [ ] Test: arama daralınca gizlenen seçimler düşer.
- [ ] Test: geri tuşu ve sekme değişimi seçimi bırakır.
- [ ] Test: Kartlar'da yalnızca kartlar.
- [ ] Test: erişilebilirlik: seçili/değil etiketi, %200 yazıda çubuk taşmıyor.
- [ ] Uygula, commit `özellik(kasa): toplu seçim`.

### Task 5: Steam Guard

**Dosyalar:** `otp_parameters.dart`, `otp_generator.dart`, `otp_content.dart`, `otpauth_uri.dart`, `import/aegis_import.dart`, `import/twofas_import.dart`, `otp_edit_screen.dart`, OTP listesi; `resources/docs/guvenlik-tasarimi.md`; testler `test/features/authenticator/*`.

- **Arayüz:**
  - `OtpKind.steam` (`'steam'`).
  - `OtpParameters.steam({required Uint8List secret})`: digits 5, period 30, SHA1.
  - `OtpGenerator.codeFor` steam'de 5 harf döndürür; alfabe `23456789BCDFGHJKMNPQRTVWXY`.
- [ ] Test: bilinen anahtar ve zaman için Steam kodu (steam-totp kütüphanesinin test değeri).
- [ ] Test: kayıt `kind: steam` yazılır ve okunur; `digits` 5 değilse ya da `period` 30 değilse reddedilir.
- [ ] Test: Aegis `steam`, 2FAS `STEAM`, `otpauth://steam/…` ve `encoder=steam` içe aktarılır; "desteklenmiyor" sayısı düşer.
- [ ] Test: elle eklemede Steam türü, hane ve süre kutuları gizli.
- [ ] Test: listede 5 harf, gruplanmadan; kopyalama.
- [ ] Test: yedek ve şifresiz dışa aktarma `kind: steam` taşır.
- [ ] Uygula, güvenlik tasarımı, commit `özellik(2fa): Steam Guard kodları`.

### Task 6: Cihaz, belgeler, sürüm, gözden geçirme

- [ ] Android 17 ve 11'de bütün cihaz testleri ve bu fazın cihaz denemeleri (bekleme süresi, klavye, toplu çöpe taşıma, Steam).
- [ ] Kılavuz, değişiklik günlüğü 1.7.0, mağaza sürüm notu 11, sürüm `1.7.0+11`, yol haritası (Faz 18 bölümü, fikir tablosundaki faz numaraları).
- [ ] Taze gözden geçirici, bulgular önce testle, PR, birleştirme, 1.7.0 yayını.

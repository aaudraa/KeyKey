# Kartlar ve notlar için gezinme: uygulama planı

> **Yürütme:** superpowers:executing-plans (satır içi). Adımlar `- [ ]` ile izlenir. Görev başlıkları betikler için İngilizce "Task N".

**Amaç:** Kartları ve notları alttaki menüye kendi sekmeleri olarak taşımak; kasa listesinin üstündeki tür çiplerini kaldırmak.

**Mimari:** `StatefulShellRoute` beş dala çıkar (`/kasa`, `/kartlar`, `/notlar`, `/2fa`, `/ayarlar`). `VaultScreen` ve `TrashScreen` bir `VaultKind` alır; aynı ekran türe göre üç kez kurulur. Menü bileşeni değişmez, yalnızca beş öğe alır.

**Teknoloji:** Flutter, go_router, Riverpod; yeni bağımlılık yok.

**Tasarım:** [gezinme.md](gezinme.md)

## Genel kısıtlar

- Dal `faz/17-gezinme`, issue #153, commit'ler `Refs #153`, PR `Closes #153`.
- Türkçe metin, İngilizce kod adları; commit `<tür>(<alan>): …`.
- Dokunma alanları 48 dp'nin altına inmez; %200 yazıda taşma yok.
- Sürüm değişmez (`1.6.0+10`, Faz 16 ile birlikte yayımlanır).

## İnceleme odağı

1. Kart formundan kaydedince Kartlar sekmesindeki listeye dönülür, Parolalar'a değil.
2. Kartlar sekmesinde çöp kutusunda "tümünü geri al" parolalara dokunmaz.
3. Kilit açılınca kilitten önceki sekmeye ve ekrana dönülür (Kartlar'daki bir kart dahil).
4. Kartlar sekmesinde bir klasör seçiliyken o klasördeki son kart silinince süzgeç kalkar.
5. Etkin sekmeye yeniden dokunmak o sekmenin listesine döner; kaydedilmemiş form sorulur.

---

### Task 1: Türe göre liste ve çöp kutusu

**Dosyalar:** `lib/features/vault/presentation/vault_screen.dart`, `lib/features/vault/presentation/trash_screen.dart`, `lib/l10n/app_*.arb`; test `test/features/vault/vault_screens_test.dart` ve kart/not testleri.

- **Arayüz:** `VaultScreen({required VaultKind kind})`, `TrashScreen({required VaultKind kind})`. `LoginFilter.kind` her zaman ekranın türü; tür çipleri yok.
- **Metinler:** `navPasswords` "Parolalar"/"Passwords", `navCards` "Kartlar"/"Cards", `navNotes` "Notlar"/"Notes"; `vaultSearchCount` türe göre (`cardsSearchCount`, `notesSearchCount`); `cardsEmpty`, `notesEmpty`; `trashTitle` aynı.
- [ ] Test: Kartlar listesi yalnızca kartları gösterir, tür çipi yok, menüde parola raporu yok; Notlar aynı; Parolalar'da rapor var.
- [ ] Test: kart çöp kutusu yalnızca kartları gösterir; "tümünü geri al" parolaya dokunmaz.
- [ ] Test: Kartlar'da son kart silinince klasör süzgeci kalkar.
- [ ] Uygula, `flutter test test/features/vault` yeşil, commit `özellik(kasa): türe göre liste ve çöp kutusu`.

### Task 2: Menüde beş sekme ve yeni adresler

**Dosyalar:** `lib/app/router.dart`, `lib/app/app_shell.dart`, `lib/features/vault/presentation/vault_entry_tiles.dart` (adresler), `lib/app/ui/add_panel.dart` gerekirse; test `test/app/*`, `test/app/ui/glass_nav_bar_test.dart`.

- **Adresler:** `AppRoutes.cards = '/kartlar'`, `cardNew = '/kartlar/yeni'`, `cardItem(id) = '/kartlar/$id'`, `cardItemEdit(id) = '/kartlar/$id/duzenle'`, `cardsTrash = '/kartlar/cop'`; notlar aynı kalıpla `/notlar`. `vaultTrash` `/kasa/cop` kalır.
- [ ] Test: menüde beş sekme, sırası ve adları; "Kartlar\nSekme 2/5"; Kartlar'a dokununca kart listesi.
- [ ] Test: "+" → Kart → kaydet → Kartlar listesi ve yeni kart; Not aynı.
- [ ] Test: kilit açılınca kartın ayrıntısına dönülür.
- [ ] Test: dar ekranda (360 dp) ve %200 yazıda menü taşmaz.
- [ ] Uygula, `flutter test` yeşil, commit `özellik(arayüz): kartlar ve notlar menüde`.

### Task 3: Tanıtım ve erişilebilirlik

**Dosyalar:** `lib/features/onboarding/presentation/intro_art.dart`, arb; test `test/features/onboarding/intro_test.dart`, `test/accessibility/accessibility_test.dart`.

- [ ] Test: "Ne nerede" sayfasında altı satır (Parolalar, Kartlar, Notlar, 2FA, Ayarlar, Ekle) ve beş sekmeli menü kopyası; %200 yazıda taşma yok.
- [ ] Erişilebilirlik testine kart ve not listeleri, kart çöp kutusu.
- [ ] Uygula, commit `özellik(tanitim): menüdeki yeni sekmeler`.

### Task 4: Cihaz, belgeler, gözden geçirme

- [ ] Entegrasyon testleri (`app_test`, `vault_flow_test`, `card_note_test`) yeni sekmelere göre; Android 17 ve 11'de bütün entegrasyon testleri.
- [ ] Kılavuz, cam tasarım belgesi, değişiklik günlüğü 1.6.0, yol haritası (Faz 17 ve kaydırılan fazlar).
- [ ] Taze gözden geçirici, bulgular önce testle, PR, birleştirme.

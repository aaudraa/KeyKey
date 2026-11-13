# KeyKey Siyah-Beyaz Tasarım ve Hareket Planı

Tasarım incelemesinin ([#103](https://github.com/aaudraa/KeyKey/issues/103)) üçüncü turunun tasarım belgesi. 2026-11-13'te proje sahibiyle örnek ekranlar üzerinden konuşuldu. **Durum: kodda bitti (2026-11-13). Planın 15 görevi tamam; telefonda üçüncü deneme ve #103'ün kapanışı proje sahibinin onayını bekliyor.** Açık sorular 2026-11-13'te yanıtlandı; proje sahibi kullanım sırasında süren hareket istedi (1.10, 1.11, kural 3). Uygulamada verilen kararlar ilgili maddelerin yanında italik notlar olarak duruyor. Uygulama planı: [`tasarim-siyah-beyaz-plani.md`](tasarim-siyah-beyaz-plani.md).

Bu belge [cam tasarım belgesinin](tasarim-cam.md) "Renkler", "Zemin" ve "Hareket" bölümlerinin yerine geçer ve ölçüleri küçültür. O belgenin geri kalanı (ekranların düzeni, tek "+", sade formlar, davranış değişiklikleri, kısıtlar) ve [ilk belgenin](tasarim-yenileme.md) otomatik doldurma kuralları aynen geçerlidir.

Örnek ekranlar: [`resources/design/siyah-beyaz-tasarim-ornekleri.html`](../design/siyah-beyaz-tasarim-ornekleri.html) (tarayıcıda açılır; açık/koyu tema düğmesi ve giriş hareketlerini yeniden oynatan düğme var). Örnekler yönü gösterir; kesin kural bu belgedir.

## Neden

Cam tasarım kodda bitti ve proje sahibi telefonda denedi. Kendi sözleriyle:

- "Çok fazla turunculuk olmuş, pek içime sinmedi. Uygulama düşünülünce turuncu akıllara gelsin yeter. Kilit noktalar turuncu olsa yeter."
- Renkli her şey (zemin, simgeler, logolar) siyah-beyaz olsun; açık ve koyu tema ikisi de kalsın.
- "Ayarlar menüsü falan, yazılar büyük geldi. Butonlar da büyük."
- "Information kısmı da butonun solunda olsa iyi olur."
- "Logoların arka planı olmasın, sadece logolar olsa yeter, transparan şekilde."
- "Cam efektleri, + butonuna basınca arka planın bulanıklaşması gibi efektleri kaldırmayalım, onlar hoş."
- "Ben animasyon çok severim. Çoğu yere animasyon koyabilirsin, abartmadıkça."

## Hedefler

1. Siyah, beyaz ve gri bir uygulama; turuncu yalnızca imza olarak dört yerde.
2. Cam hissi korunur: cam kartlar, cam menü, "+" açılınca bulanıklaşan arka plan.
3. Daha küçük yazı, satır ve düğmeler; ekrana daha çok şey sığar, kalabalık görünmez.
4. Planlı ve katmanlı hareket: çoğu etkileşimin bir hareketi olur, hiçbiri bekletmez.

## Hedef olmayanlar

- Ekranların düzeni, akışlar ve uygulamanın yaptığı işler değişmez (cam belgesindeki gibi). İstisna: aşağıda "Açık sorular"da sorulan küçülen büyük başlık.
- Yeni izin, yeni bağımlılık, gömülü yazı tipi ya da logo paketi eklenmez. Hareketler Flutter'ın kendi araçlarıyla yapılır (Lottie, Rive vb. yok). *(Benim kararım.)*
- Uygulama simgesi ve açılış ekranının zemini değişmez.

## Olmaması gerekenler

- Turuncunun dört yerin dışına sızması ("yine çok turuncu").
- Camın kaybolması: düz gri kutulara dönmüş bir uygulama.
- Hareketin işi yavaşlatması: bir hareket bitmeden sonraki dokunuş yapılamıyorsa hatadır.
- Kaydırmanın takılması (Samsung telefon ve Android 11 emülatörü).
- Erişilebilirliğin gerilemesi: kontrast (yazıda 4,5:1, simgede 3:1), en az 48 dp dokunma alanı, %200 yazı boyutu, TalkBack, "animasyonları kaldır".
- Rengi tek bilgi taşıyıcı yapmak: renk kalktığı için durumlar (hata, güç, seçili) biçim ve metinle de anlaşılmalı.

## Yaklaşımlar

| Yaklaşım | Artısı | Eksisi | Sonuç |
|---|---|---|---|
| A. Düz siyah-beyaz, camsız (ince kenarlı düz kartlar) | En sade, en ucuz çizim | Cam ve bulanıklık kaybolur | İlk örnekte gösterildi; proje sahibi camı geri istedi |
| **B. Siyah-beyaz zemin, renksiz ışık lekeleri, cam** | Cam görünür kalır, renk yok | Lekeler ve bulanıklık çizim maliyetini korur | **Seçildi** (ikinci örnek) |
| C. Camı korumak için zeminde hafif turuncu ışıltı | Cam daha canlı | "Çok turuncu" şikâyetine geri döner | Elendi |

## Görsel dil

### Renkler

Örnek ekranlardaki değerler. Kesin tonları plan kontrast testiyle belirler.

| Rol | Açık tema | Koyu tema |
|---|---|---|
| Zemin | `#E6E6E8` | `#000000` |
| Işık lekeleri (üç adet, renksiz) | beyaz, `#A9A9AE`, beyaz | `#5A5A5E`, `#3A3A3E`, `#4A4A4E` |
| Cam kart | beyaz %88 (proje sahibi "kartların içi gri değil beyaz olsun" dedi; önce %52), beyaz kenar, üstte ince parlak çizgi, hafif gölge | beyaz %7, beyaz %15 kenar |
| Yazı | `#111111` | `#F4F4F4` |
| İkincil yazı | `#6B6B6B` (testte geçmezse koyulaşır) | `#9A9A9A` |
| Seçili/basılı zemini | siyahın %6'sı | beyazın %9'u |
| Turuncu | `#F26B1D` | `#FF8A4C` |
| Turuncu üstündeki yazı ve simge | `#1A0D05` | `#1A0D05` |

Zemindeki lekeler cam belgesindeki gibi yumuşak geçişli boyamayla çizilir, yalnızca renkleri değişir. Kodda bu, `lib/app/theme.dart` içindeki renk sabitleri ile `blobsLight`/`blobsDark` listelerinin değişmesidir.

### Turuncu nerede

Yalnızca şu dört yerde:

1. **K logosu** (kilit ekranı, açılış, otomatik doldurma penceresinin başlığı).
2. **"+" düğmesi.** Düz turuncu, geçişsiz ve gölgesiz.
3. **Ekranın tek ana düğmesi:** "Kilidi aç", "Kaydet", kurulumdaki "Devam". Bir ekranda en çok bir tane.
4. **2FA süre halkası.**

Geri kalan her şey siyah-beyazdır *(benim kararlarım, örneklerde gösterildi)*:

- Seçili sekme, bağlantılar ("Parolamı unuttum" altı çizili), grup başlıkları: yazı rengi.
- İkincil düğmeler ("Yedekle", "Üret", "Geri yükle"): dolu siyah/beyaz ya da ince kenarlı.
- Anahtarlar (switch): açıkken dolu siyah/beyaz.
- Parola gücü çubuğu ve "kopyalandı" bildirimi: renksiz; güç metinle de yazılır ("Zayıf", "Güçlü"). Proje sahibi renksiz güç çubuğunu onayladı.
- Hata metni ve hata kenarı kırmızı kalır: hata rengi süs değil, bilgi.

### Cam

- Kartlar yarı saydamdır, arkalarını canlı bulanıklaştırmaz (liste takılmasın diye; bugünkü gibi).
- Gerçek bulanıklık yalnızca şuralarda: alt menü, "+" kutusu ve arkasındaki perde, alttan açılan pencereler, bildirim.
- "+" açılınca arka plan bulanıklaşır ve hafifçe kararır (bugünkü davranış korunur).
- Alt menü buzlu camdır: dolgusu çok saydam (açıkta beyaz %5, koyuda %3), bulanıklık hafif (10), üstten aşağı sönen beyaz parıltı. İkinci denemede proje sahibi daha saydam istedi. Proje sahibi ilk denemede "camsı his yok" dedi (2026-11-13); renksiz zeminde güçlü bulanıklık menüyü düz gri bir kutuya çeviriyordu.

### Ölçüler

Örnek ekranlardaki oranlar; kesin dp değerlerini plan belirler. Dokunma alanı hiçbir yerde 48 dp'nin altına inmez: küçülen görünüştür, basılan alan değil.

| Öğe | Bugün (örnek ölçüsü) | Yeni |
|---|---|---|
| Ekran başlığı ("Kasa") | 30, çok kalın | 22, kalın |
| Alt ekran başlığı | 21 | 17 |
| Kart satırı yüksekliği | 64 | 54 |
| Kart başlığı / alt yazı | 15 / 12,5 | 13,5 / 11,5 |
| Ayar satırı yüksekliği / yazısı | 56 / 14,5 | 46 / 13 |
| Form alanı yüksekliği | 60-64 | 52-54 |
| Ana düğme yüksekliği | 54-56, tam yuvarlak | 44-46, 14 köşe |
| Alt menü yüksekliği | 60 | 52 |
| "+" düğmesi | 48 | 40 (dokunma alanı 48) |
| Kart köşesi | 22 | 16 |
| Anahtar (switch) | 46×28 | 36×21 (dokunma alanı 48) |

En küçük yazı 11 sp'nin altına inmez. %200 yazı boyutunda taşma testleri yeniden geçmelidir.

### Simgeler ve logolar

- Kayıt simgesinin arkasındaki renkli kutu kalkar. Simgesi olmayan kayıtta harf, ince çizgili bir dairenin içinde durur (yazı renginde, saydam zeminde; proje sahibinin seçimi).
- Bağlı uygulamanın simgesi kutusuz ve kendi renkleriyle çizilir. (İlk denemede siyah-beyazdı; proje sahibi telefonda görünce renkli istedi, 2026-11-13.)
- Ayarlardaki ve "+" kutusundaki simgelerin turuncu zeminli kutuları kalkar; simge yazı renginde, tek başına durur.
- K logosu beyaz kutusuz, yalnızca turuncu harf olarak çizilir. Uygulamanın başlatıcıdaki simgesi değişmez.
- Kodda: `record_avatar.dart`, `kk_section.dart` (`KkIconBox`), `keykey_logo.dart`, `add_panel.dart`.

### Ayarlar

- Satırlar alçalır, yazılar küçülür (yukarıdaki tablo).
- Bilgi (i) simgesi satırın sağında, anahtarın ya da okun **hemen solunda** durur. Dokununca bugünkü bilgi penceresi açılır.
- Üstteki yedek kartı kalır; "Yedekle" düğmesi siyah-beyaz olur.

## Hareket planı

### Kurallar

1. Her hareket 150-450 ms sürer. Hiçbiri bekletmez: hareket sürerken dokunuşlar çalışır, yeni hareket eskisini yarıda keser.
2. Aynı anda tek ana hareket; diğerleri ona eşlik eder (daha kısa, daha küçük).
3. Hareket yalnızca ilk girişte kalmaz, uygulama kullanılırken de sürer (proje sahibinin isteği): her dokunuşun bir karşılığı vardır (Katman 2 ve 3), ekrana her dönüşte giriş hareketi oynar (1.10) ve zemin bütün ekranlarda çok yavaş kayar (1.11). Kendi kendine süren öteki hareketler: kilit ekranı, 2FA halkası, ilerleme göstergeleri. Sürekli kayan zemin, alt menünün bulanıklığını her karede yeniden çizdirir; telefonda pil ya da takılma görülürse önce zeminin hızı ve kare sıklığı düşürülür, gerekirse 1.11 çıkarılır.
4. Kaydırırken ekrana giren kartlar da giriş hareketiyle gelir (proje sahibinin isteği, 2026-11-13: "aşağı yukarı kaydırırken fark edilsin"). Kaydırma sırasında başka yeni hareket başlamaz (küçülen başlık dışında). Giriş hareketi proje sahibine çok hızlı geldi: süre `enter` (350 ms) ve yay eğrisi kullanılır, bugünkü 250 ms değil.
5. Yalnızca ucuz hareketler: yer, ölçek, saydamlık, döndürme. Bulanıklık ya da gölge canlandırılmaz.
6. Telefonda "animasyonları kaldır" açıksa hepsi anında olur (`KkMotion.of`), süren hareketler durur (`ambientMotionProvider`).
7. Android'in geri hareketi önizlemesiyle çakışan özel geçiş yapılmaz.
8. Güvenlik: hareketler gizli veriyi `FLAG_SECURE` dışına çıkarmaz; parola gösterme hareketi, gösterme iznini (kimlik onayı gerekiyorsa) beklemeden başlamaz.

### Ortak değerler

`lib/app/ui/kk_motion.dart` bunlara genişletilir; ekranlar süre ya da eğriyi elle yazmaz.

| Ad | Değer | Kullanım |
|---|---|---|
| `fast` | 150 ms | Basma, simge değişimi |
| `base` | 250 ms | Solma, kayma, anahtar |
| `enter` | 350 ms | Öğe girişi, ekran geçişi |
| `panelOpen` / `panelClose` | 400 / 200 ms | Kutu ve pencereler |
| `emphasis` | 450 ms | Kilit açılışı, kaydetme onayı |
| `stagger` | 40 ms | Sıradaki öğeler arası gecikme (en çok 8 öğe) |
| `spring` | `Cubic(0.2, 1.35, 0.4, 1)` | Yaylanan girişler |
| `standard` | `Curves.easeOutCubic` | Kayma ve solma |
| `exit` | `Curves.easeInCubic` | Çıkışlar |

### Katman 1: Temel (her ekranda)

| No | Yer | Hareket | Süre / eğri | Kodda | Bugün |
|---|---|---|---|---|---|
| 1.1 | Ekran açılışı ve kaydırma | Görünen satırlar 16 dp aşağıdan ve %96 ölçekten sırayla yerine oturur; kaydırırken ekrana giren her kart da aynı hareketle gelir (sıra gecikmesi olmadan) | `enter`, `spring`, `stagger` | `kk_entrance.dart` | Var (12 dp, ölçeksiz, yalnızca ilk kare); güçlendirilir |
| 1.2 | Alt menü ve alttaki ana düğme | Ekran açılırken alttan yaylanarak gelir | `enter`, `spring` | `glass_nav_bar.dart`, `kk_bars.dart` (`KkBottomAction`) | Yeni |
| 1.3 | Basma | Kart ve satır %96,5'e, küçük düğme ve simge %88'e esner; bırakınca yaylanır. Dalga efekti kalır | `fast`, `spring` | `kk_card.dart`, `kk_bars.dart`, yeni ortak `KkPressable` | Kartta var (%98); yaygınlaştırılır |
| 1.4 | Ekran geçişi | Form ve alt ekranlar sağdan 24 dp kayarak ve solarak açılır; karttan ayrıntıya büyüme kalır. *Geçişin kendisi Flutter'ın tahmini geri geçişi (FadeForwards); süresi `enter` değil. Son incelemede bütün rotaların geçişsiz açıldığı bulundu (go_router uygulama türünü `material_ui` paketinin `MaterialApp`'iyle tanıyor); rotalar artık `kkRoute` ile `MaterialPage` kuruyor, kilit ekranı `fast` solmayla geliyor (4.4).* | `enter`, `standard` | Tema `pageTransitionsTheme` | Kısmen var |
| 1.5 | Sekme değişimi | Kapsül kayar, seçilen simge küçük bir zıplama yapar (%100 → %118 → %100), içerik kısa solar | `base`, `spring` | `glass_nav_bar.dart`, `app_shell.dart` | Kapsül var; zıplama yeni |
| 1.6 | "+" kutusu | Yaylanarak açılır, satırlar sırayla belirir, "+" çarpıya döner, arka plan bulanıklaşır | `panelOpen` / `panelClose` | `add_panel.dart` | Var; korunur |
| 1.7 | Anahtarlar | Topuz yaylanarak kayar, zemin rengi yumuşak değişir | `base`, `spring` | Tema `switchTheme` ya da ortak `KkSwitch` | Yeni |
| 1.8 | Alttan açılan pencereler ve (i) | Yaylanarak açılır, aşağı çekince parmağı izler | `panelOpen` | `kk_sheet.dart` | Var; korunur |
| 1.9 | Büyük başlık | Kaydırınca küçülüp üst çubuğa oturur | Kaydırmaya bağlı | `vault_screen`, `authenticator_screen`, `settings_screen` | Yeni; onaylandı |
| 1.10 | Her dönüş | Giriş hareketi (1.1) yalnızca ekranın ilk açılışında değil, her sekme değişiminde ve alt ekrandan geri dönüşte de oynar | `enter`, `spring`, `stagger` | `kk_entrance.dart`, `app_shell.dart` | Bugün yalnızca ilk açılışta; proje sahibinin isteği |
| 1.11 | Zemin | Işık lekeleri bütün ekranlarda çok yavaş kayar (kilit ekranındaki gibi, daha sakin). Kaydırırken, uygulama arka plandayken ve "animasyonları kaldır" açıkken durur | Sürekli, 30-40 sn döngü | `kk_backdrop.dart` | Bugün yalnızca kilit ekranında; proje sahibinin isteği |

### Katman 2: Geri bildirim

| No | Olay | Hareket | Süre / eğri | Kodda |
|---|---|---|---|---|
| 2.1 | Kopyalama | Satırdaki kopyala simgesi onay işaretine döner (ölçek + solma), 1 sn sonra geri döner; alttaki cam bildirim de çıkar | `fast` + 1 sn | `vault_screen`, `login_detail_screen`, `otp_code_tile`, `kk_snack.dart`; yeni ortak `KkCopyIcon` |
| 2.2 | Kaydetme | Düğmedeki yazı onay işaretine döner, ekran kapanır, listede yeni/değişen kart bir kez parlar (zemin %0 → %10 → %0) | `emphasis` | `login_edit_screen`, `otp_edit_screen`, `kk_form.dart`, liste ekranları |
| 2.3 | Silme / çöpe atma | Kart sola kayıp solar, yüksekliği sıfıra iner, alttakiler yukarı kayar | `base`, `exit` | `vault_screen`, `authenticator_screen`, `trash_screen`, `otp_trash_screen` |
| 2.4 | Hata | Yanlış ana parolada ve boş zorunlu alanda kutu üç kısa salınımla titrer (±8 dp); hata metni solarak gelir | 300 ms | `lock_screen` (var), `kk_form.dart` (yeni) |
| 2.5 | Hata titreşimi | 2.4 ile birlikte hafif dokunsal titreşim | — | `HapticFeedback`; onaylandı |
| 2.6 | "Daha fazla seçenek" | Ok 180° döner, yongalar sırayla küçükten büyür; dokunulan yonga kaybolur, alan yükseklik açarak gelir | `base`, `spring`, `stagger` | `login_edit_screen`, `kk_form.dart` |
| 2.7 | Liste içi değişim | Süzgeç ya da sıralama değişince kartlar yeni yerine kayar. *Uygulamada yer değiştiren kart eski yerinden solup yenisinde belirir: gerçek kaydırma 1000 kayıtlı listede pahalı. (Benim kararım, plan Görev 10.)* | `base`, `standard` | `vault_screen` |

### Katman 3: İçerik

| No | Yer | Hareket | Süre / eğri | Kodda |
|---|---|---|---|---|
| 3.1 | Parolayı göster/gizle | Noktalar soldan sağa sırayla karakterlere döner (karakter başına 12 ms, toplam en çok 300 ms); gizlerken tersine. Göz simgesi çizgili göze geçer. *Gizliyken uzunluğu belli etmemek için hep 8 nokta görünür; formdaki yazma kutusu (TextField) karakter karakter dönmez, yalnızca ayrıntı ekranındaki değer döner. (Benim kararım, Görev 12.)* | ≤ 300 ms | `login_detail_screen`, `kk_form.dart`, yeni ortak `KkSecretText` |
| 3.2 | "Üret" | Karakterler 250 ms rastgele karışıp yeni parolaya oturur; güç çubuğu sıfırdan yeniden dolar. Karışan karakterler süs amaçlı rastgeledir, gerçek parola değildir. *Üretici penceresinde güç çubuğu yok (bit sayısı yazıyor); çubuk, parola formunda "Üret" ile dolan parolada 3.3'teki gibi kayar.* | 250 + `enter` | `generator_sheet.dart`, `password_strength_meter.dart` |
| 3.3 | Güç çubuğu | Değer değiştikçe genişlik yumuşak kayar | `base` | `password_strength_meter.dart` |
| 3.4 | 2FA kodu yenilenince | Eski rakamlar yukarı kayıp solar, yenileri alttan gelir (rakamlar arası 20 ms) | `base`, `standard` | `otp_display.dart`, `otp_code_tile.dart` |
| 3.5 | 2FA son 5 saniye | Halka saniyede bir hafifçe atar (%100 → %112) | 1 sn döngü | `otp_ring.dart` |
| 3.6 | Arama | Yazdıkça elenen kartlar solar, kalanlar kayarak yerleşir; sonuç yoksa boş durum solarak ve 8 dp yükselerek gelir | `base` | `vault_screen`, `authenticator_screen` |
| 3.7 | Sayılar | "24 kayıt", "6 hesap" değişince eski sayı yukarı çıkar, yenisi alttan gelir. *Uygulanmadı: sayı yalnızca arama kutusunun boşken görünen ipucunda duruyor ve kayıt başka ekranda eklenip silindiği için değişim hiç görülmüyor. (Benim kararım, Görev 12.)* | `fast` | Liste ekranları |

### Katman 4: Özel anlar

| No | Yer | Hareket | Süre / eğri | Kodda |
|---|---|---|---|---|
| 4.1 | Açılış | K logosu %80 ölçekten ve solarak belirir (sistem açılış ekranından kesintisiz devam eder) | `enter` | `keykey_logo.dart`, `lock_screen` |
| 4.2 | Kilit ekranı | Lekeler çok yavaş kayar, K süzülür, parmak izi simgesi yavaş nefes alır | Sürekli | `kk_backdrop.dart`, `lock_screen` (ilk ikisi var) |
| 4.3 | Kilit açılınca | K yukarı çekilip küçülür ve solar, kasa alttan yükselir. Açılışı geciktirmez: kasa hazır olunca başlar, içerik hareketin altında çizilir | `emphasis`, `standard` | `lock_screen`, `app_shell.dart` |
| 4.4 | Kilitlenince | İçerik hızla solar, kilit ekranı belirir. Gizli veri ekranda hareketle oyalanmaz | `fast` | `auto_lock_scope.dart` |
| 4.5 | Yedek kartı | Yedek eskiyse ayarlara her girişte kart bir kez hafifçe atar (%100 → %103) | `emphasis` | `backup_status_card.dart` |
| 4.6 | İçe/dışa aktarma, yedek, geri yükleme | İlerleme halkası döner; bitince halka onay işaretine çizilerek döner | `emphasis` | `login_import_screen`, `otp_import_screen`, `restore_screen`, `backup_section`; yeni ortak `KkDoneMark` |
| 4.7 | Kurulum adımları | Adımlar arası içerik yana kayar, adım göstergesi dolarak ilerler | `enter`, `standard` | `onboarding_screen`, `new_password_screen`, `recovery_screen` |
| 4.8 | QR tarama | Çerçeve köşeleri yavaşça nefes alır; kod okununca çerçeve kodun üstüne kapanır | Sürekli + `base` | `qr_scan_screen` |
| 4.9 | Otomatik doldurma | Pencere yaylanarak açılır; seçilen satır basılı kalır, pencere aşağı kapanır | `panelOpen` / `panelClose` | `autofill_sheet_frame.dart`, `autofill_pick_screen.dart` |

### Yeni ortak parçalar

Hareketler ekranlara dağılmasın diye `lib/app/ui/` altında toplanır:

- `KkPressable`: basınca esneyen sarmalayıcı (1.3).
- `KkCopyIcon`: kopyala ↔ onay simgesi (2.1).
- `KkSecretText`: sırayla açılan/kapanan gizli metin (3.1).
- `KkRollingText`: rakam ve sayı değişimi (3.4, 3.7).
- `KkShake`: titreme (2.4); kilit ekranındaki bugünkü kod buraya taşınır.
- `KkDoneMark`: çizilen onay işareti (2.2, 4.6).
- `KkAnimatedList` yardımcıları: ekleme, silme ve yer değiştirme (2.2, 2.3, 2.7, 3.6).

## Uygulama sırası

Her adım ayrı commit ve push; her aşamanın sonunda telefona kurulup proje sahibi dener.

| Aşama | İçerik | Bitince |
|---|---|---|
| 0 | Renkler, lekeler, turuncunun dört yere çekilmesi; kontrast testleri | Emülatörde testler |
| 1 | Ölçüler: yazı, satır, düğme, menü; simge ve logo kutularının kalkması; ayarlarda (i) yeri | **Telefonda deneme 1** (görünüm) |
| 2 | Hareket altyapısı (`KkMotion` değerleri, ortak parçalar) ve Katman 1 | |
| 3 | Katman 2 | **Telefonda deneme 2** |
| 4 | Katman 3 | |
| 5 | Katman 4 | **Telefonda deneme 3** (son) |

Takılan ya da fazla gelen hareket, denemede sadeleştirilir ya da çıkarılır; madde numaraları (1.1 … 4.9) bunun için var.

## Denetim

- Format, analiz, birim ve entegrasyon testleri (Android 11, 14, 17 emülatörleri, `-gpu host`).
- Kontrast testi yeni renklerle, lekelerin en kötü noktasında.
- Taşma testleri %200 yazı boyutunda yeni ölçülerle.
- Her hareket için: "animasyonları kaldır" açıkken anında bittiğini ve süren hareketin durduğunu gösteren test.
- Hareket sürerken dokunmanın çalıştığını gösteren testler (kaydetme, kopyalama, kilit açılışı).
- Tarama testi: ekranlarda elle yazılmış süre (`Duration(milliseconds:`) kalmaması; hepsi `KkMotion`'dan gelir.
- 1000 kayıtlı listede savurma ölçümü, cam turundaki sayılarla karşılaştırılır.
  - *Ölçüm (2026-11-13, Görev 11, Android 14 emülatörü, debug, `KKPERF`):* yükleme 408 ms, dört arama toplam 9 ms, yazıp süzme 374 ms, beş savurma ve durulma 17,4 sn. Cam turunda savurma ölçülmemişti; karşılaştırma için en yakın sayılar [güvenlik denetimindeki](guvenlik-denetimi.md) telefon ölçümü: yükleme 310 ms, arama 26 ms, yazıp süzme 363 ms. Yazıp süzme aynı düzeyde kaldı; savurma sayısı bundan sonraki turlar için dayanak.
- Samsung telefonda proje sahibiyle üç deneme (yukarıdaki tablo).

## Açık soruların yanıtları (2026-11-13)

1. Küçülen büyük başlık (1.9): eklenir.
2. Hata titreşimi (2.5): eklenir.
3. Simgesiz kayıtta harf: ince çizgili daire içinde.
4. Parola gücü çubuğu: renksiz kalır; hata kırmızısı kalır.
5. Örnek ekranlara ekran ekran yorum yok; telefonda denedikçe değişebilir.

Ek istek: hareketler yalnızca ilk girişle sınırlı kalmasın, uygulama kullanılırken de sürsün. Karşılığı: kural 3, 1.10 ve 1.11.

## Uygulayıcıya bırakılanlar

- Kesin dp ve sp değerleri, kesin gri tonları (testten geçecek biçimde).
- Ortak parçaların iç yapısı; hangi listelerin `AnimatedList`'e, hangilerinin örtük hareketlere geçeceği.
- Kilit açılışı geçişinin (4.3) gezinme yapısına nasıl oturacağı.

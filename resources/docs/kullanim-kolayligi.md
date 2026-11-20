# Kullanım kolaylıkları

**Durum:** Faz 18 tasarımı, 2026-11-20. **Görev:** [#157](https://github.com/aaudraa/KeyKey/issues/157). Plan: [kullanim-kolayligi-plani.md](kullanim-kolayligi-plani.md).

## Neden

Yol haritasının "1.0 sonrası" bölümündeki dört küçük iş, proje sahibinin 2026-11-19'da onayladığı listeden geliyor. Dördü de günlük kullanımdaki sürtünmeyi azaltır:

- **Arka plan kilidinde bekleme süresi:** başka bir uygulamaya bakıp dönünce, örneğin bir SMS kodunu okuyunca, kasa yeniden kilitli olmasın.
- **Gizli olmayan alanlarda normal klavye:** kayıt adında büyük harf, sitede `/` ve `.com` tuşları.
- **Toplu seçim:** çok kaydı tek tek çöpe atmak ya da klasöre taşımak zahmetli.
- **Steam Guard kodları:** Steam'in 2FA kodu 5 harfli ve kendi alfabesiyle üretiliyor. KeyKey bugün bu hesapları içe aktarırken atlıyor ve elle de kurulamıyor.

Proje sahibi 2026-11-20 sabahı bütün yol haritasını onay beklemeden bitirmemi istedi. Kararlar bu yüzden benim; gerekçeleri aşağıda.

## Hedefler

1. Ayarlar → Güvenlik'te **Arka planda kilitlenme**: Hemen (varsayılan), 30 saniye, 1 dakika. Süre dolmadan dönülürse kasa açık kalır; dolduysa kasa kilitlidir. Telefon uykudayken ya da saati geri alınmışken de süre aşılmaz.
2. Ayarlar → Güvenlik'te **Gizli olmayan kutularda normal klavye** (varsayılan kapalı). Açıkken adlar, klasör, arama ve hizmet adı normal klavyeyle, web adresi adres klavyesiyle açılır. Gizli kutular (parola, kullanıcı adı, notlar, kart bilgileri, 2FA anahtarı) her zaman bugünkü gibidir.
3. Parolalar, Kartlar ve Notlar listelerinde **toplu seçim**: uzun basınca seçim başlar; seçilenler çöpe taşınır ya da bir klasöre taşınır (klasörden çıkarmak dahil). "Geri al" çıkar.
4. **Steam Guard kodları**: elle eklemede "Steam" türü; Aegis ve 2FAS yedeklerinden ve `otpauth://steam/…` bağlantılarından içe aktarma; kod listede, ayrıntıda, otomatik doldurmada ve yedekte çalışır.

## Hedef olmayanlar

- Bekleme süresinde "hiçbir zaman", 5 dakikadan uzun ya da "telefon kilitlenince" seçenekleri. Dokunmama kilidi (5 dakika) aynen kalır.
- Steam'in kendi uygulamasındaki onaylar (oturum açma onayı, takas onayı) ve Steam Desktop Authenticator'ın `maFile` dosyası. Yalnızca kod üretimi.
- 2FA listesinde toplu seçim. 2FA kayıtlarında klasör yok ve yanlışlıkla silinen 2FA hesabı servise girişi engelleyebilir; tek tek silmek bilinçli bir sürtünme.
- Çöp kutusunda toplu seçim: "Tümünü geri yükle" ve "Çöpü boşalt" zaten var.

## Karşı hedefler

- Bekleme süresi açıkken telefon başkasının eline geçince kasanın süreden uzun açık kalması. Özellikle telefon uyuyunca durup sonra kaldığı yerden sayan bir saat bu açığı yaratır.
- Normal klavyenin gizli kutulara sızması. Parola, kullanıcı adı, not metni, kart bilgisi ve 2FA anahtarı hiçbir ayarda normal klavyeyle açılmaz.
- Toplu çöpe atmanın tek dokunuşla geri dönülmez olması.
- Steam kodunun 6 haneli sayı gibi gösterilmesi ya da yedekte bozulması.

## Yaklaşımlar

**Bekleme süresi nasıl ölçülür?**

1. Yalnızca bir `Timer`. Android uygulamayı dondurunca (Android 11'den beri önbellekteki uygulamalar dondurulur) zamanlayıcı çalışmaz; dönüldüğünde süre çoktan geçmiş olabilir ama kasa açık kalır. Elendi.
2. Yalnızca duvar saati (`DateTime.now`). Kullanıcı saati geri alırsa süre uzar. Telefon açık bir saldırganın elindeyse saati değiştirmek zaten mümkün, ama bu yine de bir delik.
3. **Seçilen:** arka plana geçerken iki saat birden kaydedilir: duvar saati ve `Stopwatch` (tekdüze saat). Dönüldüğünde ikisinden biri süreyi geçtiyse ya da duvar saati geri gittiyse kasa kilitlenir. Ayrıca arka planda bir `Timer` süre dolunca kilitler; uygulama donmuşsa dönüşteki denetim yakalar. Tekdüze saat telefon uyurken durabilir, duvar saati durmaz; duvar saati geri alınabilir, tekdüze saat alınamaz. İkisi birlikte iki açığı da kapatır.
   - **Uygulamada (son gözden geçirme):** `Stopwatch` `CLOCK_MONOTONIC`'tir ve uykuda durur; uyku ile saati geri almak bir araya gelince süre uzuyordu. Tekdüze saat Android'de `CLOCK_BOOTTIME` oldu (FFI ile `clock_gettime`): uykuda da ilerler, ayarlanamaz.

**Normal klavye nerede seçilir?** Her kutu kendi türünü söyler (`SecretField`'e "gizli değil: düz metin" ya da "gizli değil: adres"); ayar açıksa bu tür kullanılır. Varsayılan "gizli" kalır, böylece unutulan bir kutu güvenli tarafta kalır. Ayarın tek tek kutulara verilmesi (kullanıcı adı açık, site kapalı gibi) elendi; ayarlar ekranı karmaşıklaşırdı.

**Toplu seçim nasıl başlar?** Uzun basma (Android'in alışılmış yolu) ve seçim modunda üst çubuğun seçim çubuğuna dönmesi. Her satırda sürekli bir onay kutusu elendi; liste kalabalıklaşırdı.

**Steam kayıtta nasıl durur?** Yeni bir tür: `"kind": "steam"`. Hane, algoritma ve süre sabit (5, SHA1, 30). "TOTP ama `digits: 5` ve bir bayrak" elendi: TOTP 5 haneyi zaten reddediyor ve bayrak her okuyucuya yeni bir kural yükler.

## Tasarım

### Arka plan kilidi

- Ayar şifreli kasa ayarlarında durur (`backgroundLockSeconds`: 0, 30 veya 60). Ayarlar sürüm 6 olur. Okunamayan ayar bugünkü gibi "ek onay açık" sayılır; bekleme süresi okunamazsa "Hemen".
- `hidden` ya da `paused` gelince: süre 0 ise bugünkü gibi hemen kilitlenir. Değilse iki saat kaydedilir ve `Timer(süre)` kurulur.
- `resumed` gelince: süre aşıldıysa (iki saatten biri ≥ süre, ya da duvar saati geriye gitti) önce kilitlenir. Kilitlenmediyse zamanlayıcı iptal edilir. Kasa listeleri yeniden okunur, çünkü bu arada doldurma ekranı yeni bir kayıt eklemiş olabilir.
- `detached` her zaman hemen kilitler.
- KeyKey'in açtığı dosya seçicisinin 3 dakikalık istisnası aynen kalır. Ondan dönüşte bekleme süresi değil seçicinin kendi sınırı geçerlidir.
- Dokunmama kilidi (5 dakika) arka planda da sayar: bekleme süresi onu uzatmaz.
- Ekran, son uygulamalar listesinde bugünkü gibi boş görünür (`FLAG_SECURE`).
- Güvenlik tasarımındaki "Otomatik kilit" bölümü ve tehdit modeli bu kurala göre güncellenir; bedeli açıkça yazılır: süre boyunca telefonu eline alan kişi kasayı açık bulur.

### Normal klavye

- Ayar: `plainKeyboard` (bool), kasa ayarlarında, sürüm 6.
- `SecretField`'e `plain` parametresi gelir: `null` (gizli, bugünkü davranış), `PlainKeyboard.text` ya da `PlainKeyboard.url`.
- Ayar açıkken `text`, `TextInputType.text` ve kelime başı büyük harfle; `url`, `TextInputType.url` ile açılır. İki durumda da otomatik düzeltme, öneri ve kişisel öğrenme isteği kapalı kalır.
  - **Uygulamada (cihaz denemesi):** Flutter Android'de öneriyi kapatan kutuya görünür parola türünü de ekliyor; öyle olunca normal klavye hiç gelmiyordu. Normal klavyeli kutularda öneri açık; düzeltme ve öğrenme isteği kapalı.
- Kutular:
  - **`text`:** parola, kart ve not adı, klasör, kasa ve 2FA araması, 2FA hizmet adı.
  - **`url`:** parolanın web adresi.
  - **Gizli kalanlar (her zaman):** kullanıcı adı, parola, notlar, not metni, kart sahibi, numara, son kullanma, güvenlik kodu, PIN, 2FA hesap adı ve anahtarı, kilit ve kurtarma ekranları, doldurma ekranlarının arama kutusu.
- Doldurma ekranları kendi girişleriyle çalışır ve ayarı okumaz; orada her şey gizli kalır.

### Toplu seçim

- Parolalar, Kartlar ve Notlar listesinde bir satıra uzun basınca seçim başlar ve o satır seçilir. Seçim modunda dokunmak seçer ya da seçimi kaldırır.
- Üst çubuk "N seçildi" olur. Solda kapat (×), sağda **Tümünü seç** (görünen, süzülmüş liste), **Klasöre taşı** ve **Çöp kutusuna taşı**.
- **Çöp kutusuna taşı** onay sormaz; alttan "N kayıt çöp kutusuna taşındı · Geri al" çıkar. Kayıtlar zaten 30 gün çöp kutusunda durur.
- **Klasöre taşı** bir pencere açar: var olan klasörler, "Yeni klasör" ve "Klasörden çıkar". Seçilince bütün seçilenlerin klasörü değişir.
- Geri tuşu, sekme değişimi ve kilit seçimi bırakır. Arama ya da süzgeç değişince görünmeyen seçili kayıtlar seçimden düşer.
- Satırda seçim, solda dolu ya da boş bir daire ve hafif vurguyla gösterilir. TalkBack "seçili" / "seçili değil" der; uzun basma eylemi "Seç" diye okunur.
- Kayıtlar tek tek güncellenir (her biri kendi şifreli satırı). Biri hata verirse diğerleri yazılmış kalır ve "N kayıttan M'si taşınamadı" denir.

### Steam Guard

- **Tür:** `OtpKind.steam`, etiketi `steam`.
- **Sabit değerler:** SHA1, 30 saniye. Kayıtta `"digits": 5`, `"period": 30`, `"algorithm": "SHA1"`, `"counter": null` yazılır, okurken bu değerler zorunludur.
- **Kod:** TOTP'nin 31 bitlik sayısı alınır, `23456789BCDFGHJKMNPQRTVWXY` alfabesiyle 5 kez `sayı % 26` karakteri yazılır ve `sayı ~/= 26` yapılır.
- **Elle ekleme:** tür seçicisinde "Steam". Seçilince hane, algoritma ve süre kutuları gizlenir. Anahtar Base32 olarak girilir.
- **İçe aktarma:**
  - Aegis `"type": "steam"`.
  - 2FAS `"tokenType": "STEAM"`.
  - `otpauth://steam/…` bağlantısı ve `otpauth://totp/…?encoder=steam`.
  - Google Authenticator'ın aktarma biçiminde Steam türü yok, orada değişen bir şey yok.
- **Gösterim:** kod 5 harf olarak, gruplanmadan görünür. Kopyalama, otomatik doldurmada kod kopyalama ve ek onay aynen çalışır.
- **Uyumluluk:** Steam hesabı içeren bir yedeği KeyKey 1.6.0 ve öncesi okuyamaz ve "Yedek bozuk ya da değiştirilmiş" der; kartlarda olduğu gibi kılavuzda ve değişiklik günlüğünde yazılır. Şifresiz dışa aktarma (JSON) `kind: "steam"` yazar.
- Güvenlik tasarımındaki "2FA kaydının içeriği" ve "Kod üretimi" bölümleri güncellenir.

## Testler

- **Bekleme süresi:**
  - Süre 0'da arka planda hemen kilit.
  - 30 sn'de 10 sn sonra dönüş açık, 31 sn sonra kilitli.
  - Tekdüze saat durup duvar saati ilerleyince kilitli; duvar saati geri gidince kilitli.
  - Zamanlayıcı arka planda kilitler.
  - Dosya seçicisi istisnası bozulmaz.
  - Dokunmama kilidi bekleme süresinden bağımsız.
  - Dönüşte liste yenilenir.
  - Ayarlar sürüm 6 okuma/yazma; eski sürümler okunur.
- **Normal klavye:**
  - Ayar kapalıyken bütün kutular `visiblePassword` (ya da kendi özel türleri).
  - Açıkken ad `text` ve büyük harfli, site `url`, gizli kutular değişmiyor.
  - Öğrenme isteği her durumda kapalı.
  - Doldurma ekranlarında değişiklik yok.
- **Toplu seçim:**
  - Uzun basma seçimi başlatır; seçilip bırakılabilir.
  - Tümünü seç süzülmüş listeyi seçer.
  - Çöpe taşıma ve "Geri al".
  - Klasöre taşıma, yeni klasör ve klasörden çıkarma.
  - Sekme değişimi ve geri tuşu seçimi bırakır.
  - Kartlar'da seçim yalnızca kart.
  - TalkBack etiketleri.
- **Steam:**
  - Bilinen bir anahtar ve zaman için Steam'in ürettiği kod (Aegis ve steam-totp'nin test değeriyle).
  - Kayıt okuma ve yazma; hatalı alanlar reddediliyor.
  - Aegis, 2FAS ve `otpauth` içe aktarma.
  - Elle ekleme formu.
  - Listede 5 harf.
  - Yedekle gidip geliyor.
- **Cihazda (Android 17 ve 11):**
  - 30 sn ayarıyla başka uygulamaya geçip dönüş.
  - 1 dakikadan sonra kilit.
  - Normal klavyede ad kutusunda büyük harf.
  - Toplu çöpe taşıma.
  - Steam hesabı ekleyip kod görme.

## Belgeler

- Güvenlik tasarımı: Otomatik kilit, Arayüz koruması (klavye), 2FA kaydı ve kod üretimi.
- Kılavuz: Ayarlar → Güvenlik, toplu seçim, Steam.
- Değişiklik günlüğü 1.7.0, mağaza sürüm notu 11, yol haritası.

## Uygulayana kalanlar

- Seçim çubuğunun simgeleri, "Klasöre taşı" penceresinin görünümü.
- Steam türünün tür seçicisindeki yeri.
- Ayarlar ekranında iki yeni satırın sırası ve açıklama metinleri.

# Değişiklik günlüğü

KeyKey'deki önemli değişiklikler. Sürüm numarası kuralı [yayın belgesinde](docs/yayin.md#sürüm-numarası). `v1.0.0`'dan önceki sürümler fazların sonunu işaretler ve hata ayıklama anahtarıyla imzalıdır; kalıcı bir kurulum için kullanılmamalıdır.

## 1.11.0 (2026-11-24): Passkey sağlayıcısı

Android 14 ve üstünde KeyKey passkey sağlayıcısı olabiliyor ([#186](https://github.com/aaudraa/KeyKey/issues/186)). Tasarım: [passkey sağlayıcısı](docs/passkey.md). Veritabanı şeması değişmedi.

### Yeni

- **Passkey oluşturma ve giriş.** Ayarlar → Otomatik doldurma → **Passkey sağlayıcısı** ile Android'in ayarında KeyKey seçilince sitelerde ve uygulamalarda passkey KeyKey'de oluşturuluyor; girişte "KeyKey'in kilidini aç" ile kasa açılıyor, o sitenin hesapları aynı pencerede listeleniyor. Passkey aynı sitenin, aynı kullanıcı adlı kaydına ekleniyor; yoksa yeni kayıt açılıyor.
- **Kayıtta passkey'ler.** Kayıt ayrıntısında her passkey'in sitesi, hesabı ve oluşturulma tarihi görünüyor ve onayla silinebiliyor; listede passkey'li kayıtta küçük bir anahtar simgesi var.
- **Passkey'leri içe aktarma.** Bitwarden JSON'daki ve KeePassXC `.kdbx` dosyasındaki passkey'ler kayıtlarıyla birlikte geliyor; önizleme kaç passkey alınacağını ve alınamayanları söylüyor.
- Passkey'ler kasanın içinde şifreli; yedekle, otomatik yedekle ve senkronla taşınıyor, yeni telefona geçiyor.
- **Simgesi olmayan uygulamalar** ([#71](https://github.com/aaudraa/KeyKey/issues/71)): ana ekranda simgesi olmayan bir uygulamada da (başka bir uygulamanın içinden açılan giriş ekranları) kayıt ilk kaydetmede uygulamaya bağlanıyor.

### Güvenlik

- Anahtar üretimi ve imza Android'in kendi kripto sağlayıcısında (P-256, ES256); özel anahtar kasanın dışında hiçbir yerde şifresiz durmuyor ve düz metin dışa aktarmaya yazılmıyor.
- Kasa kilitliyken KeyKey hangi sitelerde passkey olduğunu söylemiyor. Hiçbir site, kullanıcı bir hesap seçmeden imza almıyor; girişte hazırlanan yanıtlar en çok 2 dakika bellekte duruyor.
- Başka bir sitenin adına gelen istek reddediliyor: `rpId` public suffix olamaz, tarayıcıda origin yalnızca güvenilen tarayıcılardan alınıyor ve `rpId`'ye uymalı. Passkey'i bir uygulama istiyorsa ve uygulamanın o siteye ait olduğu doğrulanamıyorsa KeyKey uyarıyor; uygulamanın imza için verdiği hazır özet kullanılmıyor, imza her zaman uygulamanın kendi kimliğine atılıyor.
- Küçük bulgular kapatıldı: site doğrulaması ([#182](https://github.com/aaudraa/KeyKey/issues/182)), KeePass içe aktarma ([#180](https://github.com/aaudraa/KeyKey/issues/180)) ve arayüz incelemesi ([#174](https://github.com/aaudraa/KeyKey/issues/174)); liste okunamazsa "Yeniden dene", ayrıntı ekranında yazma hatası söyleniyor.

### Uyumluluk

- **Bütün telefonlarını güncelle.** Parola kaydı sürüm 3, yedeğin ve senkron dosyasının içerik sürümü 6. 1.10.x ve öncesi 1.11.0 yedeklerini "daha yeni yedek" diye açmaz; senkronda "başka bir telefonda daha yeni KeyKey var" der. 1.11.0, eski sürümlerin yedeklerini ve senkron dosyalarını okumaya devam eder. Güncelleme sürerken 1.10 telefonda düzenlenen bir kayıt senkronda passkey'lerini yitirmez.
- Passkey sağlayıcısı yalnızca Android 14 ve üstünde; eski sürümlerde içe aktarılan passkey'ler kasada durur.
- Yeni izin: bütün uygulamaları görme (`QUERY_ALL_PACKAGES`, #71). KeyKey yalnızca o an kaydedilen ya da doldurulan uygulamanın adını, imza özetini ve simgesini okur ([gizlilik](docs/gizlilik.md#izinler)). Passkey için kullanıcıdan istenen yeni bir izin yok.
- Yeni bağımlılık: `androidx.credentials` 1.6.0 (Apache 2.0); Google Play hizmetleri gerekmez.

## 1.10.0 (2026-11-22): Uygulama ve site eşleştirme

Bir sitenin kaydı, o sitenin resmî uygulamasında da kendiliğinden eşleşiyor ([#178](https://github.com/aaudraa/KeyKey/issues/178)). Tasarım: [uygulama ve site eşleştirme](docs/uygulama-site-eslestirme.md). Yeni izin yok; veritabanı şeması değişmedi.

### Yeni

- **Uygulamanın doğrulanmış sitesi.** Uygulamaya bağlı olmayan kayıt, adresi uygulamanın doğrulanmış sitesiyle aynı siteyse eşleşir; tek eşleşme liste açılmadan doldurulur ve uygulama kayda kendiliğinden bağlanır. Android 12 ve üstünde sistemin zaten doğruladığı siteler kullanılır, ağa çıkılmaz.
- **Uygulamanın sitesini internetten doğrula** (Ayarlar → Otomatik doldurma, varsayılan kapalı). Sistemin doğrulamadığı durumlarda KeyKey sitenin `/.well-known/assetlinks.json` dosyasını okur; yalnızca uygulamanın kendi sitesi olduğunu söylediği ve kasada kaydı bulunan siteye, en fazla dördüne sorulur. Siteye kasadan bir şey gitmez.

### Güvenlik

- Eşleşmeyi her zaman uygulamanın imzası belirler: site dosyası uygulamanın paket adını ve imza özetini listelemelidir. Paket adı yalnızca hangi siteye sorulacağını bulur. Kayda bağlı uygulamanın imzası tutmuyorsa doğrulanmış site bunu değiştirmez, "sahte olabilir" uyarısı kalır.
- Yeni ağ kodu ayrı bir dosyada (`asset_links_client.dart`); yönlendirme izlenmez, IP adresi ve port reddedilir, gövde 128 KiB, toplam bekleme 5 saniye.

### Uyumluluk

- Ayar kaydı sürüm 8, yedeğin içerik sürümü 5. 1.9.x ve öncesi 1.10.0 yedeklerini "daha yeni yedek" diye açmaz ve güncellemeyi söyler. Senkron dosyası sürüm 4'te kalır; 1.8.0-1.9.x telefonlarla eşitleme sürer.
- Kullanım koşulları sürüm 4: internete çıkan yeni bir özellik eklendiği için güncellemeden sonra bir kez yeniden sorulur.

## 1.9.0 (2026-11-22): KeePass içe aktarma

KeePass dosyaları (`.kdbx`) doğrudan açılıp kasaya alınabiliyor ([#177](https://github.com/aaudraa/KeyKey/issues/177)). Tasarım: [KeePass içe aktarma](docs/keepass-ice-aktarma.md). Yedek biçimi ve veritabanı şeması değişmedi; yeni izin yok.

### Yeni

- **KeePass dosyası açma.** Ayarlar → Yedek ve aktarım → **İçe aktar** ile seçilen `.kdbx` dosyası ana parola ve/veya anahtar dosyasıyla açılır, kayıtlar bugünkü önizlemede gösterilir. KeePass 2, KeePassXC, KeePassDX ve Keepass2Android'in yazdığı KDBX 2, 3 ve 4 dosyaları; AES-256, ChaCha20 ve Twofish şifreleri; AES-KDF, Argon2d ve Argon2id. Düz metin dışa aktarma gerekmez.
- Gruplar klasör, TOTP alanları (KeePassXC'in `otp` alanı, KeePass 2'nin `TimeOtp` alanları, eski `TOTP Seed`) bağlı 2FA hesabı, ek alanlar özel alan, `KP2A_URL` alanları ek adres oluyor; alan başvuruları (`{REF:…}`) çözülüyor; yalnızca notu olan kayıtlar güvenli not oluyor. Çöp kutusu ve ekler alınmıyor, sayıları söyleniyor.
- Anahtar türetme telefonun yerel koduyla: Argon2 kendi yazarlarının başvuru uygulamasıyla (C, çok iş parçacıklı), AES-KDF işlemcinin AES komutlarıyla. Emülatörde Argon2d 64 MiB ve 10 geçiş 0,35 saniye, on milyon turluk AES-KDF 0,33 saniye sürdü.

### Güvenlik

- Hiçbir kayıt dosyanın tamamı doğrulanmadan gösterilmiyor: KDBX 4'te başlık ve blok HMAC'leri, KDBX 2 ve 3'te blok özetleri. Yanlış parola, desteklenmeyen biçim, bozuk dosya ve telefon için fazla ağır ayarlar ayrı mesajlarla söyleniyor. Dosya boyutu, açılmış veri ve anahtar türetme parametreleri sınırlı; kötü niyetli bir dosya belleği tüketemiyor.
- Parola, anahtar dosyası ve çözülmüş veri hiçbir yere yazılmıyor; anahtar malzemesi ve dosyanın baytları işi bitince sıfırlanıyor.

## 1.8.2 (2026-11-22): Arayüz incelemesi

1.8.1'deki incelemeye girmeyen arayüz kodu (kasa, 2FA, uygulama kabuğu, ayarlar ve ilk kurulum) incelendi; bulgular ve kararlar [#173](https://github.com/aaudraa/KeyKey/issues/173)'te. Her düzeltme önce bulguyu gösteren bir testle doğrulandı. Yedek biçimi ve veritabanı şeması değişmedi.

### Güvenlik

- **Donanım klavyesiyle kopyalama da hassas panodan geçiyor.** Bluetooth klavye, DeX ya da Chromebook'ta Ctrl+C / Ctrl+X ile kopyalanan parola ve not 30 saniye sonra silinmiyor, klavyenin pano geçmişine düşüyordu.
- **İçe aktarılan 2FA hesaplarının adlarında yön ve denetim karakterleri atılıyor.** Google, Aegis ya da 2FAS'tan gelen bir ad, metni ters çeviren işaretle başka bir servis gibi görünebiliyordu.
- Kasa kilitlenince parola değiştirme ve kurtarma anahtarı ekranlarında yazılan parolalar hemen siliniyor.

### Düzeltilenler

- **Android 14+ kenardan geri hareketi yalnızca en üstteki sayfayı kapatıyor.** Öteki sekmedeki ya da formun altındaki sayfa da kapanıyor, değişmiş formda "değişiklikler silinsin mi" sorusu atlanıyordu.
- **Senkron ya da öne gelme sırasında yapılan değişiklik kaybolmuyor.** Kart ve not formu açıkken gelen değişikliği (yeni PIN, çöpe atma) ezmiyor; liste yeniden okunurken kaydedilen değişiklik ekrandan silinip sonra eski haliyle geri yazılmıyor.
- **Kasa dosyası okunamazsa uygulama açılış ekranında donmuyor**, hata ekranı geliyor.
- Parola değişirken ekrandan çıkılmıyor; sonuç ve eski yedeklerle ilgili not her zaman gösteriliyor.
- Gösterilen yeni kurtarma anahtarından doğrulamadan çıkmadan önce soruluyor; eski anahtarın geçerli kaldığı söyleniyor.
- Bozuk bir Google Authenticator QR'ı tarayıcıyı dondurmuyor; scrypt parametre sınırı çok büyük değerlerde taşmıyor.
- Düzenlenen HOTP hesabında eski kod gösterilmiyor; aynı içe aktarmada aynı anahtar bir kez ekleniyor.
- Kart, not ve toplu taşımada "iş" yazılınca "İş"in yanına ikinci klasör açılmıyor; klasör adının harf büyüklüğü yeniden okumadan sonra da düzeltilebiliyor.
- Çöpü boşaltırken ya da kayıt sürerken ekrandan çıkılınca işlem yarıda kalmıyor.
- "+" kutusu yatay ekranda ve büyük yazıda ekrana sığıyor; "⋮" menüsü sekme değişince açık kalmıyor.

## 1.8.1 (2026-11-22): Düzeltmeler

Projenin bütünü ultra review ile incelendi; bulgular ve kararlar [#168](https://github.com/aaudraa/KeyKey/issues/168)'de. Her düzeltme önce bulguyu gösteren bir testle doğrulandı. Yedek biçimi ve veritabanı şeması değişmedi; 1.8.0 ile aynı yedekler.

### Güvenlik

- **Otomatik doldurma, sayfaya gömülü başka bir sitenin çerçevesine (iframe) parola yazmıyor.** Parola alanının çerçevesi seçiliyor, eşleştirme o çerçevenin alan adıyla yapılıyor, başka çerçevelerdeki giriş alanları doldurulmuyor.
- **Kayıttaki adreste şema yalnızca başta tanınıyor ve yalnızca http/https alan adı veriyor.** `androidapp://com.amazon.mShop.android.shopping` gibi bir paket adı `android.shopping` sitesiyle eşleşebiliyordu.
- **Dosya seçici açıkken telefon uyursa dönüşte kasa kilitli.** Seçicinin 3 dakikalık sınırı artık iki saatle denetleniyor.
- Dosya okurken (CSV, yedek, dışa aktarma doğrulaması) düz metin kopyaları bellekte sıfırlanıyor. Sızıntı kontrolü istemcisi senkronla aynı güvenli adres kuralını kullanıyor.

### Düzeltilenler

- **Yazma sırasında uygulama ölürse (düşük bellek, pil) sonraki açılışlar başarısız olmuyor.** Kalan günlük açılışta geri alınıyor; bu hata 0.3.0'dan beri vardı.
- Çöpteki girişler otomatik doldurmada eşleşmiyor.
- Ana uygulama ve doldurma ekranı birbirinin pano kopyasını erken silmiyor; kullanıcının kendi kopyaladığı da silinmiyor.
- İçe aktarmada aynı 2FA anahtarını taşıyan iki girişten biri seçilmezse anahtar kaybolmuyor.
- Otomatik yedek silmelerden ve senkronla gelen değişikliklerden sonra da yazılıyor; yedek hatırlatıcısı kart ve not değişikliklerini de görüyor.
- Başka bir kasaya katılınca eski kasanın yedek zamanı taşınmıyor; otomatik yedek katılınan kasayı yazıyor.
- Ayar kaydı yazılamazsa senkron oturum boyunca durmuyor, otomatik yedek de dosya biriktirmiyor.
- Klasörde adı UTF-8 olmayan başka bir dosya varsa senkron ve kurulum bozulmuyor.
- Değiştirerek geri yükleme başarısız olursa parmak izi kapanmıyor.
- Çok imzacılı uygulamalarda otomatik doldurma her seferinde "sahte olabilir" demiyor.

### Değişenler

- **Alttaki menüde yalnızca simgeler** ([#163](https://github.com/aaudraa/KeyKey/issues/163)). Ekran okuyucu sekme adlarını okumaya devam ediyor.
- Kilit ekranındaki kurtarmada anahtar **Dosyadan oku** ile okunabiliyor.
- Ekranların veritabanına ve kriptoya doğrudan erişmeme kuralı bir testle denetleniyor.

## 1.8.0 (2026-11-20): Senkron

Faz 19 ([tasarım](docs/senkron.md)).

### Önemli

- **1.8.0'ın yedeklerini 1.7.0 ve öncesi açamaz.** Yedeğin içerik sürümü 4 oldu (senkron ayarları). Eski sürüm "daha yeni bir yedek" der; yedek bozuk değildir, KeyKey'i güncellemek yeter.
- **Kullanım koşulları sürüm 3.** Senkronu açarsan kasanın şifreli bir kopyası senin seçtiğin sunucuya gider; koşullar ve [gizlilik bildirimi](docs/gizlilik.md#senkron) bunu anlatıyor. Güncellemeden sonraki ilk açılışta koşullar bir kez yeniden sorulur.
- Veritabanı şeması 2: kalıcı silinen kayıtların kimliği ve silinme anı (silme kaydı), ana parolanın ve kurtarma anahtarının son değiştiği an. Silme kayıtları senkron kapalıyken de yazılır.

### Eklenenler

- **Senkron (WebDAV):** Ayarlar → Telefonlar arası → **Senkron**. Kasa, kendi WebDAV klasörün (Nextcloud, ownCloud ya da başka bir sunucu) üzerinden aynı kasayı kullanan telefonların arasında eşitlenir: eklenen, değiştirilen, çöpe atılan ve kalıcı silinen kayıtlar öteki telefonlara geçer. Her telefon klasöre kendi dosyasını yazar; dosya yedekle aynı biçimde ana parolayla şifrelidir, sunucu içeriği göremez. Kasa açılınca, bir kayıt değişince, uygulamaya dönünce ve **Şimdi eşitle** ile eşitlenir. Aynı kayıtta en son değişen kalır; kaybeden parola geçmişe eklenir. Ana parola ya da kurtarma anahtarı bir telefonda değişince öteki telefonlar da yenisine geçer ve bunu bir kez söyler. Cihaz listesi, telefon kaldırma ve senkronu kapatırken bu telefonun dosyasını silme.
- **Senkrondan kur:** Yeni telefonda ilk ekrandan; kasa klasördeki en yeni dosyadan kurulur, senkron açık gelir.
- **Bu telefonu o kasaya kat:** Klasörde başka bir kasa varsa, o kasanın ana parolasıyla bu telefonun kayıtları o kasaya eklenir.
- **Senkron açıkken geri yükleme** hiçbir kaydı silmez: birleştirilen ve değiştirilen kayıtlar bütün telefonlarda yedekteki haline döner.

### Değişenler

- Birleştirerek geri yüklemede geri gelen kaydın silme kaydı kaldırılır.
- Gizlilik bildirimi, güvenlik tasarımı (tehdit modeli, bilinen sınırlar 10-13), güvenlik özeti ve kılavuz senkronu anlatıyor. Ağ kodu artık iki dosyada.

## 1.7.0 (2026-11-20): Kullanım kolaylıkları

Faz 18 ([tasarım](docs/kullanim-kolayligi.md)).

### Önemli

- **1.7.0'ın yedeklerini 1.6.0 ve öncesi açamaz.** Yedeğin içerik sürümü 3 oldu: yeni ayarlar ve Steam hesapları eski sürümde okunamazdı. Eski sürüm artık "bozuk" değil "daha yeni bir yedek" der (1.3.0 ve öncesi yine "bozuk ya da değiştirilmiş" der). Yedek bozuk değildir; KeyKey'i güncellemek yeter.

### Eklenenler

- **Arka planda kilitlenme süresi:** Ayarlar → Güvenlik'te Hemen (varsayılan), 30 saniye ya da 1 dakika. Süre dolmadan dönülürse kasa açık kalır. Süre iki saatle ölçülür: telefon uyusa ya da saati geri alınsa bile uzamaz. 5 dakika dokunmama kilidi ayrıca sürer. Dönüşte parola listesi yeniden okunur (otomatik doldurma bu arada bir parola eklemiş olabilir).
- **Gizli olmayan kutularda normal klavye** (varsayılan kapalı): kayıt adı, klasör, arama ve 2FA servis adı normal klavye ve kelime başı büyük harfle, web adresi adres klavyesiyle açılır; bu kutularda klavye öneri gösterir, öğrenme isteği kapalı kalır. Parola, kullanıcı adı, notlar ve kart bilgileri her zaman öğrenmeyen klavyeyle açılır.
- **Toplu seçim:** Parolalar, Kartlar ve Notlar listelerinde uzun basınca seçim başlar; tümünü seç, klasöre taşı (yeni klasör ya da klasörden çıkar dahil) ve çöp kutusuna taşı (Geri al ile). Seçim yalnızca görünen kayıtlarla çalışır; arama daralınca gizlenen seçimler düşer.
- **Steam Guard kodları:** 5 karakterlik Steam kodları. Aegis (`steam`), 2FAS (`STEAM`), `otpauth://steam/…`, `encoder=steam` bağlantıları ve Bitwarden'ın `steam://` anahtarı içe aktarılır; elle eklemede **Gelişmiş** altında **Steam Guard** türü. Bitwarden biçimli dışa aktarma Steam hesabını `steam://` ile yazar.

### Değişenler

- 2FA formunda tür seçimi düğme yerine çiplerle (üç tür dar ekrana sığsın diye).
- Desteklenmeyen 2FA hesabı metni örnek olarak Steam yerine Yandex diyor.

## 1.6.0 (2026-11-20): Sızıntı kontrolü, kartlar ve notlar menüde

Faz 16 ([tasarım](docs/internet-ve-sizinti.md)) ve Faz 17 ([tasarım](docs/gezinme.md)).

### Önemli

- **KeyKey artık `INTERNET` iznine sahip.** İnternete yalnızca senin başlattığın sızıntı kontrolü için çıkar; kasa, yedek, otomatik doldurma ve pano yine hiçbir yere gitmez. Hesap ve sunucu yok. Ağ kodu tek bir dosyada durur ve başka yerde ağ kodu olmadığını her derlemede bir test denetler.
- **Kullanım koşulları değişti (sürüm 2).** Güncellemeden sonraki ilk açılışta yeni metin bir kez sorulur. Değişen tek madde "Verilerin bu telefonda": "internet izni yoktur" yerine KeyKey'in internete yalnızca senin başlattığın denetimler için çıktığı yazıyor. [Gizlilik bildirimi](docs/gizlilik.md#sızıntı-kontrolü) de güncellendi.

### Eklenenler

- Parola raporunda **Sızıntı kontrolü**: **İnternetten denetle**, parolalarının bilinen veri sızıntılarında görülüp görülmediğini [Have I Been Pwned](https://haveibeenpwned.com/Passwords)'a k-anonimlikle sorar. Parolanın kendisi gitmez, yalnızca SHA-1 özetinin ilk 5 karakteri gider; karşılaştırma telefonda yapılır. Sızıntılarda görülen parolalar kaç kez görüldükleriyle listelenir; kayda dokununca parolası değiştirilir ve kayıt listeden düşer. Sonuç kaydedilmez; ekrandan çıkınca ya da kasa kilitlenince silinir. Denetimden sonra eklenen ya da değişen parolalar için "denetlenmedi" yazar.
- Bağlantı yoksa ya da bir otelin giriş sayfası gibi beklenmeyen bir yanıt gelirse "Denetlenemedi" yazar ve **Yeniden dene** çıkar; yarım sonuç ya da yanlış bir "sızıntı yok" gösterilmez.

### Değişenler

- **Kartlar ve notlar alttaki menüde.** Menüde beş sekme var: Parolalar, Kartlar, Notlar, 2FA, Ayarlar. Kasa listesinin üstündeki Parolalar / Kartlar / Notlar düğmeleri kalktı. Her sekme yalnızca kendi kayıtlarını, klasörlerini ve çöp kutusunu gösterir; "+" ile eklenen kart ve not kendi sekmesinde açılır, kilitten sonra kart ya da notun ayrıntısına dönülür. Telefonda seçili sekme kapsülde yalnızca simgeyle görünür; dar ekranda menünün boşlukları daralır, sekmeler yine 48 dp. Tanıtımın "Nerede ne var" sayfası beş sekmeyi anlatır.
- Tanıtım, yedek, 2FA saat yardımı ve otomatik yedek metinleri, README, mağaza açıklamaları ve kılavuz "internete çıkmaz" demiyor; yerine "hesap yok, sunucu yok" ve isteğe bağlı sızıntı kontrolü.
- Uygulamada şifresiz (`http`) trafik kapalı ve yalnızca sistem sertifikalarına güveniliyor; yayın APK'sı denetimi izin listesini ve bu ayarları denetliyor. F-Droid tarifinde `NonFreeNet` anti-özelliği.

### Güvenlik

- Uygulama sırasında bulundu: Flutter, Android'in şifresiz trafik yasağını Dart'ın `HttpClient`'ına uygulamıyor. Sızıntı kontrolünün istemcisi https dışı adresi kendisi reddediyor, yönlendirme izlemiyor; ayrıntılar [güvenlik tasarımında](docs/guvenlik-tasarimi.md#sızıntı-kontrolü).

## 1.5.0 (2026-11-19): Kart doldurma

Faz 15 ([tasarım](docs/kart-doldurma.md)).

### Eklenenler

- Otomatik doldurma ödeme formlarındaki kart alanlarını tanıyor: numara, kart sahibi, son kullanma (tek kutu ya da ayrı ay ve yıl, açılır liste dahil) ve güvenlik kodu. Kart kutusunda **KeyKey ile kart doldur** önerisi çıkıyor; kasa açılınca kart listeden seçiliyor ve form doluyor. PIN hiçbir yere doldurulmuyor, panoya hiçbir şey kopyalanmıyor.
- Tanıma Android ipuçlarına, HTML `autocomplete` niteliğine, Chrome'un kendi alan tahminine ve Türkçe/İngilizce kutu adlarına bakıyor. Son kullanma kutunun istediği biçimde yazılıyor (AA/YY, AA/YYYY, ayraçsız); açılır listede ay sayıyla ya da Türkçe/İngilizce adıyla eşleşiyor. Dört kutuya bölünmüş kart numarası da dolduruluyor.
- Şifresiz (`http`) sayfaya kart doldurulmadan önce uyarı ve onay geliyor.

### Düzeltilenler

- Ödeme formlarındaki güvenlik kodu kutusu parola sanılıyordu: kutuda "KeyKey ile doldur" önerisi çıkıyor, form gönderilince güvenlik kodunu parola diye kaydetmek öneriliyordu. Artık ödeme formundaki güvenlik kodu ve kart şifresi kutuları, tek başına duran "Güvenlik kodu" kutusu da parola sayılmıyor. Kart numarasıyla girilen banka formları giriş formu olarak kalıyor.

## 1.4.0 (2026-11-19): Kartlar ve güvenli notlar

Faz 14 ([tasarım](docs/kart-ve-not.md)).

> [!WARNING]
> Kartı ya da notu olan bir kasanın yedeği yeni bir içerik sürümüyle yazılır. 1.3.0 ve öncesi bu yedeği "bozuk ya da değiştirilmiş" diye reddeder; geri yüklemek için önce KeyKey'i güncelle. Kartsız ve notsuz yedekler eskisi gibi yazılır, eski sürümler de açar.

### Eklenenler

- Kart kaydı: ad, kart sahibi, numara, son kullanma, güvenlik kodu, PIN, klasör ve not. Numara yazılırken ya da yapıştırılırken gruplanır; marka (Visa, Mastercard, American Express, Troy, Discover, JCB, UnionPay, Maestro, Diners Club) numaradan anlaşılır; Luhn denetimi tutmazsa uyarı çıkar ama kayıt engellenmez. Listede yalnızca son dört hane ve son kullanma görünür; süresi geçen kartta "Süresi doldu" yazar.
- Güvenli not: ad, en çok 64 KB metin, klasör. Listede metin görünmez. Ayrıntı ekranında metin seçilebilir; seçim menüsünde yalnızca "Kopyala" ve "Tümünü seç" var ve kopyalanan metin 30 saniye sonra panodan silinir.
- Kasa sekmesi parola, kart ve notları birlikte gösterir; birden fazla tür varsa tür düğmeleri çıkar. Çöp kutusu üç türü birlikte gösterir.
- Kart ve notlar yedeğe, otomatik yedeğe ve geri yüklemeye giriyor; geri yükleme özeti onları da sayıyor. Daha yeni bir sürümle alınmış yedek "uygulamayı güncelle" diye söyleniyor.
- Bitwarden'dan içe aktarma kartları ve güvenli notları da alıyor (JSON'da kart ve not, CSV'de not satırları). Karta uymayan değer atılmıyor, etiketiyle kartın notuna yazılıyor; `PIN` adlı özel alan kartın PIN'i oluyor.
- Şifresiz dışa aktarmada biçim seçimi: CSV (artık notlar dahil) ya da yeni JSON (Bitwarden'ın biçimi, kartlar dahil her şey).

### Değişenler

- "Parolaları içe aktar" artık "İçe aktar".
- Yedek, 64 MB sınırını aşacaksa yazılmıyor ve sebebi söyleniyor.
- Metin kutularında uzun basınca açılan menüde **Kopyala** ve **Kes** de hassas panodan geçiyor ve 30 saniye sonra siliniyor (açılmış parola, not metni, kart numarası dahil). Metni başka uygulamalara gönderen düğmeler (paylaş, ara, çevir) bu menüden kalktı.
- "Kasanın yerine yedeği koy" onayı kartların ve notların da silineceğini söylüyor.

## 1.3.0 (2026-11-18): Yeni kurtarma anahtarı

Faz 13 ([tasarım](docs/kurtarma-anahtari-yenileme.md)).

### Eklenenler

- Ayarlar → Güvenlik → Yeni kurtarma anahtarı: ana parola doğrulanınca yeni bir anahtar gösterilir; geri yazılarak doğrulanınca kaydedilir ve eski anahtar bu kasayı artık açmaz. Eski yedekler eski anahtarla açılmaya devam eder; ekran bunu söyler ve yeni yedek önerir, otomatik yedek açıksa hemen yazılır.
- Anahtar doğrulanmadan kasa kilitlenirse (başka uygulamaya geçiş, uzun süre boşta kalma) yenileme iptal olur ve kilit açılınca "kaydedilmedi, eski anahtar geçerli" uyarısı çıkar.

### Değişenler

- Kurtarma anahtarını gösterme ve doğrulama adımları kurulumla ortak.
- Ana parola değiştiği anda kasa kilitlenirse otomatik yedek, kasa yeniden açılınca yazılır.

## 1.2.0 (2026-11-18): Otomatik yedek

Faz 12 ([tasarım](docs/otomatik-yedek.md)).

### Eklenenler

- Otomatik yedek: Ayarlar → Yedek ve aktarım'dan bir klasör seçilince, kasa açıkken kayıtlar değiştikçe o klasöre şifreli bir yedek yazılıyor. Elle yedekle aynı biçim ve anahtar; en yeni 5 yedek ve son 14 günün her birinin son yedeği tutuluyor, elle alınan yedeklere dokunulmuyor. Yedek önce ara adla yazılıp doğrulanıyor; yarım kalan dosya yedek sayılmıyor. İnternet ve depolama izni eklenmedi; KeyKey yalnızca seçilen klasör için izin alıyor.
- Klasöre erişilemezse ayarlarda ve yedek kartında uyarı; "Klasörü değiştir" ve "Şimdi yedekle".
- Ana parola değişince (kurtarma anahtarıyla da) ve kasaya birleştirerek geri yükleyince otomatik yedek hemen yazılıyor.
- Aynı klasörü kullanan iki telefon birbirinin otomatik yedeklerini silmiyor: dosya adında cihaza ait kısa bir kimlik var.

### Değişenler

- Ayar kaydı sürüm 5 (otomatik yedeğin klasörü); sürüm 1-4 kayıtları okunmaya devam ediyor.
- Ayarlardaki değişiklikler sırayla yazılıyor; arka planda yazılan son yedek zamanı aynı anda yapılan bir ayar değişikliğini ezmiyor.
- `pigeon` 30.0.4.

## 1.1.0 (2026-11-17): Kullanıcı gözüyle iyileştirmeler

Faz 11 ([tasarım](docs/kullanici-gozuyle.md)).

### Eklenenler

- Kilidi açınca kaldığın yere dönülüyor: kilitlenmeden önceki sekme ya da açık olan kasa kaydı. Formlar ve tek seferlik ekranlar geri açılmıyor; yer yalnızca bellekte tutuluyor.
- Kasadaki sıralama seçimi ve parola üreticinin son seçenekleri (uzunluk ve türler; parola değil) kasanın içindeki ayarlarda saklanıyor. Ayar kaydı sürüm 4; sürüm 3 kayıtları okunmaya devam ediyor.
- Tek bir 2FA hesabı eklenirken aynı gizli anahtarlı hesap varsa uyarı.
- Klasör kutusu var olan klasörleri öneriyor; harf büyüklüğü farklı yazılan ad var olan klasöre bağlanıyor.
- Çöp kutularında "Tümünü geri yükle" ve onaylı "Çöpü boşalt".
- Boş kasada "Parolaları içe aktar" ve "Yedekten geri yükle", boş 2FA listesinde "Başka uygulamadan aktar" kısayolları.
- Ana parola değişince eski yedeklerin eski parolayla açılmaya devam ettiğini söyleyen not ve oradan yeni yedek.
- Android 13 ve üstünde uygulamanın dili sistem ayarlarından ayrıca seçilebiliyor.
- Kayıttaki web adresi "Siteyi aç" ile tarayıcıda açılıyor; Hakkında'da kaynak kod, sorun bildirme ve gizlilik bildirimi bağlantıları. Yalnızca http ve https adresleri tarayıcıya devrediliyor; KeyKey'e internet izni eklenmedi.
- Kullanım koşulları: kasa kurulmadan ya da açılmadan önce bir kez gösteriliyor ve onay istiyor ([metin](docs/kosullar.md)); Ayarlar → Hakkında'dan okunabiliyor. Kabul edilen koşul sürümü kasanın dışında, şifresiz `terms` dosyasında.
- Lisanslar ekranı yeniden: önce KeyKey'in kendi lisansı, telif satırı ve "garanti yoktur" bildirimi; sonra KeyKey'in kullandığı parçalar ne işe yaradıkları ve lisans türleriyle; en sonda baş harflere göre bütün paketler. Lisanslar yeniden denetlendi ([sonuç](docs/bagimliliklar.md#lisans-denetimi-2026-11-17)).

### Değişenler

- Cam yalnızca alt menüde ve "+" kutusunda: alttan açılan pencereler, ⋮ menüleri ve üst bildirim arkasını bulanıklaştırmıyor, dolu bir yüzeyle açılıyor (koyu temada kartlardan bir ton açık). Daha okunur ve daha akıcı.
- Kayıt ayrıntısında alanlar iki kartta: giriş bilgileri (kullanıcı adı, parola, 2FA kodu, adresler, uygulamalar) ve ek bilgiler (klasör, özel alanlar, notlar); satırlar arasında ince çizgi.
- Kılavuzun ve F-Droid'in ekran görüntüleri güncel tasarımla yenilendi.

### Düzeltilenler

- Ana parola değiştirirken yanlış parola beklemesi saniye olarak değil, kilit ekranındaki gibi dakika:saniye geri sayımıyla gösteriliyor; bekleme bitene kadar düğme kapalı.
- Yedek ve dışa aktarma dosyalarının adı arayüz dilinde (`keykey-backup-…` / `keykey-yedek-…`).
- "Kasa okunamadı" ekranı bozuk dosyada yedekten dönüş yolunu da anlatıyor.
- Ayrıntı ekranındaki kopyala düğmeleri ekran okuyucuya hangi alanı kopyaladığını söylüyor.
- Kayıttan bir alan silinince, açılmış gizli değer sonraki gizli alana geçip dokunmadan açık görünmüyor.
- Alt menünün tepesindeki ince beyaz çizgi iki temada da kaldırıldı.
- Metinler: kaydedilmeyen formdan çıkış "Değişiklikleri at", çöpten çıkarma "Geri yükle", "Kasanın yerine yedeği koy", "Bu anahtar bu kasaya ait değil."; kılavuzda sık kullanılana ekleme düğmesinin yeri.
- Yayın iş akışındaki imza denetimi `apksigner` 37'nin çıktı biçimini okuyamıyordu ve `v1.1.0`'ın ilk denemesini durdurdu; denetim artık ayrı bir betikte ([`imza-ozeti.sh`](scripts/imza-ozeti.sh)), iki biçimi de okuyor ve PR'daki provada tek kullanımlık anahtarla da çalışıyor ([ayrıntı](docs/yayin.md#imza-denetimi)).

## 1.0.1 (2026-11-17): F-Droid hazırlığı

Etiketlendi ama yayımlanmadı: imzalı yayın işi, yukarıdaki imza denetimi hatasıyla dururdu. Aşağıdaki değişiklikler 1.1.0'la geldi; F-Droid'e giren ilk sürüm 1.1.0.

### Eklenenler

- F-Droid için uygulama açıklamaları, simge ve ekran görüntüleri (Fastlane, Türkçe ve İngilizce); CI uzunluk sınırlarını ve her sürümün değişiklik notunu denetliyor (#115).
- README'de ve kılavuzda Obtainium'a tek dokunuşla ekleme bağlantısı (#114).
- Kurulumda kurtarma anahtarı kopyalanabiliyor (güvenli pano, 30 saniyede temizlenir) ve metin dosyası olarak kaydedilebiliyor; doğrulama adımı yapıştırmayı ve dosyadan okumayı kabul ediyor. Düğme "Yazdım" yerine "Kaydettim".

### Düzeltilenler

- QR tarayıcıda karartmadaki saydam pencere ile köşe çerçevesi artık aynı yerde ve aynı boyda; fener düğmesi açıklamanın altında kalmıyor, üst çubukta.

### Değişenler

- Yayın derlemesi F-Droid'in derleme imajında ve derleme yolunda (`/home/vagrant/build/io.github.aaudraa.keykey`) imzasız yapılıyor; imza ayrı bir işte `apksigner` ile atılıyor. Aynı commit'i F-Droid'in kendi aracı da derliyor ve taslak yayımlanmadan önce iki APK karşılaştırılıyor; F-Droid böylece bizim imzalı APK'mızı dağıtabilecek (#116, #117).
- README yeniden düzenlendi: kurulum yolları tek yerde, kodun büyük kısmının bir yapay zekâ asistanıyla yazıldığı açıkça yazılı.
- Bağımlılıklar güncellendi: Gradle 9.9.0, Android eklentisi 9.5.1, `drift` 2.35.4, `go_router` 18.1.4, `flutter_zxing` 3.1.1, `pigeon` 29.2.0 ve dolaylı paketler.
- Yayın iş akışı anahtar parolalarını derlemeden önce deniyor; anahtar oluşturma betiği Git Bash'teki iki tuzağa karşı düzeltildi (#112).

## 1.0.0 (2026-11-16): İlk kararlı sürüm

Kalıcı yayın anahtarıyla imzalanan ilk sürüm.

### Eklenenler

- Firefox'un parola dışa aktarmasını (CSV) içe aktarma (#95).
- Etiketten imzalı APK, AAB ve taslak GitHub Release üreten yayın iş akışı (#96).
- Türkçe ve İngilizce gizlilik bildirimi (#102).
- İlk açılışta altı sayfalık hareketli tanıtım: KeyKey'in ne olduğu, menüde nerede ne bulunduğu, otomatik doldurma, başka uygulamalardan geçiş ve yedek; atlanabilir, Ayarlar → Hakkında'dan yeniden izlenebilir.
- Ekran başlıkları (Kasa, 2FA, Ayarlar) dar, eğik, kalın ve büyük harfle; alttaki menüde sekme adı daha büyük.
- Ayarlar'da tema seçimi: Sistem, Açık ya da Koyu (#103). Seçim kilit ekranında ve otomatik doldurma penceresinde de geçerli; kasanın dışında, şifresiz küçük bir dosyada saklanıyor.

### Değişenler

- Sürümler kalıcı yayın anahtarıyla imzalanıyor (#97). Hata ayıklama anahtarıyla imzalı `v0.x` sürümlerinin üstüne kurulamaz: yedek al, eski uygulamayı kaldır, yeni sürümü kur ve yedeği geri yükle. Bu yol emülatörde denendi (#101), adımlar [yayın belgesinde](docs/yayin.md#eski-sürümlerden-geçiş).
- SQLite hazır kütüphane olarak indirilmiyor, repodaki 3.54.1 kaynağından derleniyor (#99).
- Aynı koddan aynı yolda yapılan iki derleme aynı APK'yı veriyor: Android Gradle eklentisinin APK'ya gömdüğü şifreli bağımlılık listesi kaldırıldı (#99).
- Yeni görünüm (#103): açık temada krem zemin ve kartlar, koyu temada koyu gri; turuncu yalnızca K logosunda, "+" düğmesinde, ekranın ana düğmesinde ve 2FA halkasında. Zeminde yavaş kayan soluk lekeler. Alt menü ekranın altında yüzen buzlu cam; seçili sekme kapsülde adıyla görünür. Ayarlar beş grupta (Güvenlik, Yedek ve aktarım, Otomatik doldurma, Görünüm, Hakkında); uzun açıklamalar (i) düğmesinde, sürüm Hakkında'da. Onay ve uyarı pencereleri alttan, yaylanarak açılıyor; hareketler telefonda "animasyonları kaldır" açıksa kapanıyor.
- Tek "+" (#103): her sekmede menünün ucundaki "+" düğmesi parola ya da 2FA kodu eklemeyi sorar; 2FA için QR tarama, resimden okuma, dosyadan içe aktarma ve elle girme aynı kutuda.
- Listeden kopyalama (#103): kasa listesinde her kaydın yanında parolayı kopyalama düğmesi var; 2FA kartına dokunmak kodu kopyalar, süre kartın sağındaki halkada.
- Sade formlar (#103): yeni parola ve 2FA formunda yalnızca temel alanlar görünür; klasör, not, özel alan, ek site, parola kaydı ve gelişmiş 2FA ayarları "Daha fazla seçenek" ile eklenir. Kaydet düğmesi ekranın altında, klavyenin üstünde.
- Ayarların en üstünde yedek kartı (#103): son yedeğin kaç gün önce alındığını gösterir ve tek dokunuşla yedek alır.
- Kilit ekranında zemin ve logo yavaşça hareket eder; yanlış parolada parola kutusu kısaca titrer (#103).
- Android 14+ kenardan geri hareketinde sayfa parmağı izler (#103).
- Uygulama içi bildirimler üstten iniyor: durum çubuğunun altında ortada duran cam bir hap, yazısı büyük ve kalın. Yukarı kaydırınca ya da dokununca kapanır; "Geri al" düğmeli bildirim 6 saniye kalır, TalkBack açıkken kendiliğinden kapanmaz. Kasa kilitlenince açık bildirim kapanır.
- Yeni uygulama simgesi ve açılış ekranı: beyaz zeminde turuncu K (#103). Android 13+ temalı simge destekleniyor.
- Otomatik doldurma yarım pencerede açılıyor (#103): giriş yapılan uygulama arkada karartılmış olarak görünür kalır. Önce yalnızca eşleşen kayıtlar var; "Başka bir kayıt ara" kutusu pencereyi uzatır ve bütün kayıtlarda arar. Kilit açma, uyarılar ve kaydetme de aynı pencerede. Pencere arkayı bulanıklaştırmaz, kendi cam zeminini çizer; tutamaç sürüklenince parmağı izler. Karartılmış alana dokunmak, hızlı aşağı kaydırmak ya da pencereyi yarısından fazla aşağı çekmek hiçbir şey doldurmadan kapatır; uyarıdayken geri tuşu listeye döner. Sahte olabilecek uygulama uyarısında "Yine de doldur" kırmızıdır.
- Tek kesin eşleşme sorulmadan dolduruluyor (#103): tam olarak bir kayıt eşleşiyorsa, eşleşme kesinse (uygulamada imza, güvenilen tarayıcıda alan adı) ve hiçbir uyarı yoksa liste açılmaz. Her doldurmadan sonra kısa bir bildirim kaydın adını gösterir ("GitHub dolduruldu"); kullanıcı adı ve parola bildirime girmez. Bildirimin güvenli pencere dışında görünmesi [bilinen sınır](docs/guvenlik-tasarimi.md#bilinen-sınırlar) olarak yazıldı.

### Belgeler

- Giriş kutularını Android'in doldurma sistemine bildirmeyen uygulamalar bilinen sınır olarak yazıldı; örnek HoYoLAB'ın giriş ekranı (#94).
- Ekran görüntülü kullanım kılavuzu: kurulum, ilk kasa, parolalar, 2FA, otomatik doldurma, yedekleme, geçiş ve bilinen sınırlar (#104).
- Gizlilik bildirimi tema dosyasıyla güncellendi.

## 0.8.0 (2026-11-09): Güvenlik sertleştirme ve denetim

- OWASP MASVS denetimi; bulunan açık kapatıldı: başka bir uygulama, adres taşıyan bir niyetle KeyKey'i istediği ekrana götürebiliyordu.
- Bindirme pencerelerine ve gizlenmiş dokunuşlara karşı arayüz koruması.
- Yayın derlemesinde R8; APK'da izin, sembol ve deneme değeri denetimi.
- Çevrimdışı parola raporu: zayıf ve tekrar eden parolalar.
- Bağımlılık ve lisans denetimi; lisanslar ekranına Android kütüphaneleri ve SQLite eklendi.
- Erişilebilirlik: TalkBack, büyük yazı, kontrast düzeltmeleri.
- Gerçek telefonda StrongBox, parmak izi ve süre ölçümleri.

## 0.7.0 (2026-11-08): Yedekleme, içe ve dışa aktarma

- Şifreli `.keykey` yedeği (Argon2id ve libsodium `secretstream`), doğrulamalı geri yükleme, yedek hatırlatıcısı.
- Bitwarden (JSON, CSV), Chrome (CSV) ve KeePassXC (CSV) dosyalarından içe aktarma.
- Çift onaylı düz metin dışa aktarma.

## 0.6.0 (2026-11-07): Otomatik doldurma

- Android otomatik doldurma servisi; kilitli öneri, KeyKey ekranında kasayı açma.
- Uygulamalar paket adı ve imza sertifikasıyla, siteler yalnızca güvenilen tarayıcılardan gelen alan adıyla eşleşir; şüpheli durumda uyarı.
- Satır içi (klavye şeridi) öneriler, yeni parola kaydetme, doldurmadan sonra 2FA kodunu kopyalama.
- Chrome 135+ için kurulum yönlendirmesi.

## 0.5.1 (2026-11-06): Faz 5 düzeltmesi

- Telefon denemesinin bulduğu sorunlar: gizli anahtar girişi ve yapıştırma, kurtarma anahtarı yazımı, kamerada daha hızlı QR okuma.

## 0.5.0 (2026-11-06): 2FA doğrulayıcı

- TOTP ve HOTP; SHA-1, SHA-256, SHA-512; 6-8 hane.
- Kamera ve görselden QR okuma, elle anahtar girişi.
- Google Authenticator, Aegis ve 2FAS'tan içe aktarma.
- Parola kaydıyla 2FA hesabını eşleştirme; kodlar için isteğe bağlı ek onay.

## 0.4.0 (2026-11-05): Parola kasası

- Kayıtlar: ad, kullanıcı adı, parola, adresler, not, özel alanlar.
- Liste, arama, favoriler, klasörler, çöp kutusu, parola geçmişi.
- Parola ve parola cümlesi üretici, güç ölçer, kendiliğinden temizlenen pano.

## 0.3.0 (2026-11-05): Kasa, kilit ve biyometri

- Kasa oluşturma, ana parola ve kurtarma anahtarı.
- Otomatik kilit, hatalı denemelerde artan bekleme.
- Parmak iziyle açma; yeni parmak izi eklenince geçersiz olur.

## 0.2.0 (2026-11-05): Kripto çekirdeği

- libsodium ile Argon2id, XChaCha20-Poly1305 ve HKDF; kasa üst bilgisi biçimi v1.

## 0.1.0 (2026-11-05): Flutter iskeleti ve CI

- Yalnızca Android, `minSdk 30`; ekran görüntüsü engeli, kapalı Android yedeklemesi, `INTERNET` izni yok.
- CI: biçim, analiz, test, Android derlemesi, gizli bilgi taraması.

## 0.0.0 (2026-11-04): Repo ve GitHub altyapısı

- Repo, lisans, şablonlar, güvenlik politikası ve yol haritası.

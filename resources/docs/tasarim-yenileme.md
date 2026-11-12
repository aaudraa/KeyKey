# KeyKey Tasarım Yenilemesi

> **2026-11-12:** Bu belgenin "Görsel dil" ve "Ekranlar" bölümlerinin yerini [cam tasarım belgesi](tasarim-cam.md) aldı. "Otomatik doldurma" bölümündeki davranış kuralları ve simge kararı geçerliliğini koruyor.

Faz 9'daki tasarım incelemesinin ([#103](https://github.com/aaudraa/KeyKey/issues/103)) tasarım belgesi. 2026-11-10'da proje sahibiyle birlikte örnek ekranlar üzerinden kararlaştırıldı. Bu belge neyin yapılacağını anlatır; nasıl ve hangi sırayla yapılacağı ayrı bir planda yazılır.

## Neden

KeyKey bugün Flutter'ın hazır Material 3 görünümünü kullanıyor: lacivert tohum rengi, düz liste satırları, standart alt menü, varsayılan Flutter simgesi. Proje sahibi bunu "eskiden kalma" buluyor. 1.0 ile ilk kez dışarıdan insanlar uygulamayı görecek. Amaç daha modern, sade ve sıcak bir görünüm, ayrıca otomatik doldurmayı daha az kesintili hale getirmek.

En önemli şikâyet otomatik doldurma: başka bir uygulamada "KeyKey ile doldur"a dokunulunca bütün ekranı kaplayan bir liste açılıyor ve giriş yapılan uygulama kayboluyor. Tek bir kayıt eşleşse bile yine listeden seçmek gerekiyor.

## Hedefler

1. Krem zeminli, turuncu ana renkli, sade ve tutarlı bir görünüm; açık ve koyu tema.
2. Ekranın üstünde yüzen, buzlu cam görünümlü küçük bir alt menü.
3. Kasa, 2FA ve ayarlar listelerinde küçük ve hepsi aynı boyda kartlar.
4. Bir uygulamaya bağlı kayıtlarda o uygulamanın kendi simgesi kartta silik olarak görünür.
5. Otomatik doldurma ve kaydetme ekranları alttan açılan yarım pencere olur; tek eşleşen kayıt sorulmadan doldurulur.
6. Uygulamanın kendi simgesi: beyaz zeminde kalın turuncu K. Açılış ekranı da bu simgeyi kullanır.

## Hedef olmayanlar

- Ekranların yaptığı işler değişmez. Tek davranış değişikliği doldurmadadır (aşağıda).
- Yeni izin eklenmez. Özellikle `QUERY_ALL_PACKAGES` ve `INTERNET` istenmez.
- Site logoları gösterilmez: KeyKey internete çıkmaz, logo indiremez, uygulamaya da logo paketi gömülmez.
- Yazı tipi indirilmez veya gömülmez; telefonun kendi yazı tipi kullanılır.
- Tablet ve yatay ekran için ayrı düzen yapılmaz.

## Olmaması gerekenler

Çalışsa bile başarısızlık sayılacak durumlar:

- Erişilebilirliğin gerilemesi. Faz 8'deki testler (kontrast, en az 48 dp dokunma hedefi, etiketler, %200 yazı boyutu, TalkBack) aynı şekilde geçmeli.
- Buzlu camın yazıyı okunmaz yapması ya da kaydırmayı takılır hale getirmesi.
- Renk kalabalığı. Renkli olan yalnızca turuncu vurgu ve uygulama simgeleridir.
- Kayıt bilgisinin güvenli pencerelerin (`FLAG_SECURE`) dışına çıkması. Tek bilinçli istisna, doldurmadan sonraki bildirimdeki kayıt adıdır (aşağıda).
- Otomatik doldurmanın güvenlik kurallarının gevşemesi: imza ve alan adı eşleştirmesi, uyarılar ve ek onaylar aynen kalır.

## Görsel dil

### Renkler

Ana renk turuncudur (proje sahibinin kararı). Simgedeki parlak turuncu `#F26B1D` krem zeminde yazı için yeterli kontrast vermez (yaklaşık 2,9:1). Bu yüzden yazı ve düğmelerde aynı tonun okunur bir koyusu, koyu temada ise açığı kullanılır. Kesin değerleri plan belirler; her ikisi de kontrast testinden geçmelidir (normal yazıda 4,5:1).

| Rol | Açık tema | Koyu tema |
|---|---|---|
| Zemin | krem `#F6F1E7` | sıcak koyu `#1C1A17` |
| Kart | `#FFFDF8`, ince kenar `#E7DFCF` | `#24211D`, kenar `#34302A` |
| Yazı | `#2B2A28` | `#EFE8DA` |
| İkincil yazı | `#696356` (kremde 5,3:1) | `#9B9384` |
| Vurgu (düğme, seçili sekme, 2FA halkası, anahtarlar) | `#B4470F`, üstünde beyaz (kremde 4,85:1) | `#FF8A4C`, üstünde `#1C1A17` (7,4:1) |
| Simge ve büyük yüzeyler | `#F26B1D` | `#F26B1D` |
| Hata | kırmızı, kontrastı denetlenmiş | aynı |

Tema telefonun ayarını izler. Material 3 bileşenleri kalır; bu renkler `ColorScheme` ile verilir.

### Kartlar

- Kasa, 2FA ve ayarlar listelerindeki kartlar **hep aynı boydadır**, yazının uzunluğuna göre büyümez (proje sahibinin kararı). Kasa kartı iki satırdır (ad ve kullanıcı adı); uzun yazı tek satırda `…` ile kesilir.
- Köşeler yumuşak (yaklaşık 14 dp), kartlar arası dar boşluk, gölge yok, ince kenar.
- **İstisna, erişilebilirlik:** telefonun yazı boyutu büyütülünce kartlar da büyür. Yoksa %200 yazıda metin kesilir ve Faz 8'in testleri bozulur. Aynı boy kuralı normal yazı boyutu içindir. *(Benim kararım.)*

### Kayıt simgeleri

- Telefondaki bir uygulamaya bağlı kayıtta, o uygulamanın kendi simgesi kartın kenarında büyük ve silik (yaklaşık %20 görünürlük) durur, kartın dışına taşar ve kesilir. Kasa kartında sağda, 2FA kartında solda.
- Simge Android'den o an okunur (`PackageManager`), diske yazılmaz, yalnızca kasa açıkken bellekte tutulur. KeyKey yalnızca ana ekranda simgesi olan uygulamaları görebilir; görünmeyen uygulamada simge yerine aşağıdaki çizgi simge çıkar.
- Bağlı uygulaması olmayan kayıtta renksiz, ince çizgili bir simge görünür: sitesi olan kayıtta küre, olmayanda anahtar. *(Simge seçimi benim kararım.)*
- Arayüzün diğer bütün simgeleri de renksiz çizgi simgelerdir (proje sahibinin isteği). Renkli olan yalnızca uygulama simgeleri ve turuncu vurgudur.

### Alt menü

- Ekranın altında, kenarlardan ayrık, yuvarlak uçlu küçük bir şerit (yaklaşık 190×56 dp). Arkasındaki içerik bulanık ve yarı saydam görünür (buzlu cam).
- Yalnızca üç simge var, yazı yok. Seçili sekmenin simgesi dolu ve turuncu, altında küçük bir nokta duruyor. *(Yazısız olması benim önerim, proje sahibi örnekte gördü.)*
- TalkBack için sekme adları ("Kasa, sekme 1/3") eskisi gibi okunur.
- Listeler menünün arkasından kayar. Son kartın menünün altında kalmaması için listelerin sonunda boşluk bırakılır.
- Bugünkü davranış korunur: etkin sekmeye dokunmak bir üst ekrana döner ve kaydedilmemiş değişiklikleri sorar.

### Simge ve açılış ekranı

- Simge: beyaz zeminde kalın, sade, turuncu bir K (örneklerdeki "A"). K simgenin içinde kalır, kenardan taşmaz (proje sahibinin son kararı). Android'in uyarlanabilir simgesi olarak yapılır: beyaz arka katman, turuncu K ön katmanı, güvenli alana göre ölçeklenmiş. Android 13+ temalı simge için tek renkli K katmanı da eklenir.
- Kaynak SVG `resources/design/` altına girer.
- Açılış ekranı Android'in kendi açılış ekranı yöntemiyle yapılır: ortada simge, zemin açık temada krem, koyu temada sıcak koyu renk. Android 11'de (Android'in açılış ekranı API'si olmayan tek desteklenen sürüm) aynı görünüm başlangıç teması ile verilir. *(Benim kararım.)*

## Ekranlar

| Ekran | Yeni görünüm |
|---|---|
| Kasa | Başlık, yuvarlak arama kutusu, sabit boy kartlar, yüzen menü. Sıralama, rapor ve çöp kutusu düğmeleri çizgi simgeli kalır. "Henüz yedek yok" uyarısı da bir kart olur. |
| 2FA | Kartta solda hesap adı, sağda tek parça büyük kod (eşit aralıklı yazı) ve kalan süreyi gösteren küçük turuncu halka. Dokununca kopyalar, şimdiki gibi. |
| Kayıt ayrıntısı | Kullanıcı adı, parola, 2FA kodu ve site ayrı ayrı küçük kartlarda; kopyala ve göster düğmeleri çizgi simge. |
| Düzenleme ekranları | Krem zeminde yumuşak köşeli kutular, turuncu Kaydet düğmesi. |
| Kilit | Krem zemin ortasında simge, altında parola kutusu ve "Aç". Parmak izi açıksa sistem penceresi kendiliğinden gelir. |
| Ayarlar | Derli toplu (proje sahibinin isteği). Satırlar dört grup altında, her grup bir kart gibi: **Güvenlik** (ana parolayı değiştir, parmak izi, 2FA kodları için onay, şimdi kilitle), **Yedek ve aktarım** (yedekle, geri yükle, parola ve 2FA içe aktarma, şifresiz dışa aktarma), **Otomatik doldurma** (servis durumu, doldurunca 2FA kodunu kopyala), **Hakkında** (sürüm, lisanslar). Satırlar aynı boyda. Anahtarların altındaki uzun açıklamalar satırdan çıkar, satırdaki küçük (i) düğmesiyle yarım pencerede açılır. *(Gruplar ve (i) benim kararım.)* |
| Uyarı ve onay pencereleri | Ortada açılan kutu yerine alttan açılan yarım pencere. |

Tabloda olmayan ekranlar da (kasa kurulumu ve kurtarma anahtarı, parola raporu, çöp kutusu, içe aktarma, geri yükleme, otomatik doldurma kurulumu, lisanslar) aynı dili izler: krem zemin, aynı boy kartlar, çizgi simgeler, turuncu ana düğme.

2FA'daki sayaçlı (HOTP) hesaplarda kodun yerinde "Kod üret" düğmesi durur; kart yine aynı boydadır. "Hakkında" grubundaki sürüm satırı yeni: uygulamanın sürüm adını gösterir. *(İkisi de benim kararım.)*

Bütün ekranlarda içerik ve davranış aynı kalır; yalnızca görünüş değişir.

## Otomatik doldurma

### Yarım pencere

`AutofillActivity` saydam açılır: giriş yapılan uygulama arkada, hafif karartılmış olarak görünür kalır. KeyKey'in içeriği alttan açılan, köşeleri yuvarlak bir yarım pencerededir. Aşağı kaydırınca ya da karartılmış alana dokununca kapanır ve hiçbir şey doldurulmaz. `FLAG_SECURE`, son uygulamalar listesinde görünmeme ve ayrı giriş noktası (`autofillMain`) aynen kalır.

- **Kilit açma:** Parmak izi açıksa sistemin kendi penceresi gelir. Ana parola gerekiyorsa yarım pencerede sorulur. Doldurma akışında hiçbir adım tam ekranı kaplamaz.
- **Liste:** Önce yalnızca eşleşen kayıtlar, altında "Başka bir kayıt ara" kutusu. Aramaya dokununca pencere yukarı doğru uzar ve bütün kayıtlarda arar.
- **Uyarılar** (eşleşme yok, WebView, `http`, imza tutmuyor) ve ek onayları aynı pencerenin içinde gösterilir. Metinleri ve kuralları değişmez.

### Tek kaydın doğrudan doldurulması

Kilit açıldıktan sonra şu üçü birlikte geçerliyse pencere açılmaz, kayıt hemen doldurulur (proje sahibinin kararı):

1. tam olarak **bir** kayıt eşleşiyor,
2. eşleşme kesin: uygulama hedefinde imza sertifikası tutuyor, ya da güvenilen bir tarayıcıda kayıt edilebilir alan adı tutuyor,
3. hiçbir uyarı yok: WebView değil, `http` değil.

Gerekçe: Kullanıcı isteğini zaten iki kez gösterdi: öneriye dokundu ve kilidi açtı. Eşleşme kesin olduğu için yanlış uygulamaya ya da sahte siteye doldurma riski seçme adımında değil, eşleştirme kurallarında karşılanıyor. Birden fazla eşleşme varsa (aynı oyunda iki hesap gibi) pencere açılır ve yalnızca o kayıtlar gösterilir.

### Doldurma bildirimi

Doldurmadan sonra ekranın altında kısa bir bildirim (Android `Toast`) çıkar: "GitHub dolduruldu". Kullanıcı hangi kaydın gittiğini görür (proje sahibinin kararı). Bildirim yalnızca kaydın adını taşır, kullanıcı adını taşımaz.

Bilinçli ödün: Bildirim KeyKey'in güvenli penceresinin dışında görünür. Ekran kaydına girer ve erişilebilirlik servislerine bildirilir. Bugün kayıt adı KeyKey dışında hiç görünmüyor. Kayıt adı genelde zaten ekranda olan uygulamanın adı olduğu ve kullanıcı adı ile parola bildirime girmediği için bu kabul edildi. Güvenlik tasarımı belgesine yazılır.

Bildirim her doldurmada çıkar; listeden seçilerek yapılan doldurmada da. *(Benim kararım: tutarlılık için.)*

### Kaydetme

"KeyKey'e kaydet" ekranı da aynı yarım pencerede açılır. Kilit açma, düzenleme ve kaydetme kuralları değişmez.

## Kısıtlar

- Flutter ve Material 3 kalır. Yeni paket eklenmesi gerekirse bağımlılık belgesine ([bagimliliklar.md](bagimliliklar.md)) gerekçesiyle yazılır. Buzlu cam ve yarım pencere Flutter'ın kendi bileşenleriyle yapılabilir.
- En düşük sürüm Android 11 (API 30). Buzlu cam ve saydam doldurma penceresi Android 11, 14, 16 ve 17 emülatörlerinde ve Samsung telefonda denenir.
- Bulanıklaştırma pahalıdır. Yalnızca alt menüde (ve yarım pencerenin arkasındaki karartmada gerekirse) kullanılır; kartlarda kullanılmaz.
- `FLAG_SECURE`, `setHideOverlayWindows`, gizli dokunuş filtresi ve hassas pencere işaretleri her ekranda ve saydam doldurma penceresinde korunur. Saydam pencere bindirme korumasını zayıflatmamalı.
- Türkçe ve İngilizce bütün yeni metinler `.arb` dosyalarına girer.
- Testler: Faz 8'in erişilebilirlik testleri açık ve koyu temada, normal ve %200 yazıda geçmeli. Doldurmanın tek kayıt kuralı için birim testleri yazılır (tek kesin eşleşme, iki eşleşme, uyarılı tek eşleşme, eşleşme yok). Entegrasyon ve cihaz testleri dört emülatörde geçmeli.
- Güvenlik tasarımı belgesi doldurma akışı ve bildirim için güncellenir.

## Uygulayıcıya bırakılanlar

- Turuncunun okunur koyu ve açık tonlarının kesin değerleri (kontrast testinden geçecek şekilde).
- Kart yüksekliği, boşluklar ve köşe yarıçapı gibi kesin ölçüler (yukarıdaki yaklaşık değerler çevresinde).
- Çizgi simge seti: Flutter'ın Material Symbols "outlined" simgeleri yeterliyse onlar.
- Bulanıklık miktarı ve saydamlık oranı; performans ve okunurluk dengesi.
- Yarım pencerenin ilk yüksekliği ve uzama biçimi.
- Saydam doldurma penceresinin Android'deki kurulumu (tema ve Flutter'ın saydam arka plan kipi).

## Örnek ekranlar

Görüşmede kullanılan örnek ekranlar yalnızca yön göstermek içindi. Kesin ölçü ve renk bu belgedir.

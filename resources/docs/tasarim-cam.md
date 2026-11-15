# KeyKey Cam Tasarım

Tasarım incelemesinin ([#103](https://github.com/aaudraa/KeyKey/issues/103)) ikinci turunun tasarım belgesi. 2026-11-12'de proje sahibiyle örnek ekranlar üzerinden kararlaştırıldı. Bu belge neyin yapılacağını anlatır; nasıl ve hangi sırayla yapılacağı ayrı bir planda yazılır.

Bu belge [ilk tasarım belgesinin](tasarim-yenileme.md) "Görsel dil" ve "Ekranlar" bölümlerinin yerine geçer. O belgenin "Otomatik doldurma" bölümündeki davranış kuralları (yarım pencere, tek kesin eşleşmenin sorulmadan doldurulması, doldurma bildirimi) ve simge kararı aynen geçerlidir.

Örnek ekranlar: [`resources/design/cam-tasarim-ornekleri.html`](../design/cam-tasarim-ornekleri.html) (tarayıcıda açılır, açık ve koyu tema düğmesi var). Örnekler yönü gösterir; kesin ölçü, renk ve kural bu belgedir.

## Neden

İlk tur (krem zemin, turuncu vurgu, aynı boy kartlar, yüzen menü) kodda bitti, proje sahibi telefonda birkaç gün kullandı ve beğenmedi. Kendi sözleriyle:

- "Eski tasarıma göre sadece renkler değişmiş."
- Menünün cam olduğunu anlamak için yakından bakmak gerekiyor; günler sonra fark etti.
- Arka planlar klişe, kasa ekranındaki kartlar kötü, simgeler istediği tarzda değil.
- Yeni parola ekranı korkutucu: çok fazla alan ve düğme aynı anda görünüyor.
- İstediği: "tamamıyla modern, sade ve konforlu"; efektler göze hitap etsin; her ekran değişsin, yalnızca ana ekranlar değil; hareketler yumuşak olsun; "çok iPhone tarzı olmasın", Android'de kullanılacak.

## Hedefler

1. Bütün ekranlarda tek bir dil: yumuşak renkli zemin üstünde yarı saydam cam kartlar ve belirgin biçimde cam görünen yüzen menü.
2. Ekleme tek yerden: menünün ucundaki "+" her sekmede aynıdır ve önce "Parola mı, 2FA kodu mu" diye sorar.
3. Formlar korkutmaz: ekranda yalnızca gereken alanlar ve tek ana düğme durur, gerisi istenince açılır.
4. Yumuşak, kısa ve tutarlı hareketler.
5. Android'e ait bir his: başlıklar solda, Android geri oku, üç nokta menüsü, Material anahtarları ve dokunma dalgası.

## Hedef olmayanlar

- Uygulamanın yaptığı işler değişmez. Bilinçli davranış değişiklikleri "Davranış değişiklikleri" bölümünde sayılmıştır; onların dışında bir şey değişirse hatadır.
- Yeni izin eklenmez. Özellikle `QUERY_ALL_PACKAGES` ve `INTERNET` istenmez.
- Site logoları gösterilmez: KeyKey internete çıkmaz, logo indiremez, uygulamaya logo paketi de gömülmez.
- Yazı tipi indirilmez veya gömülmez; telefonun kendi yazı tipi kullanılır.
- Tablet ve yatay ekran için ayrı düzen yapılmaz.
- Uygulama simgesi değişmez (beyaz zeminde turuncu K).

## Olmaması gerekenler

Çalışsa bile başarısızlık sayılacak durumlar:

- "Yine yalnızca renkler değişmiş" hissi. Kartların, menünün, formların ve hareketlerin biçimi de değişmiş olmalı.
- Camın fark edilmemesi. Menü ve açılan kutular ilk bakışta cam olarak okunmalı.
- Erişilebilirliğin gerilemesi. Faz 8'in testleri (kontrast, en az 48 dp dokunma hedefi, etiketler, %200 yazı boyutu, TalkBack) açık ve koyu temada geçmeli.
- Kaydırmanın ya da hareketlerin takılması (proje sahibinin Samsung telefonunda ve Android 11 emülatöründe).
- iOS taklidi: ortalanmış başlıklar, "‹ Geri" yazılı düğmeler, iOS anahtarları.
- Kayıt bilgisinin güvenli pencerelerin (`FLAG_SECURE`) dışına çıkması. Tek bilinçli istisna, ilk belgede anlatılan doldurma bildirimidir.
- Otomatik doldurmanın güvenlik kurallarının gevşemesi.

## Görsel dil

### Zemin

Her ekranın zemini düz bir açık (ya da koyu) renk ve üstünde üç büyük, çok yumuşak kenarlı renk lekesidir: sol üstte turuncu-şeftali, sağ ortada lila, sol altta pembe. Lekeler ekranla birlikte kaymaz, sabit durur; içerik üstlerinden kayar. Camın cam gibi görünmesini sağlayan budur: arkasında renk olmayan cam fark edilmez (ilk turdaki sorun).

Lekeler canlı bulanıklaştırmayla değil, yumuşak geçişli boyamayla çizilir (bulanıklaştırma pahalıdır). *(Benim kararım.)*

### Renkler

Örnek ekranlardaki değerler. Kesin tonları plan belirler; hepsi kontrast testinden geçmelidir.

| Rol | Açık tema | Koyu tema |
|---|---|---|
| Zemin | `#F3EEF4` | `#0C0B10` |
| Lekeler (şeftali, lila, pembe) | `#FF9A5A`, `#B48CFF`, `#FF6FA3`, %40-60 görünürlük | `#F26B1D`, `#6B3BFF`, `#E0336E`, %40-55 görünürlük |
| Cam kart | beyaz %50, beyaz ince kenar, üstte ince parlak çizgi, hafif gölge | beyaz %8, beyaz %17 kenar |
| Yazı | `#1B1A1F` | `#F5F2F8` |
| İkincil yazı | `#5F5B68` | `#B1ABBC` |
| Vurgu (seçili sekme, simgeler, bağlantılar, anahtarlar) | `#D4500E` | `#FF9457` |
| Ana düğme ("+", Kaydet, Kilidi aç, Yedekle) | turuncu geçiş `#FF9A52` → `#EC5512` | aynı |
| Vurgu zemini (simge kutuları, "Üret") | vurgunun %12'si | vurgunun %18'i |

Turuncu ana renk olarak kalır (proje sahibinin ilk turdaki kararı; bu turda örneklerde gördü ve onayladı). Tema telefonun ayarını izler. Material 3 bileşenleri kalır.

**Kontrast kuralı.** Zemin artık tek renk olmadığı için her yazı, altına gelebilecek en kötü noktada da okunmalıdır (normal yazıda 4,5:1, simge ve büyük yazıda 3:1). Bunun iki bilinen sonucu var:

- Örneklerdeki beyaz yazılı parlak turuncu düğme bu kuralı geçmiyor (yaklaşık 3,6:1 ve altı). Turuncunun canlılığı korunur; düğmenin üstündeki yazı ve simge koyu yapılır ya da geçiş koyulaştırılır. Hangisi olacağını uygulayıcı testle seçer; tercih turuncuyu soldurmamaktır. *(Benim kararım.)*
- Doğrudan zemine yazılan ikincil ve vurgu renkli yazılar (grup başlıkları, "Son değişiklik") lekenin en koyu yerinde sınırda kalıyor. Lekelerin görünürlüğü ya da bu yazıların tonu testten geçecek kadar ayarlanır. Gerçek uygulama bu yüzden örneklerden bir miktar daha sakin görünebilir.

### Cam

- **Kartlar** yarı saydamdır ama arkalarını bulanıklaştırmaz. Zemin zaten yumuşak olduğu için fark gözle görülmez; liste takılmadan kayar. *(Benim kararım.)*
- **Gerçek bulanıklaştırma** yalnızca içeriğin altından kaydığı ya da üstüne açıldığı yerlerde kullanılır: alt menü, "+" kutusu ve arkasındaki karartma, üç nokta menüsü, alttan açılan pencereler, kopyalama bildirimi.
- Cam yüzeylerin üst kenarında ince parlak bir çizgi ve altında yumuşak bir gölge bulunur; camı cam gibi gösteren ayrıntı budur.
- Köşeler: kartlar yaklaşık 22 dp, gruplar ve kutular 24-30 dp, düğmeler ve arama kutusu tam yuvarlak uçlu.

### Kayıt simgeleri

Her kaydın solunda 42 dp, yuvarlak köşeli, renkli bir kutu durur (ilk turdaki silik filigranın yerine):

- Kayıt telefondaki bir uygulamaya bağlıysa kutuda o uygulamanın kendi simgesi, tam renkli. Simge bugünkü gibi Android'den o an okunur, diske yazılmaz.
- Bağlı değilse kutu düz renklidir ve içinde kaydın adının baş harfi durur. Renk addan türetilir: aynı ad hep aynı rengi alır. Renkler, üstündeki beyaz harfin okunacağı sabit bir takımdan seçilir. *(Benim kararım.)*
- Baş harf süs sayılır, ekran okuyucu okumaz (bugünkü test korunur).

### Simgeler

Arayüz simgeleri yuvarlak hatlı çizgi simgelerdir (Flutter'ın Material simgelerinin yuvarlak takımı yeterliyse o). Ayarlar satırlarında ve "+" kutusunda simgeler vurgu zeminli küçük kutuların içinde durur.

### Android hissi

- Ekran başlıkları solda, büyük ve kalın. Alt ekranlarda sol üstte cam daire içinde Android geri oku.
- Ek işlemler sağ üstte cam daire düğmelerdir; ikiden fazlaysa üç nokta menüsünde toplanır.
- Anahtarlar Material 3 anahtarıdır. Dokunulan her şeyde dalga efekti olur.
- Android'in geri hareketi (kenardan kaydırma ve önizlemesi) her ekranda çalışır.

## Alt menü ve "+"

- Ekranın altında, kenarlardan ayrık, tam yuvarlak uçlu tek bir cam şerit. İçinde üç sekme (Kasa, 2FA, Ayarlar), ince bir ayraç ve en uçta yuvarlak turuncu "+" düğmesi vardır (proje sahibinin kararı).
- Seçili sekme simgesi ve adıyla birlikte, daha parlak bir cam kapsülün içinde görünür; diğer sekmeler yalnızca simgedir. Sekme değişince kapsül yeni sekmeye kayar.
- "+" her sekmede ve menünün göründüğü her ekranda aynıdır (proje sahibinin kararı). Dokununca:
  1. "+" dönerek çarpıya dönüşür, arkadaki ekran hafifçe kararıp bulanır, menünün hemen üstünde bir cam kutu yaylanarak açılır.
  2. Kutuda alt alta iki satır vardır: **Parola** ("Site ya da uygulama girişi") ve **2FA kodu** ("QR tara, elle gir ya da içe aktar"). Satırlar tam genişliktedir, simge solda, ad ve kısa açıklama yanında (proje sahibinin kararı: kutular yan yana değil alt alta).
  3. **Parola** yeni parola ekranını açar.
  4. **2FA kodu** aynı kutunun içeriğini kaydırarak dört satıra çevirir: QR tara, Resimden oku, Elle gir, İçe aktar. Bunlar bugünkü dört yolun aynısıdır. Kutunun başlığındaki ok ilk iki satıra döner. *(Aynı kutuda açılması benim kararım, proje sahibi örnekte gördü.)*
  5. Çarpıya, karartılmış alana ya da geri tuşuna basmak kutuyu kapatır.
- Seçim başka bir sekmeden yapıldıysa önce ilgili sekmeye geçilir (Parola için Kasa, 2FA için 2FA), ekleme ekranı orada açılır; kaydedince ya da vazgeçince o sekmenin listesine dönülür. *(Benim kararım.)*
- Kasa henüz yüklenmemişken satırlar bugünkü "Ekle" düğmesi gibi etkisizdir.
- Menü form ekranlarında görünmez (aşağıda). Diğer bütün ekranlarda bugünkü davranış korunur: etkin sekmeye dokunmak bir üst ekrana döner.
- TalkBack: sekme adları bugünkü gibi okunur; "+" düğmesi "Ekle", açıkken "Kapat" olarak okunur; kutu açıkken odak kutunun içinde kalır.

## Ekranlar

Numaralar örnek dosyadaki ekranlarla aynıdır.

| # | Ekran | Görünüm |
|---|---|---|
| 1 | Kilit | Ortada K simgesi, "Kasa kilitli" başlığı, tek cam parola kutusu, tek büyük "Kilidi aç" düğmesi. Altında cam daire içinde parmak izi düğmesi (parmak izi açıksa), en altta "Parolamı unuttum". Zemindeki lekeler çok yavaş yer değiştirir, simge hafifçe süzülür; bu hareket yalnızca bu ekrandadır. Bekleme süresi ve hata metinleri değişmez. |
| 2 | Kasa | Büyük "Kasa" başlığı, sağında üç nokta (Sırala, Parola raporu, Çöp kutusu). Cam arama kutusu; kayıt sayısı arama kutusunun silik yazısında ("24 kayıtta ara"). Favoriler ve klasör süzgeçleri arama kutusunun altında cam yongalar. Kayıtlar 64 dp cam kartlar: solda renkli simge kutusu, ad ve kullanıcı adı, sağda parolayı kopyalama düğmesi; favori kayıtta adın yanında küçük turuncu yıldız. Yedek uyarısı ve okunamayan kayıt uyarısı listenin üstünde cam kart olarak durur. |
| 3-4 | "+" kutusu | Yukarıda anlatıldı. |
| 5-6 | Yeni parola ve düzenleme | Sol üstte geri oku, yanında başlık, sağ üstte kaydın simge kutusu (ad yazıldıkça oluşur). Dört alan ayrı cam kartlarda: Ad, Kullanıcı adı, Parola (göster düğmesi, "Üret" ve güç çubuğu aynı kartta), Site. Altında "Daha fazla seçenek" satırı, en altta tek büyük "Kaydet". Ayrıntı aşağıda. |
| 7 | Kayıt ayrıntısı | Sol üstte geri, sağ üstte düzenle ve üç nokta (bugünkü diğer işlemler). Büyük simge kutusu, ad ve site. Her bilgi kendi cam kartında, yanında yalnızca gereken düğmeler (kopyala; parolada ayrıca göster). Bağlı 2FA kodu büyük rakamlarla ve süre halkasıyla kendi kartında. Altta "Son değişiklik" bilgisi. |
| 8 | 2FA | Büyük "2FA" başlığı, üç nokta (bugünkü işlemler), cam arama kutusu. Kartlar 72 dp: solda simge kutusu, üstte küçük "Sağlayıcı · hesap", altında büyük, eşit aralıklı kod, sağda süreyle azalan turuncu halka. Dokununca kopyalar. Sayaçlı (HOTP) hesapta kodun yerinde "Kod üret" durur. Kodlar gizliyken bugünkü onay akışı aynı dille gösterilir. |
| 9 | Ayarlar | Büyük "Ayarlar" başlığı. En üstte yedek durumu kartı ("Son yedek 12 gün önce" ya da "Henüz yedek yok") ve "Yedekle" düğmesi. Altında dört grup, her biri tek cam kart: **Güvenlik**, **Yedek ve aktarım**, **Otomatik doldurma**, **Hakkında**; içerikleri ilk turdakiyle aynı. Her satırda vurgu zeminli simge kutusu, ad ve sonda anahtar ya da ok. Uzun açıklamalar bugünkü gibi (i) ile alttan açılan pencerede. |
| 10 | Otomatik doldurma ve kaydetme | Başka uygulamanın üstünde alttan yaylanarak açılan pencere. Pencerenin kendi yumuşak renkli zemini vardır (arkadaki uygulamayı bulanıklaştırmaya güvenmez; her Android sürümünde aynı görünür). Üstte tutamaç, küçük K simgesi, "Doldur" başlığı ve eşleşme sayısı; altında eşleşen kayıtlar cam kart olarak, en altta "Başka bir kayıt ara". Kurallar, uyarılar ve onaylar ilk belgedeki gibidir. |

Çizilmeyen ekranlar aynı dili izler: ilk kurulum ve yedekten kurulum, kurtarma anahtarı, yeni ana parola, parola üretici, 2FA düzenleme ve elle ekleme, QR tarama, parola raporu, çöp kutuları, içe aktarma, geri yükleme, şifresiz dışa aktarma, ana parolayı değiştirme, otomatik doldurma kurulumu, lisanslar, "kullanılamıyor" ekranı. Kural: renkli zemin, cam kartlar, solda büyük başlık, tek ana düğme, uyarı ve onaylar alttan açılan cam pencerede.

### Formlar

Proje sahibinin şikâyeti: "yeni parola ekleme korkutucu geliyor, çok buton var; çok buton olacaksa da yumuşak görünmeli."

- Yeni kayıtta yalnızca dört temel alan görünür. Klasör, not, özel alan ve ek site "Daha fazla seçenek" satırının altındadır.
- "Daha fazla seçenek" açılınca ek alanlar küçük cam yongalar olarak gelir ("+ Klasör", "+ Not", "+ Özel alan", "+ Başka site"). Yongaya dokununca yalnızca o alan forma eklenir ve odak ona geçer. Eklenen alanın yanında küçük bir kaldırma düğmesi olur.
- Var olan bir kaydı düzenlerken dolu olan ek alanlar doğrudan görünür; yongalar yalnızca boş olanlar içindir. Hiçbir veri gizlenmiş kalmaz. *(Benim kararım.)*
- Kayıt bir uygulamaya bağlıysa bağlantı satırı ve kaldırma düğmesi bugünkü gibi görünür.
- Form ekranlarında alt menü görünmez; onun yerinde tek büyük "Kaydet" düğmesi durur. Klavye açılınca düğme klavyenin üstünde kalır. *(Benim kararım: örneklerde böyle çizildi.)* Geri gidince kaydedilmemiş değişiklik sorusu bugünkü gibi sorulur.
- Aynı kalıp diğer formlarda da kullanılır. 2FA elle eklemede temel alanlar Sağlayıcı, Hesap ve Gizli anahtardır ("Yapıştır" düğmesiyle); not, bağlı kayıt ve gelişmiş ayarlar (tür, algoritma, basamak, süre ya da sayaç) "Daha fazla seçenek" altındadır.
- Form ekranları: yeni ve düzenlenen parola, yeni ve düzenlenen 2FA hesabı, ana parolayı değiştirme, içe aktarma ekranları.

## Hareket

Proje sahibinin isteği: "az da animasyon", "smooth olsun".

| Yer | Hareket |
|---|---|
| "+" kutusu | Yaylanarak açılır (yaklaşık 400 ms), satırlar sırayla belirir, "+" çarpıya döner. Kapanış daha hızlıdır (yaklaşık 200 ms). |
| Sekme değişimi | Seçili kapsül yeni sekmeye kayar, içerik kısa bir geçişle değişir. |
| Karttan ayrıntıya | Kayıt kartı ayrıntı ekranına doğru büyür; simge kutusu yerinden yeni yerine taşınır. |
| Listeler | Ekran ilk açıldığında görünen kartlar kısa bir sırayla belirir. Kaydırırken ek hareket yoktur. |
| Kopyalama | Altta cam bir bildirim yükselir ("Parola kopyalandı") ve kendiliğinden kaybolur. |
| 2FA halkası | Süreyle birlikte kesintisiz azalır. |
| Alttan açılan pencereler | Yaylanarak açılır, aşağı çekince parmağı izler. |
| Kilit | Lekeler çok yavaş kayar, simge süzülür; yanlış parolada kutu kısa bir titremeyle uyarır. |
| Dokunma | Dalga efekti; kartlar basılıyken çok hafif küçülür. |

Kurallar:

- Hareketler kısa tutulur (çoğu 150-400 ms) ve hiçbiri bir işlemi bekletmez: kullanıcı animasyon bitmeden bir sonraki dokunuşu yapabilir.
- Telefonda "animasyonları kaldır" açıksa hareketler anında olur ve kilit ekranındaki süzülme durur.
- Android'in geri hareketi önizlemesiyle çakışan özel geçiş yapılmaz.

## Davranış değişiklikleri

Görünüş dışında değişen her şey bu listededir:

1. **Tek "+".** Kasa ve 2FA ekranlarındaki ayrı "Ekle" düğmeleri kalkar; ekleme her sekmede menüdeki "+" ile başlar ve tür sorulur (proje sahibinin kararı).
2. **Listeden kopyalama.** Kasa kartındaki düğme, kaydı açmadan parolayı kopyalar. Ayrıntı ekranındaki kopyalamayla aynı yolu kullanır (aynı pano kuralları ve aynı bildirim). Parolası boş kayıtta düğme görünmez. *(Örneklerde vardı, proje sahibi gördü; davranış olarak benim önerim.)*
3. **Formlarda menü yok.** Form ekranlarında alt menü gizlenir, "Kaydet" altta durur.
4. **Ek alanlar istenince.** Formlarda ek alanlar "Daha fazla seçenek" altından eklenir.
5. **Süzgeç yongaları.** Favoriler ve klasör yongaları, ancak en az bir favori ya da klasör varsa görünür; boş kasada satır yer kaplamaz. *(Benim kararım.)*
6. **Ayarlarda yedek kartı.** Yedek durumu ve "Yedekle" en üste taşınır; "Yedek ve aktarım" grubunda yedekleme satırı ayrıca durmaz. *(Benim önerim, proje sahibi örnekte gördü.)*
7. **Ekran işlemleri üç noktada.** Kasa ekranındaki sıralama, rapor ve çöp kutusu düğmeleri tek menüde toplanır.
8. **2FA kartında işlemler uzun basınca.** Karttaki üç nokta kalkar (örneklerde yoktu); Düzenle, Favori ve Çöp kutusuna taşı, karta uzun basınca alttan açılan pencerede durur. TalkBack'te aynı işlemler kartın işlem listesinde de bulunur. *(Benim kararım; plan yazılırken eklendi.)*

## Kısıtlar

- Flutter ve Material 3 kalır. Cam, yay ve geçişler Flutter'ın kendi bileşenleriyle yapılır; yeni paket gerekirse [bağımlılık belgesine](bagimliliklar.md) gerekçesiyle yazılır.
- En düşük sürüm Android 11 (API 30). Görünüm ve hareketler Android 11, 14 ve 17 emülatörlerinde ve Samsung telefonda denenir (Android 16 emülatörü bozuk; yeniden kurulursa o da).
- `FLAG_SECURE`, `setHideOverlayWindows`, gizli dokunuş filtresi ve hassas pencere işaretleri her ekranda ve doldurma penceresinde korunur. "+" kutusu ve menüler uygulamanın kendi penceresinin içinde çizilir, ayrı pencere açmaz.
- Türkçe ve İngilizce bütün yeni metinler `.arb` dosyalarına girer.
- Yazı boyutu büyütülünce kartlar da büyür; %200'de hiçbir metin kesilmez ve taşmaz. Kart yükseklikleri normal yazı boyutu içindir.
- Testler:
  - Tema testleri yeni renklerle yeniden yazılır; kontrast, zeminin en açık ve en koyu noktasına göre ölçülür.
  - Faz 8'in erişilebilirlik testleri açık ve koyu temada, normal ve %200 yazıda geçer.
  - Yeni testler: "+" kutusunun üç sekmede açılması ve doğru ekranlara gitmesi; kasa yüklenmeden etkisiz olması; formlarda menünün gizlenmesi; "Daha fazla seçenek" yongalarının alan eklemesi ve düzenlemede dolu alanların görünmesi; listeden kopyalama; süzgeç yongalarının görünme kuralı; "animasyonları kaldır" açıkken hareketlerin atlanması.
  - Entegrasyon ve cihaz testleri yeni düğme yerlerine göre güncellenir ve üç emülatörde geçer.
- [Güvenlik tasarımı belgesi](guvenlik-tasarimi.md) panoya kopyalamanın nerelerden yapılabildiğini sayıyorsa listeden kopyalama eklenir.
- İlk turun bileşenleri (aynı boy kart, silik filigran, yalnızca simgeli menü) bu tasarıma göre değiştirilir ya da kaldırılır; kullanılmayan kod bırakılmaz.

## Uygulayıcıya bırakılanlar

- Kesin renk tonları, leke yerleri ve görünürlükleri (kontrast testinden geçecek şekilde).
- Ana düğmede koyu yazı mı, koyulaştırılmış turuncu mu kullanılacağı.
- Kart yükseklikleri, boşluklar ve köşe yarıçapları (yukarıdaki yaklaşık değerler çevresinde).
- Bulanıklık miktarı ve saydamlık oranları; performans ve okunurluk dengesi.
- Baş harf kutuları için renk takımı ve addan renge giden kural.
- Hareketlerin kesin süreleri ve eğrileri; karttan ayrıntıya geçişin nasıl kurulacağı.
- Form ekranlarında menünün nasıl gizleneceği (yönlendirme yapısı).
- Açılış ekranının zemin rengi (yeni zemin rengine uyacak şekilde; lekesiz düz renk yeterli).
- İşin hangi sırayla ve kaç adımda yapılacağı.

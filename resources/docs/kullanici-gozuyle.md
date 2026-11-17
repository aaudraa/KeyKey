# Kullanıcı gözüyle iyileştirmeler

Durum: proje sahibinin isteğiyle başladı (2026-11-17, gece): "uygulamayı bir kullanıcı gözünden bak, gerekli olup bizde olmayan bir detay varsa ekle" ve "tasarım iyileştirmesi ve değişikliği de yapabilirsin". Seçimleri ben yaptım; proje sahibi sabah gözden geçirecek. Faz 11, dal `faz/11-kullanici-gozuyle`, hedef sürüm `1.1.0`.

## Nasıl seçildi

Uygulamanın bütün kullanıcı yolları (kurulum, kayıt ekleme ve bulma, parola üretme, 2FA ekleme, doldurma, kilit, yedek, ayarlar) koddan ve metinlerden tek tek yürünerek tarandı; olgun çevrimdışı uygulamalarda (Aegis, KeePassDX, Bitwarden, Proton Pass) beklenen şeylerle karşılaştırıldı. Taramanın bulduğu çoğu şey zaten vardı: yedek hatırlatması, parola geçmişi, notlar, özel alanlar, sık kullanılanlar, sıralama, 2FA araması ve sonraki kod.

Değişmeyen sınırlar: `INTERNET` izni yok, veri yalnızca cihazda, güvenlik tasarımı gevşetilmez.

## Bu fazda

Durum sütunu: ✓ yapıldı, → proje sahibine bırakıldı.

| # | Kullanıcının gördüğü | Değişiklik | Durum |
|---|---|---|---|
| 1 | Uygulama arka plana gidince kilitleniyor, açınca hep Kasa sekmesine dönüyor: kullanıcı adını kopyalayıp parolaya dönen kayıt arar, 2FA kullanan her seferinde sekme değiştirir, doldurma kurulumundan dönen Ayarlar'ı bulamaz | Kilit açılınca kilitlenmeden önceki sekmeye ya da açık olan kasa kaydına dönülür. Formlar ve tek seferlik ekranlar geri açılmaz. Yer yalnızca bellekte tutulur. | ✓ |
| 2 | Kasadaki sıralama seçimi her kilitte sıfırlanıyor | Seçim ayarlarda saklanır. | ✓ |
| 3 | Ana parola değiştirirken yanlış parola beklemesi "900 saniye" diye yazıyor, saymıyor | Kilit ekranındaki gibi dakika:saniye geri sayımı. | ✓ |
| 4 | Tek bir 2FA hesabı QR ya da elle eklenirken aynısı varsa sessizce ikinci kopya oluşuyor | Aynı hesap varsa uyarılır; kullanıcı yine de ekleyebilir. | ✓ |
| 5 | Ad, site, klasör ve arama kutularında parola klavyesi açılıyor: büyük harf ve adres klavyesi yok | Gizli olmayan alanlar normal metin ya da adres klavyesi açar. Klavyenin öğrenmesi her alanda kapalı kalır. | → |
| 6 | Yedek ve dışa aktarma dosyalarının adı İngilizce arayüzde de Türkçe | Dosya adı arayüz diline göre. | ✓ |
| 7 | Parola üretici her açılışta 20 karaktere dönüyor | Son seçenekler saklanır (parola değil, yalnızca uzunluk ve türler). | ✓ |
| 8 | Klasör adı her seferinde elle yazılıyor; "İş" ve "iş" iki klasör oluyor | Klasör kutusu var olan klasörleri önerir. | ✓ |
| 9 | Çöp kutusunda her kaydı tek tek silmek ya da geri yüklemek gerekiyor | "Çöpü boşalt" (onaylı) ve "Tümünü geri yükle". | ✓ |
| 10 | Boş kasada yalnızca "+" var; başka uygulamadan gelen ya da yeni telefona geçen kullanıcı içe aktarmayı aramak zorunda | Boş kasada "İçe aktar" ve "Yedekten geri yükle" kısayolları. | ✓ |
| 11 | Ana parola değişince eski yedeklerin eski parolayla açılmaya devam ettiği söylenmiyor | Değişiklikten sonra bunu söyleyen ve yeni yedek öneren bir not. | ✓ |
| 12 | "Kasa okunamadı" ekranı yalnızca "KeyKey'i güncelle" diyor | Dosya bozuksa yedekten geri yükleme yolu da anlatılır. | ✓ |
| 13 | Android 13 ve üstünde KeyKey'in dili sistem ayarlarından ayrıca seçilemiyor | Uygulama başına dil (`localeConfig`). | ✓ |
| 14 | Metinler: kaydı bırakmak "Sil", çöpten çıkarmak "Geri al" diyor; "1 2FA accounts" gibi tekil/çoğul hataları; ayrıntı ekranındaki bütün kopyala düğmeleri ekran okuyucuya yalnızca "Kopyala" diyor | Metin düzeltmeleri; kopyala düğmeleri hangi alanı kopyaladığını söyler. İngilizce sayılı metinlerin hepsi zaten tekil/çoğul ayırıyordu; Türkçede gerek yok. | ✓ |
| 15 | Kılavuz, "sık kullanılan" düğmesinin yerini yanlış gösteriyor | Kılavuz düzeltmesi. | ✓ |

Zaman kalırsa sırayla (ilki yapıldı: "Siteyi aç" ve Hakkında bağlantıları, [güvenlik tasarımı](guvenlik-tasarimi.md#tarayıcıda-açma)): kayıttaki siteyi tarayıcıda açma ve Hakkında'ya kaynak kod, sorun bildirme, gizlilik ve kılavuz bağlantıları (tarayıcıya devretmek `INTERNET` izni gerektirmez); parmak iziyle açan kullanıcıya ara sıra ana parolayı sorma (Aegis'teki parola hatırlatıcısı); 2FA hesabını başka uygulamaya taşımak için QR olarak gösterme ve düz `otpauth://` listesini içe aktarma.

Ayrıca yapılanlar: boş 2FA listesinde "Başka uygulamadan aktar" kısayolu (boş kasadakiyle tutarlı).

## Bağımsız gözden geçirme

Faz bitince dal, kodu yazmamış ayrı bir model tarafından baştan incelendi. Bulunan önemli hata: kilit açılınca **listeden açılan kayda** dönülmüyordu (go_router'da push ile açılan sayfa temel adreste görünmüyor); düzeltildi, test listeden açılan kayıtla deniyor. Küçük bulguların hepsi düzeltildi: tek kayıttaki klasörün harf büyüklüğü, port taşıyan şemasız adres, kullanıcı bilgisi taşıyan yanıltıcı adres, bağlı 2FA kodunun kopyala düğmesi, parola değiştikten sonra düğmenin yeniden açılması, sıralama adının tam `switch`'le yazılması, iki zayıf test.

Bilerek böyle bırakılanlar (kararlarım):

- Düzenleme formundayken kilitlenirse kayda değil listeye dönülür: formlar geri açılmaz, yarım değişiklik bellekte tutulmaz.
- ASCII dışı harfli alan adlarında "Siteyi aç" çıkmaz: benzer görünen alan adlarına karşı. Adres kopyalanıp tarayıcıya yapıştırılabilir.
- Klasör eşleşmesi Türkçe harfleri de sadeleştirir ("Şirket" ile "Sirket" aynı klasör): aramadaki kuralla aynı.
- Kilit açıldıktan hemen sonra liste önce ada göre çizilip ayarlar yüklenince bir kez yeniden sıralanabilir; ayarlar şifreli kayıtta, kilitten önce okunamaz.
- "Siteyi aç" adresi o siteyi açtığını bildiren bir uygulamaya da (örneğin GitHub uygulaması) gidebilir; Android'in olağan davranışı.

## Tasarım: cam yalnızca alt menüde

Proje sahibi (2026-11-17, sabah): "Benim istediğim cam tasarımı sadece alttaki navbar, harici şart değil, kalanı sana emanet." Kararlar benim.

**Ne değişiyor:**

1. **Gerçek bulanıklık yalnızca alt menüde ve ona bağlı "+" panelinde kalır.** Alttan açılan pencereler (parola üretici, onaylar, bilgi pencereleri), ⋮ menüleri ve üstten inen bildirim dolu yüzey olur: kartların rengi, aynı kenar ve gölge, aynı karartma ve hareketler. Neden: okunurluk (dördüncü telefon denemesinde buzlu kartlarda görülen sorunun aynısı), bulanıklık en pahalı çizim olduğu için daha akıcı açılış ve kaydırma, kartlarla tutarlılık.
2. **Kayıt ayrıntısında alanlar gruplanır.** Kullanıcı adı, parola, bağlı 2FA kodları, web adresleri ve uygulamalar tek kartta; klasör, özel alanlar ve notlar ikinci kartta. Satırlar arasında Ayarlar'daki gibi ince çizgi. Neden: kayıt tek parça okunur, ekran sakinleşir, daha az kaydırılır.

**Değişmeyenler (proje sahibinin seçtikleri ya da telefonda onayladıkları):** renkler ve turuncunun yeri, başlık yazı tipi, harfli daireler, kasa ve 2FA listelerindeki ayrı kartlar, form alanları, zemindeki kayan ışıklar, bütün hareketler, alt menünün ve "+" panelinin camı.

**Doğrulama:** Değişiklikler emülatörde önce/sonra ekran görüntüleriyle karşılaştırılır (emülatörün kendi kaydedicisi uygulamanın ekran koruması açıkken de görüntü alır); sonra telefon denemesi.

**Durum (2026-11-17):** İkisi de yapıldı.

- Açılan yüzeyler için temaya ayrı bir dolu renk (`raised`) eklendi: açık temada kart kremi, koyu temada karttan bir ton açık `#36363A`. Daha açık bir ton (`#3A3A3F`) ikincil yazıda 4,5:1 kontrastın altında kaldığı için seçilmedi; tema testi açılan yüzeyi de kontrast ölçümüne katıyor.
- Ayrıntı ekranında iki kart; parola geçmişi kendi kartında kalıyor. Eski "her alan kendi kartında" testi kaldırıldı, yerine kartların gruplandığını sınayan test geldi.
- Kılavuzdaki değişen ekranların görüntüleri (04-09, 12-15) ve F-Droid ekran görüntüleri bu tasarımla yeniden alındı. 01-03, 10 ve 11 değişmeyen ekranlar.

**Bağımsız gözden geçirme (tasarım PR'ı):** Kritik ya da önemli bulgu yok. Bulguları kullanıcıya etkisine göre yeniden derecelendirdim:

- *Düzeltildi:* Kayıt düzenlenip bir alan silinince, açılmış gizli değer bir sonraki gizli alana geçiyordu; o alan dokunmadan açık görünüyordu (bu PR'dan önce de vardı). Etiket ya da değer değişince alan yeniden gizleniyor; test önce kırmızı görüldü.
- *Düzeltildi:* QR taramada kameranın üstündeki açıklama da dolu yüzeyde (koyu temada %12 beyaz dolgu parlak görüntüde okunmayabilirdi).
- *Düzeltildi:* Testler pencere, menü ve bildirimin koyu temada `raised` rengini kullandığını da sınıyor; koyu temada `raised` kart renginden farklı olmalı.
- *Düzeltildi:* Bu yüzeyleri hâlâ "cam" diye anlatan yorumlar.
- *Bırakıldı (küçük):* Ayrıntı kartında iç içe iki kırpma katmanı (Ayarlar'daki grupla aynı yapı, görünüşe etkisi yok); boş grubun atlandığı ve geçmiş kartının ayrı olduğu için ayrı test yok; açık temada menü kartlarla aynı renk, kenar ve gölgeyle ayrılıyor; ayarlar yüklenirken bağlı 2FA satırı bir an boş kalabiliyor.

## Telefon denemesi 17 (2026-11-17, öğleden sonra)

Proje sahibinin notları ve kararlar:

1. **"Navbarda koyu temada yine ince bir beyaz çizgi çıkıyor, istemiyorum."** Çizgi, alt menünün camının tepesindeki 1 piksellik parlak şeritti (kartlardan telefon denemesi 6'da kaldırılmıştı). Şerit önce yalnızca koyu temada kaldırıldı; telefon denemesi 18'de açık temada da istenmedi ve tamamen kalktı. Camın üstten sönen yumuşak parıltısı kalıyor. Sekmeler ile "+" arasındaki dikey ayraç ayrı ve soluk gri, dokunulmadı.
2. **"Lisans konusuna iyi bakmanı istiyorum, sonra dava yemeyelim."** Lisanslar yeniden denetlendi; çakışma yok. Eksik olan KeyKey'in kendi telif ve "garanti yoktur" bildirimiydi, eklendi. Ayrıntılar ve sınırlar: [bağımlılıklar belgesi](bagimliliklar.md#lisans-denetimi-2026-11-17).
3. **"Ayarlardaki lisanslar ekranını da düzeltelim, çok karışık."** Flutter'ın hazır sayfasının yerine üç bölümlü kendi ekranımız: KeyKey'in lisansı, KeyKey'in kullandıkları (ne işe yaradıklarıyla), bütün paketler (baş harflere göre). [Ayrıntı](bagimliliklar.md#lisanslar-ekranı).
4. **"Tanıtım ekranında koşul onaylama da olsa iyi olur; verilerin gizliliği hakkında her şeyi açıklayalım."** [Kullanım koşulları](kosullar.md) eklendi. Kararlarım:
   - **Ne zaman:** Yeni kullanıcıya tanıtımdan sonra, kasa oluşturmaya ya da yedekten dönmeye geçerken; kasası olan kullanıcıya güncellemeden sonra kilit ekranından önce bir kez. Tanıtım onaysız izlenebilir.
   - **Nasıl:** Yedi kısa bölüm, sonunda "Okudum, anladım ve kabul ediyorum" kutusu; işaretlenmeden "Kabul et ve devam et" çalışmaz. Ayarlar → Hakkında'dan onaysız okunur.
   - **İçerik:** Yalnızca KeyKey'in gerçekte yaptığı (internet izni yok, Argon2id + XChaCha20-Poly1305, Keystore, 30 saniyelik pano); kullanıcının elinde olanlar (ana parola, kurtarma anahtarı, yedek, telefonun güvenliği); kodun büyük kısmının yapay zekâ asistanıyla yazıldığı ve bağımsız denetimden geçmediği; garanti olmadığı. Abartılı bir güvenlik vaadi yok: sorumluluk reddini güçlü kılan da açık ve doğru bilgilendirme.
   - **Saklama:** Kabul edilen sürüm numarası kasanın dışında şifresiz `terms` dosyasında ([güvenlik tasarımı](guvenlik-tasarimi.md#depolama)). Koşullar değişirse sürüm artar, herkese bir kez daha sorulur.
   - **Sınır:** Bu metinler hukuki riski azaltır ama ortadan kaldırmaz; ağır kusur ve kast için sorumluluk önceden kaldırılamaz. Hukukçu görüşü alınmadı.

**Bağımsız gözden geçirme (koşullar ve lisanslar):** Kritik bulgu yok. Etkisine göre derecelendirdim:

- *Düzeltildi (önemli):* Otomatik doldurma penceresi, koşullar hiç kabul edilmeden kasayı açabiliyordu (güncelleyip uygulamayı açmamış kullanıcı). Pencere artık "Önce KeyKey'i aç ve kullanım koşullarını kabul et" diyor.
- *Düzeltildi (önemli, doğruluk):* "Verilerin yalnızca bu telefondaki kasada durur" yedek ve dışa aktarmayla çelişiyordu; pano cümlesi klavyelerin pano geçmişini anmıyordu ([güvenlik tasarımı](guvenlik-tasarimi.md) bu korumayı "kısmen" sayıyor). İkisi de düzeltildi.
- *Düzeltildi:* Lisans metinleri yüklenemezse sonsuz bekleme yerine mesaj; ekran okuyucu için paket başlıkları; kabul dosyası yazılamazsa hiçbir hata dışarı çıkmıyor; koşul belgesinin sürüm testi gerçekten sürüm satırını arıyor; kurtarma, "kullanılamıyor" ve geri tuşu için testler; parmak izi dışı cihaz betiğinin ön koşulu (koşulların elle kabulü).
- *Kararım:* "Kasa kullanılamıyor" ekranından önce de koşullar soruluyor; zararsız ve kural basit kalıyor. Koşullar lisansın şartı değil, bir bildirim ve sorumluluk reddi (GPL-3.0 programı çalıştırmak için kabul istemez).
- *Bırakıldı (küçük):* Lisans kataloğu arayüz iş parçacığında kuruluyor (telefonda yavaşlarsa ayrı iş parçacığına taşınır); uzun lisans tek metin olarak çiziliyor; GPL sürümü ayrıca denetlenmiyor ve bozuk başlık tanıma iki kalıpla sınırlı (bugünkü 204 girdinin hepsi doğru); entegrasyon testleri kapıyı değil kasa ekranlarını sınıyor (kapı widget testlerinde).

## Telefon denemesi 18 (2026-11-17, akşamüstü)

Proje sahibi koşulları kabul etti ve yeni Lisanslar ekranını beğendi ("lisanslar ekranı güzel olmuş"). Tek not:

1. **"Navbardaki beyaz çizgiyi iki tema için de kaldır, beyaz temada da olmasın."** Alt menünün tepesindeki 1 piksellik parlak şerit açık temada da kaldırıldı; artık hiçbir cam yüzeyde yok. Camı cam gibi gösteren üstten sönen yumuşak parıltı, ince kenar ve gölge kalıyor. Sekmeler ile "+" arasındaki dikey ayraç soluk gri, beyaz değil; dokunulmadı. Güncel APK telefonda denendi; proje sahibi doğruladı: "çizgi gitmiş, iki temada da düzgün."

## Proje sahibinin kararına bırakılanlar

Bunlar ya güvenlik tasarımını değiştiriyor ya da büyük iş; sırayı ve kararı proje sahibi verir. Yol haritasının "1.0 sonrası" tablosuna yazıldı.

- **Gizli olmayan alanlarda normal klavye** (bu fazdaki 5. madde, uygulanmadı). Bütün metin kutuları bilerek `visiblePassword` klavyesi açıyor: `enableIMEPersonalizedLearning: false` yalnızca bir istek, birçok klavye bunu yok sayıyor; `visiblePassword` ise neredeyse her klavyede öneriyi ve öğrenmeyi gerçekten kapatıyor. Normal klavye büyük harf ve adres tuşları getirir ama kayıt adları, siteler ve klasörler (hangi bankayı, hangi siteyi kullandığın) klavyenin sözlüğüne ve bulut eşitlemesine girebilir. Gizlilik mi kolaylık mı, karar proje sahibinin.

- **Arka plan kilidinde bekleme süresi** (30 saniye, 1 dakika gibi; varsayılan "hemen"). Kullanıcıların en çok istediği şeylerden; ama telefon başkasının eline geçtiğinde kasanın açık kalabileceği bir pencere açar. Bu fazdaki 1. madde sürtünmenin çoğunu güvenlikten ödün vermeden giderir.
- **Seçilen klasöre otomatik şifreli yedek** (Drive ya da Syncthing klasörü olabilir). Çevrimdışı bir kasada en büyük gerçek risk veri kaybı. Yedeğin hangi anahtarla, ne zaman yazılacağı güvenlik tasarımında ayrı bir karar.
- **Yeni kurtarma anahtarı üretme** (kâğıt kaybolursa ya da dosya sızarsa). Kripto çekirdeğinde yeni bir işlem.
- **Güvenli not ve kart kayıtları**, **KeePass (`.kdbx`) içe aktarma**, **toplu seçim** (çoklu silme, klasöre taşıma).

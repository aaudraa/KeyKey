# Değişiklik günlüğü

KeyKey'deki önemli değişiklikler. Sürüm numarası kuralı [yayın belgesinde](docs/yayin.md#sürüm-numarası). `v1.0.0`'dan önceki sürümler fazların sonunu işaretler ve hata ayıklama anahtarıyla imzalıdır; kalıcı bir kurulum için kullanılmamalıdır.

## 1.2.0 (yayımlanmadı): Otomatik yedek

Faz 12 ([tasarım](docs/otomatik-yedek.md)).

### Eklenenler

- Otomatik yedek: Ayarlar → Yedek ve aktarım'dan bir klasör seçilince, kasa açıkken kayıtlar değiştikçe o klasöre şifreli bir yedek yazılıyor. Elle yedekle aynı biçim ve anahtar; her günün son yedeği en yeni 14 gün için tutuluyor, elle alınan yedeklere dokunulmuyor. İnternet ve depolama izni eklenmedi; KeyKey yalnızca seçilen klasör için izin alıyor.
- Klasöre erişilemezse ayarlarda ve yedek kartında uyarı; "Klasörü değiştir" ve "Şimdi yedekle".
- Ana parola değişince otomatik yedek hemen yeni parolayla yazılıyor.

### Değişenler

- Ayar kaydı sürüm 5 (otomatik yedeğin klasörü); sürüm 1-4 kayıtları okunmaya devam ediyor.
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

# Kartlar ve notlar için gezinme

**Durum:** Faz 17 tasarımı, 2026-11-20. **Görev:** [#153](https://github.com/aaudraa/KeyKey/issues/153). Plan: [gezinme-plani.md](gezinme-plani.md).

## Neden

1.4.0'da gelen kartlar ve güvenli notlar kasa listesinde parolalarla karışık duruyor; türler listenin üstündeki "Parolalar · Kartlar · Notlar" süzgeç çipleriyle ayrılıyor. Proje sahibi (2026-11-20): "navbara ekle, o kısımlar da üstte sekme niyetinde görünmesin, kötü görünüyor." Çipler sekme gibi görünüyor ama sekme gibi davranmıyor: seçim kalıcı değil, arama bütün türlerde, boş liste ve menü türe göre değişmiyor.

## Hedefler

- Kartlar ve notlar alttaki cam menüde kendi sekmeleriyle: **Parolalar · Kartlar · Notlar · 2FA · Ayarlar** ve en uçta "+".
- Her sekmenin kendi listesi: arama, favori ve klasör çipleri, sıralama, boş liste ve çöp kutusu o türe ait.
- Kasa listesinin üstündeki tür çipleri kalkar.
- Görünüm KeyKey'in cam diliyle aynı kalır; yeni bir bileşen dili gelmez.

## Hedef olmayanlar

- Kart ve not ayrıntı ve düzenleme ekranlarının içeriği değişmez (yalnızca adresleri).
- Kayıt modeli, şifreleme, yedek biçimi, otomatik doldurma değişmez.
- Bütün türlerde ortak arama yok (aşağıda).

## Karşı hedefler

- Sekmelerin sırf sığsın diye 48 dp'lik dokunma alanının altına inmesi.
- Büyük yazıda ya da dar ekranda menünün taşması.
- Bir kart ya da notun yanlış sekmede açılması, kaydettikten sonra başka sekmeye dönülmesi.

## Yaklaşımlar

| Yaklaşım | Artı | Eksi |
|---|---|---|
| **1. Beş sekme, mevcut cam şerit** (seçilen) | Proje sahibinin istediği; menü bileşeni zaten "sığmazsa yalnızca simge" kuralını biliyor; tek liste ekranı türe göre üç kez kullanılır | Telefonda seçili sekmenin adı sığmaz, sekmeler yalnızca simgeyle görünür |
| 2. Dört sekme, Ayarlar üst çubuğa | Seçili sekmenin adı çoğu telefonda sığar | Ayarlar'ın yeri değişir; istenmeyen bir değişiklik; her ekranda ayrı düğme |
| 3. Simgenin altında küçük adlarla yeni şerit | Bütün adlar her zaman görünür | Menünün bütün görünüşü değişir; İngilizce adlar 60 dp'ye zor sığar; "+" ile birlikte kalabalık |

Seçilen 1. Ekranın başlığı zaten sekmenin adını büyük yazıyor; seçili sekme kapsülle işaretli. Geniş ekranda (tablet, yatay) seçili sekmenin adı yine kapsülde görünür.

## Tasarım

### Menü

- Sekmeler: Parolalar (`key_outlined` / `key`), Kartlar (`credit_card_outlined` / `credit_card`), Notlar (`sticky_note_2_outlined` / `sticky_note_2`), 2FA, Ayarlar. Simgeler "+" kutusundaki ve listelerdeki simgelerle aynı aileden.
- İlk sekmenin adı "Kasa" yerine "Parolalar": artık yalnızca parolaları tutuyor.
- Ekran okuyucu: "Kartlar, sekme 2/5".
- "+" kutusu aynı: Kart seçilince Kartlar sekmesinde yeni kart formu açılır, kaydedince kart listesine dönülür.

### Listeler

- Tek liste ekranı (`VaultScreen`) türe göre üç kez kurulur. Başlık sekmenin adı.
- Arama yalnızca o türde; arama kutusunun etiketi o türün sayısını gösterir ("12 kartta ara").
- Favori ve klasör çipleri yalnızca o türün kayıtlarından.
- Sıralama (ada göre, son değişene göre) üç sekmede aynı ayarı kullanır.
- Menü: sıralama, çöp kutusu; parola raporu yalnızca Parolalar'da.
- Yedek hatırlatıcısı ve okunamayan kayıt uyarısı yalnızca Parolalar'da (açılıştaki ekran).
- Boş liste: Parolalar'da bugünkü gibi içe aktarma ve geri yükleme kısayolları; Kartlar ve Notlar'da "+" ile eklemeyi anlatan kısa metin.

### Çöp kutusu

Her sekmenin çöp kutusu yalnızca o türü gösterir; "tümünü geri al" ve "çöpü boşalt" da yalnızca o türe dokunur. 30 günlük kendiliğinden silme değişmez.

### Adresler

| Ekran | Eski | Yeni |
|---|---|---|
| Kart listesi | `/kasa` (çiple) | `/kartlar` |
| Kart ayrıntısı, düzenleme, yeni | `/kasa/kart/:id`, `…/duzenle`, `/kasa/yeni-kart` | `/kartlar/:id`, `/kartlar/:id/duzenle`, `/kartlar/yeni` |
| Not listesi ve ekranları | `/kasa/not/…`, `/kasa/yeni-not` | `/notlar`, `/notlar/:id`, `/notlar/:id/duzenle`, `/notlar/yeni` |
| Çöp kutuları | `/kasa/cop` (hepsi) | `/kasa/cop`, `/kartlar/cop`, `/notlar/cop` |

Derin bağlantı kapalı olduğu için adresler dışarıdan kullanılmıyor; kilitten sonra dönülecek yer bellekte tutulduğu için güncellemeden etkilenmez.

### Tanıtım

"Ne nerede" sayfası menünün kopyasını gösteriyor: beş sekme ve "+", altında altı satır (Parolalar, Kartlar, Notlar, 2FA, Ayarlar, Ekle).

### Ortak arama

Bugün kasa araması parola, kart ve notları birlikte arıyor. Sekmeler ayrılınca her sekme kendi türünde arar. Ortak arama bırakıldı: sonuç listesi yine türlere bölünmek zorunda kalırdı ve üst çubuk her sekmede aynı düğmeyi taşırdı. İhtiyaç olursa ayrı bir iş.

## Testler

- Menü: beş sekme, sırası, ekran okuyucu adları ("sekme 2/5"), dar ekranda ve %200 yazıda taşma yok, dokunma alanları 48 dp.
- Listeler: her sekme yalnızca kendi türünü gösterir; arama, favori ve klasör çipleri türe göre; tür çipleri yok; parola raporu yalnızca Parolalar'da; boş liste metinleri.
- Çöp kutusu türe göre; "tümünü geri al" başka türe dokunmaz.
- "+" kutusundan kart ve not doğru sekmede açılır, kaydedince o sekmenin listesine dönülür.
- Erişilebilirlik testinde yeni ekranlar (açık/koyu, %200 yazı).
- Cihaz: Android 17 ve 11 emülatörlerinde bütün entegrasyon testleri; kart ve not akışı yeni sekmelerden.

## Belgeler

Kılavuz (Kartlar ve güvenli notlar), cam tasarım belgesi (menü), değişiklik günlüğü 1.6.0, yol haritası. Sürüm Faz 16 ile birlikte `1.6.0+10` olarak yayımlanır.

## Uygulayana kalanlar

Boş liste metinlerinin son hali, simge ağırlıkları, dosya içi düzen.

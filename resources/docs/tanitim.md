# Tanıtım ekranları

Durum: proje sahibi 2026-11-16'da onayladı (önerilen eklemeler dahil). 1.0'dan önce, `faz/9-yayin` dalında.

## Neden

Uygulamayı ilk kez açan kişi doğrudan "Kasa oluştur" ekranına düşüyor; uygulamanın ne olduğunu, nerede ne bulunduğunu ve başka uygulamalardan geçilebildiğini görmüyor. Proje sahibi ilk açılışta hareketli, uygulamanın kendi simgelerini tanıtan ("bu burada, şu şurada") bir tanıtım istiyor; başka uygulamalardan aktarma da görselleştirilmeli.

## Ne yapılacak

Kasa kurulmamışken uygulama açılınca, kasa oluşturma ekranından önce altı sayfalık bir tanıtım gelir. Sayfalar sağa kaydırılarak ya da **İleri** ile geçilir; altta sayfa noktaları, sağ üstte **Atla** vardır.

1. **Hoş geldin:** K logosu turuncu çizilerek belirir, dolar. "KeyKey" ve "Parolaların ve 2FA kodların, yalnızca bu telefonda."
2. **Verilerin sende:** telefon simgesi; üstünden bir bulut kayıp gider ve üstü çizilir. "İnternet izni yok, hesap yok, sunucu yok."
3. **Nerede ne var:** alttaki menünün aynısı çizilir, simgeleri sırayla parlar ve yanlarında ne oldukları yazar: kilit → Kasa (parolaların), kalkan → 2FA (doğrulama kodların), dişli → Ayarlar (yedek, doldurma, tema), turuncu + → yeni parola ya da 2FA ekle.
4. **Otomatik doldurma:** bir giriş kutusunun altında "KeyKey ile doldur" önerisi belirir, kutular dolar. "Uygulamalarda ve Chrome'da tek dokunuşla."
5. **Geçiş:** KeePassXC logosu ve uygulama adlarıyla rozetler süzülerek K logosuna akar. "Bitwarden, Chrome, Firefox, KeePassXC, Google Authenticator, Aegis ve 2FAS'tan taşı."
6. **Yedek ve başla:** "Yedeğini sen alırsın; telefon kaybolursa kurtaran o." Ana düğme **Kasamı oluştur**.

**Atla** ve **Kasamı oluştur** kasa oluşturma ekranına götürür; "Yedekten geri yükle" orada kalır.

**Tekrar izlemek için:** Ayarlar → Hakkında → **Tanıtımı yeniden göster**. Bu yolla açılan tanıtımda son düğme **Bitti** olur ve Ayarlar'a döner. Tanıtım kendiliğinden yalnızca kasa yokken çıkar; kasa kurulunca bir daha çıkmaz. Bu yüzden hiçbir şey saklanmaz.

Telefonda "Animasyonları kaldır" açıksa hareketler anında biter, metinler ve çizimler son halleriyle görünür.

## Logolar

Gerçek logo olarak yalnızca **KeePassXC**'ninki kullanılır: `keepassxc.svg` LGPL-2 lisanslı (2016, Lorenzo Stella; KeePassXC'nin `COPYING` dosyası). Lisans notu uygulamanın lisanslar sayfasına eklenir. Diğerleri yalnızca adlarıyla, yazı rozeti olarak geçer:

| Uygulama | Neden logo yok |
|---|---|
| Aegis | Kod GPL-3.0, logonun lisansı belirtilmemiş. |
| 2FAS | Görseller açık kaynak projenin parçası değil. |
| Bitwarden | Lisans logolar üzerinde hak vermiyor. |
| Firefox, Chrome, Google | Logo kullanımı yazılı izin istiyor; adı yazıyla anmak serbest. |

Bu sayede F-Droid'in "özgür olmayan görsel" uyarısı gelmez ve [gizlilik bildirimindeki](gizlilik.md#mağaza-formları) F-Droid yanıtı geçerli kalır.

## Yaklaşımlar

1. **Tamamen gerçek logolar:** en tanıdık, ama marka ve lisans sorunu, F-Droid uyarısı. Seçilmedi.
2. **Baş harfli rozetler:** sorunsuz, ama hiçbir gerçek logo yok. Seçilmedi.
3. **Serbest olan gerçek logo + ad rozetleri (seçilen):** proje sahibinin tercihi; hepsini göstermek gerekmiyor, amaç aktarmanın mümkün olduğunu göstermek.

## Kurucuya kalanlar

Sayfaların çizim ayrıntıları, hareket süreleri (mevcut `KkMotion` değerleriyle), metinlerin son hali ve İngilizce karşılıkları.

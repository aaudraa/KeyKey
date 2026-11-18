# Yeni kurtarma anahtarı

Faz 13'ün tasarımı. Kararları, proje sahibinin verdiği tam yetkiyle (2026-11-18) uygulayan verdi; gerekçeler aşağıda.

## Neden

Kurtarma anahtarı kasa kurulurken bir kez gösterilir ve bir daha değiştirilemez. Kâğıt kaybolursa ya da anahtarın kaydedildiği dosya sızarsa, onu bulan biri yalnızca kasa dosyasına (ya da bir yedeğe) ulaşarak kasayı açabilir. Bugün tek çare yeni bir kasa kurup kayıtları taşımak. Ana parola değiştirilebildiği halde kurtarma anahtarının değiştirilememesi, ikisinin aynı değerde olduğu düşünülünce bir boşluk.

## Hedefler

- Kasa açıkken, ana parolayı doğrulayarak yeni bir kurtarma anahtarı üretmek.
- Eski anahtarın bu kasayı artık açmaması.
- Yeni anahtarın kurulumdaki gibi gösterilmesi, kopyalanabilmesi, dosyaya kaydedilebilmesi ve geri yazılarak doğrulanması.
- Yarıda bırakılan işlemin hiçbir şeyi değiştirmemesi.

## Hedef olmayanlar

- Kasa anahtarını döndürmek ve kayıtları yeniden şifrelemek ([bilinen sınır 5](guvenlik-tasarimi.md#bilinen-sınırlar) olduğu gibi kalır).
- Eski yedekleri geçersiz kılmak: yedek dosyası kendi üst bilgisini taşır, uygulama onlara dokunamaz.
- Eski anahtarı göstermek ya da saklamak.

## Karşı hedefler

- Kilidi açık telefonu eline alan birinin, ana parolayı bilmeden kalıcı bir anahtar alabilmesi.
- Kullanıcının yeni anahtarı not etmeden eskisinin geçersiz olması.
- Ana parola yuvasının ya da parmak izi yuvasının bozulması.

## Yaklaşımlar

1. **Önce göster, doğrulayınca yaz (seçilen).** Yeni yuva bellekte hazırlanır. Kullanıcı anahtarı geri yazınca yuva gerçekten açılarak doğrulanır, ancak o zaman üst bilgi diske yazılır. Kurulumdaki akışla aynı; yarıda bırakmak güvenli.
2. **Hemen yaz, sonra göster.** Kısa, ama kullanıcı anahtarı not etmeden ekranı kapatırsa kasa, kimsenin bilmediği bir kurtarma anahtarıyla kalır. Karşı hedefe aykırı.
3. **Kasa anahtarını da döndür.** Eski yedekler ve kopyalanmış eski kasa dosyaları da bu kasayla ilgisiz olur, ama bütün kayıtların yeniden şifrelenmesi gerekir; yarıda kesilmeye dayanıklı yapmak büyük bir iş. Ayrı bir faz olabilir.

## Tasarım

### Akış

Ayarlar → Güvenlik → **Yeni kurtarma anahtarı**. Üç adım:

1. **Açıklama ve ana parola.** Eski anahtarın bu kasayı artık açmayacağı ve eski yedeklerin eski anahtarla açılmaya devam edeceği söylenir. Kullanıcı ana parolasını girer.
2. **Yeni anahtar.** Kurulumdaki ekranla aynı: uyarı, anahtar, "Kopyala" (güvenli pano, 30 sn) ve "Dosyaya kaydet".
3. **Doğrulama.** Kullanıcı anahtarı yazar ya da kaydettiği dosyadan okutur. Yuva açılırsa üst bilgi yazılır. Ardından eski yedeklerin eski anahtarla açıldığını söyleyen not çıkar ve oradan yeni bir yedek alınabilir; otomatik yedek açıksa yeni üst bilgiyle hemen yazılır.

### Ana parola neden isteniyor

Yeni anahtar, kasayı ana parolasız açan kalıcı bir sırdır. Kilidi açık telefonu ele geçiren biri ana parolayı bilmeden böyle bir sır alamamalı. Parola denetimi kilit ekranıyla aynı yoldan geçer: hatalı deneme sayacı ve bekleme burada da işler. Parmak izi yeterli sayılmaz, çünkü parola değiştirmede de sayılmıyor.

### Kripto

- Yeni kurtarma anahtarı rastgele 32 bayttır; metin biçimi ve KEK türetmesi değişmez ([Kurtarma anahtarı](guvenlik-tasarimi.md#kurtarma-anahtarı)).
- Yalnızca `recovery` yuvası yeniden yazılır: yeni KEK ile, yeni nonce'la, aynı AD ile (`keykey/v1/wrap`, `vaultId`, `recovery`). `vaultId`, KDF parametreleri, tuz, parola yuvası ve parmak izi yuvası değişmez.
- Diske yazılacak üst bilgi, doğrulama anında oturumdaki **güncel** üst bilgiden kurulur, yalnızca kurtarma yuvası değiştirilir. Arada parola değişmiş olsa bile yeni parola yuvası geri alınmaz.
- Üst bilgi, parola değiştirmedeki gibi tek bir yazmayla güncellenir.
- Kripto çekirdeğine yeni bir işlem eklenir, biçim değişmez: eski sürümler yeni üst bilgiyi okur.

### Yarıda kalma

- Adım 1 ya da 2'de vazgeçilirse ya da kasa kilitlenirse hiçbir şey yazılmaz.
- Doğrulama sürerken kasa kilitlenirse yazma tamamlanır ya da hiç başlamaz; kilit ekranı diskteki üst bilgiyle açılır.
- Anahtar metni Dart dizesidir, silinemez ([bilinen sınır 7](guvenlik-tasarimi.md#bilinen-sınırlar)); ekrandan çıkınca bırakılır.

### Dosya seçici

Kasa açıkken anahtarı dosyaya kaydetmek ve dosyadan okumak, yedek almadaki gibi dış etkinlik kapısından geçer: seçici açıkken arka plan kilidi çalışmaz.

## Güvenlik

- Eski kurtarma anahtarı bu cihazdaki kasayı açmaz. Eski yedekler ve kasa dosyasının eski kopyaları eski anahtarla açılmaya devam eder; kullanıcıya söylenir, eskilerini silmesi önerilir. Bilinen sınır 5'e eklenir.
- Ana parola ve hatalı deneme beklemesi kilit ekranındakiyle aynı.
- Kasa anahtarı değişmediği için 2FA anahtarı, kayıt anahtarı ve parmak izi yuvası etkilenmez.

## Denemeler

- **Kripto birim testleri:** yeni anahtar açar, eskisi açmaz, parola hâlâ açar, değişmeyen alanlar aynı kalır, iki üretim farklı anahtar verir.
- **Servis:** yanlış parola hiçbir şey değiştirmez ve sayacı artırır; yanlış yazılan anahtar yazmaz; doğrulama üst bilgiyi yazar ve oturumu günceller; arada parola değişirse yeni parola yuvası korunur.
- **Arayüz:** üç adım, vazgeçme, yanlış parola, yanlış anahtar, kilit.
- **Cihaz:** gerçek libsodium ile yenileme ve yeni anahtarla açma (`integration_test/crypto_test.dart`).

## Uygulayana kalanlar

Metinler, simge, ekranın görsel düzeni ve ortak adım bileşeninin sınırları.

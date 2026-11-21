# İnternet ve sızıntı kontrolü

**Faz:** 16 · **Görev:** [#152](https://github.com/aaudraa/KeyKey/issues/152) · **Sürüm:** 1.6.0 · **Tarih:** 2026-11-20

KeyKey 1.5.0'a kadar internet izni olmadan çalıştı. Proje sahibi 2026-11-19'da internete açılmaya karar verdi ([yol haritası, İnternet](../yol-haritasi.md#temel-kararlar)). Bu faz kararı uygular: `INTERNET` izni ilk internet özelliğiyle birlikte gelir, ve o özellik parola raporundaki sızıntı kontrolüdür. Proje sahibi bu fazda soru sorulmasını istemedi; aşağıdaki seçimler benim, gerekçeleriyle.

## Neden

- F-Droid başvurusu "benzersiz özellik yok" gerekçesiyle reddedildi; proje sahibi çevrimdışı nişin dışına çıkıp senkron ve sızıntı kontrolü gibi özellikleri istiyor.
- Parola raporu bugün zayıf ve tekrar eden parolaları gösteriyor, ama güçlü görünen bir parola bir sızıntıda ele geçmişse onu bilemiyor. Saldırganlar önce sızıntı listelerini dener; sızmış bir parola ne kadar uzun olursa olsun zayıftır.
- Sızıntı kontrolü küçük ve kendi içinde kapalı bir iş. Ağ altyapısını (izin, denetimler, metinler) senkrondan (Faz 19) önce küçük bir özellikle sınamış oluruz.

## Hedefler

- Parola raporunda **Sızıntı kontrolü**: kullanıcı düğmeye basınca kasadaki parolalar [Have I Been Pwned](https://haveibeenpwned.com/Passwords)'ın Pwned Passwords verisinde aranır, sızıntılarda görülenler kaç kez görüldükleriyle listelenir.
- Parolanın kendisi hiçbir zaman gönderilmez: yalnızca SHA-1 özetinin ilk 5 karakteri gider, karşılaştırma telefonda yapılır (k-anonimlik).
- `INTERNET` izni, uygulama içi metinler, kullanım koşulları, gizlilik bildirimi, README, mağaza açıklamaları ve güvenlik belgeleri aynı sürümde değişir; arada yanlış bir metin kalmaz.
- Koddaki tek ağ çağrısı tek bir dosyada durur; başka bir yerde ağ kodu olmadığını bir test denetler.

## Hedef olmayanlar

- Arka planda ya da kendiliğinden denetim (kasa açılınca, kayıt kaydedilince). Ağa yalnızca kullanıcının dokunuşuyla çıkılır.
- Kayıt düzenleme ekranında tek parola denetimi. Rapor bütün kasayı tek dokunuşla denetliyor; düzenleme ekranına ikinci bir düğme sonra eklenebilir.
- E-posta adresinin sızıntılarda aranması (HIBP'nin hesap API'si). Anahtar ister, ücretlidir ve e-postayı açıkça gönderir.
- Sonuçların saklanması. Sonuç bellekte durur; ekran kapanınca ya da kasa kilitlenince gider.
- Senkron ve başka internet özellikleri (Faz 19 ve sonrası).

## Karşı hedefler

Teknik olarak çalışsa bile başarısızlık sayılacak durumlar:

- Parolanın, tam özetinin ya da kullanıcı adının, sitenin, kayıt adının cihazdan çıkması.
- Kullanıcı dokunmadan ağa çıkılması; şifresiz (`http`) bağlantı.
- İnternet izninin başka bir kod parçasına (bir kütüphaneye, otomatik doldurmaya) sessizce yol açması.
- Uygulamada "internet izni yok" diyen bir metnin kalması ya da tersine, kullanıcı ne gittiğini bilmeden düğmeye basması.
- Sızıntı sonucunun kasaya, diske ya da sistem kaydına yazılması.

## Yaklaşımlar

### Denetimin zamanı

| Yaklaşım | Artı | Eksi |
|---|---|---|
| **1. Raporda düğme, sonuç bellekte** (seçilen) | Ağ yalnızca kullanıcı isteyince; ne gittiği düğmenin hemen üstünde yazıyor; ayar ve kayıt biçimi değişmiyor | Sonuç her açılışta yeniden istenir |
| 2. Ayarlarda açılan, kasa açılınca kendiliğinden denetim | Kullanıcı unutsa da haber verir | Kullanıcı farkında olmadan ağa çıkılır; her açılışta trafik; ayar biçimi değişir |
| 3. HIBP verisinin tamamını indirip çevrimdışı arama | Hiçbir önek gitmez | Veri onlarca GB; Bloom filtresiyle küçültülse de yüzlerce MB ve güncellemesi ayrı bir iş |

Birincisi seçildi: roadmap'teki "her internet özelliği kullanıcı açınca çalışır, varsayılan kapalıdır" kuralına en doğrudan uyan o. Ayrı bir "sızıntı kontrolü açık" ayarı yok; düğmeye basmak açmaktır ve açıklama her seferinde düğmenin üstündedir.

### Ağ kodu

| Yaklaşım | Artı | Eksi |
|---|---|---|
| **1. Dart'ın kendi `HttpClient`'ı** (seçilen) | Yeni bağımlılık yok; F-Droid derlemesi ve lisans listesi değişmez | Daha alçak düzey bir arayüz |
| 2. `package:http` | Daha rahat arayüz | Yeni bağımlılık, kazancı küçük |
| 3. Kotlin'de OkHttp, Pigeon köprüsüyle | Android'in ağ güvenliği yapılandırmasının tamamı | Yeni yerel bağımlılık ve köprü kodu |

### Sertifika sabitleme

Yapılmıyor. Pwned Passwords Cloudflare'in arkasında; sertifikaları ve ara sertifikaları değişir, sabitlenen bir anahtar değişince denetim kullanıcıda kırılır. Giden veri zaten parolayı ele vermeyecek biçimde (k-anonimlik); bağlantıyı dinleyen biri en çok hangi öneklerin sorulduğunu ve dönen listeleri görür. Sistemin güvendiği sertifika yetkilileri kullanılır; kullanıcının eklediği sertifikalara (Android 7'den beri varsayılan) güvenilmez.

## Tasarım

### Sızıntı kontrolü nasıl çalışır

1. Çöp kutusunda olmayan, parolası boş olmayan kayıtların parolalarının SHA-1 özeti alınır (UTF-8 bayt, büyük harfli onaltılık, 40 karakter).
2. Özetler ilk 5 karaktere (önek) göre gruplanır. Aynı parola ya da aynı önek bir kez sorulur.
3. Her önek için `GET https://api.pwnedpasswords.com/range/{önek}` gönderilir, `Add-Padding: true` başlığıyla. Önekler karışık sırayla, aynı anda en çok 4 istek olarak gider; sıra kasadaki kayıt sırasını ele vermez.
4. Yanıt `SONEK:SAYI` satırlarıdır (35 karakterlik sonek). Dolgu satırlarının sayısı 0'dır ve atılır. Yanıtta sayısı 0'dan büyük bir sonek kaydın özetinin sonekiyle tutarsa parola o kadar kez görülmüştür.
5. Sonuç: her özet için görülme sayısı. Ekran her kaydın güncel parolasının özetine bakar; parolası denetimden sonra değişen kayıt listeden kendiliğinden düşer (yeni parolası denetlenmemiştir).

Have I Been Pwned bir istekten yalnızca öneki ve gönderenin IP adresini görür. Önek, dünyadaki bütün olası parolaları yaklaşık bir milyonda bire böler; HIBP'nin verisinde her önekte 800'den fazla sonek var, dolgu yanıt boyutunu da gizler.

### Ağ istemcisi

`lib/core/network/pwned_passwords_client.dart`, KeyKey'in tek ağ kodu:

- Yalnızca `https://api.pwnedpasswords.com/range/` adresine gider. Öneki kendisi denetler: tam 5 karakter, `0-9A-F`; uymazsa ağa hiç çıkmadan hata verir. Böylece bu dosyadan önek dışında bir şey gitmesi kodun kendisiyle olanaksızdır.
- Yönlendirmeleri izlemez (yanıt 200 değilse hata). Çerez tutmaz. `User-Agent: KeyKey` (sürüm ve cihaz bilgisi yok).
- Zaman sınırları: bağlantı 10 saniye, bütün istek 30 saniye. Yanıt en çok 1 MiB okunur (gerçek yanıt yaklaşık 30-40 KB).
- Yanıtın her boş olmayan satırı `^[0-9A-F]{35}:[0-9]+$` olmalı; biri uymazsa yanıtın tamamı geçersizdir.
- Testler için istemci başka bir temel adresle kurulabilir (yalnızca testlerde kullanılır, uygulamada sabit).

**Ağ denetimi testi.** Bir birim testi `lib/` altındaki bütün Dart dosyalarını ve `android/app/src/main/` altındaki Kotlin dosyalarını tarar. `HttpClient`, `Socket`, `WebSocket`, `HttpServer`, `package:http`, `HttpURLConnection`, `java.net.URL`, `okhttp` gibi ağ kodları yalnızca istemci dosyasında bulunabilir. Yeni bir ağ kodu eklenirse test kırılır ve bilinçli bir karar ister. Bağımlılıkların hiçbiri kendi başına ağa çıkmıyor (QR okuyucu zxing, Google'ın ML Kit'i değil); [bağımlılıklar belgesine](bagimliliklar.md) yazılır.

### Ekran

Parola raporunun en üstünde, bilgi metninin altında bir cam kart:

```
┌───────────────────────────────────────────┐
│ Sızıntı kontrolü                          │
│ Parolaların veri sızıntılarında görülüp   │
│ görülmediğini Have I Been Pwned'a sorar.  │
│ Parolanın kendisi gönderilmez: yalnızca   │
│ özetinin ilk 5 karakteri gider, karşılaş- │
│ tırma bu telefonda yapılır. Have I Been   │
│ Pwned IP adresini görür.                  │
│ Veri: Have I Been Pwned (CC BY 4.0)  ↗    │
│                    [ İnternetten denetle ]│
└───────────────────────────────────────────┘
```

- **Denetlenirken:** ilerleme çubuğu ve "12 / 40 önek". Ekrandan çıkınca ya da kasa kilitlenince denetim bırakılır, yeni istek başlamaz.
- **Hata:** "Denetlenemedi. İnternet bağlantını kontrol et." ve **Yeniden dene**. Bir önek bir kez yeniden denenir; yine olmazsa denetimin tamamı hatadır, yarım sonuç gösterilmez (yarım "temiz" sonuç yanıltır).
- **Sızıntı yok:** onay simgesi ve "Sızıntılarda görülen parola yok." ve **Yeniden denetle**.
- **Sızıntı var:** "Sızıntılarda görülen parolalar (N)" başlığı ve kayıtlar; her satırda "Sızıntılarda 1.234 kez görüldü" (sayı dile göre biçimlenir). En çok görülen önce, eşitse ada göre. Kayda dokununca düzenleme ekranı açılır, raporun diğer bölümleri gibi. Altında: "Bu parolalar saldırganların denediği listelerde. Hepsini değiştir; aynı parolayı kullandığın başka yerler varsa onları da."
- Atıf bağlantısı (`haveibeenpwned.com/Passwords`) tarayıcıda açılır; KeyKey arka plana geçtiği için kasa kilitlenir, bu da her bağlantıda olduğu gibi.
- Kasada parola yoksa kart açıklamayla birlikte durur ama düğme kapalıdır.

Raporun bilgi metni değişir: zayıf ve tekrar eden parolaların telefonda hesaplandığını, sızıntı kontrolünün ise yalnızca düğmeyle internete çıktığını söyler.

### Durum

`breachCheckProvider` (Riverpod, ekranla yaşar): boşta, denetleniyor (yapılan, toplam), bitti (özet → sayı ve denetlenen özetler), hata. Kasa kilitlenince (kayıt listesi kapanınca) sıfırlanır. Sonuç kasaya, ayarlara, diske ve kayda yazılmaz.

### Android

- Manifest: `android.permission.INTERNET`. `ACCESS_NETWORK_STATE` istenmez; bağlantı yoksa istek hata verir.
- Uygulamada `android:usesCleartextTraffic="false"` ve `res/xml/network_security_config.xml`: şifresiz trafik kapalı, yalnızca sistem sertifika yetkilileri. Bu ayarlar platform (Kotlin/Java) kodunu korur.
- **Uygulama sırasında bulundu:** Flutter (3.47) Android'in bu kuralını Dart'ın `HttpClient`'ına uygulamıyor; motor `domainNetworkPolicy` değerini boş geçiyor ve emülatörde `http://` isteği reddedilmedi. Bu yüzden https'i istemci kendisi zorlar: `PwnedPasswordsClient` https dışı adresi kurulurken reddeder (yalnızca bu cihazdaki test sunucusuna, `127.0.0.1`/`localhost`/`::1`, şifresiz bağlanılabilir). Adres zaten sabit ve yönlendirme izlenmediği için https'ten http'ye düşülemez.
- `check-release-apk.sh`: `INTERNET` izin verilenler listesine gerekçesiyle eklenir; manifestte şifresiz trafiğin kapalı olduğu ve ağ güvenliği yapılandırmasının bağlı olduğu denetlenir.
- Otomatik doldurma aynı uygulamada çalışır ama ağ koduna dokunmaz; ağ denetimi testi bunu da kapsar.

### Metinler

- **Kullanım koşulları sürüm 2.** "Verilerin bu telefonda" maddesi: hesap ve sunucu yok; KeyKey internete yalnızca senin başlattığın denetimler için çıkar, bugün tek denetim sızıntı kontrolü ve parolanın kendisi gitmez. `currentTermsVersion` 2 olur; bütün kullanıcılara yeni metin bir kez sorulur (koşullar belgesinin kendi kuralı).
- **Tanıtım:** "İnternet izni yok, hesap yok, sunucu yok" metni yerine "Hesap yok, sunucu yok. Kasan bu telefonda şifreli durur. İnternete yalnızca senin başlattığın denetimler çıkar; parolaların gitmez."
- **Yedek ve otomatik yedek:** "KeyKey internete çıkmadığı için" gibi gerekçeler "sunucusu olmadığı için" olur; "KeyKey'in kendisi internete çıkmaz" cümleleri yedekleme bağlamına daraltılır.
- **2FA saat yardımı:** "KeyKey saati internetten almaz."
- **Gizlilik bildirimi** (TR/EN): internet izninin ne için olduğu, ne gittiği (5 karakterlik önek), kime gittiği (Have I Been Pwned, Cloudflare üzerinden) ve karşı tarafın ne gördüğü (IP adresi, önek, zaman). Mağaza formu yanıtları ve F-Droid anti-özelliği güncellenir.
- **README ve mağaza açıklamaları:** "İnternete çıkmaz" sözü kalkar, yerine "Hesap yok, sunucu yok" ve isteğe bağlı sızıntı kontrolü.
- **F-Droid tarifi:** `NonFreeNet` anti-özelliği (Have I Been Pwned'ın sunucu yazılımı özgür değil).

### Testler

- İstemci: yerel bir test sunucusuna karşı yol (`/range/5BAA6`), başlıklar (`Add-Padding`, `User-Agent`), yönlendirme ve 200 dışı yanıt hatası, büyük yanıt sınırı, geçersiz önekte ağa hiç çıkmama.
- Denetim: bilinen özet (`password` → `5BAA6` + `1E4C9…FD8`), dolgu satırlarının atılması, geçersiz satırın hatası, aynı parolanın bir kez sorulması, çöp ve boş parolanın atlanması, eşzamanlılık sınırı, bir kez yeniden deneme, hata, iptal.
- Ekran: açıklama ve düğme, sonuç listesi ve sayılar, temiz sonuç, hata ve yeniden dene, parolası değişen kaydın düşmesi, kilitte sıfırlanma, erişilebilirlik.
- Ağ denetimi testi; koşullar sürümü 2.
- Entegrasyon testi (emülatörde, gerçek API, sistem sertifikalarıyla): `password` sızmış çıkar, rastgele uzun bir parola çıkmaz. https dışı adresin reddi birim testindedir (yukarıdaki bulgu).
- Cihaz: Android 17 ve 11'de raporda gerçek denetim; kayıt taraması (deneme parolaları, özetler ve önekler kayıtta olmamalı).

### Belgeler

Güvenlik tasarımı (tehdit modeli, "Ağ" bölümü, bilinen sınırlar), İngilizce özet, denetim (MASVS-NETWORK artık kapsamda), gizlilik bildirimi, koşullar, kılavuz, bağımlılıklar, F-Droid belgesi, değişiklik günlüğü, mağaza metinleri, yol haritası. Sürüm `1.6.0+10`.

## Bilinen sınırlar

- Have I Been Pwned gönderenin IP adresini, sorulan önekleri ve zamanı görür. Bir IP'den gelen önek kümesi o kasanın parmak izi gibi kullanılabilir; tek başına parolayı ele vermez. Sızmamış, rastgele üretilmiş bir parolanın 5 karakterlik öneki 20 bit bilgi verir ve geriye 140 bit kalır. Zayıf bir parolanın öneki ise bir sözlükle aday listesini daraltır; zayıf parola zaten raporun diğer bölümünde.
- Sonuç Have I Been Pwned'ın verisinin bildiği kadardır: "sızıntıda görülmedi" "güvenli" demek değildir.
- Dart'ta dizeler bellekten silinemez; özetler, parolaların kendisi gibi, kasa açıkken bellekte durur ([Bellek](guvenlik-tasarimi.md#bellek)).

## Uygulayana kalanlar

Metinlerin son hali, ekran yerleşiminin ayrıntıları, sınıf ve dosya adları (istemci dosyası dışında), eşzamanlılık ve zaman sınırlarının küçük ayarları.

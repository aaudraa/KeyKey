# Uygulama ve site eşleştirme

Faz 25'in tasarımı. Hedef sürüm `1.10.0`. Takip: [#178](https://github.com/aaudraa/KeyKey/issues/178).

Proje sahibi 2026-11-22'de bunun internetle yeniden ele alınmasını istedi ("o an engelimiz vardı artık yok"; "hangi sistem daha iyi ve sağlamsa"). Aşağıdaki seçimler benim; proje sahibi soru sorulmadan ilerlenmesini istiyor. Her seçimin gerekçesi yanında yazılı.

## Neden

Bugün bir uygulamada doldurma yalnızca **o uygulamaya bağlı** kayıtlarla eşleşir ([Eşleştirme](guvenlik-tasarimi.md#eşleştirme)). KeePass, Bitwarden ya da tarayıcıdan içe aktarılan kayıtların yalnızca adresi vardır. Kullanıcı GitHub uygulamasını ilk kez açtığında `github.com` kaydı eşleşmez: "Eşleşme yok" uyarısı çıkar, kullanıcı kaydı listeden arar, uyarıyı okur, bağlama kutusunu işaretler. İçe aktarmadan sonra her uygulama için bir kez bu yapılır.

Uygulamanın bir siteye ait olduğunu söylemenin standart bir yolu var: site `https://<alan adı>/.well-known/assetlinks.json` dosyasında uygulamanın paket adını ve imza özetini yayımlar (Digital Asset Links). Android 12 ve sonrası bu dosyayı uygulama kurulurken kendisi okur ve tutan alan adlarını "doğrulanmış" olarak saklar. Google Parola Yöneticisi ve Bitwarden da uygulama ile siteyi bu dosyayla eşleştirir. İnternet izni yokken KeyKey dosyayı okuyamıyordu; sistemin kendi doğrulaması da kullanılmıyordu.

## Hedefler

- Uygulamada, kayda bağlı olmasa bile, uygulamanın **doğrulanmış sitesiyle** aynı siteyi taşıyan kayıt eşleşir.
- Önce internetsiz: Android 12+ sistemin zaten doğruladığı alan adları (`DomainVerificationManager`).
- Sonra internetle, ayar açıksa: sistemin doğrulamadığı ama uygulamanın kendisinin sitesi olduğunu söylediği alan adının `assetlinks.json` dosyası.
- Doğrulanmış site eşleşmesi kesin eşleşmedir: tek kayıt ve uyarı yoksa liste açılmadan doldurulur. Doldurulunca uygulama kayda kendiliğinden bağlanır; sonraki doldurmalar bugünkü imza eşleşmesiyle olur, ağa çıkılmaz.

## Hedef olmayanlar

- **Tarayıcıda uygulama bağlantıları.** Güvenilen tarayıcıda bugün yalnızca adresler karşılaştırılıyor; o kural değişmez.
- **Kaydetme sırasında adres eklemek.** Yeni kaydedilen girişe uygulamanın sitesini eklemek ayrı bir iş; bu fazda kayıt yalnızca uygulamaya bağlanmaya devam eder.
- **`include` ifadeleri.** `assetlinks.json` başka bir dosyayı gösterebilir (`include`); izlenmez. Android'in kendi doğrulaması büyük sitelerde zaten yapılmış olur.
- **Güvenilen tarayıcı listesini internetten güncellemek.** Gömülü kalır; sahte siteye karşı ana savunma o.
- **Sonuçları saklamak.** Olumlu sonuç kayda bağlama olarak saklanır; olumsuz sonuç hiç saklanmaz.

## Karşı hedefler

Bunlardan biri olursa iş çalışsa bile başarısızdır:

- Sahte bir uygulamanın, yalnızca paket adını ya da manifestindeki alan adını taklit ederek bir sitenin parolasını alması.
- Ayar kapalıyken ağa çıkmak. Ayar açıkken kasadaki sitelerin listesini ağa dökmek: yalnızca hem uygulamanın kendi sitesi olduğunu söylediği hem de kasada kaydı olan siteye sorulur.
- Doldurma ekranının ağ yüzünden uzun süre beklemesi.
- Bugünkü imza eşleşmesinin ve uyarıların zayıflaması: imzası tutmayan kayıt, doğrulanmış site yüzünden eşleşmiş sayılmaz.

## Yaklaşımlar

| Yaklaşım | Artısı | Eksisi |
|---|---|---|
| **1. Sistem doğrulaması, sonra ayarla `assetlinks.json`** (seçilen) | İnternetsiz kısım ağa hiç çıkmaz ve sistemin yaptığı doğrulamaya dayanır; internet kısmı yalnızca sistemin doğrulamadığı durumları kapatır; olumlu sonuç kayda bağlama olarak saklanır | İki kaynak, iki kod yolu |
| 2. Yalnızca `assetlinks.json` | Tek kod yolu, Android 11'de de aynı | Her ilk doldurmada ağ; ayar kapalı kullanıcı hiç yararlanmaz |
| 3. Yalnızca sistem doğrulaması | Ağ yok, en küçük iş | Android 11'de yok; sistemin doğrulaması tek bir alan adı tutmazsa bütün alan adlarını düşürür (Android 12'de `autoVerify` hepsi ya da hiçbiri), büyük uygulamaların bir kısmı hiç doğrulanmamış görünür |
| 4. Paket adından site tahmini, doğrulamasız | İnternetsiz, Android 11'de de çalışır | Paket adını herkes seçebilir: `com.github.android` adlı sahte uygulama `github.com` parolasını alır. Reddedildi |

Birincisi seçildi; proje sahibinin "daha iyi ve sağlam" isteğine en çok o uyuyor. Paket adından tahmin yalnızca **sorulacak siteyi bulmak** için kullanılır, kendisi hiçbir zaman eşleşme saymaz (aşağıda).

## Tasarım

### Akış

Doldurma ekranı, kasa açıldıktan sonra bugünkü gibi `matchLogins` ile eşleşmeleri bulur. Hedef tarayıcı olmayan bir uygulamaysa ve imzası okunabildiyse ([`certsSha256`](guvenlik-tasarimi.md#eşleştirme) boş değilse) şunlar eklenir:

1. **Uygulamanın alan adları** Kotlin'den alınır (`DomainVerificationManager.getDomainVerificationUserState`, Android 12+): uygulamanın manifestinde `autoVerify` ile bildirdiği her `https` alan adı ve durumu. Yalnızca `DOMAIN_STATE_VERIFIED` doğrulanmış sayılır. `DOMAIN_STATE_SELECTED` (kullanıcının ayarlardan elle açtığı) sayılmaz: o kullanıcının tercihidir, sitenin onayı değildir. Android 11'de liste boştur.
2. **Doğrulanmış site:** Her doğrulanmış alan adı kayıt edilebilir alan adına indirgenir ([Public Suffix List](guvenlik-tasarimi.md#eşleştirme)). Joker (`*.ornek.com`) baştaki `*.` atılarak işlenir. Kayıttaki adreslerden birinin kayıt edilebilir alan adı bunlardan biriyse kayıt **doğrulanmış site** olarak eşleşir.
3. **İnternetle doğrulama**, yalnızca ayar açıksa ve 2. adımdan sonra hâlâ eşleşmeyen kayıt varsa:
   - **Aday alan adları:** uygulamanın bildirdiği ama doğrulanmamış alan adları (1. adım, joker atılmış) ve paket adından türetilen alan adı. Paket adının parçaları ters sırayla birleştirilir ve kayıt edilebilir alan adı olan ilk önek alınır: `com.github.android` → `github.com`, `tr.com.garanti.cep` → `garanti.com.tr`. Bulunamazsa aday çıkmaz.
   - **Süzme:** Yalnızca kayıt edilebilir alan adı kasadaki eşleşmemiş (ve imzası tutmuyor sayılmayan) bir kaydın adresiyle aynı olan adaylar kalır. Aynı siteden bir aday yeter. En fazla 4 site sorulur; fazlası atılır (alfabetik sırayla, belirlenimci olsun diye).
   - **Sorgu:** Her aday için `https://<aday>/.well-known/assetlinks.json` okunur. Sorgular birlikte başlar; toplam bekleme en fazla 5 saniyedir.
   - **Karar:** Dosyada şu ifade varsa aday doğrulanmış sayılır: `relation` içinde `delegate_permission/common.get_login_creds` ya da `delegate_permission/common.handle_all_urls`; `target.namespace` `android_app`; `target.package_name` uygulamanın paket adı; `target.sha256_cert_fingerprints` uygulamanın imzasını tutuyor (aşağıda). Sonra 2. adımdaki kural bu aday için de uygulanır.
4. Eşleşmeler sıralanır: önce bağlı uygulama, sonra doğrulanmış site; her grup kendi içinde ada göre.
5. Kullanıcı doğrulanmış site eşleşmesini doldurunca uygulama, bugünkü bağlama kutusuyla aynı yoldan kayda bağlanır (paket adı ve imza özetleri). Kutu gösterilmez; bağlama kendiliğinden yapılır, çünkü eşleşmenin kendisi zaten doğrulanmıştır. Bağlama kaydı değiştirdiği için senkron açıksa diğer telefonlara da gider.

Sorgu sürerken ekran kilit açma sonrasındaki yükleniyor görünümünü sürdürür ve altında "Uygulamanın sitesi doğrulanıyor" yazar. Hata, zaman aşımı ya da dosyada eşleşme yoksa aday sessizce düşer; liste bugünkü gibi açılır. Ağ hatası kullanıcıya ayrı bir hata olarak gösterilmez: eşleşmenin olmaması zaten "Eşleşme yok" uyarısıyla söylenir.

### İmza karşılaştırması

`sha256_cert_fingerprints` büyük harfli, iki nokta ayraçlı onaltılık özetlerdir (`AB:CD:...`). Küçük harfe çevrilip ayraçlar atılır; 64 karakter onaltılık olmayan değer atılır.

- **Tek imzacılı uygulama:** Listedeki özetlerden biri `PackageManager.hasSigningCertificate` ile tutarsa yeter. Bu, imza anahtarını döndürmüş uygulamada eski sertifikayı da kabul eder; Android'in kendi doğrulamasıyla aynı.
- **Çok imzacılı uygulama:** Uygulamanın şu anki bütün imzacılarının özetleri listede olmalıdır.

Mevcut `hasSigningCertificates` köprüsü tek imzacıda her özet için ayrı çağrılır; çok imzacıda karşılaştırma Dart'ta `certsSha256` ile yapılır.

### Şüpheli durumlar ve kesin eşleşme

- **İmza tutmuyor her zaman kazanır.** Kayıt, bağlı uygulamasının paket adı aynı ama imzası farklı olduğu için `signatureMismatches` içindeyse doğrulanmış site yüzünden eşleşmiş sayılmaz; uyarı bugünkü gibi "bu uygulama sahte olabilir" der. Sitenin yeni imzayı onaylaması anahtar değişikliği olabilir, ama aynı paket adında iki farklı imza görmek tam da saldırının görüntüsüdür; kullanıcı kaydı düzenleyip eski bağlamayı kaldırabilir.
- **Kesin eşleşme:** Doğrulanmış site eşleşmesi kesin eşleşme sayılır. Tek eşleşme, uyarı yok, `signatureMismatches` boş ve uygulama web sayfası göstermiyorsa liste açılmadan doldurulur ([Akış](guvenlik-tasarimi.md#akış), 4. adım).
- **WebView:** Bugünkü kural değişmez. Eşleşmiş kayıtta WebView uyarısı yoktur (site, uygulamayı kendisi onaylamıştır; sayfayı barındıran uygulamanın parolayı görebilmesi AutoSpill'in tehlikesiydi ve burada uygulama sitenin sahibidir); ama uygulama web sayfası gösteriyorsa liste yine de açılır.

### Neden güvenli

Sahte bir uygulama paket adını ve manifestindeki alan adlarını istediği gibi seçebilir. İkisi de tek başına bir şey kazandırmaz:

- Sistem bir alan adını ancak o sitenin `assetlinks.json` dosyası uygulamanın **imzasını** listeliyorsa doğrular. Sahte uygulamanın imza anahtarı farklıdır.
- İnternetle doğrulamada da karar imzaya bakar. Paket adından türetilen aday yalnızca hangi siteye sorulacağını belirler.
- Sitenin dosyasını değiştirebilen biri (sitenin kendisi ele geçmişse) zaten o sitenin girişini ele geçirmiştir.

Kalan risk: sitenin `assetlinks.json` dosyasının başka bir şirketin uygulamasını listelemesi (ortak giriş, iş ortağı). Bu, sitenin sahibinin kendi beyanıdır; Google Parola Yöneticisi de aynı beyanla paylaşır.

### Ağ

Ağ kodu yeni bir dosyada durur: `lib/core/network/asset_links_client.dart`. [Ağ denetimi testi](../../test/core/network/network_audit_test.dart) izin verilen dosyalara bunu ekler. Diğer istemcilerle aynı kurallar:

- Yalnızca `https`; adres kodda kurulur: `https://<alan adı>/.well-known/assetlinks.json`. Alan adı, kayıt edilebilir alan adı olan ya da sistemin bildirdiği ASCII (punycode) bir addır; IP adresi ve port kabul edilmez, uymazsa ağa çıkılmaz.
- Yönlendirme izlenmez (Android'in kendi doğrulaması da izlemez). Yanıt `200` ve gövde en fazla 128 KiB olmalı; JSON dizisi değilse aday düşer.
- Bağlanma 3 saniye, istek 5 saniye. Çerez tutulmaz, `User-Agent` yalnızca "KeyKey".
- Sistemin güvendiği sertifika yetkilileri kullanılır, kullanıcının eklediği sertifikalara güvenilmez; sabitleme yapılmaz (siteler binlerce farklı sunucu).
- Siteye ne gider: yalnızca sabit yolun kendisi. Site ve ağı izleyen biri, bu cihazın o sitenin `assetlinks.json` dosyasını istediğini görür; yani kullanıcının o sitenin uygulamasında KeyKey ile doldurma yapmak üzere olduğunu ve kasada o siteden bir kayıt bulunduğunu çıkarabilir. Kasadan hiçbir şey gitmez.

### Ayar

Ayarlar → Otomatik doldurma'da yeni bir anahtar: **"Uygulamanın sitesini internetten doğrula"**, varsayılan kapalı ([İnternet kararı](../yol-haritasi.md#temel-kararlar): her internet özelliği kullanıcı açınca çalışır). Açıklaması: "Bir uygulamada eşleşen kayıt yoksa, uygulamanın sitesi olduğunu söylediği ve kasanda kaydı bulunan sitenin assetlinks.json dosyası okunur. Siteye kasandan bir şey gitmez." Ayar şifreli kasa ayarlarına (`AppSettings`, sürüm 8) eklenir; okunamazsa kapalı sayılır. İnternetsiz kısım (sistemin doğrulaması) ayar istemez, her zaman çalışır.

**Uygularken eklenenler:** Ayar kaydının sürümü artınca yedeğin içerik sürümü de artar (güvenlik tasarımındaki kural, bir test sabitliyor): yedekler 5 ile yazılır. Senkron dosyası ayar kaydı taşımadığı için 4'te kalır, böylece 1.8.0-1.9.x telefonlarla eşitleme sürer. Kullanım koşullarındaki "internete yalnızca … için çıkar" cümlesi bu özellikle eksik kalacağı için koşullar sürüm 4 olur ve bir kez yeniden sorulur.

### Kotlin

`PlatformApi`'ye (Pigeon) bir çağrı: `appDomains(packageName)` → `[(host, verified)]`. Android 12'nin altında, paket bulunamazsa ya da uygulama `https` alan adı bildirmiyorsa boş liste. Alan adları küçük harfe çevrilir; `getHostToStateMap` anahtarları zaten ASCII'dir. Hedef uygulama doldurma ekranını kendisi başlattığı için paket görünürlüğü engel olmaz; AOSP'deki denetim (`DomainVerificationEnforcer.assertApprovedUserStateQuerent`) yalnızca görünürlüğe bakar, ek izin istemez.

### Testler

- `matchLogins`: doğrulanmış alan adıyla aynı site eşleşir, alt alan adı eşleşir, başka site eşleşmez; `SELECTED` sayılmaz; joker; imzası tutmayan kayıt doğrulanmış site yüzünden eşleşmez; sıralama; tarayıcıda alan adları kullanılmaz.
- Aday üretimi: paket adından türetme (`com.github.android`, `tr.com.garanti.cep`, tek parçalı, kayıt edilebilir önek yok), süzme, en fazla 4.
- `assetlinks.json` çözümleme: iki ilişki türü, yanlış paket, yanlış namespace, özet biçimleri, bozuk JSON, dizi olmayan kök, büyük gövde.
- İstemci: yerel test sunucusuyla yönlendirme izlenmez, `http` reddedilir, zaman aşımı, boyut sınırı, IP adresi reddedilir.
- Ayar kapalıyken istemci hiç çağrılmaz.
- Doldurma ekranı (widget): doğrulanmış site tek eşleşmede doğrudan doldurur ve uygulamayı bağlar; yükleniyor yazısı; ağ hatasında liste açılır.
- Kotlin birim testi: alan adı listesinin dönüşümü.
- Cihazda: Android 12+ emülatörde doğrulanmış alan adı olan bir uygulama (örneğin Wikipedia, `org.wikipedia`; doğrulama `adb shell pm get-app-links` ile görülür) ve `wikipedia.org` kaydıyla gerçek doldurma yolu. Sonuç: [güvenlik denetimi](guvenlik-denetimi.md#ağ).

### Belgeler

Güvenlik tasarımı ([Eşleştirme](guvenlik-tasarimi.md#eşleştirme), [Şüpheli durumlar](guvenlik-tasarimi.md#şüpheli-durumlar), tehdit modeli satırı, Ağ bölümü), gizlilik bildirimi (`gizlilik.md`, `privacy.md`), kullanım kılavuzu, yol haritası, sürüm notu.

### Ayrıntılar (taze okumadan sonra netleşenler)

- **Bağlama ekler, değiştirmez.** Bugünkü `_bindApp` gibi: kayıtta aynı paket adı varsa o girdi yenilenir, başka paketler kalır. GitHub'ın iki uygulaması aynı kayda ayrı ayrı bağlanabilir. Saklanan özetler uygulamanın cihazdaki şu anki bütün imzacılarıdır (`certsSha256`), dosyada tutan tek özet değil; sonraki imza eşleşmesi bugünkü kuralla yapılır.
- **İmza tutmuyor:** Kayıt bugünkü kuralla `signatureMismatches`e düşüyorsa (hedef paket bağlı, imzası tutmuyor) doğrulanmış siteye bakılmaz. Aynı kayıtta hedef paket bir kez bulunur, çünkü bağlama aynı paketi yeniler.
- **Kayıt edilebilir alan adı** web hedefindeki kuralla aynıdır: doğrulanmış `login.ornek.com`, `ornek.com` altındaki bütün adresleri tutar. Public Suffix List'te olmayan paylaşımlı barındırmalarda bu, tarayıcıda bugün de geçerli olan sınırdır.
- **"Web sayfası gösteriyor"** bugünkü `AutofillTarget.showsWebPage` (`inWebView` ya da `untrustedWebDomain`); yeni bir sinyal gerekmez.
- **Paket adından türetme** üst düzey alan adından başlar ve kayıt edilebilir olan **ilk** (en kısa) öneki alır: `com.google.android.apps.foo` → `google.com`.
- **Ayar kapalıyken** ekran bu özellikten söz etmez; "Eşleşme yok" uyarısı bugünkü gibidir. Ayar Ayarlar'da açıklamasıyla durur. (Benim kararım: uyarıya ayar önerisi eklemek, şüpheli durumda kullanıcıyı ağa çıkmaya yönlendirmek olurdu.)
- **Sistem doğrulamasının okunabildiği** cihazda denenir (emülatörde Wikipedia). Okunamazsa (`SecurityException` ya da boş durum) Kotlin boş liste döner ve yalnızca internetle doğrulama kalır; bu durum belgeye yazılır.

## Uygulayana kalanlar

- Pigeon tanımının adı ve dönüş tipinin biçimi.
- Yükleniyor yazısının tam yeri ve çevirisi.
- Kasada çok sayıda kayıt varken eşleştirmenin performansı: adres başına Public Suffix List çağrısı bugün de yapılıyor; gerekirse kayıt başına önbellek.

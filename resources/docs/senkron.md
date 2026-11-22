# Senkron

**Durum:** Faz 19 tasarımı, 2026-11-20. **Görev:** [#160](https://github.com/aaudraa/KeyKey/issues/160). Plan: [senkron-plani.md](senkron-plani.md).

## Neden

Proje sahibi 2026-11-19'da internete açılmaya ve senkrona karar verdi ([yol haritası](../yol-haritasi.md#temel-kararlar)). Bugün iki telefon arasında kayıt taşımanın tek yolu yedek dosyası: birinde yedek alınır, ötekinde birleştirerek geri yüklenir. Bu elle yapılan, tek yönlü ve unutulan bir iş. İki telefonda (ya da telefon ve tablette) aynı kasayı kullanan biri, birinde eklediği parolanın ötekinde de kendiliğinden görünmesini bekler.

Yol haritası sırayı da koydu: önce WebDAV, çünkü Nextcloud gibi kendi sunucusunu ya da WebDAV sunan bir bulut hesabını kullanan biri hesap açmadan bağlanabilir. Google Drive, proje sahibinin Google Cloud hesabında bir OAuth istemcisi gerektirir; o adım ona kalır ve ayrı bir iştir.

## Hedefler

- Aynı kasayı kullanan telefonlar, kullanıcının kendi WebDAV klasörü üzerinden parola, 2FA, kart ve not kayıtlarını eşitler. Eklenen, değiştirilen, çöpe atılan ve kalıcı silinen kayıtlar öteki telefonlara geçer.
- Sunucu yalnızca şifreli dosya görür: kayıtların içeriği, sayısı, türleri ve zamanları sunucudan gizlidir (yedeğin iki katmanlı biçimi).
- Ana parola ya da kurtarma anahtarı bir telefonda değişince öteki telefonların kilit ekranı da yenisine geçer. Bu bir **iptal değildir**: kasa anahtarı değişmez; eski parolayla açılan herhangi bir kopya (eski yedek, sunucunun dosya geçmişi ya da çöp kutusu, kaldırılmamış bir telefonun dosyası) kasa anahtarını verir ve o anahtar sonraki senkron dosyalarını da açar ([aşağıda](#ana-parola-ve-kurtarma-anahtarı-değişikliği)).
- Yeni telefon, sunucudaki senkron dosyasından kurulabilir. Başka bir kasası olan telefon, kendi kayıtlarını kaybetmeden senkrondaki kasaya katılabilir.
- Hiçbir durumda kayıt sessizce kaybolmaz: birleştirme yalnızca daha yeni bir değişikliği ya da daha yeni bir kalıcı silmeyi uygular.

## Hedef olmayanlar

- **Google Drive** (ayrı iş, proje sahibinin OAuth istemcisine bağlı).
- **Kasa kilitliyken ya da arka planda eşitleme.** Kasa anahtarı gerekir; otomatik yedekteki gibi kasa dışında saklanan bir anahtar yoktur.
- **Ayarların eşitlenmesi.** Ayar kaydı cihaza aittir (tema, kilit süresi, otomatik yedek klasörü, senkron bilgileri); senkron dosyasına girmez.
- **Otomatik doldurma ekranının eşitlemesi.** Doldurmanın kaydettiği parola, ana uygulama açılınca ya da öne gelince eşitlenir.
- **Kendinden imzalı sertifika, sertifika sabitleme, `http://` sunucu.** Yalnızca sistemin güvendiği sertifikalarla HTTPS (bu telefonun kendi `127.0.0.1` adresi dışında).
- **Eşitleme uygulamasının klasörü üzerinden (Syncthing, Nextcloud uygulaması) senkron.** Otomatik yedek o klasöre zaten yazıyor; aynı motorla ayrı bir taşıyıcı olarak sonra eklenebilir.
- **Paylaşılan kasa, birden çok kullanıcı.** Bir klasör tek bir kasaya aittir.
- **Kasa anahtarını yenilemek** (parola sızınca gerçek iptal). Bütün kayıtların yeniden şifrelenmesini ve öteki telefonlara yeni anahtarın ulaştırılmasını gerektirir; ayrı ve büyük bir iş.
- **Alan alan birleştirme.** Aynı kayıt iki telefonda eşitlemeler arasında değişirse yeni olan bütünüyle kazanır; yalnızca kaybeden parola kurtarılır ([Birleştirme](#birleştirme)).

## Karşı hedefler

Çalışsa bile başarısızlık sayılacaklar:

- Bir telefonun eski hali, öteki telefonda yapılmış daha yeni bir değişikliği ya da silmeyi geri alırsa.
- Kalıcı silinen bir kayıt, başka bir telefonun dosyasından geri gelirse.
- Sunucuya ya da ağa şifresiz kayıt, parola, kayıt adı veya kullanıcı adı giderse; uygulama parolası kasa dışında ya da günlükte görünürse.
- Bir hata (yanlış parola, bozuk dosya, başka kasa, sunucu hatası) yarım bir birleştirme bırakırsa.
- Kullanıcı, sunucuya ne gittiğini ve kimin neyi görebileceğini bilmeden senkronu açarsa.

## Yaklaşımlar

| Yaklaşım | Kazanç | Bedel |
|---|---|---|
| **1. Her telefon kendi şifreli dosyasını yazar, ötekilerinkini okur** (seçilen) | Aynı dosyaya iki telefon yazmaz; kilit ve çakışma yok. Dosya yedek biçiminde, kod ve doğrulama kuralları hazır. Birleştirme her sırada aynı sonucu verir. Sunucuda yalnızca telefon sayısı kadar dosya. | Her eşitlemede ötekilerin dosyası indirilir (değişmemişse `ETag` ile atlanır). Kullanılmayan telefonun dosyası elle kaldırılana kadar sunucuda kalır. |
| 2. Tek ortak dosya, `ETag` ve `If-Match` ile | Sunucuda tek dosya. | İki telefon aynı anda yazarsa biri yeniden denemek zorunda; sunucuların `If-Match` desteği tutarsız; yarım bir yazma bütün telefonların ortak dosyasını bozar. |
| 3. Kayıt başına bir dosya | Yalnızca değişen kayıt gider. | Sunucu kayıt sayısını, değişme zamanlarını ve hangi kaydın ne zaman silindiğini görür; yüzlerce istek. Tehdit modelini gevşetir. |

**Seçim 1.** Bir parola yöneticisinde en kötü sonuç veri kaybı; ortak bir dosyanın yarım yazılması ya da iki yazmanın çakışması tam da bunu doğurur. Telefon başına dosyada her telefon yalnızca kendi dosyasını yazar ve birleştirme değişmeli (sıra fark etmez) olduğu için bütün telefonlar aynı sonuca varır. Yedek biçimi, şifreleme ve katı okuma kuralları zaten denetlenmiş kod. Üçüncü yol, yedeğin gizlediği her şeyi sunucuya açar.

## Tasarım

### Kasa ve klasör

- Senkron yalnızca **aynı kasayı** (aynı `vaultId` ve kasa anahtarı) kullanan telefonlar arasındadır. Kayıtlar kasa anahtarının alt anahtarlarıyla şifreli olduğu için telefonlar arasında olduğu gibi taşınır, yeniden şifrelenmez.
- Bir WebDAV klasörü tek bir kasaya aittir. Klasördeki senkron dosyalarının üst bilgisi şifresizdir ve `vaultId` taşır; böylece parola sormadan "bu klasörde başka bir kasa var" denebilir.
- Dosya adı: `keykey-sync-<cihaz>.keykey`. Dilden bağımsızdır (telefonlar farklı dillerde olabilir). `<cihaz>` otomatik yedeğin kullandığı, kasanın dışında tutulan altı onaltılık karakterlik kurulum kimliğidir (`auto_backup_device`); gizli değildir.
- Her telefon yalnızca kendi dosyasını yazar, ama **kendi dosyası dahil** klasördeki bütün dosyaları okur. Olağan durumda kendi dosyası yerel kasayla aynıdır ve birleştirme bir şey değiştirmez; yerel kasa yedekten değiştirildiyse kendi dosyasındaki kayıtlar kaybolmaz.

### Senkron dosyası

Dosya [yedek biçimindedir](guvenlik-tasarimi.md#yedek-biçimi): aynı sihir, aynı kapsayıcı, aynı yedek anahtarı (`HKDF-Expand(kasa anahtarı, "keykey/v1/backup")`), aynı sınırlar (64 MiB, 100 000 kayıt). Düz metin JSON'u içerik **sürümü 4** ile yazılır ve bir `sync` nesnesi taşır:

```json
{
  "version": 4,
  "createdAt": 1730000000000,
  "records": [ { "id": "…", "type": "login", "createdAt": 0, "updatedAt": 0, "blob": "…" } ],
  "sync": {
    "device": "a1b2c3",
    "deviceName": "SM-G780G",
    "passwordChangedAt": 1730000000000,
    "recoveryChangedAt": null,
    "deleted": [ { "id": "<16 bayt>", "deletedAt": 1730000000000 } ]
  }
}
```

- `records`: ayar kaydı **hariç** bütün kayıtlar (çöp kutusundakiler dahil). Senkron dosyasında `settings` türünde kayıt varsa dosya reddedilir.
- `device`: dosyanın adındaki kimlikle aynı olmalı; değilse dosya reddedilir.
- `deviceName`: telefonun modeli (`Build.MODEL`, en çok 64 karakter). Yalnızca cihaz listesinde gösterilir, şifreli katmandadır.
- `passwordChangedAt`, `recoveryChangedAt`: üst bilgideki parola yuvasının ve kurtarma yuvasının bu telefonun bildiği son değişme zamanları (aşağıda); 1.8.0'dan beri değişmediyse `null`.
- `deleted`: silme kayıtları (aşağıda). Kimlikler tekrarlanamaz.
- Elle ve otomatik yedekler de sürüm 4 ile yazılır ama `sync` taşımaz ([Sürümler](#sürümler): ayar kaydı sürüm 7 olduğu için 1.7.0 bu yedekleri zaten okuyamaz). 1.10.0'dan beri yedekler sürüm 5 ile yazılır (ayar kaydı sürüm 8); senkron dosyası ayar kaydı taşımadığı için sürüm 4'te kalır, 1.8.0-1.9.x telefonlarla eşitleme sürer. `sync` yalnızca sürüm 4'te bulunabilir; senkron dosyası olarak okunan dosyada zorunludur, Geri yükle'de isteğe bağlıdır.
- Senkron dosyası yedek gibi geri yüklenebilir (Geri yükle ekranı): kayıtları alınır, `sync` nesnesi yok sayılır. Telefon kaybolunca sunucudaki dosya son çare yedeğidir.
- Okurken doğrulama yedekteki kadar katıdır: bilinmeyen alan, eksik alan, yanlış uzunluk, yinelenen kimlik reddedilir. Daha yeni bir içerik sürümü `NewerBackupException` olur ("başka bir telefonda daha yeni KeyKey var").

### Silme kayıtları

Bugün kalıcı silme (çöpü boşaltma, kalıcı silme, 30 günlük temizlik) satırı siler. Senkronda öteki telefonun dosyası o kaydı geri getirirdi. Bu yüzden:

- Veritabanına yeni tablo: `tombstones` (`id` 16 bayt, `deleted_at`). `VaultStore.deleteRecord` satırı silerken aynı işlemde silme kaydını yazar. Senkron açık olsun olmasın her zaman yazılır; böylece senkron sonradan açıldığında da geçmiş silmeler bilinir.
- Silme kaydı yalnızca kimlik ve zamandır; içerik, tür ve ad taşımaz. Veritabanında şifresizdir (kayıtların zaman damgaları gibi, [bilinen sınırlar](guvenlik-tasarimi.md#bilinen-sınırlar)); senkron dosyasında şifreli katmandadır.
- Silme kayıtları silinmez. Bir kayıt 16 bayt ve bir sayıdır; 100 000 sınırı kayıtlarla ortak sayılır. Eski bir telefon aylar sonra bağlansa bile sildiği kayıt geri gelmez.
- Ayar kaydı silinmez, silme kaydı da yazılmaz.
- Kasa değiştirilince (yedekten değiştirme, senkrondaki kasaya katılma) eski kasanın silme kayıtları da silinir; yeni kasanınkiler (varsa) yazılır.

### Birleştirme

Eşitleme, yerel kasa ile indirilen her cihaz dosyasını kayıt kimliğine göre birleştirir:

1. Her kimlik için adaylar: yerel kayıt, dosyalardaki kayıtlar ve en yeni silme kaydı.
2. **En iyi kayıt:** `updatedAt` değeri en büyük olan; eşitse şifreli verisi bayt bayt büyük olan. Bu kural her telefonda aynı sonucu verir.
3. Silme kaydının zamanı en iyi kaydın `updatedAt` değerinden **büyük ya da eşitse** kayıt silinmiş sayılır: yerelde varsa silinir, silme kaydı tutulur. Değilse (kayıt silindikten sonra başka telefonda değiştirildi) kayıt kalır ve o silme kaydı yerelden kaldırılır; değişiklik kaybolmaz.
4. Aynı kimlik farklı türle gelirse (AD türe bağlı olduğu için bu ancak bozulmayla olur) o cihaz dosyası bütünüyle yok sayılır.
   - **Saat koruması:** Bir dosyada bu telefonun saatinden **24 saatten fazla ileride** bir zaman (`updatedAt`, `deletedAt`, yuva zamanları) varsa o dosya bütünüyle yok sayılır ve durumda "<cihaz> telefonunun saati ileride" yazar. Saati yanlış bir telefonun (ya da veritabanına yazabilen birinin uydurduğu) gelecek tarihli sürüm veya silme kaydı böylece bütün telefonlarda kalıcı olarak kazanamaz. Saat düzelince o telefonun dosyası yeniden alınır.
   - **Kaybeden parola kurtarılır:** Kazanan ve kaybeden ikisi de parola kaydıysa ve kaybeden sürümün parolası boş değilse, kazananın parolası değilse ve kazananın parola geçmişinde yoksa, kaybeden parola kazananın geçmişine eklenir (`changedAt` = kaybeden sürümün `updatedAt` değeri, en çok 10 kayıt kuralıyla). Kayıt yeniden şifrelenir ve `updatedAt` değeri kazananınkinden 1 ms sonrası olur; böylece kurtarılmış sürüm öteki telefonlarda da düz kazananı yener. İki telefon aynı kurtarmayı yaparsa içerikleri aynıdır, bayt kuralıyla biri kalır; kural yeniden tetiklenmez. Örnek: otomatik doldurma A telefonunda yeni bir parola kaydetti, A eşitlemeden önce B'de aynı kayıt favoriye alındı; B'nin sürümü kazanır ama yeni parola geçmişte durur ve kayıt ekranında görünür. Öteki alanlar ve parola dışındaki türler için kaybeden değişiklik kaybolur ([bilinen sınırlar](#güvenlik)).
5. **Doğrulama:** Yerele yazılacak her uzak kayıt, açık kasanın anahtarıyla çözülür ve biçimi denetlenir (geri yüklemedeki gibi). Tek bir kayıt açılmazsa o cihaz dosyası bütünüyle yok sayılır ve durumda bildirilir; öteki dosyalarla birleştirme sürer.
6. Bütün değişiklikler (kayıtlar, silmeler, silme kayıtları, varsa üst bilgi) **tek SQLite işleminde** yazılır. Yarıda kalırsa kasa eski halinde kalır.
7. Yazılan kayıtlar listeye yansır (kontrolcüler yeniden okur). Ekranda açık bir düzenleme formu varsa Faz 18'in kuralı geçerli: form yalnızca kullanıcının değiştirdiği alanları en son kayda yazar.
8. Ardından bu telefonun dosyası, birleşmiş halden yeniden üretilip yüklenir; ancak içeriği son yüklenenden farklıysa (aşağıda).

Saat sorunu: `updatedAt` telefonun saatidir. 24 saate kadar ileride olan bir telefonun değişiklikleri o kadar süre kazanır; daha ilerisi saat korumasına takılır. Telefon saatleri ağdan ayarlandığı için fark pratikte saniyeler mertebesindedir.

### Ana parola ve kurtarma anahtarı değişikliği

Kasa anahtarı değişmez; parola değişince yalnızca üst bilgideki sarmalama değişir. Öteki telefonlar eski üst bilgiyi tutmaya devam ederse eski parola o telefonlarda ve onların sunucudaki dosyalarında kasayı açmaya devam ederdi; parolasını sızdığı için değiştiren biri için bu kabul edilemez.

- `vault_meta`'ya iki yeni sütun: `password_changed_at` ve `recovery_changed_at` (boş olabilir). Ana parola değişince ve kurtarma anahtarıyla yeni parola belirlenince birincisi, kurtarma anahtarı yenilenince ikincisi üst bilgiyle aynı işlemde o anın zamanıyla yazılır.
- İki yuva **ayrı ayrı** birleşir, çünkü birbirinden bağımsızdır: parola yuvası KDF parametreleri ve tuzla birlikte bir bütündür (AD'leri bağlı), kurtarma yuvasının AD'si yalnızca kasa kimliğidir. Uzak dosyanın parola zamanı yereldekinden büyükse uzak parola yuvası (parametreler ve tuz dahil), kurtarma zamanı büyükse uzak kurtarma yuvası alınır; `vaultId` aynı olmalıdır. Böylece bir telefonda yenilenen kurtarma anahtarı, başka bir telefondaki sonraki parola değişikliğiyle geri alınmaz.
- **Zamanı bilinmeyen fark:** İki tarafta da zaman `null` ama yuvalar farklıysa (1.8.0 öncesinde telefonlardan birinde parola değişmiş) hiçbir şey alınmaz; durumda "Bu telefonla <cihaz> farklı ana parola kullanıyor. Doğru parolanın olduğu telefonda ana parolayı yeniden belirle; öteki telefonlar ona geçer." yazar. Rastgele bir seçim eski, belki sızmış bir parolayı geri getirebilirdi. Zamanlar eşit ve yuvalar farklıysa (aynı milisaniye) bayt bayt büyük olan alınır.
- Birleşik üst bilgi birleştirmeyle aynı işlemde yazılır. Dosyayı kasa anahtarına sahip olmayan biri üretemez (yedek anahtarı ondan türer), yani yuvalar ancak kullanıcının kendi telefonlarından gelir. Yine de yuvalar parolasız doğrulanamaz; biçimleri yerel üst bilgi kadar katı denetlenir.
- Kasa açık kalır (anahtar aynı). Parmak izi yuvası etkilenmez, çünkü kasa anahtarını sarar. Kullanıcıya bir kez gösterilir: "Ana parola başka bir telefonda değiştirildi. Kasayı bir sonraki açışında yeni parolayı kullan." ya da "Kurtarma anahtarı başka bir telefonda yenilendi. Eski kurtarma anahtarın artık geçmez."
- **Bu bir iptal değildir.** Eski parolayla açılan her kopya kasa anahtarını verir: eski yedekler (bugün de [bilinen sınır](guvenlik-tasarimi.md#bilinen-sınırlar)), sunucunun dosya geçmişi ve çöp kutusu (Nextcloud bunları varsayılan olarak tutar), kaldırılmamış bir telefonun dosyası. Kasa anahtarını ele geçiren, sonraki bütün senkron dosyalarını da açar. Parolası sızan ya da telefonu çalınan kullanıcıya önerilen: o telefonun **uygulama parolasını sunucuda iptal etmek** (her telefona ayrı uygulama parolası verilmesi kurulumda önerilir) ve kasayı yeni bir kasaya taşımak (yeni kasa kurup yedeği birleştirerek almak). Bu öneri kılavuzda ve güvenlik tasarımında yazar.

### WebDAV istemcisi

`lib/core/network/webdav_client.dart`; ağ denetim testi (`network_audit_test.dart`) iki dosyaya izin verecek şekilde güncellenir. Sızıntı kontrolünün istemci kuralları aynen geçerli:

- Dart'ın `dart:io` `HttpClient`'ı. XML yanıtı için `xml` paketi (saf Dart, MIT; [bağımlılıklar](bagimliliklar.md) güncellenir). Başka yeni bağımlılık yok.
- **Yalnızca HTTPS** ve sistemin güvendiği sertifikalar; `http://` yalnızca `127.0.0.1`, `localhost`, `::1` için (bu telefonda çalışan bir sunucu ve testler). Adres kaydedilirken denetlenir.
- **Yönlendirme izlenmez.** 3xx yanıt hata olur ("sunucu başka bir adrese yönlendirdi; adresi denetle"); kimlik bilgisi başka bir sunucuya gitmez.
- Kimlik doğrulama: HTTP Basic, her istekte. Kullanıcıya **uygulama parolası** önerilir (Nextcloud: Ayarlar → Güvenlik → Uygulama parolası); hesap parolası da çalışır.
- `User-Agent: KeyKey`, çerez yok. Bağlanma 10, istek 60 saniyede zaman aşımı.
- Yanıt sınırları: klasör listesi 1 MiB, dosya 64 MiB ve kapsayıcı payı. Aşan yanıt hata olur.
- Kullanılan istekler: `PROPFIND` (Depth 1; `getetag`, `getcontentlength`, `getlastmodified`, `resourcetype`), `GET`, `PUT`, `MOVE` (`Overwrite: T`), `DELETE`, `MKCOL`.
- **Yazma:** Dosya önce `keykey-sync-<cihaz>.keykey.tmp` adıyla `PUT` edilir (`.part` olamaz: Nextcloud ve ownCloud o uzantıyı yarım yükleme sayıp dosya önbelleğine almıyor), geri okunup bayt bayt karşılaştırılır, sonra `MOVE` ile son adına taşınır. Böylece öteki telefonlar yarım dosya görmez. Sunucu `MOVE` desteklemiyorsa (405, 501) son adla doğrudan yazılır ve ara dosya silinir.
- Hata mesajları ve günlükler adres yolunu, kullanıcı adını ve parolayı taşımaz.
- Sunucuyla konuşan kod yalnızca bu dosyadadır; birleştirme, dosya biçimi ve arayüz ağ bilmez (taşıyıcı bir arayüzün arkasındadır; testler bellekte bir sahte taşıyıcı ve yerel bir WebDAV test sunucusu kullanır).

### Ne zaman eşitlenir

Yalnızca ana uygulamada ve kasa açıkken; aynı anda tek eşitleme. Biri sürerken gelen tetik, bittikten sonra bir kez daha eşitler.

- Kasa açılınca.
- Parola, 2FA, kart ya da not kaydı değişince 5 saniye sonra (peş peşe değişiklikler tek eşitlemede; otomatik yedekteki gibi).
- Uygulama öne gelince, son eşitlemeden 60 saniye geçtiyse.
- Ayarlardaki **Şimdi eşitle** ile.
- Ana parola değişince ya da kurtarma anahtarı yenilenince hemen (eski parolayla açılan dosya sunucuda bir sonraki tetiği beklemesin).
- Kasa kilitlenince süren eşitleme bırakılır; yanıtı atılır (otomatik yedeğin dönem sayacıyla aynı yol). Tek SQLite işlemi kilitten önce başladıysa tamamlanır.
- **Yükleme yalnızca gerektiğinde:** Birleşmiş halin özeti (kimlik, tür, `updatedAt`, şifreli verinin BLAKE2b özeti, silme kayıtları, üst bilgi ve yuva zamanları, sıralı) ayar kaydında tutulan son yüklenen özetle aynıysa yüklenmez.
- **İndirme yalnızca gerektiğinde:** Öteki dosyaların `ETag` değeri bu oturumda bellekte tutulur; değişmeyen dosya yeniden indirilmez. Kasa açılınca ilk eşitleme hepsini indirir.

### Senkronu açmak

**Ayarlar → Senkron.** Üç alan: sunucu klasörünün adresi, kullanıcı adı, uygulama parolası (gizli kutu, öğrenmesiz klavye). **Bağlan**:

1. Adres denetlenir (HTTPS). `PROPFIND` ile klasör okunur. 401/403: "Kullanıcı adı ya da uygulama parolası yanlış." Klasör yoksa (404) ve üstü varsa `MKCOL` ile oluşturulur.
2. Klasördeki `keykey-sync-*.keykey` dosyalarının şifresiz üst bilgisi okunur (`vaultId`).
   - **Senkron dosyası yok:** senkron açılır, bu telefonun dosyası yüklenir.
   - **Hepsi bu kasanın:** senkron açılır, eşitlenir.
   - **Başka bir kasa:** "Bu klasörde başka bir KeyKey kasası var." Seçenekler: **Bu telefonu o kasaya kat** (aşağıda) ya da **Vazgeç**.
   - **Birden çok kasa:** "Bu klasörde birden çok kasa var. Boş bir klasör seç." Senkron açılmaz.
3. Açmadan önce kısa bir açıklama penceresi: dosyaların ana parolayla şifreli gittiği; sunucunun dosya adlarını, boyutlarını, zamanlarını ve IP adresini gördüğü; dosyayı ele geçirenin ana parolayı çevrimdışı deneyebileceği; senkronun yedek olmadığı (bir telefonda silinen öteki telefonlardan da silinir, yedek almaya devam et); her telefona ayrı bir uygulama parolası vermenin, telefon kaybolunca yalnızca onunkini iptal etmeyi sağladığı.

Senkron bilgileri (adres, kullanıcı adı, uygulama parolası, açık/kapalı, son eşitleme zamanı, son yüklenen özet) **ayar kaydında**, yani kasanın içinde şifreli durur; ayar kaydı sürüm 7. Ayar kaydı senkron dosyasına girmez, elle ve otomatik yedeğe girer.

### Yeni telefonu senkrondan kurmak

Kurulum ekranında yedekten geri yüklemenin yanında **Senkrondan kur**: aynı üç alan → klasördeki senkron dosyaları → **en son değişen** dosya indirilir → Geri yükle ekranının kilit açma adımı (ana parola ya da kurtarma anahtarı) → kasa o dosyadan kurulur. Kayıtlar, silme kayıtları ve yuva zamanları dosyadan yazılır; ayar kaydı varsayılan ayarlarla ve senkron bilgileriyle oluşturulur; senkron açık gelir ve hemen eşitler (öteki dosyalarda daha yeni değişiklik varsa onlar da gelir). Parmak izi her telefonda ayrıca açılır.

### Başka kasası olan telefonu katmak

"Bu telefonu o kasaya kat" seçilince:

1. Klasördeki en son değişen dosya indirilir; kullanıcı **o kasanın** ana parolasını ya da kurtarma anahtarını girer.
2. Bu telefonun kayıtları açık kasanın anahtarıyla çözülür, senkron kasasının anahtarıyla yeniden şifrelenir ve birleştirilir (geri yüklemedeki "birleştirme" ile aynı kural: aynı kimlikte yeni olan kalır; kimlikler korunur).
3. Tek işlemde: kasa, senkron dosyasının üst bilgisi ve kayıtlarıyla değiştirilir, bu telefonun kayıtları üstüne birleştirilir, eski silme kayıtları silinir ve dosyanınkiler yazılır. Ayar kaydı bu telefonun ayarlarıdır (senkron bilgileri eklenir).
4. Parmak izi yuvası silinir (kasa anahtarı değişti); kasa yeni anahtarla açık kalır. Kullanıcıya söylenir: "Bu telefonda artık senkron kasasının ana parolası geçerli. Parmak iziyle açmayı yeniden aç."
5. Ardından eşitlenir; bu telefonun kayıtları öteki telefonlara geçer.

Bu adımdan önce bir uyarı: "Bu telefonun ana parolası ve kurtarma anahtarı artık geçmez; senkron kasasınınkiler geçer." Vazgeçilirse hiçbir şey yazılmaz.

### Durum ve cihazlar

**Ayarlar → Senkron** açıkken:

```text
Senkron                         Açık
Son eşitleme                    2 dakika önce
[ Şimdi eşitle ]

Cihazlar
  Bu telefon · SM-G780G         şimdi
  Pixel 8 · d4e5f6              3 gün önce      [Kaldır]

[ Senkronu kapat ]
```

- Cihaz satırları son eşitlemede okunan dosyalardan gelir: model, kimlik, dosyanın sunucudaki son değişme zamanı.
- **Kaldır:** O telefonun dosyası sunucudan silinir. Uyarı: telefon hâlâ kullanılıyorsa bir sonraki eşitlemesinde dosyasını yeniden yükler; kaybolan ya da çalınan bir telefonu durdurmanın yolu, onun uygulama parolasını sunucuda iptal etmektir. Sunucunun dosya geçmişi ve çöp kutusundaki kopyalar KeyKey'in erişiminde değildir.
- **Senkronu kapat:** Senkron bilgileri ayar kaydından silinir. Pencerede "Bu telefonun sunucudaki dosyasını da sil" kutusu, işaretli gelir. Kasadaki kayıtlara ve silme kayıtlarına dokunulmaz.
- **Hata durumları** Senkron satırında yazar ve **Şimdi eşitle** sonucunda bildirim olarak çıkar: bağlantı yok, kimlik reddedildi, sertifika geçersiz, sunucu hatası, sunucuda yer yok (507), klasör yok, başka bir kasa, daha yeni KeyKey, bir telefonun dosyası okunamadı (hangisi olduğu yazılır), kasa çok büyük. Kasa ekranında ayrıca uyarı yok.

### Senkron açıkken yedekten geri yükleme

Yedekten geri yükleyen kullanıcı "bu kayıtlar geri gelsin" der. Senkron bunu bozmamalı ve geri yükleme senkron üzerinden hiçbir şeyi silmemeli.

- **Birleştirerek geri yükleme:** Eklenen ya da güncellenen her kaydın silme kaydı yerelden kaldırılır ve senkron açıksa `updatedAt` değeri **şimdi** yapılır (zaman şifreli içerikte ve AD'de değil, yalnızca veritabanı sütunu; yeniden şifreleme gerekmez). Böylece öteki telefonlardaki daha eski silmeleri ve değişiklikleri yener; geri gelen kayıt bir sonraki eşitlemede yeniden silinmez.
- **Değiştirerek geri yükleme:** Yedeğin kasa kimliği bu telefonun senkron klasöründeki kasayla aynıysa senkron açık kalır, geri yüklenen bütün kayıtların `updatedAt` değeri şimdi yapılır ve hemen eşitlenir. Yedekte olmayan kayıtlar öteki telefonlardan ve bu telefonun kendi sunucu dosyasından geri gelir; senkron açıkken değiştirmek kayıt **silmez**, yalnızca yedektekileri en yeni sürüm yapar. Geri yükleme ekranı bunu söyler: "Senkron açık: yedekteki kayıtlar bütün telefonlarda yedekteki haline döner; yedekte olmayan kayıtlar silinmez." Kasa kimliği farklıysa bu telefonda senkron kapanır (klasör başka bir kasanın); kullanıcı yeniden açınca [açma denetimi](#senkronu-açmak) çalışır.
- Değiştirmede bu telefonun senkron bilgileri, otomatik yedek klasörü gibi, yedekteki ayar kaydının değil bu telefonun değeridir.
- Senkron kapalıyken geri yükleme bugünkü gibidir; zamanlar değişmez.

## Güvenlik

[Güvenlik tasarımına](guvenlik-tasarimi.md) gelecekler:

- **Ağ bölümü:** iki ağ yolu: sızıntı kontrolü ve kullanıcının girdiği WebDAV sunucusuyla senkron. Ağ kodu iki dosyada.
- **Tehdit modeline yeni satırlar:**
  - *WebDAV sunucusu ya da sunucuyu ele geçiren:* dosya adlarını (cihaz kimlikleri), boyutları, değişme zamanlarını, IP adresini görür; dosyaları silebilir, eskileriyle değiştirebilir, saklayabilir. İçeriği okuyamaz, değiştiremez, uyduramaz. Eski bir dosya yalnızca kendisinden yeni değişiklikleri geri getiremez, çünkü birleştirme yalnızca daha yeniyi uygular ve silme kayıtları yerelde durur; en kötü sonuç bir değişikliğin öteki telefona geç ulaşmasıdır. Ana parolayı çevrimdışı deneyebilir (otomatik yedekteki gibi; Argon2id).
  - *Ağdaki saldırgan:* HTTPS ve sistem sertifikaları; yönlendirme izlenmez; Basic kimlik bilgisi yalnızca TLS içinde gider.
  - *Kullanılmayan telefonun dosyası ve sunucunun dosya geçmişi:* eski üst bilgiyle, yani eski parolayla açılır ve kasa anahtarını verir; o anahtar sonraki dosyaları da açar. Parola değişikliği iptal değildir ([Hedef olmayanlar](#hedef-olmayanlar)).
  - *Çalınan ya da kaybolan telefon, kasası açılmış:* senkron bilgileri kasada olduğu için eşitlemeye devam eder ve yeni kayıtları alır. Tek çare, o telefonun uygulama parolasını sunucuda iptal etmek; kılavuz ve kurulum açıklaması bunu söyler.
- **Uygulama parolası** kasanın içinde, ayar kaydında şifreli durur; kasa açıkken bellekte. Elle ve otomatik yedeğe girer (yedek şifreli). Günlüğe, hata mesajına ve senkron dosyasına girmez.
- **Bilinen sınırlara:** saat farkı (yeni olan kazanır kuralı telefonun saatine güvenir; 24 saatten ilerisi alınmaz); aynı kayıt iki telefonda eşitlemeler arasında değişirse eski olan değişiklik kaybolur (yalnızca parola, geçmişe kurtarılır); silme kayıtlarının sayısı ve zamanları veritabanında şifresiz; veritabanına yazabilen biri 24 saate kadar ileri tarihli bir silme ya da sürümle o kaydı bütün telefonlarda etkileyebilir (bugün yalnızca o telefonu etkiliyordu); sunucu bir telefonun dosyasını saklayarak değişikliklerin yayılmasını geciktirebilir; parola değişikliği iptal değildir.
- **Kullanım koşulları sürüm 3** ve **gizlilik bildirimi:** "Verilerin bu telefonda" ve "İnternete yalnızca sızıntı kontrolü için çıkar" cümleleri senkronla doğru olmaktan çıkar. Yeni metin: senkronu açarsan şifreli kasa kopyası senin seçtiğin sunucuya gider; KeyKey ve geliştiricileri o sunucuya erişmez; sunucunun güvenliği ve senkronun yedek yerine geçmediği. Güncellemeden sonraki ilk açılışta koşullar bir kez yeniden sorulur.

## Sürümler

- Uygulama 1.8.0 (12).
- Veritabanı şeması bir artar: `tombstones` tablosu, `vault_meta.password_changed_at` ve `recovery_changed_at`. Göç testleri.
- Ayar kaydı sürüm 7 (senkron bilgileri). Ayar kaydı elle ve otomatik yedeğe girdiği için [yedeğin içerik sürümü kuralı](guvenlik-tasarimi.md#yedek-biçimi) işler: 1.7.0 sürüm 7 ayar kaydını okuyamaz, bu yüzden 1.8.0'ın elle ve otomatik yedekleri **sürüm 4** ile yazılır (`sync` olmadan); senkron dosyası sürüm 4 ve `sync` ile. 1.7.0 ikisine de "bozuk" değil "daha yeni yedek" der. Kayıt içerik sürümlerini yedeğin içerik sürümüyle birlikte sabitleyen test güncellenir.

## Testler

Birim ve ekran testleri (cihazsız):

- **Dosya biçimi:** sürüm 4 yazma ve okuma; `sync` zorunlu ve yalnızca sürüm 4'te; yanlış cihaz kimliği, `settings` kaydı, yinelenen silme kaydı, bilinmeyen alan reddedilir; sürüm 5 "daha yeni"; senkron dosyası Geri yükle'de yedek gibi açılır.
- **Silme kayıtları:** kalıcı silme, çöpü boşaltma ve 30 günlük temizlik silme kaydı yazar; ayar kaydı yazmaz; şema göçü eski veritabanını korur.
- **Birleştirme** (sahte taşıyıcıyla, iki ve üç telefon): yeni olan kazanır; eşit zamanda bayt kuralı her sırada aynı sonucu verir; silme kaydı eski değişikliği siler, yeni değişiklik silmeyi yener ve silme kaydı kalkar; kalıcı silinen kayıt eski bir dosyadan geri gelmez; açılmayan kayıt o dosyayı yok saydırır, öteki dosyalar birleşir; tür çakışması; birleştirme sırasında hata olursa kasa değişmez; değişmeyen durumda yükleme yapılmaz; değişmeyen `ETag` indirilmez.
- **Üst bilgi:** parola değişikliği öteki telefona geçer, yeni parola kasayı açar, eski açmaz; kurtarma yenilemesi sonraki bir parola değişikliğiyle geri alınmaz (yuvalar ayrı); eski zaman alınmaz; iki tarafta zaman yokken farklı yuva alınmaz ve uyarı çıkar; başka `vaultId` alınmaz; parmak izi yuvası kalır.
- **Saat ve kurtarma:** 24 saatten ileri zamanlı dosya yok sayılır ve bildirilir; eşzamanlı düzenlemede kaybeden parola kazananın geçmişine girer, iki telefon aynı kurtarmayı yapınca tek sonuca varılır ve kural yeniden tetiklenmez; parola aynıysa ya da geçmişteyse hiçbir şey eklenmez.
- **Geri yükleme:** senkron açıkken birleştirme silme kaydını kaldırır ve zamanı yeniler, geri gelen kayıt eşitlemede silinmez; değiştirme aynı kasada senkronu açık tutar ve yedekte olmayan kayıtları silmez; başka kasada senkronu kapatır; kendi sunucu dosyasındaki kayıtlar geri gelir.
- **WebDAV istemcisi** (testte yerel bir HTTP sunucusu): `PROPFIND` yanıtları (Nextcloud, Apache `mod_dav`, rclone örnekleri; farklı ad alanı önekleri), `PUT` → geri okuma → `MOVE`; `MOVE` yoksa doğrudan yazma; 401, 403, 404, 405, 507, 3xx, zaman aşımı, büyük yanıt, `http://` reddi (yerel adres hariç); hata mesajında kimlik bilgisi ve yol yok.
- **Akışlar:** senkronu açma (boş klasör, aynı kasa, başka kasa, birden çok kasa, açıklama penceresi); yeni telefonu kurma; başka kasası olan telefonu katma (kayıtları kaybolmaz, eski parola artık açmaz, parmak izi kapanır); cihaz kaldırma; senkronu kapatma; yedekten değiştirince senkronun kapanması; kilitlenince eşitlemenin bırakılması; tetikler (açılış, değişiklik + 5 sn, öne gelme + 60 sn, elle).
- **Ağ denetimi:** iki dosya izinli, başka yerde ağ kodu yok.
- **Erişilebilirlik:** yeni ekranlar için mevcut erişilebilirlik testleri (320 dp, %200 yazı, etiketler).

Cihazda:

- Entegrasyon testi: telefonda çalışan yerel bir WebDAV test sunucusuyla (`127.0.0.1`) iki kasa durumunu birleştirme, gerçek SQLite ve libsodium ile.
- Gerçek kullanıcı yolu, Android 17 ve 11 emülatörlerinde: bilgisayarda bir WebDAV sunucusu (rclone `serve webdav`), emülatöre `adb reverse` ile `127.0.0.1` üzerinden. İki emülatör aynı anda çalışmadığı için ikinci telefon, aynı emülatörde silinip senkrondan kurularak taklit edilir: kayıt ekle → öteki "telefon" görür; sil → geri gelmez; parola değiştir → öteki yeni parolaya geçer.
- Gerçek bir Nextcloud ile deneme proje sahibinin hesabına bağlı; yapılamazsa yayın raporunda yazar.

## Belgeler

Güvenlik tasarımı (ağ, tehdit modeli, yedek biçimi sürüm 4, silme kayıtları, depolama tabloları, senkron bölümü, bilinen sınırlar), kullanım koşulları sürüm 3, gizlilik bildirimi (Türkçe ve İngilizce), kılavuz (Senkron bölümü, "Eşitleme yok" maddesinin kalkması), bağımlılıklar (`xml`), değişiklik günlüğü, mağaza sürüm notu, yol haritası.

## Uygulayana kalanlar

- Ekranların düzeni ve metinlerin son hali, mevcut ayar ekranlarının kalıbıyla.
- Taşıyıcı arayüzünün tam imzası, birleştirmenin hangi sınıfta durduğu.
- `deviceName` için platform kanalı (mevcut bir kanal varsa ona eklenir).
- WebDAV örnek yanıtlarının tam metinleri (test verisi).

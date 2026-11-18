# Otomatik yedek

Faz 12'nin tasarımı. Takip: Faz 12 takip issue'su. Hedef sürüm `1.2.0`.

Proje sahibi 2026-11-18'de sıradaki işi bana bıraktı ("kendi planlamanı yapıp uygula"). Aşağıdaki seçimler benim; her birinin gerekçesi yanında yazılı.

## Neden

Sunucu olmadığı için telefon kaybolursa tek kopya kullanıcının aldığı yedektir. Bugün yedek elle alınıyor; hatırlatıcı ancak 14 gün sonra uyarıyor. Arada eklenen parolalar ve 2FA hesapları telefonla birlikte gider.

Otomatik yedek, kullanıcının bir kez seçtiği klasöre kasa değiştikçe kendiliğinden yedek yazar. Klasör Syncthing, Nextcloud ya da benzeri bir eşitleme uygulamasının klasörüyse yedek telefonun dışına da çıkar. KeyKey'in kendisi yine internete çıkmaz.

## Hedefler

- Kullanıcı bir kez klasör seçer. Sonrasında kasa açıkken parola veya 2FA kayıtları değişince yedek kendiliğinden yazılır.
- Elle alınan yedekle aynı `.keykey` biçimi ve aynı anahtar. Aynı geri yükleme ekranıyla, alındığı andaki ana parola veya kurtarma anahtarıyla açılır.
- Eski yedekler bir süre kalır. Yanlışlıkla silinen bir şey bir sonraki yedekle birlikte kaybolmaz.
- Hata sessiz kalmaz: yazılamayan yedek ayarlarda ve yedek kartında görünür.

## Hedef olmayanlar

- **Kasa kilitliyken arka planda yedek.** Yedeği şifrelemek için kasa anahtarı gerekir. Anahtar yalnızca kasa açıkken bellekte durur.
- **İnternet ya da bulut API'si.** Eşitleme, klasörü sağlayan uygulamanın işi.
- **Google Drive'a doğrudan yazma.** Drive, Android'in klasör seçicisine klasör olarak çıkmıyor (aşağıda [Drive](#drive)).

## Karşı hedefler

Bunlardan biri olursa iş çalışsa bile başarısızdır:

- Kasa anahtarının ya da yedek anahtarının kasa kilitliyken erişilebilir bir yerde durması.
- Kullanıcının elle aldığı yedeklere ya da klasördeki başka dosyalara dokunulması.
- Yarım yazılmış ya da bozuk bir yedeğin, son iyi yedek silinerek onun yerine geçmesi.
- `INTERNET` ya da depolama izni.

## Yaklaşımlar

| Yaklaşım | Artısı | Eksisi |
|---|---|---|
| **1. Seçilen klasöre günlük dosyalar** (seçilen) | Eski günler kalır. Yeni dosya doğrulanmadan eskisi silinmez. Tehdit modeli değişmez. Aegis'in otomatik yedeği de böyle çalışır. | Drive klasör olarak seçilemiyor. Telefonun dışına çıkmak için eşitleme uygulaması gerekir. |
| 2. Bir kez seçilen tek dosyanın üzerine yazmak | Drive dahil her yerde çalışır. | Tek kopya kalır. Yanlış bir durum (silinen kayıtlar) ya da yarım bir yazma son iyi yedeği bozar. Drive sürüm geçmişi tutar, yerel klasörler tutmaz. |
| 3. Arka plan işi (WorkManager), kasa kilitliyken de | Uygulama açılmasa da çalışır. | Anahtarın kilitli kasanın dışında saklanmasını gerektirir. Tehdit modelini değiştirir. Reddedildi. |

**Seçim 1.** Bir parola yöneticisinde en kötü sonuç veri kaybı. Tek dosyanın üzerine yazmak, yedeği tam da gerektiği anda bozabilir. Drive eksikliği gerçek bir eksik. Telefonda Drive'ın klasör seçicide çıkıp çıkmadığı denenecek. Çıkmıyorsa 2. yaklaşım ayrı bir iş olarak eklenebilir: Drive kendi sürüm geçmişini tuttuğu için orada tek dosya kabul edilebilir.

## Tasarım

### Ne zaman yazılır

Kasa açıkken, otomatik yedek açıksa ve parola veya 2FA kayıtlarının son değişimi son yedekten yeniyse yazılır. Son yedek elle de alınmış olabilir. Ölçüt hatırlatıcıyla aynı: veritabanındaki şifresiz `updatedAt`, ayar kaydı sayılmaz.

Tetikler:

- **Kayıtlar değişince:** değişiklikten 5 saniye sonra. Peş peşe gelen değişiklikler, örneğin bir içe aktarma, tek yedekte toplanır.
- **Kasa açılınca:** otomatik doldurmanın kaydettiği değişiklikler ana uygulamanın listelerinden geçmez. Önceki oturumda kilitlenmeden önce yetişmeyen yedek de burada yazılır.
- **Ana parola değişince:** hemen. Böylece en yeni yedek yeni parolayla açılır.

Aynı anda tek yedek yazılır. Yazarken yeni bir değişiklik gelirse iş bitince bir kez daha yazılır. Kasa kilitlenirse bekleyen yedek iptal olur, bir sonraki açılışta yazılır.

### Nasıl yazılır

1. Yedek, elle yedekteki gibi kasa açıkken bellekte üretilir (`BackupService.create`).
2. Klasörde yeni bir dosya açılır: `keykey-otomatik-2026-11-18-153012.keykey`. Arayüz İngilizceyse önek `keykey-auto`.
3. Baytlar yazılır, geri okunur ve karşılaştırılır. Tutmazsa yeni dosya silinmeye çalışılır, eski yedeklere dokunulmaz. Baytlar her durumda bellekte sıfırlanır.
4. Başarılıysa son yedek zamanı ayar kaydına yazılır. Kart ve hatırlatıcı bunu kullanır. Ardından eski otomatik yedekler budanır.

### Budama

- Yalnızca adı otomatik yedek kalıbına tam uyan dosyalar dikkate alınır: `keykey-otomatik-` ya da `keykey-auto-` öneki, `YYYY-AA-GG-SSddss` zamanı ve `.keykey` uzantısı. Elle alınan yedekler (`keykey-yedek-…`) ve başka her dosya dokunulmaz kalır.
- Her günün en yeni dosyası kalır, aynı günün eskileri silinir.
- En yeni 14 gün kalır, daha eskileri silinir. Kayıt değişmeyen günlerde yedek yazılmadığı için bu, takvimde 14 günden uzun bir geçmiş demek.
- Budama ancak yeni yedek doğrulandıktan sonra çalışır. Silme başarısız olursa yedek yine başarılı sayılır, bir sonraki yedekte yeniden denenir.

### Klasör nerede tutulur

- Klasör Android'in klasör seçicisiyle (`ACTION_OPEN_DOCUMENT_TREE`) seçilir. KeyKey kalıcı okuma ve yazma izni alır (`takePersistableUriPermission`). Depolama izni gerekmez.
- Klasörün adresi ve görünen adı ayar kaydında, yani kasanın içinde şifreli tutulur (ayar kaydı sürüm 5). Kasa kilitliyken yedek zaten yazılamadığı için bu yeterli.
- Otomatik yedek kapatılınca ya da klasör değiştirilince eski klasörün kalıcı izni bırakılır. Klasördeki yedekler silinmez.
- Yedekten geri yüklenen bir kasa eski telefonun klasör adresini getirebilir. Bu telefonda o adres için izin yoktur. İlk denemede "klasöre erişilemiyor" durumu gösterilir, kullanıcı klasörü yeniden seçer.

### Hata

- Yazma başarısız olursa durum o oturum boyunca "yazılamadı" olur. İzin kalkmış, klasör silinmiş ya da yer kalmamış olabilir. Ayarlardaki satır ve yedek kartı bunu gösterir. Kart, kullanıcıyı klasörü yeniden seçmeye ya da elle yedeğe yönlendirir.
- Son yedek zamanı ilerlemediği için hatırlatıcı her zamanki kuralla çalışmaya devam eder.

### Arayüz

Ayarlar → Yedek ve aktarım grubunun başında bir **Otomatik yedek** satırı:

```text
[⟳] Otomatik yedek                          [ ○ ]
    Kapalı. Kasa değişince seçtiğin klasöre şifreli yedek yazar.

[⟳] Otomatik yedek                          [ ● ]
    KeyKey-yedekler klasörüne · bugün 15:30
    (hata varsa:) Son yedek yazılamadı. Klasörü yeniden seç.
```

- **Açmak:** önce kısa bir açıklama penceresi çıkar. Ne yapıldığını, dosyaların kasa parolanla şifreli olduğunu ve klasörü bir eşitleme uygulamasıyla telefonun dışına çıkarmayı anlatır; Drive'ın listede çıkmayabileceğini de söyler. "Klasör seç" klasör seçiciyi açar. Seçiciden vazgeçilirse anahtar kapalı kalır. Seçilince ilk yedek hemen yazılır.
- **Açıkken satıra dokunmak:** "Klasörü değiştir", "Şimdi yedekle" ve "Kapat" seçenekleri.
- **Yedek kartı:** otomatik yedek açıksa durum yazısının altında klasör adı görünür. Son yazma başarısızsa uyarı gösterilir.

## Güvenlik

- Biçim, anahtar ve şifreleme elle yedekle aynı. Kripto çekirdeğinde değişiklik yok.
- Yedek yalnızca kasa açıkken üretilir. Arka planda çalışan bir iş ve kasa dışında saklanan bir anahtar yok.
- Seçilen klasör başka uygulamalarca okunabilir; eşitleme uygulaması da dosyayı başka cihazlara taşır. Elle alınıp Drive'a konan yedek için de durum aynı. Dosyayı ele geçiren biri ana parolayı çevrimdışı deneyebilir; Argon2id bunu yavaşlatır. Fark şu: otomatik yedekle böyle kopyaların sayısı artar. Kullanıcıya açıklama penceresinde söylenir.
- **Eski parola:** her yedek alındığı andaki parolayla açılır. Parola değişince yeni yedekler yeni parolayla yazılır. Klasördeki eski yedekler budanana kadar, yani 14 değişiklik günü boyunca, eski parolayla açılmaya devam eder. Parola sızdığı için değiştirildiyse klasördeki eski yedekler elle silinmeli. Parola değiştirme ekranı bunu söyler.
- Kalıcı izin yalnızca seçilen klasör için alınır, kapatınca bırakılır.

## Denemeler

- **Birim testleri:** dosya adı ve budama kuralı, ayar kaydı sürüm 5 (eski sürümler okunmaya devam eder), otomatik yedek denetleyicisi. Denetleyici sahte bir klasör API'siyle sınanır: tetikler, bekleme, tek iş, hata durumu, kilitlenince iptal, son yedek zamanı.
- **Arayüz testleri:** ayar satırı, açıklama penceresi, açma, kapatma, klasör değiştirme, hata gösterimi.
- **Emülatör:** Android 17 ve 11 üzerinde klasör seçme, yazma, budama ve izin kalkınca hata. Android 11'de kök klasör ve İndirilenler kökü seçilemiyor.
- **Telefon (proje sahibiyle):** Samsung'un "Dosyalarım" klasörü, Drive'ın seçicide çıkıp çıkmadığı ve otomatik yedeğin geri yüklenmesi.

**Emülatör sonuçları (2026-11-18):** [`auto-backup-device-test.sh`](../scripts/auto-backup-device-test.sh) Android 17 (`Medium_Phone_API_37.0`) ve Android 11 (`KeyKey_API_30`) üzerinde geçti. Betik `integration_test/auto_backup_test.dart`'ı çalıştırır ve seçicilere bir kullanıcı gibi dokunur. Sınanan yol:

1. Klasör seçicide yeni bir klasör açılıp seçilir ve izin verilir.
2. Gerçek kasanın yedeği klasöre yazılır, geri okunarak doğrulanır, geri yükleme ekranının yoluyla parolayla açılır.
3. Aynı günün eski dosyası budanır.
4. Elle yedek, ortak dosyaya taşınan seçici yardımcısıyla kaydedilir.
5. Kalıcı izin bırakılınca `hasAccess` `false` döner.

İki gözlem:

- **Geçici izin:** Android seçiciden gelen geçici izni etkinlik kapanana kadar tutuyor. Kalıcı izin bırakıldıktan sonra aynı oturumda yazma yine geçebiliyor. Denetleyici bu yüzden yazmadan önce kalıcı izne bakıyor.
- **Android 11'in belge ekranı:** klasör öğelerine gelen adb dokunuşlarını yok sayıyor, bu yüzden betik öğelere dokunmuyor, klasörü seçicinin "Yeni klasör" düğmesiyle açıyor. Bu bir test sınırı; parmakla dokunma etkilenmiyor.

İki emülatörde de bütün entegrasyon testleri yeşil.

## Uygulayana kalanlar

- Bekleme süresi (5 sn) ve kaç günün tutulacağı (14) kodda sabit. Ayar olarak açılmaz.
- Pencerelerin ve satırların tam metinleri.
- Kotlin tarafında klasör işlemleri `DocumentsContract` ile yapılır, yeni kütüphane eklenmez.

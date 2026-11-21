# Gizlilik bildirimi

**Geçerlilik:** KeyKey 1.0 ve sonrası · **Son güncelleme:** 2026-11-20 · English: [privacy.md](privacy.md)

KeyKey hiçbir veri toplamaz. Hesap ve KeyKey'in bir sunucusu yoktur; kasan bu telefonda, şifreli durur. KeyKey 1.6.0'dan beri internet iznine sahiptir ve internete yalnızca senin açtığın iki özellik için çıkar: parola raporundaki [sızıntı kontrolü](#sızıntı-kontrolü) ve açarsan [senkron](#senkron). Sızıntı kontrolünde parolaların ve kasan cihazdan çıkmaz; senkronda kasanın yalnızca ana parolanla şifrelenmiş bir kopyası senin seçtiğin sunucuya gider. Ağ kodu iki dosyadadır ve başka bir yerde ağ kodu olmadığını her derlemede bir test denetler; kaynak koddan herkes doğrulayabilir.

## Toplanmayanlar

- Hesap, kayıt veya kimlik bilgisi yok. KeyKey'i kullanmak için hesap açılmaz.
- Analitik, kullanım istatistiği, reklam kimliği ve reklam yok.
- Hata raporu gönderimi yok. Bir hata bildirmek istersen GitHub'da issue açarsın; neyi paylaşacağına sen karar verirsin.
- Üçüncü taraf izleme kütüphanesi yok.

## Cihazda tutulanlar

- Girdiğin parolalar, kartlar, güvenli notlar, 2FA hesapları ve ayarlar yalnızca senin cihazında, ana parolandan türetilen anahtarla şifrelenmiş bir veritabanında durur. Şifreleme ayrıntıları [güvenlik tasarımında](guvenlik-tasarimi.md).
- Android'in bulut yedeği kapalıdır; kasa Google hesabına yedeklenmez.
- Senkronu açarsan klasör adresi, kullanıcı adı ve uygulama parolası kasanın içinde, ayar kaydında şifreli durur. Kasanın yedeğine de girer (yedek şifreli).
- İki istisna var, ikisi de uygulamanın kendi klasöründe ayrı, şifresiz küçük birer dosya ve başka hiçbir bilgi içermez:
  - Tema seçimin (sistem, açık ya da koyu): kilit ekranı da seçtiğin temayla açılsın diye.
  - [Kullanım koşullarını](kosullar.md) kabul ettiğin: yalnızca kabul edilen koşulların sürüm numarası. Koşullar kasa açılmadan önce sorulduğu için kasanın içinde tutulamaz.
- Uygulamayı kaldırınca bütün verisi silinir. Önce bir yedek almazsan veri geri getirilemez.

## İzinler

| İzin | Neden |
|---|---|
| Kamera | Yalnızca 2FA QR kodu tararken istenir. Görüntü kaydedilmez, cihazdan çıkmaz. |
| Biyometri (parmak izi) | Kasayı parmak iziyle açmak için. Parmak izinin kendisi KeyKey'e hiç ulaşmaz; Android yalnızca "doğrulandı" bilgisini verir. |
| Bindirme pencerelerini gizleme | KeyKey ekrandayken başka uygulamaların üstüne pencere çizip dokunuşları kandırmasını önlemek için. |
| İnternet | Parola raporundaki sızıntı kontrolü için, sen dokununca; açarsan senkron için, yalnızca senin girdiğin sunucuyla. Ne gittiği aşağıda: [sızıntı kontrolü](#sızıntı-kontrolü), [senkron](#senkron). |

Konum, rehber, depolama ve bütün uygulamaları görme (`QUERY_ALL_PACKAGES`) izinleri istenmez.

## Otomatik doldurma

KeyKey'i doldurma servisi olarak seçersen Android, bir giriş formuna dokunduğunda formun yapısını (alan türleri, uygulamanın paket adı, tarayıcıdaysa sitenin alan adı) KeyKey'e verir. KeyKey bunu yalnızca doğru kaydı önermek için kullanır ve saklamaz. Kaydetme önerisini kabul edersen yalnızca senin onayladığın kullanıcı adı ve parola kasaya eklenir. Kayıtları uygulamalara bağlayabilmek için KeyKey ana ekranda simgesi olan uygulamaların listesini görebilir.

## Pano

Kopyaladığın parola, kart bilgisi, not ve 2FA kodları panoda "hassas" olarak işaretlenir (Android 13 ve üstü, klavye önizlemesinde görünmez) ve 30 saniye sonra silinir.

## Sızıntı kontrolü

Parola raporunda **İnternetten denetle**'ye dokunursan KeyKey, parolalarının bilinen veri sızıntılarında görülüp görülmediğini [Have I Been Pwned](https://haveibeenpwned.com/Passwords)'ın Pwned Passwords hizmetine sorar. Sen dokunmadan hiçbir şey gönderilmez; otomatik ya da arka planda denetim yoktur.

- **Ne gider:** Her parolanın SHA-1 özetinin yalnızca ilk 5 karakteri (örneğin `5BAA6`). Parolanın kendisi, özetin geri kalanı, kayıt adı, kullanıcı adı ve site gitmez. Karşılaştırma telefonda yapılır (k-anonimlik).
- **Kime gider:** `api.pwnedpasswords.com` (Have I Been Pwned; hizmet Cloudflare üzerinden sunuluyor), yalnızca HTTPS ile.
- **Karşı taraf ne görür:** IP adresin, sorulan önekler ve zamanı. İstekte `User-Agent: KeyKey` dışında tanımlayıcı, çerez ya da hesap yoktur. Bir IP adresinden gelen önek kümesi bir kasanın parmak izi gibi kullanılabilir; tek başına parolayı ele vermez.
- **Ne saklanır:** Hiçbir şey. Sonuç yalnızca bellekte durur; ekrandan çıkınca ya da kasa kilitlenince silinir.

Veri Have I Been Pwned'ındır ve CC BY 4.0 lisansıyla kullanılır.

## Senkron

Ayarlar → **Senkron**'u açarsan KeyKey, kasanın şifreli bir kopyasını senin girdiğin WebDAV klasörüne (Nextcloud, ownCloud ya da başka bir WebDAV sunucusu) yazar ve aynı klasörü kullanan telefonlarının dosyalarını okur. Senkron kapalıyken hiçbir şey gönderilmez. Tasarım ayrıntıları [senkron tasarımında](senkron.md).

- **Ne gider:** Kasanın, yedekle aynı biçimde ana parolanla şifrelenmiş kopyası: kayıtlar, silinen kayıtların kimlikleri ve zamanları, telefonun modeli (örneğin SM-G780G). Dosya adında bu kurulumun rastgele 6 karakterlik kimliği vardır (`keykey-sync-a1b2c3.keykey`). Kullanıcı adı ve uygulama parolası sunucuya giriş için her istekte HTTPS içinde gider; dosyaya yazılmaz.
- **Kime gider:** Yalnızca senin girdiğin sunucuya, yalnızca HTTPS ile (yönlendirme izlenmez). KeyKey'in ya da geliştiricilerinin bir sunucusu yoktur; geliştiriciler dosyalara erişmez.
- **Karşı taraf ne görür:** IP adresin, dosya adları, boyutları ve değişme zamanları. İçeriği ana parolan olmadan okuyamaz ve değiştiremez; ana parolanı çevrimdışı deneyebilir, bu yüzden ana parolanın güçlü olması önemlidir.
- **Ne saklanır:** Sunucuda her telefonun bir dosyası. Senkronu kapatırken bu telefonun dosyasını da silebilirsin; sunucunun dosya geçmişi ve çöp kutusu KeyKey'in erişiminde değildir.

## Dosyalar

Yedek, dışa ve içe aktarma dosyaları yalnızca Android'in dosya seçicisiyle senin seçtiğin yere yazılır ya da oradan okunur. Drive gibi bir konum seçersen dosyayı oraya Android'in kendisi taşır; KeyKey dosyayı hiçbir yere göndermez. Şifresiz dışa aktarma çift onay ister ve dosyanın şifresiz olduğu açıkça söylenir.

## Bağlantılar

Bir kayıtta **Siteyi aç**'a ya da Ayarlar'ın Hakkında bölümündeki bir bağlantıya dokunursan KeyKey yalnızca o adresi tarayıcına verir, sayfayı tarayıcı yükler. Başka hiçbir şey aktarılmaz; sayfayı KeyKey değil tarayıcın yükler.

## Değişiklikler

Bu bildirim değişirse yeni hali bu dosyada ve [değişiklik günlüğünde](../CHANGELOG.md) yayımlanır. İnternete çıkan yeni bir özellik eklenirse bildirimde açıkça yazar ve kullanım koşulları yeniden sorulur.

## İletişim

Sorular için GitHub'da issue aç: https://github.com/aaudraa/KeyKey/issues. Bir güvenlik açığı bildirmek için [güvenlik politikasına](../../.github/SECURITY.md) bak.

## Mağaza formları

Dağıtım kararı (#100, 2026-11-09): 1.0 GitHub Releases'ta, sonra F-Droid. F-Droid başvurusu 2026-11-18'de kabul edilmedi ([fdroiddata!57995](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/57995); 3 ay kuralı ve benzersiz özellik); aşağıdaki F-Droid yanıtı yeniden başvuru için duruyor. IzzyOnDroid'e başvurulmuyor (2026-11-17): yapay zekâyla yazılmış kodu kabul etmiyor ([F-Droid tasarımı](f-droid.md#izzyondroid-neden-yok)). Play Store şimdilik yok; Play yanıtı ileride gerekirse diye duruyor.

- **GitHub Releases ve Obtainium:** Gizlilik formu istemiyor; bu bildirim yeterli.

- **Play Store veri güvenliği formu:** "Uygulama kullanıcı verisi toplamıyor." Sızıntı kontrolü Play'e gidilirse formda yeniden değerlendirilir: giden yalnızca 5 karakterlik özet öneki, HTTPS ile (aktarımda şifreli), kullanıcı dokununca; kimse saklamaz. Senkron verisi geliştiriciye değil, kullanıcının kendi seçtiği sunucuya, uçtan uca şifreli gider. Kullanıcı veri silme talebinde bulunabilir: uygulama içinden kayıt silme ve uygulamayı kaldırma.
- **F-Droid:** `NonFreeNet` anti-özelliği: sızıntı kontrolü özgür olmayan bir ağ hizmetine (Have I Been Pwned) bağlanır. Senkron kullanıcının kendi WebDAV sunucusuna bağlanır; yeni bir anti-özellik gerektirmez. İzleme yok, özgür olmayan bağımlılık yok. SQLite ve libsodium kaynaktan derleniyor; Flutter motoru F-Droid'in izin verdiği hazır parçalardan. Başvuru Faz 10'da (#119): F-Droid kaynaktan derler, derlemesi bizimkiyle birebir aynı olduğu için bizim imzalı APK'mızı dağıtır.

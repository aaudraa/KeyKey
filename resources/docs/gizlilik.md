# Gizlilik bildirimi

**Geçerlilik:** KeyKey 1.0 ve sonrası · **Son güncelleme:** 2026-11-09 · English: [privacy.md](privacy.md)

KeyKey hiçbir veri toplamaz ve hiçbir yere göndermez. Uygulamanın internet izni yoktur, bu yüzden istese de cihazdan veri çıkaramaz. Bunu kurulu uygulamanın izinlerinden ya da kaynak koddan herkes doğrulayabilir.

## Toplanmayanlar

- Hesap, kayıt veya kimlik bilgisi yok. KeyKey'i kullanmak için hesap açılmaz.
- Analitik, kullanım istatistiği, reklam kimliği ve reklam yok.
- Hata raporu gönderimi yok. Bir hata bildirmek istersen GitHub'da issue açarsın; neyi paylaşacağına sen karar verirsin.
- Üçüncü taraf izleme kütüphanesi yok.

## Cihazda tutulanlar

- Girdiğin parolalar, 2FA hesapları, notlar ve ayarlar yalnızca senin cihazında, ana parolandan türetilen anahtarla şifrelenmiş bir veritabanında durur. Şifreleme ayrıntıları [güvenlik tasarımında](guvenlik-tasarimi.md).
- Android'in bulut yedeği kapalıdır; kasa Google hesabına yedeklenmez.
- Uygulamayı kaldırınca bütün verisi silinir. Önce bir yedek almazsan veri geri getirilemez.

## İzinler

| İzin | Neden |
|---|---|
| Kamera | Yalnızca 2FA QR kodu tararken istenir. Görüntü kaydedilmez, cihazdan çıkmaz. |
| Biyometri (parmak izi) | Kasayı parmak iziyle açmak için. Parmak izinin kendisi KeyKey'e hiç ulaşmaz; Android yalnızca "doğrulandı" bilgisini verir. |
| Bindirme pencerelerini gizleme | KeyKey ekrandayken başka uygulamaların üstüne pencere çizip dokunuşları kandırmasını önlemek için. |

İnternet, konum, rehber, depolama ve bütün uygulamaları görme (`QUERY_ALL_PACKAGES`) izinleri istenmez.

## Otomatik doldurma

KeyKey'i doldurma servisi olarak seçersen Android, bir giriş formuna dokunduğunda formun yapısını (alan türleri, uygulamanın paket adı, tarayıcıdaysa sitenin alan adı) KeyKey'e verir. KeyKey bunu yalnızca doğru kaydı önermek için kullanır ve saklamaz. Kaydetme önerisini kabul edersen yalnızca senin onayladığın kullanıcı adı ve parola kasaya eklenir. Kayıtları uygulamalara bağlayabilmek için KeyKey ana ekranda simgesi olan uygulamaların listesini görebilir.

## Pano

Kopyaladığın parola ve 2FA kodları panoda "hassas" olarak işaretlenir (Android 13 ve üstü, klavye önizlemesinde görünmez) ve 30 saniye sonra silinir.

## Dosyalar

Yedek, dışa ve içe aktarma dosyaları yalnızca Android'in dosya seçicisiyle senin seçtiğin yere yazılır ya da oradan okunur. Drive gibi bir konum seçersen dosyayı oraya Android'in kendisi taşır; KeyKey internete çıkmaz. Şifresiz dışa aktarma çift onay ister ve dosyanın şifresiz olduğu açıkça söylenir.

## Değişiklikler

Bu bildirim değişirse yeni hali bu dosyada ve [değişiklik günlüğünde](../CHANGELOG.md) yayımlanır. İnternete çıkmak gerektiren bir özellik (örneğin senkron) eklenirse bu ayrı bir karar olur ve bildirimde açıkça yazar ([yol haritası](../yol-haritasi.md#10-sonrası)).

## İletişim

Sorular için GitHub'da issue aç: https://github.com/aaudraa/KeyKey/issues. Bir güvenlik açığı bildirmek için [güvenlik politikasına](../../.github/SECURITY.md) bak.

## Mağaza formları (taslak)

Dağıtım kararı (#100, 2026-11-09): 1.0 GitHub Releases'ta, sonra IzzyOnDroid ve F-Droid. Play Store şimdilik yok; Play yanıtı ileride gerekirse diye duruyor.

- **Play Store veri güvenliği formu:** "Uygulama kullanıcı verisi toplamıyor veya paylaşmıyor." Veri aktarımda şifrelenir sorusu: aktarım yok. Kullanıcı veri silme talebinde bulunabilir: uygulama içinden kayıt silme ve uygulamayı kaldırma.
- **F-Droid:** Beklenen anti-özellik yok. İnternet yok, izleme yok, özgür olmayan bağımlılık yok. SQLite ve libsodium kaynaktan derleniyor; Flutter motoru gibi kalan hazır parçalar F-Droid'in kendi derleme kurallarıyla #100'de ele alınacak.

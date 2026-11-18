# Gizlilik bildirimi

**Geçerlilik:** KeyKey 1.0 ve sonrası · **Son güncelleme:** 2026-11-17 · English: [privacy.md](privacy.md)

KeyKey hiçbir veri toplamaz ve hiçbir yere göndermez. Uygulamanın internet izni yoktur, bu yüzden istese de cihazdan veri çıkaramaz. Bunu kurulu uygulamanın izinlerinden ya da kaynak koddan herkes doğrulayabilir.

## Toplanmayanlar

- Hesap, kayıt veya kimlik bilgisi yok. KeyKey'i kullanmak için hesap açılmaz.
- Analitik, kullanım istatistiği, reklam kimliği ve reklam yok.
- Hata raporu gönderimi yok. Bir hata bildirmek istersen GitHub'da issue açarsın; neyi paylaşacağına sen karar verirsin.
- Üçüncü taraf izleme kütüphanesi yok.

## Cihazda tutulanlar

- Girdiğin parolalar, 2FA hesapları, notlar ve ayarlar yalnızca senin cihazında, ana parolandan türetilen anahtarla şifrelenmiş bir veritabanında durur. Şifreleme ayrıntıları [güvenlik tasarımında](guvenlik-tasarimi.md).
- Android'in bulut yedeği kapalıdır; kasa Google hesabına yedeklenmez.
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

İnternet, konum, rehber, depolama ve bütün uygulamaları görme (`QUERY_ALL_PACKAGES`) izinleri istenmez.

## Otomatik doldurma

KeyKey'i doldurma servisi olarak seçersen Android, bir giriş formuna dokunduğunda formun yapısını (alan türleri, uygulamanın paket adı, tarayıcıdaysa sitenin alan adı) KeyKey'e verir. KeyKey bunu yalnızca doğru kaydı önermek için kullanır ve saklamaz. Kaydetme önerisini kabul edersen yalnızca senin onayladığın kullanıcı adı ve parola kasaya eklenir. Kayıtları uygulamalara bağlayabilmek için KeyKey ana ekranda simgesi olan uygulamaların listesini görebilir.

## Pano

Kopyaladığın parola ve 2FA kodları panoda "hassas" olarak işaretlenir (Android 13 ve üstü, klavye önizlemesinde görünmez) ve 30 saniye sonra silinir.

## Dosyalar

Yedek, dışa ve içe aktarma dosyaları yalnızca Android'in dosya seçicisiyle senin seçtiğin yere yazılır ya da oradan okunur. Drive gibi bir konum seçersen dosyayı oraya Android'in kendisi taşır; KeyKey internete çıkmaz. Şifresiz dışa aktarma çift onay ister ve dosyanın şifresiz olduğu açıkça söylenir.

## Bağlantılar

Bir kayıtta **Siteyi aç**'a ya da Ayarlar'ın Hakkında bölümündeki bir bağlantıya dokunursan KeyKey yalnızca o adresi tarayıcına verir, sayfayı tarayıcı yükler. Başka hiçbir şey aktarılmaz; KeyKey'in kendisi yine internete çıkmaz.

## Değişiklikler

Bu bildirim değişirse yeni hali bu dosyada ve [değişiklik günlüğünde](../CHANGELOG.md) yayımlanır. İnternete çıkmak gerektiren bir özellik (örneğin senkron) eklenirse bu ayrı bir karar olur ve bildirimde açıkça yazar ([yol haritası](../yol-haritasi.md#10-sonrası)).

## İletişim

Sorular için GitHub'da issue aç: https://github.com/aaudraa/KeyKey/issues. Bir güvenlik açığı bildirmek için [güvenlik politikasına](../../.github/SECURITY.md) bak.

## Mağaza formları

Dağıtım kararı (#100, 2026-11-09): 1.0 GitHub Releases'ta, sonra F-Droid. F-Droid başvurusu 2026-11-18'de kabul edilmedi ([fdroiddata!57995](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/57995); 3 ay kuralı ve benzersiz özellik); aşağıdaki F-Droid yanıtı yeniden başvuru için duruyor. IzzyOnDroid'e başvurulmuyor (2026-11-17): yapay zekâyla yazılmış kodu kabul etmiyor ([F-Droid tasarımı](f-droid.md#izzyondroid-neden-yok)). Play Store şimdilik yok; Play yanıtı ileride gerekirse diye duruyor.

- **GitHub Releases ve Obtainium:** Gizlilik formu istemiyor; bu bildirim yeterli.

- **Play Store veri güvenliği formu:** "Uygulama kullanıcı verisi toplamıyor veya paylaşmıyor." Veri aktarımda şifrelenir sorusu: aktarım yok. Kullanıcı veri silme talebinde bulunabilir: uygulama içinden kayıt silme ve uygulamayı kaldırma.
- **F-Droid:** Beklenen anti-özellik yok. İnternet yok, izleme yok, özgür olmayan bağımlılık yok. SQLite ve libsodium kaynaktan derleniyor; Flutter motoru F-Droid'in izin verdiği hazır parçalardan. Başvuru Faz 10'da (#119): F-Droid kaynaktan derler, derlemesi bizimkiyle birebir aynı olduğu için bizim imzalı APK'mızı dağıtır.

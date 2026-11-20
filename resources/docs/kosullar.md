# Kullanım koşulları

**Sürüm:** 3 · **Tarih:** 2026-11-20 · English: [terms.md](terms.md)

KeyKey bu koşulları kasa kurulmadan ya da açılmadan önce bir kez gösterir; "Okudum, anladım ve kabul ediyorum." işaretlenmeden devam edilmez. Ayarlar → Hakkında → **Kullanım koşulları**'ndan yeniden okunabilir. Uygulamadaki metinle bu dosya aynıdır; koşullar değişirse sürüm numarası artar ve uygulama yeni metni bir kez daha sorar. Verilerle ilgili ayrıntılar [gizlilik bildiriminde](gizlilik.md), lisansın tamamı [LICENSE](../../LICENSE) dosyasında.

KeyKey'i kullanmaya başlamadan önce lütfen oku. Kısa tuttuk; her madde KeyKey'in gerçekte nasıl çalıştığını anlatıyor.

## Verilerin senin elinde

Parolaların, 2FA hesapların, kartların ve notların bu telefondaki kasada durur. Yedek ya da dışa aktarma dosyası yalnızca sen istersen oluşur ve senin seçtiğin yere kaydedilir. KeyKey hesap açtırmaz, sunucusu yoktur, reklam göstermez, kullanım bilgisi toplamaz. İnternete yalnızca senin açtığın özellikler için çıkar: parola raporundaki sızıntı kontrolü (parolalarının kendisi gönderilmez) ve açarsan senkron. Bir bağlantıyı açtığında sayfa tarayıcında açılır. Geliştiriciler verilerini göremez, toplamaz ve saklamaz.

## Kasa nasıl korunur

Kasa, ana parolandan Argon2id ile türetilen bir anahtarla korunur; kayıtlar XChaCha20-Poly1305 ile şifrelenir. Ana parolan hiçbir yere kaydedilmez. Parmak iziyle açmayı açarsan kasanın anahtarı, telefonun güvenli donanımında (Android Keystore) duran bir anahtarla korunur.

## Ana parola ve kurtarma anahtarı yalnızca sende

Ana parolanı ve kurtarma anahtarını yalnızca sen bilirsin. İkisini birden kaybedersen kasan açılamaz; geliştiriciler dahil kimse verilerini kurtaramaz. İkisini de kimseyle paylaşma: KeyKey ana parolanı hiçbir zaman e-postayla ya da mesajla sormaz.

## Yedek almak senin elinde

Telefon kaybolur, bozulur ya da KeyKey silinirse kasa da gider. Düzenli olarak şifreli yedek almak ve yedeği güvenli bir yerde saklamak senin sorumluluğundadır. Şifresiz dışa aktarma dosyası korumasızdır; işin bitince sil.

## Senkronu açarsan

Senkronu açarsan kasanın şifreli bir kopyası senin seçtiğin WebDAV sunucusuna yazılır ve aynı klasörü kullanan telefonlarınla eşitlenir. Kopya ana parolanla şifrelidir; sunucu içeriğini okuyamaz. KeyKey ve geliştiricileri o sunucuya erişmez. Sunucunun güvenliği ve uygulama parolasının saklanması senin ya da sunucu sağlayıcının sorumluluğundadır. Senkron yedek yerine geçmez: bir telefonda silinen kayıt öteki telefonlardan da silinir, bu yüzden yedek almayı sürdür.

## Telefonunun güvenliği

Ele geçirilmiş bir telefonda hiçbir uygulama verilerini koruyamaz. Telefonunu güncel tut ve ekran kilidi kullan; root'lu bir telefonda ya da güvenmediğin uygulamaların yanında kullanma. Kopyaladığın parola 30 saniye sonra panodan silinir; o süre içinde panoya erişebilen uygulamalar onu okuyabilir, bazı klavyelerin pano geçmişi onu daha uzun tutabilir.

## Açık kaynak, bağımsız denetimden geçmedi

KeyKey ücretsiz ve açık kaynaklıdır (GPL-3.0); kodunu herkes inceleyebilir. Kodun büyük kısmı bir yapay zekâ asistanıyla yazıldı. KeyKey henüz bağımsız bir güvenlik denetiminden geçmedi.

## Garanti yoktur

KeyKey olduğu gibi, hiçbir garanti olmadan sunulur. Yürürlükteki hukukun izin verdiği ölçüde geliştiriciler; veri kaybından, verilerinin başkalarının eline geçmesinden ya da KeyKey'in kullanımından doğan zararlardan sorumlu tutulamaz. Ayrıntılar GPL-3.0 lisansının 15. ve 16. maddelerinde (Ayarlar → Hakkında → Lisanslar).

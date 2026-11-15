# Tema seçimi

Durum: kullanıcı 2026-11-15'te onayladı (telefon denemesi 6). İş #103 kapsamında, `faz/9-yayin` dalında.

## Neden

Ayarlarda tema seçimi yok; uygulama her zaman telefonun temasını izliyor. Kullanıcı açık ya da koyu temayı telefondan bağımsız seçebilmek istiyor.

## Ne yapılacak

- Ayarlar'da yeni bir **Görünüm** grubu, içinde **Tema** satırı. Satırın sağında seçili tema yazar.
- Satıra dokununca alttan pencere açılır: **Sistem** (varsayılan), **Açık**, **Koyu**. Seçili olanın yanında işaret durur. Seçim anında uygulanır, pencere kapanır.
- Seçim her yerde geçerlidir: kilit ekranı, ilk kurulum ve otomatik doldurma penceresi dahil.

## Saklama

Uygulamanın öteki ayarları kasanın içinde şifreli durur ve kasa kilitliyken okunamaz. Tema seçimi oraya konsaydı kilit ekranı onu bilemez, kilit açılınca ekran bir an renk değiştirirdi. Bu yüzden tema seçimi **kasanın dışında, şifresiz** saklanır:

- Uygulamanın özel klasöründe (`keykey.db` ile aynı yerde) `theme` adlı küçük bir metin dosyası. İçeriği `system`, `light` ya da `dark`.
- Dosya yoksa, okunamıyorsa ya da içeriği tanınmıyorsa **Sistem** kullanılır. Kasa dosyası açılamasa bile tema yüklenir.
- Gizli bir bilgi değildir: dosyayı okuyan biri yalnızca seçilen temayı öğrenir. Android yedeklemesi zaten kapalıdır.
- [Güvenlik tasarımı](guvenlik-tasarimi.md) belgesinin şifresiz kalan bilgiler listesine eklenir.

## Yaklaşımlar

1. **Şifresiz dosya (seçilen).** Kilit ekranı dahil her yerde aynı tema; tek bedeli zararsız bir bilginin şifresiz kalması.
2. **Şifreli ayar kaydının içinde.** Hiçbir şey şifresiz kalmaz ama kilit ekranı her zaman telefonun temasıyla açılır, kilit açılınca renk değişir. Kullanıcı istemedi.
3. **Veritabanına şifresiz yeni tablo.** 1. ile aynı sonuç ama şema değişikliği ve göç ister; kasa dosyası açılamadığında tema da okunamaz. Gereksiz.

## Kapsam dışı

- Android'in açılış ekranı (uygulama yüklenirken bir an görünen zemin) telefonun temasını izlemeye devam eder; uygulamanın kendi seçimini oradan okumak yerel kod ister.
- Renk ya da vurgu seçimi yok; yalnızca açık/koyu.

## Kurucuya kalanlar

Kod adları, dosyanın yazılma biçimi, simge seçimi.

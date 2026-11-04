# Güvenlik Politikası

## Güvenlik açığı bildirme

**Güvenlik açıklarını herkese açık issue olarak paylaşma.** Bunun yerine GitHub'ın [özel güvenlik bildirimi](https://github.com/aaudraa/KeyKey/security/advisories/new) formunu kullan.

Bildiriminde şunlar olursa açığı daha hızlı doğrulayabiliriz:

- Etkilenen bileşen ve sürüm ya da commit
- Açığı yeniden üretme adımları
- Olası etki: saldırganın neye erişebildiği ve hangi koşullar gerektiği

Bildirimine gerçek parola, 2FA anahtarı veya kasa dosyası ekleme.

## Süreç

KeyKey gönüllü olarak geliştirilen küçük bir proje, bu yüzden kesin bir yanıt süresi sözü veremiyoruz. Bildirimleri öncelikli olarak ele alıyor, düzeltme yayımlanana kadar ayrıntıları gizli tutuyoruz. İstersen yayımlanan güvenlik duyurusunda adınla teşekkür ederiz.

## Kapsam

**Kapsamda:** Bu repodaki kod, kasa ve yedek dosyası biçimi, kriptografik tasarım ve otomatik doldurma davranışı.

**Kapsam dışı:**

- Android'in veya üçüncü taraf kütüphanelerin kendi açıkları (bunları ilgili projeye bildir, KeyKey'i etkiliyorsa bize de haber ver)
- Kilidi açık, root edilmiş veya zararlı yazılım bulaşmış bir cihaz gerektiren senaryolar
- Cihaza fiziksel erişim ve ana parolanın bilinmesini gerektiren senaryolar

## Mevcut durum

KeyKey henüz yayımlanmadı ve **bağımsız bir güvenlik denetiminden geçmedi**. Kararlı bir sürüm çıkana kadar desteklenen bir sürüm yok; bildirimler `main` branch'ine göre değerlendirilir.

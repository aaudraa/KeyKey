# Katkı Rehberi

KeyKey'e ilgin için teşekkürler. Proje erken aşamada ve yönü [yol haritasında](../resources/yol-haritasi.md) yazıyor. Büyük bir değişikliğe başlamadan önce bir issue açıp konuşalım.

## Temel kurallar

- **Dil:** Issue, PR, commit ve belgeler Türkçe yazılır. Koddaki adlar İngilizcedir.
- **Güvenlik açıkları:** Herkese açık issue açma, [güvenlik politikasını](SECURITY.md) izle.
- **Gerçek veri yok:** Issue, PR, test ve ekran görüntülerine gerçek parola, 2FA anahtarı veya kasa dosyası koyma.
- **Kripto:** Kendi algoritmanı yazma. Şifreleme ve depolama biçimindeki değişiklikler önceden konuşulur.
- **Bağımlılıklar:** Yeni paketin lisansı GPL-3.0 ile uyumlu olmalı ve PR'da neden gerektiği yazmalı.

## Branch, commit ve PR

Branch adları `faz/<numara>-<kısa-ad>` biçimindedir. Commit mesajları `<tür>(<alan>): <açıklama>` biçiminde yazılır. Ayrıntılar ve tam akış için yol haritasının [Çalışma düzeni](../resources/yol-haritasi.md#çalışma-düzeni) bölümüne bak.

PR açmadan önce şablondaki kontrol listesini tamamla. `Closes #12` gibi anahtar kelimeler İngilizce kalmalı, çünkü GitHub issue'ları yalnızca bunlarla otomatik kapatır.

## Lisans

Katkın, projenin [GPL-3.0](../LICENSE) lisansıyla dağıtılır.

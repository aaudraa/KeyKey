# Değişiklik günlüğü

KeyKey'deki önemli değişiklikler. Sürüm numarası kuralı [yayın belgesinde](docs/yayin.md#sürüm-numarası). `v1.0.0`'dan önceki sürümler fazların sonunu işaretler ve hata ayıklama anahtarıyla imzalıdır; kalıcı bir kurulum için kullanılmamalıdır.

## Yayımlanmamış

Faz 9 (1.0 yayını) sürüyor.

### Eklenenler

- Firefox'un parola dışa aktarmasını (CSV) içe aktarma (#95).
- Etiketten imzalı APK, AAB ve taslak GitHub Release üreten yayın iş akışı (#96).
- Türkçe ve İngilizce gizlilik bildirimi (#102).

### Değişenler

- SQLite hazır kütüphane olarak indirilmiyor, repodaki 3.54.1 kaynağından derleniyor (#99).
- Aynı koddan aynı yolda yapılan iki derleme aynı APK'yı veriyor: Android Gradle eklentisinin APK'ya gömdüğü şifreli bağımlılık listesi kaldırıldı (#99).

### Belgeler

- Giriş kutularını Android'in doldurma sistemine bildirmeyen uygulamalar bilinen sınır olarak yazıldı; örnek HoYoLAB'ın giriş ekranı (#94).

## 0.8.0 (2026-11-09): Güvenlik sertleştirme ve denetim

- OWASP MASVS denetimi; bulunan açık kapatıldı: başka bir uygulama, adres taşıyan bir niyetle KeyKey'i istediği ekrana götürebiliyordu.
- Bindirme pencerelerine ve gizlenmiş dokunuşlara karşı arayüz koruması.
- Yayın derlemesinde R8; APK'da izin, sembol ve deneme değeri denetimi.
- Çevrimdışı parola raporu: zayıf ve tekrar eden parolalar.
- Bağımlılık ve lisans denetimi; lisanslar ekranına Android kütüphaneleri ve SQLite eklendi.
- Erişilebilirlik: TalkBack, büyük yazı, kontrast düzeltmeleri.
- Gerçek telefonda StrongBox, parmak izi ve süre ölçümleri.

## 0.7.0 (2026-11-08): Yedekleme, içe ve dışa aktarma

- Şifreli `.keykey` yedeği (Argon2id ve libsodium `secretstream`), doğrulamalı geri yükleme, yedek hatırlatıcısı.
- Bitwarden (JSON, CSV), Chrome (CSV) ve KeePassXC (CSV) dosyalarından içe aktarma.
- Çift onaylı düz metin dışa aktarma.

## 0.6.0 (2026-11-07): Otomatik doldurma

- Android otomatik doldurma servisi; kilitli öneri, KeyKey ekranında kasayı açma.
- Uygulamalar paket adı ve imza sertifikasıyla, siteler yalnızca güvenilen tarayıcılardan gelen alan adıyla eşleşir; şüpheli durumda uyarı.
- Satır içi (klavye şeridi) öneriler, yeni parola kaydetme, doldurmadan sonra 2FA kodunu kopyalama.
- Chrome 135+ için kurulum yönlendirmesi.

## 0.5.1 (2026-11-06): Faz 5 düzeltmesi

- Telefon denemesinin bulduğu sorunlar: gizli anahtar girişi ve yapıştırma, kurtarma anahtarı yazımı, kamerada daha hızlı QR okuma.

## 0.5.0 (2026-11-06): 2FA doğrulayıcı

- TOTP ve HOTP; SHA-1, SHA-256, SHA-512; 6-8 hane.
- Kamera ve görselden QR okuma, elle anahtar girişi.
- Google Authenticator, Aegis ve 2FAS'tan içe aktarma.
- Parola kaydıyla 2FA hesabını eşleştirme; kodlar için isteğe bağlı ek onay.

## 0.4.0 (2026-11-05): Parola kasası

- Kayıtlar: ad, kullanıcı adı, parola, adresler, not, özel alanlar.
- Liste, arama, favoriler, klasörler, çöp kutusu, parola geçmişi.
- Parola ve parola cümlesi üretici, güç ölçer, kendiliğinden temizlenen pano.

## 0.3.0 (2026-11-05): Kasa, kilit ve biyometri

- Kasa oluşturma, ana parola ve kurtarma anahtarı.
- Otomatik kilit, hatalı denemelerde artan bekleme.
- Parmak iziyle açma; yeni parmak izi eklenince geçersiz olur.

## 0.2.0 (2026-11-05): Kripto çekirdeği

- libsodium ile Argon2id, XChaCha20-Poly1305 ve HKDF; kasa üst bilgisi biçimi v1.

## 0.1.0 (2026-11-05): Flutter iskeleti ve CI

- Yalnızca Android, `minSdk 30`; ekran görüntüsü engeli, kapalı Android yedeklemesi, `INTERNET` izni yok.
- CI: biçim, analiz, test, Android derlemesi, gizli bilgi taraması.

## 0.0.0 (2026-11-04): Repo ve GitHub altyapısı

- Repo, lisans, şablonlar, güvenlik politikası ve yol haritası.

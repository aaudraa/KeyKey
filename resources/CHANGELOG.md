# Değişiklik günlüğü

KeyKey'deki önemli değişiklikler. Sürüm numarası kuralı [yayın belgesinde](docs/yayin.md#sürüm-numarası). `v1.0.0`'dan önceki sürümler fazların sonunu işaretler ve hata ayıklama anahtarıyla imzalıdır; kalıcı bir kurulum için kullanılmamalıdır.

## Yayımlanmamış

Faz 9 (1.0 yayını) sürüyor.

### Eklenenler

- Firefox'un parola dışa aktarmasını (CSV) içe aktarma (#95).
- Etiketten imzalı APK, AAB ve taslak GitHub Release üreten yayın iş akışı (#96).
- Türkçe ve İngilizce gizlilik bildirimi (#102).

### Değişenler

- Sürümler kalıcı yayın anahtarıyla imzalanıyor (#97). Hata ayıklama anahtarıyla imzalı `v0.x` sürümlerinin üstüne kurulamaz: yedek al, eski uygulamayı kaldır, yeni sürümü kur ve yedeği geri yükle. Bu yol emülatörde denendi (#101), adımlar [yayın belgesinde](docs/yayin.md#eski-sürümlerden-geçiş).
- SQLite hazır kütüphane olarak indirilmiyor, repodaki 3.54.1 kaynağından derleniyor (#99).
- Aynı koddan aynı yolda yapılan iki derleme aynı APK'yı veriyor: Android Gradle eklentisinin APK'ya gömdüğü şifreli bağımlılık listesi kaldırıldı (#99).
- Yeni görünüm (#103): krem zemin, turuncu ana renk, telefonun koyu temasına uyan koyu tema. Alt menü ekranın üstünde yüzen buzlu cam. Kayıtlar ve 2FA hesapları yazıya göre büyümeyen, aynı boyda küçük kartlarda; bağlı uygulamanın simgesi kartın içinde silik görünür. Ayarlar dört grupta (Güvenlik, Yedek ve aktarım, Otomatik doldurma, Hakkında); uzun açıklamalar (i) düğmesinde, sürüm Hakkında'da. Onay ve uyarı pencereleri alttan açılıyor.
- Yeni uygulama simgesi ve açılış ekranı: beyaz zeminde turuncu K (#103). Android 13+ temalı simge destekleniyor.
- Otomatik doldurma yarım pencerede açılıyor (#103): giriş yapılan uygulama arkada karartılmış olarak görünür kalır. Önce yalnızca eşleşen kayıtlar var; "Başka bir kayıt ara" kutusu pencereyi uzatır ve bütün kayıtlarda arar. Kilit açma, uyarılar ve kaydetme de aynı pencerede. Karartılmış alana dokunmak ya da aşağı kaydırmak hiçbir şey doldurmadan kapatır; uyarıdayken geri tuşu listeye döner.
- Tek kesin eşleşme sorulmadan dolduruluyor (#103): tam olarak bir kayıt eşleşiyorsa, eşleşme kesinse (uygulamada imza, güvenilen tarayıcıda alan adı) ve hiçbir uyarı yoksa liste açılmaz. Her doldurmadan sonra kısa bir bildirim kaydın adını gösterir ("GitHub dolduruldu"); kullanıcı adı ve parola bildirime girmez. Bildirimin güvenli pencere dışında görünmesi [bilinen sınır](docs/guvenlik-tasarimi.md#bilinen-sınırlar) olarak yazıldı.

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

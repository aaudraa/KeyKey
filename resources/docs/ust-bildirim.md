# Üstten inen bildirim

Durum: proje sahibi onayladı ve uygulandı (2026-11-16, [plan](ust-bildirim-plani.md)).

## Neden

Uygulamanın içindeki kısa bildirimler ("Kopyalandı", "Çöp kutusuna taşındı · Geri al", "Yedek kaydedildi", kaydetme hataları) altta küçük çıkıyor. Proje sahibi, 1.0'dan önce bu bildirimlerin üstten inmesini, tasarıma uymasını ve yazılarının daha büyük ve kalın olmasını istedi.

Bugün iki tür bildirim var. Üç yerde (kopyalama, kayıt ve 2FA hesabını çöpe taşıyınca çıkan "Geri al") cam bildirim (`showKkSnack`) kullanılıyor. Yaklaşık 30 yerde ise düz, opak Flutter `SnackBar`'ı kullanılıyor. İkisi de altta çıkıyor.

## Hedefler

- Bütün uygulama içi bildirimler tek bir görünümde ve üstten iniyor.
- Görünüm A, ortada hap. Yazı kadar geniş, ekranın ortasında bir cam hap. Durum çubuğunun hemen altında duruyor.
- Yazı şimdikinden büyük ve kalın: 16 punto, kalın (w700). Şimdiki 14 punto, normal kalınlıkta.

```
     ╭──────────────────────────────╮
     │  Kopyalandı. 30 sn sonra…    │
     ╰──────────────────────────────╯
  VAULT
```

## Hedef dışı

- Otomatik doldurmadaki "… dolduruldu" yazısı Android'in kendi bildirimi (Toast). Uygulama penceresi o anda açık olmadığı için olduğu gibi kalıyor.
- Bildirim kuyruğu yok. Yeni bildirim öncekinin yerine geçiyor, bugünkü gibi.

## Yaklaşımlar

1. **Kendi katmanımızda çizilen bildirim (seçilen).** Bildirim, uygulamanın en üst katmanına (kök gezginin `Overlay`'i) ekleniyor. Ekran kapansa da yaşıyor, alttan açılan pencerelerin de üstünde kalıyor. 30 yerin hepsi tek bir yardımcıya geçiyor.
2. **Flutter'ın `SnackBar`'ını yukarı itmek** (`margin` ile). Ekran yüksekliğine ve klavyeye bağlı kırılgan hesaplar gerekiyor, giriş hareketi de aşağıdan kalıyor. Bu yüzden elendi.
3. **Her ekranın üstüne ayrı bir bant koymak.** 30 yeri dağıtıyor, ekran kapandığında çıkan bildirim ("Çöp kutusuna taşındı") kayboluyor. Bu yüzden elendi.

## Tasarım

- **Yer:** Durum çubuğunun 8 dp altında, yatayda ortada. En geniş hali ekranın iki yanından 16'şar dp boşluk kalacak kadar. Mesaj uzunsa iki satıra iniyor.
- **Görünüm:** Bugünkü cam bildirimle aynı cam yüzey: güçlü bulanıklık, hap biçimi, ince kenar çizgisi. Yazı ana renkte, 16 punto, w700. "Geri al" gibi bir düğme varsa hapın sağında duruyor ve yazısı da aynı büyüklükte, w800.
- **Hareket:** Yukarıdan kayarak ve belirerek iniyor (`KkMotion.base`), çıkarken yukarı kayıp soluyor (`KkMotion.panelClose`). "Animasyonları kaldır" açıkken anında çıkıp anında kayboluyor.
- **Süre:** Düğmesiz bildirim 4 saniye ekranda kalıyor. Düğmeli bildirim 6 saniye kalıyor, çünkü üstteki düğmeye ulaşmak alttakinden uzun sürüyor. *(Benim kararım.)*
- **Kapanma:** Yukarı kaydırınca ya da dokununca kapanıyor; hap üst çubuğu örtebildiği için dokunmak geri tuşuna beklemeden yol açıyor *(son incelemede eklendi)*. Yeni bildirim öncekinin yerine geçiyor. Kasa kilitlenince açık bildirim kapanıyor, kilitten sonra "Geri al"a basılamasın diye. *(Benim kararım.)*
- **Simge:** Yok. Mesajların bir kısmı başarı, bir kısmı hata; yanlış simge, simgesizlikten kötü. Hata bildirimi de renksiz kalıyor, turuncu yalnızca dört yerde kullanılıyor. *(Benim kararım.)*
- **Erişilebilirlik:** Mesaj TalkBack'te okunuyor (canlı bölge). TalkBack açıkken düğmeli bildirim kendiliğinden kapanmıyor, Flutter'ın `SnackBar` kuralı gibi; TalkBack'in kapatma eylemiyle kapanıyor.
- **Kod:** `showKkSnack(context, message, {action})` aynı adla kalıyor; `await` öncesi alınan `kkSnackFor(context)` ekran kapansa da bildirimi gösteriyor, içi yeni katmana geçiyor. `SnackBarAction` yerine küçük bir `KkSnackAction(label, onPressed)` geliyor. Doğrudan `SnackBar` gösteren bütün yerler `showKkSnack`'e geçiyor, temadaki `snackBarTheme` kalkıyor. Bir tarama testi `lib/` altında `SnackBar` ve `showSnackBar` kalmadığını denetliyor.

## Kurucuya kalanlar

- Katmanın kök gezgine nasıl bağlanacağı (global anahtar ya da `Navigator.of(context, rootNavigator: true).overlay`).
- Kilitlenmeyi dinlemenin yolu (kasa oturumu sağlayıcısı).
- Kaydırma ve zamanlayıcının test edilebilir kurgusu.

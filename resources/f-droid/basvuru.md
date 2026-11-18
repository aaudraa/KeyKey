# F-Droid başvurusu

KeyKey'i F-Droid ana deposuna eklemek için `fdroid/fdroiddata` deposuna açılan birleştirme isteği (merge request). Tasarım: [f-droid.md](../docs/f-droid.md).

**Durum:** istek açık: [fdroiddata!57995](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/57995), başlık `New app: KeyKey`, 2026-11-18. Tarif `v1.1.0` (`382671772ea1cf352a4683880bd573bd33319159`). İnceleme ve kabul #130'da izleniyor; başvurunun kendisi #119'du.

## Nasıl açıldı

1. Proje sahibi GitLab'da hesap açtı (`audrq`) ve [`fdroid/fdroiddata`](https://gitlab.com/fdroid/fdroiddata)'yı kendi ad alanına çatalladı. Çatal herkese açık, yalnızca `master` dalıyla.
2. GitLab profilinde **commit e-postası** gizli adrese (`…@users.noreply.gitlab.com`) alındı. Yoksa web arayüzünden ya da API'den yapılan commit'ler hesabın e-postasını fdroiddata'nın herkese açık geçmişine yazar. Yazar adı olarak profildeki görünen ad çıkar; proje sahibi bunu istiyor.
3. Gerisi `glab` (GitLab'ın komut satırı aracı, `winget install GLab.GLab`) ile yapıldı. Proje sahibi `glab auth login --hostname gitlab.com --web` ile tarayıcıdan bir kez yetki verdi; anahtar Windows'un kimlik deposunda.
4. Çatalda `io.github.aaudraa.keykey` dalı ve `metadata/io.github.aaudraa.keykey.yml` dosyası tek API çağrısıyla açıldı (`POST projects/:id/repository/commits`, `start_branch: master`). Dosya [`io.github.aaudraa.keykey.yml`](io.github.aaudraa.keykey.yml)'nin aynısı, yalnızca en üstteki Türkçe yorum satırları silindi (fdroiddata'daki dosyalarda yorum olmaz). Satır sonu LF. Commit mesajı: `New app: io.github.aaudraa.keykey`.
5. İstek `fdroid/fdroiddata` → `master` hedefine açıldı. Başlık şablonun istediği biçimde: `New app: KeyKey`. Metin fdroiddata'nın [istek şablonuyla](https://gitlab.com/fdroid/fdroiddata/-/blob/master/.gitlab/merge_request_templates/Default.md) dolduruldu. "Maintainer'ların commit atmasına izin ver" ve "squash" açık.

## Metnin içeriği

İngilizce metnin tamamı istekte. Bölümleri:

- Uygulamanın özeti ve Fastlane klasöründen dört ekran görüntüsü.
- Neden yazıldığı: parolalar, 2FA kodları ve otomatik doldurma tek çevrimdışı kasada, internet izni yok, yaygın uygulamalardan içe aktarma, birebir aynı ve geliştirici imzalı derleme. Başka uygulamalarla kıyas yok.
- **3 ay kuralı:** uygulamanın yaşı açıkça yazıldı ve istisna istendi (aşağıda).
- **APK boyutu:** neden 80,8 MB olduğu; isterlerse mimariye göre bölünmüş APK'ya geçileceği.
- Şablonun kontrol listesi: doğru olan maddeler işaretli. İşaretsizler: 3 ay kuralı, ABI ayrımı ve henüz çalışmamış CI maddeleri; her biri için gerekçe yazılı.
- İnceleyenlere notlar: birebir aynı derleme ve imza (`Binaries`, `AllowedAPKSigningKeys`, yayın iş akışındaki `apksigcopier compare`), bağımlılıklar, `scanignore` ve `sudo` gerekçeleri.
- **Yapay zekâ açıklaması:** kodun büyük kısmı bir yapay zekâ asistanıyla (Claude) yazıldı; işi proje sahibi yönetti ve gerçek telefonda denedi; projenin kendi OWASP MASVS denetimi var, bağımsız denetim yok.

## Bilinen engeller

- **3 ay kuralı.** F-Droid'in [kabul politikası](https://f-droid.org/docs/Inclusion_Policy) uygulamanın en az 3 aydır geliştiriliyor olmasını istiyor (Quality Control, 6. madde; şablon özellikle bu maddeye dikkat çekiyor). İstisnalar: kanıtlanmış bir kullanıcı kitlesi, geliştiricinin F-Droid'de başka uygulaması olması, yalnızca bir etkinlik için yapılmış olması. KeyKey'in ilk commit'i 2026-11-04 ve istisnalara uymuyor. Proje sahibi buna rağmen şimdi başvurmayı ve istisna istemeyi seçti. Kabul edilmezse istek **2027-02-04**'e kadar bekler.
- **APK boyutu.** Evrensel APK 80,8 MB: arm64-v8a, armeabi-v7a ve x86_64 için ayrı ayrı yaklaşık 26 MB yerel kütüphane, sıkıştırılmamış. Şablon büyük APK'lar için mimariye göre bölünmüş APK istiyor. Bölmek yayın iş akışını, tarifi (`VercodeOperation`, mimari başına `Builds` bloğu) ve Obtainium ayarını değiştirir; istenirse ayrı faz olur.
- **CI.** fdroiddata'nın iş akışı, isteği açanın çatalında çalışır. GitLab hesap doğrulaması istediği için çalışmadı ("The pipeline failed due to the user not being verified"). Şablon telefon numarası ya da kart verilmemesini, isteğe not düşülmesini söylüyor; not metinde var. Aynı tarif kendi CI'ımızda `fdroid build` ve `fdroid lint`'ten geçiyor.

## İstek açıkken

- **Yeni sürüm çıkarsa:** istek birleşmeden önce tarifte yalnızca son sürüm durmalı. `Builds` altındaki blok yeni sürümün `versionName`, `versionCode` ve tam commit özetiyle (`git rev-parse vX.Y.Z^{commit}`) **değiştirilir**, yenisi eklenmez; `CurrentVersion` ve `CurrentVersionCode` de güncellenir. Aynı değişiklik repodaki [`io.github.aaudraa.keykey.yml`](io.github.aaudraa.keykey.yml)'ye de yapılır. Çataldaki dala yeni commit atılır (`glab api --method POST projects/audrq%2Ffdroiddata/repository/commits`, `action: update`); dal yeniden yazılmaz, çakışma yoksa rebase yapılmaz.
- **İnceleme soruları:** istekteki yorumlar birlikte yanıtlanır. Yanıtlar İngilizce.
- **Kabulden sonra:** README'ye F-Droid bağlantısı eklenir (#130).

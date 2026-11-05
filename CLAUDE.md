# KeyKey için Claude Code kuralları

KeyKey, Android için çevrimdışı ve açık kaynak bir parola yöneticisi ve 2FA uygulaması (Flutter).

Bu dosya yalnızca kuralları içerir. Durum, plan ve kararların tek kaynağı [`resources/yol-haritasi.md`](resources/yol-haritasi.md), işe başlamadan onu oku. Kripto işlerinde kod [`resources/docs/guvenlik-tasarimi.md`](resources/docs/guvenlik-tasarimi.md) ile çelişemez.

## Çalışma

- Küçük adımlarla ilerle ve commit'leri push'la. Yeni faza kullanıcı onay vermeden başlama.
- Her faz tek dalda yürür: `faz/<numara>-<kısa-ad>`. Biten dallar silinmez.
- Eksik bir araç varsa etrafından dolaşma, kur.
- Issue ve milestone'ları iş ilerledikçe güncel tut.

## Birleştirme

- `main`'e PR ancak faz tamamen çalışınca açılır.
- Her PR yalnızca kullanıcı o PR için açıkça onay verince birleştirilir.
- Birleştirmeden önce kullanıcıya GitHub'daki "Keep my email addresses private" ayarının açık olduğunu sor.
- Yalnızca şu komutla birleştir, başarısız olursa düz birleştirmeye dönme: `gh pr merge --merge --author-email 184309740+aaudraa@users.noreply.github.com`

## Depo düzeni

- Proje kodu olmayan her dosya `resources/` altına girer. Kökte yalnızca orada olmak zorunda olanlar kalır.
- Commit, issue, PR, belge ve kod yorumları Türkçedir. Kod adları İngilizce kalır. `Closes #n` da İngilizce kalmalı.
- Commit biçimi: `<tür>(<alan>): <kısa açıklama>`. Türler yol haritasının "Commit mesajları" bölümünde.

## Kontroller

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test -d <cihaz>
```

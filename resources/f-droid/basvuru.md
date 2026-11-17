# F-Droid başvurusu

KeyKey'i F-Droid ana deposuna eklemek için `fdroid/fdroiddata` deposuna açılacak birleştirme isteği (merge request). Tasarım: [f-droid.md](../docs/f-droid.md). Takip: #119.

## Proje sahibinin adımları

1. [GitLab](https://gitlab.com/users/sign_up)'da hesap aç (yoksa).
2. [`fdroid/fdroiddata`](https://gitlab.com/fdroid/fdroiddata)'yı çatalla (Fork).
3. Çatalda `io.github.aaudraa.keykey` adında bir dal aç.
4. Dala `metadata/io.github.aaudraa.keykey.yml` dosyasını ekle: içeriği [`io.github.aaudraa.keykey.yml`](io.github.aaudraa.keykey.yml)'nin aynısı, yalnızca en üstteki Türkçe yorum satırları silinir (fdroiddata'daki dosyalarda yorum olmaz). `commit:` satırı `v1.1.0` etiketinin tam özetini taşımalı; `git rev-parse v1.1.0^{commit}` ile alınır. (`v1.0.1` etiketi var ama o sürüm yayımlanmadı; F-Droid'e giren ilk sürüm 1.1.0.)
5. Commit mesajı: `New App: io.github.aaudraa.keykey`
6. Birleştirme isteğini aç: hedef `fdroid/fdroiddata` → `master`, başlık `New App: io.github.aaudraa.keykey`, açıklama aşağıdaki İngilizce metin. "New App" etiketini seç.
7. Açılan isteğin bağlantısını #119'a yaz. İncelemede gelen soruları birlikte yanıtlarız.

İsteği açınca fdroiddata'nın kendi CI'ı uygulamayı derler ve `fdroid lint` çalıştırır. Bizim yayın iş akışındaki "F-Droid karşılaştırması" aynı derlemeyi önceden yaptığı için bunun geçmesi beklenir.

## Birleştirme isteğinin metni

```markdown
## New App: KeyKey (io.github.aaudraa.keykey)

KeyKey is an offline password manager and 2FA (TOTP/HOTP) authenticator for Android 11+.

* Source: https://github.com/aaudraa/KeyKey (GPL-3.0-only)
* No INTERNET permission, no trackers, no ads, no proprietary dependencies (no Google Play Services, no ML Kit, no Firebase). QR codes are read with zxing-cpp (flutter_zxing).
* Native code is built from source during the build: libsodium (from the source archive inside the `sodium` Dart package, via its build hook) and SQLite (from the amalgamation in the repo). Apart from pub.dev packages (pinned by `pubspec.lock` hashes), Gradle dependencies from Google Maven / Maven Central and the Flutter engine artifacts, nothing is downloaded at build time.
* Fastlane metadata (en-US, tr-TR) is in the repo.

### Reproducible build, developer signature

The recipe uses `Binaries:` and `AllowedAPKSigningKeys:` so F-Droid can publish the upstream-signed APK.

* Upstream release builds are made in `registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie`, in `/home/vagrant/build/io.github.aaudraa.keykey`, with the same prebuild/build steps as this recipe, then signed with `apksigner` (v2+v3, alignment preserved).
* Our release workflow also runs `fdroid build` on the same commit and checks the result with `apksigcopier compare` before the release is published: https://github.com/aaudraa/KeyKey/blob/main/.github/workflows/yayin.yml
* Signing certificate SHA-256: `66ff7b5c0c009a8530d0a55dd1d80a3af35de48bd0667c456a0cf86a6d1129a0`

### Notes for reviewers

* `scanignore`: the libsodium source tarball shipped inside the `sodium` package (`.pub-cache/hosted/pub.dev/sodium-*/3rdparty/libsodium-*-stable.tar.gz`). The package's build hook compiles libsodium from it with the NDK; it is source, not a binary.
* `sudo: apt-get install -y make` is needed by libsodium's configure/make.
* **AI disclosure:** much of KeyKey's code was written with an AI coding assistant (Claude); the project owner directed the work and tested it on a real phone. The project ran its own OWASP MASVS-based security review (documented in the repo) but has not been independently audited. We say this openly in the README and the app description.

Thanks for reviewing!
```

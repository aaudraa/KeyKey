# Argon2

KeePass dosyalarının (KDBX 4) anahtar türetmesi için Argon2d ve Argon2id. Algoritmanın yazarlarının başvuru uygulaması; RFC 9106'nın test vektörlerini üreten kod. libsodium'da Argon2d yok, Argon2id'si de KeePass'ın kullandığı paralellik, gizli anahtar ve ek veri parametrelerini almıyor ([KeePass içe aktarma tasarımı](../../../resources/docs/keepass-ice-aktarma.md)).

| | |
|---|---|
| Sürüm | `20190702` etiketi (son sürüm) |
| Kaynak | https://github.com/P-H-C/phc-winner-argon2, commit `62358ba2123abd17fccf2a108a301d4b52c01a7c` |
| Arşiv | https://codeload.github.com/P-H-C/phc-winner-argon2/tar.gz/refs/tags/20190702 |
| Arşivin SHA-256 özeti | `daf972a89577f8772602bf2eb38b6a3dd3d922bf5724d45e7f9589b5e830442c` (2026-11-22'de indirildi) |
| Lisans | CC0 1.0 ya da Apache 2.0, seçime bağlı (`LICENSE`) |

Arşivden yalnızca aşağıdaki dosyalar alındı, hiçbiri değiştirilmedi. `opt.c` (x86 SSE) alınmadı; telefonlar ARM, taşınabilir `ref.c` derlenir. Derleme `android/app/src/main/cpp/CMakeLists.txt`'te, Kotlin'e köprü `argon2_jni.c`.

```
220f8736a89ff51c92ef3d497f413b48e6cf1df3d6278bc909c6308c78e1718e  LICENSE
df20cb726a2fe6bccc736b81ea0d86219766a0d17f1794c19e048a34830ca1cc  include/argon2.h
72a93deebc5fd76bec0c6d300a2d92b500fb354b26babbddbc6d8b88681e663d  src/argon2.c
0f53eb2370f8971f04fcf043b8083bf81d1530c48b2ead71c0b6c4e22a01aeec  src/core.c
e20124ec0f780f88527e79cf00825e839624ed1f469c7e231596bf070f8c7b14  src/encoding.c
4ec47b080c22f4ee416b9dbcfae70ee6007fcfba427f870d7b84395846fa1bc7  src/ref.c
1402085e2f54b021ea31b0d301f4b689a8b300832e2d11901502e62835185e3e  src/thread.c
c9665623cb3d306f63b6a3effd87bcfab971c28253c77e111445e42c1523235e  src/core.h
42f283d12ec445cfb423ac2f1f5a5d1a7f152ce2b9363f6ec3e1d5b61cd4ee6d  src/encoding.h
9eab7f9ff356862a00a3075478dd0059344953ed79daab8b29185be2010efe78  src/thread.h
8ac91f1f57d94235f8de0069b7809be1deb365c3b37adb8e30423cd364aff09a  src/blake2/blake2-impl.h
3c2de197dd23179f78c57deac7b73a6049778bf651c5db57e508b2cfce5e7559  src/blake2/blake2.h
52519ccbc1e48f489ff444091f630d05dadcc8f1ee61c5b7361e3a9618299c9a  src/blake2/blake2b.c
bcfdcf785218cf897f05b144e80b659e611188fee3887d533bdcb7a6aa4c336b  src/blake2/blamka-round-ref.h
```

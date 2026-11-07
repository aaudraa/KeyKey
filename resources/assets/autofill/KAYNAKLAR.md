# Otomatik doldurma verilerinin kaynakları

Bu klasördeki dosyalar uygulamaya veri olarak girer, kod değildir. Kurallar güvenlik tasarımı belgesinin "Otomatik doldurma > Eşleştirme" bölümünde.

| Dosya | Kaynak | Lisans | SHA-256 |
|---|---|---|---|
| `public_suffix_list.dat` | [Public Suffix List](https://publicsuffix.org/list/public_suffix_list.dat), sürüm `2026-11-06_09-01-47_UTC` | MPL 2.0 | `027fe126522e646b2335c3d564750d7223f0994a1a460107ce4f3a40bd682310` |

2026-11-06 tarihinde indirildi, değiştirilmeden duruyor. ICANN ve özel bölümlerin ikisi de kullanılır. Lisansı uygulamanın lisanslar sayfasında da gösterilir.

## Güvenilen tarayıcılar

Güvenilen tarayıcı listesi bu klasörde değil, koda gömülü: `android/app/src/main/kotlin/io/github/aaudraa/keykey/autofill/TrustedBrowserList.kt`. O dosya [Google'ın ayrıcalıklı uygulamalar listesinden](https://www.gstatic.com/gpm-passkeys-privileged-apps/apps.json) `resources/scripts/trusted-browsers.mjs` ile üretilir:

```sh
curl -sSfL -o apps.json https://www.gstatic.com/gpm-passkeys-privileged-apps/apps.json
node resources/scripts/trusted-browsers.mjs apps.json
```

2026-11-06'daki kaynağın SHA-256 özeti `0891ee2507894999ead3eb4f42e17936a2e8ed8f8fd95592535c9811ef319481`. 73 uygulamadan 63'ü alındı. Test sürümlerinin (`userdebug`) imzaları alınmadı. Tarayıcı olmayan Google Play Hizmetleri ile iki kimlik bilgisi sağlayıcısı (`com.fido.fido2client`, `com.oplus.credential`) da dışarıda kaldı.

#!/usr/bin/env bash
# İmzasız yayın derlemesini imzalar: APK'yı apksigner, AAB'yi jarsigner ile.
# Yayın iş akışı gerçek anahtarla, F-Droid denemesi tek kullanımlık anahtarla
# aynı betiği çalıştırır; böylece yayın zinciri her denemede sınanır.
#
# Kullanım: imzala.sh <imzasız-apk> <imzalı-apk> [<imzasız-aab> <imzalı-aab>]
# Ortam: KEYKEY_KEYSTORE, KEYKEY_KEY_ALIAS, KEYKEY_KEYSTORE_PASSWORD,
#        KEYKEY_KEY_PASSWORD; ANDROID_HOME (apksigner için), jarsigner PATH'te.
#
# apksigner zip içeriğine dokunmaz, yalnızca imza bloğunu ekler; F-Droid bu
# yüzden imzayı kendi imzasız derlemesine kopyalayıp doğrulayabilir. Şemalar
# açıkça yazılı: v1 (JAR) imzası META-INF'e dosya ekler, Android 11+ için
# gereksiz. Hizalama korunur: derleme zaten hizalı, apksigner yeniden
# hizalarsa yerleşim F-Droid'in derlemesinden ayrılır.
set -euo pipefail

if [[ $# -ne 2 && $# -ne 4 ]]; then
  echo "Kullanım: $0 <imzasız-apk> <imzalı-apk> [<imzasız-aab> <imzalı-aab>]" >&2
  exit 2
fi
: "${KEYKEY_KEYSTORE:?}" "${KEYKEY_KEY_ALIAS:?}"
: "${KEYKEY_KEYSTORE_PASSWORD:?}" "${KEYKEY_KEY_PASSWORD:?}"
: "${ANDROID_HOME:?}"

apksigner="$(find "$ANDROID_HOME/build-tools" -name apksigner | sort -V | tail -n 1)"
if [[ -z "$apksigner" ]]; then
  echo "HATA: $ANDROID_HOME/build-tools altında apksigner yok." >&2
  exit 1
fi
echo "apksigner: $apksigner"

"$apksigner" sign --ks "$KEYKEY_KEYSTORE" --ks-key-alias "$KEYKEY_KEY_ALIAS" \
  --ks-pass env:KEYKEY_KEYSTORE_PASSWORD --key-pass env:KEYKEY_KEY_PASSWORD \
  --v1-signing-enabled false --v2-signing-enabled true \
  --v3-signing-enabled true --v4-signing-enabled false \
  --alignment-preserved true \
  --in "$1" --out "$2"
"$apksigner" verify "$2"

if [[ $# -eq 4 ]]; then
  jarsigner -keystore "$KEYKEY_KEYSTORE" \
    -storepass:env KEYKEY_KEYSTORE_PASSWORD -keypass:env KEYKEY_KEY_PASSWORD \
    -sigalg SHA256withRSA -digestalg SHA-256 \
    -signedjar "$4" "$3" "$KEYKEY_KEY_ALIAS" >/dev/null
  # -verify imzasız dosyada da 0 döner; çıktı denetlenir. -strict, Android
  # anahtarları kendinden imzalı olduğu için her zaman uyarı verirdi.
  if ! jarsigner -verify "$4" | grep -q '^jar verified\.'; then
    echo "HATA: AAB imzası doğrulanmadı." >&2
    exit 1
  fi
fi
echo "İmzalandı: $2${4:+, $4}"

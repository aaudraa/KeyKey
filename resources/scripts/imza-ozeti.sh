#!/usr/bin/env bash
# APK'nın imza sertifikasının SHA-256 özetini yazar (64 küçük onaltılık hane).
#
# Kullanım: imza-ozeti.sh <apk>               apksigner ile doğrular, özeti yazar
#           imza-ozeti.sh --cikti <dosya>     hazır "apksigner verify --print-certs"
#                                             çıktısını okur (imza-ozeti-test.sh)
#
# apksigner'ın çıktısı sürüme göre değişiyor: build-tools 36 "Signer #1
# certificate SHA-256 digest: …", 37 her şema için ayrı "V3.0 Signer:
# certificate SHA-256 digest: …" yazıyor. İkisi de okunur. Bütün imzalayanlar
# aynı sertifikayı kullanmalı; tek bir özet çıkmazsa betik durur.
# Ortam: ANDROID_HOME (apksigner için).
set -euo pipefail

if [[ "${1:-}" == "--cikti" ]]; then
  cikti="$(cat "${2:?çıktı dosyası}")"
else
  apk="${1:?APK yolu}"
  : "${ANDROID_HOME:?}"
  apksigner="$(find "$ANDROID_HOME/build-tools" -name apksigner | sort -V | tail -n 1)"
  if [[ -z "$apksigner" ]]; then
    echo "HATA: $ANDROID_HOME/build-tools altında apksigner yok." >&2
    exit 1
  fi
  echo "apksigner: $apksigner" >&2
  cikti="$("$apksigner" verify --print-certs "$apk")"
  printf '%s\n' "$cikti" >&2
fi

ozetler="$(printf '%s\n' "$cikti" | tr -d '\r' |
  sed -n -E 's/^(Signer #[0-9]+|V[0-9.]+ Signer:) certificate SHA-256 digest: ([0-9a-f]{64})$/\2/p' |
  sort -u)"
sayi="$(printf '%s' "$ozetler" | grep -c . || true)"
if [[ "$sayi" -ne 1 ]]; then
  echo "HATA: apksigner çıktısında tek bir imza sertifikası yok (${sayi} farklı SHA-256 özeti)." >&2
  exit 1
fi
printf '%s\n' "$ozetler"

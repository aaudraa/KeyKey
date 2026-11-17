#!/usr/bin/env bash
# imza-ozeti.sh'nin apksigner çıktısını okuyuşunu sınar. Örnekler gerçek
# çıktılardan: eski biçim build-tools 36.0.0, yeni biçim 37.0.0 (v1.1.0'ın
# ilk yayın denemesi, 2026-11-17).
# Kullanım: bash resources/scripts/imza-ozeti-test.sh
set -euo pipefail

betik="$(dirname "$0")/imza-ozeti.sh"
gecici="$(mktemp -d)"
trap 'rm -rf "$gecici"' EXIT
hata=0

ozet=66ff7b5c0c009a8530d0a55dd1d80a3af35de48bd0667c456a0cf86a6d1129a0
baska=0000000000000000000000000000000000000000000000000000000000000001

# beklenen: ya bir özet ya da "HATA" (betik sıfır olmayan kodla çıkmalı).
sina() {
  local ad="$1" beklenen="$2" girdi="$3" sonuc kod=0
  printf '%s\n' "$girdi" > "$gecici/cikti.txt"
  sonuc="$(bash "$betik" --cikti "$gecici/cikti.txt" 2>/dev/null)" || kod=$?
  if [[ "$beklenen" == HATA ]]; then
    if [[ $kod -eq 0 ]]; then
      echo "BAŞARISIZ: $ad: hata bekleniyordu, '$sonuc' çıktı" >&2
      hata=1
      return
    fi
  elif [[ $kod -ne 0 || "$sonuc" != "$beklenen" ]]; then
    echo "BAŞARISIZ: $ad: '$beklenen' bekleniyordu, '$sonuc' (çıkış $kod) çıktı" >&2
    hata=1
    return
  fi
  echo "geçti: $ad"
}

sina "eski biçim (build-tools 36)" "$ozet" "Signer #1 certificate DN: CN=KeyKey
Signer #1 certificate SHA-256 digest: $ozet
Signer #1 certificate SHA-1 digest: f47c04ccd913f8a69eeb3a67c5fc58d4ecd6e9aa
Signer #1 certificate MD5 digest: 51c495cf3762dbebbb235b8fcb5b0604"

sina "yeni biçim (build-tools 37)" "$ozet" "V3.0 Signer: certificate DN: CN=KeyKey
V3.0 Signer: certificate SHA-256 digest: $ozet
V3.0 Signer: certificate SHA-1 digest: f47c04ccd913f8a69eeb3a67c5fc58d4ecd6e9aa
V3.0 Signer: certificate MD5 digest: 51c495cf3762dbebbb235b8fcb5b0604"

sina "şemalar aynı sertifikayla" "$ozet" "V2 Signer: certificate SHA-256 digest: $ozet
V3.0 Signer: certificate SHA-256 digest: $ozet"

sina "Windows satır sonu" "$ozet" "$(printf 'V3.0 Signer: certificate SHA-256 digest: %s\r' "$ozet")"

sina "şemalar farklı sertifikayla" HATA "V2 Signer: certificate SHA-256 digest: $ozet
V3.0 Signer: certificate SHA-256 digest: $baska"

sina "özet yok" HATA "V3.0 Signer: certificate DN: CN=KeyKey"

sina "boş çıktı" HATA ""

exit $hata

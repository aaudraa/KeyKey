#!/usr/bin/env bash
# yeniden-dene.sh'deki yeniden_dene_429'u sınar: yalnızca 429 (Too Many
# Requests) hatasında, verilen sayı kadar yeniden dener; başka hatada denemez.
# Kullanım: bash resources/scripts/yeniden-dene-test.sh
set -euo pipefail

# shellcheck source=resources/scripts/yeniden-dene.sh
source "$(cd "$(dirname "$0")" && pwd)/yeniden-dene.sh"
gecici="$(mktemp -d)"
trap 'rm -rf "$gecici"' EXIT
hata=0

# sahte <kaç kez 429> <sonra çıkış kodu>: her çağrıyı sayar.
sahte() {
  local sayi
  sayi=$(($(cat "$gecici/sayac" 2>/dev/null || echo 0) + 1))
  echo "$sayi" > "$gecici/sayac"
  if (( sayi <= $1 )); then
    echo "> Received status code 429 from server: Too Many Requests"
    return 1
  fi
  echo "deneme $sayi"
  return "$2"
}

# durum <açıklama> <beklenen çıkış> <beklenen çağrı> <deneme> <429 sayısı> <son kod>
durum() {
  local aciklama="$1" beklenen_cikis="$2" beklenen_cagri="$3" cikis=0
  rm -f "$gecici/sayac"
  yeniden_dene_429 "$4" 0 sahte "$5" "$6" >"$gecici/cikti.txt" 2>&1 || cikis=$?
  local cagri
  cagri="$(cat "$gecici/sayac")"
  if [[ "$cikis" != "$beklenen_cikis" || "$cagri" != "$beklenen_cagri" ]]; then
    echo "BAŞARISIZ: $aciklama: çıkış $cikis, çağrı $cagri (beklenen $beklenen_cikis, $beklenen_cagri)" >&2
    sed 's/^/  /' "$gecici/cikti.txt" >&2
    hata=1
  fi
}

durum "ilk denemede geçer" 0 1 3 0 0
durum "iki 429'dan sonra geçer" 0 3 3 2 0
durum "deneme hakkı biter" 1 3 3 5 0
durum "429 olmayan hata yeniden denenmez" 7 1 3 0 7

# Çağıran pipefail açmamışsa da hata kodu kaybolmamalı.
rm -f "$gecici/sayac"
kod=0
( set +o pipefail; yeniden_dene_429 3 0 sahte 0 7 ) >/dev/null 2>&1 || kod=$?
if [[ "$kod" != 7 ]]; then
  echo "BAŞARISIZ: pipefail kapalıyken çıkış $kod, beklenen 7" >&2
  hata=1
fi

# Çıktı gizlenmez: komutun yazdıkları günlükte görünmeli.
rm -f "$gecici/sayac"
yeniden_dene_429 3 0 sahte 1 0 >"$gecici/cikti.txt" 2>&1
if ! grep -q "Too Many Requests" "$gecici/cikti.txt" || ! grep -q "deneme 2" "$gecici/cikti.txt"; then
  echo "BAŞARISIZ: komutun çıktısı görünmüyor" >&2
  hata=1
fi

if [[ $hata -ne 0 ]]; then exit 1; fi
echo "yeniden-dene: bütün durumlar geçti"

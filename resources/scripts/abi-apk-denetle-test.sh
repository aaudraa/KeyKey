#!/usr/bin/env bash
# abi-apk-denetle.sh'yi sentetik APK'larla (zip) sınar.
# Kullanım: bash resources/scripts/abi-apk-denetle-test.sh
set -euo pipefail

betik="$(cd "$(dirname "$0")" && pwd)/abi-apk-denetle.sh"
gecici="$(mktemp -d)"
trap 'rm -rf "$gecici"' EXIT
hata=0
# Windows'ta python3 çoğu zaman yalnızca Store kısayolu; çalışanı seçilir.
py=""
for aday in python3 python; do
  if "$aday" -c "" 2>/dev/null; then py="$aday"; break; fi
done
[[ -n "$py" ]] || { echo "HATA: Python yok." >&2; exit 1; }

# kur <klasör> <dosya=içerik>...: klasörü baştan kurar.
kur() {
  local klasor="$1"; shift
  rm -rf "$klasor"
  local cift yol
  for cift in "$@"; do
    yol="$klasor/${cift%%=*}"
    mkdir -p "$(dirname "$yol")"
    printf '%s' "${cift#*=}" > "$yol"
  done
}

# paketle <klasör> <apk>: zip her ortamda yok, Python'un zipfile'ı var.
paketle() {
  "$py" - "$1" "$2" <<'EOF'
import os, sys, zipfile
kok, apk = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(apk, "w") as z:
    for dizin, _, dosyalar in os.walk(kok):
        for ad in sorted(dosyalar):
            yol = os.path.join(dizin, ad)
            z.write(yol, os.path.relpath(yol, kok).replace(os.sep, "/"))
EOF
}

ortak=(
  "AndroidManifest.xml=manifest"
  "classes.dex=dex"
  "resources.arsc=arsc"
  "res/a.xml=res"
  "assets/flutter_assets/x=asset"
  "META-INF/X.SF=imza"
)

kur "$gecici/evrensel" "${ortak[@]}" \
  "lib/arm64-v8a/a.so=arm64" "lib/armeabi-v7a/a.so=arm32" "lib/x86_64/a.so=x64"
paketle "$gecici/evrensel" "$gecici/evrensel.apk"

# sina <ad> <beklenen: 0|HATA> <dosya=içerik>...
sina() {
  local ad="$1" beklenen="$2"; shift 2
  kur "$gecici/abi" "$@"
  paketle "$gecici/abi" "$gecici/abi.apk"
  local kod=0
  bash "$betik" "$gecici/evrensel.apk" arm64-v8a "$gecici/abi.apk" >/dev/null 2>&1 || kod=$?
  if [[ "$beklenen" == 0 && $kod -ne 0 ]]; then
    echo "BAŞARISIZ: $ad: uygun bekleniyordu, çıkış $kod" >&2; hata=1
  elif [[ "$beklenen" == HATA && $kod -eq 0 ]]; then
    echo "BAŞARISIZ: $ad: hata bekleniyordu" >&2; hata=1
  fi
}

sina "uygun ABI APK'sı" 0 "${ortak[@]}" "lib/arm64-v8a/a.so=arm64"
sina "farklı classes.dex" HATA \
  "${ortak[@]/classes.dex=dex/classes.dex=baska}" "lib/arm64-v8a/a.so=arm64"
sina "fazladan başka işlemci" HATA \
  "${ortak[@]}" "lib/arm64-v8a/a.so=arm64" "lib/x86_64/a.so=x64"
sina "farklı yerel kütüphane" HATA "${ortak[@]}" "lib/arm64-v8a/a.so=baska"
sina "eksik yerel kütüphane" HATA "${ortak[@]}"
sina "evrenselde olmayan dosya" HATA \
  "${ortak[@]}" "lib/arm64-v8a/a.so=arm64" "assets/fazla=x"
sina "farklı imza dosyası yok sayılır" 0 \
  "${ortak[@]/META-INF\/X.SF=imza/META-INF/X.SF=baska}" "lib/arm64-v8a/a.so=arm64"

if [[ $hata -ne 0 ]]; then exit 1; fi
echo "abi-apk-denetle: bütün durumlar geçti"

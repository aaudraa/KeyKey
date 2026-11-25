#!/usr/bin/env bash
# fdroid-deposu-kur.sh'nin sürüm seçimini ve indirilen APK'ların
# denetimini sahte bir gh ile sınar. fdroid update'in kendisini CI'daki
# "Depo provası" işi sınar.
# Kullanım: bash resources/scripts/fdroid-deposu-kur-test.sh
set -euo pipefail

betik="$(cd "$(dirname "$0")" && pwd)/fdroid-deposu-kur.sh"
gecici="$(mktemp -d)"
trap 'rm -rf "$gecici"' EXIT
hata=0

# Sahte gh: "release list" GH_SAHTE_LISTE'yi yazar; "release download"
# GH_SAHTE_DOSYALAR klasöründeki <etiket>/ dosyalarını --dir'e kopyalar.
mkdir -p "$gecici/bin"
cat > "$gecici/bin/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1 $2" == "release list" ]]; then
  cat "$GH_SAHTE_LISTE"
elif [[ "$1 $2" == "release download" ]]; then
  etiket="$3"; shift 3
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--dir" ]]; then hedef="$2"; shift; fi
    shift
  done
  mkdir -p "$hedef"
  cp "$GH_SAHTE_DOSYALAR/$etiket/"* "$hedef/"
else
  echo "sahte gh: beklenmeyen komut: $*" >&2
  exit 1
fi
EOF
chmod +x "$gecici/bin/gh"
export PATH="$gecici/bin:$PATH"

# gh release list --json tagName,isDraft,isPrerelease çıktısı (en yeni başta).
cat > "$gecici/liste.json" <<'EOF'
[{"tagName":"v1.13.0","isDraft":true,"isPrerelease":false},
 {"tagName":"v1.12.1-deneme.1","isDraft":false,"isPrerelease":true},
 {"tagName":"v1.12.0","isDraft":false,"isPrerelease":false},
 {"tagName":"deneme-obtainium-1","isDraft":false,"isPrerelease":true},
 {"tagName":"v1.11.1","isDraft":false,"isPrerelease":false},
 {"tagName":"v1.11.0","isDraft":false,"isPrerelease":false},
 {"tagName":"v1.10.0","isDraft":false,"isPrerelease":false},
 {"tagName":"v1.9.0","isDraft":false,"isPrerelease":false}]
EOF
export GH_SAHTE_LISTE="$gecici/liste.json"

liste="$(bash "$betik" --surum-listesi --surumler 3 | tr '\n' ' ')"
if [[ "$liste" != "v1.12.0 v1.11.1 v1.11.0 " ]]; then
  echo "BAŞARISIZ: sürüm listesi '$liste', beklenen 'v1.12.0 v1.11.1 v1.11.0 '" >&2
  hata=1
fi

# İndirme denetimi: özeti tutmayan APK reddedilir.
mkdir -p "$gecici/dosyalar/v1.12.0"
printf 'apk' > "$gecici/dosyalar/v1.12.0/keykey-1.12.0.apk"
printf '%s  keykey-1.12.0.apk\n' "$(printf 'baska' | sha256sum | cut -d' ' -f1)" \
  > "$gecici/dosyalar/v1.12.0/SHA256SUMS"
export GH_SAHTE_DOSYALAR="$gecici/dosyalar"
if bash "$betik" --indir v1.12.0 --apk-klasoru "$gecici/apk" >/dev/null 2>&1; then
  echo "BAŞARISIZ: özeti tutmayan APK kabul edildi" >&2
  hata=1
fi

# Özeti tutan ama imzası okunamayan APK da reddedilir (imza-ozeti.sh düşer).
printf '%s  keykey-1.12.0.apk\n' "$(printf 'apk' | sha256sum | cut -d' ' -f1)" \
  > "$gecici/dosyalar/v1.12.0/SHA256SUMS"
rm -rf "$gecici/apk"
if ANDROID_HOME="$gecici/sdk-yok" bash "$betik" --indir v1.12.0 \
    --apk-klasoru "$gecici/apk" >/dev/null 2>&1; then
  echo "BAŞARISIZ: imzası okunamayan APK kabul edildi" >&2
  hata=1
fi
if compgen -G "$gecici/apk/*.apk" >/dev/null; then
  echo "BAŞARISIZ: reddedilen APK klasörde kaldı" >&2
  hata=1
fi

if [[ $hata -ne 0 ]]; then exit 1; fi
echo "fdroid-deposu-kur: bütün durumlar geçti"

#!/usr/bin/env bash
# KeyKey'in kendi F-Droid deposunu yayımlanmış sürümlerden baştan kurar.
# Tasarım: resources/docs/dagitim.md#3-kendi-f-droid-deposu
#
# Kullanım:
#   fdroid-deposu-kur.sh --surum-listesi [--surumler N]
#       Depoya girecek etiketleri yazar: taslak ve ön sürüm hariç en yeni N
#       sürüm (varsayılan 3).
#   fdroid-deposu-kur.sh --indir <etiket> --apk-klasoru <klasör>
#       Sürümün APK'larını indirir; her biri SHA256SUMS'a uymalı ve tarifteki
#       AllowedAPKSigningKeys sertifikasıyla imzalı olmalı. Uymayan varsa
#       hiçbiri klasöre konmaz ve betik durur.
#   fdroid-deposu-kur.sh --kur [--surumler N] --cikti <klasör> [--yalniz-evrensel]
#       Sürümleri indirir, fdroid update ile depoyu kurar ve imzalar; Pages'e
#       yüklenecek site <çıktı>/fdroid/repo altına yazılır. Çalışma klasörü
#       (yapılandırma, anahtar yolu) siteye girmez.
#
# --kur için ortam: FDROID_KEYSTORE (dosya yolu), FDROID_KEY_ALIAS,
# FDROID_KEYSTORE_PASSWORD, FDROID_KEY_PASSWORD. Parolalar yapılandırma
# dosyasına yazılmaz; fdroidserver onları ortamdan okur.
# Gereken araçlar: gh (GH_TOKEN), sha256sum, Python, imza-ozeti.sh için
# ANDROID_HOME; --kur için fdroid.
set -euo pipefail

betikler="$(cd "$(dirname "$0")" && pwd)"
kok="$(cd "$betikler/../.." && pwd)"
appid=io.github.aaudraa.keykey
tarif="$kok/resources/f-droid/$appid.yml"
repo_url="https://aaudraa.github.io/KeyKey/fdroid/repo"

py=""
for aday in python3 python; do
  if "$aday" -c "" 2>/dev/null; then py="$aday"; break; fi
done
[[ -n "$py" ]] || { echo "HATA: Python yok." >&2; exit 1; }

kip="" surumler=3 etiket="" apk_klasoru="" cikti="" yalniz_evrensel=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --surum-listesi) kip=liste ;;
    --indir) kip=indir; etiket="$2"; shift ;;
    --kur) kip=kur ;;
    --surumler) surumler="$2"; shift ;;
    --apk-klasoru) apk_klasoru="$2"; shift ;;
    --cikti) cikti="$2"; shift ;;
    --yalniz-evrensel) yalniz_evrensel=1 ;;
    *) echo "HATA: bilinmeyen argüman: $1" >&2; exit 2 ;;
  esac
  shift
done

surum_listesi() {
  gh release list --limit 50 --json tagName,isDraft,isPrerelease |
    "$py" -c '
import json, sys
n = int(sys.argv[1])
secilen = [r["tagName"] for r in json.load(sys.stdin)
           if not r["isDraft"] and not r["isPrerelease"]
           and r["tagName"].startswith("v")]
print("\n".join(secilen[:n]))
' "$surumler" | tr -d '\r'
}

# indir <etiket> <klasör>
indir() {
  local etiket="$1" hedef="$2" gecici beklenen apk ad sayi=0
  gecici="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$gecici'" RETURN
  gh release download "$etiket" --pattern 'keykey-*.apk' --pattern SHA256SUMS \
    --dir "$gecici" >/dev/null
  beklenen="$(sed -n 's/^AllowedAPKSigningKeys: *//p' "$tarif" | tr -d '[:space:]')"
  [[ -f "$gecici/SHA256SUMS" ]] || { echo "HATA: $etiket: SHA256SUMS yok." >&2; return 1; }
  for apk in "$gecici"/keykey-*.apk; do
    [[ -e "$apk" ]] || continue
    ad="$(basename "$apk")"
    if ! grep -qE "^[0-9a-f]{64}  ${ad//./\\.}\$" "$gecici/SHA256SUMS"; then
      echo "HATA: $etiket: $ad SHA256SUMS'ta yok." >&2; return 1
    fi
    if ! (cd "$gecici" && grep -E "  ${ad//./\\.}\$" SHA256SUMS | sha256sum -c --quiet -); then
      echo "HATA: $etiket: $ad özeti tutmuyor." >&2; return 1
    fi
    local ozet
    if ! ozet="$(bash "$betikler/imza-ozeti.sh" "$apk" 2>"$gecici/imza.txt")" ||
        [[ "$ozet" != "$beklenen" ]]; then
      echo "HATA: $etiket: $ad beklenen sertifikayla ($beklenen) imzalı değil." >&2
      tail -n 5 "$gecici/imza.txt" >&2
      return 1
    fi
    sayi=$((sayi + 1))
  done
  (( sayi > 0 )) || { echo "HATA: $etiket: APK yok." >&2; return 1; }
  mkdir -p "$hedef"
  for apk in "$gecici"/keykey-*.apk; do
    ad="$(basename "$apk")"
    # İşlemciye özel APK'lar istenmiyorsa yalnızca evrensel alınır.
    if (( yalniz_evrensel )) && [[ ! "$ad" =~ ^keykey-[0-9]+\.[0-9]+\.[0-9]+\.apk$ ]]; then
      continue
    fi
    mv "$apk" "$hedef/"
  done
  echo "$etiket: $sayi APK doğrulandı"
}

# Tarifin depoya ait kısmı: derleme ve güncelleme denetimi alanları atılır.
uygulama_bilgisi() {
  sed -e '/^RepoType:/,$d' "$tarif"
  sed -n '/^AllowedAPKSigningKeys:/p' "$tarif"
}

kur() {
  : "${FDROID_KEYSTORE:?}" "${FDROID_KEY_ALIAS:?}"
  : "${FDROID_KEYSTORE_PASSWORD:?}" "${FDROID_KEY_PASSWORD:?}"
  [[ -n "$cikti" ]] || { echo "HATA: --cikti gerekli." >&2; exit 2; }
  local calisma etiketler
  calisma="$(mktemp -d)"
  mkdir -p "$calisma/repo" "$calisma/metadata"
  etiketler="$(surum_listesi)"
  [[ -n "$etiketler" ]] || { echo "HATA: yayımlanmış sürüm yok." >&2; exit 1; }
  while IFS= read -r etiket; do
    indir "$etiket" "$calisma/repo"
  done <<< "$etiketler"

  uygulama_bilgisi > "$calisma/metadata/$appid.yml"
  cp -r "$kok/fastlane/metadata/android/." "$calisma/metadata/$appid/"
  mkdir -p "$calisma/repo/icons"
  cp "$kok/fastlane/metadata/android/en-US/images/icon.png" "$calisma/repo/icons/keykey.png"

  cat > "$calisma/config.yml" <<EOF
repo_url: $repo_url
repo_name: KeyKey
repo_icon: keykey.png
repo_description: >-
  KeyKey'in kendi deposu: GitHub sürümleriyle aynı, aynı anahtarla imzalı
  APK'lar. KeyKey's own repository: the same APKs as the GitHub releases,
  signed with the same key. https://github.com/aaudraa/KeyKey
archive_older: 0
keystore: $FDROID_KEYSTORE
repo_keyalias: $FDROID_KEY_ALIAS
keystorepass: {env: FDROID_KEYSTORE_PASSWORD}
keypass: {env: FDROID_KEY_PASSWORD}
EOF
  chmod 600 "$calisma/config.yml"
  (cd "$calisma" && fdroid update --pretty)

  mkdir -p "$cikti/fdroid"
  rm -rf "$cikti/fdroid/repo"
  cp -r "$calisma/repo" "$cikti/fdroid/repo"
  rm -rf "$calisma"
  echo "Depo kuruldu: $cikti/fdroid/repo ($(tr '\n' ' ' <<< "$etiketler"))"
}

case "$kip" in
  liste) surum_listesi ;;
  indir)
    [[ -n "$apk_klasoru" ]] || { echo "HATA: --apk-klasoru gerekli." >&2; exit 2; }
    indir "$etiket" "$apk_klasoru" ;;
  kur) kur ;;
  *) echo "Kullanım: bkz. betiğin başı" >&2; exit 2 ;;
esac

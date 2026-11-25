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
#   fdroid-deposu-kur.sh --kur --yerel <klasör> --cikti <klasör> [--izinli-anahtar <sha256>]
#       Sürüm indirmek yerine klasördeki keykey-*.apk dosyalarıyla kurar
#       (PR provası: işlemciye özel APK'lar, tek kullanımlık anahtar).
#
# fdroid PATH'te yoksa fdroidserver'ın ana dalı klonlanır (f-droid-derle.sh
# gibi; F-Droid imajında fdroid komutu kurulu değil).
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
# İmza denetleyicisi; IMZA_OZETI yalnızca testte sahtesiyle değiştirilir.
imza_ozeti="${IMZA_OZETI:-$betikler/imza-ozeti.sh}"
# Bütün geçici klasörler bunun altında; betik nasıl biterse bitsin silinir.
gecici_kok="$(mktemp -d)"
trap 'rm -rf "$gecici_kok"' EXIT

py=""
for aday in python3 python; do
  if "$aday" -c "" 2>/dev/null; then py="$aday"; break; fi
done
[[ -n "$py" ]] || { echo "HATA: Python yok." >&2; exit 1; }

kip="" surumler=3 etiket="" apk_klasoru="" cikti="" yalniz_evrensel=0 yerel="" izinli_anahtar=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --surum-listesi) kip=liste ;;
    --indir) kip=indir; etiket="$2"; shift ;;
    --kur) kip=kur ;;
    --surumler) surumler="$2"; shift ;;
    --apk-klasoru) apk_klasoru="$2"; shift ;;
    --cikti) cikti="$2"; shift ;;
    --yalniz-evrensel) yalniz_evrensel=1 ;;
    --yerel) yerel="$2"; shift ;;
    --izinli-anahtar) izinli_anahtar="$2"; shift ;;
    --uygulama-bilgisi) kip=bilgi ;;
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
  gecici="$(mktemp -d "$gecici_kok/indir.XXXXXX")"
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
    if ! ozet="$(bash "$imza_ozeti" "$apk" 2>"$gecici/imza.txt")" ||
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

# fdroid_calistir <argümanlar...>: fdroid'i bulur ya da klonlayıp çalıştırır.
fdroid_calistir() {
  if command -v fdroid >/dev/null; then
    fdroid "$@"
    return
  fi
  local fs="${FDROIDSERVER:-}" deneme
  if [[ -z "$fs" ]]; then
    fs="$(mktemp -d)/fdroidserver"
    for deneme in 1 2 3; do
      rm -rf "$fs"
      if git clone --quiet --depth 1 https://gitlab.com/fdroid/fdroidserver.git "$fs"; then
        break
      fi
      [[ $deneme == 3 ]] && { echo "HATA: fdroidserver klonlanamadı." >&2; return 1; }
      echo "fdroidserver klonlanamadı, yeniden deneniyor ($deneme)" >&2
      sleep 30
    done
    echo "fdroidserver: $(git -C "$fs" rev-parse HEAD)" >&2
  fi
  PATH="$fs:$PATH" PYTHONPATH="$fs:$fs/examples" fdroid "$@"
}

# Tarifin depoya ait kısmı: derleme ve güncelleme denetimi alanları atılır,
# izinli imza anahtarı kalır. --izinli-anahtar onu değiştirir (PR provasında
# APK'lar tek kullanımlık anahtarla imzalı).
uygulama_bilgisi() {
  sed -e '/^RepoType:/,$d' "$tarif"
  if [[ -n "$izinli_anahtar" ]]; then
    echo "AllowedAPKSigningKeys: $izinli_anahtar"
  else
    sed -n '/^AllowedAPKSigningKeys:/p' "$tarif"
  fi
}

kur() {
  : "${FDROID_KEYSTORE:?}" "${FDROID_KEY_ALIAS:?}"
  : "${FDROID_KEYSTORE_PASSWORD:?}" "${FDROID_KEY_PASSWORD:?}"
  [[ -n "$cikti" ]] || { echo "HATA: --cikti gerekli." >&2; exit 2; }
  local etiketler
  calisma="$(mktemp -d "$gecici_kok/calisma.XXXXXX")"
  mkdir -p "$calisma/repo" "$calisma/metadata"
  if [[ -n "$yerel" ]]; then
    etiketler="yerel: $yerel"
    compgen -G "$yerel/keykey-*.apk" >/dev/null || { echo "HATA: $yerel içinde APK yok." >&2; exit 1; }
    cp "$yerel"/keykey-*.apk "$calisma/repo/"
  else
    etiketler="$(surum_listesi)"
    [[ -n "$etiketler" ]] || { echo "HATA: yayımlanmış sürüm yok." >&2; exit 1; }
    while IFS= read -r etiket; do
      indir "$etiket" "$calisma/repo"
    done <<< "$etiketler"
  fi

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
  (cd "$calisma" && fdroid_calistir update --pretty)

  mkdir -p "$cikti/fdroid"
  rm -rf "$cikti/fdroid/repo"
  cp -r "$calisma/repo" "$cikti/fdroid/repo"
  echo "Depo kuruldu: $cikti/fdroid/repo ($(tr '\n' ' ' <<< "$etiketler"))"
}

case "$kip" in
  liste) surum_listesi ;;
  indir)
    [[ -n "$apk_klasoru" ]] || { echo "HATA: --apk-klasoru gerekli." >&2; exit 2; }
    indir "$etiket" "$apk_klasoru" ;;
  kur) kur ;;
  bilgi) uygulama_bilgisi ;;
  *) echo "Kullanım: bkz. betiğin başı" >&2; exit 2 ;;
esac

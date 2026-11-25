#!/usr/bin/env bash
# fdroid-deposu-dogrula.sh'yi tek kullanımlık anahtarla imzalanmış yapay bir
# depoyla sınar: doğru depo geçer; yanlış parmak izi, tutmayan APK özeti,
# eksik sürüm sayısı ve siteye giren yapılandırma reddedilir.
# Gereken araçlar: keytool, jarsigner, Python.
# Kullanım: bash resources/scripts/fdroid-deposu-dogrula-test.sh
set -euo pipefail

betik="$(cd "$(dirname "$0")" && pwd)/fdroid-deposu-dogrula.sh"
gecici="$(mktemp -d)"
trap 'rm -rf "$gecici"' EXIT
hata=0

py=""
for aday in python3 python; do
  if "$aday" -c "" 2>/dev/null; then py="$aday"; break; fi
done

export DENEME_PAROLA=deneme-parola
keytool -genkeypair -keystore "$gecici/a.jks" -storetype PKCS12 -alias deneme \
  -keyalg RSA -keysize 2048 -validity 1 -dname CN=deneme \
  -storepass:env DENEME_PAROLA -keypass:env DENEME_PAROLA >/dev/null 2>&1
parmak="$(keytool -list -v -keystore "$gecici/a.jks" -storepass:env DENEME_PAROLA |
  sed -n 's/^[[:space:]]*SHA256: //p' | head -n 1 | tr -d ':\r' | tr 'A-F' 'a-f')"

# depo_kur <klasör>: iki APK'lı (evrensel ve arm64) yapay depo.
depo_kur() {
  local d="$1"
  mkdir -p "$d"
  printf 'evrensel' > "$d/keykey-1.12.0.apk"
  printf 'arm64' > "$d/keykey-1.12.0-arm64-v8a.apk"
  "$py" - "$d" <<'EOF'
import hashlib, json, os, sys, zipfile
d = sys.argv[1]
def surum(ad, nativecode):
    ozet = hashlib.sha256(open(os.path.join(d, ad), "rb").read()).hexdigest()
    return ozet, {"file": {"name": "/" + ad, "sha256": ozet},
                  "manifest": {"versionName": "1.12.0", "versionCode": 19,
                               "nativecode": nativecode}}
surumler = dict([surum("keykey-1.12.0.apk", ["arm64-v8a", "armeabi-v7a", "x86_64"]),
                 surum("keykey-1.12.0-arm64-v8a.apk", ["arm64-v8a"])])
index = {"packages": {"io.github.aaudraa.keykey": {"versions": surumler}}}
json.dump(index, open(os.path.join(d, "index-v2.json"), "w"))
for jar in ("entry.jar", "index-v1.jar"):
    with zipfile.ZipFile(os.path.join(d, jar), "w") as z:
        z.writestr("icerik.json", "{}")
EOF
  # fdroid update gibi: entry.jar SHA-256, index-v1.jar eski istemciler için SHA-1.
  jarsigner -keystore "$gecici/a.jks" -storepass:env DENEME_PAROLA \
    "$d/entry.jar" deneme >/dev/null 2>&1
  jarsigner -keystore "$gecici/a.jks" -storepass:env DENEME_PAROLA \
    -sigalg SHA1withRSA -digestalg SHA1 "$d/index-v1.jar" deneme >/dev/null 2>&1
}

# bekle <geçmeli|düşmeli> <açıklama> <betik argümanları...>
bekle() {
  local beklenen="$1" aciklama="$2"; shift 2
  if bash "$betik" "$@" >"$gecici/cikti.txt" 2>&1; then sonuc=geçmeli; else sonuc=düşmeli; fi
  if [[ "$sonuc" != "$beklenen" ]]; then
    echo "BAŞARISIZ: $aciklama ($beklenen idi)" >&2
    sed 's/^/  /' "$gecici/cikti.txt" >&2
    hata=1
  fi
}

depo_kur "$gecici/iyi"
bekle geçmeli "doğru depo, parmak izsiz" "$gecici/iyi"
bekle geçmeli "doğru depo, doğru parmak izi" "$gecici/iyi" --parmak-izi "$parmak"
bekle geçmeli "doğru depo, beklenen iki APK" "$gecici/iyi" --apk-sayisi 2
bekle düşmeli "yanlış parmak izi" "$gecici/iyi" --parmak-izi "$(printf '0%.0s' {1..64})"
bekle düşmeli "beklenenden az APK" "$gecici/iyi" --apk-sayisi 4

depo_kur "$gecici/ozet"
printf 'degisti' > "$gecici/ozet/keykey-1.12.0.apk"
bekle düşmeli "tutmayan APK özeti" "$gecici/ozet"

depo_kur "$gecici/sizinti"
printf 'keystore: x' > "$gecici/sizinti/config.yml"
bekle düşmeli "siteye giren config.yml" "$gecici/sizinti"

depo_kur "$gecici/imzasiz"
"$py" -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1],'w').writestr('a','b')" "$gecici/imzasiz/entry.jar"
bekle düşmeli "imzasız entry.jar" "$gecici/imzasiz"

if [[ $hata -ne 0 ]]; then exit 1; fi
echo "fdroid-deposu-dogrula: bütün durumlar geçti"

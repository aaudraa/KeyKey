#!/usr/bin/env bash
# Kurulan F-Droid deposunu yayımlamadan önce denetler:
# - entry.jar ve index-v1.jar imzalı ve imzaları geçerli,
# - index-v2.json'da KeyKey var; her sürümün APK'sı klasörde ve özeti tutuyor,
# - siteye yapılandırma, anahtar ya da metadata girmemiş.
#
# Kullanım: fdroid-deposu-dogrula.sh <repo-klasörü> [--parmak-izi <sha256>] [--apk-sayisi N]
#   --parmak-izi  İndeksi imzalayan sertifikanın SHA-256'sı buna eşit olmalı
#                 (gerçek depo). Verilmezse yalnızca imzanın geçerliliğine
#                 bakılır (prova, tek kullanımlık anahtar).
#   --apk-sayisi  İndekste tam bu kadar APK olmalı (işlemciye özel APK provası).
# Test: fdroid-deposu-dogrula-test.sh
set -euo pipefail

repo="${1:?repo klasörü}"
shift
beklenen="" apk_sayisi=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --parmak-izi) beklenen="$2"; shift ;;
    --apk-sayisi) apk_sayisi="$2"; shift ;;
    *) echo "HATA: bilinmeyen argüman: $1" >&2; exit 2 ;;
  esac
  shift
done
appid=io.github.aaudraa.keykey

py=""
for aday in python3 python; do
  if "$aday" -c "" 2>/dev/null; then py="$aday"; break; fi
done
[[ -n "$py" ]] || { echo "HATA: Python yok." >&2; exit 1; }

for jar in entry.jar index-v1.jar; do
  [[ -f "$repo/$jar" ]] || { echo "HATA: $jar yok." >&2; exit 1; }
  cikti="$(jarsigner -verify "$repo/$jar" 2>&1 || true)"
  if ! grep -q "^jar verified" <<< "$(tr -d '\r' <<< "$cikti")"; then
    echo "HATA: $jar imzası geçersiz:" >&2
    printf '%s\n' "$cikti" >&2
    exit 1
  fi
  if [[ -n "$beklenen" ]]; then
    gercek="$(keytool -printcert -jarfile "$repo/$jar" 2>/dev/null |
      sed -n 's/^[[:space:]]*SHA256: //p' | head -n 1 | tr -d ':\r' | tr 'A-F' 'a-f' || true)"
    if [[ "$gercek" != "$beklenen" ]]; then
      echo "HATA: $jar '${gercek}' ile imzalı, beklenen '${beklenen}'." >&2
      exit 1
    fi
  fi
done

"$py" - "$repo" "$appid" "$apk_sayisi" <<'EOF'
import hashlib, json, os, sys
repo, appid, beklenen_sayi = sys.argv[1], sys.argv[2], sys.argv[3]
with open(os.path.join(repo, "index-v2.json"), encoding="utf-8") as f:
    index = json.load(f)
paket = index.get("packages", {}).get(appid)
if not paket or not paket.get("versions"):
    sys.exit(f"HATA: indekste {appid} ya da sürümü yok.")
surumler = paket["versions"].values()
for surum in surumler:
    dosya = surum["file"]
    yol = os.path.join(repo, dosya["name"].lstrip("/"))
    with open(yol, "rb") as f:
        ozet = hashlib.sha256(f.read()).hexdigest()
    if ozet != dosya["sha256"]:
        sys.exit(f"HATA: {dosya['name']} özeti indekstekiyle tutmuyor.")
    m = surum["manifest"]
    print(f"{m['versionName']} ({m['versionCode']}) {dosya['name']} "
          f"{','.join(m.get('nativecode', [])) or 'evrensel'}")
if beklenen_sayi and len(surumler) != int(beklenen_sayi):
    sys.exit(f"HATA: indekste {len(surumler)} APK var, beklenen {beklenen_sayi}.")
EOF

yasak="$(find "$repo" \( -name '*.jks' -o -name 'config.yml' -o -name '*.keystore' -o -path '*/metadata/*' \) -print)"
if [[ -n "$yasak" ]]; then
  echo "HATA: siteye girmemesi gereken dosyalar:" >&2
  printf '%s\n' "$yasak" >&2
  exit 1
fi
echo "Depo doğrulandı: $repo"

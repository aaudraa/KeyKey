#!/usr/bin/env bash
# Kurulan F-Droid deposunu yayımlamadan önce denetler:
# - entry.jar ve index-v1.jar imzalı ve imzaları geçerli,
# - index-v2.json'da KeyKey var; her sürümün APK'sı klasörde ve özeti tutuyor,
# - siteye yapılandırma, anahtar ya da metadata girmemiş.
#
# Kullanım: fdroid-deposu-dogrula.sh <repo-klasörü> [beklenen-parmak-izi]
#   Parmak izi verilirse indeksi imzalayan sertifikanın SHA-256'sı ona eşit
#   olmalı (gerçek depo); verilmezse yalnızca imzanın geçerliliğine bakılır
#   (prova, tek kullanımlık anahtar).
set -euo pipefail

repo="${1:?repo klasörü}"
beklenen="${2:-}"
appid=io.github.aaudraa.keykey

py=""
for aday in python3 python; do
  if "$aday" -c "" 2>/dev/null; then py="$aday"; break; fi
done
[[ -n "$py" ]] || { echo "HATA: Python yok." >&2; exit 1; }

for jar in entry.jar index-v1.jar; do
  [[ -f "$repo/$jar" ]] || { echo "HATA: $jar yok." >&2; exit 1; }
  cikti="$(jarsigner -verify -verbose -certs "$repo/$jar")"
  grep -q "^jar verified" <<< "$cikti" || { echo "HATA: $jar imzası geçersiz." >&2; exit 1; }
done

if [[ -n "$beklenen" ]]; then
  gercek="$(unzip -p "$repo/entry.jar" 'META-INF/*.RSA' 'META-INF/*.EC' 2>/dev/null |
    keytool -printcert 2>/dev/null | sed -n 's/^[[:space:]]*SHA256: //p' | head -n 1 |
    tr -d ':\r' | tr 'A-F' 'a-f')"
  if [[ "$gercek" != "$beklenen" ]]; then
    echo "HATA: indeks '$gercek' ile imzalı, beklenen '$beklenen'." >&2
    exit 1
  fi
fi

"$py" - "$repo" "$appid" <<'EOF'
import hashlib, json, os, sys
repo, appid = sys.argv[1], sys.argv[2]
with open(os.path.join(repo, "index-v2.json"), encoding="utf-8") as f:
    index = json.load(f)
paket = index.get("packages", {}).get(appid)
if not paket or not paket.get("versions"):
    sys.exit(f"HATA: indekste {appid} ya da sürümü yok.")
for surum in paket["versions"].values():
    dosya = surum["file"]
    yol = os.path.join(repo, dosya["name"].lstrip("/"))
    with open(yol, "rb") as f:
        ozet = hashlib.sha256(f.read()).hexdigest()
    if ozet != dosya["sha256"]:
        sys.exit(f"HATA: {dosya['name']} özeti indekstekiyle tutmuyor.")
    m = surum["manifest"]
    print(f"{m['versionName']} ({m['versionCode']}) {dosya['name']} "
          f"{','.join(m.get('nativecode', [])) or 'evrensel'}")
EOF

yasak="$(find "$repo" \( -name '*.jks' -o -name 'config.yml' -o -name '*.keystore' -o -path '*/metadata/*' \) -print)"
if [[ -n "$yasak" ]]; then
  echo "HATA: siteye girmemesi gereken dosyalar:" >&2
  printf '%s\n' "$yasak" >&2
  exit 1
fi
echo "Depo doğrulandı: $repo"

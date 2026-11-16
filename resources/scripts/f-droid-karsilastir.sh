#!/usr/bin/env bash
# Bizim imzalı APK'mızla F-Droid'in imzasız derlemesini karşılaştırır: imzayı
# F-Droid'in APK'sına kopyalar ve doğrular (apksigcopier, F-Droid'in kullandığı
# yöntem). Tutmazsa farklı dosyaları listeler.
#
# Kullanım: f-droid-karsilastir.sh <bizim-imzali.apk> <fdroid-imzasiz.apk>
set -euo pipefail

signed="$1"
unsigned="$2"

for f in "$signed" "$unsigned"; do
  if [[ ! -f "$f" ]]; then
    echo "HATA: $f yok; derleme işi APK'yı yüklememiş." >&2
    exit 1
  fi
done

if apksigcopier compare "$signed" --unsigned "$unsigned"; then
  echo "AYNI: F-Droid'in derlemesi bizim imzamızı kabul ediyor."
  exit 0
fi

echo "FARKLI: imza F-Droid'in derlemesine uymuyor. Farklı dosyalar:" >&2
python3 - "$signed" "$unsigned" <<'EOF' >&2
import sys, zipfile
a, b = (zipfile.ZipFile(p) for p in sys.argv[1:3])
ia = {i.filename: i for i in a.infolist() if not i.filename.startswith("META-INF/")}
ib = {i.filename: i for i in b.infolist() if not i.filename.startswith("META-INF/")}
for name in sorted(ia.keys() | ib.keys()):
    x, y = ia.get(name), ib.get(name)
    if x is None or y is None:
        print(f"  yalnızca {'F-Droid' if x is None else 'bizim'}: {name}")
    elif (x.CRC, x.file_size, x.compress_type) != (y.CRC, y.file_size, y.compress_type):
        print(f"  içerik: {name} ({x.file_size} / {y.file_size} bayt)")
order_a = [i.filename for i in a.infolist() if not i.filename.startswith("META-INF/")]
order_b = [i.filename for i in b.infolist() if not i.filename.startswith("META-INF/")]
if order_a != order_b:
    print("  dosya sırası farklı")
EOF
exit 1

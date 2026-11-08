#!/usr/bin/env bash
# Uygulamanın cihazdaki bütün dosyalarında gizli bilgi arar (MASTG: yerel
# depolamada hassas veri). Root gerekir: google_apis imajlı bir emülatörde
# "adb root" çalışır, Play Store imajlarında çalışmaz.
#
# Kullanım: resources/scripts/storage-scan.sh [seri] [aranacaklar]
#
# Uygulamanın iç klasörü (/data/data), cihaz şifrelemesinden önce açılan
# klasörü (/data/user_de) ve dış klasörü (/sdcard/Android/data) bilgisayara
# kopyalanır. Her dosyada aranacaklar dosyasındaki değerler hem UTF-8 hem
# UTF-16 olarak, büyük küçük harf ayırmadan aranır. Bulunan değer yazılmaz,
# aranacaklar dosyasındaki satır numarası yazılır.
# Ayrıca dosya listesi ve SQLite dosyalarının düz metin olup
# olmadığı yazılır. Bir şey bulunursa çıkış kodu 1'dir.
set -u
export MSYS_NO_PATHCONV=1

serial="${1:-emulator-5554}"
here="$(cd "$(dirname "$0")" && pwd)"
needles="${2:-$here/deneme-degerleri.txt}"
package=io.github.aaudraa.keykey

device() { adb -s "$serial" "$@"; }

if [[ "$(device shell id -u | tr -d '\r')" != 0 ]]; then
  device root >/dev/null
  sleep 3
fi
if [[ "$(device shell id -u | tr -d '\r')" != 0 ]]; then
  echo "HATA: root yok. google_apis imajlı bir emülatör gerekir." >&2
  exit 2
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
remote=/data/local/tmp/kk-depolama.tar
device shell "rm -f $remote; tar -cf $remote /data/data/$package /data/user_de/0/$package \
  /sdcard/Android/data/$package 2>/dev/null; true"
device pull "$remote" "$(cygpath -w "$work/d.tar" 2>/dev/null || echo "$work/d.tar")" >/dev/null
device shell rm -f "$remote"
tar -xf "$work/d.tar" -C "$work" 2>/dev/null
rm -f "$work/d.tar"

echo "Dosyalar:"
(cd "$work" && find . -type f -printf '  %s\t%P\n' | sort -k2)

echo "SQLite dosyaları:"
while IFS= read -r file; do
  if head -c 16 "$file" | grep -q 'SQLite format 3'; then
    echo "  ${file#"$work"/}: SQLite (içerik alanlar düzeyinde şifreli olmalı)"
  fi
done < <(find "$work" -type f)

hits=0
line=0
while IFS= read -r needle; do
  line=$((line + 1))
  [[ -z "$needle" || "$needle" == \#* ]] && continue
  utf16=$(printf '%s' "$needle" | iconv -f UTF-8 -t UTF-16LE | od -An -tx1 | tr -d ' \n')
  found=$(grep -rlaiF -- "$needle" "$work" || true)
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if od -An -tx1 -v "$file" | tr -d ' \n' | grep -q "$utf16"; then
      found+=$'\n'"$file (UTF-16)"
    fi
  done < <(find "$work" -type f -size -20M)
  found=$(sed '/^$/d' <<<"$found")
  [[ -z "$found" ]] && continue
  hits=$((hits + 1))
  echo "BULUNDU (aranacakların $line. satırı):"
  sed "s|^$work/|  |" <<<"$found"
done <"$needles"

if [[ $hits -gt 0 ]]; then
  echo "SONUÇ: $hits değer düz metin olarak bulundu."
  exit 1
fi
echo "SONUÇ: temiz."

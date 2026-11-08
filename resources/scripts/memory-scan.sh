#!/usr/bin/env bash
# KeyKey'in çalışan sürecinin belleğinde gizli bilgi arar (MASTG: bellekte
# hassas veri). Root gerekir: google_apis imajlı bir emülatörde "adb root"
# çalışır, Play Store imajlarında çalışmaz.
#
# Kullanım: resources/scripts/memory-scan.sh [seri] [aranacaklar]
#
# Sürecin yazılabilir bellek bölgeleri (/proc/<pid>/maps'te rw olanlar)
# cihazda dökülüp sıkıştırılır ve bilgisayara alınır. Değerler
# memory-search.mjs ile UTF-8 ve UTF-16 olarak aranır; değerin kendisi
# yazılmaz. Döküm işi bitince silinir.
#
# Kasa açıkken çözülmüş kayıtların bellekte olması tasarım gereğidir; asıl
# soru kilitten sonra ne kaldığıdır. Bkz. güvenlik tasarımı, "Bellek".
set -u
export MSYS_NO_PATHCONV=1

serial="${1:-emulator-5554}"
here="$(cd "$(dirname "$0")" && pwd)"
needles="${2:-$here/deneme-degerleri.txt}"
package=io.github.aaudraa.keykey

device() { adb -s "$serial" "$@"; }
winpath() { cygpath -w "$1" 2>/dev/null || echo "$1"; }

if [[ "$(device shell id -u | tr -d '\r')" != 0 ]]; then
  device root >/dev/null
  sleep 3
fi
if [[ "$(device shell id -u | tr -d '\r')" != 0 ]]; then
  echo "HATA: root yok. google_apis imajlı bir emülatör gerekir." >&2
  exit 2
fi

pid=$(device shell pidof "$package" | tr -d '\r' | awk '{print $1}')
if [[ -z "$pid" ]]; then
  echo "HATA: $package çalışmıyor." >&2
  exit 2
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Cihazda çalışan kısım. Ayrılmış ama kullanılmayan bölgeler sıfır okunur,
# sıkıştırınca yer tutmaz. Okunamayan bölge atlanır.
cat >"$work/dump.sh" <<'DEVICE'
pid=$1
out=$2
rm -f "$out"
grep ' rw' /proc/$pid/maps | while read range rest; do
  s=${range%-*}
  e=${range#*-}
  dd if=/proc/$pid/mem bs=1048576 iflag=skip_bytes,count_bytes \
    skip=$((0x$s)) count=$((0x$e - 0x$s)) 2>/dev/null
done | gzip -1 >"$out"
DEVICE

remote_script=/data/local/tmp/kk-bellek.sh
remote_dump=/data/local/tmp/kk-bellek.gz
device push "$(winpath "$work/dump.sh")" "$remote_script" >/dev/null
device shell sh "$remote_script" "$pid" "$remote_dump"
device pull "$remote_dump" "$(winpath "$work/bellek.gz")" >/dev/null
device shell rm -f "$remote_script" "$remote_dump"

echo "Süreç $pid, sıkıştırılmış döküm $(($(stat -c %s "$work/bellek.gz") / 1048576)) MB."
node "$(winpath "$here/memory-search.mjs")" "$(winpath "$work/bellek.gz")" "$(winpath "$needles")"

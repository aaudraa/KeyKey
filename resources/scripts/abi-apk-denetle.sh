#!/usr/bin/env bash
# İşlemciye özel APK'nın evrensel APK'nın alt kümesi olduğunu denetler.
#
# Evrensel APK F-Droid'in kendi derlemesiyle bayt bayt aynı çıkıyor
# (f-droid-karsilastir.sh); bu denetim de işlemciye özel APK'nın aynı
# derlemeden geldiğini gösterir: imza dosyaları (META-INF/) dışındaki her
# dosyası evrenseldekiyle aynı olmalı ve evrenselin o işlemciye ait her
# dosyası onda da bulunmalı. Başka işlemcinin klasörü olmamalı.
#
# Kullanım: abi-apk-denetle.sh <evrensel-apk> <abi> <abi-apk>
# Tasarım: resources/docs/dagitim.md#doğrulanabilirlik
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Kullanım: $0 <evrensel-apk> <abi> <abi-apk>" >&2
  exit 2
fi
evrensel="$1" abi="$2" abi_apk="$3"

# liste <apk>: imza dosyaları dışındaki dosyalar, sıralı.
liste() {
  unzip -Z1 "$1" | grep -v '/$' | grep -v '^META-INF/' | LC_ALL=C sort
}

# beklenen: evrenselin dosyalarından lib/ altında yalnızca bu işlemcininkiler.
beklenen="$(liste "$evrensel" | grep -E -v '^lib/' || true)
$(liste "$evrensel" | grep -E "^lib/${abi}/" || true)"
beklenen="$(printf '%s\n' "$beklenen" | grep -v '^$' | LC_ALL=C sort)"
gercek="$(liste "$abi_apk")"

if [[ -z "$(printf '%s\n' "$beklenen" | grep "^lib/${abi}/" || true)" ]]; then
  echo "HATA: evrensel APK'da lib/${abi}/ yok." >&2
  exit 1
fi

if [[ "$beklenen" != "$gercek" ]]; then
  echo "HATA: ${abi_apk} dosya listesi evrenselin ${abi} alt kümesi değil:" >&2
  diff <(printf '%s\n' "$beklenen") <(printf '%s\n' "$gercek") >&2 || true
  exit 1
fi

farkli=0
while IFS= read -r dosya; do
  a="$(unzip -p "$evrensel" "$dosya" | sha256sum | cut -d' ' -f1)"
  b="$(unzip -p "$abi_apk" "$dosya" | sha256sum | cut -d' ' -f1)"
  if [[ "$a" != "$b" ]]; then
    echo "HATA: ${dosya} evrensel APK'dakinden farklı." >&2
    farkli=1
  fi
done <<< "$gercek"
[[ $farkli -eq 0 ]] || exit 1

echo "${abi_apk}: evrenselin ${abi} alt kümesi ($(printf '%s\n' "$gercek" | wc -l) dosya)"

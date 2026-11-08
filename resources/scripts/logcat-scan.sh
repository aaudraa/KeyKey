#!/usr/bin/env bash
# Logcat'te gizli bilgi arar. Kullanım:
#
#   resources/scripts/logcat-scan.sh baslat [seri]
#   (uygulamayı kullan ya da cihaz testlerini çalıştır)
#   resources/scripts/logcat-scan.sh tara [seri] [aranacaklar] [kayıt dosyası]
#
# "baslat" logcat tamponunu büyütür ve temizler. "tara" bütün cihazın
# kaydını alır (yalnızca KeyKey'in değil; otomatik doldurma gibi sistem
# parçaları da kayıt yazar) ve aranacaklar dosyasındaki her değeri büyük
# küçük harf ayırmadan arar. Değerler testlerde ve elle denemede kullanılan
# deneme parolaları, anahtarlar ve kullanıcı adlarıdır. Bulunan değer ekrana
# yazılmaz; satırdaki yeri [GİZLİ] olarak gösterilir. Bir şey bulunursa çıkış
# kodu 1'dir.
set -u
export MSYS_NO_PATHCONV=1

cmd="${1:-}"
serial="${2:-emulator-5554}"
here="$(cd "$(dirname "$0")" && pwd)"
needles="${3:-$here/logcat-gizliler.txt}"

device() { adb -s "$serial" "$@"; }

case "$cmd" in
  baslat)
    device logcat -G 16M >/dev/null
    device logcat -c
    echo "Logcat temizlendi ($serial)."
    ;;
  tara)
    log="${4:-$(mktemp)}"
    device logcat -d -v threadtime >"$log"
    lines=$(wc -l <"$log")
    # Tampon dolduysa en eski satırlar düşmüş olabilir; tarama eksik kalır.
    first=$(head -1 "$log")
    echo "Kayıt: $lines satır, ilk satır: ${first:0:40}"
    hits=0
    while IFS= read -r needle; do
      [[ -z "$needle" || "$needle" == \#* ]] && continue
      found=$(grep -F -i -- "$needle" "$log")
      [[ -z "$found" ]] && continue
      hits=$((hits + $(wc -l <<<"$found")))
      # Değerin kendisi yerine kaç kez ve hangi kayıt etiketlerinde geçtiği.
      awk -v n="$needle" 'BEGIN { IGNORECASE = 1 }
        { line = $0; gsub(n, "[GİZLİ]", line); print "  " substr(line, 1, 200) }' \
        <<<"$found" | head -5
    done <"$needles"
    if [[ $hits -gt 0 ]]; then
      echo "SONUÇ: $hits satırda gizli değer bulundu."
      exit 1
    fi
    echo "SONUÇ: temiz."
    ;;
  *)
    echo "Kullanım: $0 baslat|tara [seri] [aranacaklar] [kayıt dosyası]" >&2
    exit 2
    ;;
esac

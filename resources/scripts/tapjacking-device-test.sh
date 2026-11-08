#!/usr/bin/env bash
# KeyKey'in bindirme pencerelerine ve erişilebilirlik servislerine karşı
# korumasını açık bir emülatörde dener.
#
# Kullanım: resources/scripts/tapjacking-device-test.sh [seri]
#
# Önce: KeyKey kurulu olmalı (kilit ya da kurulum ekranı, ikisinde de parola
# kutusunun "Göster" düğmesi var) ve saldırgan uygulama derlenmiş olmalı:
#   android/gradlew -p resources/test-apps/saldirgan assembleDebug
#
# Denenenler:
# 1. Yarı saydam, dokunuşları geçiren bindirme penceresi açıkken KeyKey öne
#    gelir. Android 12+ pencereyi gizlemeli. Android 11'de gizlenemez; orada
#    "Göster" düğmesine dokunuş düşürülmeli, bindirme kapanınca geçmeli.
# 2. Kendini erişilebilirlik aracı olarak bildirmeyen bir servis KeyKey'in
#    ekranını okumaya çalışır. Android 14+ hiçbir şey okuyamamalı. Daha eski
#    sürümlerde okuyabildiği yazılır; bu bilinen bir sınırdır, hata sayılmaz.
set -u
export MSYS_NO_PATHCONV=1

serial="${1:-emulator-5554}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
attacker_apk="$root/resources/test-apps/saldirgan/build/outputs/apk/debug/saldirgan-debug.apk"
attacker=io.github.aaudraa.saldirgan
keykey=io.github.aaudraa.keykey
reader="$attacker/.ReaderService"
fail=0

device() { adb -s "$serial" "$@"; }

nodes() {
  device shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  device exec-out cat /sdcard/ui.xml | tr '>' '\n' | grep '<node'
}

# Etikete (metin ya da açıklama) göre düğmenin ortasına dokunur.
tap_label() {
  local line bounds
  line=$(timeout 30 bash -c "$(declare -f nodes device); serial=$serial; nodes" \
    | grep -E "(text|content-desc)=\"($1)\"" | head -1)
  [[ -z "$line" ]] && return 1
  bounds=$(sed -E 's/.*bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]".*/\1 \2 \3 \4/' <<<"$line")
  # shellcheck disable=SC2086
  set -- $bounds
  device shell input tap $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 ))
}

has_label() {
  timeout 30 bash -c "$(declare -f nodes device); serial=$serial; nodes" \
    | grep -qE "(text|content-desc)=\"($1)\""
}

check() {
  if [[ "$1" == ok ]]; then echo "  geçti: $2"; else echo "  KALDI: $2"; fail=1; fi
}

overlay_on_screen() {
  device shell dumpsys window windows | grep -A40 "Window #.*$attacker" \
    | grep -oE 'isOnScreen=(true|false)' | head -1
}

open_keykey() {
  device shell am start -n "$keykey/.MainActivity" >/dev/null 2>&1
  sleep 5
  # Yazılımsal grafikli emülatörde çıkan sistem penceresi.
  tap_label 'Wait' >/dev/null 2>&1 && sleep 2
}

sdk=$(device shell getprop ro.build.version.sdk | tr -d '\r')
echo "Android API $sdk ($serial)"
[[ -f "$attacker_apk" ]] || { echo "Saldırgan APK yok: $attacker_apk"; exit 2; }
device shell pm path "$keykey" >/dev/null || { echo "KeyKey kurulu değil."; exit 2; }
# Git Bash'te adb.exe, /c/... biçimindeki yolu tanımaz.
apk_arg="$attacker_apk"
command -v cygpath >/dev/null && apk_arg=$(cygpath -w "$attacker_apk")
device install -r "$apk_arg" >/dev/null || { echo "Saldırgan APK kurulamadı."; exit 2; }
device shell appops set "$attacker" SYSTEM_ALERT_WINDOW allow

cleanup() {
  device shell am start -n "$attacker/.MainActivity" --es mod kapat >/dev/null 2>&1
  device shell settings delete secure enabled_accessibility_services >/dev/null 2>&1
  device shell settings put secure accessibility_enabled 0 >/dev/null 2>&1
}
trap cleanup EXIT

echo "1. Bindirme penceresi"
device shell input keyevent 3
sleep 1
device shell am start -n "$attacker/.MainActivity" >/dev/null
sleep 3
device shell am force-stop "$keykey"
open_keykey
state=$(overlay_on_screen)
if [[ $sdk -ge 31 ]]; then
  [[ "$state" == "isOnScreen=false" ]] && check ok "KeyKey öndeyken bindirme gizli" \
    || check no "KeyKey öndeyken bindirme gizli ($state)"
else
  echo "  bilgi: Android 11'de bindirme gizlenemiyor ($state)"
fi

tap_label 'Show|Göster' || check no "Göster düğmesi bulunamadı"
sleep 2
if [[ $sdk -ge 31 ]]; then
  has_label 'Hide|Gizle' && check ok "bindirme gizliyken dokunuş çalışıyor" \
    || check no "bindirme gizliyken dokunuş çalışıyor"
else
  has_label 'Show|Göster' && ! has_label 'Hide|Gizle' \
    && check ok "bindirmenin altındaki dokunuş düşürüldü" \
    || check no "bindirmenin altındaki dokunuş düşürüldü"
  device shell am start -n "$attacker/.MainActivity" --es mod kapat >/dev/null
  sleep 2
  open_keykey
  tap_label 'Show|Göster'
  sleep 2
  has_label 'Hide|Gizle' && check ok "bindirme kapanınca dokunuş çalışıyor" \
    || check no "bindirme kapanınca dokunuş çalışıyor"
fi
device shell am start -n "$attacker/.MainActivity" --es mod kapat >/dev/null

echo "2. Erişilebilirlik servisi"
device shell settings delete secure enabled_accessibility_services >/dev/null
sleep 1
device shell settings put secure enabled_accessibility_services "$reader"
device shell settings put secure accessibility_enabled 1
sleep 3
device shell input keyevent 3
sleep 2
device logcat -c
open_keykey
# Klavyeyi açar: başka bir uygulamadan olay gelirken de KeyKey okunmaya çalışılır.
tap_label 'Show|Göster|Hide|Gizle'
sleep 1
device shell input keyevent 61
sleep 3
log=$(device logcat -d -s KKOKUYUCU | grep 'olay=')
alive=$(grep -c 'olay=' <<<"$log")
read_lines=$(grep -cE 'pencere=[1-9]|olay_kaynagi_keykey=true' <<<"$log")
max_texts=$(grep -oE 'metin=[0-9]+' <<<"$log" | cut -d= -f2 | sort -n | tail -1)
echo "  okuyucu $alive olay aldı; KeyKey'e ait $read_lines olayda en fazla ${max_texts:-0} metin okudu"
[[ $alive -gt 0 ]] && check ok "okuyucu servis çalışıyor" || check no "okuyucu servis çalışıyor"
if [[ $sdk -ge 34 ]]; then
  [[ $read_lines -eq 0 ]] && check ok "KeyKey'in ekranı okunamıyor" \
    || check no "KeyKey'in ekranı okunamıyor"
else
  echo "  bilgi: Android $sdk'te erişilebilirlik koruması yok (bilinen sınır)"
fi

if [[ $fail == 0 ]]; then echo "SONUÇ: tamam"; else echo "SONUÇ: KALDI"; fi
exit $fail

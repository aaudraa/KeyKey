#!/usr/bin/env bash
# Otomatik yedek klasörünü açık bir cihazda gerçek Storage Access Framework ile
# sınar: integration_test/auto_backup_test.dart'ı başlatır ve klasör ile belge
# seçicilerine bir kullanıcı gibi dokunur.
#
# Kullanım: resources/scripts/auto-backup-device-test.sh [seri] [en fazla saniye]
#
# Klasör seçicide araç çubuğundaki "Yeni klasör" ile bir test klasörü açılır,
# seçilir ve izin verilir; belge seçicide "Kaydet"e basılır. Klasör öğelerine
# dokunulmaz, çünkü Android 11'in belge ekranı onlara gelen adb dokunuşlarını
# yok sayıyor. Test bitince klasör ve elle yedek denemesi silinir. Seçici dili
# İngilizce ya da Türkçe olabilir.
set -u
export MSYS_NO_PATHCONV=1

serial="${1:-emulator-5554}"
limit="${2:-480}"
name=KeyKeyOtomatikTest
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

device() { adb -s "$serial" "$@"; }

screen() { device exec-out cat /sdcard/ui.xml | tr '>' '\n'; }

# Son okunan ekranda [attr] özniteliği [pattern] (ERE, tam eşleşme) olan ilk
# öğeye dokunur.
tap_attr() {
  local line
  line=$(screen | grep -E "$1=\"($2)\"" | head -1)
  [[ -z "$line" ]] && return 1
  # shellcheck disable=SC2046
  set -- $(echo "$line" | sed -E 's/.*bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]".*/\1 \2 \3 \4/')
  device shell input tap $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 ))
}

read_screen() { device shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; }

# Klasör seçicide bir adım ilerler: izin penceresi; test klasörünün içindeyse
# "bu klasörü kullan"; ad penceresi açıksa adı yazıp onay; yoksa "yeni klasör".
step_folder_picker() {
  read_screen || return 1
  tap_attr text 'ALLOW|Allow|İZİN VER|İzin ver' && return 0
  if screen | grep -qiE "text=\"[^\"]*${name}[^\"]*\""; then
    tap_attr text 'USE THIS FOLDER|Use this folder|BU KLASÖRÜ KULLAN|Bu klasörü kullan'
    return 0
  fi
  if screen | grep -qE 'text="(Folder name|Name|Klasör adı|Ad)"'; then
    device shell input text "$name"
    sleep 1
    read_screen
    tap_attr text 'OK|Tamam|TAMAM'
    return 0
  fi
  tap_attr content-desc 'New folder|Yeni klasör'
}

cleanup() {
  device shell "find /sdcard/ -maxdepth 3 -type d -name '$name*' -exec rm -rf {} +" 2>/dev/null
  device shell "find /sdcard/ -name 'keykey-yedek-deneme*.keykey' -delete" 2>/dev/null
}

cleanup
device shell input keyevent KEYCODE_WAKEUP
device shell wm dismiss-keyguard

flutter test integration_test/auto_backup_test.dart -d "$serial" \
  --dart-define=KEYKEY_SAF_TEST=true --reporter expanded >"$log" 2>&1 &
test_pid=$!
started=$SECONDS
while kill -0 "$test_pid" 2>/dev/null; do
  if (( SECONDS - started >= limit )); then
    echo "ZAMAN AŞIMI: test $limit saniyede bitmedi." >&2
    kill "$test_pid" 2>/dev/null
    break
  fi
  focus=$(device shell dumpsys window | grep -m1 mCurrentFocus)
  if [[ "$focus" == *documentsui* ]]; then
    if grep -q 'KKADIM belge-kaydet' "$log"; then
      read_screen && tap_attr text 'SAVE|Save|KAYDET|Kaydet'
    else
      step_folder_picker
    fi
  fi
  sleep 2
done
wait "$test_pid"
status=$?

grep -E 'KKADIM|KKSONUC|Some tests failed|All tests passed|Expected|Actual' "$log" | tail -20
folder=$(device shell "find /sdcard/ -maxdepth 3 -type d -name '$name*' 2>/dev/null" | tr -d '\r' | head -1)
echo "Klasör: ${folder:-yok}; içinde: $( [[ -n "$folder" ]] && device shell ls "$folder" | tr -d '\r' | tr '\n' ' ')"
cleanup
exit "$status"

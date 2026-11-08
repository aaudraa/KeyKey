#!/usr/bin/env bash
# Parmak izi testini açık bir emülatörde gerçek Keystore ile çalıştırır.
#
# Kullanım: resources/scripts/biometric-device-test.sh [seri] [en fazla saniye]
#
# Emülatöre PIN ve parmak izi kaydeder, test sürerken sanal parmağı dokundurur,
# test isteyince ikinci parmak izini ekler. Sonunda PIN'i kaldırır, çünkü emülatör
# PIN varken soğuk açılıştan sonra uygulamayı başlatmıyor.
set -u
export MSYS_NO_PATHCONV=1

serial="${1:-emulator-5554}"
limit="${2:-420}"
pin=1234
package=io.github.aaudraa.keykey
log="$(mktemp)"

device() { adb -s "$serial" "$@"; }

ui_dump() {
  device shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  device exec-out cat /sdcard/ui.xml | tr '>' '\n' | grep -E 'text="[^"]+"' \
    | sed -E 's/.* text="([^"]*)".*bounds="([^"]*)".*/\1 @ \2/'
}

ui_tap() {
  local line
  line=$(ui_dump | grep -F "$1" | head -1)
  [[ -z "$line" ]] && return 1
  # shellcheck disable=SC2046
  set -- $(echo "$line" | sed -E 's/.*\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\].*/\1 \2 \3 \4/')
  device shell input tap $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 ))
}

# Sistemin parmak izi penceresi ekranda mı. Pencere, testlerin ve uygulamanın
# verdiği vazgeç düğmesi metniyle tanınır. `uiautomator dump` ekranın boşta
# kalmasını beklediği için görülen pencerenin açılış animasyonu bitmiştir.
prompt_visible() {
  device shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || return 1
  device exec-out cat /sdcard/ui.xml | tr '>' '\n' \
    | grep -F 'package="com.android.systemui"' \
    | grep -qE 'text="(Vazgeç|Ana parolayı kullan|Cancel|Use master password)"'
}

touch_finger() {
  device emu finger touch "$1" >/dev/null
  sleep 1
  device emu finger remove "$1" >/dev/null
}

# Android'in kayıtlı gördüğü parmak izi sayısı.
fingerprint_count() {
  local count
  count=$(device shell dumpsys fingerprint 2>/dev/null | grep -oE '"count":[0-9]+' | head -1 | cut -d: -f2)
  echo "${count:-0}"
}

# Ayarlardan bir parmak izi kaydeder.
enroll() {
  local finger="$1" step before after screen
  before=$(fingerprint_count)
  # Önceki kayıttan kalan ekran başarı gibi görünmesin.
  device shell am force-stop com.android.settings
  device shell am start -a android.settings.FINGERPRINT_ENROLL >/dev/null
  sleep 4
  device shell input text "$pin"
  device shell input keyevent 66
  sleep 3
  # Android sürümüne göre ekranlar değişiyor: 14'te MORE ve AGREE, 11'de NEXT.
  for step in 1 2 3 4 5 6 7 8; do
    screen=$(ui_dump)
    if grep -qE 'Touch the sensor|Put your finger|Lift, then touch' <<<"$screen"; then
      break
    elif grep -qF 'AGREE' <<<"$screen"; then
      ui_tap 'AGREE'
    elif grep -qF 'NEXT' <<<"$screen"; then
      ui_tap 'NEXT'
    elif grep -qF 'MORE' <<<"$screen"; then
      ui_tap 'MORE'
    else
      break
    fi
    sleep 2
  done
  for step in $(seq 1 14); do
    ui_dump | grep -qF 'Fingerprint added' && break
    touch_finger "$finger"
    sleep 1
  done
  ui_tap 'DONE'
  sleep 1
  after=$(fingerprint_count)
  if [[ "$after" -le "$before" ]]; then
    echo "HATA: parmak izi $finger eklenemedi (sayı $before -> $after)" >&2
    return 1
  fi
}

cleanup() {
  device shell locksettings clear --old "$pin" >/dev/null 2>&1
  # KK_LOG verilirse ayrıntılı günlük saklanır.
  [[ -n "${KK_LOG:-}" ]] && cp "$log" "$KK_LOG"
  rm -f "$log"
}
trap cleanup EXIT

# Yeni açılmış emülatörde ekran uykuda veya kilit ekranında olabilir; o
# zaman ayarların kayıt ekranı açılmaz. PIN konmadan önce kilit kaldırılır.
device shell input keyevent KEYCODE_WAKEUP
device shell wm dismiss-keyguard
sleep 2
device shell locksettings set-pin "$pin" >/dev/null
# Her çalıştırma iki parmak izi ekler. Android 11 emülatöründe PIN'i
# kaldırmak parmak izlerini silmiyor, ayarlardan silme de bitmiyor; beş
# sınırına gelince ikinci parmak izi eklenemez ve test yanlış yerde düşer.
existing=$(fingerprint_count)
if (( existing > 3 )); then
  echo "HATA: emülatörde $existing parmak izi kayıtlı, yenisi eklenemez." \
    "Emülatörü -wipe-data ile yeniden başlat."
  exit 2
fi
enroll 1 || exit 2
echo "Hazır: PIN ve birinci parmak izi kayıtlı."

flutter test integration_test/biometric_test.dart -d "$serial" --dart-define=KK_BIOMETRIC=true --reporter expanded >"$log" 2>&1 &
test_pid=$!

added=0
started=$SECONDS
while kill -0 "$test_pid" 2>/dev/null; do
  if (( SECONDS - started >= limit )); then
    echo "ZAMAN AŞIMI: test $limit saniyede bitmedi." >&2
    kill "$test_pid" 2>/dev/null
    break
  fi
  if [[ "$added" == 0 ]] && grep -q 'KKPARMAK_EKLE' "$log"; then
    added=1
    echo "İkinci parmak izi ekleniyor."
    enroll 2 || echo "HATA: ikinci parmak izi eklenemedi" >&2
    device shell monkey -p "$package" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
    sleep 2
    device shell run-as "$package" touch files/kk_parmak_eklendi
  elif prompt_visible; then
    # Parmak yalnızca pencere yerleşince dokunur. Android 11'in sistem
    # arayüzü, açılış animasyonu sürerken gelen doğrulamada pencereyi hiç
    # kapatmıyor ve sonuç uygulamaya ulaşmıyor.
    touch_finger 1
  fi
  sleep 1
done

wait "$test_pid"
status=$?
tr '\r' '\n' <"$log" | grep -E 'Olmadı|Expected:|Actual:|\[E\]|All tests passed|Some tests failed|[+][0-9]+: .*(biometric|Keystore|parmak|yuva)' | cut -c1-200 | tail -20
echo "SONUÇ: çıkış=$status"
exit "$status"

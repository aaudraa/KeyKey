#!/usr/bin/env bash
# QR testini açık bir emülatörde çalıştırır: önce görsel testleri, sonra kamera
# izni verilmişken ve reddedilmişken tarama ekranını.
#
# Kullanım: resources/scripts/camera-device-test.sh [seri] [her çalıştırma için en fazla saniye]
#
# flutter test uygulamayı her çalıştırmada kurar ve sonunda kaldırır. Bu
# yüzden izin, test "KKKAMERA_IZIN" yazınca, uygulama kuruluyken ayarlanır.
# Reddetmek için "user-fixed" bayrağı konur: Android izin penceresini
# göstermeden reddeder, test pencerede takılmaz. Bu komut Android 11'de yok;
# orada betik izin penceresindeki reddet düğmesine dokunur.
set -u
export MSYS_NO_PATHCONV=1

serial="${1:-emulator-5554}"
limit="${2:-600}"
package=io.github.aaudraa.keykey
permission=android.permission.CAMERA
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

device() { adb -s "$serial" "$@"; }

# Ekranda izin penceresinin reddet düğmesi varsa ona dokunur.
tap_deny() {
  local line
  device shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || return 1
  line=$(device exec-out cat /sdcard/ui.xml | tr '>' '\n' \
    | grep -E 'text="(Deny|DENY|Don.t allow|Reddet)"' | head -1)
  [[ -z "$line" ]] && return 1
  # shellcheck disable=SC2046
  set -- $(echo "$line" | sed -E 's/.*bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]".*/\1 \2 \3 \4/')
  device shell input tap $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 ))
}

# Testi süre sınırıyla çalıştırır. [mode] boş değilse izni ayarlar.
run() {
  local name="$1" mode="$2"
  shift 2
  echo "== $name"
  flutter test integration_test/qr_test.dart -d "$serial" --reporter expanded "$@" >"$log" 2>&1 &
  local test_pid=$! started=$SECONDS sent=0 deny_dialog=0
  while kill -0 "$test_pid" 2>/dev/null; do
    if (( SECONDS - started >= limit )); then
      echo "ZAMAN AŞIMI: $name $limit saniyede bitmedi." >&2
      kill "$test_pid" 2>/dev/null
      break
    fi
    if [[ -n "$mode" && "$sent" == 0 ]] && grep -q 'KKKAMERA_IZIN' "$log"; then
      sent=1
      if [[ "$mode" == granted ]]; then
        device shell pm grant "$package" "$permission"
      else
        # Komut yoksa hata metni basar; çıkış kodu her sürümde güvenilir değil.
        if [[ -n "$(device shell pm set-permission-flags "$package" "$permission" user-fixed 2>&1)" ]]; then
          deny_dialog=1
        fi
      fi
      device shell run-as "$package" touch files/kk_kamera_hazir
      echo "İzin ayarlandı: $mode"
    elif [[ "$deny_dialog" == 1 ]] && tap_deny; then
      deny_dialog=0
      echo "İzin penceresinde reddedildi."
    fi
    sleep 1
  done
  wait "$test_pid"
  local status=$?
  tr '\r' '\n' <"$log" | grep -E 'Expected:|Actual:|\[E\]|All tests passed|Some tests failed|[+][0-9]+( ~[0-9]+)?: ' | cut -c1-200 | tail -8
  echo "$name: çıkış=$status"
  return "$status"
}

failed=0
run "görsel testleri" "" || failed=1
run "kamera izni verilmiş" granted --dart-define=KK_CAMERA=granted --plain-name "kamera izni" || failed=1
run "kamera izni reddedilmiş" denied --dart-define=KK_CAMERA=denied --plain-name "kamera izni" || failed=1

echo "SONUÇ: $([[ "$failed" == 0 ]] && echo tamam || echo BAŞARISIZ)"
exit "$failed"

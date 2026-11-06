#!/usr/bin/env bash
# QR testini açık bir emülatörde çalıştırır: önce görsel testleri, sonra kamera
# izni verilmişken ve reddedilmişken tarama ekranını.
#
# Kullanım: resources/scripts/camera-device-test.sh [seri] [her çalıştırma için en fazla saniye]
#
# flutter test uygulamayı her çalıştırmada kurar ve sonunda kaldırır. Bu
# yüzden izin, test "KKKAMERA_IZIN" yazınca, uygulama kuruluyken ayarlanır.
# Reddetmek için "user-fixed" bayrağı konur: Android izin penceresini
# göstermeden reddeder, test pencerede takılmaz.
set -u
export MSYS_NO_PATHCONV=1

serial="${1:-emulator-5554}"
limit="${2:-600}"
package=io.github.aaudraa.keykey
permission=android.permission.CAMERA
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

device() { adb -s "$serial" "$@"; }

# Testi süre sınırıyla çalıştırır. [mode] boş değilse izni ayarlar.
run() {
  local name="$1" mode="$2"
  shift 2
  echo "== $name"
  flutter test integration_test/qr_test.dart -d "$serial" --reporter expanded "$@" >"$log" 2>&1 &
  local test_pid=$! elapsed=0 sent=0
  while kill -0 "$test_pid" 2>/dev/null; do
    if [[ "$elapsed" -ge "$limit" ]]; then
      echo "ZAMAN AŞIMI: $name $limit saniyede bitmedi." >&2
      kill "$test_pid" 2>/dev/null
      break
    fi
    if [[ -n "$mode" && "$sent" == 0 ]] && grep -q 'KKKAMERA_IZIN' "$log"; then
      sent=1
      if [[ "$mode" == granted ]]; then
        device shell pm grant "$package" "$permission"
      else
        device shell pm set-permission-flags "$package" "$permission" user-fixed
      fi
      device shell run-as "$package" touch files/kk_kamera_hazir
      echo "İzin ayarlandı: $mode"
    fi
    sleep 1
    elapsed=$((elapsed + 1))
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

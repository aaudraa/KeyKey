#!/usr/bin/env bash
# Güvenli pano testini açık bir emülatörde çalıştırır.
#
# Kullanım: resources/scripts/clipboard-device-test.sh [seri] [en fazla saniye]
#
# Test isteyince uygulamayı arka plana alır, 15 saniye sonra geri getirir ve
# testin beklediği işaret dosyasını oluşturur.
set -u
export MSYS_NO_PATHCONV=1

serial="${1:-emulator-5554}"
limit="${2:-300}"
package=io.github.aaudraa.keykey
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

device() { adb -s "$serial" "$@"; }

flutter test integration_test/clipboard_test.dart -d "$serial" --dart-define=KK_CLIPBOARD=true --reporter expanded >"$log" 2>&1 &
test_pid=$!

sent=0
elapsed=0
while kill -0 "$test_pid" 2>/dev/null; do
  if [[ "$elapsed" -ge "$limit" ]]; then
    echo "ZAMAN AŞIMI: test $limit saniyede bitmedi." >&2
    kill "$test_pid" 2>/dev/null
    break
  fi
  if [[ "$sent" == 0 ]] && grep -q 'KKPANO_ARKA' "$log"; then
    sent=1
    echo "Uygulama arka plana alınıyor."
    device shell input keyevent KEYCODE_HOME
    sleep 15
    device shell monkey -p "$package" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
    sleep 2
    device shell run-as "$package" touch files/kk_pano_dondu
  fi
  sleep 1
  elapsed=$((elapsed + 1))
done

wait "$test_pid"
status=$?
tr '\r' '\n' <"$log" | grep -E 'Expected:|Actual:|\[E\]|All tests passed|Some tests failed|[+][0-9]+: ' | cut -c1-200 | tail -12
echo "SONUÇ: çıkış=$status"
exit "$status"

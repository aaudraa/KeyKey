#!/usr/bin/env bash
# Açık bir emülatörde bütün cihaz testlerini sırayla çalıştırır ve özet verir.
#
# Kullanım: resources/scripts/all-device-tests.sh [seri]
#
# Sırayla: bütün entegrasyon testleri, parmak izi, pano ve kamera betikleri.
# Her adımın kendi süre sınırı vardır; biri takılırsa öbürleri yine çalışır.
set -u
export MSYS_NO_PATHCONV=1

serial="${1:-emulator-5554}"
here="$(cd "$(dirname "$0")" && pwd)"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

results=()

step() {
  local name="$1"
  shift
  echo "=== $name ($(date +%H:%M:%S))"
  "$@"
  local status=$?
  results+=("$name: $([[ "$status" == 0 ]] && echo tamam || echo "BAŞARISIZ ($status)")")
}

integration() {
  timeout 1800 flutter test integration_test -d "$serial" --reporter expanded >"$log" 2>&1
  local status=$?
  [[ "$status" == 124 ]] && echo "ZAMAN AŞIMI: entegrasyon testleri 30 dakikada bitmedi." >&2
  tr '\r' '\n' <"$log" | grep -E 'KKOLCUM|Expected:|Actual:|\[E\]|All tests passed|Some tests failed' | cut -c1-200 | tail -15
  return "$status"
}

step "entegrasyon testleri" integration
step "parmak izi" bash "$here/biometric-device-test.sh" "$serial" 600
step "pano" bash "$here/clipboard-device-test.sh" "$serial" 300
step "kamera ve QR" bash "$here/camera-device-test.sh" "$serial" 600

echo "=== Özet: $serial"
failed=0
for result in "${results[@]}"; do
  echo "  $result"
  [[ "$result" == *BAŞARISIZ* ]] && failed=1
done
exit "$failed"

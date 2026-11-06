#!/usr/bin/env bash
# Yayın APK'sının güvenlik kurallarına uyduğunu denetler.
# Kullanım: bash resources/scripts/check-release-apk.sh [apk-yolu]
set -euo pipefail

apk="${1:-build/app/outputs/flutter-apk/app-release.apk}"

# Yeni bir izin gerekirse buraya bilinçli olarak eklenmeli.
allowed_permissions=(
  "io.github.aaudraa.keykey.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"
  # Parmak iziyle açma. androidx.biometric ikisini de ekliyor.
  "android.permission.USE_BIOMETRIC"
  "android.permission.USE_FINGERPRINT"
  # QR okuma. Yalnızca tarama ekranında istenir. Kamera ve görsel seçici
  # kütüphanelerinin eklediği öbür izinler manifest'te bilerek kaldırıldı.
  "android.permission.CAMERA"
)

sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "$sdk" ]]; then
  echo "HATA: ANDROID_HOME tanımlı değil." >&2
  exit 2
fi
if [[ ! -f "$apk" ]]; then
  echo "HATA: APK bulunamadı: $apk" >&2
  exit 2
fi

build_tools="$(find "$sdk/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
aapt2="$build_tools/aapt2"
[[ -x "$aapt2" ]] || aapt2="$build_tools/aapt2.exe"

failed=0
fail() {
  echo "HATA: $1"
  failed=1
}

permissions="$("$aapt2" dump permissions "$apk" | tr -d '\r' | sed -n "s/^uses-permission: name='\([^']*\)'.*/\1/p")"
echo "İzinler:"
while IFS= read -r permission; do
  [[ -z "$permission" ]] && continue
  echo "  $permission"
  allowed=0
  for candidate in "${allowed_permissions[@]}"; do
    [[ "$permission" == "$candidate" ]] && allowed=1
  done
  [[ "$allowed" == 1 ]] || fail "izin verilenler listesinde olmayan izin: $permission"
done <<< "$permissions"

if "$aapt2" dump badging "$apk" | grep -q 'application-debuggable'; then
  fail "APK debuggable olarak derlenmiş."
fi

manifest="$("$aapt2" dump xmltree --file AndroidManifest.xml "$apk" | tr -d '\r')"
if ! grep -Eq 'allowBackup\([^)]*\)=(false|\(type 0x12\)0x0)' <<< "$manifest"; then
  fail "allowBackup kapalı değil."
fi
if ! grep -q 'android:dataExtractionRules' <<< "$manifest"; then
  fail "dataExtractionRules tanımlı değil."
fi

if [[ "$failed" != 0 ]]; then
  echo "Sonuç: BAŞARISIZ"
  exit 1
fi
echo "Sonuç: tamam"

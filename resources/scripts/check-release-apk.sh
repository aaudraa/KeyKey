#!/usr/bin/env bash
# Yayın APK'sının güvenlik kurallarına uyduğunu denetler.
# Kullanım: bash resources/scripts/check-release-apk.sh [apk-yolu]
set -euo pipefail

apk="${1:-build/app/outputs/flutter-apk/app-release.apk}"

# Yeni bir izin gerekirse buraya bilinçli olarak eklenmeli.
allowed_permissions=(
  "io.github.aaudraa.keykey.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"
  # KeyKey ekrandayken başka uygulamaların bindirme pencerelerini gizlemek
  # (dokunma korsanlığı koruması, Android 12+). Normal izin, kullanıcıya
  # sorulmaz.
  "android.permission.HIDE_OVERLAY_WINDOWS"
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

# İçerik denetimleri açılmış APK üzerinde yapılır.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
unzip -q -o "$apk" -d "$work"

# R8: kendi paketimizden adı korunan sınıflar yalnızca manifestteki
# bileşenler olabilir (Android onları adıyla bulur). R8 kapanırsa bütün sınıf
# adları görünür ve bu denetim düşer.
components="$(grep -oE ':name\([^)]*\)="io\.github\.aaudraa\.keykey\.[A-Za-z0-9_.$]+"' <<< "$manifest" \
  | sed -E 's/.*="([^"]+)"/\1/' | sort -u)"
kept="$(cat "$work"/classes*.dex | grep -aoE 'Lio/github/aaudraa/keykey/[A-Za-z0-9_/$]+;' \
  | sed -E 's/^L//; s/;$//; s|/|.|g' | sort -u || true)"
echo "Adı korunan sınıflar:"
while IFS= read -r class; do
  [[ -z "$class" ]] && continue
  echo "  $class"
  grep -qxF "$class" <<< "$components" || fail "R8 bu sınıfın adını korumuş, manifestte değil: $class"
done <<< "$kept"
[[ -n "$kept" ]] || fail "dex'te MainActivity bulunamadı; APK yapısı beklenmedik."

# Yerel kütüphanelerde hata ayıklama bölümü ve tam sembol tablosu olmamalı.
# Kalan dinamik semboller, kütüphanenin Dart'tan çağrılabilmesi için gerekir.
readelf="$(find "$sdk/ndk" -path '*/toolchains/llvm/prebuilt/*/bin/llvm-readelf*' 2>/dev/null | sort -V | tail -n 1 || true)"
if [[ -z "$readelf" ]]; then
  fail "llvm-readelf bulunamadı ($sdk/ndk); yerel kütüphaneler denetlenemedi."
else
  libs=0
  while IFS= read -r so; do
    libs=$((libs + 1))
    if "$readelf" -S -W "$so" | grep -qE '\.(debug_[a-z_]+|symtab)\b'; then
      fail "hata ayıklama bilgisi içeren kütüphane: ${so#"$work"/}"
    fi
  done < <(find "$work/lib" -name '*.so')
  echo "Yerel kütüphaneler: $libs dosya denetlendi."
fi

# Yayına girmemesi gereken dosyalar.
forbidden="$(cd "$work" && find . -type f \( -iname '*.jks' -o -iname '*.keystore' -o -iname '*.p12' \
  -o -iname '*.pem' -o -iname '.env' -o -iname '*.keykey' -o -iname 'DebugProbesKt.bin' \
  -o -path '*fixtures*' \) | sed 's|^\./||')"
[[ -z "$forbidden" ]] || fail "yayına girmemesi gereken dosyalar: $(tr '\n' ' ' <<< "$forbidden")"

# Testlerde ve elle denemelerde kullanılan parolalar, anahtarlar ve kullanıcı
# adları APK'nın hiçbir dosyasında geçmemeli. Değer yazılmaz, yalnızca dosya.
values="$(dirname "$0")/deneme-degerleri.txt"
leaks="$(grep -vE '^\s*(#|$)' "$values" | grep -rlaiF -f - "$work" | sed "s|^$work/||" || true)"
[[ -z "$leaks" ]] || fail "deneme değeri içeren dosyalar: $(tr '\n' ' ' <<< "$leaks")"

if [[ "$failed" != 0 ]]; then
  echo "Sonuç: BAŞARISIZ"
  exit 1
fi
echo "Sonuç: tamam"

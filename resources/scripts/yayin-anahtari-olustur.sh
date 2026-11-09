#!/usr/bin/env bash
# KeyKey'in kalıcı yayın anahtarını oluşturur, şifreli arşive koyar, arşivi
# USB'ye (E:) ve D: diskine kopyalar, anahtarı GitHub'daki "yayin" ortamına
# yükler ve şifresiz dosyaları siler.
#
# Parolalar ekrana yazılmaz ve hiçbir yere kaydedilmez. Senin bilmen gereken
# tek parola, şimdi seçeceğin ARŞİV PAROLASI. Anahtarın kendi parolası rastgele
# üretilir ve arşivin içindeki bilgi dosyasında durur.
set -euo pipefail

KEYTOOL="/c/Program Files/Android/Android Studio/jbr/bin/keytool.exe"
SEVENZIP="/c/Program Files/7-Zip/7z.exe"
REPO="aaudraa/KeyKey"
NAME="keykey-yayin-anahtari"
TARGETS=("/e/KeyKey-yayin-anahtari" "/d/KeyKey-yayin-anahtari")

for tool in "$KEYTOOL" "$SEVENZIP"; do
  [[ -x "$tool" ]] || { echo "HATA: bulunamadı: $tool" >&2; exit 1; }
done
command -v gh >/dev/null || { echo "HATA: gh yok." >&2; exit 1; }
[[ -d /e ]] || { echo "HATA: USB bellek (E:) takılı değil." >&2; exit 1; }
for target in "${TARGETS[@]}"; do
  if [[ -e "$target/$NAME.7z" ]]; then
    echo "HATA: $target/$NAME.7z zaten var. Var olan bir anahtarın üstüne yazılmaz." >&2
    exit 1
  fi
done

echo "Arşiv parolasını seç. En az 16 karakter; bir cümle olabilir."
echo "Bu parolayı KÂĞIDA YAZ. Kaybolursa yedekler açılamaz."
while true; do
  read -r -s -p "Arşiv parolası: " ARCHIVE_PW; echo
  read -r -s -p "Tekrar: " ARCHIVE_PW2; echo
  if [[ "$ARCHIVE_PW" != "$ARCHIVE_PW2" ]]; then
    echo "Parolalar aynı değil, yeniden dene."
  elif (( ${#ARCHIVE_PW} < 16 )); then
    echo "En az 16 karakter olmalı, yeniden dene."
  else
    break
  fi
done
unset ARCHIVE_PW2

work="$(mktemp -d)"
cleanup() { rm -rf "$work"; }
trap cleanup EXIT

# Anahtarın parolası: rastgele, ekrana yazılmaz. PKCS12'de depo ve anahtar
# parolası aynıdır.
KEYKEY_STORE_PW="$(openssl rand -base64 33 | tr -d '\n')"
export KEYKEY_STORE_PW

echo "Anahtar oluşturuluyor (RSA 4096, 30 yıl)..."
"$KEYTOOL" -genkeypair -keystore "$work/$NAME.jks" -storetype PKCS12 \
  -alias keykey -keyalg RSA -keysize 4096 -validity 10950 \
  -dname "CN=KeyKey" \
  -storepass:env KEYKEY_STORE_PW -keypass:env KEYKEY_STORE_PW >/dev/null

cert="$("$KEYTOOL" -list -v -keystore "$work/$NAME.jks" -storepass:env KEYKEY_STORE_PW \
  | sed -n 's/^[[:space:]]*SHA256: //p' | head -n 1 | tr -d ':' | tr 'A-F' 'a-f')"
[[ ${#cert} == 64 ]] || { echo "HATA: sertifika özeti okunamadı." >&2; exit 1; }

cat > "$work/bilgi.txt" <<EOF
KeyKey yayın anahtarı
Oluşturma: $(date -u +%Y-%m-%dT%H:%MZ)
Dosya: $NAME.jks (PKCS12)
Takma ad (alias): keykey
Depo ve anahtar parolası: $KEYKEY_STORE_PW
Sertifika SHA-256: $cert
Geçerlilik: 30 yıl, RSA 4096, CN=KeyKey

GitHub'a geri yüklemek (repo aaudraa/KeyKey, ortam yayin):
  KEYKEY_KEYSTORE_BASE64   = base64 -w0 $NAME.jks
  KEYKEY_KEYSTORE_PASSWORD = yukarıdaki parola
  KEYKEY_KEY_PASSWORD      = yukarıdaki parola
  KEYKEY_KEY_ALIAS         = keykey
Ayrıntılar: resources/docs/yayin.md
EOF

echo "Şifreli arşiv hazırlanıyor (7z, AES-256, dosya adları da gizli)..."
(cd "$work" && "$SEVENZIP" a -t7z -mhe=on -mx=9 -p"$ARCHIVE_PW" "$NAME.7z" "$NAME.jks" bilgi.txt >/dev/null)
"$SEVENZIP" t -p"$ARCHIVE_PW" "$work/$NAME.7z" >/dev/null
echo "Arşiv parolayla açılabiliyor."
archive_sha="$(sha256sum "$work/$NAME.7z" | cut -d' ' -f1)"

for target in "${TARGETS[@]}"; do
  mkdir -p "$target"
  cp "$work/$NAME.7z" "$target/"
  copy_sha="$(sha256sum "$target/$NAME.7z" | cut -d' ' -f1)"
  [[ "$copy_sha" == "$archive_sha" ]] || { echo "HATA: $target kopyası bozuk." >&2; exit 1; }
  echo "Kopyalandı ve doğrulandı: $target/$NAME.7z"
done

echo "GitHub'daki yayin ortamına yükleniyor..."
base64 -w0 "$work/$NAME.jks" | gh secret set KEYKEY_KEYSTORE_BASE64 --env yayin --repo "$REPO"
printf '%s' "$KEYKEY_STORE_PW" | gh secret set KEYKEY_KEYSTORE_PASSWORD --env yayin --repo "$REPO"
printf '%s' "$KEYKEY_STORE_PW" | gh secret set KEYKEY_KEY_PASSWORD --env yayin --repo "$REPO"
printf 'keykey' | gh secret set KEYKEY_KEY_ALIAS --env yayin --repo "$REPO"
unset KEYKEY_STORE_PW ARCHIVE_PW

echo
echo "Bitti. Şifresiz anahtar silindi; yalnızca şifreli arşivler ve GitHub'daki kopya kaldı."
echo "Sertifika SHA-256: $cert"
echo "Arşiv SHA-256:     $archive_sha"
echo "Kalan adımlar: arşivi Google Drive'a yükle, parolayı kâğıda yaz."

#!/usr/bin/env bash
# Yayın anahtarının parolasını denetler ve GitHub'daki "yayin" ortamına
# doğru değerleri yeniden yükler.
#
# Neden: yayin-anahtari-olustur.sh parolayı Git Bash'teki openssl ile üretti.
# O openssl çıktıyı Windows satır sonuyla (CR LF) bitirir; betik yalnızca LF'yi
# sildiği için anahtar deposu sonunda görünmez bir CR olan parolayla kilitlendi.
# gh ise gizli değerin sonundaki satır sonunu kırptı, bu yüzden GitHub'daki
# parola depoyu açmadı. (Parola "/" ile başlasaydı Git Bash onu yol sanıp
# ayrıca çevirirdi; o da denenir.)
#
# Betik arşivi geçici bir klasöre açar, parolanın olası hallerini dener ve açan
# hali bulur. Açan hal temiz parola değilse aynı anahtarı (aynı sertifika)
# temiz parolayla yeniden paketler. Onay verirsen temiz parolayı ve paketi
# GitHub'a yükler. Arşivlere dokunmaz. Parolalar ekrana yazılmaz.
set -euo pipefail

KEYTOOL="/c/Program Files/Android/Android Studio/jbr/bin/keytool.exe"
SEVENZIP="/c/Program Files/7-Zip/7z.exe"
REPO="aaudraa/KeyKey"
NAME="keykey-yayin-anahtari"
EXPECTED_CERT="66ff7b5c0c009a8530d0a55dd1d80a3af35de48bd0667c456a0cf86a6d1129a0"
CR=$'\r'

# Bu betikte Git Bash hiçbir değeri yol diye çevirmesin.
export MSYS2_ENV_CONV_EXCL='*' MSYS2_ARG_CONV_EXCL='*'

for tool in "$KEYTOOL" "$SEVENZIP"; do
  [[ -x "$tool" ]] || { echo "HATA: bulunamadı: $tool" >&2; exit 1; }
done
command -v gh >/dev/null || { echo "HATA: gh yok." >&2; exit 1; }

archive=""
for dir in /e/KeyKey-yayin-anahtari /d/KeyKey-yayin-anahtari; do
  if [[ -f "$dir/$NAME.7z" ]]; then archive="$dir/$NAME.7z"; break; fi
done
[[ -n "$archive" ]] || { echo "HATA: arşiv E: ya da D: diskinde bulunamadı." >&2; exit 1; }
echo "Arşiv: $archive"

work="$(mktemp -d)"
cleanup() { rm -rf "$work"; }
trap cleanup EXIT

read -r -s -p "Arşiv parolası (kâğıttaki): " ARCHIVE_PW; echo
"$SEVENZIP" x -y -p"$ARCHIVE_PW" -o"$(cygpath -w "$work")" "$(cygpath -w "$archive")" >/dev/null \
  || { echo "HATA: arşiv açılamadı (parola yanlış olabilir)." >&2; exit 1; }
unset ARCHIVE_PW

jks="$work/$NAME.jks"
[[ -f "$jks" ]] || { echo "HATA: arşivde $NAME.jks yok." >&2; exit 1; }
# Satırın sonundaki CR kasıtlı olarak silinmez: parolanın parçası olabilir.
line="$(sed -n 's/^Depo ve anahtar parolası: //p' "$work/bilgi.txt")"
[[ -n "$line" ]] || { echo "HATA: bilgi.txt'te parola satırı yok." >&2; exit 1; }
clean="${line%"$CR"}"

opens() {
  KK_PW="$1" "$KEYTOOL" -list -v -keystore "$(cygpath -w "$2")" \
    -storepass:env KK_PW 2>/dev/null
}

candidates=("$clean" "$clean$CR")
labels=("temiz parola" "sonunda CR olan parola")
if [[ "$clean" == /* ]]; then
  converted="$(cygpath -m /)${clean#/}"
  candidates+=("$converted" "$converted$CR")
  labels+=("Git Bash'in çevirdiği parola" "Git Bash'in çevirdiği, sonunda CR olan parola")
  unset converted
fi

found=-1
for i in "${!candidates[@]}"; do
  if opens "${candidates[$i]}" "$jks" >/dev/null; then found=$i; break; fi
done
if (( found < 0 )); then
  echo "HATA: parolanın hiçbir hali anahtar deposunu açmadı. Burada dur ve durumu bildir." >&2
  exit 1
fi
echo "Açan parola: ${labels[$found]}"

upload="$jks"
if (( found != 0 )); then
  echo "Aynı anahtar temiz parolayla yeniden paketleniyor..."
  upload="$work/yeniden.jks"
  KK_SRC="${candidates[$found]}" KK_DST="$clean" "$KEYTOOL" -importkeystore \
    -srckeystore "$(cygpath -w "$jks")" -srcstoretype PKCS12 \
    -srcstorepass:env KK_SRC -srckeypass:env KK_SRC -srcalias keykey \
    -destkeystore "$(cygpath -w "$upload")" -deststoretype PKCS12 \
    -deststorepass:env KK_DST -destkeypass:env KK_DST -destalias keykey \
    -noprompt >/dev/null 2>&1 \
    || { echo "HATA: yeniden paketlenemedi." >&2; exit 1; }
fi
unset candidates line

out="$(opens "$clean" "$upload")" \
  || { echo "HATA: yüklenecek paket temiz parolayla açılmıyor." >&2; exit 1; }
cert="$(printf '%s\n' "$out" | sed -n 's/^[[:space:]]*SHA256: //p' | head -n 1 | tr -d ':' | tr 'A-F' 'a-f')"
alias_ok="$(printf '%s\n' "$out" | grep -c '^Alias name: keykey' || true)"
echo "Sertifika SHA-256: $cert"
[[ "$cert" == "$EXPECTED_CERT" ]] || { echo "HATA: sertifika belgedekiyle aynı değil." >&2; exit 1; }
[[ "$alias_ok" == 1 ]] || { echo "HATA: 'keykey' takma adı bulunamadı." >&2; exit 1; }
# İmza özel anahtarla atılır: deponun yanında anahtarın da açıldığını göster.
KK_PW="$clean" "$KEYTOOL" -certreq -alias keykey -keystore "$(cygpath -w "$upload")" \
  -storepass:env KK_PW -keypass:env KK_PW >/dev/null 2>&1 \
  || { echo "HATA: özel anahtar temiz parolayla açılmıyor." >&2; exit 1; }
echo "Yüklenecek paket temiz parolayla açılıyor; sertifika belgedekiyle aynı, takma ad keykey."

read -r -p "Temiz parolayı ve paketi GitHub'daki yayin ortamına yükleyeyim mi? (e/h): " answer
if [[ "$answer" != "e" ]]; then
  echo "Yüklenmedi."
  exit 0
fi
base64 -w0 "$upload" | gh secret set KEYKEY_KEYSTORE_BASE64 --env yayin --repo "$REPO"
printf '%s' "$clean" | gh secret set KEYKEY_KEYSTORE_PASSWORD --env yayin --repo "$REPO"
printf '%s' "$clean" | gh secret set KEYKEY_KEY_PASSWORD --env yayin --repo "$REPO"
printf 'keykey' | gh secret set KEYKEY_KEY_ALIAS --env yayin --repo "$REPO"
unset clean
echo "Yüklendi. Şifresiz dosyalar silindi."

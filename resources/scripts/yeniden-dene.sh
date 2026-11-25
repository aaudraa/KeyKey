#!/usr/bin/env bash
# Kaynak olarak yüklenir: source resources/scripts/yeniden-dene.sh
#
# yeniden_dene_429 <deneme> <bekleme-saniye> <komut> [argümanlar...]
#   Komutu çalıştırır; düşer ve çıktısında HTTP 429 (Too Many Requests)
#   varsa bekleyip en çok <deneme> kez çalıştırır. Başka bir hatada hemen
#   komutun çıkış koduyla döner. Çıktı gizlenmez.
#
# Neden: Maven Central GitHub'ın makinelerine zaman zaman 429 veriyor ve
# Gradle derlemesi bağımlılık indiremeden düşüyor (#195). Yeniden derleme
# aynı kaynaktan aynı çıktıyı verir; yeniden üretilebilirlik etkilenmez.
# Test: yeniden-dene-test.sh

yeniden_dene_429() {
  local deneme="$1" bekleme="$2" sira=1 kod gunluk
  shift 2
  gunluk="$(mktemp)"
  while true; do
    # Komutun kendi kodu, çağıranın pipefail ve -e ayarından bağımsız okunur.
    kod=0
    { "$@" 2>&1 | tee "$gunluk"; kod=${PIPESTATUS[0]}; } || true
    if (( kod == 0 )); then
      rm -f "$gunluk"
      return 0
    fi
    if (( sira >= deneme )) || ! grep -qE "status code 429|Too Many Requests" "$gunluk"; then
      rm -f "$gunluk"
      return "$kod"
    fi
    echo "UYARI: 429 (Too Many Requests); ${bekleme} saniye sonra yeniden deneniyor ($sira/$deneme)" >&2
    sleep "$bekleme"
    sira=$((sira + 1))
  done
}

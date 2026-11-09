#!/usr/bin/env bash
# SQLite kaynağını (amalgamation) sqlite.org'dan indirir, sitenin yayımladığı
# SHA3-256 özetiyle doğrular ve android/third_party/sqlite/sqlite3.c'yi
# günceller. Sürüm verilmezse sitedeki son sürüm alınır.
#
# Kullanım: bash resources/scripts/sqlite-guncelle.sh [3.54.1]
#           bash resources/scripts/sqlite-guncelle.sh --denetle
#   --denetle: repodaki sqlite3.c'nin README'deki sürümün resmî dosyasıyla
#              bayt bayt aynı olduğunu doğrular, hiçbir şeyi değiştirmez.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
target="$root/android/third_party/sqlite"
readme="$target/README.md"

check_only=0
version="${1:-}"
if [[ "$version" == "--denetle" ]]; then
  check_only=1
  version="$(sed -n 's/^| Sürüm | \([0-9.]*\) |$/\1/p' "$readme")"
fi

page="$(curl -sSfL https://sqlite.org/download.html)"
# Sayfadaki satırlar: PRODUCT,<sürüm>,<yol>,<boyut>,<SHA3-256>
rows="$(grep -o -E 'PRODUCT,[0-9.]+,[0-9]{4}/sqlite-amalgamation-[0-9]+\.zip,[0-9]+,[0-9a-f]{64}' <<<"$page" || true)"
if [[ -n "$version" ]]; then
  row="$(grep "^PRODUCT,${version//./\\.}," <<<"$rows" || true)"
else
  row="$(head -n 1 <<<"$rows")"
fi
if [[ -z "$row" ]]; then
  echo "HATA: sqlite.org'un indirme sayfasında ${version:-son} sürümün kaynağı bulunamadı." >&2
  echo "Eski sürümler sayfadan kalkar; o durumda yeni sürüme geç." >&2
  exit 1
fi
IFS=, read -r _ version path _ expected <<<"$row"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
curl -sSfL -o "$work/sqlite.zip" "https://sqlite.org/$path"
actual="$(openssl dgst -sha3-256 -r "$work/sqlite.zip" | cut -d' ' -f1)"
if [[ "$actual" != "$expected" ]]; then
  echo "HATA: SHA3-256 uyuşmuyor. Beklenen $expected, inen $actual." >&2
  exit 1
fi
unzip -q -j "$work/sqlite.zip" '*/sqlite3.c' -d "$work"
source_sha="$(sha256sum "$work/sqlite3.c" | cut -d' ' -f1)"

if [[ "$check_only" == 1 ]]; then
  current="$(sha256sum "$target/sqlite3.c" | cut -d' ' -f1)"
  if [[ "$current" != "$source_sha" ]]; then
    echo "HATA: repodaki sqlite3.c, SQLite $version'in resmî dosyasıyla aynı değil." >&2
    exit 1
  fi
  echo "Tamam: sqlite3.c, SQLite $version'in resmî dosyasıyla aynı ($source_sha)."
  exit 0
fi

cp "$work/sqlite3.c" "$target/sqlite3.c"
echo "SQLite $version yazıldı."
echo "README'deki tabloyu güncelle:"
echo "  Sürüm: $version"
echo "  Kaynak: https://sqlite.org/$path"
echo "  Arşivin SHA3-256 özeti: $expected"
echo "  sqlite3.c SHA-256: $source_sha"

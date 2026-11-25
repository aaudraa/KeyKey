#!/usr/bin/env bash
# F-Droid'in kendi aracıyla (fdroid build) KeyKey'i derler; fdroiddata'nın
# "fdroid build" CI işinin kopyası. F-Droid'in derleme imajında
# (registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie) root olarak
# çalıştırılır.
#
# Kullanım: f-droid-derle.sh <commit> <çıktı-apk> [lint]
#
# Tarifin son derleme bloğundaki commit, versionName ve versionCode bu
# commit'teki pubspec.yaml'a göre değiştirilir; derlemede Binaries satırı
# çıkarılır (taslak ya da henüz olmayan bir sürümü indirmeye çalışmasın,
# karşılaştırmayı f-droid-karsilastir.sh yapar). "lint" verilirse derlemeden
# sonra tarifin tamamı (Binaries dahil) fdroid lint ve rewritemeta'dan geçer;
# yayın iş akışı vermez, böylece yeni bir lint kuralı yayını durdurmaz.
set -euo pipefail

commit="$1"
lint="${3:-}"
# Betik başka klasörlere geçiyor; çıktı yolu baştan mutlak olmalı.
out="$(realpath -m "$2")"

appid=io.github.aaudraa.keykey
repo="$(git rev-parse --show-toplevel)"
home_vagrant=/home/vagrant

# shellcheck disable=SC1091
source /etc/profile.d/bsenv.sh
: "${fdroidserver:?bsenv.sh fdroidserver yolunu tanımlamadı}"
export ANDROID_HOME=/opt/android-sdk

apt-get update -qq
apt-get install -qy sudo openjdk-21-jdk-headless >/dev/null
update-alternatives --set java /usr/lib/jvm/java-21-openjdk-amd64/bin/java
sdkmanager "platform-tools" "build-tools;31.0.0" >/dev/null

# fdroiddata CI'ındaki gibi fdroidserver'ın güncel ana dalı (fdroiddata
# önce sabit bir commit'i doğrular, sonra ana dala ileri sarar).
# GitLab'dan klonlama zaman zaman yarıda kopuyor; üç kez denenir.
for try in 1 2 3; do
  rm -rf "$fdroidserver"
  if git clone --quiet --depth 1 https://gitlab.com/fdroid/fdroidserver.git "$fdroidserver"; then
    break
  fi
  [[ $try == 3 ]] && exit 1
  echo "fdroidserver klonlanamadı, yeniden deneniyor ($try)" >&2
  sleep 30
done
echo "fdroidserver: $(git -C "$fdroidserver" rev-parse HEAD)"

pubspec="$(git -C "$repo" show "$commit:pubspec.yaml")"
version="$(sed -n 's/^version: *\([^+ ]*\)+\([0-9]*\).*$/\1/p' <<<"$pubspec")"
code="$(sed -n 's/^version: *\([^+ ]*\)+\([0-9]*\).*$/\2/p' <<<"$pubspec")"

mkdir -p "$home_vagrant/config" "$home_vagrant/metadata" "$home_vagrant/srclibs" "$home_vagrant/tmp" \
  "$home_vagrant/unsigned" "$home_vagrant/logs" "$home_vagrant/build"
python3 - "$repo/resources/f-droid/$appid.yml" "$home_vagrant/metadata/$appid.yml" \
  "$home_vagrant/tmp/$appid.yml.tam" "$commit" "$version" "$code" <<'EOF'
import re, sys
src, dst, full, commit, version, code = sys.argv[1:]
text = open(src, encoding="utf-8").read()
# fdroiddata'daki dosyalarda yorum olmaz (basvuru.md); baştaki yorumlar atılır.
text = re.sub(r"\A(#.*\n)+", "", text)
# Son derleme bloğu: "  - versionName:" ile başlayan son bölüm.
head, sep, last = text.rpartition("\n  - versionName:")
last = re.sub(r"^ (.*)$", f" {version}", last, count=1, flags=re.M)
last = re.sub(r"^    versionCode: .*$", f"    versionCode: {code}", last, count=1, flags=re.M)
last = re.sub(r"^    commit: .*$", f"    commit: {commit}", last, count=1, flags=re.M)
text = head + sep + last
text = re.sub(r"^CurrentVersion: .*$", f"CurrentVersion: {version}", text, flags=re.M)
text = re.sub(r"^CurrentVersionCode: .*$", f"CurrentVersionCode: {code}", text, flags=re.M)
open(full, "w", encoding="utf-8").write(text)
open(dst, "w", encoding="utf-8").write(re.sub(r"^Binaries:.*\n", "", text, flags=re.M))
EOF
sed -n '/^Builds:/,/^$/p' "$home_vagrant/metadata/$appid.yml"
# fdroiddata'dan Flutter srclib'i ve config/ (lint kategorileri ve
# simgelerini oradan okur). Seyrek ve sığ klon, üç deneme.
fdroiddata="$(mktemp -d)"
for try in 1 2 3; do
  rm -rf "$fdroiddata"
  if git clone --quiet --depth 1 --filter=blob:none --sparse \
      https://gitlab.com/fdroid/fdroiddata.git "$fdroiddata" &&
    git -C "$fdroiddata" sparse-checkout set --no-cone /config/ /srclibs/flutter.yml; then
    break
  fi
  [[ $try == 3 ]] && exit 1
  echo "fdroiddata klonlanamadı, yeniden deneniyor ($try)" >&2
  sleep 30
done
cp "$fdroiddata/srclibs/flutter.yml" "$home_vagrant/srclibs/flutter.yml"
cp -r "$fdroiddata/config/." "$home_vagrant/config/"

chown -R vagrant "$home_vagrant"
cd "$home_vagrant"
fdroid=(sudo --preserve-env --user vagrant
  env PATH="$fdroidserver:$PATH"
  env PYTHONPATH="$fdroidserver:$fdroidserver/examples"
  env PYTHONUNBUFFERED=true
  env HOME="$home_vagrant"
  fdroid)
"${fdroid[@]}" fetchsrclibs "$appid:$code" --verbose
# fdroid build sudo'yu kaldırıyor; Maven Central 429 verirse (#195) yeniden
# denemeden önce kurulur.
fdroid_derle() {
  command -v sudo >/dev/null || apt-get install -qy sudo >/dev/null
  (unset CI; "${fdroid[@]}" build --verbose --test --refresh-scanner --on-server --no-tarball "$appid:$code")
}
# shellcheck source=resources/scripts/yeniden-dene.sh
source "$repo/resources/scripts/yeniden-dene.sh"
yeniden_dene_429 3 120 fdroid_derle

mkdir -p "$(dirname "$out")"
cp "$home_vagrant/tmp/${appid}_${code}.apk" "$out"
echo "F-Droid derledi: $out ($appid $version, $code)"

if [[ "$lint" == lint ]]; then
  # fdroiddata'nın CI'ı da bunları çalıştırır; rewritemeta yalnızca önerir.
  # Başvurulacak tarif Binaries satırıyla denetlenir.
  # fdroid build sudo'yu kaldırıyor, yeniden kurulur.
  apt-get install -qy sudo >/dev/null
  cp "tmp/$appid.yml.tam" "metadata/$appid.yml"
  "${fdroid[@]}" lint "$appid"
  cp "metadata/$appid.yml" "tmp/$appid.yml.once"
  "${fdroid[@]}" rewritemeta "$appid"
  if ! diff -u "tmp/$appid.yml.once" "metadata/$appid.yml"; then
    echo "UYARI: fdroid rewritemeta tarifin biçiminde değişiklik öneriyor (yukarıda)." >&2
  fi
fi

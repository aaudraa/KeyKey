#!/usr/bin/env bash
# F-Droid'in kendi aracıyla (fdroid build) KeyKey'i derler; fdroiddata'nın
# "fdroid build" CI işinin kopyası. F-Droid'in derleme imajında
# (registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie) root olarak
# çalıştırılır.
#
# Kullanım: f-droid-derle.sh <commit> <çıktı-apk>
#
# Tarifin son derleme bloğundaki commit, versionName ve versionCode bu
# commit'teki pubspec.yaml'a göre değiştirilir; Binaries satırı çıkarılır
# (taslak ya da henüz olmayan bir sürümü indirmeye çalışmasın,
# karşılaştırmayı f-droid-karsilastir.sh yapar).
set -euo pipefail

commit="$1"
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

# fdroiddata CI'ındaki gibi fdroidserver'ın güncel ana dalı.
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

mkdir -p "$home_vagrant/metadata" "$home_vagrant/srclibs" "$home_vagrant/tmp" \
  "$home_vagrant/unsigned" "$home_vagrant/logs" "$home_vagrant/build"
python3 - "$repo/resources/f-droid/$appid.yml" "$home_vagrant/metadata/$appid.yml" \
  "$commit" "$version" "$code" <<'EOF'
import re, sys
src, dst, commit, version, code = sys.argv[1:]
text = open(src, encoding="utf-8").read()
text = re.sub(r"^Binaries:.*\n", "", text, flags=re.M)
# Son derleme bloğu: "  - versionName:" ile başlayan son bölüm.
head, sep, last = text.rpartition("\n  - versionName:")
last = re.sub(r"^ (.*)$", f" {version}", last, count=1, flags=re.M)
last = re.sub(r"^    versionCode: .*$", f"    versionCode: {code}", last, count=1, flags=re.M)
last = re.sub(r"^    commit: .*$", f"    commit: {commit}", last, count=1, flags=re.M)
text = head + sep + last
text = re.sub(r"^CurrentVersion: .*$", f"CurrentVersion: {version}", text, flags=re.M)
text = re.sub(r"^CurrentVersionCode: .*$", f"CurrentVersionCode: {code}", text, flags=re.M)
open(dst, "w", encoding="utf-8").write(text)
EOF
sed -n '/^Builds:/,/^$/p' "$home_vagrant/metadata/$appid.yml"
curl -sSfL https://gitlab.com/fdroid/fdroiddata/-/raw/master/srclibs/flutter.yml \
  -o "$home_vagrant/srclibs/flutter.yml"

chown -R vagrant "$home_vagrant"
cd "$home_vagrant"
fdroid=(sudo --preserve-env --user vagrant
  env PATH="$fdroidserver:$PATH"
  env PYTHONPATH="$fdroidserver:$fdroidserver/examples"
  env PYTHONUNBUFFERED=true
  env HOME="$home_vagrant"
  fdroid)
"${fdroid[@]}" fetchsrclibs "$appid:$code" --verbose
(unset CI; "${fdroid[@]}" build --verbose --test --refresh-scanner --on-server --no-tarball "$appid:$code")

mkdir -p "$(dirname "$out")"
cp "$home_vagrant/tmp/${appid}_${code}.apk" "$out"
echo "F-Droid derledi: $out ($appid $version, $code)"

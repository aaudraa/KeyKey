#!/usr/bin/env bash
# KeyKey'in APK'sını F-Droid'in derleyeceği yerde ve F-Droid tarifindeki
# adımlarla, imzasız derler. F-Droid'in derleme imajında
# (registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie) root olarak
# çalıştırılır; derlemenin kendisi vagrant kullanıcısıyla yapılır.
#
# Kullanım: f-droid-yolunda-derle.sh <commit> <çıktı-apk> [appbundle]
#   appbundle verilirse AAB de derlenir ve <çıktı-apk> yerine .aab ile yazılır.
#
# Yolların neden önemli olduğu: resources/docs/yayin.md#yeniden-üretilebilir-derleme
# Tarif: resources/f-droid/io.github.aaudraa.keykey.yml (adımlar onunla aynı kalmalı)
set -euo pipefail

commit="$1"
# Betik başka klasörlere geçiyor; çıktı yolu baştan mutlak olmalı.
out="$(realpath -m "$2")"
bundle="${3:-}"

appid=io.github.aaudraa.keykey
repo="$(git rev-parse --show-toplevel)"
recipe="$repo/resources/f-droid/$appid.yml"
home_vagrant=/home/vagrant
build="$home_vagrant/build/$appid"
flutter="$home_vagrant/build/srclib/flutter"
flutter_version="$(sed -n 's/^ *- flutter@\(.*\)$/\1/p' "$recipe" | tail -n 1)"
ndk_version=28.2.13676358 # tarifteki ndk: r28c, Flutter'ın ndkVersion'u

# shellcheck disable=SC1091
source /etc/profile.d/bsenv.sh
export ANDROID_HOME=/opt/android-sdk

apt-get update -qq
# make: libsodium'un derlemesi için (tarifteki sudo adımı).
apt-get install -qy sudo openjdk-21-jdk-headless make >/dev/null
update-alternatives --set java /usr/lib/jvm/java-21-openjdk-amd64/bin/java
sdkmanager --install "ndk;$ndk_version" >/dev/null

rm -rf "$build" "$flutter"
mkdir -p "$home_vagrant/build/srclib"
git clone --quiet --no-checkout "$repo" "$build"
git -C "$build" checkout --quiet "$commit"
git clone --quiet --filter=blob:none https://github.com/flutter/flutter.git "$flutter"
git -C "$flutter" checkout --quiet "$flutter_version"
chown -R vagrant "$home_vagrant"

# Tarifteki prebuild ve build adımları; F-Droid, prebuild ile build arasında
# scandelete'teki .pub-cache'i siler, build paketleri yeniden indirir.
sudo --preserve-env=ANDROID_HOME,PATH --user vagrant env HOME="$home_vagrant" \
  bash -euo pipefail -c "
    cd '$build'
    export PUB_CACHE=\$(pwd)/.pub-cache
    '$flutter/bin/flutter' config --no-analytics
    '$flutter/bin/flutter' pub get --enforce-lockfile
    sed -i -e '/signingConfig = /d' android/app/build.gradle.kts
    rm -rf .pub-cache
    export PUB_CACHE=\$(pwd)/.pub-cache
    '$flutter/bin/flutter' build apk --release
    if [[ -n '$bundle' ]]; then '$flutter/bin/flutter' build appbundle --release; fi
  "

mkdir -p "$(dirname "$out")"
cp "$build/build/app/outputs/flutter-apk/app-release.apk" "$out"
if [[ -n "$bundle" ]]; then
  cp "$build/build/app/outputs/bundle/release/app-release.aab" "${out%.apk}.aab"
  cp "$build/build/app/outputs/mapping/release/mapping.txt" "${out%.apk}-mapping.txt"
fi
echo "Derlendi: $out ($build, Flutter $flutter_version, NDK $ndk_version)"

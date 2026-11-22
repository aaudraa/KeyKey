# KeePass dosyalarının Argon2'si: başvuru uygulaması (android/third_party/argon2)
# ve Kotlin'e köprüsü. Tasarım: resources/docs/keepass-ice-aktarma.md
cmake_minimum_required(VERSION 3.18)
project(keykey_argon2 C)

set(ARGON2 ${CMAKE_CURRENT_SOURCE_DIR}/../../../../third_party/argon2)

add_library(keykey_argon2 SHARED
  argon2_jni.c
  ${ARGON2}/src/argon2.c
  ${ARGON2}/src/core.c
  ${ARGON2}/src/ref.c
  ${ARGON2}/src/thread.c
  ${ARGON2}/src/encoding.c
  ${ARGON2}/src/blake2/blake2b.c
)
target_include_directories(keykey_argon2 PRIVATE ${ARGON2}/include ${ARGON2}/src)
# Derleme klasörünün yolu kütüphaneye girmesin: aynı koddan aynı APK
# (yeniden üretilebilir derleme, resources/docs/yayin.md).
target_compile_options(keykey_argon2 PRIVATE
  -O3
  -ffile-prefix-map=${ARGON2}=argon2
  -ffile-prefix-map=${CMAKE_CURRENT_SOURCE_DIR}=cpp
)
# Android 15'in 16 KB sayfalı cihazları.
target_link_options(keykey_argon2 PRIVATE -Wl,-z,max-page-size=16384)

// Argon2 başvuru uygulamasının Kotlin köprüsü (Argon2Native.kt).
//
// Girdiler Java dizilerinden kendi belleğimize kopyalanır, iş bitince
// sıfırlanır. Argon2 bellek bloğunu kendisi siler; parola ve gizli anahtar
// için ARGON2_FLAG_CLEAR_* bayrakları açık.
#include <jni.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "argon2.h"

static void wipe_free(uint8_t *buffer, size_t length) {
    if (buffer == NULL) return;
    volatile uint8_t *p = buffer;
    while (length--) *p++ = 0;
    free(buffer);
}

// Java dizisinin kopyası; dizi null ise NULL ve uzunluk 0.
static uint8_t *copy_array(JNIEnv *env, jbyteArray array, size_t *length) {
    *length = 0;
    if (array == NULL) return NULL;
    jsize size = (*env)->GetArrayLength(env, array);
    uint8_t *buffer = malloc(size > 0 ? (size_t) size : 1);
    if (buffer == NULL) return NULL;
    (*env)->GetByteArrayRegion(env, array, 0, size, (jbyte *) buffer);
    *length = (size_t) size;
    return buffer;
}

// Argon2'nin hata kodunu döndürür (ARGON2_OK = 0); sonuç [out]'a yazılır.
JNIEXPORT jint JNICALL
Java_io_github_aaudraa_keykey_Argon2Native_hash(
    JNIEnv *env, jclass clazz, jint type, jbyteArray password, jbyteArray salt,
    jint iterations, jint memory_kib, jint parallelism, jint version,
    jbyteArray secret, jbyteArray associated_data, jbyteArray out) {
    (void) clazz;
    size_t password_length, salt_length, secret_length, ad_length;
    uint8_t *password_copy = copy_array(env, password, &password_length);
    uint8_t *salt_copy = copy_array(env, salt, &salt_length);
    uint8_t *secret_copy = copy_array(env, secret, &secret_length);
    uint8_t *ad_copy = copy_array(env, associated_data, &ad_length);
    jsize out_length = (*env)->GetArrayLength(env, out);
    uint8_t *out_copy = calloc(out_length > 0 ? (size_t) out_length : 1, 1);

    int result;
    if (password_copy == NULL || salt_copy == NULL || out_copy == NULL ||
        (secret != NULL && secret_copy == NULL) ||
        (associated_data != NULL && ad_copy == NULL)) {
        result = ARGON2_MEMORY_ALLOCATION_ERROR;
    } else {
        long cpus = sysconf(_SC_NPROCESSORS_ONLN);
        uint32_t threads = (uint32_t) parallelism;
        if (cpus > 0 && (uint32_t) cpus < threads) threads = (uint32_t) cpus;
        argon2_context context = {
            .out = out_copy,
            .outlen = (uint32_t) out_length,
            .pwd = password_copy,
            .pwdlen = (uint32_t) password_length,
            .salt = salt_copy,
            .saltlen = (uint32_t) salt_length,
            .secret = secret_copy,
            .secretlen = (uint32_t) secret_length,
            .ad = ad_copy,
            .adlen = (uint32_t) ad_length,
            .t_cost = (uint32_t) iterations,
            .m_cost = (uint32_t) memory_kib,
            .lanes = (uint32_t) parallelism,
            .threads = threads,
            .version = (uint32_t) version,
            .allocate_cbk = NULL,
            .free_cbk = NULL,
            .flags = ARGON2_FLAG_CLEAR_PASSWORD | ARGON2_FLAG_CLEAR_SECRET,
        };
        result = argon2_ctx(&context, type == 0 ? Argon2_d : Argon2_id);
        if (result == ARGON2_OK) {
            (*env)->SetByteArrayRegion(env, out, 0, out_length, (jbyte *) out_copy);
        }
    }

    wipe_free(password_copy, password_length);
    wipe_free(salt_copy, salt_length);
    wipe_free(secret_copy, secret_length);
    wipe_free(ad_copy, ad_length);
    wipe_free(out_copy, (size_t) out_length);
    return result;
}

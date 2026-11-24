package io.github.aaudraa.keykey

/**
 * Argon2 başvuru uygulamasının (android/third_party/argon2) JNI köprüsü.
 * KeePass dosyalarını açmak için; kasanın şifrelemesinde kullanılmaz.
 */
internal object Argon2Native {
    init {
        System.loadLibrary("keykey_argon2")
    }

    /** Argon2'nin hata kodları (argon2.h). */
    const val OK = 0
    const val MEMORY_ALLOCATION_ERROR = -22
    const val THREAD_FAIL = -33

    /** [type] 0 Argon2d, 2 Argon2id. Sonuç [out]'a yazılır; dönen değer hata kodu. */
    @JvmStatic
    external fun hash(
        type: Int,
        password: ByteArray,
        salt: ByteArray,
        iterations: Int,
        memoryKiB: Int,
        parallelism: Int,
        version: Int,
        secret: ByteArray?,
        associatedData: ByteArray?,
        out: ByteArray,
    ): Int
}

package io.github.aaudraa.keykey

import java.security.MessageDigest
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Başka uygulamaların şifreli dışa aktarma dosyalarını açmak için AES-256-GCM.
 *
 * Android'in kendi kitaplığı kullanılır; libsodium'un AES-GCM'i işlemcinin AES
 * desteğine bağlı ve `sodium` paketinde yok. Kasanın şifrelemesinde
 * kullanılmaz.
 */
class ImportCrypto : ImportCryptoApi {
    override fun aesGcmDecrypt(
        key: ByteArray,
        nonce: ByteArray,
        cipherTextWithTag: ByteArray,
    ): ByteArray? {
        require(key.size == KEY_BYTES) { "Anahtar 32 bayt olmalı." }
        require(nonce.isNotEmpty()) { "Nonce boş olamaz." }
        if (cipherTextWithTag.size < TAG_BYTES) return null
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val secretKey = SecretKeySpec(key, "AES")
        return try {
            cipher.init(Cipher.DECRYPT_MODE, secretKey, GCMParameterSpec(TAG_BYTES * 8, nonce))
            cipher.doFinal(cipherTextWithTag)
        } catch (_: AEADBadTagException) {
            // Yanlış anahtar, yani yanlış parola, veya değiştirilmiş dosya.
            null
        }
    }

    override fun kdbxAesKdf(key: ByteArray, seed: ByteArray, rounds: Long): ByteArray {
        if (key.size != KDBX_KEY_BYTES || seed.size != KDBX_KEY_BYTES || rounds < 0) {
            throw FlutterError("failed", "Geçersiz AES-KDF parametresi.")
        }
        val block = key.copyOf()
        try {
            transformHalf(seed, block, 0, rounds)
            transformHalf(seed, block, AES_BLOCK, rounds)
            return MessageDigest.getInstance("SHA-256").digest(block)
        } finally {
            // Pigeon'un verdiği kopya da bizim; anahtar bellekte kalmasın.
            block.fill(0)
            key.fill(0)
        }
    }

    /**
     * [block]'un [offset]'teki 16 baytını AES-256-ECB'den [rounds] kez geçirir.
     *
     * Sıfırlardan oluşan veriyi AES-CBC ile şifrelemek AES'i art arda
     * uygulamakla aynıdır: `C_i = E(C_{i-1} xor 0)`, `C_0 = IV`. Böylece
     * binlerce tur tek çağrıda, işlemcinin AES komutlarıyla yapılır; her tur
     * için ayrı `Cipher.update` çağrısı milyon turda bir saniyeden uzun
     * sürüyordu. Son şifreli blok sonuçtur.
     */
    private fun transformHalf(seed: ByteArray, block: ByteArray, offset: Int, rounds: Long) {
        if (rounds == 0L) return
        val cipher = Cipher.getInstance("AES/CBC/NoPadding")
        cipher.init(
            Cipher.ENCRYPT_MODE,
            SecretKeySpec(seed, "AES"),
            IvParameterSpec(block, offset, AES_BLOCK),
        )
        val zeros = ByteArray(CHUNK_BYTES)
        val out = ByteArray(CHUNK_BYTES)
        try {
            var remaining = rounds
            while (remaining > 0) {
                val blocks = minOf(remaining, (CHUNK_BYTES / AES_BLOCK).toLong()).toInt()
                val length = blocks * AES_BLOCK
                cipher.update(zeros, 0, length, out, 0)
                System.arraycopy(out, length - AES_BLOCK, block, offset, AES_BLOCK)
                remaining -= blocks
            }
        } finally {
            out.fill(0)
        }
    }

    override fun kdbxArgon2(
        type: Long,
        password: ByteArray,
        salt: ByteArray,
        iterations: Long,
        memoryKiB: Long,
        parallelism: Long,
        version: Long,
        secret: ByteArray?,
        associatedData: ByteArray?,
    ): ByteArray {
        // Sınırlar Dart'ta da denetleniyor (KdbxHeader); burada da Int'e
        // sığmayan değer geçmesin.
        if ((type != 0L && type != 2L) || iterations !in 1..1000 ||
            memoryKiB !in 8..1_048_576 || parallelism !in 1..64
        ) {
            throw FlutterError("failed", "Geçersiz Argon2 parametresi.")
        }
        val out = ByteArray(KDBX_KEY_BYTES)
        val result =
            try {
                Argon2Native.hash(
                    type.toInt(), password, salt, iterations.toInt(), memoryKiB.toInt(),
                    parallelism.toInt(), version.toInt(), secret, associatedData, out,
                )
            } finally {
                // Pigeon'un verdiği kopya; bileşik anahtar bellekte kalmasın.
                password.fill(0)
            }
        when (result) {
            Argon2Native.OK -> return out
            Argon2Native.MEMORY_ALLOCATION_ERROR ->
                throw FlutterError("out-of-memory", "Argon2 için bellek ayrılamadı.")
            else -> throw FlutterError("failed", "Argon2 hatası $result.")
        }
    }

    private companion object {
        const val KDBX_KEY_BYTES = 32
        const val AES_BLOCK = 16
        const val CHUNK_BYTES = 64 * 1024
        const val KEY_BYTES = 32
        const val TAG_BYTES = 16
    }
}

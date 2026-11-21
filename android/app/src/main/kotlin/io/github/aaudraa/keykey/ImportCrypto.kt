package io.github.aaudraa.keykey

import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
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

    private companion object {
        const val KEY_BYTES = 32
        const val TAG_BYTES = 16
    }
}

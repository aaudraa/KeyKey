package io.github.aaudraa.keykey.passkey

import io.github.aaudraa.keykey.FlutterError
import io.github.aaudraa.keykey.PasskeyCryptoApi
import io.github.aaudraa.keykey.PasskeyKeyPair
import java.math.BigInteger
import java.security.GeneralSecurityException
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.Signature
import java.security.interfaces.ECPrivateKey
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import java.security.spec.PKCS8EncodedKeySpec

/**
 * Passkey'lerin P-256 anahtarları, Android'in kendi sağlayıcısıyla
 * (Conscrypt/BoringSSL). Android Keystore kullanılmaz: anahtar kasaya yazılır
 * ve senkronla taşınır, dışa alınabilir olmalı. Gelen özel anahtar baytları
 * kullanıldıktan sonra sıfırlanır.
 */
class PasskeyCrypto : PasskeyCryptoApi {
    override fun generate(): PasskeyKeyPair {
        val generator = KeyPairGenerator.getInstance("EC")
        generator.initialize(ECGenParameterSpec("secp256r1"))
        val pair = generator.generateKeyPair()
        val point = (pair.public as ECPublicKey).w
        return PasskeyKeyPair(
            privateKey = pair.private.encoded,
            x = fixed32(point.affineX),
            y = fixed32(point.affineY),
        )
    }

    override fun sign(privateKey: ByteArray, data: ByteArray): ByteArray {
        try {
            val key = KeyFactory.getInstance("EC").generatePrivate(PKCS8EncodedKeySpec(privateKey))
            if (key !is ECPrivateKey || key.params.curve.field.fieldSize != P256_BITS) {
                throw FlutterError("invalid-key", "P-256 anahtarı değil.")
            }
            return Signature.getInstance("SHA256withECDSA").run {
                initSign(key)
                update(data)
                sign()
            }
        } catch (error: GeneralSecurityException) {
            throw FlutterError("invalid-key", "Anahtar okunamadı: ${error.javaClass.simpleName}")
        } finally {
            privateKey.fill(0)
        }
    }

    internal companion object {
        const val P256_BITS = 256
        private const val COORDINATE_BYTES = 32

        /** İşaretsiz, 32 bayta tamamlanmış büyük-sonlu koordinat. */
        fun fixed32(value: BigInteger): ByteArray {
            val raw = value.toByteArray()
            val out = ByteArray(COORDINATE_BYTES)
            val length = minOf(raw.size, COORDINATE_BYTES)
            System.arraycopy(raw, raw.size - length, out, COORDINATE_BYTES - length, length)
            return out
        }
    }
}

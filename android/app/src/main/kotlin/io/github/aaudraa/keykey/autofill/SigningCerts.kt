package io.github.aaudraa.keykey.autofill

import android.content.pm.PackageManager
import java.security.MessageDigest

/** Uygulamaların imza sertifikalarını okur ve karşılaştırır. */
object SigningCerts {
    /**
     * [packageName]'in şu anki imza sertifikalarının SHA-256 özetleri, küçük
     * harf onaltılık. Paket bulunamazsa veya okunamazsa boş liste.
     */
    fun digestsOf(pm: PackageManager, packageName: String): List<String> = try {
        val info = pm.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
        val signing = info.signingInfo ?: return emptyList()
        val certs = if (signing.hasMultipleSigners()) {
            signing.apkContentsSigners
        } else {
            // Tek imzacıda geçmişin son öğesi şu anki sertifikadır.
            signing.signingCertificateHistory?.takeLast(1)?.toTypedArray()
        }
        certs.orEmpty().map { toHex(sha256(it.toByteArray())) }.distinct()
    } catch (error: PackageManager.NameNotFoundException) {
        emptyList()
    }

    /**
     * [packageName] verilen özetlerin her biriyle imzalanmış mı. Android,
     * imza anahtarını döndürmüş uygulamalarda eski sertifikaları da kabul eder.
     */
    fun hasAll(pm: PackageManager, packageName: String, digests: List<String>): Boolean {
        if (digests.isEmpty()) return false
        return digests.all { digest ->
            val bytes = fromHex(digest) ?: return false
            try {
                pm.hasSigningCertificate(packageName, bytes, PackageManager.CERT_INPUT_SHA256)
            } catch (error: IllegalArgumentException) {
                false
            }
        }
    }

    internal fun sha256(bytes: ByteArray): ByteArray =
        MessageDigest.getInstance("SHA-256").digest(bytes)

    internal fun toHex(bytes: ByteArray): String =
        bytes.joinToString("") { "%02x".format(it.toInt() and 0xff) }

    internal fun fromHex(text: String): ByteArray? {
        if (text.length != 64 || text.any { it !in "0123456789abcdef" }) return null
        return ByteArray(32) { i -> text.substring(i * 2, i * 2 + 2).toInt(16).toByte() }
    }
}

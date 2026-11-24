package io.github.aaudraa.keykey.passkey

import io.github.aaudraa.keykey.FlutterError
import io.github.aaudraa.keykey.autofill.TRUSTED_BROWSERS
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigInteger
import java.security.AlgorithmParameters
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.security.spec.ECParameterSpec
import java.security.spec.ECPoint
import java.security.spec.ECPublicKeySpec

class PasskeyCryptoTest {
    private val crypto = PasskeyCrypto()

    @Test
    fun `üretilen anahtarın imzası açık noktayla doğrulanıyor`() {
        val pair = crypto.generate()
        assertEquals(32, pair.x.size)
        assertEquals(32, pair.y.size)
        val data = "keykey".toByteArray()
        val key = pair.privateKey.copyOf()
        val signature = crypto.sign(key, data)
        // Kullanılan özel anahtar baytları sıfırlanır.
        assertTrue(key.all { it == 0.toByte() })

        val params = AlgorithmParameters.getInstance("EC").apply {
            init(ECGenParameterSpec("secp256r1"))
        }.getParameterSpec(ECParameterSpec::class.java)
        val public = KeyFactory.getInstance("EC").generatePublic(
            ECPublicKeySpec(ECPoint(BigInteger(1, pair.x), BigInteger(1, pair.y)), params),
        )
        val verifier = Signature.getInstance("SHA256withECDSA").apply {
            initVerify(public)
            update(data)
        }
        assertTrue(verifier.verify(signature))
    }

    @Test
    fun `bozuk anahtar ayrı hata`() {
        val error = assertThrows(FlutterError::class.java) {
            crypto.sign(byteArrayOf(1, 2, 3), byteArrayOf(4))
        }
        assertEquals("invalid-key", error.code)
    }

    @Test
    fun `koordinat 32 bayta tamamlanıyor`() {
        assertArrayEquals(ByteArray(31) + byteArrayOf(5), PasskeyCrypto.fixed32(BigInteger.valueOf(5)))
        val big = BigInteger(1, ByteArray(32) { 0xff.toByte() })
        assertArrayEquals(ByteArray(32) { 0xff.toByte() }, PasskeyCrypto.fixed32(big))
    }
}

class PrivilegedBrowsersTest {
    @Test
    fun `liste Credential Manager biçiminde ve Chrome'u içeriyor`() {
        val json = JSONObject(PrivilegedBrowsers.allowlistJson)
        val apps = json.getJSONArray("apps")
        assertEquals(TRUSTED_BROWSERS.size, apps.length())
        var chrome: JSONObject? = null
        for (i in 0 until apps.length()) {
            val app = apps.getJSONObject(i)
            assertEquals("android", app.getString("type"))
            val info = app.getJSONObject("info")
            if (info.getString("package_name") == "com.android.chrome") chrome = info
        }
        val signature = chrome!!.getJSONArray("signatures").getJSONObject(0)
        assertEquals("release", signature.getString("build"))
        assertEquals(
            "F0:FD:6C:5B:41:0F:25:CB:25:C3:B5:33:46:C8:97:2F:AE:30:F8:EE:74:11:DF:91:04:80:AD:6B:2D:60:DB:83",
            signature.getString("cert_fingerprint_sha256"),
        )
    }
}

class PendingAssertionsTest {
    private var now = 1_000L

    @After
    fun reset() {
        PendingAssertions.clear()
        PendingAssertions.clock = { System.currentTimeMillis() }
    }

    @Test
    fun `yanıt bir kez verilir, sonra hepsi silinir`() {
        PendingAssertions.clock = { now }
        val token = PendingAssertions.put(mapOf("a" to "{1}", "b" to "{2}"))
        assertEquals("{2}", PendingAssertions.take(token, "b"))
        assertNull(PendingAssertions.take(token, "a"))
    }

    @Test
    fun `süre dolunca silinir`() {
        PendingAssertions.clock = { now }
        val token = PendingAssertions.put(mapOf("a" to "{1}"))
        now += PendingAssertions.TTL_MILLIS + 1
        assertNull(PendingAssertions.take(token, "a"))
    }

    @Test
    fun `bilinmeyen anahtar null`() {
        assertNull(PendingAssertions.take("yok", "a"))
    }
}

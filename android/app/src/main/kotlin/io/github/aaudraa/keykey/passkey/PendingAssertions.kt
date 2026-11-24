package io.github.aaudraa.keykey.passkey

import java.security.SecureRandom
import java.util.Timer
import kotlin.concurrent.schedule

/**
 * Kasa açılınca hesaplanan giriş yanıtları; kullanıcı sistem penceresinde bir
 * hesap seçene kadar süreç belleğinde bekler. Özel anahtar burada yoktur,
 * yalnızca imzalı yanıtlar. Bir yanıt alınınca o isteğin bütün yanıtları
 * silinir; [TTL_MILLIS] sonra da silinir. Süreç kapanırsa hepsi gider.
 */
object PendingAssertions {
    const val TTL_MILLIS = 2 * 60 * 1000L

    private class Batch(val responses: Map<String, String>, val createdAt: Long)

    private val batches = mutableMapOf<String, Batch>()
    private val random = SecureRandom()
    private val timer by lazy { Timer("keykey-passkey", true) }

    /** Saat; testler değiştirir. */
    internal var clock: () -> Long = { System.currentTimeMillis() }

    /** [responses]: kimlik (base64url) → yanıt JSON'u. Dönen anahtar niyete konur. */
    @Synchronized
    fun put(responses: Map<String, String>): String {
        prune()
        val bytes = ByteArray(16).also(random::nextBytes)
        val token = bytes.joinToString("") { "%02x".format(it) }
        batches[token] = Batch(responses.toMap(), clock())
        timer.schedule(TTL_MILLIS + 1000) { synchronized(this@PendingAssertions) { prune() } }
        return token
    }

    /** Seçilen kimliğin yanıtı; bir kez verilir, sonra hepsi silinir. */
    @Synchronized
    fun take(token: String, credentialId: String): String? {
        prune()
        return batches.remove(token)?.responses?.get(credentialId)
    }

    @Synchronized
    internal fun clear() = batches.clear()

    private fun prune() {
        val now = clock()
        batches.entries.removeAll { now - it.value.createdAt > TTL_MILLIS }
    }
}

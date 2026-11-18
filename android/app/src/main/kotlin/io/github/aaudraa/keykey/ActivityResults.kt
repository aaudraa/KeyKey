package io.github.aaudraa.keykey

import android.content.ActivityNotFoundException
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContract
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.util.concurrent.atomic.AtomicInteger
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

private val requests = AtomicInteger()

private const val BUFFER_SIZE = 64 * 1024

/**
 * Bir sistem ekranını (belge ya da klasör seçici) açar ve sonucunu bekler. Kayıt her
 * çağrıda ayrı anahtarla yapılır ve sonuç gelince kaldırılır. Ekran açılamazsa `null`.
 */
internal suspend fun <I, O> ComponentActivity.awaitActivityResult(
    contract: ActivityResultContract<I, O>,
    input: I,
): O? = suspendCancellableCoroutine { continuation ->
    lateinit var launcher: ActivityResultLauncher<I>
    launcher =
        activityResultRegistry.register(
            "keykey-result-${requests.incrementAndGet()}",
            contract,
        ) { result ->
            launcher.unregister()
            if (continuation.isActive) continuation.resume(result)
        }
    continuation.invokeOnCancellation { launcher.unregister() }
    try {
        launcher.launch(input)
    } catch (_: ActivityNotFoundException) {
        launcher.unregister()
        continuation.resume(null)
    }
}

/** En fazla [limit] bayt okur; akış daha uzunsa [limit] bayt döner. Ara bellek sıfırlanır. */
internal fun readAtMost(stream: InputStream, limit: Long): ByteArray {
    val out = ByteArrayOutputStream()
    val buffer = ByteArray(BUFFER_SIZE)
    var total = 0L
    try {
        while (total < limit) {
            val wanted = minOf(buffer.size.toLong(), limit - total).toInt()
            val count = stream.read(buffer, 0, wanted)
            if (count < 0) break
            out.write(buffer, 0, count)
            total += count
        }
        return out.toByteArray()
    } finally {
        buffer.fill(0)
    }
}

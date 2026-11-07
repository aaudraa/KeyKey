package io.github.aaudraa.keykey

import android.content.ActivityNotFoundException
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContract
import androidx.activity.result.contract.ActivityResultContracts
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.util.concurrent.atomic.AtomicInteger
import kotlin.coroutines.resume
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext

/**
 * Android'in belge oluşturma ve açma ekranlarıyla dosya yazar ve okur.
 *
 * Storage Access Framework kullanıldığı için depolama izni gerekmez ve uygulamanın
 * klasörüne hiçbir şey yazılmaz. Drive gibi konumlar kendi uygulamaları üzerinden
 * çalışır, KeyKey'in internet izni gerekmez. Yazılan baytlar işi bitince sıfırlanır,
 * çünkü düz metin dışa aktarma da buradan geçer.
 */
class DocumentFiles(private val activity: ComponentActivity) : DocumentApi {
    override suspend fun save(
        suggestedName: String,
        mimeType: String,
        bytes: ByteArray,
    ): DocumentResult {
        try {
            val uri =
                pick(ActivityResultContracts.CreateDocument(mimeType), suggestedName)
                    ?: return DocumentResult(DocumentStatus.CANCELLED)
            return withContext(Dispatchers.IO) {
                if (write(uri, bytes) && matches(uri, bytes)) {
                    DocumentResult(DocumentStatus.DONE)
                } else {
                    delete(uri)
                    DocumentResult(DocumentStatus.FAILED)
                }
            }
        } finally {
            bytes.fill(0)
        }
    }

    override suspend fun open(mimeTypes: List<String>, maxBytes: Long): DocumentResult {
        val uri =
            pick(ActivityResultContracts.OpenDocument(), mimeTypes.toTypedArray())
                ?: return DocumentResult(DocumentStatus.CANCELLED)
        return withContext(Dispatchers.IO) { read(uri, maxBytes) }
    }

    /**
     * Seçiciyi açar ve sonucunu bekler. Kayıt her çağrıda ayrı anahtarla yapılır ve
     * sonuç gelince kaldırılır.
     */
    private suspend fun <I, O> pick(contract: ActivityResultContract<I, O>, input: I): O? =
        suspendCancellableCoroutine { continuation ->
            lateinit var launcher: ActivityResultLauncher<I>
            launcher =
                activity.activityResultRegistry.register(
                    "keykey-document-${requests.incrementAndGet()}",
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

    private fun write(uri: Uri, bytes: ByteArray): Boolean =
        try {
            val stream = activity.contentResolver.openOutputStream(uri, "w")
            stream?.use { it.write(bytes) } != null
        } catch (_: IOException) {
            false
        } catch (_: SecurityException) {
            false
        } catch (_: IllegalArgumentException) {
            false
        }

    /** Yazılanı geri okuyup karşılaştırır. Fazlası da eksiği de tutmaz sayılır. */
    private fun matches(uri: Uri, expected: ByteArray): Boolean {
        val actual =
            try {
                activity.contentResolver.openInputStream(uri)?.use {
                    readAtMost(it, expected.size.toLong() + 1)
                }
            } catch (_: IOException) {
                null
            } catch (_: SecurityException) {
                null
            } ?: return false
        try {
            return actual.contentEquals(expected)
        } finally {
            actual.fill(0)
        }
    }

    private fun read(uri: Uri, maxBytes: Long): DocumentResult {
        val declared = size(uri)
        if (declared != null && declared > maxBytes) {
            return DocumentResult(DocumentStatus.TOO_LARGE)
        }
        val bytes =
            try {
                activity.contentResolver.openInputStream(uri)?.use {
                    readAtMost(it, maxBytes + 1)
                }
            } catch (_: IOException) {
                null
            } catch (_: SecurityException) {
                null
            } ?: return DocumentResult(DocumentStatus.FAILED)
        if (bytes.size > maxBytes) {
            bytes.fill(0)
            return DocumentResult(DocumentStatus.TOO_LARGE)
        }
        return DocumentResult(DocumentStatus.DONE, bytes)
    }

    /** Sağlayıcının bildirdiği boyut; bilinmiyorsa `null`. */
    private fun size(uri: Uri): Long? =
        try {
            activity.contentResolver
                .query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)
                ?.use { cursor ->
                    val column = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (cursor.moveToFirst() && column >= 0 && !cursor.isNull(column)) {
                        cursor.getLong(column)
                    } else {
                        null
                    }
                }
        } catch (_: SecurityException) {
            null
        } catch (_: IllegalArgumentException) {
            null
        }

    /** En fazla [limit] bayt okur; dosya daha uzunsa [limit] bayt döner. */
    private fun readAtMost(stream: InputStream, limit: Long): ByteArray {
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

    private fun delete(uri: Uri) {
        try {
            DocumentsContract.deleteDocument(activity.contentResolver, uri)
        } catch (_: Exception) {
            // Silinemezse kullanıcıya hata zaten gösteriliyor; yarım dosya kalabilir.
        }
    }

    private companion object {
        const val BUFFER_SIZE = 64 * 1024
        val requests = AtomicInteger()
    }
}

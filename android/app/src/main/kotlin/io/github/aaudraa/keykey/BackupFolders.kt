package io.github.aaudraa.keykey

import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import java.io.FileNotFoundException
import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Otomatik yedeğin klasörü: Android'in klasör seçicisi (`ACTION_OPEN_DOCUMENT_TREE`) ve
 * seçilen klasöre yazma, listeleme, silme.
 *
 * Depolama izni gerekmez. KeyKey yalnızca kullanıcının seçtiği klasör için kalıcı okuma
 * ve yazma izni alır; otomatik yedek kapatılınca izin bırakılır. Yazılan baytlar işi
 * bitince sıfırlanır. Klasör silinmiş ya da izin kalkmışsa işlemler hata atmaz, başarısız
 * döner.
 */
class BackupFolders(private val activity: ComponentActivity) : BackupFolderApi {
    private val resolver
        get() = activity.contentResolver

    override suspend fun pick(): FolderPickResult {
        val tree =
            activity.awaitActivityResult(ActivityResultContracts.OpenDocumentTree(), null)
                ?: return FolderPickResult(FolderPickStatus.CANCELLED)
        return withContext(Dispatchers.IO) {
            try {
                resolver.takePersistableUriPermission(tree, ACCESS)
                FolderPickResult(FolderPickStatus.DONE, tree.toString(), displayName(tree))
            } catch (_: SecurityException) {
                FolderPickResult(FolderPickStatus.FAILED)
            }
        }
    }

    override fun hasAccess(folderUri: String): Boolean {
        val uri = Uri.parse(folderUri)
        return resolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission && it.isWritePermission
        }
    }

    override suspend fun list(folderUri: String): List<String>? =
        withContext(Dispatchers.IO) { children(Uri.parse(folderUri))?.map { it.name } }

    override suspend fun write(
        folderUri: String,
        name: String,
        mimeType: String,
        bytes: ByteArray,
    ): Boolean {
        try {
            return withContext(Dispatchers.IO) {
                val document = create(Uri.parse(folderUri), mimeType, name)
                when {
                    document == null -> false
                    writeAll(document, bytes) && matches(document, bytes) -> true
                    else -> {
                        deleteDocument(document)
                        false
                    }
                }
            }
        } finally {
            bytes.fill(0)
        }
    }

    override suspend fun delete(folderUri: String, names: List<String>): Long =
        withContext(Dispatchers.IO) {
            val tree = Uri.parse(folderUri)
            val wanted = names.toSet()
            val matching = children(tree)?.filter { it.name in wanted } ?: emptyList()
            matching
                .count { deleteDocument(DocumentsContract.buildDocumentUriUsingTree(tree, it.id)) }
                .toLong()
        }

    override fun release(folderUri: String) {
        try {
            resolver.releasePersistableUriPermission(Uri.parse(folderUri), ACCESS)
        } catch (_: SecurityException) {
            // İzin zaten yoksa bırakacak bir şey de yok.
        }
    }

    private data class Child(val id: String, val name: String)

    /** Klasörün kendisini gösteren belge adresi. */
    private fun folderDocument(tree: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(
            tree,
            DocumentsContract.getTreeDocumentId(tree),
        )

    private fun displayName(tree: Uri): String {
        val fallback = DocumentsContract.getTreeDocumentId(tree).substringAfterLast(':')
        return try {
            resolver
                .query(folderDocument(tree), arrayOf(Document.COLUMN_DISPLAY_NAME), null, null, null)
                ?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
                ?.takeIf { it.isNotBlank() } ?: fallback
        } catch (_: RuntimeException) {
            fallback
        }
    }

    /** Klasördeki belgeler; klasöre erişilemiyorsa `null`. */
    private fun children(tree: Uri): List<Child>? =
        try {
            val uri =
                DocumentsContract.buildChildDocumentsUriUsingTree(
                    tree,
                    DocumentsContract.getTreeDocumentId(tree),
                )
            resolver
                .query(
                    uri,
                    arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME),
                    null,
                    null,
                    null,
                )
                ?.use { cursor ->
                    buildList {
                        while (cursor.moveToNext()) {
                            val id = cursor.getString(0) ?: continue
                            val name = cursor.getString(1) ?: continue
                            add(Child(id, name))
                        }
                    }
                }
        } catch (_: RuntimeException) {
            // SecurityException (izin kalkmış), IllegalArgumentException (klasör yok)
            // ve sağlayıcıların attığı diğer çalışma zamanı hataları.
            null
        }

    private fun create(tree: Uri, mimeType: String, name: String): Uri? =
        try {
            DocumentsContract.createDocument(resolver, folderDocument(tree), mimeType, name)
        } catch (_: FileNotFoundException) {
            null
        } catch (_: RuntimeException) {
            null
        }

    private fun writeAll(document: Uri, bytes: ByteArray): Boolean =
        try {
            resolver.openOutputStream(document, "w")?.use { it.write(bytes) } != null
        } catch (_: IOException) {
            false
        } catch (_: RuntimeException) {
            false
        }

    /** Yazılanı geri okuyup karşılaştırır. Fazlası da eksiği de tutmaz sayılır. */
    private fun matches(document: Uri, expected: ByteArray): Boolean {
        val actual =
            try {
                resolver.openInputStream(document)?.use {
                    readAtMost(it, expected.size.toLong() + 1)
                }
            } catch (_: IOException) {
                null
            } catch (_: RuntimeException) {
                null
            } ?: return false
        try {
            return actual.contentEquals(expected)
        } finally {
            actual.fill(0)
        }
    }

    private fun deleteDocument(document: Uri): Boolean =
        try {
            DocumentsContract.deleteDocument(resolver, document)
        } catch (_: FileNotFoundException) {
            false
        } catch (_: RuntimeException) {
            false
        }

    private companion object {
        const val ACCESS =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
    }
}

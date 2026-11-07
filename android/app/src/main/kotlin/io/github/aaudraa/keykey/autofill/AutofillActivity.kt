package io.github.aaudraa.keykey.autofill

import android.app.assist.AssistStructure
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.service.autofill.Dataset
import android.view.WindowManager
import android.view.autofill.AutofillManager
import android.view.autofill.AutofillValue
import android.widget.RemoteViews
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.github.aaudraa.keykey.AutofillApi
import io.github.aaudraa.keykey.AutofillRequestInfo
import io.github.aaudraa.keykey.BiometricApi
import io.github.aaudraa.keykey.BiometricVault
import io.github.aaudraa.keykey.ClipboardApi
import io.github.aaudraa.keykey.R
import io.github.aaudraa.keykey.SecureClipboard

/**
 * Öneriye dokunulunca açılan doldurma ekranı. Kaydetme de bu ekranda yapılır:
 * niyet [EXTRA_SAVE_TOKEN] taşıyorsa ekran [PendingSaves] içindeki isteği alır
 * ve yalnızca kaydeder, hiçbir şey doldurmaz.
 *
 * Ana uygulamadan ayrı bir Flutter giriş noktasıyla (`autofillMain`) çalışır:
 * kasayı kendisi açar, kullanıcı kaydı seçer ve onaylar. Seçilen değerler
 * buradan bir `Dataset` olarak sisteme döner ve sistem onları hemen doldurur.
 * Ekran kapanınca Flutter motoru da kapanır.
 */
class AutofillActivity : FlutterFragmentActivity(), AutofillApi {
    private var parsed: ParsedStructure? = null
    private var request: AutofillRequestInfo? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
        readRequest(intent)
        super.onCreate(savedInstanceState)
    }

    override fun getDartEntrypointFunctionName(): String = "autofillMain"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        BiometricApi.setUp(messenger, BiometricVault(this))
        ClipboardApi.setUp(messenger, SecureClipboard(this))
        AutofillApi.setUp(messenger, this)
    }

    private fun readRequest(intent: Intent) {
        val saveToken = intent.getStringExtra(EXTRA_SAVE_TOKEN)
        if (saveToken != null) {
            request = PendingSaves.take(saveToken)
            return
        }
        val structure = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(AutofillManager.EXTRA_ASSIST_STRUCTURE, AssistStructure::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(AutofillManager.EXTRA_ASSIST_STRUCTURE)
        } ?: return
        val form = try {
            StructureParser.parse(structure)
        } catch (error: RuntimeException) {
            return
        }
        // KeyKey kendi formlarını doldurmaz.
        if (form.packageName == packageName || !form.form.hasCredentials) return
        parsed = form
        request = AutofillRequests.of(this, form)
    }

    override fun currentRequest(): AutofillRequestInfo? = request

    override fun hasSigningCertificates(packageName: String, certsSha256: List<String>): Boolean =
        SigningCerts.hasAll(packageManager, packageName, certsSha256)

    override fun fill(username: String, password: String) {
        val form = parsed
        if (form == null) {
            cancel()
            return
        }
        val presentation = RemoteViews(packageName, R.layout.autofill_item).apply {
            setTextViewText(R.id.autofill_text, getString(R.string.autofill_fill_with_keykey))
        }
        @Suppress("DEPRECATION")
        val builder = Dataset.Builder(presentation)
        var filled = 0
        if (username.isNotEmpty()) {
            for (id in form.idsOf(FieldKind.USERNAME)) {
                @Suppress("DEPRECATION")
                builder.setValue(id, AutofillValue.forText(username))
                filled++
            }
        }
        // Yalnızca giriş parolası doldurulur; yeni parola alanları kullanıcıya
        // bırakılır.
        if (password.isNotEmpty()) {
            for (id in form.idsOf(FieldKind.PASSWORD)) {
                @Suppress("DEPRECATION")
                builder.setValue(id, AutofillValue.forText(password))
                filled++
            }
        }
        if (filled == 0) {
            cancel()
            return
        }
        setResult(
            RESULT_OK,
            Intent().putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, builder.build()),
        )
        finish()
    }

    override fun cancel() {
        setResult(RESULT_CANCELED)
        finish()
    }

    companion object {
        /** Kaydetme isteğinin [PendingSaves] içindeki anahtarı. */
        const val EXTRA_SAVE_TOKEN = "io.github.aaudraa.keykey.autofill.SAVE_TOKEN"
    }
}

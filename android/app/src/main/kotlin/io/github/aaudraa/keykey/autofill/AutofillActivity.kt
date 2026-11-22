package io.github.aaudraa.keykey.autofill

import android.app.assist.AssistStructure
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.service.autofill.Dataset
import android.view.MotionEvent
import android.view.autofill.AutofillManager
import android.view.autofill.AutofillValue
import android.widget.RemoteViews
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.github.aaudraa.keykey.AppDomain
import io.github.aaudraa.keykey.AppPackages
import io.github.aaudraa.keykey.AppPackagesApi
import io.github.aaudraa.keykey.AutofillApi
import io.github.aaudraa.keykey.AutofillRequestInfo
import io.github.aaudraa.keykey.BiometricApi
import io.github.aaudraa.keykey.BiometricVault
import io.github.aaudraa.keykey.CardFillValues
import io.github.aaudraa.keykey.ClipboardApi
import io.github.aaudraa.keykey.R
import io.github.aaudraa.keykey.SecureClipboard
import io.github.aaudraa.keykey.WindowProtection

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

    /** Ekran "KeyKey ile kart doldur" önerisinden açıldı. */
    private var forCard = false

    private val protection = WindowProtection(this)

    override fun onCreate(savedInstanceState: Bundle?) {
        protection.beforeCreate()
        readRequest(intent)
        super.onCreate(savedInstanceState)
        protection.afterCreate()
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (protection.dropTouch(event)) return true
        return super.dispatchTouchEvent(event)
    }

    override fun getDartEntrypointFunctionName(): String = "autofillMain"

    /** Pencere saydam; karartmayı ve yarım pencereyi Flutter çizer. */
    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        BiometricApi.setUp(messenger, BiometricVault(this))
        ClipboardApi.setUp(messenger, SecureClipboard(this))
        AutofillApi.setUp(messenger, this)
        AppPackagesApi.setUp(messenger, AppPackages(this))
    }

    private fun readRequest(intent: Intent) {
        val saveToken = intent.getStringExtra(EXTRA_SAVE_TOKEN)
        if (saveToken != null) {
            val pending = PendingSaves.take(saveToken) ?: return
            request = AutofillRequests.of(this, pending.form, pending.values)
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
        // Hangi önerinin dokunulduğu niyetin eyleminden bilinir; formda o
        // türün alanı yoksa istek yok sayılır.
        val card = intent.action == ACTION_FILL_CARD
        val fillable = if (card) form.form.hasCard else form.form.hasCredentials
        // KeyKey kendi formlarını doldurmaz.
        if (IgnoredPackages.isIgnored(form.packageName, packageName) || !fillable) return
        parsed = form
        forCard = card
        request = AutofillRequests.of(this, form, forCard = card)
    }

    override fun currentRequest(): AutofillRequestInfo? = request

    override fun hasSigningCertificates(packageName: String, certsSha256: List<String>): Boolean =
        SigningCerts.hasAll(packageManager, packageName, certsSha256)

    override fun appDomains(packageName: String): List<AppDomain> =
        AppDomains.of(this, packageName)

    override fun fill(username: String, password: String, notice: String) {
        val form = parsed
        // Kart isteğine giriş değerleri doldurulmaz.
        if (form == null || forCard) {
            cancel()
            return
        }
        @Suppress("DEPRECATION")
        val builder = Dataset.Builder(presentation(R.string.autofill_fill_with_keykey))
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
        finishWith(builder.build(), notice)
    }

    override fun fillCard(values: CardFillValues, notice: String) {
        val form = parsed
        // Giriş isteğine kart değerleri doldurulmaz.
        if (form == null || !forCard) {
            cancel()
            return
        }
        val card = CardValues(
            number = values.number,
            cardholder = values.cardholder,
            expMonth = values.expMonth?.toInt(),
            expYear = values.expYear?.toInt(),
            securityCode = values.securityCode,
        )
        val fill = CardFill.values(form.fields, form.form, card)
        if (fill.isEmpty()) {
            cancel()
            return
        }
        @Suppress("DEPRECATION")
        val builder = Dataset.Builder(presentation(R.string.autofill_fill_card_with_keykey))
        for ((index, value) in fill) {
            val autofillValue = when (value) {
                is FillValue.Text -> AutofillValue.forText(value.text)
                is FillValue.ListIndex -> AutofillValue.forList(value.index)
                is FillValue.Date -> AutofillValue.forDate(value.millis)
            }
            @Suppress("DEPRECATION")
            builder.setValue(form.ids[index], autofillValue)
        }
        finishWith(builder.build(), notice)
    }

    private fun presentation(label: Int) = RemoteViews(packageName, R.layout.autofill_item).apply {
        setTextViewText(R.id.autofill_text, getString(label))
    }

    /**
     * Dolduranı sisteme döndürür ve ekranı kapatır. Bildirimde yalnızca
     * kaydın ya da kartın adı var; değerler bildirime girmez. Bu pencere
     * güvenli değildir, bkz. güvenlik tasarımı "Bilinen ödünler".
     */
    private fun finishWith(dataset: Dataset, notice: String) {
        Toast.makeText(applicationContext, notice, Toast.LENGTH_SHORT).show()
        setResult(
            RESULT_OK,
            Intent().putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, dataset),
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

        /** "KeyKey ile doldur" önerisinin niyeti. */
        const val ACTION_FILL_LOGIN = "io.github.aaudraa.keykey.autofill.FILL_LOGIN"

        /** "KeyKey ile kart doldur" önerisinin niyeti. */
        const val ACTION_FILL_CARD = "io.github.aaudraa.keykey.autofill.FILL_CARD"
    }
}

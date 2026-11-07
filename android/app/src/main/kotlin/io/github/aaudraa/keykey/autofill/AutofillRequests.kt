package io.github.aaudraa.keykey.autofill

import android.content.Context
import android.content.pm.PackageManager
import io.github.aaudraa.keykey.AutofillRequestInfo
import io.github.aaudraa.keykey.AutofillSaveValues
import java.util.UUID

/** Çözümlenmiş formdan Flutter ekranına verilecek isteği kurar. */
internal object AutofillRequests {
    fun of(context: Context, form: ParsedStructure, save: AutofillSaveValues? = null): AutofillRequestInfo {
        val pm = context.packageManager
        // Web alan adına yalnızca güvenilen tarayıcıdan gelirse inanılır;
        // WebView'lı bir uygulama istediği alan adını yazabilir.
        val trustedBrowser = TrustedBrowsers.isTrusted(pm, form.packageName)
        return AutofillRequestInfo(
            packageName = form.packageName,
            appLabel = labelOf(pm, form.packageName),
            certsSha256 = SigningCerts.digestsOf(pm, form.packageName),
            webDomain = form.webDomain.takeIf { trustedBrowser },
            webScheme = form.webScheme.takeIf { trustedBrowser },
            untrustedWebDomain = form.webDomain.takeUnless { trustedBrowser },
            hasUsernameField = form.idsOf(FieldKind.USERNAME).isNotEmpty(),
            hasPasswordField = form.idsOf(FieldKind.PASSWORD).isNotEmpty(),
            save = save,
        )
    }

    private fun labelOf(pm: PackageManager, packageName: String): String? = try {
        pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
    } catch (error: PackageManager.NameNotFoundException) {
        null
    }
}

/** Kaydetme ekranını bekleyen form ve kaydedilecek değerler. */
internal class PendingSave(val form: ParsedStructure, val values: AutofillSaveValues)

/**
 * Kaydetme ekranını bekleyen istekler.
 *
 * Değerler niyete konmaz, çünkü niyetler sistem sürecinden geçer ve orada
 * tutulur. Servis ve ekran aynı süreçte çalıştığı için istek bellekte bir
 * anahtarla bekler; niyet yalnızca anahtarı taşır. Ekran isteği alınca
 * buradan siler. Süreç kapanırsa istek de gider, ekran "form yok" der.
 *
 * Uygulamanın adı ve imzası ekranda okunur. Android KeyKey'e başka
 * uygulamaları ancak manifestteki sorgular sayesinde gösterir: ana ekranda
 * simgesi olan uygulamalar ve güvenilen tarayıcılar. Bunların dışındaki bir
 * uygulamanın imzası okunamazsa kayıt bağlanmadan kaydedilir.
 */
internal object PendingSaves {
    /** Sistem kaydetme ekranını hemen açar; birikmesin diye sınır var. */
    private const val MAX_PENDING = 4

    private val pending = LinkedHashMap<String, PendingSave>()

    @Synchronized
    fun put(request: PendingSave): String {
        while (pending.size >= MAX_PENDING) pending.remove(pending.keys.first())
        val token = UUID.randomUUID().toString()
        pending[token] = request
        return token
    }

    @Synchronized
    fun take(token: String): PendingSave? = pending.remove(token)
}

package io.github.aaudraa.keykey.autofill

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.view.autofill.AutofillManager
import io.github.aaudraa.keykey.AutofillSetupApi
import io.github.aaudraa.keykey.AutofillSetupStatus

/**
 * Ayarlar ekranındaki otomatik doldurma kurulumu.
 *
 * Yeni izin istemez: servisin seçili olup olmadığını `AutofillManager`
 * söyler, Chrome'un sürümü manifestteki tarayıcı sorgusu sayesinde okunur.
 * Chrome'daki "başka servis" ayarının açık olup olmadığı okunmaz; o
 * `READ_USER_DICTIONARY` gibi bir izin isterdi.
 */
class AutofillSetup(private val activity: Activity) : AutofillSetupApi {
    override fun status(): AutofillSetupStatus {
        val manager = activity.getSystemService(AutofillManager::class.java)
        return AutofillSetupStatus(
            supported = manager?.isAutofillSupported == true,
            enabled = manager?.hasEnabledAutofillServices() == true,
            chromeMajorVersion = chromeMajorVersion(),
        )
    }

    override fun openAutofillSettings(): Boolean {
        val intent = Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE)
            .setData(Uri.parse("package:${activity.packageName}"))
        // Sistem, niyetteki paketin isteyen uygulama olduğunu
        // getCallingPackage ile denetler; bu yalnızca sonuç beklenen
        // başlatmada doludur.
        return start { @Suppress("DEPRECATION") activity.startActivityForResult(intent, REQUEST_AUTOFILL) }
    }

    override fun openChromeAutofillSettings(): Boolean {
        val intent = Intent(Intent.ACTION_APPLICATION_PREFERENCES)
            .addCategory(Intent.CATEGORY_DEFAULT)
            .addCategory(Intent.CATEGORY_APP_BROWSER)
            .addCategory(Intent.CATEGORY_PREFERENCE)
            .setPackage(CHROME)
        return start { activity.startActivity(intent) }
    }

    private fun start(launch: () -> Unit): Boolean = try {
        launch()
        true
    } catch (error: ActivityNotFoundException) {
        false
    }

    private fun chromeMajorVersion(): Long? = try {
        activity.packageManager.getPackageInfo(CHROME, 0)
            .versionName?.substringBefore('.')?.toLongOrNull()
    } catch (error: PackageManager.NameNotFoundException) {
        null
    }

    private companion object {
        const val CHROME = "com.android.chrome"
        const val REQUEST_AUTOFILL = 4201
    }
}

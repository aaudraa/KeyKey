package io.github.aaudraa.keykey

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri

/**
 * Kayıttaki siteyi ve Hakkında bağlantılarını sistemin tarayıcısında açar.
 *
 * Sayfayı KeyKey indirmez; adres yalnızca kullanıcı dokununca
 * tarayıcıya devredilir. Dart tarafı da denetlese de burada yalnızca http ve
 * https kabul edilir: `intent:`, `javascript:` ya da `file:` bir bağlantı
 * başka bir uygulamanın bileşenini başlatamasın.
 */
class WebLinks(private val activity: Activity) : WebLinkApi {
    override fun openWebPage(url: String): Boolean {
        val uri = Uri.parse(url)
        if (!isWebPage(uri.scheme, uri.host)) return false
        val intent = Intent(Intent.ACTION_VIEW, uri)
            .addCategory(Intent.CATEGORY_BROWSABLE)
        return try {
            activity.startActivity(intent)
            true
        } catch (error: ActivityNotFoundException) {
            false
        }
    }

    companion object {
        fun isWebPage(scheme: String?, host: String?): Boolean =
            scheme?.lowercase() in setOf("http", "https") && !host.isNullOrEmpty()
    }
}

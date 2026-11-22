package io.github.aaudraa.keykey.autofill

import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.verify.domain.DomainVerificationManager
import android.content.pm.verify.domain.DomainVerificationUserState
import android.os.Build
import io.github.aaudraa.keykey.AppDomain
import java.util.Locale

/**
 * Bir uygulamanın bildirdiği alan adları ve sistemin onları doğrulayıp
 * doğrulamadığı (Android 12+, `DomainVerificationManager`).
 *
 * Başka bir uygulamanın durumu yalnızca o uygulama KeyKey'e görünürse
 * okunabilir; ek izin gerekmez. Doldurma ekranını hedef uygulama başlattığı
 * için görünürdür. Tasarım: `resources/docs/uygulama-site-eslestirme.md`.
 */
object AppDomains {
    fun of(context: Context, packageName: String): List<AppDomain> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return emptyList()
        val manager = context.getSystemService(DomainVerificationManager::class.java)
            ?: return emptyList()
        val state = try {
            manager.getDomainVerificationUserState(packageName)
        } catch (error: PackageManager.NameNotFoundException) {
            null
        } catch (error: SecurityException) {
            null
        } ?: return emptyList()
        return fromStates(state.hostToStateMap).map { (host, verified) ->
            AppDomain(host = host, verified = verified)
        }
    }

    /**
     * Alan adı → durum haritasını küçük harfli, sıralı listeye çevirir.
     * Yalnızca `DOMAIN_STATE_VERIFIED` doğrulanmış sayılır; kullanıcının
     * ayarlardan açtığı (`SELECTED`) sitenin onayı değildir.
     */
    internal fun fromStates(states: Map<String, Int>): List<Pair<String, Boolean>> =
        states.entries
            .map { (host, state) ->
                host.lowercase(Locale.ROOT) to
                    (state == DomainVerificationUserState.DOMAIN_STATE_VERIFIED)
            }
            .sortedBy { it.first }
}

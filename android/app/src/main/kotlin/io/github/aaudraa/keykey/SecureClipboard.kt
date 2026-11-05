package io.github.aaudraa.keykey

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.os.SystemClock
import java.security.MessageDigest

/**
 * Hassas metni panoya kopyalar ve süre dolunca temizler.
 *
 * Uygulama öndeyken temizliği zamanlayıcı yapar ve yalnızca panoda hâlâ bizim
 * kopyamız varsa siler. Uygulama arka plandaysa Android panoyu okutmaz; o zaman
 * temizliği izin gerektirmeyen, kesin olmayan bir alarm yapar ve koşulsuz siler.
 * Sınırlar güvenlik tasarımı belgesinin Pano bölümünde.
 */
class SecureClipboard(context: Context) : ClipboardApi {
    private val context = context.applicationContext
    private val clipboard = this.context.getSystemService(ClipboardManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private var pendingClear: Runnable? = null

    // Panoda hâlâ bizim kopyamız mı diye bakmak için metnin kendisini değil
    // özetini tutarız. Zaman damgası güvenilir çıkmadı: kopyalar kopyalamaz
    // okunan değer sonradan okunanla eşleşmeyebiliyor.
    private var copiedDigest: ByteArray? = null

    override fun copySensitive(text: String, clearAfterMillis: Long) {
        val clip = ClipData.newPlainText(LABEL, text)
        clip.description.extras =
            PersistableBundle().apply {
                // Android 13+ önizlemede göstermez. Sabit adı eski sürümlerde de
                // aynıdır, bazı klavyeler ve üreticiler buna bakıyor.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
                } else {
                    putBoolean(SENSITIVE_EXTRA, true)
                }
            }
        clipboard.setPrimaryClip(clip)
        copiedDigest = digest(text)

        pendingClear?.let(handler::removeCallbacks)
        val clear = Runnable { clearIfStillOurs() }
        pendingClear = clear
        handler.postDelayed(clear, clearAfterMillis)
        scheduleAlarm(clearAfterMillis)
    }

    private fun clearIfStillOurs() {
        pendingClear = null
        cancelAlarm()
        // Önde: yalnızca bizim kopyamızı sileriz. Arka planda pano okunamaz,
        // o durumda kullanıcının sonraki kopyasını ayırt edemeyiz ve sileriz.
        val current = clipboard.primaryClip?.takeIf { it.itemCount > 0 }
            ?.getItemAt(0)?.text?.toString()
        val expected = copiedDigest
        if (current == null || expected == null ||
            MessageDigest.isEqual(digest(current), expected)
        ) {
            clipboard.clearPrimaryClip()
        }
        copiedDigest = null
    }

    private fun digest(text: String): ByteArray =
        MessageDigest.getInstance("SHA-256").digest(text.toByteArray(Charsets.UTF_8))

    private fun pendingIntent(): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, ClipboardClearReceiver::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

    private fun scheduleAlarm(delayMillis: Long) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        alarms.setAndAllowWhileIdle(
            AlarmManager.ELAPSED_REALTIME,
            SystemClock.elapsedRealtime() + delayMillis,
            pendingIntent(),
        )
    }

    private fun cancelAlarm() {
        context.getSystemService(AlarmManager::class.java).cancel(pendingIntent())
    }

    companion object {
        private const val LABEL = "KeyKey"
        private const val SENSITIVE_EXTRA = "android.content.extra.IS_SENSITIVE"
    }
}

/** Uygulama arka plandayken veya süreç kapandıysa panoyu temizler. */
class ClipboardClearReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        context.getSystemService(ClipboardManager::class.java).clearPrimaryClip()
    }
}

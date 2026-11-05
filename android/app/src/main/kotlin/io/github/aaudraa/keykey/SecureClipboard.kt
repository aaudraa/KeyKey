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
 * Temizliği önce zamanlayıcı yapar. Süreç durdurulduysa veya dondurulduysa,
 * biraz paylı kurulan ve izin gerektirmeyen bir alarm yapar. İkisi de panoda
 * hâlâ bizim kopyamız varsa siler; Android arka plandaki uygulamaya panoyu
 * okutmadığı için orada bunu ayırt edemez ve siler. Sınırlar güvenlik tasarımı
 * belgesinin Pano bölümünde.
 */
class SecureClipboard(context: Context) : ClipboardApi {
    private val context = context.applicationContext
    private val handler = Handler(Looper.getMainLooper())
    private var pendingClear: Runnable? = null

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
        clipboard(context).setPrimaryClip(clip)
        copiedDigest = digest(text)

        pendingClear?.let(handler::removeCallbacks)
        val clear = Runnable { clearIfStillOurs(context) }
        pendingClear = clear
        handler.postDelayed(clear, clearAfterMillis)
        // Zamanlayıcı önce çalışsın diye alarm paylı kurulur. Aynı ana kurulunca
        // Android 11'de alarm önce çalışıp kullanıcının yeni kopyasını sildi.
        scheduleAlarm(context, clearAfterMillis + ALARM_MARGIN_MILLIS)
    }

    companion object {
        private const val LABEL = "KeyKey"
        private const val SENSITIVE_EXTRA = "android.content.extra.IS_SENSITIVE"
        private const val ALARM_MARGIN_MILLIS = 10_000L

        // Panoda hâlâ bizim kopyamız mı diye bakmak için metnin kendisini
        // değil özetini tutarız, yalnızca bellekte. Zaman damgası güvenilir
        // çıkmadı: kopyalar kopyalamaz okunan değer sonradan okunanla
        // eşleşmeyebiliyor.
        @Volatile private var copiedDigest: ByteArray? = null

        /** Panoda hâlâ bizim kopyamız varsa veya bunu bilemiyorsak siler. */
        fun clearIfStillOurs(context: Context) {
            cancelAlarm(context)
            val clipboard = clipboard(context)
            val current =
                clipboard.primaryClip
                    ?.takeIf { it.itemCount > 0 }
                    ?.getItemAt(0)
                    ?.text
                    ?.toString()
            val expected = copiedDigest
            if (current == null || expected == null ||
                MessageDigest.isEqual(digest(current), expected)
            ) {
                clipboard.clearPrimaryClip()
            }
            copiedDigest = null
        }

        private fun clipboard(context: Context): ClipboardManager =
            context.getSystemService(ClipboardManager::class.java)

        private fun digest(text: String): ByteArray =
            MessageDigest.getInstance("SHA-256").digest(text.toByteArray(Charsets.UTF_8))

        private fun pendingIntent(context: Context): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                0,
                Intent(context, ClipboardClearReceiver::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )

        private fun scheduleAlarm(context: Context, delayMillis: Long) {
            context.getSystemService(AlarmManager::class.java).setAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME,
                SystemClock.elapsedRealtime() + delayMillis,
                pendingIntent(context),
            )
        }

        private fun cancelAlarm(context: Context) {
            context.getSystemService(AlarmManager::class.java).cancel(pendingIntent(context))
        }
    }
}

/** Zamanlayıcı çalışamadıysa panoyu temizler, örneğin süreç durdurulduysa. */
class ClipboardClearReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        SecureClipboard.clearIfStillOurs(context.applicationContext)
    }
}

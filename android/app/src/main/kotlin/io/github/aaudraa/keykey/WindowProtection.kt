package io.github.aaudraa.keykey

import android.app.Activity
import android.os.Build
import android.os.SystemClock
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Toast

/**
 * KeyKey pencerelerini başka uygulamalara karşı korur: ekran görüntüsü,
 * bindirme pencereleriyle dokunma korsanlığı (tapjacking) ve erişilebilirlik
 * servisleri. Ana uygulama ve doldurma ekranı aynı korumayı kullanır.
 *
 * Kurallar güvenlik tasarımı belgesinin "Arayüz koruması" bölümünde.
 */
class WindowProtection(private val activity: Activity) {
    private var lastNoticeAt = 0L

    /** `super.onCreate`'ten önce çağrılır. */
    fun beforeCreate() {
        val window = activity.window
        // Ekran görüntüsünü, ekran kaydını ve son uygulamalar önizlemesini engeller.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.setRecentsScreenshotEnabled(false)
        }
        // KeyKey ekrandayken başka uygulamaların bindirme pencereleri gizlenir.
        // HIDE_OVERLAY_WINDOWS izni gerekir; sistem pencereleri etkilenmez.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            window.setHideOverlayWindows(true)
        }
    }

    /**
     * `super.onCreate`'ten sonra çağrılır: pencerenin görünüm ağacı ancak o
     * zaman kurulur.
     */
    fun afterCreate() {
        // Ekranın içeriğini yalnızca kendini erişilebilirlik aracı olarak
        // bildiren servisler (TalkBack, Switch Access gibi) okuyabilir.
        // FLAG_SECURE erişilebilirlik servislerini engellemez.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            activity.window.decorView.setAccessibilityDataSensitive(
                View.ACCESSIBILITY_DATA_SENSITIVE_YES,
            )
        }
    }

    /**
     * Dokunuş düşürülecekse `true` döner ve kullanıcıya nedenini söyler.
     * Etkinliğin `dispatchTouchEvent`'i bunu ilk iş olarak sorar.
     */
    fun dropTouch(event: MotionEvent): Boolean {
        if (!shouldDropTouch(Build.VERSION.SDK_INT, event.flags)) return false
        val now = SystemClock.uptimeMillis()
        if (event.actionMasked == MotionEvent.ACTION_DOWN && now - lastNoticeAt > NOTICE_INTERVAL_MS) {
            lastNoticeAt = now
            Toast.makeText(activity, R.string.touch_blocked_overlay, Toast.LENGTH_LONG).show()
        }
        return true
    }

    companion object {
        private const val NOTICE_INTERVAL_MS = 3_000L

        /**
         * Android 11'de bindirme pencereleri gizlenemez. Orada, dokunulan
         * noktanın üstünde başka bir uygulamanın penceresi varsa dokunuş
         * düşürülür. Android 12 ve sonrasında pencereler zaten gizlendiği
         * için düşürülmez; sistemin kendi pencereleri (ör. büyüteç) KeyKey'i
         * kullanılmaz hale getirmesin.
         */
        fun shouldDropTouch(sdk: Int, flags: Int): Boolean =
            sdk < Build.VERSION_CODES.S && flags and MotionEvent.FLAG_WINDOW_IS_OBSCURED != 0
    }
}

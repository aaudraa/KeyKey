package io.github.aaudraa.keykey

import android.os.Build
import android.view.MotionEvent
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WindowProtectionTest {
    private val obscured = MotionEvent.FLAG_WINDOW_IS_OBSCURED
    private val partially = MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED

    @Test
    fun `Android 11'de örtülü dokunuş düşürülüyor`() {
        assertTrue(WindowProtection.shouldDropTouch(Build.VERSION_CODES.R, obscured))
        assertTrue(WindowProtection.shouldDropTouch(Build.VERSION_CODES.R, obscured or partially))
    }

    @Test
    fun `Android 11'de örtülmemiş veya yalnızca kısmen örtülü dokunuş geçiyor`() {
        assertFalse(WindowProtection.shouldDropTouch(Build.VERSION_CODES.R, 0))
        // Dokunulan noktanın üstünde değil, ekranın başka yerinde bir pencere var.
        assertFalse(WindowProtection.shouldDropTouch(Build.VERSION_CODES.R, partially))
    }

    @Test
    fun `Android 12 ve sonrasında dokunuş düşürülmüyor, pencereler zaten gizli`() {
        for (sdk in listOf(Build.VERSION_CODES.S, Build.VERSION_CODES.UPSIDE_DOWN_CAKE, 36, 37)) {
            assertFalse(WindowProtection.shouldDropTouch(sdk, obscured))
        }
    }
}

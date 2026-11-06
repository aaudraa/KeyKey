package io.github.aaudraa.keykey.autofill

import android.app.Activity
import android.os.Bundle

/**
 * Öneriye dokunulunca açılan doldurma ekranı.
 *
 * Geçici: kasa açma ve kayıt seçimi ayrı Flutter giriş noktasıyla gelecek.
 * Şimdilik hiçbir şey doldurmadan kapanır.
 */
class AutofillActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        finish()
    }
}

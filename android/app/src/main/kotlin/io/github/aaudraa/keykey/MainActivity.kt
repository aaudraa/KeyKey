package io.github.aaudraa.keykey

import android.os.Bundle
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.github.aaudraa.keykey.autofill.AutofillSetup

// BiometricPrompt, FragmentActivity gerektirdiği için FlutterActivity kullanılmıyor.
class MainActivity : FlutterFragmentActivity() {
    private val protection = WindowProtection(this)

    override fun onCreate(savedInstanceState: Bundle?) {
        protection.beforeCreate()
        super.onCreate(savedInstanceState)
        protection.afterCreate()
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (protection.dropTouch(event)) return true
        return super.dispatchTouchEvent(event)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        BiometricApi.setUp(messenger, BiometricVault(this))
        ClipboardApi.setUp(messenger, SecureClipboard(this))
        ImportCryptoApi.setUp(messenger, ImportCrypto())
        AutofillSetupApi.setUp(messenger, AutofillSetup(this))
        DocumentApi.setUp(messenger, DocumentFiles(this))
    }
}

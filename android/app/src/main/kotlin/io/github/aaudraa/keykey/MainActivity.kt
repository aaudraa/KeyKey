package io.github.aaudraa.keykey

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.github.aaudraa.keykey.autofill.AutofillSetup

// BiometricPrompt, FragmentActivity gerektirdiği için FlutterActivity kullanılmıyor.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Ekran görüntüsünü, ekran kaydını ve son uygulamalar önizlemesini engeller.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
        super.onCreate(savedInstanceState)
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

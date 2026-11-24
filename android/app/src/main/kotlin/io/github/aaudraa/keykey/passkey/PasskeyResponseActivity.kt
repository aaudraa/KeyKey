package io.github.aaudraa.keykey.passkey

import android.app.Activity
import android.os.Build
import android.os.Bundle
import androidx.annotation.RequiresApi
import androidx.credentials.GetCredentialResponse
import androidx.credentials.PublicKeyCredential
import androidx.credentials.exceptions.GetCredentialUnknownException
import androidx.credentials.provider.PendingIntentHandler

/**
 * Kullanıcı sistem penceresinde bir hesap seçince açılır; görünmez. Kasa
 * açılırken hesaplanmış yanıtı [PendingAssertions]'tan alıp verir. Flutter
 * çalıştırılmaz, kasa yeniden açılmaz.
 */
@RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
class PasskeyResponseActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val token = intent.getStringExtra(EXTRA_TOKEN)
        val credentialId = intent.getStringExtra(EXTRA_CREDENTIAL_ID)
        val response = if (token != null && credentialId != null) {
            PendingAssertions.take(token, credentialId)
        } else {
            null
        }
        val result = intent
        if (response == null) {
            PendingIntentHandler.setGetCredentialException(
                result,
                GetCredentialUnknownException(getString(io.github.aaudraa.keykey.R.string.passkey_expired)),
            )
        } else {
            PendingIntentHandler.setGetCredentialResponse(
                result,
                GetCredentialResponse(PublicKeyCredential(response)),
            )
        }
        setResult(RESULT_OK, result)
        finish()
    }

    companion object {
        const val EXTRA_TOKEN = "io.github.aaudraa.keykey.passkey.TOKEN"
        const val EXTRA_CREDENTIAL_ID = "io.github.aaudraa.keykey.passkey.CREDENTIAL_ID"
    }
}

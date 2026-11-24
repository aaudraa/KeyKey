package io.github.aaudraa.keykey.passkey

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.CancellationSignal
import android.os.OutcomeReceiver
import androidx.annotation.RequiresApi
import androidx.credentials.exceptions.ClearCredentialException
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.provider.AuthenticationAction
import androidx.credentials.provider.BeginCreateCredentialRequest
import androidx.credentials.provider.BeginCreateCredentialResponse
import androidx.credentials.provider.BeginCreatePublicKeyCredentialRequest
import androidx.credentials.provider.BeginGetCredentialRequest
import androidx.credentials.provider.BeginGetCredentialResponse
import androidx.credentials.provider.BeginGetPublicKeyCredentialOption
import androidx.credentials.provider.CreateEntry
import androidx.credentials.provider.CredentialProviderService
import androidx.credentials.provider.ProviderClearCredentialStateRequest
import io.github.aaudraa.keykey.R

/**
 * KeyKey'in Credential Manager sağlayıcısı (Android 14+). Yalnızca passkey.
 *
 * Servis kasaya hiç dokunmaz: kilitliyken hangi sitelerde passkey olduğu
 * bilinmez ve söylenmez. Oluşturmada tek bir "KeyKey" seçeneği, girişte
 * "KeyKey'in kilidini aç" eylemi verir; ikisi de [PasskeyActivity]'yi açar.
 */
@RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
class KeyKeyCredentialService : CredentialProviderService() {
    override fun onBeginCreateCredentialRequest(
        request: BeginCreateCredentialRequest,
        cancellationSignal: CancellationSignal,
        callback: OutcomeReceiver<BeginCreateCredentialResponse, CreateCredentialException>,
    ) {
        callback.onResult(createResponse(this, request))
    }

    override fun onBeginGetCredentialRequest(
        request: BeginGetCredentialRequest,
        cancellationSignal: CancellationSignal,
        callback: OutcomeReceiver<BeginGetCredentialResponse, GetCredentialException>,
    ) {
        callback.onResult(getResponse(this, request))
    }

    override fun onClearCredentialStateRequest(
        request: ProviderClearCredentialStateRequest,
        cancellationSignal: CancellationSignal,
        callback: OutcomeReceiver<Void?, ClearCredentialException>,
    ) {
        // KeyKey oturum tutmaz; temizlenecek bir şey yok.
        callback.onResult(null)
    }

    internal companion object {
        private const val REQUEST_CREATE = 1
        private const val REQUEST_UNLOCK = 2

        fun createResponse(
            context: Context,
            request: BeginCreateCredentialRequest,
        ): BeginCreateCredentialResponse {
            if (request !is BeginCreatePublicKeyCredentialRequest) {
                return BeginCreateCredentialResponse()
            }
            val entry = CreateEntry.Builder(
                context.getString(R.string.passkey_account_name),
                activityIntent(context, PasskeyActivity.ACTION_CREATE, REQUEST_CREATE),
            ).build()
            return BeginCreateCredentialResponse.Builder().addCreateEntry(entry).build()
        }

        fun getResponse(
            context: Context,
            request: BeginGetCredentialRequest,
        ): BeginGetCredentialResponse {
            val wantsPasskey = request.beginGetCredentialOptions.any {
                it is BeginGetPublicKeyCredentialOption
            }
            if (!wantsPasskey) return BeginGetCredentialResponse()
            val unlock = AuthenticationAction(
                context.getString(R.string.passkey_unlock),
                activityIntent(context, PasskeyActivity.ACTION_UNLOCK, REQUEST_UNLOCK),
            )
            return BeginGetCredentialResponse.Builder().addAuthenticationAction(unlock).build()
        }

        private fun activityIntent(context: Context, action: String, code: Int): PendingIntent {
            val intent = Intent(context, PasskeyActivity::class.java).setAction(action)
            // Sistem isteği niyete kendisi ekler; bu yüzden değiştirilebilir.
            return PendingIntent.getActivity(
                context,
                code,
                intent,
                PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
    }
}

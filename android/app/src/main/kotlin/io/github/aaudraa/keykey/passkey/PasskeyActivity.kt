package io.github.aaudraa.keykey.passkey

import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.SigningInfo
import android.os.Build
import android.os.Bundle
import android.view.MotionEvent
import androidx.annotation.RequiresApi
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CreatePublicKeyCredentialResponse
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.CreateCredentialUnknownException
import androidx.credentials.exceptions.domerrors.InvalidStateError
import androidx.credentials.exceptions.domerrors.NotSupportedError
import androidx.credentials.exceptions.domerrors.SecurityError
import androidx.credentials.exceptions.publickeycredential.CreatePublicKeyCredentialDomException
import androidx.credentials.provider.BeginGetCredentialResponse
import androidx.credentials.provider.BeginGetPublicKeyCredentialOption
import androidx.credentials.provider.CallingAppInfo
import androidx.credentials.provider.PendingIntentHandler
import androidx.credentials.provider.PublicKeyCredentialEntry
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.github.aaudraa.keykey.AppDomain
import io.github.aaudraa.keykey.AppPackages
import io.github.aaudraa.keykey.AppPackagesApi
import io.github.aaudraa.keykey.BiometricApi
import io.github.aaudraa.keykey.BiometricVault
import io.github.aaudraa.keykey.ClipboardApi
import io.github.aaudraa.keykey.PasskeyApi
import io.github.aaudraa.keykey.PasskeyAssertion
import io.github.aaudraa.keykey.PasskeyCryptoApi
import io.github.aaudraa.keykey.PasskeyRequestInfo
import io.github.aaudraa.keykey.SecureClipboard
import io.github.aaudraa.keykey.WindowProtection
import io.github.aaudraa.keykey.autofill.AppDomains
import io.github.aaudraa.keykey.autofill.SigningCerts

/**
 * Passkey penceresi: oluşturmada ve girişte kasayı açtırır. Ana uygulamadan
 * ayrı bir Flutter giriş noktasıyla (`passkeyMain`) çalışır; kasa işlemden
 * sonra kilitlenir ve ekranla birlikte motor da kapanır.
 *
 * Oluşturmada yanıt doğrudan sisteme döner. Girişte kilit açılınca sitenin
 * passkey'leri için yanıtlar hesaplanır, [PendingAssertions]'a konur ve
 * sisteme hesap listesi verilir; seçimi [PasskeyResponseActivity] tamamlar.
 */
@RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
class PasskeyActivity : FlutterFragmentActivity(), PasskeyApi {
    private var info: PasskeyRequestInfo? = null
    private var getOption: BeginGetPublicKeyCredentialOption? = null
    private val protection = WindowProtection(this)

    override fun onCreate(savedInstanceState: Bundle?) {
        protection.beforeCreate()
        info = readRequest(intent)
        super.onCreate(savedInstanceState)
        protection.afterCreate()
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (protection.dropTouch(event)) return true
        return super.dispatchTouchEvent(event)
    }

    override fun getDartEntrypointFunctionName(): String = "passkeyMain"

    /** Pencere saydam; karartmayı ve yarım pencereyi Flutter çizer. */
    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        BiometricApi.setUp(messenger, BiometricVault(this))
        ClipboardApi.setUp(messenger, SecureClipboard(this))
        AppPackagesApi.setUp(messenger, AppPackages(this))
        PasskeyApi.setUp(messenger, this)
        PasskeyCryptoApi.setUp(messenger, PasskeyCrypto())
    }

    private fun readRequest(intent: Intent): PasskeyRequestInfo? = when (intent.action) {
        ACTION_CREATE -> {
            val request = PendingIntentHandler.retrieveProviderCreateCredentialRequest(intent)
            val call = request?.callingRequest as? CreatePublicKeyCredentialRequest
            if (request == null || call == null) {
                null
            } else {
                info(KIND_CREATE, call.requestJson, call.clientDataHash, request.callingAppInfo)
            }
        }
        ACTION_UNLOCK -> {
            val request = PendingIntentHandler.retrieveBeginGetCredentialRequest(intent)
            val option = request?.beginGetCredentialOptions
                ?.filterIsInstance<BeginGetPublicKeyCredentialOption>()
                ?.firstOrNull()
            val caller = request?.callingAppInfo
            getOption = option
            if (option == null || caller == null) {
                null
            } else {
                info(KIND_GET, option.requestJson, option.clientDataHash, caller)
            }
        }
        else -> null
    }

    private fun info(
        kind: String,
        requestJson: String,
        clientDataHash: ByteArray?,
        caller: CallingAppInfo,
    ): PasskeyRequestInfo {
        // Yalnızca listedeki tarayıcının bildirdiği web origin'ine güvenilir;
        // başka çağıranda null döner.
        val origin = try {
            caller.getOrigin(PrivilegedBrowsers.allowlistJson)
        } catch (_: IllegalArgumentException) {
            null
        } catch (_: IllegalStateException) {
            null
        }
        return PasskeyRequestInfo(
            kind = kind,
            requestJson = requestJson,
            packageName = caller.packageName,
            certsSha256 = digests(caller.signingInfo),
            appLabel = label(caller.packageName),
            browserOrigin = origin,
            clientDataHash = clientDataHash,
        )
    }

    /** Otomatik doldurmadaki kuralla: tek imzacıda şu anki sertifika. */
    private fun digests(signing: SigningInfo): List<String> {
        val certs = if (signing.hasMultipleSigners()) {
            signing.apkContentsSigners
        } else {
            signing.signingCertificateHistory?.takeLast(1)?.toTypedArray()
        }
        return certs.orEmpty()
            .map { SigningCerts.toHex(SigningCerts.sha256(it.toByteArray())) }
            .distinct()
    }

    private fun label(packageName: String): String? = try {
        packageManager.getApplicationLabel(packageManager.getApplicationInfo(packageName, 0))
            .toString()
    } catch (_: PackageManager.NameNotFoundException) {
        null
    }

    override fun request(): PasskeyRequestInfo? = info

    override fun hasSigningCertificates(packageName: String, certsSha256: List<String>): Boolean =
        SigningCerts.hasAll(packageManager, packageName, certsSha256)

    override fun appDomains(packageName: String): List<AppDomain> =
        AppDomains.of(this, packageName)

    override fun finishCreate(responseJson: String) {
        val result = Intent()
        PendingIntentHandler.setCreateCredentialResponse(
            result,
            CreatePublicKeyCredentialResponse(responseJson),
        )
        done(result)
    }

    override fun finishGet(assertions: List<PasskeyAssertion>) {
        val option = getOption
        val result = Intent()
        val response = if (option == null || assertions.isEmpty()) {
            BeginGetCredentialResponse()
        } else {
            val token = PendingAssertions.put(
                assertions.associate { it.credentialId to it.responseJson },
            )
            val entries = assertions.mapIndexed { index, assertion ->
                PublicKeyCredentialEntry.Builder(
                    this,
                    assertion.userName,
                    responseIntent(token, assertion.credentialId, index),
                    option,
                ).setDisplayName(assertion.displayName.ifEmpty { null }).build()
            }
            BeginGetCredentialResponse.Builder().setCredentialEntries(entries).build()
        }
        PendingIntentHandler.setBeginGetCredentialResponse(result, response)
        done(result)
    }

    override fun fail(error: String) {
        if (intent.action != ACTION_CREATE) {
            // Girişte hata: sistem bu sağlayıcıdan hesap göstermez.
            finishGet(emptyList())
            return
        }
        val result = Intent()
        PendingIntentHandler.setCreateCredentialException(result, createException(error))
        done(result)
    }

    override fun cancel() {
        if (intent.action == ACTION_CREATE) {
            val result = Intent()
            PendingIntentHandler.setCreateCredentialException(
                result,
                CreateCredentialCancellationException(),
            )
            done(result)
        } else {
            setResult(RESULT_CANCELED)
            finish()
        }
    }

    private fun done(result: Intent) {
        setResult(RESULT_OK, result)
        finish()
    }

    private fun responseIntent(token: String, credentialId: String, index: Int): PendingIntent {
        val intent = Intent(this, PasskeyResponseActivity::class.java)
            .putExtra(PasskeyResponseActivity.EXTRA_TOKEN, token)
            .putExtra(PasskeyResponseActivity.EXTRA_CREDENTIAL_ID, credentialId)
        return PendingIntent.getActivity(
            this,
            RESPONSE_REQUEST_BASE + index,
            intent,
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    companion object {
        const val ACTION_CREATE = "io.github.aaudraa.keykey.passkey.CREATE"
        const val ACTION_UNLOCK = "io.github.aaudraa.keykey.passkey.UNLOCK"
        private const val KIND_CREATE = "create"
        private const val KIND_GET = "get"
        private const val RESPONSE_REQUEST_BASE = 100

        internal fun createException(error: String): CreateCredentialException = when (error) {
            "alreadyExists" -> CreatePublicKeyCredentialDomException(InvalidStateError())
            "unsupportedAlgorithm" -> CreatePublicKeyCredentialDomException(NotSupportedError())
            "rpIdMismatch" -> CreatePublicKeyCredentialDomException(SecurityError())
            else -> CreateCredentialUnknownException(error)
        }
    }
}

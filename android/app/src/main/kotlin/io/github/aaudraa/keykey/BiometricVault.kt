package io.github.aaudraa.keykey

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricPrompt
import androidx.fragment.app.FragmentActivity
import java.security.GeneralSecurityException
import java.security.KeyStore
import java.security.ProviderException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Kasa anahtarını Keystore'daki AES-256-GCM anahtarıyla sarar.
 *
 * Anahtar yalnızca BIOMETRIC_STRONG doğrulaması ve CryptoObject ile kullanılabilir,
 * süre penceresi yoktur, yeni parmak izi eklenince geçersiz olur. Ayrıntılar güvenlik
 * tasarımı belgesinin Biyometri bölümünde.
 *
 * Hata kayıtlarına anahtar veya düz metin yazılmaz.
 */
class BiometricVault(private val activity: FragmentActivity) : BiometricApi {
    private val keyStore: KeyStore
        get() = KeyStore.getInstance(KEYSTORE).apply { load(null) }

    override fun availability(): BiometricAvailability =
        when (BiometricManager.from(activity).canAuthenticate(BIOMETRIC_STRONG)) {
            BiometricManager.BIOMETRIC_SUCCESS -> BiometricAvailability.AVAILABLE
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE,
            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE,
            -> BiometricAvailability.NO_HARDWARE
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> BiometricAvailability.NOT_ENROLLED
            else -> BiometricAvailability.UNAVAILABLE
        }

    override suspend fun wrap(
        plainText: ByteArray,
        associatedData: ByteArray,
        texts: BiometricPromptTexts,
    ): BiometricWrapResult = suspendCancellableCoroutine { continuation ->
        wrap(plainText, associatedData, texts) { continuation.resume(it) }
    }

    override suspend fun unwrap(
        iv: ByteArray,
        cipherText: ByteArray,
        associatedData: ByteArray,
        texts: BiometricPromptTexts,
    ): BiometricUnwrapResult = suspendCancellableCoroutine { continuation ->
        unwrap(iv, cipherText, associatedData, texts) { continuation.resume(it) }
    }

    private fun wrap(
        plainText: ByteArray,
        associatedData: ByteArray,
        texts: BiometricPromptTexts,
        callback: (BiometricWrapResult) -> Unit,
    ) {
        fun finish(result: BiometricWrapResult) {
            plainText.fill(0)
            if (result.status != BiometricStatus.SUCCESS) deleteKey()
            callback(result)
        }

        val cipher =
            try {
                deleteKey()
                newCipher().apply { init(Cipher.ENCRYPT_MODE, generateKey()) }
            } catch (_: GeneralSecurityException) {
                finish(BiometricWrapResult(BiometricStatus.FAILED))
                return
            } catch (_: ProviderException) {
                finish(BiometricWrapResult(BiometricStatus.FAILED))
                return
            }

        authenticate(cipher, texts, { finish(BiometricWrapResult(it)) }) { authenticated ->
            val result =
                try {
                    authenticated.updateAAD(associatedData)
                    val cipherText = authenticated.doFinal(plainText)
                    BiometricWrapResult(BiometricStatus.SUCCESS, authenticated.iv, cipherText)
                } catch (_: GeneralSecurityException) {
                    BiometricWrapResult(BiometricStatus.FAILED)
                } catch (_: IllegalStateException) {
                    BiometricWrapResult(BiometricStatus.FAILED)
                }
            finish(result)
        }
    }

    private fun unwrap(
        iv: ByteArray,
        cipherText: ByteArray,
        associatedData: ByteArray,
        texts: BiometricPromptTexts,
        callback: (BiometricUnwrapResult) -> Unit,
    ) {
        fun finish(status: BiometricStatus) {
            callback(BiometricUnwrapResult(status))
        }

        val cipher =
            try {
                val key = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
                if (key == null) {
                    finish(BiometricStatus.INVALIDATED)
                    return
                }
                newCipher().apply {
                    init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_BITS, iv))
                }
            } catch (_: KeyPermanentlyInvalidatedException) {
                finish(BiometricStatus.INVALIDATED)
                return
            } catch (_: GeneralSecurityException) {
                finish(BiometricStatus.FAILED)
                return
            } catch (_: ProviderException) {
                finish(BiometricStatus.FAILED)
                return
            }

        authenticate(cipher, texts, { finish(it) }) { authenticated ->
            try {
                authenticated.updateAAD(associatedData)
                // Bu dizi sıfırlanamaz: köprü onu bu fonksiyon döndükten sonra
                // kodluyor. Sınır güvenlik tasarımı belgesinde yazıyor.
                val plainText = authenticated.doFinal(cipherText)
                callback(BiometricUnwrapResult(BiometricStatus.SUCCESS, plainText))
            } catch (_: GeneralSecurityException) {
                finish(BiometricStatus.FAILED)
            } catch (_: IllegalStateException) {
                finish(BiometricStatus.FAILED)
            }
        }
    }

    override fun deleteKey() {
        try {
            keyStore.deleteEntry(KEY_ALIAS)
        } catch (_: GeneralSecurityException) {
            // Anahtar silinemese de yuva olmadan bir işe yaramaz.
        }
    }

    private fun authenticate(
        cipher: Cipher,
        texts: BiometricPromptTexts,
        onError: (BiometricStatus) -> Unit,
        onSuccess: (Cipher) -> Unit,
    ) {
        val promptCallback =
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    result: BiometricPrompt.AuthenticationResult,
                ) {
                    val authenticated = result.cryptoObject?.cipher
                    if (authenticated == null) {
                        onError(BiometricStatus.FAILED)
                    } else {
                        onSuccess(authenticated)
                    }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    onError(statusFor(errorCode))
                }
            }

        val info =
            BiometricPrompt.PromptInfo.Builder()
                .setTitle(texts.title)
                .setNegativeButtonText(texts.negativeButton)
                .setAllowedAuthenticators(BIOMETRIC_STRONG)
                .setConfirmationRequired(false)
                .build()

        try {
            BiometricPrompt(activity, activity.mainExecutor, promptCallback)
                .authenticate(info, BiometricPrompt.CryptoObject(cipher))
        } catch (_: IllegalStateException) {
            onError(BiometricStatus.FAILED)
        }
    }

    private fun statusFor(errorCode: Int): BiometricStatus =
        when (errorCode) {
            BiometricPrompt.ERROR_USER_CANCELED,
            BiometricPrompt.ERROR_NEGATIVE_BUTTON,
            BiometricPrompt.ERROR_CANCELED,
            BiometricPrompt.ERROR_TIMEOUT,
            -> BiometricStatus.CANCELLED
            BiometricPrompt.ERROR_LOCKOUT,
            BiometricPrompt.ERROR_LOCKOUT_PERMANENT,
            -> BiometricStatus.LOCKED_OUT
            else -> BiometricStatus.FAILED
        }

    private fun newCipher(): Cipher = Cipher.getInstance(TRANSFORMATION)

    private fun generateKey(): SecretKey =
        try {
            generateKey(strongBox = true)
        } catch (_: StrongBoxUnavailableException) {
            generateKey(strongBox = false)
        } catch (_: ProviderException) {
            // Bazı cihazlar StrongBox eksikliğini bu hatayla bildiriyor.
            generateKey(strongBox = false)
        }

    private fun generateKey(strongBox: Boolean): SecretKey {
        val spec =
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(KEY_BITS)
                .setUserAuthenticationRequired(true)
                .setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
                .setInvalidatedByBiometricEnrollment(true)
                .setIsStrongBoxBacked(strongBox)
                .build()
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE).run {
            init(spec)
            generateKey()
        }
    }

    private companion object {
        const val KEYSTORE = "AndroidKeyStore"
        const val KEY_ALIAS = "keykey_biometric_v1"
        const val KEY_BITS = 256
        const val TAG_BITS = 128
        const val TRANSFORMATION = "AES/GCM/NoPadding"
    }
}

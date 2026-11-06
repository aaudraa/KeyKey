package io.github.aaudraa.keykey.autofill

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.Presentations
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.widget.RemoteViews
import io.github.aaudraa.keykey.R

/**
 * Android'in otomatik doldurma servisi.
 *
 * Kasaya hiç dokunmaz, kayıt adlarını bilmez. Doldurulacak alan bulursa tek
 * bir öneri döndürür: "KeyKey ile doldur". Öneriye dokunulunca
 * [AutofillActivity] açılır; kasa orada açılır ve kayıt orada seçilir.
 * Ayrıntılar güvenlik tasarımı belgesinin "Otomatik doldurma" bölümünde.
 */
class KeyKeyAutofillService : AutofillService() {
    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback,
    ) {
        val structure = request.fillContexts.lastOrNull()?.structure
        if (structure == null) {
            callback.onSuccess(null)
            return
        }
        val parsed = try {
            StructureParser.parse(structure)
        } catch (error: RuntimeException) {
            // Beklenmedik bir form, servisi düşürmemeli.
            callback.onSuccess(null)
            return
        }
        // KeyKey'in kendi formları (ana parola, kayıt düzenleme) doldurulmaz.
        if (parsed.packageName == packageName || !parsed.form.hasCredentials) {
            callback.onSuccess(null)
            return
        }
        callback.onSuccess(lockedResponse(request.id, parsed))
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        callback.onSuccess()
    }

    private fun lockedResponse(requestId: Int, parsed: ParsedStructure): FillResponse {
        val ids = parsed.credentialIds.toTypedArray()
        // Sistem kimlik doğrulama sonucunu niyete ekleyeceği için değiştirilebilir
        // olmalı. Niyet açıkça bizim ekranımıza yöneliyor.
        val intent = Intent(this, AutofillActivity::class.java)
        val pending = PendingIntent.getActivity(
            this,
            requestId,
            intent,
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_CANCEL_CURRENT,
        )
        val presentation = RemoteViews(packageName, R.layout.autofill_item).apply {
            setTextViewText(R.id.autofill_text, getString(R.string.autofill_fill_with_keykey))
        }
        val builder = FillResponse.Builder()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            builder.setAuthentication(
                ids,
                pending.intentSender,
                Presentations.Builder().setMenuPresentation(presentation).build(),
            )
        } else {
            @Suppress("DEPRECATION")
            builder.setAuthentication(ids, pending.intentSender, presentation)
        }
        return builder.build()
    }
}

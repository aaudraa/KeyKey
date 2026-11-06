package io.github.aaudraa.keykey.autofill

import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.Dataset
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.InlinePresentation
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.widget.RemoteViews
import android.widget.inline.InlinePresentationSpec
import androidx.autofill.inline.UiVersions
import androidx.autofill.inline.v1.InlineSuggestionUi
import io.github.aaudraa.keykey.MainActivity
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
        val inlineSpec = request.inlineSuggestionsRequest?.inlinePresentationSpecs?.firstOrNull()
        callback.onSuccess(lockedResponse(request.id, parsed, inlineSpec))
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        callback.onSuccess()
    }

    private fun lockedResponse(
        requestId: Int,
        parsed: ParsedStructure,
        inlineSpec: InlinePresentationSpec?,
    ): FillResponse {
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
        val label = getString(R.string.autofill_fill_with_keykey)
        val menu = RemoteViews(packageName, R.layout.autofill_item).apply {
            setTextViewText(R.id.autofill_text, label)
        }
        // Klavye öneriyi kendi şeridinde göstermek istiyorsa satır içi görünüm
        // de verilir; verilmezse bazı klavyelerde öneri hiç görünmüyor.
        val inline = inlineSpec?.let { inlinePresentation(it, label) }
        // Kimlik doğrulama tek öneri (Dataset) düzeyindedir: ekran bir Dataset
        // döndürünce sistem onu hemen doldurur. Değerler boştur; servis
        // kaydı bilmez.
        @Suppress("DEPRECATION")
        val dataset = Dataset.Builder(menu).apply {
            if (inline != null) setInlinePresentation(inline)
            for (id in ids) setValue(id, null)
            setAuthentication(pending.intentSender)
        }.build()
        return FillResponse.Builder().addDataset(dataset).build()
    }

    /** Klavye şeridindeki öneri; yalnızca "KeyKey ile doldur" yazar. */
    private fun inlinePresentation(spec: InlinePresentationSpec, label: String): InlinePresentation? {
        if (!UiVersions.getVersions(spec.style).contains(UiVersions.INLINE_UI_VERSION_1)) return null
        // Uzun basınca KeyKey açılır; kayıt bilgisi taşımaz.
        val attribution = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val content = InlineSuggestionUi.newContentBuilder(attribution)
            .setTitle(label)
            .setStartIcon(Icon.createWithResource(this, R.mipmap.ic_launcher))
            .build()
        return InlinePresentation(content.slice, spec, false)
    }
}

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
import android.service.autofill.SaveInfo
import android.service.autofill.SaveRequest
import android.widget.RemoteViews
import android.widget.inline.InlinePresentationSpec
import androidx.autofill.inline.UiVersions
import androidx.autofill.inline.v1.InlineSuggestionUi
import io.github.aaudraa.keykey.AutofillSaveValues
import io.github.aaudraa.keykey.MainActivity
import io.github.aaudraa.keykey.R

/**
 * Android'in otomatik doldurma servisi.
 *
 * Kasaya hiç dokunmaz, kayıt adlarını bilmez. Doldurulacak alan bulursa tek
 * bir öneri döndürür: "KeyKey ile doldur". Öneriye dokunulunca
 * [AutofillActivity] açılır; kasa orada açılır ve kayıt orada seçilir.
 * Form gönderilince sistem kaydetmeyi önerir; kullanıcı kabul ederse
 * [onSaveRequest] değerleri yine kasaya dokunmadan aynı ekrana verir.
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
        val structure = request.fillContexts.lastOrNull()?.structure
        val parsed = try {
            structure?.let { StructureParser.parse(it, readValues = true) }
        } catch (error: RuntimeException) {
            null
        }
        // Yeni parola alanı varsa (kayıt ya da parola değiştirme formu) o
        // kaydedilir, yoksa giriş parolası.
        val password = parsed?.let {
            it.firstValue(FieldKind.NEW_PASSWORD) ?: it.firstValue(FieldKind.PASSWORD)
        }
        if (parsed == null || parsed.packageName == packageName || password == null) {
            callback.onSuccess()
            return
        }
        val save = AutofillSaveValues(
            username = parsed.firstValue(FieldKind.USERNAME).orEmpty(),
            password = password,
        )
        val token = PendingSaves.put(PendingSave(parsed.withoutValues(), save))
        // Ekran servisten açılır. SaveCallback.onSuccess(IntentSender) ile
        // verilen başlatıcıyı sistem formun ekranı üzerinden başlatıyor; giriş
        // ekranı kapanmışsa (çoğu uygulama girişten sonra kapatır) hiçbir şey
        // açılmıyordu (Android 11 emülatöründe görüldü). Sistemin bağladığı
        // doldurma servisi arka plandan ekran açabilir.
        val intent = Intent(this, AutofillActivity::class.java)
            .putExtra(AutofillActivity.EXTRA_SAVE_TOKEN, token)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(intent)
        } catch (error: RuntimeException) {
            PendingSaves.take(token)
            callback.onFailure(null)
            return
        }
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
        return FillResponse.Builder().addDataset(dataset).apply {
            saveInfo(parsed)?.let { setSaveInfo(it) }
        }.build()
    }

    /**
     * Form gönderilince kaydetme önerilsin diye. Parola alanı yoksa öneri
     * yapılmaz. Yeni parola alanları varsa (kayıt ya da parola değiştirme)
     * onlar gerekir; kullanıcı adı ve eski parola isteğe bağlıdır.
     */
    private fun saveInfo(parsed: ParsedStructure): SaveInfo? {
        val newPasswords = parsed.idsOf(FieldKind.NEW_PASSWORD)
        val passwords = parsed.idsOf(FieldKind.PASSWORD)
        val usernames = parsed.idsOf(FieldKind.USERNAME)
        val required = newPasswords.ifEmpty { passwords }
        if (required.isEmpty()) return null
        val optional = (usernames + passwords).filterNot { it in required }.distinct()
        var type = SaveInfo.SAVE_DATA_TYPE_PASSWORD
        if (usernames.isNotEmpty()) type = type or SaveInfo.SAVE_DATA_TYPE_USERNAME
        return SaveInfo.Builder(type, required.toTypedArray()).apply {
            if (optional.isNotEmpty()) setOptionalIds(optional.toTypedArray())
            // Giriş aynı ekranda bitip form gizlendiğinde de öneri gelsin.
            setFlags(SaveInfo.FLAG_SAVE_ON_ALL_VIEWS_INVISIBLE)
        }.build()
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

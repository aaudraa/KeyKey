package io.github.aaudraa.keykey.autofill

import android.app.assist.AssistStructure
import android.view.View
import android.view.autofill.AutofillId

/** Sistemin verdiği formun çözümlenmiş hali. */
class ParsedStructure(
    /** Formu gösteren uygulama. Tarayıcıysa tarayıcının kendisi. */
    val packageName: String,
    /** Sayfanın alan adı; yalnızca güvenilen tarayıcıdan geldiyse anlamlı. */
    val webDomain: String?,
    val webScheme: String?,
    val ids: List<AutofillId>,
    val fields: List<FieldInfo>,
    val form: ParsedForm,
    /**
     * Alanların metin değerleri, [ids] ile aynı sırada. Yalnızca kaydetme
     * isteğinde okunur; doldurma isteğinde boştur.
     */
    val values: List<String?> = emptyList(),
    /**
     * Formda web içeriği var: WebView, HTML alanı ya da alan adı. Bazı
     * WebView sürümleri alan adını bildirmiyor; uyarı yine de verilsin diye.
     */
    val hasWebContent: Boolean = webDomain != null,
) {
    fun idsOf(kind: FieldKind): List<AutofillId> = form.of(kind).map { ids[it] }

    /** Değerler atılmış kopya; bekleyen kaydetme isteğinde başka alan kalmasın. */
    fun withoutValues(): ParsedStructure =
        ParsedStructure(packageName, webDomain, webScheme, ids, fields, form, hasWebContent = hasWebContent)

    /** Bu türdeki ilk dolu alanın değeri. */
    fun firstValue(kind: FieldKind): String? =
        form.of(kind).firstNotNullOfOrNull { index -> values.getOrNull(index)?.takeIf { it.isNotEmpty() } }

    /** Doldurulacak kart alanları, formdaki sırasıyla. PIN alanı girmez. */
    val cardIds: List<AutofillId>
        get() = form.cardIndices.map { ids[it] }

    /** Doldurulacak kullanıcı adı ve parola alanları, sırasıyla. */
    val credentialIds: List<AutofillId>
        get() = (idsOf(FieldKind.USERNAME) + idsOf(FieldKind.PASSWORD) + idsOf(FieldKind.NEW_PASSWORD))
            .distinct()
}

object StructureParser {
    /** [readValues] yalnızca kaydetmede açılır; değerler gereksiz yere okunmaz. */
    fun parse(structure: AssistStructure, readValues: Boolean = false): ParsedStructure {
        val ids = mutableListOf<AutofillId>()
        val values = mutableListOf<String?>()
        val fields = mutableListOf<FieldInfo>()
        var webDomain: String? = null
        var webScheme: String? = null
        var hasWebContent = false

        fun visit(node: AssistStructure.ViewNode, parentVisible: Boolean, parentFrame: Pair<String, String?>?) {
            val visible = parentVisible && node.visibility == View.VISIBLE
            if (node.className == "android.webkit.WebView" || node.htmlInfo != null) hasWebContent = true
            if (webDomain == null && !node.webDomain.isNullOrEmpty()) {
                webDomain = node.webDomain
                webScheme = node.webScheme
            }
            // Gömülü çerçeve kendi alan adını bildirir; alt düğümler onu devralır.
            val frame = node.webDomain?.takeIf { it.isNotEmpty() }?.let { it to node.webScheme } ?: parentFrame
            val id = node.autofillId
            if (id != null && node.autofillType != View.AUTOFILL_TYPE_NONE) {
                val html = node.htmlInfo
                val attributes = html?.attributes
                    ?.associate { (it.first ?: "") to (it.second ?: "") }
                    .orEmpty()
                ids += id
                if (readValues) {
                    val value = node.autofillValue
                    values += if (value != null && value.isText) value.textValue.toString() else null
                }
                fields += FieldInfo(
                    autofillHints = node.autofillHints?.toList().orEmpty(),
                    inputType = node.inputType,
                    autofillType = node.autofillType,
                    htmlTag = html?.tag,
                    htmlAttributes = attributes,
                    idEntry = node.idEntry,
                    hint = node.hint,
                    isVisible = visible,
                    isEnabled = node.isEnabled,
                    options = node.autofillOptions?.map { it.toString() }.orEmpty(),
                    maxLength = maxLengthOf(node, attributes),
                    frameDomain = frame?.first,
                    frameScheme = frame?.second,
                )
            }
            for (i in 0 until node.childCount) visit(node.getChildAt(i), visible, frame)
        }

        for (i in 0 until structure.windowNodeCount) {
            visit(structure.getWindowNodeAt(i).rootViewNode, true, null)
        }
        // Giriş alanları tek çerçeveyle sınırlanır; eşleştirme o çerçevenin
        // alan adıyla yapılır (N9). Çerçeve bilinmiyorsa sayfanınki kullanılır.
        val scoped = CredentialFrame.restrict(FormParser.parse(fields), fields)
        return ParsedStructure(
            packageName = structure.activityComponent.packageName,
            webDomain = scoped.frameDomain ?: webDomain,
            webScheme = if (scoped.frameDomain != null) scoped.frameScheme else webScheme,
            ids = ids,
            fields = fields,
            form = scoped.form,
            values = values,
            hasWebContent = hasWebContent || webDomain != null,
        )
    }

    /**
     * Kutunun uzunluk sınırı. Uygulamalarda `maxTextLength`, Chrome'da
     * `maxlength` niteliği. Bilinmiyorsa 0.
     */
    private fun maxLengthOf(node: AssistStructure.ViewNode, attributes: Map<String, String>): Int {
        val native = node.maxTextLength
        if (native > 0) return native
        val html = attributes.entries.firstOrNull { it.key.equals("maxlength", ignoreCase = true) }
        return html?.value?.trim()?.toIntOrNull()?.takeIf { it > 0 } ?: 0
    }
}

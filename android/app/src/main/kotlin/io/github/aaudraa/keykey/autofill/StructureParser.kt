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
) {
    fun idsOf(kind: FieldKind): List<AutofillId> = form.of(kind).map { ids[it] }

    /** Doldurulacak kullanıcı adı ve parola alanları, sırasıyla. */
    val credentialIds: List<AutofillId>
        get() = (idsOf(FieldKind.USERNAME) + idsOf(FieldKind.PASSWORD) + idsOf(FieldKind.NEW_PASSWORD))
            .distinct()
}

object StructureParser {
    fun parse(structure: AssistStructure): ParsedStructure {
        val ids = mutableListOf<AutofillId>()
        val fields = mutableListOf<FieldInfo>()
        var webDomain: String? = null
        var webScheme: String? = null

        fun visit(node: AssistStructure.ViewNode, parentVisible: Boolean) {
            val visible = parentVisible && node.visibility == View.VISIBLE
            if (webDomain == null && !node.webDomain.isNullOrEmpty()) {
                webDomain = node.webDomain
                webScheme = node.webScheme
            }
            val id = node.autofillId
            if (id != null && node.autofillType != View.AUTOFILL_TYPE_NONE) {
                val html = node.htmlInfo
                ids += id
                fields += FieldInfo(
                    autofillHints = node.autofillHints?.toList().orEmpty(),
                    inputType = node.inputType,
                    autofillType = node.autofillType,
                    htmlTag = html?.tag,
                    htmlAttributes = html?.attributes
                        ?.associate { (it.first ?: "") to (it.second ?: "") }
                        .orEmpty(),
                    idEntry = node.idEntry,
                    hint = node.hint,
                    isVisible = visible,
                    isEnabled = node.isEnabled,
                )
            }
            for (i in 0 until node.childCount) visit(node.getChildAt(i), visible)
        }

        for (i in 0 until structure.windowNodeCount) {
            visit(structure.getWindowNodeAt(i).rootViewNode, true)
        }
        return ParsedStructure(
            packageName = structure.activityComponent.packageName,
            webDomain = webDomain,
            webScheme = webScheme,
            ids = ids,
            fields = fields,
            form = FormParser.parse(fields),
        )
    }
}

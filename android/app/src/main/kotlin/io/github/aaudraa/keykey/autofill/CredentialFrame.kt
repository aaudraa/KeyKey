package io.github.aaudraa.keykey.autofill

import java.util.Locale

/**
 * Giriş alanlarını tek bir çerçeveyle sınırlar.
 *
 * Tarayıcı, sayfaya gömülü başka kökenli çerçevelerin (reklam, yorum) alanlarını
 * da aynı yapıya koyabilir. Eşleştirme sayfanın alan adıyla yapılıp bütün parola
 * alanları doldurulursa banka parolası o çerçevenin sahibine gider. Bu yüzden
 * çerçeve, parolanın yazılacağı alandan seçilir; eşleştirme o çerçevenin alan
 * adıyla yapılır ve başka çerçevelerdeki giriş alanları formdan çıkarılır.
 * Kart alanlarına dokunulmaz: ödeme sağlayıcısının çerçevesinde durmaları
 * olağan, kart da bir siteye bağlı değil.
 */
object CredentialFrame {
    class Result(val form: ParsedForm, val frameDomain: String?, val frameScheme: String?)

    private val credentialKinds = listOf(FieldKind.PASSWORD, FieldKind.NEW_PASSWORD, FieldKind.USERNAME)

    fun restrict(form: ParsedForm, fields: List<FieldInfo>): Result {
        // Sıra önemli: parola hangi çerçevedeyse eşleştirme o siteyle yapılır.
        val anchor = credentialKinds.firstNotNullOfOrNull { kind -> form.of(kind).minOrNull() }
            ?: return Result(form, null, null)
        val frame = fields[anchor].frameDomain?.lowercase(Locale.ROOT)
        val kept = form.fields.mapValues { (kind, indices) ->
            if (kind !in credentialKinds) {
                indices
            } else {
                indices.filter { fields[it].frameDomain?.lowercase(Locale.ROOT) == frame }
            }
        }.filterValues { it.isNotEmpty() }
        return Result(ParsedForm(kept), frame, fields[anchor].frameScheme)
    }
}

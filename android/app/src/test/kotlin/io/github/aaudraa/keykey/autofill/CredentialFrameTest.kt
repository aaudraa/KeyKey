package io.github.aaudraa.keykey.autofill

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** N9: parola yalnızca eşleştirilen alan adının çerçevesine yazılır. */
class CredentialFrameTest {
    private fun input(type: String, name: String, frame: String?) = FieldInfo(
        htmlTag = "input",
        htmlAttributes = mapOf("type" to type, "name" to name),
        frameDomain = frame,
        frameScheme = frame?.let { "https" },
    )

    private fun restrict(vararg fields: FieldInfo): CredentialFrame.Result {
        val list = fields.toList()
        return CredentialFrame.restrict(FormParser.parse(list), list)
    }

    @Test
    fun başkaKökendekiÇerçevedekiParolaAlanıDoldurulmuyor() {
        val result = restrict(
            input("email", "email", "banka.example"),
            input("password", "password", "banka.example"),
            // Sayfaya gömülü reklam çerçevesindeki parola alanı.
            input("password", "password", "reklam.example"),
        )

        assertEquals("banka.example", result.frameDomain)
        assertEquals("https", result.frameScheme)
        assertEquals(listOf(0), result.form.of(FieldKind.USERNAME))
        assertEquals(listOf(1), result.form.of(FieldKind.PASSWORD))
    }

    @Test
    fun girişFormuÇerçevedeyseOÇerçeveninAlanAdıKullanılıyor() {
        val result = restrict(
            input("text", "search", "magaza.example"),
            input("email", "email", "giris.saglayici.example"),
            input("password", "password", "giris.saglayici.example"),
        )

        assertEquals("giris.saglayici.example", result.frameDomain)
        assertEquals(listOf(1), result.form.of(FieldKind.USERNAME))
        assertEquals(listOf(2), result.form.of(FieldKind.PASSWORD))
    }

    @Test
    fun parolanınÇerçevesiKullanıcıAdınınkindenÖnceGeliyor() {
        // Kullanıcı adı sayfada, parola başka bir çerçevede: parola hangi
        // siteye gidecekse eşleştirme o siteyle yapılır, öteki alan atılır.
        val result = restrict(
            input("email", "email", "banka.example"),
            input("password", "password", "reklam.example"),
        )

        assertEquals("reklam.example", result.frameDomain)
        assertEquals(emptyList<Int>(), result.form.of(FieldKind.USERNAME))
        assertEquals(listOf(1), result.form.of(FieldKind.PASSWORD))
    }

    @Test
    fun alanAdıBüyükKüçükHarfeDuyarsız() {
        val result = restrict(
            input("password", "password", "Banka.Example"),
            input("password", "password2", "banka.example"),
        )

        assertEquals(listOf(0, 1), result.form.of(FieldKind.PASSWORD))
    }

    @Test
    fun uygulamaFormuDeğişmiyor() {
        val fields = listOf(
            FieldInfo(autofillHints = listOf("username")),
            FieldInfo(autofillHints = listOf("password")),
        )
        val form = FormParser.parse(fields)
        val result = CredentialFrame.restrict(form, fields)

        assertNull(result.frameDomain)
        assertEquals(form, result.form)
    }

    @Test
    fun kartAlanlarıSüzülmüyor() {
        // Ödeme sağlayıcısının çerçevesindeki kart alanları kart doldurmada
        // kullanılır; kart bir siteye bağlı değil.
        val fields = listOf(
            FieldInfo(autofillHints = listOf("creditCardNumber"), frameDomain = "odeme.example"),
            FieldInfo(autofillHints = listOf("password"), frameDomain = "magaza.example"),
        )
        val form = FormParser.parse(fields)
        val result = CredentialFrame.restrict(form, fields)

        assertEquals(form.cardIndices, result.form.cardIndices)
    }
}

package io.github.aaudraa.keykey

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WebLinksTest {
    @Test
    fun `http ve https adresli sayfalar açılabilir`() {
        assertTrue(WebLinks.isWebPage("https", "bank.example"))
        assertTrue(WebLinks.isWebPage("http", "a.example"))
        assertTrue(WebLinks.isWebPage("HTTPS", "b.example"))
    }

    @Test
    fun `başka şemalar ve adressiz bağlantılar açılmaz`() {
        for (scheme in listOf("javascript", "intent", "file", "content", "androidapp", "mailto", null)) {
            assertFalse(scheme.toString(), WebLinks.isWebPage(scheme, "x.example"))
        }
        assertFalse(WebLinks.isWebPage("https", null))
        assertFalse(WebLinks.isWebPage("https", ""))
    }
}

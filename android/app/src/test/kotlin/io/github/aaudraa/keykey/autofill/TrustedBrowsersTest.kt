package io.github.aaudraa.keykey.autofill

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TrustedBrowsersTest {
    @Test
    fun chromeYayınİmzasıylaListede() {
        assertEquals(
            setOf("f0fd6c5b410f25cb25c3b53346c8972fae30f8ee7411df910480ad6b2d60db83"),
            TrustedBrowsers.allowedDigests("com.android.chrome"),
        )
    }

    @Test
    fun testSürümüİmzalarıAlınmıyor() {
        // Chrome'un userdebug imzası kaynakta var, listede olmamalı.
        assertFalse(
            TrustedBrowsers.allowedDigests("com.android.chrome")
                .contains("1975b2f17177bc89a5dff31f9e64a6cae281a53dc1d1d59b1d147fe1c82afa00"),
        )
        // Yalnızca test imzası olan paket hiç yok.
        assertTrue(TrustedBrowsers.allowedDigests("com.google.android.apps.chrome").isEmpty())
    }

    @Test
    fun tarayıcıOlmayanlarListedeYok() {
        assertTrue(TrustedBrowsers.allowedDigests("com.google.android.gms").isEmpty())
        assertTrue(TrustedBrowsers.allowedDigests("com.fido.fido2client").isEmpty())
        assertTrue(TrustedBrowsers.allowedDigests("com.oplus.credential").isEmpty())
        assertTrue(TrustedBrowsers.allowedDigests("io.github.aaudraa.ornekgiris").isEmpty())
    }

    @Test
    fun yaygınTarayıcılarListede() {
        for (name in listOf(
            "org.mozilla.firefox",
            "com.sec.android.app.sbrowser",
            "com.microsoft.emmx",
            "com.brave.browser",
            "com.opera.browser",
            "com.duckduckgo.mobile.android",
        )) {
            assertTrue(name, TrustedBrowsers.allowedDigests(name).isNotEmpty())
        }
    }

    @Test
    fun özetlerKüçükHarfVe64Karakter() {
        val pattern = Regex("^[0-9a-f]{64}$")
        for ((name, digests) in TRUSTED_BROWSERS) {
            assertTrue(name, digests.isNotEmpty() && digests.all { pattern.matches(it) })
        }
    }
}

package io.github.aaudraa.keykey.autofill

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** K10: çok imzacılı uygulamada imzacı kümesi bütün olarak karşılaştırılır. */
class SigningCertsTest {
    private val a = "a".repeat(64)
    private val b = "b".repeat(64)
    private val c = "c".repeat(64)

    @Test
    fun çokİmzacılıdaAynıKümeEşleşiyor() {
        // hasSigningCertificate yalnızca tek imzacılı uygulamada doğru döner;
        // çok imzacılıda sistem sorulmaz.
        assertTrue(
            SigningCerts.matches(listOf(a, b), multipleSigners = true, currentSigners = listOf(b, a)) { false },
        )
    }

    @Test
    fun çokİmzacılıdaEksikYaDaFazlaİmzacıEşleşmiyor() {
        assertFalse(SigningCerts.matches(listOf(a, b), true, listOf(a)) { true })
        assertFalse(SigningCerts.matches(listOf(a), true, listOf(a, b)) { true })
        assertFalse(SigningCerts.matches(listOf(a, b), true, listOf(a, c)) { true })
    }

    @Test
    fun tekİmzacılıdaSistemeSoruluyor() {
        // Android, imza anahtarını döndürmüş uygulamalarda eski sertifikayı da
        // kabul eder; bu yüzden tek imzacıda sistem karar verir.
        assertTrue(SigningCerts.matches(listOf(a), false, listOf(b)) { it == a })
        assertFalse(SigningCerts.matches(listOf(a), false, listOf(a)) { false })
    }

    @Test
    fun boşKayıtHiçEşleşmiyor() {
        assertFalse(SigningCerts.matches(emptyList(), true, emptyList()) { true })
        assertFalse(SigningCerts.matches(emptyList(), false, listOf(a)) { true })
    }
}

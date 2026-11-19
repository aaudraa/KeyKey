package io.github.aaudraa.keykey.autofill

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FieldClassifierTest {
    // android.text.InputType değerleri.
    private val text = 0x1
    private val textPassword = 0x1 or 0x80
    private val textVisiblePassword = 0x1 or 0x90
    private val textWebPassword = 0x1 or 0xe0
    private val textEmail = 0x1 or 0x20
    private val numberPassword = 0x2 or 0x10
    private val number = 0x2

    private fun kind(field: FieldInfo) = FieldClassifier.classify(field)

    private fun html(vararg attributes: Pair<String, String>) =
        FieldInfo(htmlTag = "input", htmlAttributes = attributes.toMap())

    @Test
    fun geliştiriciIpuçlarınaGüveniliyor() {
        assertEquals(FieldKind.USERNAME, kind(FieldInfo(autofillHints = listOf("username"))))
        assertEquals(FieldKind.USERNAME, kind(FieldInfo(autofillHints = listOf("emailAddress"))))
        assertEquals(FieldKind.PASSWORD, kind(FieldInfo(autofillHints = listOf("password"))))
        assertEquals(FieldKind.NEW_PASSWORD, kind(FieldInfo(autofillHints = listOf("newPassword"))))
        assertEquals(FieldKind.OTP, kind(FieldInfo(autofillHints = listOf("smsOTPCode"))))
        assertEquals(FieldKind.OTP, kind(FieldInfo(autofillHints = listOf("2faAppOTPCode"))))
    }

    @Test
    fun sisteminEklediğiParolaIpucuTanınıyor() {
        // Android 14+ parola alanlarına "passwordAuto" ekliyor; cihazda bulundu.
        assertEquals(
            FieldKind.PASSWORD,
            kind(FieldInfo(autofillHints = listOf("passwordAuto"), inputType = textPassword, hint = "Parola")),
        )
    }

    @Test
    fun başkaBirIpucuVarsaTahminEdilmiyor() {
        // Adres alanının kimliğinde "user" geçse bile doldurulmaz.
        assertNull(kind(FieldInfo(autofillHints = listOf("postalAddress"), idEntry = "user_address")))
        assertNull(kind(FieldInfo(autofillHints = listOf("creditCardNumber"), inputType = textPassword)))
    }

    @Test
    fun girişTüründenParolaVeEPosta() {
        assertEquals(FieldKind.PASSWORD, kind(FieldInfo(inputType = textPassword)))
        assertEquals(FieldKind.PASSWORD, kind(FieldInfo(inputType = textWebPassword)))
        assertEquals(FieldKind.PASSWORD, kind(FieldInfo(inputType = textVisiblePassword)))
        assertEquals(FieldKind.PASSWORD, kind(FieldInfo(inputType = numberPassword)))
        assertEquals(FieldKind.USERNAME, kind(FieldInfo(inputType = textEmail)))
        assertNull(kind(FieldInfo(inputType = text)))
        assertNull(kind(FieldInfo(inputType = number)))
    }

    @Test
    fun yeniParolaSözcüklerdenAyrılıyor() {
        assertEquals(FieldKind.NEW_PASSWORD, kind(FieldInfo(inputType = textPassword, idEntry = "confirm_password")))
        assertEquals(FieldKind.NEW_PASSWORD, kind(FieldInfo(inputType = textPassword, hint = "Yeni şifre")))
        assertEquals(FieldKind.NEW_PASSWORD, kind(FieldInfo(inputType = textPassword, hint = "Parola tekrar")))
        assertEquals(FieldKind.PASSWORD, kind(FieldInfo(inputType = textPassword, idEntry = "password")))
    }

    @Test
    fun türkçeVeIngilizceAlanAdları() {
        assertEquals(FieldKind.USERNAME, kind(FieldInfo(inputType = text, hint = "Kullanıcı adı")))
        assertEquals(FieldKind.USERNAME, kind(FieldInfo(inputType = text, hint = "KULLANICI ADI")))
        assertEquals(FieldKind.USERNAME, kind(FieldInfo(inputType = text, hint = "E-posta")))
        assertEquals(FieldKind.USERNAME, kind(FieldInfo(inputType = text, hint = "T.C. Kimlik No")))
        assertEquals(FieldKind.USERNAME, kind(FieldInfo(inputType = text, idEntry = "et_user_name")))
        assertEquals(FieldKind.USERNAME, kind(FieldInfo(inputType = text, idEntry = "loginEmail")))
        assertEquals(FieldKind.PASSWORD, kind(FieldInfo(inputType = text, hint = "Şifre")))
        assertEquals(FieldKind.PASSWORD, kind(FieldInfo(inputType = text, hint = "ŞİFRE")))
        assertEquals(FieldKind.PASSWORD, kind(FieldInfo(inputType = text, idEntry = "user_password")))
        assertEquals(FieldKind.OTP, kind(FieldInfo(inputType = number, hint = "Doğrulama kodu")))
        assertEquals(FieldKind.OTP, kind(FieldInfo(inputType = number, idEntry = "otp_input")))
    }

    @Test
    fun aramaVeCaptchaDoldurulmuyor() {
        assertNull(kind(FieldInfo(inputType = text, hint = "Search users")))
        assertNull(kind(FieldInfo(inputType = text, idEntry = "captcha_login")))
    }

    @Test
    fun htmlNitelikleri() {
        assertEquals(FieldKind.PASSWORD, kind(html("type" to "password")))
        assertEquals(FieldKind.NEW_PASSWORD, kind(html("type" to "password", "autocomplete" to "new-password")))
        assertEquals(FieldKind.PASSWORD, kind(html("type" to "password", "autocomplete" to "current-password")))
        assertEquals(FieldKind.USERNAME, kind(html("type" to "email")))
        assertEquals(FieldKind.USERNAME, kind(html("type" to "text", "autocomplete" to "username")))
        assertEquals(FieldKind.USERNAME, kind(html("type" to "text", "name" to "login")))
        assertEquals(FieldKind.OTP, kind(html("type" to "text", "autocomplete" to "one-time-code")))
        assertEquals(FieldKind.NEW_PASSWORD, kind(html("type" to "password", "name" to "password_confirm")))
    }

    @Test
    fun doldurulmayanHtmlAlanları() {
        assertNull(kind(html("type" to "hidden", "name" to "password")))
        assertNull(kind(html("type" to "submit", "name" to "login")))
        assertNull(kind(html("type" to "checkbox", "name" to "remember_user")))
        assertNull(kind(FieldInfo(htmlTag = "select", htmlAttributes = mapOf("name" to "user"))))
    }

    @Test
    fun görünmeyenKapalıVeMetinOlmayanAlanlar() {
        assertNull(kind(FieldInfo(inputType = textPassword, isVisible = false)))
        assertNull(kind(FieldInfo(inputType = textPassword, isEnabled = false)))
        assertNull(kind(FieldInfo(inputType = textPassword, autofillType = 2)))
    }

    @Test
    fun formdaKullanıcıAdıParoladanÖnceTahminEdiliyor() {
        val form = FormParser.parse(
            listOf(
                FieldInfo(inputType = text, idEntry = "field1"),
                FieldInfo(inputType = text, idEntry = "field2"),
                FieldInfo(inputType = textPassword),
            ),
        )
        assertEquals(listOf(1), form.of(FieldKind.USERNAME))
        assertEquals(listOf(2), form.of(FieldKind.PASSWORD))
        assertTrue(form.hasCredentials)
    }

    @Test
    fun açıkKullanıcıAdıVarsaTahminYapılmıyor() {
        val form = FormParser.parse(
            listOf(
                FieldInfo(inputType = textEmail),
                FieldInfo(inputType = text, idEntry = "field2"),
                FieldInfo(inputType = textPassword),
            ),
        )
        assertEquals(listOf(0), form.of(FieldKind.USERNAME))
    }

    @Test
    fun kayıtFormundaYeniParolalar() {
        val form = FormParser.parse(
            listOf(
                html("type" to "email"),
                html("type" to "password", "autocomplete" to "new-password"),
                html("type" to "password", "name" to "confirm"),
            ),
        )
        assertEquals(listOf(0), form.of(FieldKind.USERNAME))
        assertEquals(listOf(1, 2), form.of(FieldKind.NEW_PASSWORD))
    }

    @Test
    fun yalnızcaKodAlanıOlanFormDoldurulmuyor() {
        val form = FormParser.parse(listOf(FieldInfo(inputType = number, hint = "SMS kodu")))
        assertEquals(listOf(0), form.of(FieldKind.OTP))
        assertFalse(form.hasCredentials)
    }

    @Test
    fun kartNumarasıylaGirişFormuGirişKalır() {
        val form = FormParser.parse(
            listOf(
                FieldInfo(inputType = text, hint = "Kart numarası"),
                FieldInfo(inputType = numberPassword, hint = "Şifre"),
            ),
        )
        assertFalse(form.hasCard)
        assertEquals(listOf(0), form.of(FieldKind.USERNAME))
        assertEquals(listOf(1), form.of(FieldKind.PASSWORD))
    }

    @Test
    fun cvvliFormÖdemeFormu() {
        val form = FormParser.parse(
            listOf(
                FieldInfo(inputType = text, hint = "Kart numarası"),
                FieldInfo(inputType = text, hint = "AA/YY"),
                FieldInfo(inputType = numberPassword, hint = "CVV"),
            ),
        )
        assertTrue(form.hasCard)
        assertFalse(form.hasCredentials)
        assertEquals(listOf(0), form.of(FieldKind.CARD_NUMBER))
        assertEquals(listOf(1), form.of(FieldKind.CARD_EXPIRY))
        assertEquals(listOf(2), form.of(FieldKind.CARD_SECURITY_CODE))
        assertEquals(emptyList<Int>(), form.of(FieldKind.PASSWORD))
    }

    @Test
    fun sisteminParolaIpucuOlanCvvParolaSayılmıyor() {
        // Android 17 emülatöründeki ipucusuz form: sistem CVV'ye "passwordAuto" ekledi.
        val form = FormParser.parse(
            listOf(
                FieldInfo(inputType = number, hint = "Kart numarası"),
                FieldInfo(inputType = text, hint = "Son kullanma (AA/YY)"),
                FieldInfo(autofillHints = listOf("passwordAuto"), inputType = numberPassword, hint = "CVV"),
            ),
        )
        assertEquals(listOf(2), form.of(FieldKind.CARD_SECURITY_CODE))
        assertFalse(form.hasCredentials)
    }

    @Test
    fun zayıfSözcüklerİkiGruptaÖdemeFormuYapar() {
        val form = FormParser.parse(
            listOf(
                FieldInfo(inputType = text, hint = "Kart numarası"),
                FieldInfo(inputType = numberPassword, hint = "Güvenlik kodu"),
            ),
        )
        assertTrue(form.hasCard)
        assertFalse(form.hasCredentials)
        assertEquals(listOf(1), form.of(FieldKind.CARD_SECURITY_CODE))
    }

    @Test
    fun yalnızCvvKutusu() {
        val form = FormParser.parse(listOf(FieldInfo(inputType = numberPassword, idEntry = "cvv")))
        assertTrue(form.hasCard)
        assertFalse(form.hasCredentials)
    }

    @Test
    fun karışıkFormdaGirişVeKartAyrı() {
        val form = FormParser.parse(
            listOf(
                FieldInfo(inputType = textEmail),
                FieldInfo(inputType = textPassword, idEntry = "password"),
                FieldInfo(autofillHints = listOf("creditCardNumber"), inputType = number),
                html("type" to "password", "autocomplete" to "cc-csc"),
            ),
        )
        assertEquals(listOf(0), form.of(FieldKind.USERNAME))
        assertEquals(listOf(1), form.of(FieldKind.PASSWORD))
        assertEquals(listOf(2), form.of(FieldKind.CARD_NUMBER))
        assertEquals(listOf(3), form.of(FieldKind.CARD_SECURITY_CODE))
        assertTrue(form.hasCredentials)
        assertTrue(form.hasCard)
        assertEquals(listOf(2, 3), form.cardIndices)
    }

    @Test
    fun ödemeFormundaKartAlanıKullanıcıAdıTahminiOlmuyor() {
        // Kart sahibi kutusu düz metin; parola kutusundan önce gelse de
        // kullanıcı adı sayılmamalı.
        val form = FormParser.parse(
            listOf(
                FieldInfo(inputType = text, hint = "Kart sahibi"),
                FieldInfo(autofillHints = listOf("creditCardNumber"), inputType = text),
                FieldInfo(inputType = textPassword),
            ),
        )
        assertEquals(listOf(0), form.of(FieldKind.CARD_HOLDER))
        assertEquals(emptyList<Int>(), form.of(FieldKind.USERNAME))
    }

    @Test
    fun ayVeYılSözcükleriTekBaşınaÖdemeFormuYapmaz() {
        val form = FormParser.parse(
            listOf(
                FieldInfo(inputType = text, hint = "Ay"),
                FieldInfo(inputType = text, hint = "Yıl"),
                FieldInfo(inputType = textPassword),
            ),
        )
        assertFalse(form.hasCard)
        assertEquals(listOf(2), form.of(FieldKind.PASSWORD))
    }

    @Test
    fun kartSahibiTekBaşınaÖdemeFormuYapmaz() {
        val form = FormParser.parse(
            listOf(
                FieldInfo(inputType = text, hint = "Kart sahibi"),
                FieldInfo(inputType = textPassword),
            ),
        )
        assertFalse(form.hasCard)
        assertEquals(listOf(0), form.of(FieldKind.USERNAME))
    }

    @Test
    fun ödemeFormundaGenelAyVeYılKutularıSonKullanma() {
        val form = FormParser.parse(
            listOf(
                FieldInfo(autofillHints = listOf("creditCardNumber"), inputType = text),
                FieldInfo(idEntry = "month", autofillType = 3),
                FieldInfo(idEntry = "year", autofillType = 3),
            ),
        )
        assertEquals(listOf(1), form.of(FieldKind.CARD_EXP_MONTH))
        assertEquals(listOf(2), form.of(FieldKind.CARD_EXP_YEAR))
    }

    @Test
    fun boşForm() {
        assertFalse(FormParser.parse(emptyList()).hasCredentials)
        assertFalse(FormParser.parse(listOf(FieldInfo(inputType = text, hint = "Ad soyad"))).hasCredentials)
    }
}

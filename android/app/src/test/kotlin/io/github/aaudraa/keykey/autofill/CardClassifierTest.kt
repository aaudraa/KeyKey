package io.github.aaudraa.keykey.autofill

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CardClassifierTest {
    // android.text.InputType ve View.AUTOFILL_TYPE_* değerleri.
    private val text = 0x1
    private val numberPassword = 0x2 or 0x10
    private val textPassword = 0x1 or 0x80
    private val listType = 3
    private val dateType = 4

    private fun guess(field: FieldInfo) = CardClassifier.classify(field)

    private fun strong(kind: FieldKind) = CardGuess(kind, strong = true)

    private fun weak(kind: FieldKind) = CardGuess(kind, strong = false)

    private fun html(vararg attributes: Pair<String, String>) =
        FieldInfo(htmlTag = "input", htmlAttributes = attributes.toMap())

    @Test
    fun androidIpuçlarıGüçlü() {
        assertEquals(strong(FieldKind.CARD_NUMBER), guess(FieldInfo(autofillHints = listOf("creditCardNumber"))))
        assertEquals(
            strong(FieldKind.CARD_SECURITY_CODE),
            guess(FieldInfo(autofillHints = listOf("creditCardSecurityCode"), inputType = numberPassword)),
        )
        assertEquals(strong(FieldKind.CARD_EXPIRY), guess(FieldInfo(autofillHints = listOf("creditCardExpirationDate"))))
        assertEquals(
            strong(FieldKind.CARD_EXP_MONTH),
            guess(FieldInfo(autofillHints = listOf("creditCardExpirationMonth"))),
        )
        assertEquals(strong(FieldKind.CARD_EXP_YEAR), guess(FieldInfo(autofillHints = listOf("creditCardExpirationYear"))))
        assertNull(guess(FieldInfo(autofillHints = listOf("creditCardExpirationDay"))))
    }

    @Test
    fun başkaIpucuKartSayılmıyor() {
        assertNull(guess(FieldInfo(autofillHints = listOf("password"), inputType = textPassword)))
        assertNull(guess(FieldInfo(autofillHints = listOf("postalAddress"), hint = "Kart sahibi adresi")))
    }

    @Test
    fun htmlAutocompleteGüçlü() {
        assertEquals(strong(FieldKind.CARD_NUMBER), guess(html("autocomplete" to "cc-number")))
        assertEquals(strong(FieldKind.CARD_NUMBER), guess(html("autocomplete" to "billing cc-number")))
        assertEquals(strong(FieldKind.CARD_HOLDER), guess(html("autocomplete" to "cc-name")))
        assertEquals(strong(FieldKind.CARD_HOLDER_GIVEN), guess(html("autocomplete" to "cc-given-name")))
        assertEquals(strong(FieldKind.CARD_HOLDER_FAMILY), guess(html("autocomplete" to "cc-family-name")))
        assertEquals(strong(FieldKind.CARD_EXPIRY), guess(html("autocomplete" to "cc-exp")))
        assertEquals(strong(FieldKind.CARD_EXP_MONTH), guess(html("autocomplete" to "cc-exp-month")))
        assertEquals(strong(FieldKind.CARD_EXP_YEAR), guess(html("autocomplete" to "cc-exp-year")))
        assertEquals(strong(FieldKind.CARD_SECURITY_CODE), guess(html("type" to "password", "autocomplete" to "cc-csc")))
        // Chrome autocomplete değerini ipucu olarak da gönderiyor.
        assertEquals(strong(FieldKind.CARD_NUMBER), guess(FieldInfo(autofillHints = listOf("cc-number"))))
    }

    @Test
    fun chromeTahminiGüçlü() {
        assertEquals(
            strong(FieldKind.CARD_SECURITY_CODE),
            guess(html("type" to "password", "computed-autofill-hints" to "CREDIT_CARD_VERIFICATION_CODE")),
        )
        assertEquals(
            strong(FieldKind.CARD_NUMBER),
            guess(
                html(
                    "computed-autofill-hints" to "UNKNOWN_TYPE",
                    "crowdsourcing-autofill-hints" to "CREDIT_CARD_NUMBER",
                ),
            ),
        )
        assertEquals(
            strong(FieldKind.CARD_EXP_YEAR),
            guess(
                html(
                    "computed-autofill-hints" to "",
                    "crowdsourcing-autofill-hints" to "NO_SERVER_DATA",
                    "ua-autofill-hints" to "CREDIT_CARD_EXP_4_DIGIT_YEAR",
                ),
            ),
        )
        assertEquals(strong(FieldKind.CARD_EXP_YEAR), guess(html("ua-autofill-hints" to "CREDIT_CARD_EXP_2_DIGIT_YEAR")))
        assertEquals(strong(FieldKind.CARD_EXP_MONTH), guess(html("ua-autofill-hints" to "CREDIT_CARD_EXP_MONTH")))
        assertEquals(
            strong(FieldKind.CARD_EXPIRY),
            guess(html("computed-autofill-hints" to "CREDIT_CARD_EXP_DATE_2_DIGIT_YEAR")),
        )
        assertEquals(
            strong(FieldKind.CARD_EXPIRY),
            guess(html("computed-autofill-hints" to "CREDIT_CARD_EXP_DATE_4_DIGIT_YEAR")),
        )
        assertEquals(strong(FieldKind.CARD_HOLDER), guess(html("computed-autofill-hints" to "CREDIT_CARD_NAME_FULL")))
        assertEquals(strong(FieldKind.CARD_HOLDER_GIVEN), guess(html("computed-autofill-hints" to "CREDIT_CARD_NAME_FIRST")))
        assertEquals(strong(FieldKind.CARD_HOLDER_FAMILY), guess(html("computed-autofill-hints" to "CREDIT_CARD_NAME_LAST")))
        assertEquals(
            strong(FieldKind.CARD_SECURITY_CODE),
            guess(html("computed-autofill-hints" to "CREDIT_CARD_STANDALONE_VERIFICATION_CODE")),
        )
        // Chrome'un kart dışı tahmini kart sayılmaz.
        assertNull(guess(html("type" to "password", "computed-autofill-hints" to "PASSWORD")))
    }

    @Test
    fun sisteminParolaIpucuGeliştiriciIpucuSayılmıyor() {
        // Android 14+ ipucu verilmemiş gizli kutulara "passwordAuto" ekliyor;
        // Android 17 emülatöründe ipucusuz formdaki CVV böyle parola sanıldı.
        assertEquals(
            strong(FieldKind.CARD_SECURITY_CODE),
            guess(FieldInfo(autofillHints = listOf("passwordAuto"), inputType = numberPassword, hint = "CVV")),
        )
        assertEquals(
            weak(FieldKind.CARD_SECURITY_CODE),
            guess(FieldInfo(autofillHints = listOf("passwordAuto"), inputType = numberPassword, hint = "Güvenlik kodu")),
        )
        assertNull(guess(FieldInfo(autofillHints = listOf("passwordAuto"), inputType = textPassword, hint = "Parola")))
    }

    @Test
    fun güvenlikKoduAdlarıGüçlü() {
        assertEquals(
            strong(FieldKind.CARD_SECURITY_CODE),
            guess(FieldInfo(inputType = numberPassword, idEntry = "et_cvv")),
        )
        assertEquals(strong(FieldKind.CARD_SECURITY_CODE), guess(FieldInfo(inputType = text, hint = "CVC2")))
        assertEquals(strong(FieldKind.CARD_SECURITY_CODE), guess(html("type" to "tel", "label" to "CSC")))
        assertEquals(strong(FieldKind.CARD_SECURITY_CODE), guess(html("name" to "cardCvv")))
    }

    @Test
    fun sözcüklerZayıf() {
        assertEquals(weak(FieldKind.CARD_NUMBER), guess(FieldInfo(inputType = text, hint = "Kart numarası")))
        assertEquals(weak(FieldKind.CARD_NUMBER), guess(FieldInfo(inputType = text, hint = "KART NUMARASI")))
        assertEquals(weak(FieldKind.CARD_NUMBER), guess(FieldInfo(inputType = text, idEntry = "card_number")))
        assertEquals(weak(FieldKind.CARD_NUMBER), guess(html("name" to "cardNumber")))
        assertEquals(weak(FieldKind.CARD_EXPIRY), guess(FieldInfo(inputType = text, hint = "Son kullanma (AA/YY)")))
        assertEquals(weak(FieldKind.CARD_EXPIRY), guess(FieldInfo(inputType = text, hint = "MM/YY")))
        assertEquals(weak(FieldKind.CARD_EXPIRY), guess(html("placeholder" to "Expiry date")))
        assertEquals(weak(FieldKind.CARD_HOLDER), guess(FieldInfo(inputType = text, hint = "Kart sahibi")))
        assertEquals(weak(FieldKind.CARD_HOLDER), guess(FieldInfo(inputType = text, hint = "Name on card")))
        assertEquals(weak(FieldKind.CARD_SECURITY_CODE), guess(FieldInfo(inputType = numberPassword, hint = "Güvenlik kodu")))
        assertEquals(weak(FieldKind.CARD_EXP_MONTH), guess(FieldInfo(idEntry = "spinner_month", autofillType = listType)))
        assertEquals(weak(FieldKind.CARD_EXP_MONTH), guess(FieldInfo(inputType = text, hint = "Son kullanma ayı")))
        assertEquals(weak(FieldKind.CARD_EXP_YEAR), guess(FieldInfo(inputType = text, hint = "Yıl")))
        assertEquals(weak(FieldKind.CARD_EXP_YEAR), guess(FieldInfo(inputType = text, hint = "Expiration year")))
        assertEquals(weak(FieldKind.CARD_EXP_MONTH), guess(FieldInfo(inputType = text, hint = "Ay")))
    }

    @Test
    fun kartTürüAdıKartSahibiniNumaraYapmıyor() {
        // Gözden geçirme: "kredi kartı" gibi genel sözler sahibi kutusunu
        // numara yapıyor, numara da sahibi kutusuna yazılıyordu.
        assertEquals(weak(FieldKind.CARD_HOLDER), guess(FieldInfo(inputType = text, hint = "Kredi kartı sahibi")))
        assertEquals(weak(FieldKind.CARD_HOLDER), guess(FieldInfo(inputType = text, hint = "Banka kartı sahibinin adı")))
        assertEquals(weak(FieldKind.CARD_HOLDER), guess(FieldInfo(inputType = text, hint = "Name on credit card")))
        assertEquals(weak(FieldKind.CARD_HOLDER), guess(FieldInfo(inputType = text, hint = "Kartın üzerindeki isim")))
        assertEquals(weak(FieldKind.CARD_NUMBER), guess(FieldInfo(inputType = text, hint = "Kredi kartı numarası")))
        assertEquals(weak(FieldKind.CARD_NUMBER), guess(FieldInfo(inputType = text, hint = "Credit card number")))
        // Kart türünün adı tek başına numara demek değil (kartın adı, limit, borç).
        assertNull(guess(FieldInfo(inputType = text, hint = "Kredi kartı")))
        assertNull(guess(FieldInfo(inputType = text, hint = "Kredi kartı limiti")))
        assertNull(guess(FieldInfo(inputType = text, hint = "Debit card")))
    }

    @Test
    fun hediyeKartıTaksitVeSmsKoduKartSayılmıyor() {
        assertNull(guess(FieldInfo(inputType = text, hint = "Gift card number")))
        assertNull(guess(FieldInfo(inputType = text, hint = "Hediye kartı numarası")))
        assertNull(guess(FieldInfo(inputType = text, hint = "Üye kartı numarası")))
        assertNull(guess(FieldInfo(inputType = text, hint = "Loyalty card number")))
        // Taksit listesi "ay" diyebilir; Aralık kartı 12 taksit seçmemeli.
        assertNull(guess(FieldInfo(idEntry = "taksit_ay", autofillType = listType)))
        assertNull(guess(FieldInfo(hint = "Installment months", autofillType = listType)))
        // Türkçede "güvenlik kodu" çoğu zaman captcha ya da SMS kodudur.
        assertNull(guess(FieldInfo(inputType = text, hint = "SMS ile gönderilen güvenlik kodu")))
        assertNull(guess(FieldInfo(inputType = text, hint = "Resimdeki güvenlik kodu")))
    }

    @Test
    fun benzerSözcüklerKartSayılmıyor() {
        assertNull(guess(FieldInfo(inputType = text, hint = "Doğum yılı")))
        assertNull(guess(FieldInfo(inputType = text, hint = "Birth month")))
        assertNull(guess(FieldInfo(inputType = text, hint = "Ayrıntılar")))
        assertNull(guess(FieldInfo(inputType = text, hint = "Kullanıcı adı")))
        assertNull(guess(FieldInfo(inputType = textPassword, hint = "Şifre")))
        assertNull(guess(FieldInfo(inputType = text, hint = "Yıllık gelir")))
    }

    @Test
    fun metinOlmayanAlanlar() {
        // Numara ve güvenlik kodu yalnızca metin kutusu olabilir.
        assertNull(guess(FieldInfo(autofillHints = listOf("creditCardNumber"), autofillType = listType)))
        assertNull(guess(FieldInfo(autofillHints = listOf("creditCardSecurityCode"), autofillType = dateType)))
        // Son kullanma liste ya da tarih olabilir.
        assertEquals(
            strong(FieldKind.CARD_EXP_MONTH),
            guess(html("type" to "select-one", "autocomplete" to "cc-exp-month").copy(autofillType = listType)),
        )
        assertEquals(
            strong(FieldKind.CARD_EXPIRY),
            guess(FieldInfo(autofillHints = listOf("creditCardExpirationDate"), autofillType = dateType)),
        )
        // Açma kapama düğmesi hiçbir şey olamaz.
        assertNull(guess(FieldInfo(autofillHints = listOf("creditCardExpirationMonth"), autofillType = 2)))
    }

    @Test
    fun görünmeyenVeKapalıAlanlar() {
        assertNull(guess(FieldInfo(autofillHints = listOf("creditCardNumber"), isVisible = false)))
        assertNull(guess(FieldInfo(autofillHints = listOf("creditCardNumber"), isEnabled = false)))
        assertNull(guess(html("type" to "hidden", "autocomplete" to "cc-number")))
    }
}

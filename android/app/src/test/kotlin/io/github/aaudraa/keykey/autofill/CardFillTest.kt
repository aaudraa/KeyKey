package io.github.aaudraa.keykey.autofill

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CardFillTest {
    private val listType = 3
    private val dateType = 4

    private val card = CardValues(
        number = "4111111111111111",
        cardholder = "DENEME KİŞİ YILMAZ",
        expMonth = 12,
        expYear = 2028,
        securityCode = "123",
    )

    /** Her alanın türü verilir; sınıflandırıcıdan bağımsız sınanır. */
    private fun fill(vararg fields: Pair<FieldKind, FieldInfo>, values: CardValues = card): Map<Int, FillValue> {
        val kinds = mutableMapOf<FieldKind, MutableList<Int>>()
        fields.forEachIndexed { index, (kind, _) -> kinds.getOrPut(kind) { mutableListOf() }.add(index) }
        return CardFill.values(fields.map { it.second }, ParsedForm(kinds), values)
    }

    private fun one(kind: FieldKind, field: FieldInfo = FieldInfo(), values: CardValues = card): FillValue? =
        fill(kind to field, values = values)[0]

    private fun text(value: String) = FillValue.Text(value)

    @Test
    fun numaraYalnızRakam() {
        assertEquals(text("4111111111111111"), one(FieldKind.CARD_NUMBER))
    }

    @Test
    fun bölünmüşNumara() {
        val box = FieldInfo(maxLength = 4)
        val split = fill(
            FieldKind.CARD_NUMBER to box,
            FieldKind.CARD_NUMBER to box,
            FieldKind.CARD_NUMBER to box,
            FieldKind.CARD_NUMBER to box,
        )
        assertEquals(listOf("4111", "1111", "1111", "1111").map(::text), (0..3).map { split[it] })

        val unknown = fill(FieldKind.CARD_NUMBER to box, FieldKind.CARD_NUMBER to FieldInfo())
        assertEquals(text("4111111111111111"), unknown[0])
        assertFalse(unknown.containsKey(1))
    }

    @Test
    fun adVeSoyad() {
        val split = fill(
            FieldKind.CARD_HOLDER_GIVEN to FieldInfo(),
            FieldKind.CARD_HOLDER_FAMILY to FieldInfo(),
        )
        assertEquals(text("DENEME KİŞİ"), split[0])
        assertEquals(text("YILMAZ"), split[1])
        assertEquals(text("DENEME KİŞİ YILMAZ"), one(FieldKind.CARD_HOLDER))

        val single = fill(
            FieldKind.CARD_HOLDER_GIVEN to FieldInfo(),
            FieldKind.CARD_HOLDER_FAMILY to FieldInfo(),
            values = card.copy(cardholder = " DENEME "),
        )
        assertEquals(text("DENEME"), single[0])
        assertFalse(single.containsKey(1))
    }

    @Test
    fun tekKutuSonKullanma() {
        assertEquals(text("12/28"), one(FieldKind.CARD_EXPIRY))
        assertEquals(text("12/2028"), one(FieldKind.CARD_EXPIRY, FieldInfo(hint = "AA/YYYY")))
        assertEquals(text("1228"), one(FieldKind.CARD_EXPIRY, FieldInfo(maxLength = 4)))
        assertEquals(text("122028"), one(FieldKind.CARD_EXPIRY, FieldInfo(maxLength = 6)))
        assertEquals(text("12/2028"), one(FieldKind.CARD_EXPIRY, FieldInfo(maxLength = 7)))
        assertEquals(text("12/28"), one(FieldKind.CARD_EXPIRY, FieldInfo(maxLength = 5, hint = "AA/YYYY")))
        assertEquals(text("12-28"), one(FieldKind.CARD_EXPIRY, FieldInfo(hint = "MM-YY")))
        assertEquals(text("12/28"), one(FieldKind.CARD_EXPIRY, FieldInfo(hint = "MM / YY")))
        assertEquals(text("12.28"), one(FieldKind.CARD_EXPIRY, FieldInfo(hint = "AA.YY")))
        assertEquals(
            text("12/2028"),
            one(
                FieldKind.CARD_EXPIRY,
                FieldInfo(htmlTag = "input", htmlAttributes = mapOf("computed-autofill-hints" to "CREDIT_CARD_EXP_DATE_4_DIGIT_YEAR")),
            ),
        )
        assertEquals(
            text("12/28"),
            one(
                FieldKind.CARD_EXPIRY,
                FieldInfo(
                    htmlTag = "input",
                    htmlAttributes = mapOf(
                        "computed-autofill-hints" to "CREDIT_CARD_EXP_DATE_2_DIGIT_YEAR",
                        "maxlength" to "7",
                    ),
                    maxLength = 7,
                ),
            ),
        )
        assertEquals(text("03/28"), one(FieldKind.CARD_EXPIRY, values = card.copy(expMonth = 3)))
    }

    @Test
    fun ayrıAyVeYılMetin() {
        assertEquals(text("03"), one(FieldKind.CARD_EXP_MONTH, values = card.copy(expMonth = 3)))
        assertEquals(text("2028"), one(FieldKind.CARD_EXP_YEAR))
        assertEquals(text("28"), one(FieldKind.CARD_EXP_YEAR, FieldInfo(maxLength = 2)))
        assertEquals(text("28"), one(FieldKind.CARD_EXP_YEAR, FieldInfo(hint = "YY")))
        assertEquals(text("2028"), one(FieldKind.CARD_EXP_YEAR, FieldInfo(hint = "YYYY")))
        assertEquals(
            text("28"),
            one(
                FieldKind.CARD_EXP_YEAR,
                FieldInfo(htmlTag = "input", htmlAttributes = mapOf("ua-autofill-hints" to "CREDIT_CARD_EXP_2_DIGIT_YEAR")),
            ),
        )
    }

    private fun list(vararg options: String) = FieldInfo(autofillType = listType, options = options.toList())

    @Test
    fun ayListeleri() {
        val numbers = listOf("Ay") + (1..12).map { "%02d".format(it) }
        assertEquals(FillValue.ListIndex(12), one(FieldKind.CARD_EXP_MONTH, list(*numbers.toTypedArray())))
        val plain = (1..12).map { "$it" }
        assertEquals(FillValue.ListIndex(11), one(FieldKind.CARD_EXP_MONTH, list(*plain.toTypedArray())))

        val turkish = arrayOf(
            "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
            "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık",
        )
        assertEquals(FillValue.ListIndex(1), one(FieldKind.CARD_EXP_MONTH, list(*turkish), card.copy(expMonth = 2)))
        assertEquals(FillValue.ListIndex(7), one(FieldKind.CARD_EXP_MONTH, list(*turkish), card.copy(expMonth = 8)))
        val upper = turkish.map { it.uppercase(java.util.Locale.forLanguageTag("tr")) }.toTypedArray()
        assertEquals(FillValue.ListIndex(3), one(FieldKind.CARD_EXP_MONTH, list(*upper), card.copy(expMonth = 4)))
        assertEquals(FillValue.ListIndex(4), one(FieldKind.CARD_EXP_MONTH, list(*upper), card.copy(expMonth = 5)))
        val short = arrayOf("OCA", "ŞUB", "MAR", "NİS", "MAY", "HAZ", "TEM", "AĞU", "EYL", "EKİ", "KAS", "ARA")
        assertEquals(FillValue.ListIndex(1), one(FieldKind.CARD_EXP_MONTH, list(*short), card.copy(expMonth = 2)))
        assertEquals(FillValue.ListIndex(8), one(FieldKind.CARD_EXP_MONTH, list(*short), card.copy(expMonth = 9)))
        val labelled = (1..12).map { "%02d - %s".format(it, turkish[it - 1]) }.toTypedArray()
        assertEquals(FillValue.ListIndex(11), one(FieldKind.CARD_EXP_MONTH, list(*labelled)))
        val english = arrayOf("Month", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sept", "Oct", "Nov", "Dec")
        assertEquals(FillValue.ListIndex(9), one(FieldKind.CARD_EXP_MONTH, list(*english), card.copy(expMonth = 9)))
        assertEquals(FillValue.ListIndex(4), one(FieldKind.CARD_EXP_MONTH, list(*english), card.copy(expMonth = 4)))
        val englishFull = arrayOf("January", "February", "March", "April")
        assertEquals(FillValue.ListIndex(3), one(FieldKind.CARD_EXP_MONTH, list(*englishFull), card.copy(expMonth = 4)))

        assertFalse(fill(FieldKind.CARD_EXP_MONTH to list("Ay", "Seçiniz")).containsKey(0))
    }

    @Test
    fun yılListeleri() {
        assertEquals(FillValue.ListIndex(2), one(FieldKind.CARD_EXP_YEAR, list("Yıl", "2027", "2028")))
        assertEquals(FillValue.ListIndex(1), one(FieldKind.CARD_EXP_YEAR, list("27", "28")))
        assertFalse(fill(FieldKind.CARD_EXP_YEAR to list("2026", "2027")).containsKey(0))
    }

    @Test
    fun tarihAlanı() {
        val millis = java.time.ZonedDateTime.of(2028, 12, 1, 12, 0, 0, 0, java.time.ZoneOffset.UTC)
            .toInstant().toEpochMilli()
        assertEquals(FillValue.Date(millis), one(FieldKind.CARD_EXPIRY, FieldInfo(autofillType = dateType)))
        assertEquals(FillValue.Date(millis), one(FieldKind.CARD_EXP_MONTH, FieldInfo(autofillType = dateType)))
    }

    @Test
    fun eksikDeğerler() {
        val noExpiry = fill(
            FieldKind.CARD_NUMBER to FieldInfo(),
            FieldKind.CARD_EXPIRY to FieldInfo(),
            FieldKind.CARD_EXP_MONTH to FieldInfo(),
            FieldKind.CARD_EXP_YEAR to FieldInfo(),
            values = card.copy(expMonth = null, expYear = null),
        )
        assertEquals(setOf(0), noExpiry.keys)

        val noCode = fill(
            FieldKind.CARD_NUMBER to FieldInfo(),
            FieldKind.CARD_SECURITY_CODE to FieldInfo(),
            values = card.copy(securityCode = ""),
        )
        assertEquals(setOf(0), noCode.keys)

        val empty = CardValues(number = "", cardholder = "", expMonth = null, expYear = null, securityCode = "")
        assertTrue(
            fill(
                FieldKind.CARD_NUMBER to FieldInfo(),
                FieldKind.CARD_HOLDER to FieldInfo(),
                FieldKind.CARD_SECURITY_CODE to FieldInfo(),
                values = empty,
            ).isEmpty(),
        )
    }

    @Test
    fun güvenlikKoduVePinAlanı() {
        val values = fill(FieldKind.CARD_SECURITY_CODE to FieldInfo(), FieldKind.CARD_PIN to FieldInfo())
        assertEquals(text("123"), values[0])
        assertFalse(values.containsKey(1))
    }

    @Test
    fun değerlerMetneGirmiyor() {
        val shown = card.toString()
        assertFalse(shown.contains("4111"))
        assertFalse(shown.contains("123"))
        assertFalse(shown.contains("DENEME"))
        assertFalse(FillValue.Text("4111111111111111").toString().contains("4111"))
    }
}

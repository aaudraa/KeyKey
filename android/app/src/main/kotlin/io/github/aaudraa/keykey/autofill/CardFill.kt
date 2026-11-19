package io.github.aaudraa.keykey.autofill

import java.time.ZoneOffset
import java.time.ZonedDateTime
import java.util.Locale

/**
 * Doldurulacak kartın değerleri. PIN burada yok: hiçbir alana doldurulmaz.
 * [expYear] dört hanelidir (2028).
 */
data class CardValues(
    val number: String,
    val cardholder: String,
    val expMonth: Int?,
    val expYear: Int?,
    val securityCode: String,
) {
    /** Değerler günlüğe ya da hata metnine düşmesin. */
    override fun toString(): String = "CardValues(…)"
}

/** Bir alana verilecek değer; `AutofillValue`'ya ekran çevirir. */
sealed interface FillValue {
    data class Text(val text: String) : FillValue {
        override fun toString(): String = "Text(…)"
    }

    data class ListIndex(val index: Int) : FillValue

    data class Date(val millis: Long) : FillValue
}

/**
 * Kart değerlerini alanın türüne, uzunluk sınırına ve ipucu metnine göre
 * biçimler. Kurallar `resources/docs/kart-doldurma.md` belgesinin "Değerlerin
 * biçimi" bölümünde.
 */
object CardFill {
    private const val AUTOFILL_TYPE_LIST = 3
    private const val AUTOFILL_TYPE_DATE = 4

    /** Ay adları, harfleri sadeleştirilmiş: Türkçe ve İngilizce. */
    private val MONTH_NAMES = listOf(
        listOf("ocak", "january"),
        listOf("subat", "february"),
        listOf("mart", "march"),
        listOf("nisan", "april"),
        listOf("mayis", "may"),
        listOf("haziran", "june"),
        listOf("temmuz", "july"),
        listOf("agustos", "august"),
        listOf("eylul", "september"),
        listOf("ekim", "october"),
        listOf("kasim", "november"),
        listOf("aralik", "december"),
    )

    private val SEPARATOR = Regex("(?:mm|aa)\\s*([/\\-. ])\\s*(?:yy|aa)", RegexOption.IGNORE_CASE)
    private val FOUR_DIGIT_YEAR = Regex("yyyy|aaaa", RegexOption.IGNORE_CASE)
    private val TWO_DIGIT_YEAR = Regex("(?<![a-z])(yy|aa)(?![a-z])", RegexOption.IGNORE_CASE)
    private val FIRST_TOKEN = Regex("[\\p{L}\\p{N}]+")

    /** Alanın [fields] içindeki sırasından değerine. Değeri olmayan alan girmez. */
    fun values(fields: List<FieldInfo>, form: ParsedForm, card: CardValues): Map<Int, FillValue> {
        val result = mutableMapOf<Int, FillValue>()
        fun put(index: Int, value: FillValue?) {
            if (value != null && (value !is FillValue.Text || value.text.isNotEmpty())) result[index] = value
        }

        numbers(fields, form.of(FieldKind.CARD_NUMBER), card.number.filter(Char::isDigit))
            .forEach { (index, text) -> put(index, FillValue.Text(text)) }

        val holder = card.cardholder.trim()
        val split = holder.lastIndexOf(' ')
        val given = if (split > 0) holder.substring(0, split).trim() else holder
        val family = if (split > 0) holder.substring(split + 1) else ""
        form.of(FieldKind.CARD_HOLDER).forEach { put(it, FillValue.Text(holder)) }
        form.of(FieldKind.CARD_HOLDER_GIVEN).forEach { put(it, FillValue.Text(given)) }
        form.of(FieldKind.CARD_HOLDER_FAMILY).forEach { put(it, FillValue.Text(family)) }

        form.of(FieldKind.CARD_SECURITY_CODE).forEach { put(it, FillValue.Text(card.securityCode)) }

        val month = card.expMonth
        val year = card.expYear
        if (month != null && year != null) {
            form.of(FieldKind.CARD_EXPIRY).forEach { put(it, expiry(fields[it], month, year)) }
        }
        if (month != null) {
            form.of(FieldKind.CARD_EXP_MONTH).forEach { put(it, month(fields[it], month, year)) }
        }
        if (year != null) {
            form.of(FieldKind.CARD_EXP_YEAR).forEach { put(it, year(fields[it], month, year)) }
        }
        return result
    }

    /**
     * Numara tek kutuya yazılır. Birden çok kutu varsa ve hepsinin uzunluk
     * sınırı biliniyorsa numara sınırlara göre bölünür.
     */
    private fun numbers(fields: List<FieldInfo>, indices: List<Int>, digits: String): List<Pair<Int, String>> {
        if (digits.isEmpty() || indices.isEmpty()) return emptyList()
        if (indices.size == 1 || indices.any { fields[it].maxLength <= 0 }) {
            return listOf(indices.first() to digits)
        }
        var start = 0
        return indices.mapNotNull { index ->
            if (start >= digits.length) return@mapNotNull null
            val end = minOf(digits.length, start + fields[index].maxLength)
            (index to digits.substring(start, end)).also { start = end }
        }
    }

    private fun expiry(field: FieldInfo, month: Int, year: Int): FillValue? {
        if (field.autofillType == AUTOFILL_TYPE_DATE) return date(month, year)
        if (field.autofillType == AUTOFILL_TYPE_LIST) return null
        val hint = hintText(field)
        val chrome = chromeType(field)
        val fourDigits = when {
            chrome?.endsWith("4_DIGIT_YEAR") == true -> true
            chrome?.endsWith("2_DIGIT_YEAR") == true -> false
            field.maxLength in 4..5 -> false
            field.maxLength in 6..7 -> true
            else -> FOUR_DIGIT_YEAR.containsMatchIn(hint)
        }
        val separator = when (field.maxLength) {
            4, 6 -> ""
            else -> SEPARATOR.find(hint)?.groupValues?.get(1) ?: "/"
        }
        return FillValue.Text(twoDigits(month) + separator + yearText(year, fourDigits))
    }

    private fun month(field: FieldInfo, month: Int, year: Int?): FillValue? = when (field.autofillType) {
        AUTOFILL_TYPE_DATE -> year?.let { date(month, it) }
        AUTOFILL_TYPE_LIST -> field.options.indexOfFirst { matchesMonth(it, month) }
            .takeIf { it >= 0 }?.let { FillValue.ListIndex(it) }
        else -> FillValue.Text(twoDigits(month))
    }

    private fun year(field: FieldInfo, month: Int?, year: Int): FillValue? = when (field.autofillType) {
        AUTOFILL_TYPE_DATE -> month?.let { date(it, year) }
        AUTOFILL_TYPE_LIST -> field.options.indexOfFirst { matchesYear(it, year) }
            .takeIf { it >= 0 }?.let { FillValue.ListIndex(it) }
        else -> {
            val chrome = chromeType(field)
            val hint = hintText(field)
            val twoDigits = when {
                chrome?.endsWith("2_DIGIT_YEAR") == true -> true
                chrome?.endsWith("4_DIGIT_YEAR") == true -> false
                field.maxLength == 2 -> true
                FOUR_DIGIT_YEAR.containsMatchIn(hint) -> false
                else -> TWO_DIGIT_YEAR.containsMatchIn(hint)
            }
            FillValue.Text(yearText(year, !twoDigits))
        }
    }

    /** Ayın 1'i öğlen UTC: her saat diliminde aynı ay kalır. */
    private fun date(month: Int, year: Int): FillValue =
        FillValue.Date(ZonedDateTime.of(year, month, 1, 12, 0, 0, 0, ZoneOffset.UTC).toInstant().toEpochMilli())

    private fun matchesMonth(option: String, month: Int): Boolean {
        val token = FIRST_TOKEN.find(fold(option))?.value ?: return false
        if (token.all(Char::isDigit)) return token.toIntOrNull() == month
        if (token.length < 3) return false
        return MONTH_NAMES[month - 1].any { it.startsWith(token) } &&
            MONTH_NAMES.indices.none { it != month - 1 && MONTH_NAMES[it].any { name -> name.startsWith(token) } }
    }

    private fun matchesYear(option: String, year: Int): Boolean {
        val token = FIRST_TOKEN.find(fold(option))?.value ?: return false
        if (!token.all(Char::isDigit)) return false
        return when (token.length) {
            4 -> token.toInt() == year
            2 -> token.toInt() == year % 100
            else -> false
        }
    }

    /** Büyük-küçük harf ve Türkçe harf farkını giderir: "NİSAN" ve "Nisan" → "nisan". */
    private fun fold(text: String): String =
        text.replace('İ', 'i').replace('I', 'i').lowercase(Locale.ROOT)
            .replace('ı', 'i').replace('ş', 's').replace('ğ', 'g')
            .replace('ü', 'u').replace('ö', 'o').replace('ç', 'c')

    private fun hintText(field: FieldInfo): String {
        val html = field.htmlAttributes.mapKeys { it.key.lowercase(Locale.ROOT) }
        return listOfNotNull(field.hint, html["placeholder"], html["label"]).joinToString(" ")
    }

    private fun chromeType(field: FieldInfo): String? {
        val html = field.htmlAttributes.mapKeys { it.key.lowercase(Locale.ROOT) }
        return CardClassifier.CHROME_ATTRIBUTES.firstNotNullOfOrNull { name ->
            html[name]?.trim()?.uppercase(Locale.ROOT)?.takeIf { it.startsWith("CREDIT_CARD_") }
        }
    }

    private fun twoDigits(month: Int) = month.toString().padStart(2, '0')

    private fun yearText(year: Int, fourDigits: Boolean) =
        if (fourDigits) year.toString() else (year % 100).toString().padStart(2, '0')
}

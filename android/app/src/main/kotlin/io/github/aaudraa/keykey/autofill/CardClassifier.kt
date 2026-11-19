package io.github.aaudraa.keykey.autofill

import java.util.Locale

/**
 * Bir alanın kart alanı tahmini. [strong] kanıt alanın kart olduğunu tek
 * başına söyler; zayıf kanıt ancak formda başka kart alanları da varsa
 * sayılır (bkz. [FormParser]).
 */
data class CardGuess(val kind: FieldKind, val strong: Boolean)

/**
 * Ödeme formlarındaki kart alanlarını tanır. Kanıt sırası: Android
 * ipuçları, HTML `autocomplete`, Chrome'un kendi tahmini, güvenlik kodunun
 * kendine özgü adları ve son olarak Türkçe ve İngilizce sözcükler.
 * Kurallar `resources/docs/kart-doldurma.md` belgesinde.
 */
object CardClassifier {
    private const val AUTOFILL_TYPE_TEXT = 1
    private const val AUTOFILL_TYPE_LIST = 3
    private const val AUTOFILL_TYPE_DATE = 4

    /** Android ve HTML `autocomplete` ipuçları, küçük harfle. */
    private val HINTS = mapOf(
        "creditcardnumber" to FieldKind.CARD_NUMBER,
        "creditcardsecuritycode" to FieldKind.CARD_SECURITY_CODE,
        "creditcardexpirationdate" to FieldKind.CARD_EXPIRY,
        "creditcardexpirationmonth" to FieldKind.CARD_EXP_MONTH,
        "creditcardexpirationyear" to FieldKind.CARD_EXP_YEAR,
        "cc-number" to FieldKind.CARD_NUMBER,
        "cc-name" to FieldKind.CARD_HOLDER,
        "cc-given-name" to FieldKind.CARD_HOLDER_GIVEN,
        "cc-family-name" to FieldKind.CARD_HOLDER_FAMILY,
        "cc-exp" to FieldKind.CARD_EXPIRY,
        "cc-exp-month" to FieldKind.CARD_EXP_MONTH,
        "cc-exp-year" to FieldKind.CARD_EXP_YEAR,
        "cc-csc" to FieldKind.CARD_SECURITY_CODE,
    )

    /** Alanın türü hakkında bir şey söylemeyen ipuçları. */
    private val NON_DEVELOPER_HINTS = setOf("off", "on", "passwordauto")

    /** Chrome'un HTML niteliklerinde gönderdiği tahminler, öncelik sırasıyla. */
    internal val CHROME_ATTRIBUTES =
        listOf("computed-autofill-hints", "crowdsourcing-autofill-hints", "ua-autofill-hints")

    private val CHROME_UNKNOWN = setOf("", "UNKNOWN_TYPE", "NO_SERVER_DATA", "EMPTY_TYPE")

    private val CHROME_TYPES = mapOf(
        "CREDIT_CARD_NUMBER" to FieldKind.CARD_NUMBER,
        "CREDIT_CARD_NAME_FULL" to FieldKind.CARD_HOLDER,
        "CREDIT_CARD_NAME_FIRST" to FieldKind.CARD_HOLDER_GIVEN,
        "CREDIT_CARD_NAME_LAST" to FieldKind.CARD_HOLDER_FAMILY,
        "CREDIT_CARD_EXP_MONTH" to FieldKind.CARD_EXP_MONTH,
        "CREDIT_CARD_EXP_2_DIGIT_YEAR" to FieldKind.CARD_EXP_YEAR,
        "CREDIT_CARD_EXP_4_DIGIT_YEAR" to FieldKind.CARD_EXP_YEAR,
        "CREDIT_CARD_EXP_DATE_2_DIGIT_YEAR" to FieldKind.CARD_EXPIRY,
        "CREDIT_CARD_EXP_DATE_4_DIGIT_YEAR" to FieldKind.CARD_EXPIRY,
        "CREDIT_CARD_VERIFICATION_CODE" to FieldKind.CARD_SECURITY_CODE,
        "CREDIT_CARD_STANDALONE_VERIFICATION_CODE" to FieldKind.CARD_SECURITY_CODE,
    )

    /** Güvenlik kodunun başka bir anlama gelmeyen adları. */
    private val SECURITY_CODE_NAMES = listOf("cvv", "cvc", "csc")

    private val SECURITY_CODE_WORDS = listOf(
        "security code", "securitycode", "security number", "card verification", "cardverification",
        "verification value", "güvenlik kod", "guvenlik kod", "güvenlikkod", "guvenlikkod",
    )
    private val HOLDER_WORDS = listOf(
        "cardholder", "card holder", "holder name", "holdername", "name on card", "nameoncard",
        "kart sahib", "kartsahib", "kart üzerindeki", "kart uzerindeki",
        "kartın üzerindeki", "kartin uzerindeki", "ccname",
    )
    private val NUMBER_WORDS = listOf(
        "card number", "cardnumber", "card no", "cardno", "card num", "cardnum",
        "cc number", "ccnumber", "ccnum", "credit card", "creditcard", "debit card",
        "kart numara", "kartnumara", "kart no", "kartno", "kredi kart", "banka kart",
    )
    private val EXPIRY_WORDS = listOf(
        "expir", "exp date", "expdate", "valid thru", "valid through", "validthru", "valid until",
        "son kullanma", "sonkullanma", "geçerlilik", "gecerlilik",
    )
    private val EXPIRY_TOKENS = setOf("exp", "skt")
    private val MONTH_TOKENS = setOf("ay", "ayı", "ayi", "mm", "aa")
    private val YEAR_TOKENS = setOf("yıl", "yılı", "yil", "yili", "yy", "yyyy", "aaaa")
    private val PIN_WORDS = listOf("kart şifre", "kart sifre", "kartşifre", "kartsifre", "card pin", "cardpin")

    /** Kart sanılmaması gereken alanlar: doğum tarihi, arama, captcha. */
    private val EXCLUDED_WORDS = listOf("doğum", "dogum", "birth", "search", "captcha", "arama")

    private val SKIPPED_HTML_TYPES = setOf("hidden", "submit", "button", "checkbox", "radio", "search")
    private val TOKEN_SPLIT = Regex("[^\\p{L}\\p{N}]+")

    fun classify(field: FieldInfo): CardGuess? {
        if (!field.isVisible || !field.isEnabled) return null
        val tag = field.htmlTag?.lowercase(Locale.ROOT)
        if (tag != null && tag != "input" && tag != "select") return null
        val html = field.htmlAttributes.mapKeys { it.key.lowercase(Locale.ROOT) }
        if (html["type"]?.lowercase(Locale.ROOT) in SKIPPED_HTML_TYPES) return null
        val guess = guess(field, html) ?: return null
        return guess.takeIf { fits(it.kind, field.autofillType) }
    }

    private fun guess(field: FieldInfo, html: Map<String, String>): CardGuess? {
        // Geliştirici ipucu verdiyse ona güvenilir; başka bir şeyse (parola,
        // adres) alan kart değildir. "passwordAuto" geliştiricinin değil
        // sistemin ipucudur: Android 14+ ipucu verilmemiş her gizli kutuya
        // ekliyor, gizli rakam CVV kutusu da buna dahil.
        val hints = field.autofillHints.map { it.lowercase(Locale.ROOT) }
            .filterNot { it in NON_DEVELOPER_HINTS }
        if (hints.isNotEmpty()) {
            hints.firstNotNullOfOrNull { HINTS[it] }?.let { return CardGuess(it, strong = true) }
            return null
        }
        html["autocomplete"]?.lowercase(Locale.ROOT)?.split(' ')
            ?.firstNotNullOfOrNull { HINTS[it] }
            ?.let { return CardGuess(it, strong = true) }
        // Chrome kendi tahminini biliyorsa, kart olsun olmasın, ona uyulur.
        chromeType(html)?.let { type -> return CHROME_TYPES[type]?.let { CardGuess(it, strong = true) } }

        val words = listOfNotNull(
            field.idEntry,
            field.hint,
            html["name"],
            html["id"],
            html["placeholder"],
            html["label"],
        ).joinToString(" ") { FieldClassifier.normalize(it) }
        if (EXCLUDED_WORDS.any { words.contains(it) }) return null
        if (SECURITY_CODE_NAMES.any { words.contains(it) }) {
            return CardGuess(FieldKind.CARD_SECURITY_CODE, strong = true)
        }
        return weakGuess(words)?.let { CardGuess(it, strong = false) }
    }

    private fun weakGuess(words: String): FieldKind? {
        if (SECURITY_CODE_WORDS.any { words.contains(it) }) return FieldKind.CARD_SECURITY_CODE
        if (PIN_WORDS.any { words.contains(it) }) return FieldKind.CARD_PIN
        if (HOLDER_WORDS.any { words.contains(it) }) return FieldKind.CARD_HOLDER
        val tokens = words.split(TOKEN_SPLIT).toSet()
        val month = tokens.any { it in MONTH_TOKENS || it.endsWith("month") }
        val year = tokens.any { it in YEAR_TOKENS || it.endsWith("year") }
        val expiry = EXPIRY_WORDS.any { words.contains(it) } || tokens.any { it in EXPIRY_TOKENS }
        return when {
            month && year -> FieldKind.CARD_EXPIRY
            month -> FieldKind.CARD_EXP_MONTH
            year -> FieldKind.CARD_EXP_YEAR
            expiry -> FieldKind.CARD_EXPIRY
            NUMBER_WORDS.any { words.contains(it) } -> FieldKind.CARD_NUMBER
            else -> null
        }
    }

    /** Chrome'un ilk anlamlı tahmini; yoksa `null`. */
    private fun chromeType(html: Map<String, String>): String? =
        CHROME_ATTRIBUTES.firstNotNullOfOrNull { name ->
            html[name]?.trim()?.uppercase(Locale.ROOT)?.takeUnless { it in CHROME_UNKNOWN }
        }

    /** Numara, ad ve güvenlik kodu metin kutusudur; son kullanma liste ya da tarih de olabilir. */
    private fun fits(kind: FieldKind, autofillType: Int): Boolean = when (kind) {
        FieldKind.CARD_EXPIRY, FieldKind.CARD_EXP_MONTH, FieldKind.CARD_EXP_YEAR ->
            autofillType == AUTOFILL_TYPE_TEXT || autofillType == AUTOFILL_TYPE_LIST ||
                autofillType == AUTOFILL_TYPE_DATE
        else -> autofillType == AUTOFILL_TYPE_TEXT
    }
}

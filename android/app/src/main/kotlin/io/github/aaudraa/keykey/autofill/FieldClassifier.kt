package io.github.aaudraa.keykey.autofill

import java.util.Locale

/** Doldurulabilir alan türleri. */
enum class FieldKind { USERNAME, PASSWORD, NEW_PASSWORD, OTP }

/**
 * Formdaki bir alanın, Android'in `ViewNode`'undan bağımsız özeti.
 *
 * Alan tespiti bu düz model üzerinde çalışır; böylece JVM birim testleriyle
 * sınanabilir. `ViewNode`'dan çeviri [StructureParser]'dadır.
 */
data class FieldInfo(
    val autofillHints: List<String> = emptyList(),
    val inputType: Int = 0,
    /** `View.AUTOFILL_TYPE_TEXT` (1) dışındakiler doldurulmaz. */
    val autofillType: Int = AUTOFILL_TYPE_TEXT,
    val htmlTag: String? = null,
    val htmlAttributes: Map<String, String> = emptyMap(),
    val idEntry: String? = null,
    val hint: String? = null,
    val isVisible: Boolean = true,
    val isEnabled: Boolean = true,
) {
    companion object {
        const val AUTOFILL_TYPE_TEXT = 1
    }
}

/**
 * Bir alanın ne istediğini tahmin eder. Sırayla: geliştiricinin verdiği
 * autofill ipuçları, HTML nitelikleri, giriş türü, alanın kimliği ve ipucu
 * metnindeki Türkçe ve İngilizce sözcükler.
 */
object FieldClassifier {
    // android.text.InputType değerleri. JVM testlerinde Android sınıfı
    // yüklenmediği için burada sabit olarak tutuluyor.
    private const val TYPE_MASK_CLASS = 0x0000000f
    private const val TYPE_MASK_VARIATION = 0x00000ff0
    private const val TYPE_CLASS_TEXT = 0x00000001
    private const val TYPE_CLASS_NUMBER = 0x00000002
    private const val TEXT_PASSWORD = 0x00000080
    private const val TEXT_VISIBLE_PASSWORD = 0x00000090
    private const val TEXT_WEB_PASSWORD = 0x000000e0
    private const val TEXT_EMAIL_ADDRESS = 0x00000020
    private const val TEXT_WEB_EMAIL_ADDRESS = 0x000000d0
    private const val NUMBER_PASSWORD = 0x00000010

    // "passwordAuto": Android 14+ parola türündeki alanlara bu ipucunu kendisi
    // ekliyor; tanınmazsa alan "başka bir şey" sayılıp atlanıyordu.
    private val PASSWORD_HINTS =
        setOf("password", "passwordauto", "current-password", "currentpassword")
    private val NEW_PASSWORD_HINTS = setOf("newpassword", "new-password")
    private val USERNAME_HINTS =
        setOf("username", "newusername", "new-username", "emailaddress", "email")
    private val OTP_HINTS =
        setOf("smsotpcode", "2faappotpcode", "one-time-code", "onetimecode", "otp")

    private val PASSWORD_WORDS = listOf("password", "passwd", "pwd", "şifre", "sifre", "parola")
    private val NEW_WORDS =
        listOf("new", "confirm", "repeat", "retype", "yeni", "tekrar", "onay")
    private val USERNAME_WORDS = listOf(
        "username", "user", "login", "email", "e-mail", "mail", "account",
        "kullanıcı", "kullanici", "e-posta", "eposta", "hesap",
        "kimlik", "tckn", "müşteri", "musteri", "customer",
    )
    private val OTP_WORDS = listOf(
        "otp", "2fa", "totp", "mfa", "one-time", "onetime", "verification code",
        "authcode", "auth code", "doğrulama kodu", "dogrulama kodu",
        "tek kullanımlık", "sms kodu",
    )
    private val IGNORED_WORDS = listOf("search", "captcha", "arama")

    fun classify(field: FieldInfo): FieldKind? {
        if (field.autofillType != FieldInfo.AUTOFILL_TYPE_TEXT) return null
        if (!field.isVisible || !field.isEnabled) return null
        if (field.htmlTag != null && field.htmlTag.lowercase(Locale.ROOT) != "input") return null

        // Geliştirici ipucu verdiyse ona güvenilir; ipucu başka bir şeyse
        // (adres, kart numarası) alan doldurulmaz.
        val hints = field.autofillHints.map { it.lowercase(Locale.ROOT) }
        if (hints.isNotEmpty()) {
            fromHints(hints)?.let { return it }
            if (hints.none { it == "off" || it == "on" }) return null
        }

        val html = field.htmlAttributes.mapKeys { it.key.lowercase(Locale.ROOT) }
        val htmlType = html["type"]?.lowercase(Locale.ROOT)
        if (htmlType in setOf("hidden", "submit", "button", "checkbox", "radio", "search")) {
            return null
        }
        html["autocomplete"]?.let { fromHints(it.lowercase(Locale.ROOT).split(' ')) }
            ?.let { return it }

        val words = listOfNotNull(field.idEntry, field.hint, html["name"], html["id"], html["placeholder"])
            .joinToString(" ") { normalize(it) }
        if (IGNORED_WORDS.any { words.contains(it) }) return null

        val passwordLike = htmlType == "password" || isPasswordInputType(field.inputType)
        if (passwordLike) {
            return if (NEW_WORDS.any { words.contains(it) }) FieldKind.NEW_PASSWORD else FieldKind.PASSWORD
        }
        if (OTP_WORDS.any { words.contains(it) }) return FieldKind.OTP
        if (PASSWORD_WORDS.any { words.contains(it) }) {
            return if (NEW_WORDS.any { words.contains(it) }) FieldKind.NEW_PASSWORD else FieldKind.PASSWORD
        }
        if (htmlType == "email" || isEmailInputType(field.inputType)) return FieldKind.USERNAME
        if (USERNAME_WORDS.any { words.contains(it) }) return FieldKind.USERNAME
        return null
    }

    /** Alan sıradan bir metin kutusu mu; kullanıcı adı tahmini için. */
    fun isPlainText(field: FieldInfo): Boolean {
        if (field.autofillType != FieldInfo.AUTOFILL_TYPE_TEXT) return false
        if (!field.isVisible || !field.isEnabled) return false
        val htmlType = field.htmlAttributes.entries
            .firstOrNull { it.key.equals("type", ignoreCase = true) }?.value?.lowercase(Locale.ROOT)
        if (field.htmlTag != null) {
            return field.htmlTag.equals("input", ignoreCase = true) &&
                (htmlType == null || htmlType in setOf("text", "email", "tel"))
        }
        return field.inputType and TYPE_MASK_CLASS == TYPE_CLASS_TEXT
    }

    private fun fromHints(hints: List<String>): FieldKind? = when {
        hints.any { it in NEW_PASSWORD_HINTS } -> FieldKind.NEW_PASSWORD
        hints.any { it in PASSWORD_HINTS } -> FieldKind.PASSWORD
        hints.any { it in OTP_HINTS } -> FieldKind.OTP
        hints.any { it in USERNAME_HINTS } -> FieldKind.USERNAME
        else -> null
    }

    private fun isPasswordInputType(inputType: Int): Boolean {
        val variation = inputType and TYPE_MASK_VARIATION
        return when (inputType and TYPE_MASK_CLASS) {
            TYPE_CLASS_TEXT -> variation == TEXT_PASSWORD ||
                variation == TEXT_WEB_PASSWORD ||
                variation == TEXT_VISIBLE_PASSWORD
            TYPE_CLASS_NUMBER -> variation == NUMBER_PASSWORD
            else -> false
        }
    }

    private fun isEmailInputType(inputType: Int): Boolean {
        val variation = inputType and TYPE_MASK_VARIATION
        return inputType and TYPE_MASK_CLASS == TYPE_CLASS_TEXT &&
            (variation == TEXT_EMAIL_ADDRESS || variation == TEXT_WEB_EMAIL_ADDRESS)
    }

    /**
     * Küçük harfe çevirir; `İ` ve `I` Türkçe kurala göre değil, `i` olur.
     * Kimliklerdeki `_` ve `-` boşluk sayılır, `user_name` ile `username`
     * ayrıca aranır.
     */
    internal fun normalize(text: String): String {
        val lower = text.replace('İ', 'i').replace('I', 'i').lowercase(Locale.ROOT)
        return lower + " " + lower.replace('_', ' ').replace('-', ' ') + " " +
            lower.replace("_", "").replace("-", "")
    }
}

/** Bir formun çözümü: her alan türü için alanların sırası. */
data class ParsedForm(val fields: Map<FieldKind, List<Int>>) {
    val hasCredentials: Boolean
        get() = listOf(FieldKind.USERNAME, FieldKind.PASSWORD, FieldKind.NEW_PASSWORD)
            .any { fields[it].orEmpty().isNotEmpty() }

    fun of(kind: FieldKind): List<Int> = fields[kind].orEmpty()
}

object FormParser {
    /**
     * Alanları gezinme sırasıyla alır, türlerini bulur. Parola alanı olup
     * kullanıcı adı bulunamadıysa, ilk parola alanından hemen önceki sıradan
     * metin kutusu kullanıcı adı sayılır; çoğu giriş formu böyledir.
     */
    fun parse(fields: List<FieldInfo>): ParsedForm {
        val kinds = fields.map { FieldClassifier.classify(it) }.toMutableList()
        val firstPassword = kinds.indexOfFirst {
            it == FieldKind.PASSWORD || it == FieldKind.NEW_PASSWORD
        }
        if (firstPassword > 0 && FieldKind.USERNAME !in kinds) {
            val candidate = (firstPassword - 1 downTo 0).firstOrNull {
                kinds[it] == null && FieldClassifier.isPlainText(fields[it])
            }
            if (candidate != null) kinds[candidate] = FieldKind.USERNAME
        }
        val grouped = mutableMapOf<FieldKind, MutableList<Int>>()
        kinds.forEachIndexed { index, kind ->
            if (kind != null) grouped.getOrPut(kind) { mutableListOf() }.add(index)
        }
        return ParsedForm(grouped)
    }
}

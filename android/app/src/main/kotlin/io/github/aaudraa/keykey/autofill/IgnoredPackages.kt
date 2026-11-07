package io.github.aaudraa.keykey.autofill

/**
 * KeyKey'in hiçbir şey doldurmadığı ve kaydetmeyi önermediği uygulamalar.
 *
 * KeyKey'in kendi formları (ana parola, kayıt düzenleme) ve cihazın kendi
 * kilit bilgileri: Ayarlar'daki PIN onayı ve kilit ekranı. Android 14
 * emülatöründe Ayarlar'da PIN girilince KeyKey cihaz PIN'ini kaydetmeyi
 * önerdi ve öneri penceresi parmak izi kaydını kapattı.
 */
internal object IgnoredPackages {
    private val SYSTEM = setOf(
        "android",
        "com.android.settings",
        "com.android.systemui",
    )

    fun isIgnored(packageName: String, ownPackage: String): Boolean =
        packageName == ownPackage || packageName in SYSTEM
}

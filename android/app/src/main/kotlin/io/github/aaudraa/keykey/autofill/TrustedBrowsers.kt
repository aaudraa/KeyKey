package io.github.aaudraa.keykey.autofill

import android.content.pm.PackageManager

/**
 * Bildirdiği `webDomain`'e güvenilen tarayıcılar.
 *
 * Bir uygulama ancak paket adı [TRUSTED_BROWSERS] listesindeyse ve o
 * listedeki imzalardan biriyle imzalanmışsa web sitesi kayıtlarıyla eşleşir.
 * Aynı paket adını taşıyan, başka anahtarla imzalanmış bir uygulama
 * güvenilmez. Kaynak ve kurallar güvenlik tasarımı belgesinin Eşleştirme
 * bölümünde.
 */
object TrustedBrowsers {
    /** [packageName] için kabul edilen imza özetleri; listede yoksa boş. */
    fun allowedDigests(packageName: String): Set<String> =
        TRUSTED_BROWSERS[packageName].orEmpty()

    fun isTrusted(pm: PackageManager, packageName: String): Boolean =
        allowedDigests(packageName).any { SigningCerts.hasAll(pm, packageName, listOf(it)) }
}

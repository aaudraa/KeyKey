package io.github.aaudraa.keykey.autofill

import android.content.pm.PackageManager

/**
 * Bildirdiği `webDomain`'e güvenilen tarayıcılar: paket adı ve imza özeti.
 *
 * Bir uygulama ancak bu listede ve imzası tutuyorsa web sitesi kayıtlarıyla
 * eşleşir. Kaynak ve kurallar güvenlik tasarımı belgesinin Eşleştirme
 * bölümünde.
 */
object TrustedBrowsers {
    /** Paket adı -> izin verilen imza özetleri. */
    private val browsers: Map<String, Set<String>> = emptyMap()

    fun isTrusted(pm: PackageManager, packageName: String): Boolean {
        val allowed = browsers[packageName] ?: return false
        return allowed.any { SigningCerts.hasAll(pm, packageName, listOf(it)) }
    }
}

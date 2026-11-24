package io.github.aaudraa.keykey.passkey

import io.github.aaudraa.keykey.autofill.TRUSTED_BROWSERS
import org.json.JSONArray
import org.json.JSONObject

/**
 * Credential Manager'ın ayrıcalıklı tarayıcı listesi
 * (`CallingAppInfo.getOrigin`): yalnızca bu tarayıcıların bildirdiği web
 * origin'ine güvenilir. KeyKey'in gömülü güvenilen tarayıcı listesinden
 * üretilir; o liste de Google'ın aynı amaçlı listesinden gelir.
 */
object PrivilegedBrowsers {
    val allowlistJson: String by lazy { allowlistJson(TRUSTED_BROWSERS) }

    internal fun allowlistJson(browsers: Map<String, Set<String>>): String {
        val apps = JSONArray()
        for ((packageName, digests) in browsers.toSortedMap()) {
            val signatures = JSONArray()
            for (digest in digests.sorted()) {
                signatures.put(
                    JSONObject()
                        .put("build", "release")
                        .put("cert_fingerprint_sha256", fingerprint(digest)),
                )
            }
            apps.put(
                JSONObject()
                    .put("type", "android")
                    .put(
                        "info",
                        JSONObject().put("package_name", packageName).put("signatures", signatures),
                    ),
            )
        }
        return JSONObject().put("apps", apps).toString()
    }

    /** `ab12…` → `AB:12:…`. */
    internal fun fingerprint(hex: String): String =
        hex.uppercase().chunked(2).joinToString(":")
}

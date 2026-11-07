package io.github.aaudraa.keykey.autofill

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class IgnoredPackagesTest {
    private val own = "io.github.aaudraa.keykey"

    @Test
    fun kendiFormlarıVeSistemFormlarıAtlanıyor() {
        assertTrue(IgnoredPackages.isIgnored(own, own))
        assertTrue(IgnoredPackages.isIgnored("com.android.settings", own))
        assertTrue(IgnoredPackages.isIgnored("com.android.systemui", own))
        assertTrue(IgnoredPackages.isIgnored("android", own))
    }

    @Test
    fun başkaUygulamalarAtlanmıyor() {
        assertFalse(IgnoredPackages.isIgnored("io.github.aaudraa.ornekgiris", own))
        assertFalse(IgnoredPackages.isIgnored("com.android.chrome", own))
        // Ön ek benzerliği yetmez.
        assertFalse(IgnoredPackages.isIgnored("com.android.settings.fake", own))
    }
}

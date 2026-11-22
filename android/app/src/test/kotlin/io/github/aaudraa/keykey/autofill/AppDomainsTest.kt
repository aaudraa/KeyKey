package io.github.aaudraa.keykey.autofill

import android.content.pm.verify.domain.DomainVerificationUserState
import org.junit.Assert.assertEquals
import org.junit.Test

class AppDomainsTest {
    @Test
    fun yalnızcaDoğrulanmışAlanAdıDoğrulanmışSayılıyor() {
        val domains = AppDomains.fromStates(
            mapOf(
                "GitHub.com" to DomainVerificationUserState.DOMAIN_STATE_VERIFIED,
                "*.github.io" to DomainVerificationUserState.DOMAIN_STATE_NONE,
                "x.com" to DomainVerificationUserState.DOMAIN_STATE_SELECTED,
            ),
        )
        assertEquals(
            listOf("*.github.io" to false, "github.com" to true, "x.com" to false),
            domains,
        )
    }

    @Test
    fun boşHaritaBoşListe() {
        assertEquals(emptyList<Pair<String, Boolean>>(), AppDomains.fromStates(emptyMap()))
    }
}

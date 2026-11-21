package io.github.aaudraa.keykey

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** N10: süreçte tek bir bekleyen pano temizliği olur. */
class ClearScheduleTest {
    private val posted = mutableListOf<Runnable>()
    private val cancelled = mutableListOf<Runnable>()
    private val schedule = ClearSchedule(
        post = { runnable, _ -> posted += runnable },
        cancel = { runnable -> cancelled += runnable },
    )

    @Test
    fun yeniKopyaEskiZamanlayıcıyıIptalEdiyor() {
        // Ana uygulama ve doldurma ekranı ayrı SecureClipboard nesneleri kurar
        // ama aynı zamanlayıcıyı paylaşır; ilkinin temizliği ikincinin
        // kopyasını erkenden silmemeli.
        var runs = 0
        schedule.replace(30_000) { runs++ }
        schedule.replace(30_000) { runs++ }

        assertEquals(listOf(posted[0]), cancelled)
        posted[1].run()
        assertEquals(1, runs)
    }

    @Test
    fun çalışanTemizlikSonrakiniIptalEttirmiyor() {
        schedule.replace(30_000) {}
        posted[0].run()
        schedule.replace(30_000) {}

        assertTrue(cancelled.isEmpty())
    }

    @Test
    fun iptalEdilmişTemizlikÇalışsaBileBirŞeyYapmıyor() {
        // Handler iptalden hemen önce çalıştırmaya başlamış olabilir.
        var runs = 0
        schedule.replace(30_000) { runs++ }
        val stale = posted[0]
        schedule.replace(30_000) { runs += 10 }
        stale.run()

        assertEquals(0, runs)
    }
}

package io.github.aaudraa.keykey

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayInputStream

/** K11: dosya okurken düz metin kopyaları bellekte sıfırlanmadan kalmaz. */
class WipingByteArrayOutputStreamTest {
    /** Korumalı iç diziyi gösterir. */
    private class Probe : WipingByteArrayOutputStream(4) {
        fun internal(): ByteArray = buf
    }

    @Test
    fun büyürkenEskiDiziSıfırlanıyor() {
        val out = Probe()
        out.write(byteArrayOf(1, 2, 3), 0, 3)
        val first = out.internal()
        out.write(ByteArray(100) { 7 }, 0, 100)

        assertTrue(first.all { it == 0.toByte() })
        assertArrayEquals(byteArrayOf(1, 2, 3) + ByteArray(100) { 7 }, out.toByteArray())
    }

    @Test
    fun silinceİçDiziSıfırlanıyor() {
        val out = Probe()
        out.write(ByteArray(50) { 9 }, 0, 50)
        out.wipe()

        assertTrue(out.internal().all { it == 0.toByte() })
        assertTrue(out.toByteArray().isEmpty())
    }

    @Test
    fun okumaSınırıKoruyor() {
        val data = ByteArray(300_000) { (it % 251).toByte() }
        assertArrayEquals(data.copyOf(70_000), readAtMost(ByteArrayInputStream(data), 70_000))
        assertArrayEquals(data, readAtMost(ByteArrayInputStream(data), 1_000_000))
    }
}

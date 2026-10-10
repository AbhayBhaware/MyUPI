package com.example.myupi

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ClipAnnouncerTest {

    @Test
    fun testConcatenateEmptyAndSingle() {
        val empty = ClipAnnouncer.concatenateWithCrossfade(emptyList())
        assertEquals(0, empty.size)

        val single = ShortArray(1000) { 1000.toShort() }
        val result = ClipAnnouncer.concatenateWithCrossfade(listOf(single))
        assertEquals(1000, result.size)
        assertEquals(1000.toShort(), result[500])
    }

    @Test
    fun testConcatenateWithCrossfade() {
        val clipA = ShortArray(1000) { 10000.toShort() }
        val clipB = ShortArray(1000) { 20000.toShort() }

        val combined = ClipAnnouncer.concatenateWithCrossfade(listOf(clipA, clipB))

        // Total length should be: 1000 + 1000 - 240 (crossfade samples) = 1760
        assertEquals(1760, combined.size)

        // Before crossfade: matches clipA
        assertEquals(10000.toShort(), combined[0])
        assertEquals(10000.toShort(), combined[500])

        // After crossfade: matches clipB
        assertEquals(20000.toShort(), combined[1500])

        // Inside crossfade region (between index 760 and 1000):
        // Sample at midpoint should be blend of ~10000 and ~20000 -> ~15000
        val midSample = combined[880].toInt()
        assertTrue("Midpoint sample ($midSample) should be blended between 10000 and 20000",
            midSample in 14000..16000)
    }
}

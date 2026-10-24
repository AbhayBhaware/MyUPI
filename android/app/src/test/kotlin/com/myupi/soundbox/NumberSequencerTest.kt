package com.myupi.soundbox

import org.junit.Assert.assertEquals
import org.junit.Test

class NumberSequencerTest {

    @Test
    fun testGoldenAmountsDecomposition() {
        // 1. Single digit 1
        assertEquals(listOf("num_1"), NumberSequencer.sequenceAmount(1L))

        // 2. Single digit 7
        assertEquals(listOf("num_7"), NumberSequencer.sequenceAmount(7L))

        // 3. Teen 11
        assertEquals(listOf("num_11"), NumberSequencer.sequenceAmount(11L))

        // 4. Teen 19
        assertEquals(listOf("num_19"), NumberSequencer.sequenceAmount(19L))

        // 5. Distinct 2-digit 21
        assertEquals(listOf("num_21"), NumberSequencer.sequenceAmount(21L))

        // 6. Max 2-digit 99
        assertEquals(listOf("num_99"), NumberSequencer.sequenceAmount(99L))

        // 7. Round hundred 100
        assertEquals(listOf("num_1", "hundred"), NumberSequencer.sequenceAmount(100L))

        // 8. Hundred plus unit 101
        assertEquals(listOf("num_1", "hundred", "num_1"), NumberSequencer.sequenceAmount(101L))

        // 9. Multi-hundred 250
        assertEquals(listOf("num_2", "hundred", "num_50"), NumberSequencer.sequenceAmount(250L))

        // 10. Max 3-digit 999
        assertEquals(listOf("num_9", "hundred", "num_99"), NumberSequencer.sequenceAmount(999L))

        // 11. Round thousand 1,000
        assertEquals(listOf("num_1", "thousand"), NumberSequencer.sequenceAmount(1000L))

        // 12. Thousand plus unit 1,001
        assertEquals(listOf("num_1", "thousand", "num_1"), NumberSequencer.sequenceAmount(1001L))

        // 13. Mixed 5-digit 12,345
        assertEquals(
            listOf("num_12", "thousand", "num_3", "hundred", "num_45"),
            NumberSequencer.sequenceAmount(12345L)
        )

        // 14. 1 Lakh (1,00,000)
        assertEquals(listOf("num_1", "lakh"), NumberSequencer.sequenceAmount(100000L))

        // 15. 10 Lakhs (10,00,000)
        assertEquals(listOf("num_10", "lakh"), NumberSequencer.sequenceAmount(1000000L))
    }

    @Test
    fun testPaymentAnnouncementGoldenSetAcrossAllLanguages() {
        for (lang in NumberSequencer.SUPPORTED_LANGUAGES) {
            // Test 1: 1 Rupee singular in English
            val seq1 = NumberSequencer.sequencePayment("1", langCode = lang, format = "A")
            val expectedRupee = if (lang == "en-IN") "rupee" else "rupees"
            assertEquals(listOf("payment_received", "num_1", expectedRupee), seq1)

            // Test 16: 250.50 with paise
            val seqPaise = NumberSequencer.sequencePayment("250.50", langCode = lang, format = "A")
            assertEquals(
                listOf("payment_received", "num_2", "hundred", "num_50", "rupees", "num_50", "paise"),
                seqPaise
            )

            // Test with Chime enabled
            val seqChime = NumberSequencer.sequencePayment("500", langCode = lang, format = "A", withChime = true)
            assertEquals(
                listOf("chime", "payment_received", "num_5", "hundred", "rupees"),
                seqChime
            )

            // Test Short Format B
            val seqFormatB = NumberSequencer.sequencePayment("100", langCode = lang, format = "B")
            assertEquals(
                listOf("num_1", "hundred", "rupees", "received"),
                seqFormatB
            )

            // Test Polite Format C
            val seqFormatC = NumberSequencer.sequencePayment("100", langCode = lang, format = "C")
            assertEquals(
                listOf("payment_received", "num_1", "hundred", "rupees", "thank_you"),
                seqFormatC
            )
        }
    }

    @Test
    fun testCroresAndEdgeCases() {
        // 1 Crore
        assertEquals(listOf("num_1", "crore"), NumberSequencer.sequenceAmount(10000000L))

        // 2 Crore 50 Lakh
        assertEquals(
            listOf("num_2", "crore", "num_50", "lakh"),
            NumberSequencer.sequenceAmount(25000000L)
        )

        // Zero
        assertEquals(listOf("num_0"), NumberSequencer.sequenceAmount(0L))

        // Formatted input with commas and spaces
        val seqCommas = NumberSequencer.sequencePayment(" 12,345 ", "en-IN")
        assertEquals(
            listOf("payment_received", "num_12", "thousand", "num_3", "hundred", "num_45", "rupees"),
            seqCommas
        )
    }
}

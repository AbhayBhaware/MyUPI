package com.myupi.soundbox

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SpeechTemplateBuilderTest {

    @Test
    fun testShopNameSanitization() {
        assertEquals("", SpeechTemplateBuilder.sanitizeShopName(""))
        assertEquals("", SpeechTemplateBuilder.sanitizeShopName("   "))
        assertEquals("A and B Stores", SpeechTemplateBuilder.sanitizeShopName("A & B Stores"))
        assertEquals("Ganesh Sweets and Bakery", SpeechTemplateBuilder.sanitizeShopName("Ganesh Sweets 🍰 & Bakery 🌟*#_!"))
        assertEquals("11 11 Studios", SpeechTemplateBuilder.sanitizeShopName("11 11 Studios"))

        val longName = "Super Grand Luxury Mega Store of Electronics and Groceries"
        val sanitized = SpeechTemplateBuilder.sanitizeShopName(longName)
        assertTrue(sanitized.length <= 30)
        assertEquals("Super Grand Luxury Mega Store", sanitized)
    }

    @Test
    fun testAmountAndCurrencyFormatting() {
        assertEquals("1 rupee", SpeechTemplateBuilder.formatSpokenAmount("1", "en-IN"))
        assertEquals("7 rupees", SpeechTemplateBuilder.formatSpokenAmount("7", "en-IN"))
        assertEquals("250 rupees 50 paise", SpeechTemplateBuilder.formatSpokenAmount("250.50", "en-IN"))
        assertEquals("1000 rupees", SpeechTemplateBuilder.formatSpokenAmount("1,000", "en-IN"))

        assertEquals("500 रुपये", SpeechTemplateBuilder.formatSpokenAmount("500", "hi-IN"))
        assertEquals("250 रुपये 50 पैसे", SpeechTemplateBuilder.formatSpokenAmount("250.50", "hi-IN"))
        assertEquals("500 रुपये", SpeechTemplateBuilder.formatSpokenAmount("500", "mr-IN"))
        assertEquals("500 રૂપિયા", SpeechTemplateBuilder.formatSpokenAmount("500", "gu-IN"))
        assertEquals("500 ரூபாய்", SpeechTemplateBuilder.formatSpokenAmount("500", "ta-IN"))
        assertEquals("500 రూపాయలు", SpeechTemplateBuilder.formatSpokenAmount("500", "te-IN"))
        assertEquals("500 টাকা", SpeechTemplateBuilder.formatSpokenAmount("500", "bn-IN"))
        assertEquals("500 ರೂಪಾಯಿ", SpeechTemplateBuilder.formatSpokenAmount("500", "kn-IN"))
    }

    @Test
    fun testEnglishAnnouncementTemplates() {
        // Standard Format A
        assertEquals(
            "500 rupees received on My U P I",
            SpeechTemplateBuilder.buildAnnouncement("500", "en-IN", "A")
        )

        // Short Format B
        assertEquals(
            "500 rupees received",
            SpeechTemplateBuilder.buildAnnouncement("500", "en-IN", "B")
        )

        // With Shop Format C
        assertEquals(
            "500 rupees received on My U P I for Ramesh Kirana Store",
            SpeechTemplateBuilder.buildAnnouncement("500", "en-IN", "C", "Ramesh Kirana Store", true)
        )

        // Format A behaves as C when shop name is included
        assertEquals(
            "500 rupees received on My U P I for Ramesh Kirana Store",
            SpeechTemplateBuilder.buildAnnouncement("500", "en-IN", "A", "Ramesh Kirana Store", true)
        )

        // Format B never speaks shop name
        assertEquals(
            "500 rupees received",
            SpeechTemplateBuilder.buildAnnouncement("500", "en-IN", "B", "Ramesh Kirana Store", true)
        )

        // Clean fallback when shop name is empty
        assertEquals(
            "500 rupees received on My U P I",
            SpeechTemplateBuilder.buildAnnouncement("500", "en-IN", "C", "", true)
        )
    }

    @Test
    fun testHindiAndMarathiTemplates() {
        assertEquals(
            "माय यू पी आई पर 500 रुपये प्राप्त हुए",
            SpeechTemplateBuilder.buildAnnouncement("500", "hi-IN", "A")
        )
        assertEquals(
            "500 रुपये प्राप्त हुए",
            SpeechTemplateBuilder.buildAnnouncement("500", "hi-IN", "B")
        )
        assertEquals(
            "माय यू पी आई पर 500 रुपये प्राप्त हुए, Ramesh Store के लिए",
            SpeechTemplateBuilder.buildAnnouncement("500", "hi-IN", "C", "Ramesh Store", true)
        )

        assertEquals(
            "माय यू पी आय वर 500 रुपये मिळाले",
            SpeechTemplateBuilder.buildAnnouncement("500", "mr-IN", "A")
        )
        assertEquals(
            "500 रुपये मिळाले",
            SpeechTemplateBuilder.buildAnnouncement("500", "mr-IN", "B")
        )
        assertEquals(
            "माय यू पी आय वर 500 रुपये मिळाले, Ramesh Store साठी",
            SpeechTemplateBuilder.buildAnnouncement("500", "mr-IN", "C", "Ramesh Store", true)
        )
    }

    @Test
    fun testFullMatrixAllLanguagesAndAmounts() {
        val languages = listOf("en-IN", "hi-IN", "mr-IN", "gu-IN", "ta-IN", "te-IN", "bn-IN", "kn-IN")
        val amounts = listOf("1", "7", "11", "99", "100", "250.50", "1,000", "12,345", "1,00,000")

        for (lang in languages) {
            for (amt in amounts) {
                for (fmt in listOf("A", "B", "C")) {
                    val text = SpeechTemplateBuilder.buildAnnouncement(
                        rawAmount = amt,
                        langCode = lang,
                        format = fmt,
                        merchantName = "Ramesh Store",
                        includeShopName = true
                    )
                    assertTrue("Announcement should not be empty for $lang $amt $fmt", text.isNotEmpty())
                    assertFalse("Should never contain 'Rs.'", text.contains("Rs."))
                    assertFalse("Should never contain '₹'", text.contains("₹"))
                }
            }
        }
    }
}

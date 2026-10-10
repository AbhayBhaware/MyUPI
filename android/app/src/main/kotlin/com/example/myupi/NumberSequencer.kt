package com.example.myupi

// NumberSequencer.kt
//
// Converts monetary amounts into an ordered list of audio clip IDs
// according to the Indian numbering system (crore, lakh, thousand, hundred, 0-99).
//
// Pure Kotlin functions — zero Android framework dependencies — 100% unit testable.

object NumberSequencer {

    val SUPPORTED_LANGUAGES = setOf(
        "en-IN",
        "hi-IN",
        "mr-IN",
        "gu-IN",
        "ta-IN",
        "te-IN",
        "bn-IN",
        "kn-IN"
    )

    /**
     * Converts a raw amount string (e.g. "1", "1,250", "250.50") into a full sequence
     * of clip identifiers for audio playback.
     */
    fun sequencePayment(
        rawAmount: String,
        langCode: String = "en-IN",
        format: String = "A",
        withChime: Boolean = false
    ): List<String> {
        val cleaned = rawAmount.replace(",", "").trim()
        if (cleaned.isEmpty()) return emptyList()

        val parts = cleaned.split(".")
        val rupeeVal = parts[0].toLongOrNull() ?: 0L
        val paiseStr = if (parts.size > 1) parts[1].padEnd(2, '0').take(2) else ""
        val paiseVal = paiseStr.toIntOrNull() ?: 0

        val clips = mutableListOf<String>()

        if (withChime) {
            clips.add("chime")
        }

        val amountClips = sequenceAmount(rupeeVal)
        val rupeeClip = if (langCode == "en-IN" && rupeeVal == 1L) "rupee" else "rupees"

        when (format.uppercase()) {
            "B" -> {
                // Short Format: "<Amount> [rupees] [paise] received"
                clips.addAll(amountClips)
                clips.add(rupeeClip)
                if (paiseVal > 0) {
                    clips.addAll(sequenceAmount(paiseVal.toLong()))
                    clips.add("paise")
                }
                clips.add("received")
            }
            "C" -> {
                // Polite Format: "Payment received, <Amount> [rupees] [paise]. Thank you."
                clips.add("payment_received")
                clips.addAll(amountClips)
                clips.add(rupeeClip)
                if (paiseVal > 0) {
                    clips.addAll(sequenceAmount(paiseVal.toLong()))
                    clips.add("paise")
                }
                clips.add("thank_you")
            }
            else -> {
                // Standard Format (A): "Payment received, <Amount> [rupees] [paise]"
                clips.add("payment_received")
                clips.addAll(amountClips)
                clips.add(rupeeClip)
                if (paiseVal > 0) {
                    clips.addAll(sequenceAmount(paiseVal.toLong()))
                    clips.add("paise")
                }
            }
        }

        return clips
    }

    /**
     * Sequences an arbitrary positive integer into Indian number clip IDs.
     * Pure number representation without currency or phrase tokens.
     */
    fun sequenceAmount(amount: Long): List<String> {
        if (amount == 0L) return listOf("num_0")
        if (amount < 0L) return emptyList()

        val clips = mutableListOf<String>()

        val crores = amount / 10_000_000L
        var remainder = amount % 10_000_000L

        if (crores > 0) {
            clips.addAll(sequenceAmount(crores))
            clips.add("crore")
        }

        val lakhs = remainder / 100_000L
        remainder %= 100_000L
        if (lakhs > 0) {
            clips.addAll(decomposeUnder100(lakhs.toInt()))
            clips.add("lakh")
        }

        val thousands = remainder / 1000L
        remainder %= 1000L
        if (thousands > 0) {
            clips.addAll(decomposeUnder100(thousands.toInt()))
            clips.add("thousand")
        }

        val hundreds = remainder / 100L
        remainder %= 100L
        if (hundreds > 0) {
            clips.add("num_$hundreds")
            clips.add("hundred")
        }

        if (remainder > 0) {
            clips.addAll(decomposeUnder100(remainder.toInt()))
        }

        return clips
    }

    /**
     * Returns clip ID for numbers 0 to 99.
     */
    private fun decomposeUnder100(value: Int): List<String> {
        return if (value in 0..99) {
            listOf("num_$value")
        } else {
            emptyList()
        }
    }

    /**
     * Sample test sequence for settings audio preview.
     */
    fun sequenceTest(langCode: String = "en-IN", withChime: Boolean = false): List<String> {
        val clips = mutableListOf<String>()
        if (withChime) clips.add("chime")
        clips.add("payment_received")
        clips.add("num_1")
        clips.add("hundred")
        clips.add(if (langCode == "en-IN") "rupees" else "rupees")
        return clips
    }
}

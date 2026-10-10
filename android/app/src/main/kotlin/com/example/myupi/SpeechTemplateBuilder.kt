package com.example.myupi

// SpeechTemplateBuilder.kt
//
// Pure Kotlin speech template builder for MyUPI Soundbox announcements.
// Mirrors lib/utils/speech_template_builder.dart for 100% parity across
// native background speech and Flutter UI previews.

object SpeechTemplateBuilder {

    val brandNames = mapOf(
        "en-IN" to "My U P I",
        "hi-IN" to "माय यू पी आई",
        "mr-IN" to "माय यू पी आय",
        "gu-IN" to "માય યુ પી આઈ",
        "ta-IN" to "மை யூ பி ஐ",
        "te-IN" to "మై యు పి ఐ",
        "bn-IN" to "মাই ইউ পি আই",
        "kn-IN" to "ಮೈ ಯು ಪಿ ಐ"
    )

    /**
     * Sanitizes merchant shop names for TTS:
     * - Replaces '&' with 'and'
     * - Strips emojis and punctuation symbols
     * - Collapses repeated spaces
     * - Caps at ~30 characters / 4–5 words at a clean word boundary
     */
    fun sanitizeShopName(raw: String): String {
        if (raw.trim().isEmpty()) return ""

        // 1. Replace '&' with 'and'
        var s = raw.replace("&", " and ")

        // 2. Strip emojis, symbols, keeping letters, digits, whitespace, hyphen
        s = s.replace(Regex("[^\\p{L}\\p{N}\\s\\-]"), " ")

        // 3. Collapse multiple spaces
        s = s.replace(Regex("\\s+"), " ").trim()
        if (s.isEmpty()) return ""

        // 4. Cap at ~30 characters or 5 words at word boundary
        val words = s.split(" ")
        val cappedWords = mutableListOf<String>()
        var charCount = 0

        for (word in words) {
            if (cappedWords.size >= 5) break
            val addedLen = if (cappedWords.isEmpty()) word.length else word.length + 1
            if (charCount + addedLen > 30 && cappedWords.isNotEmpty()) break
            cappedWords.add(word)
            charCount += addedLen
        }

        return cappedWords.joinToString(" ").trim()
    }

    /**
     * Converts a numeric amount string into localized spoken words.
     * Always speaks "rupee/rupees", never "Rs." or "₹".
     * Handles paise when present; omits paise when zero.
     */
    fun formatSpokenAmount(rawAmount: String, langCode: String): String {
        val cleaned = rawAmount.replace(",", "").trim()
        if (cleaned.isEmpty()) return ""

        val parts = cleaned.split(".")
        val rupeeInt = parts[0].toLongOrNull() ?: 0L
        val rupeeDisplay = parts[0]
        val paiseStr = if (parts.size > 1) parts[1].padEnd(2, '0').take(2) else null
        val paiseInt = paiseStr?.toIntOrNull() ?: 0

        return when (langCode) {
            "hi-IN" -> if (paiseInt > 0) "$rupeeDisplay रुपये $paiseInt पैसे" else "$rupeeDisplay रुपये"
            "mr-IN" -> if (paiseInt > 0) "$rupeeDisplay रुपये $paiseInt पैसे" else "$rupeeDisplay रुपये"
            "gu-IN" -> if (paiseInt > 0) "$rupeeDisplay રૂપિયા $paiseInt પૈસા" else "$rupeeDisplay રૂપિયા"
            "ta-IN" -> if (paiseInt > 0) "$rupeeDisplay ரூபாய் $paiseInt காசுகள்" else "$rupeeDisplay ரூபாய்"
            "te-IN" -> if (paiseInt > 0) "$rupeeDisplay రూపాయలు $paiseInt పైసలు" else "$rupeeDisplay రూపాయలు"
            "bn-IN" -> if (paiseInt > 0) "$rupeeDisplay টাকা $paiseInt পয়সা" else "$rupeeDisplay টাকা"
            "kn-IN" -> if (paiseInt > 0) "$rupeeDisplay ರೂಪಾಯಿ $paiseInt ಪೈಸೆ" else "$rupeeDisplay ರೂಪಾಯಿ"
            else -> {
                val rupeeWord = if (rupeeInt == 1L) "rupee" else "rupees"
                if (paiseInt > 0) "$rupeeDisplay $rupeeWord $paiseInt paise" else "$rupeeDisplay $rupeeWord"
            }
        }
    }

    /**
     * Builds the complete announcement sentence.
     */
    fun buildAnnouncement(
        rawAmount: String,
        langCode: String = "en-IN",
        format: String = "A",
        merchantName: String = "",
        includeShopName: Boolean = false
    ): String {
        val amountText = formatSpokenAmount(rawAmount, langCode)
        if (amountText.isEmpty()) return "Payment received"

        val brand = brandNames[langCode] ?: brandNames["en-IN"]!!
        val sanitizedShop = sanitizeShopName(merchantName)
        val hasShop = includeShopName && sanitizedShop.isNotEmpty()

        val effectiveFormat = when (format.uppercase()) {
            "B" -> "B"
            "C" -> if (hasShop) "C" else "A"
            else -> if (hasShop) "C" else "A"
        }

        return when (langCode) {
            "hi-IN" -> when (effectiveFormat) {
                "B" -> "$amountText प्राप्त हुए"
                "C" -> "$brand पर $amountText प्राप्त हुए, $sanitizedShop के लिए"
                else -> "$brand पर $amountText प्राप्त हुए"
            }
            "mr-IN" -> when (effectiveFormat) {
                "B" -> "$amountText मिळाले"
                "C" -> "$brand वर $amountText मिळाले, $sanitizedShop साठी"
                else -> "$brand वर $amountText मिळाले"
            }
            "gu-IN" -> when (effectiveFormat) {
                "B" -> "$amountText પ્રાપ્ત થયા"
                "C" -> "$brand પર $amountText પ્રાપ્ત થયા, $sanitizedShop માટે"
                else -> "$brand પર $amountText પ્રાપ્ત થયા"
            }
            "ta-IN" -> when (effectiveFormat) {
                "B" -> "$amountText பெறப்பட்டது"
                "C" -> "$brand இல் $amountText பெறப்பட்டது, $sanitizedShop க்காக"
                else -> "$brand இல் $amountText பெறப்பட்டது"
            }
            "te-IN" -> when (effectiveFormat) {
                "B" -> "$amountText అందాయి"
                "C" -> "$brand పై $amountText అందాయి, $sanitizedShop కొరకు"
                else -> "$brand పై $amountText అందాయి"
            }
            "bn-IN" -> when (effectiveFormat) {
                "B" -> "$amountText পাওয়া গেছে"
                "C" -> "$brand এ $amountText পাওয়া গেছে, $sanitizedShop এর জন্য"
                else -> "$brand এ $amountText পাওয়া গেছে"
            }
            "kn-IN" -> when (effectiveFormat) {
                "B" -> "$amountText ಸ್ವೀಕರಿಸಲಾಗಿದೆ"
                "C" -> "$brand ನಲ್ಲಿ $amountText ಸ್ವೀಕರಿಸಲಾಗಿದೆ, $sanitizedShop ಗಾಗಿ"
                else -> "$brand ನಲ್ಲಿ $amountText ಸ್ವೀಕರಿಸಲಾಗಿದೆ"
            }
            else -> when (effectiveFormat) {
                "B" -> "$amountText received"
                "C" -> "$amountText received on $brand for $sanitizedShop"
                else -> "$amountText received on $brand"
            }
        }
    }

    /**
     * Builds the test announcement sentence.
     */
    fun buildTestSpeech(
        langCode: String = "en-IN",
        format: String = "A",
        merchantName: String = "",
        includeShopName: Boolean = false
    ): String {
        return buildAnnouncement(
            rawAmount = "100",
            langCode = langCode,
            format = format,
            merchantName = merchantName,
            includeShopName = includeShopName
        )
    }
}

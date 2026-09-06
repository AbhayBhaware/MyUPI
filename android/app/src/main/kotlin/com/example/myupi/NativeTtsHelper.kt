package com.example.myupi

// NativeTtsHelper.kt
//
// Native Android Text-to-Speech for MyUPI background Soundbox.
// -------------------------------------------------------------
// Uses android.speech.tts.TextToSpeech — no Flutter engine required.
//
// Design:
//   • Singleton lifecycle tied to NotificationListenerService.
//   • Initializes asynchronously; queues speech until ready.
//   • Language: en-IN → en-US → en-GB → default English fallback.
//   • FIFO queue — rapid payments announced sequentially, no overlap.
//   • All methods safe to call before init completes (items are queued).
//   • shutdown() releases engine on service destroy.

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import java.util.LinkedList
import java.util.Locale
import java.util.UUID

private const val TAG = "MyUPI_BACKGROUND"

class NativeTtsHelper(context: Context) : TextToSpeech.OnInitListener {

    private val tts: TextToSpeech = TextToSpeech(context.applicationContext, this)
    private var isReady = false
    private val pendingQueue: LinkedList<String> = LinkedList()

    init {
        // Register utterance listener for sequential queue processing.
        tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {
                Log.d(TAG, "TTS speaking utterance: $utteranceId")
            }

            override fun onDone(utteranceId: String?) {
                Log.d(TAG, "TTS utterance done: $utteranceId")
            }

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                Log.e(TAG, "TTS utterance error: $utteranceId")
            }

            override fun onError(utteranceId: String?, errorCode: Int) {
                Log.e(TAG, "TTS utterance error: $utteranceId code=$errorCode")
            }
        })
    }

    // ── TextToSpeech.OnInitListener ──────────────────────────────────────────

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            val lang = SharedPreferencesManager.getLanguage()
            setLanguageWithFallback(lang)
            // Read persisted speech speed (Slow/Normal/Fast).
            tts.setSpeechRate(SharedPreferencesManager.getSpeechRate())
            tts.setPitch(1.0f)
            isReady = true
            Log.d(TAG, "TTS initialized successfully (rate=${SharedPreferencesManager.getSpeechRate()}).")
            drainQueue()             // speak anything that was queued before init
        } else {
            Log.e(TAG, "TTS initialization failed (status=$status). Background TTS unavailable.")
        }
    }

    // ── Language setup ───────────────────────────────────────────────────────

    fun isLanguageAvailable(langCode: String): Boolean {
        if (!isReady) return false
        val parts = langCode.split("-")
        val locale = if (parts.size == 2) Locale(parts[0], parts[1]) else Locale(langCode)
        val result = tts.isLanguageAvailable(locale)
        return result != TextToSpeech.LANG_MISSING_DATA && result != TextToSpeech.LANG_NOT_SUPPORTED
    }

    private fun setLanguageWithFallback(langCode: String) {
        val parts = langCode.split("-")
        val targetLocale = if (parts.size == 2) Locale(parts[0], parts[1]) else Locale(langCode)
        
        val candidates = listOf(
            targetLocale,
            Locale("en", "IN"),
            Locale.US,
            Locale.UK,
            Locale.ENGLISH,
        )
        for (locale in candidates) {
            val result = tts.setLanguage(locale)
            if (result != TextToSpeech.LANG_MISSING_DATA &&
                result != TextToSpeech.LANG_NOT_SUPPORTED) {
                Log.d(TAG, "TTS language set to: $locale")
                return
            }
        }
        Log.w(TAG, "TTS: No suitable language found — using device default.")
    }

    /**
     * Apply a new language immediately (called after user changes language setting).
     */
    fun updateLanguage() {
        if (!isReady) return
        val lang = SharedPreferencesManager.getLanguage()
        setLanguageWithFallback(lang)
    }

    // ── Public API ───────────────────────────────────────────────────────────

    /**
     * Speak a payment announcement built from the raw extracted amount.
     *
     * Only call this after KotlinUpiDetector has confirmed isPayment == true
     * AND amount is non-null.
     */
    fun speakPayment(rawAmount: String) {
        val text = buildPaymentSpeech(rawAmount)
        Log.d(TAG, "TTS speaking: \"$text\"")
        enqueue(text)
    }

    /**
     * Speak an arbitrary test string to preview current config.
     */
    fun speakTest() {
        val text = buildTestSpeech()
        Log.d(TAG, "TTS test: \"$text\"")
        enqueue(text)
    }

    /**
     * Apply a new speech rate immediately (called after user changes speed setting).
     */
    fun updateSpeechRate() {
        val rate = SharedPreferencesManager.getSpeechRate()
        try {
            tts.setSpeechRate(rate)
            Log.d(TAG, "TTS speech rate updated to: $rate")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update speech rate: ${e.message}")
        }
    }

    /** Release the TTS engine. Call from NotificationListenerService.onDestroy(). */
    fun shutdown() {
        try {
            tts.stop()
            tts.shutdown()
            Log.d(TAG, "TTS shut down.")
        } catch (e: Exception) {
            Log.e(TAG, "TTS shutdown error: ${e.message}")
        }
    }

    // ── Speech text builder ──────────────────────────────────────────────────

    companion object {
        /**
         * Converts a raw amount string to a speech-friendly sentence.
         *
         *   "1"      → "Payment received, 1 rupee"
         *   "10"     → "Payment received, 10 rupees"
         *   "500"    → "Payment received, 500 rupees"
         *   "1,250"  → "Payment received, 1,250 rupees"
         *   "25.50"  → "Payment received, 25 rupees 50 paise"
         */
        fun buildPaymentSpeech(rawAmount: String): String {
            val cleaned = rawAmount.replace(",", "").trim()
            if (cleaned.isEmpty()) return "Payment received"

            val parts = cleaned.split(".")
            val rupeeInt = parts[0].toIntOrNull() ?: 0
            val paiseStr = if (parts.size > 1) parts[1].padEnd(2, '0').take(2) else null
            val paiseInt = paiseStr?.toIntOrNull() ?: 0

            val rupeeDisplay = rawAmount.split(".")[0]

            val lang = SharedPreferencesManager.getLanguage()
            val formatType = SharedPreferencesManager.getAnnouncementFormat()
            val includeShopName = SharedPreferencesManager.isIncludeShopNameEnabled()
            val merchantName = SharedPreferencesManager.getMerchantName()

            // Construct amount text in localized format
            val amountText = when (lang) {
                "hi-IN" -> if (paiseInt > 0) "$rupeeDisplay रुपये $paiseInt पैसे" else "$rupeeDisplay रुपये"
                "mr-IN" -> if (paiseInt > 0) "$rupeeDisplay रुपये $paiseInt पैसे" else "$rupeeDisplay रुपये"
                "gu-IN" -> if (paiseInt > 0) "$rupeeDisplay રૂપિયા $paiseInt પૈસા" else "$rupeeDisplay રૂપિયા"
                "ta-IN" -> if (paiseInt > 0) "$rupeeDisplay ரூபாய் $paiseInt காசுகள்" else "$rupeeDisplay ரூபாய்"
                "te-IN" -> if (paiseInt > 0) "$rupeeDisplay రూపాయలు $paiseInt పైసలు" else "$rupeeDisplay రూపాయలు"
                "bn-IN" -> if (paiseInt > 0) "$rupeeDisplay টাকা $paiseInt পয়সা" else "$rupeeDisplay টাকা"
                "kn-IN" -> if (paiseInt > 0) "$rupeeDisplay ರೂಪಾಯಿ $paiseInt ಪೈಸೆ" else "$rupeeDisplay ರೂಪಾಯಿ"
                else -> { // en-IN fallback
                    val rupeeWord = if (rupeeInt == 1) "rupee" else "rupees"
                    if (paiseInt > 0) "$rupeeDisplay $rupeeWord $paiseInt paise" else "$rupeeDisplay $rupeeWord"
                }
            }

            var sentence = ""
            val shop = if (includeShopName && merchantName.isNotBlank()) merchantName else ""

            when (lang) {
                "hi-IN" -> {
                    sentence = when (formatType) {
                        "B" -> "$amountText प्राप्त हुए।"
                        "C" -> "पेमेंट प्राप्त हुआ, $amountText। धन्यवाद।"
                        else -> "पेमेंट प्राप्त हुआ, $amountText।"
                    }
                    if (shop.isNotEmpty()) sentence = "$shop पर $sentence"
                }
                "mr-IN" -> {
                    sentence = when (formatType) {
                        "B" -> "$amountText प्राप्त झाले."
                        "C" -> "पेमेंट प्राप्त झाले, $amountText. धन्यवाद."
                        else -> "पेमेंट प्राप्त झाले, $amountText."
                    }
                    if (shop.isNotEmpty()) sentence = "$shop वर $sentence"
                }
                "gu-IN" -> {
                    sentence = when (formatType) {
                        "B" -> "$amountText પ્રાપ્ત થયા."
                        "C" -> "પેમેન્ટ પ્રાપ્ત થયું, $amountText. આભાર."
                        else -> "પેમેન્ટ પ્રાપ્ત થયું, $amountText."
                    }
                    if (shop.isNotEmpty()) sentence = "$shop પર $sentence"
                }
                "ta-IN" -> {
                    sentence = when (formatType) {
                        "B" -> "$amountText பெறப்பட்டது."
                        "C" -> "பணம் பெறப்பட்டது, $amountText. நன்றி."
                        else -> "பணம் பெறப்பட்டது, $amountText."
                    }
                    if (shop.isNotEmpty()) sentence = "$shop இல் $sentence"
                }
                "te-IN" -> {
                    sentence = when (formatType) {
                        "B" -> "$amountText అందాయి."
                        "C" -> "చెల్లింపు అందింది, $amountText. ధన్యవాదాలు."
                        else -> "చెల్లింపు అందింది, $amountText."
                    }
                    if (shop.isNotEmpty()) sentence = "$shop వద్ద $sentence"
                }
                "bn-IN" -> {
                    sentence = when (formatType) {
                        "B" -> "$amountText পাওয়া গেছে।"
                        "C" -> "পেমেন্ট পাওয়া গেছে, $amountText। ধন্যবাদ।"
                        else -> "পেমেন্ট পাওয়া গেছে, $amountText।"
                    }
                    if (shop.isNotEmpty()) sentence = "$shop এ $sentence"
                }
                "kn-IN" -> {
                    sentence = when (formatType) {
                        "B" -> "$amountText ಸ್ವೀಕರಿಸಲಾಗಿದೆ."
                        "C" -> "ಪಾವತಿ ಸ್ವೀಕರಿಸಲಾಗಿದೆ, $amountText. ಧನ್ಯವಾದಗಳು."
                        else -> "ಪಾವತಿ ಸ್ವೀಕರಿಸಲಾಗಿದೆ, $amountText."
                    }
                    if (shop.isNotEmpty()) sentence = "$shop ನಲ್ಲಿ $sentence"
                }
                else -> { // en-IN
                    sentence = when (formatType) {
                        "B" -> "$amountText received"
                        "C" -> "Payment received, $amountText. Thank you."
                        else -> "Payment received, $amountText"
                    }
                    if (shop.isNotEmpty()) {
                        if (sentence.endsWith(".")) {
                            sentence = sentence.dropLast(1) + " at $shop."
                        } else {
                            sentence += " at $shop."
                        }
                    }
                }
            }

            return sentence
        }

        fun buildTestSpeech(): String {
            return when (SharedPreferencesManager.getLanguage()) {
                "hi-IN" -> "यह MyUPI साउंडबॉक्स का परीक्षण है।"
                "mr-IN" -> "हा MyUPI साउंडबॉक्सचा चाचणी संदेश आहे."
                "gu-IN" -> "આ MyUPI સાઉન્ડબોક્સનું પરીક્ષણ છે."
                "ta-IN" -> "இது MyUPI சவுண்ட்பாக்ஸ் சோதனை."
                "te-IN" -> "ఇది MyUPI సౌండ్‌బాక్స్ పరీక్ష."
                "bn-IN" -> "এটি MyUPI সাউন্ডবক্সের একটি পরীক্ষা।"
                "kn-IN" -> "ಇದು MyUPI ಸೌಂಡ್‌ಬಾಕ್ಸ್ ಪರೀಕ್ಷೆ."
                else -> "This is a MyUPI soundbox test."
            }
        }
    }

    // ── Queue management ─────────────────────────────────────────────────────

    @Synchronized
    private fun enqueue(text: String) {
        if (pendingQueue.size >= 10) {
            Log.w(TAG, "TTS queue full — dropping announcement to prevent unbounded memory growth.")
            return
        }
        pendingQueue.add(text)
        if (isReady) {
            drainQueue()
        }
        // If not ready yet, items stay in queue until onInit fires drainQueue().
    }

    @Synchronized
    private fun drainQueue() {
        if (!isReady) return
        while (pendingQueue.isNotEmpty()) {
            val text = pendingQueue.poll() ?: break
            val utteranceId = "myupi_${UUID.randomUUID()}"
            try {
                // Use QUEUE_ADD to append cleanly to the hardware TTS queue
                tts.speak(text, TextToSpeech.QUEUE_ADD, null, utteranceId)
            } catch (e: Exception) {
                Log.e(TAG, "TTS speak error: ${e.message}")
            }
        }
    }
}

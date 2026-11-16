package com.myupi.soundbox

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

class NativeTtsHelper(private val context: Context) : TextToSpeech.OnInitListener {

    private val tts: TextToSpeech = TextToSpeech(context.applicationContext, this)
    @Volatile
    private var isReady = false
    private val initLatch = java.util.concurrent.CountDownLatch(1)
    private val pendingQueue: LinkedList<String> = LinkedList()

    private fun isHumanVoiceEnabled(): Boolean {
        return try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.getBoolean("flutter.human_voice_enabled", false)
        } catch (e: Exception) {
            false
        }
    }

    private fun isChimeEnabled(): Boolean {
        return try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.getBoolean("flutter.soundbox_chime_enabled", true)
        } catch (e: Exception) {
            true
        }
    }

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
        try {
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
        } finally {
            initLatch.countDown()
        }
    }

    // ── Language setup ───────────────────────────────────────────────────────

    fun isLanguageAvailable(langCode: String): Boolean {
        // 1. If human-voice offline pack exists for this language, it is guaranteed available
        if (ClipAnnouncer.isPackAvailable(context, langCode)) {
            return true
        }

        // 2. Wait up to 1500 ms for TTS engine to initialize if not ready
        if (!isReady) {
            try {
                initLatch.await(1500, java.util.concurrent.TimeUnit.MILLISECONDS)
            } catch (_: InterruptedException) {}
        }

        if (!isReady) {
            // If TTS engine is still not ready, check if it's one of the supported Indic languages
            return SpeechTemplateBuilder.brandNames.containsKey(langCode)
        }

        val parts = langCode.split("-")
        val fullLocale = if (parts.size == 2) Locale(parts[0], parts[1]) else Locale(langCode)
        val langOnlyLocale = Locale(parts[0])

        val fullRes = tts.isLanguageAvailable(fullLocale)
        if (fullRes >= TextToSpeech.LANG_AVAILABLE || fullRes == TextToSpeech.LANG_MISSING_DATA) {
            return true
        }

        val langRes = tts.isLanguageAvailable(langOnlyLocale)
        if (langRes >= TextToSpeech.LANG_AVAILABLE || langRes == TextToSpeech.LANG_MISSING_DATA) {
            return true
        }

        return SpeechTemplateBuilder.brandNames.containsKey(langCode)
    }

    private fun setLanguageWithFallback(langCode: String) {
        val parts = langCode.split("-")
        val targetLocale = if (parts.size == 2) Locale(parts[0], parts[1]) else Locale(langCode)
        val langOnlyLocale = Locale(parts[0])
        
        val candidates = listOf(
            targetLocale,
            langOnlyLocale,
            Locale("en", "IN"),
            Locale.US,
            Locale.UK,
            Locale.ENGLISH,
        )
        for (locale in candidates) {
            val result = tts.setLanguage(locale)
            if (result >= TextToSpeech.LANG_AVAILABLE) {
                Log.d(TAG, "TTS language set to: $locale")
                return
            } else if (result == TextToSpeech.LANG_MISSING_DATA && (locale == targetLocale || locale == langOnlyLocale)) {
                Log.d(TAG, "TTS language set to: $locale (voice data downloading/missing)")
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
        val lang = SharedPreferencesManager.getLanguage()
        val includeShopName = SharedPreferencesManager.isIncludeShopNameEnabled()
        val merchantName = SharedPreferencesManager.getMerchantName()
        val hasShopName = includeShopName && merchantName.isNotBlank()

        // Guarded Human Voice path (Section 4):
        // Active when humanVoiceEnabled is ON, shop name is NOT enabled (v1 rule),
        // and voice pack exists for the active language.
        if (!hasShopName && isHumanVoiceEnabled() && ClipAnnouncer.isPackAvailable(context, lang)) {
            try {
                val formatType = SharedPreferencesManager.getAnnouncementFormat()
                val withChime = isChimeEnabled()
                val success = ClipAnnouncer.playPayment(context, rawAmount, lang, formatType, withChime)
                if (success) {
                    Log.d(TAG, "ClipAnnouncer played human-voice payment for $rawAmount ($lang)")
                    return
                }
            } catch (e: Exception) {
                Log.e(TAG, "ClipAnnouncer error, falling back to system TTS: ${e.message}", e)
            }
        }

        // Standard system TTS path (guaranteed never silent)
        val text = buildPaymentSpeech(rawAmount)
        Log.d(TAG, "TTS speaking: \"$text\"")
        enqueue(text)
    }

    /**
     * Speak an arbitrary test string to preview current config.
     */
    fun speakTest() {
        val lang = SharedPreferencesManager.getLanguage()
        if (isHumanVoiceEnabled() && ClipAnnouncer.isPackAvailable(context, lang)) {
            try {
                val withChime = isChimeEnabled()
                val success = ClipAnnouncer.playTest(context, lang, withChime)
                if (success) {
                    Log.d(TAG, "ClipAnnouncer played human-voice test preview ($lang)")
                    return
                }
            } catch (e: Exception) {
                Log.e(TAG, "ClipAnnouncer test preview error, falling back to TTS: ${e.message}", e)
            }
        }

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

    /** Release the TTS engine. */
    fun shutdown() {
        try {
            tts.stop()
            tts.shutdown()
            isReady = false
            synchronized(NativeTtsHelper::class.java) {
                if (instance == this) {
                    instance = null
                }
            }
            Log.d(TAG, "TTS shut down.")
        } catch (e: Exception) {
            Log.e(TAG, "TTS shutdown error: ${e.message}")
        }
    }

    // ── Speech text builder & Singleton ──────────────────────────────────────

    companion object {
        @Volatile
        private var instance: NativeTtsHelper? = null

        fun getInstance(context: Context): NativeTtsHelper {
            return instance ?: synchronized(this) {
                instance ?: NativeTtsHelper(context.applicationContext).also { instance = it }
            }
        }

        fun buildPaymentSpeech(rawAmount: String): String {
            val lang = SharedPreferencesManager.getLanguage()
            val formatType = SharedPreferencesManager.getAnnouncementFormat()
            val includeShopName = SharedPreferencesManager.isIncludeShopNameEnabled()
            val merchantName = SharedPreferencesManager.getMerchantName()

            return SpeechTemplateBuilder.buildAnnouncement(
                rawAmount = rawAmount,
                langCode = lang,
                format = formatType,
                merchantName = merchantName,
                includeShopName = includeShopName
            )
        }

        fun buildTestSpeech(): String {
            val lang = SharedPreferencesManager.getLanguage()
            val formatType = SharedPreferencesManager.getAnnouncementFormat()
            val includeShopName = SharedPreferencesManager.isIncludeShopNameEnabled()
            val merchantName = SharedPreferencesManager.getMerchantName()

            return SpeechTemplateBuilder.buildTestSpeech(
                langCode = lang,
                format = formatType,
                merchantName = merchantName,
                includeShopName = includeShopName
            )
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

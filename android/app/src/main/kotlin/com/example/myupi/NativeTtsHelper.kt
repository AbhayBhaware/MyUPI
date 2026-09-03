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
                drainQueue()
            }

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                Log.e(TAG, "TTS utterance error: $utteranceId")
                drainQueue()
            }

            override fun onError(utteranceId: String?, errorCode: Int) {
                Log.e(TAG, "TTS utterance error: $utteranceId code=$errorCode")
                drainQueue()
            }
        })
    }

    // ── TextToSpeech.OnInitListener ──────────────────────────────────────────

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            setLanguageWithFallback()
            tts.setSpeechRate(0.9f)   // slightly slower than default for clarity
            tts.setPitch(1.0f)
            isReady = true
            Log.d(TAG, "TTS initialized successfully.")
            drainQueue()             // speak anything that was queued before init
        } else {
            Log.e(TAG, "TTS initialization failed (status=$status). Background TTS unavailable.")
        }
    }

    // ── Language setup ───────────────────────────────────────────────────────

    private fun setLanguageWithFallback() {
        val candidates = listOf(
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
        Log.w(TAG, "TTS: No suitable English language found — using device default.")
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
     * Speak an arbitrary test string (called from the Flutter Test Soundbox button
     * via MethodChannel when the app prefers native TTS for consistency).
     */
    fun speakTest(text: String = "This is a MyUPI soundbox test.") {
        Log.d(TAG, "TTS test: \"$text\"")
        enqueue(text)
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
            // Remove commas for numeric parsing, but keep original for speech
            // so "1,250" is said naturally by the TTS engine.
            val cleaned = rawAmount.replace(",", "").trim()
            if (cleaned.isEmpty()) return "Payment received"

            val parts = cleaned.split(".")
            val rupeeInt = parts[0].toIntOrNull() ?: 0
            val paiseStr = if (parts.size > 1) parts[1].padEnd(2, '0').take(2) else null
            val paiseInt = paiseStr?.toIntOrNull() ?: 0

            val rupeeWord = if (rupeeInt == 1) "rupee" else "rupees"

            return if (paiseInt > 0) {
                // Use original comma-formatted rupee part for natural TTS pronunciation
                val rupeeDisplay = rawAmount.split(".")[0]
                "Payment received, $rupeeDisplay $rupeeWord $paiseInt paise"
            } else {
                // Use original comma-formatted amount for natural pronunciation
                val amtDisplay = rawAmount.split(".")[0]
                "Payment received, $amtDisplay $rupeeWord"
            }
        }
    }

    // ── Queue management ─────────────────────────────────────────────────────

    @Synchronized
    private fun enqueue(text: String) {
        pendingQueue.add(text)
        if (isReady && pendingQueue.size == 1) {
            drainQueue()
        }
        // If not ready yet, items stay in queue until onInit fires drainQueue().
    }

    @Synchronized
    private fun drainQueue() {
        if (!isReady || pendingQueue.isEmpty()) return
        val text = pendingQueue.poll() ?: return
        val utteranceId = "myupi_${UUID.randomUUID()}"
        try {
            tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
        } catch (e: Exception) {
            Log.e(TAG, "TTS speak error: ${e.message}")
        }
    }
}

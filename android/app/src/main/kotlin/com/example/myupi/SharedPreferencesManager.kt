package com.example.myupi

// SharedPreferencesManager.kt
//
// Central persistent storage for MyUPI background Soundbox.
// ----------------------------------------------------------
// Manages:
//   • Soundbox ON/OFF setting
//   • Speech speed setting (Slow/Normal/Fast)
//   • Payment history (up to MAX_HISTORY_SIZE records)
//
// All data is stored in Android SharedPreferences so it is:
//   • Accessible from NotificationListenerService (no Flutter required)
//   • Persistent across app closes and device restarts
//   • Thread-safe (commit vs apply)
//
// History records store only: amount, appName, timestampMs.
// NO UPI IDs, bank accounts, phone numbers, or notification text are stored.

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

private const val TAG = "MyUPI_BACKGROUND"

private const val PREFS_NAME        = "myupi_prefs"
private const val KEY_SOUNDBOX_ON   = "soundbox_enabled"
private const val KEY_SPEECH_SPEED  = "speech_speed"   // "slow" | "normal" | "fast"
private const val KEY_HISTORY       = "payment_history" // JSON array
private const val MAX_HISTORY_SIZE  = 1000

// ─── Data class for a payment history record ──────────────────────────────────

data class PaymentRecord(
    val amount: String,
    val appName: String,
    val timestampMs: Long,
)

// ─── Manager singleton ────────────────────────────────────────────────────────

object SharedPreferencesManager {

    private lateinit var prefs: SharedPreferences

    /** Must be called once before any other method (e.g. in onCreate of service or app). */
    fun init(context: Context) {
        prefs = context.applicationContext
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    // ── Soundbox ON/OFF ───────────────────────────────────────────────────────

    /** Returns true if Soundbox is enabled (default: true). */
    fun isSoundboxEnabled(): Boolean = prefs.getBoolean(KEY_SOUNDBOX_ON, true)

    fun setSoundboxEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_SOUNDBOX_ON, enabled).apply()
        Log.d(TAG, "Soundbox enabled: $enabled")
    }

    // ── Speech speed ──────────────────────────────────────────────────────────

    /** Returns "slow", "normal", or "fast" (default: "normal"). */
    fun getSpeechSpeed(): String = prefs.getString(KEY_SPEECH_SPEED, "normal") ?: "normal"

    fun setSpeechSpeed(speed: String) {
        require(speed in listOf("slow", "normal", "fast")) {
            "Invalid speech speed: $speed. Must be slow, normal, or fast."
        }
        prefs.edit().putString(KEY_SPEECH_SPEED, speed).apply()
        Log.d(TAG, "Speech speed: $speed")
    }

    /** Converts speech speed string to a float rate for TextToSpeech. */
    fun getSpeechRate(): Float = when (getSpeechSpeed()) {
        "slow"   -> 0.65f
        "fast"   -> 1.2f
        else     -> 0.9f   // "normal"
    }

    // ── Payment history ───────────────────────────────────────────────────────

    /**
     * Add a new payment record to history.
     * If MAX_HISTORY_SIZE is exceeded, the oldest records are trimmed.
     * Duplicate protection is handled by the caller (seenKeys in the service).
     */
    @Synchronized
    fun addPayment(amount: String, appName: String) {
        val list = loadHistoryList().toMutableList()
        val record = JSONObject().apply {
            put("amount", amount)
            put("appName", appName)
            put("timestampMs", System.currentTimeMillis())
        }
        // Insert at front (newest first).
        list.add(0, record)
        // Trim if over limit.
        val trimmed = if (list.size > MAX_HISTORY_SIZE) list.take(MAX_HISTORY_SIZE) else list
        val arr = JSONArray().apply { trimmed.forEach { put(it) } }
        prefs.edit().putString(KEY_HISTORY, arr.toString()).apply()
        Log.d(TAG, "Payment history saved: ₹$amount from $appName (total: ${trimmed.size})")
    }

    /**
     * Load all payment history records, newest first.
     */
    @Synchronized
    fun getHistory(): List<PaymentRecord> {
        return loadHistoryList().mapNotNull { obj ->
            try {
                PaymentRecord(
                    amount      = obj.getString("amount"),
                    appName     = obj.getString("appName"),
                    timestampMs = obj.getLong("timestampMs"),
                )
            } catch (e: Exception) {
                Log.w(TAG, "Skipping malformed history record: ${e.message}")
                null
            }
        }
    }

    /**
     * Delete all payment history records.
     * Settings (soundbox enabled, speech speed) are NOT affected.
     */
    @Synchronized
    fun clearHistory() {
        prefs.edit().remove(KEY_HISTORY).apply()
        Log.d(TAG, "Payment history cleared.")
    }

    // ── Internal helpers ──────────────────────────────────────────────────────

    private fun loadHistoryList(): List<JSONObject> {
        val json = prefs.getString(KEY_HISTORY, "[]") ?: "[]"
        return try {
            val arr = JSONArray(json)
            (0 until arr.length()).map { arr.getJSONObject(it) }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse payment history JSON: ${e.message}")
            emptyList()
        }
    }
}

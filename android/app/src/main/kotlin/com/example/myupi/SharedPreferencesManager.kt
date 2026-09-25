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

private const val PREFS_NAME            = "myupi_prefs"
private const val KEY_SOUNDBOX_ON       = "soundbox_enabled"
private const val KEY_SPEECH_SPEED      = "speech_speed"   // "slow" | "normal" | "fast"
private const val KEY_MERCHANT_NAME     = "merchant_name"
private const val KEY_ANNOUNCE_FORMAT   = "announce_format" // "A" | "B" | "C"
private const val KEY_INCLUDE_SHOP_NAME = "include_shop_name" // bool
private const val KEY_LANGUAGE          = "language" // e.g. "en-IN"
private const val KEY_HISTORY           = "payment_history" // JSON array
private const val KEY_MERCHANT_ID      = "merchant_id"
private const val KEY_ONBOARDING        = "onboarding_completed" // bool
private const val KEY_SUBSCRIPTION_STATE = "subscription_state" // "INTRO_OFFER_AVAILABLE", etc.
private const val MAX_HISTORY_SIZE      = 1000

// ─── Data class for a payment history record ──────────────────────────────────

data class PaymentRecord(
    val amount: String,
    val appName: String,
    val trustLevel: String,
    val timestampMs: Long,
    val verificationStatus: String = "NOT_VERIFIED",
    val source: String = "NOTIFICATION",
    val parserVersion: Int = 1,
)

// ─── Record Result for Single Gatekeeper Ledger Writes ────────────────────────

sealed class RecordResult {
    data class Fresh(val record: PaymentRecord) : RecordResult()
    data class Merged(
        val updatedRecord: PaymentRecord,
        val originalSource: String,
        val originalLabel: String,
    ) : RecordResult()
    data class DuplicateIgnored(val reason: String) : RecordResult()
}

// ─── Manager singleton ────────────────────────────────────────────────────────

object SharedPreferencesManager {

    private lateinit var prefs: SharedPreferences

    /**
     * Normalizes amount string (e.g. "₹199", "199.00", "1,000") to numeric Double.
     * Returns null if unparseable.
     */
    fun normalizeAmount(amountStr: String?): Double? {
        if (amountStr.isNullOrBlank()) return null
        val clean = amountStr
            .replace("₹", "")
            .replace("Rs.", "", ignoreCase = true)
            .replace("Rs", "", ignoreCase = true)
            .replace("INR", "", ignoreCase = true)
            .replace(",", "")
            .trim()
        return clean.toDoubleOrNull()
    }

    /**
     * Numeric equality comparison for payment amounts (handles "199.00" == "199").
     */
    fun areAmountsEqual(a: String?, b: String?): Boolean {
        val numA = normalizeAmount(a) ?: return false
        val numB = normalizeAmount(b) ?: return false
        return Math.abs(numA - numB) < 0.001
    }

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

    // ── Onboarding ────────────────────────────────────────────────────────────

    /** Returns true if the user has completed first-time onboarding (default: false). */
    fun isOnboardingCompleted(): Boolean = prefs.getBoolean(KEY_ONBOARDING, false)

    /** Mark onboarding as completed. Irreversible from the app side. */
    fun setOnboardingCompleted() {
        prefs.edit().putBoolean(KEY_ONBOARDING, true).apply()
        Log.d(TAG, "Onboarding marked complete.")
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

    // ── Merchant & Voice Settings ─────────────────────────────────────────────

    fun getLanguage(): String = prefs.getString(KEY_LANGUAGE, "en-IN") ?: "en-IN"

    fun setLanguage(lang: String) {
        prefs.edit().putString(KEY_LANGUAGE, lang).apply()
        Log.d(TAG, "Language updated: $lang")
    }

    fun getMerchantName(): String = prefs.getString(KEY_MERCHANT_NAME, "MyUPI") ?: "MyUPI"

    fun setMerchantName(name: String) {
        prefs.edit().putString(KEY_MERCHANT_NAME, name).apply()
        Log.d(TAG, "Merchant name updated: $name")
    }

    fun getAnnouncementFormat(): String = prefs.getString(KEY_ANNOUNCE_FORMAT, "A") ?: "A"

    fun setAnnouncementFormat(format: String) {
        require(format in listOf("A", "B", "C")) {
            "Invalid announcement format: $format"
        }
        prefs.edit().putString(KEY_ANNOUNCE_FORMAT, format).apply()
        Log.d(TAG, "Announcement format updated: $format")
    }

    fun isIncludeShopNameEnabled(): Boolean = prefs.getBoolean(KEY_INCLUDE_SHOP_NAME, false)

    fun setIncludeShopNameEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_INCLUDE_SHOP_NAME, enabled).apply()
        Log.d(TAG, "Include shop name updated: $enabled")
    }

    // ── Merchant Profile Foundation ──────────────────────────────────────────

    fun getMerchantId(): String {
        var id = prefs.getString(KEY_MERCHANT_ID, null)
        if (id.isNullOrBlank()) {
            id = java.util.UUID.randomUUID().toString()
            prefs.edit().putString(KEY_MERCHANT_ID, id).apply()
            Log.d(TAG, "Generated local merchant ID: $id")
        }
        return id
    }

    fun getMerchantProfile(): Map<String, Any> {
        return mapOf(
            "merchantId"         to getMerchantId(),
            "shopName"           to getMerchantName(),
            "preferredLanguage"  to getLanguage(),
            "speechSpeed"        to getSpeechSpeed(),
            "announcementFormat" to getAnnouncementFormat(),
            "soundboxEnabled"    to isSoundboxEnabled(),
            "includeShopName"    to isIncludeShopNameEnabled(),
        )
    }

    // ── Feature Flags & Entitlements ─────────────────────────────────────────

    fun getFeatureFlags(): Map<String, Boolean> {
        return mapOf(
            "notificationSoundbox" to true,
            "verifiedPayments"     to false,
            "backendSync"          to false,
            "premiumFeatures"      to false,
        )
    }

    fun getSubscriptionState(): String =
        prefs.getString(KEY_SUBSCRIPTION_STATE, "INTRO_OFFER_AVAILABLE") ?: "INTRO_OFFER_AVAILABLE"

    fun setSubscriptionState(state: String) {
        prefs.edit().putString(KEY_SUBSCRIPTION_STATE, state).apply()
        Log.d(TAG, "Subscription state updated: $state")
    }

    fun getSubscriptionTier(): String {
        val state = getSubscriptionState()
        return if (state == "ACTIVE" || state == "GRACE_PERIOD" || state == "CANCELLED") {
            "PREMIUM"
        } else {
            "FREE"
        }
    }

    // ── Payment history ───────────────────────────────────────────────────────

    /**
     * Single shared gatekeeper for inserting or merging ANY payment ledger entry.
     * Enforces a 60-second sliding window deduplication & cross-channel merge check:
     *
     * for each entry in ledger where entry.timestamp is within last 60s:
     *     if entry.amount == newAmount (compare as normalized numeric, not string):
     *         if entry.source != newSource:
     *             -> upgrade existing entry to "Dual Confirmed", do NOT insert new row
     *         else:
     *             -> discard newEvent entirely, do NOT insert, do NOT re-announce
     *         stop here
     * -> otherwise, insert as new entry and announce
     */
    @Synchronized
    fun recordPaymentOrMerge(
        amount: String,
        appName: String,
        trustLevel: String,
        source: String,
        verificationStatus: String = "NOT_VERIFIED",
        parserVersion: Int = 1,
    ): RecordResult {
        val newNumeric = normalizeAmount(amount)
        if (newNumeric == null || newNumeric <= 0.0) {
            Log.w(TAG, "Cannot record payment: invalid amount '$amount'")
            return RecordResult.DuplicateIgnored("Invalid amount")
        }

        val list = loadHistoryList().toMutableList()
        val now = System.currentTimeMillis()
        val WINDOW_MS = 60_000L
        val newSourceUpper = source.uppercase()

        // 1. Scan ledger for any matching entry within the last 60 seconds
        var existingItem: JSONObject? = null

        for (i in list.indices) {
            val item = list[i]
            val itemTime = item.optLong("timestampMs", 0L)
            val timeDiff = now - itemTime

            // Check sliding 60-second window (allows slight clock skew up to 5s in future)
            if (timeDiff in -5_000L..WINDOW_MS) {
                val itemAmount = item.optString("amount", "")
                if (areAmountsEqual(itemAmount, amount)) {
                    existingItem = item
                    break
                }
            }
        }

        // 2. If a match is found in the sliding 60s window
        if (existingItem != null) {
            val existingSource = existingItem.optString("source", "NOTIFICATION").uppercase()
            val existingAppName = existingItem.optString("appName", "")

            // Case A: Different channel detected -> upgrade existing entry to "Dual Confirmed" ("BOTH")
            if (existingSource != newSourceUpper && existingSource != "BOTH") {
                val combinedAppName = when {
                    existingAppName.contains(appName, ignoreCase = true) -> existingAppName
                    appName.contains(existingAppName, ignoreCase = true) -> appName
                    newSourceUpper == "NOTIFICATION" -> "$appName + $existingAppName"
                    else -> "$existingAppName + $appName"
                }

                existingItem.put("source", "BOTH")
                existingItem.put("trustLevel", "HIGH")
                existingItem.put("appName", combinedAppName)

                // Clean up any subsequent duplicates for this amount within the window
                val iterator = list.iterator()
                var skippedFirst = false
                while (iterator.hasNext()) {
                    val it = iterator.next()
                    if (it === existingItem) {
                        skippedFirst = true
                        continue
                    }
                    val t = it.optLong("timestampMs", 0L)
                    if (skippedFirst && (now - t in -5_000L..WINDOW_MS) && areAmountsEqual(it.optString("amount", ""), amount)) {
                        iterator.remove()
                        Log.d(TAG, "Pruned duplicate historical entry for ₹$amount during merge")
                    }
                }

                val arr = JSONArray().apply { list.forEach { put(it) } }
                prefs.edit().putString(KEY_HISTORY, arr.toString()).apply()

                Log.d(TAG, "Upgraded existing ledger entry to Dual Confirmed: ₹$amount -> BOTH ($combinedAppName)")

                val updatedRecord = PaymentRecord(
                    amount = existingItem.optString("amount", amount),
                    appName = combinedAppName,
                    trustLevel = "HIGH",
                    timestampMs = existingItem.optLong("timestampMs", now),
                    verificationStatus = existingItem.optString("verificationStatus", verificationStatus),
                    source = "BOTH",
                    parserVersion = parserVersion,
                )

                return RecordResult.Merged(
                    updatedRecord = updatedRecord,
                    originalSource = existingSource,
                    originalLabel = existingAppName,
                )
            } else {
                // Case B: Same channel duplicate or already BOTH -> discard newEvent entirely
                Log.d(TAG, "Discarding duplicate payment event: ₹$amount from $appName (existing source: $existingSource, incoming source: $newSourceUpper)")
                return RecordResult.DuplicateIgnored("Duplicate $newSourceUpper payment within 60s window")
            }
        }

        // 3. No match found within 60s -> Insert as fresh entry
        val newRecordObj = JSONObject().apply {
            put("amount", amount)
            put("appName", appName)
            put("trustLevel", trustLevel)
            put("timestampMs", now)
            put("verificationStatus", verificationStatus)
            put("source", newSourceUpper)
            put("parserVersion", parserVersion)
        }

        list.add(0, newRecordObj)
        val trimmed = if (list.size > MAX_HISTORY_SIZE) list.take(MAX_HISTORY_SIZE) else list
        val arr = JSONArray().apply { trimmed.forEach { put(it) } }
        prefs.edit().putString(KEY_HISTORY, arr.toString()).apply()

        Log.d(TAG, "Payment history saved: ₹$amount from $appName ($verificationStatus, source: $newSourceUpper, total: ${trimmed.size})")

        val record = PaymentRecord(
            amount = amount,
            appName = appName,
            trustLevel = trustLevel,
            timestampMs = now,
            verificationStatus = verificationStatus,
            source = newSourceUpper,
            parserVersion = parserVersion,
        )

        return RecordResult.Fresh(record)
    }

    /**
     * Add a payment record to history. Delegates to [recordPaymentOrMerge]
     * to enforce strict numeric 60-second deduplication and prevent duplicate entries.
     */
    @Synchronized
    fun addPayment(
        amount: String,
        appName: String,
        trustLevel: String,
        verificationStatus: String = "NOT_VERIFIED",
        source: String = "NOTIFICATION",
        parserVersion: Int = 1,
    ) {
        recordPaymentOrMerge(
            amount = amount,
            appName = appName,
            trustLevel = trustLevel,
            source = source,
            verificationStatus = verificationStatus,
            parserVersion = parserVersion,
        )
    }

    /**
     * Load all payment history records, newest first.
     * Handles missing fields from older stored records with safe defaults.
     */
    @Synchronized
    fun getHistory(): List<PaymentRecord> {
        return loadHistoryList().mapNotNull { obj ->
            try {
                PaymentRecord(
                    amount             = obj.getString("amount"),
                    appName            = obj.getString("appName"),
                    trustLevel         = obj.optString("trustLevel", "HIGH"),
                    timestampMs        = obj.getLong("timestampMs"),
                    verificationStatus = obj.optString("verificationStatus", "NOT_VERIFIED"),
                    source             = obj.optString("source", "NOTIFICATION"),
                    parserVersion      = obj.optInt("parserVersion", 1),
                )
            } catch (e: Exception) {
                Log.w(TAG, "Skipping malformed history record: ${e.message}")
                null
            }
        }
    }

    /**
     * Updates an existing recent payment record to source "BOTH" and HIGH trust.
     * Matches by normalized numeric amount within the last 60 seconds.
     * Returns true if a record was successfully merged.
     */
    @Synchronized
    fun mergeRecentPayment(
        amount: String,
        newSource: String = "BOTH",
        combinedAppName: String,
        newTrustLevel: String = "HIGH",
    ): Boolean {
        val list = loadHistoryList().toMutableList()
        val now = System.currentTimeMillis()

        for (i in list.indices) {
            val item = list[i]
            val itemAmount = item.optString("amount", "")
            val itemTime = item.optLong("timestampMs", 0L)

            // Match within 60 seconds and normalized numeric amount
            if (areAmountsEqual(itemAmount, amount) && (now - itemTime) in -5_000L..60_000L) {
                item.put("source", newSource)
                item.put("trustLevel", newTrustLevel)
                item.put("appName", combinedAppName)
                val arr = JSONArray().apply { list.forEach { put(it) } }
                prefs.edit().putString(KEY_HISTORY, arr.toString()).apply()
                Log.d(TAG, "Payment history record merged: ₹$amount -> $newSource ($combinedAppName)")
                return true
            }
        }
        return false
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

    // ── Diagnostic Logging (Zero-PII) ─────────────────────────────────────────

    private const val KEY_DIAGNOSTIC_LOGS = "diagnostic_logs"
    private const val MAX_DIAGNOSTIC_LOGS = 25

    /**
     * Records recent detection events for diagnostics with Zero-PII guarantee.
     * Only stores app label, status, trust level, amount, and reason.
     */
    @Synchronized
    fun addDiagnosticLog(
        appName: String,
        status: String,
        trustLevel: String,
        amount: String?,
        reason: String,
    ) {
        try {
            val json = prefs.getString(KEY_DIAGNOSTIC_LOGS, "[]") ?: "[]"
            val arr = JSONArray(json)
            val list = (0 until arr.length()).map { arr.getJSONObject(it) }.toMutableList()
            val item = JSONObject().apply {
                put("timestampMs", System.currentTimeMillis())
                put("appName", appName)
                put("status", status)
                put("trustLevel", trustLevel)
                put("amount", amount ?: "")
                put("reason", reason)
            }
            list.add(0, item)
            val trimmed = if (list.size > MAX_DIAGNOSTIC_LOGS) list.take(MAX_DIAGNOSTIC_LOGS) else list
            val outArr = JSONArray().apply { trimmed.forEach { put(it) } }
            prefs.edit().putString(KEY_DIAGNOSTIC_LOGS, outArr.toString()).apply()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to write diagnostic log: ${e.message}")
        }
    }

    @Synchronized
    fun getDiagnosticLogs(): List<Map<String, Any>> {
        val json = prefs.getString(KEY_DIAGNOSTIC_LOGS, "[]") ?: "[]"
        return try {
            val arr = JSONArray(json)
            (0 until arr.length()).map { i ->
                val obj = arr.getJSONObject(i)
                mapOf(
                    "timestampMs" to obj.optLong("timestampMs"),
                    "appName"     to obj.optString("appName"),
                    "status"      to obj.optString("status"),
                    "trustLevel"  to obj.optString("trustLevel"),
                    "amount"      to obj.optString("amount"),
                    "reason"      to obj.optString("reason"),
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
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

package com.example.myupi

// CrossChannelCoordinator.kt
//
// MyUPI Cross-Channel Deduplication & Merge Engine (Master Brief Part 1c)
// ----------------------------------------------------------------------
// Coordinates detection events across both Notification Listener and SMS channels.
// Employs a 45-second sliding window to match candidate payments by amount.
//
// Behavior:
//   - If Notification lands first: announced via TTS, logged as NOTIFICATION (HIGH trust).
//     If matching SMS lands within 45s: merged into single ledger entry with source="BOTH",
//     trustLevel="HIGH", TTS is NOT repeated.
//   - If SMS lands first (e.g. notification delayed/dropped): announced via TTS, logged
//     as SMS (MEDIUM trust). If matching Notification lands within 45s: merged into
//     single ledger entry with source="BOTH", trustLevel="HIGH", TTS is NOT repeated.
//   - If only one channel detects: logged and announced under that channel.

import android.util.Log

sealed class CrossChannelDisposition {
    object Fresh : CrossChannelDisposition()
    data class Merged(val originalSource: String, val originalLabel: String) : CrossChannelDisposition()
}

object CrossChannelCoordinator {

    private const val TAG = "MyUPI_COORDINATOR"
    private const val CROSS_CHANNEL_WINDOW_MS = 45_000L // 45-second sliding window

    private data class TrackedEvent(
        val amount: String,
        val channel: String, // "NOTIFICATION" or "SMS"
        val label: String,   // App name or Bank name
        val timestampMs: Long,
        var isMerged: Boolean = false,
    )

    private val trackedEvents = mutableListOf<TrackedEvent>()

    /**
     * Normalizes amount string (e.g. "500.00" -> "500") for exact cross-channel matching.
     */
    private fun normalizeAmount(amount: String): String {
        val clean = amount.replace(",", "").trim()
        val d = clean.toDoubleOrNull() ?: return clean
        return if (d == d.toLong().toDouble()) {
            d.toLong().toString()
        } else {
            clean
        }
    }

    /**
     * Coordinate an incoming payment detected via Notification.
     * Returns [CrossChannelDisposition.Merged] if an SMS was already detected for this amount within 45s,
     * or [CrossChannelDisposition.Fresh] if this is the first channel to detect it.
     */
    @Synchronized
    fun onNotificationDetected(amount: String, appName: String): CrossChannelDisposition {
        val now = System.currentTimeMillis()
        pruneExpired(now)

        val normAmount = normalizeAmount(amount)

        // Look for an unmerged SMS event with matching amount within the window
        val existingSms = trackedEvents.firstOrNull {
            !it.isMerged && it.channel == "SMS" && normalizeAmount(it.amount) == normAmount
        }

        if (existingSms != null) {
            existingSms.isMerged = true
            Log.d(TAG, "Notification MERGED with earlier SMS for ₹$amount (Bank: ${existingSms.label}, App: $appName)")
            return CrossChannelDisposition.Merged(
                originalSource = "SMS",
                originalLabel = existingSms.label,
            )
        }

        // Register new notification event
        trackedEvents.add(
            TrackedEvent(
                amount = amount,
                channel = "NOTIFICATION",
                label = appName,
                timestampMs = now,
            )
        )
        return CrossChannelDisposition.Fresh
    }

    /**
     * Coordinate an incoming payment detected via Bank SMS.
     * Returns [CrossChannelDisposition.Merged] if a Notification was already detected for this amount within 45s,
     * or [CrossChannelDisposition.Fresh] if this is the first channel to detect it.
     */
    @Synchronized
    fun onSmsDetected(amount: String, bankName: String): CrossChannelDisposition {
        val now = System.currentTimeMillis()
        pruneExpired(now)

        val normAmount = normalizeAmount(amount)

        // Look for an unmerged Notification event with matching amount within the window
        val existingNotif = trackedEvents.firstOrNull {
            !it.isMerged && it.channel == "NOTIFICATION" && normalizeAmount(it.amount) == normAmount
        }

        if (existingNotif != null) {
            existingNotif.isMerged = true
            Log.d(TAG, "SMS MERGED with earlier Notification for ₹$amount (App: ${existingNotif.label}, Bank: $bankName)")
            return CrossChannelDisposition.Merged(
                originalSource = "NOTIFICATION",
                originalLabel = existingNotif.label,
            )
        }

        // Register new SMS event
        trackedEvents.add(
            TrackedEvent(
                amount = amount,
                channel = "SMS",
                label = bankName,
                timestampMs = now,
            )
        )
        return CrossChannelDisposition.Fresh
    }

    private fun pruneExpired(now: Long) {
        val iterator = trackedEvents.iterator()
        while (iterator.hasNext()) {
            val event = iterator.next()
            if (now - event.timestampMs > CROSS_CHANNEL_WINDOW_MS) {
                iterator.remove()
            }
        }
    }
}

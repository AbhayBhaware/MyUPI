package com.example.myupi

// CrossChannelCoordinator.kt
//
// MyUPI Cross-Channel Deduplication & Merge Engine (Master Brief Part 1c)
// ----------------------------------------------------------------------
// Coordinates detection events across both Notification Listener and SMS channels.
// Employs a 60-second sliding window to match candidate payments by normalized numeric amount.
//
// Behavior:
//   - If Notification lands first: announced via TTS, logged as NOTIFICATION (HIGH trust).
//     If matching SMS lands within 60s: merged into single ledger entry with source="BOTH",
//     trustLevel="HIGH", TTS is NOT repeated.
//   - If SMS lands first: announced via TTS, logged as SMS (MEDIUM trust).
//     If matching Notification lands within 60s: merged into single ledger entry with
//     source="BOTH", trustLevel="HIGH", TTS is NOT repeated.
//   - If same channel repeats within 60s: flagged as DuplicateIgnored (dropped, no insert, no TTS).

import android.util.Log

sealed class CrossChannelDisposition {
    object Fresh : CrossChannelDisposition()
    data class Merged(val originalSource: String, val originalLabel: String) : CrossChannelDisposition()
    data class DuplicateIgnored(val reason: String) : CrossChannelDisposition()
}

object CrossChannelCoordinator {

    private const val TAG = "MyUPI_COORDINATOR"
    private const val CROSS_CHANNEL_WINDOW_MS = 60_000L // 60-second sliding window

    private data class TrackedEvent(
        val amount: String,
        val channel: String, // "NOTIFICATION" or "SMS"
        val label: String,   // App name or Bank name
        val timestampMs: Long,
        var isMerged: Boolean = false,
    )

    private val trackedEvents = mutableListOf<TrackedEvent>()

    /**
     * Coordinate an incoming payment detected via Notification.
     * Returns [CrossChannelDisposition.Merged] if an SMS was already detected for this amount within 60s,
     * [CrossChannelDisposition.DuplicateIgnored] if a notification was already detected for this amount within 60s,
     * or [CrossChannelDisposition.Fresh] if this is the first channel to detect it.
     */
    @Synchronized
    fun onNotificationDetected(amount: String, appName: String): CrossChannelDisposition {
        val now = System.currentTimeMillis()
        pruneExpired(now)

        // 1. Check for same-channel duplicate (Google Pay repost / update) within the 60s window
        val existingNotif = trackedEvents.firstOrNull {
            it.channel == "NOTIFICATION" && SharedPreferencesManager.areAmountsEqual(it.amount, amount)
        }
        if (existingNotif != null) {
            Log.d(TAG, "Duplicate notification suppressed in coordinator for ₹$amount ($appName)")
            return CrossChannelDisposition.DuplicateIgnored("Duplicate notification within 60s")
        }

        // 2. Look for an unmerged SMS event with matching amount within the window
        val existingSms = trackedEvents.firstOrNull {
            !it.isMerged && it.channel == "SMS" && SharedPreferencesManager.areAmountsEqual(it.amount, amount)
        }

        if (existingSms != null) {
            existingSms.isMerged = true
            Log.d(TAG, "Notification MERGED with earlier SMS for ₹$amount (Bank: ${existingSms.label}, App: $appName)")
            return CrossChannelDisposition.Merged(
                originalSource = "SMS",
                originalLabel = existingSms.label,
            )
        }

        // 3. Register new notification event
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
     * Returns [CrossChannelDisposition.Merged] if a Notification was already detected for this amount within 60s,
     * [CrossChannelDisposition.DuplicateIgnored] if an SMS was already detected for this amount within 60s,
     * or [CrossChannelDisposition.Fresh] if this is the first channel to detect it.
     */
    @Synchronized
    fun onSmsDetected(amount: String, bankName: String): CrossChannelDisposition {
        val now = System.currentTimeMillis()
        pruneExpired(now)

        // 1. Check for same-channel duplicate SMS within the 60s window
        val existingSms = trackedEvents.firstOrNull {
            it.channel == "SMS" && SharedPreferencesManager.areAmountsEqual(it.amount, amount)
        }
        if (existingSms != null) {
            Log.d(TAG, "Duplicate SMS suppressed in coordinator for ₹$amount ($bankName)")
            return CrossChannelDisposition.DuplicateIgnored("Duplicate SMS within 60s")
        }

        // 2. Look for an unmerged Notification event with matching amount within the window
        val existingNotif = trackedEvents.firstOrNull {
            !it.isMerged && it.channel == "NOTIFICATION" && SharedPreferencesManager.areAmountsEqual(it.amount, amount)
        }

        if (existingNotif != null) {
            existingNotif.isMerged = true
            Log.d(TAG, "SMS MERGED with earlier Notification for ₹$amount (App: ${existingNotif.label}, Bank: $bankName)")
            return CrossChannelDisposition.Merged(
                originalSource = "NOTIFICATION",
                originalLabel = existingNotif.label,
            )
        }

        // 3. Register new SMS event
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

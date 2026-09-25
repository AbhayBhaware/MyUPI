package com.example.myupi

// SmsReceiver.kt
//
// MyUPI SMS BroadcastReceiver — Backup Payment Detection (Master Brief Part 1b & Part 2)
// --------------------------------------------------------------------------------------
// Catches incoming bank SMS messages via android.provider.Telephony.SMS_RECEIVED.
// Parses UPI credit messages with BankSmsDetector and merges with Notification listener
// via CrossChannelCoordinator.

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "MyUPI_SMS_RECEIVER"

        // Process-level SMS deduplication cache (60s sliding window)
        private val smsDedupCache = mutableMapOf<String, Long>()
        private const val DEDUP_WINDOW_MS = 60_000L

        private fun isDuplicateSms(key: String, nowMs: Long): Boolean {
            synchronized(smsDedupCache) {
                val iterator = smsDedupCache.entries.iterator()
                while (iterator.hasNext()) {
                    val entry = iterator.next()
                    if (nowMs - entry.value > DEDUP_WINDOW_MS) {
                        iterator.remove()
                    }
                }
                val lastSeen = smsDedupCache[key]
                if (lastSeen != null && (nowMs - lastSeen) <= DEDUP_WINDOW_MS) {
                    return true
                }
                smsDedupCache[key] = nowMs
                return false
            }
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = try {
            Telephony.Sms.Intents.getMessagesFromIntent(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to extract SMS messages from intent: ${e.message}")
            return
        }

        if (messages.isNullOrEmpty()) return

        // Extract sender and concatenate message body (for multi-part SMS)
        val sender = messages[0].originatingAddress ?: ""
        val bodyBuilder = java.lang.StringBuilder()
        for (sms in messages) {
            bodyBuilder.append(sms.messageBody ?: "")
        }
        val fullBody = bodyBuilder.toString()

        Log.d(TAG, "SMS received from: $sender (length: ${fullBody.length})")

        // 1. Detect UPI bank credit using BankSmsDetector
        val result = BankSmsDetector.detect(sender, fullBody) ?: return

        // Initialize persistent storage
        try {
            SharedPreferencesManager.init(context.applicationContext)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to init SharedPreferencesManager in SmsReceiver: ${e.message}")
        }

        val nowMs = System.currentTimeMillis()
        val normAmount = SharedPreferencesManager.normalizeAmount(result.amount)?.toString() ?: result.amount

        // 2. Pre-filter: drop duplicate SMS broadcasts within 60s
        val smsDedupKey = "$sender|$normAmount"
        if (isDuplicateSms(smsDedupKey, nowMs)) {
            Log.d(TAG, "Duplicate SMS payment suppressed for $smsDedupKey within 60s window")
            return
        }

        // 3. Single Gatekeeper Ledger Write & Cross-Channel Merge
        // Single authoritative path to write to history. Checks the persistent ledger:
        // - If same source (SMS) within 60s: discards duplicate (DuplicateIgnored)
        // - If opposite source (NOTIFICATION) within 60s: merges into Dual Confirmed (Merged)
        // - If fresh payment: inserts into ledger (Fresh)
        val recordResult = SharedPreferencesManager.recordPaymentOrMerge(
            amount = result.amount,
            appName = result.bankName,
            trustLevel = result.trustLevel,
            source = "SMS",
            verificationStatus = "NOT_VERIFIED",
            parserVersion = result.parserVersion,
        )

        when (recordResult) {
            is RecordResult.DuplicateIgnored -> {
                Log.d(TAG, "Duplicate SMS payment discarded by ledger gatekeeper: ₹${result.amount} from ${result.bankName} (${recordResult.reason})")
                SharedPreferencesManager.addDiagnosticLog(
                    appName = "${result.bankName} (SMS)",
                    status = "DUPLICATE_SUPPRESSED",
                    trustLevel = result.trustLevel,
                    amount = result.amount,
                    reason = recordResult.reason,
                )
                // Do NOT speak TTS, do NOT insert
            }

            is RecordResult.Merged -> {
                Log.d(TAG, "Cross-channel match: SMS ₹${result.amount} merged with ${recordResult.originalLabel} notification.")
                SharedPreferencesManager.addDiagnosticLog(
                    appName = "${result.bankName} (SMS)",
                    status = "MERGED_WITH_NOTIF",
                    trustLevel = "HIGH",
                    amount = result.amount,
                    reason = "Merged with ${recordResult.originalLabel} notification within 60s window",
                )

                // Notify Flutter UI of the merged update
                PaymentNotificationListener.sendCustomEventToFlutter(
                    packageName = sender,
                    title = "Dual Confirmed Payment",
                    text = "₹${result.amount} received via ${recordResult.originalLabel} + SMS",
                    notificationKey = "SMS|$sender|$nowMs",
                )
                // Do NOT speak TTS again — the notification already spoke it!
            }

            is RecordResult.Fresh -> {
                Log.d(TAG, "Fresh payment detected via SMS: ₹${result.amount} from ${result.bankName} (Trust: ${result.trustLevel})")
                SharedPreferencesManager.addDiagnosticLog(
                    appName = "${result.bankName} (SMS)",
                    status = "MATCHED",
                    trustLevel = result.trustLevel,
                    amount = result.amount,
                    reason = result.reason,
                )

                // Forward to Flutter UI
                PaymentNotificationListener.sendCustomEventToFlutter(
                    packageName = sender,
                    title = result.bankName,
                    text = "Received ₹${result.amount} via Bank SMS",
                    notificationKey = "SMS|$sender|$nowMs",
                )

                // 4. TTS Announcement — only if Soundbox is ON and payment is MEDIUM trust
                if (result.trustLevel == "MEDIUM") {
                    val soundboxEnabled = try {
                        SharedPreferencesManager.isSoundboxEnabled()
                    } catch (e: Exception) {
                        true
                    }

                    if (soundboxEnabled) {
                        Log.d(TAG, "TTS: Speaking SMS payment of ₹${result.amount}")
                        val helper = PaymentNotificationListener.ttsHelper ?: NativeTtsHelper(context.applicationContext)
                        helper.speakPayment(result.amount)
                    } else {
                        Log.d(TAG, "TTS: Soundbox OFF — skipping announcement for SMS payment.")
                    }
                } else {
                    Log.w(TAG, "TTS: Low trust or large SMS payment (₹${result.amount}) — NOT speaking for fraud protection.")
                }
            }
        }
    }
}

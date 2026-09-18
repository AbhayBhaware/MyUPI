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

        // 2. Cross-Channel Coordination (45-second deduplication & merge)
        val disposition = CrossChannelCoordinator.onSmsDetected(result.amount, result.bankName)

        when (disposition) {
            is CrossChannelDisposition.Merged -> {
                // A notification already landed for this payment within the 45s window!
                Log.d(TAG, "Cross-channel match: SMS ₹${result.amount} merged with ${disposition.originalLabel} notification.")
                
                val combinedLabel = "${disposition.originalLabel} + ${result.bankName}"
                SharedPreferencesManager.mergeRecentPayment(
                    amount = result.amount,
                    newSource = "BOTH",
                    combinedAppName = combinedLabel,
                    newTrustLevel = "HIGH",
                )

                SharedPreferencesManager.addDiagnosticLog(
                    appName = "${result.bankName} (SMS)",
                    status = "MERGED_WITH_NOTIF",
                    trustLevel = "HIGH",
                    amount = result.amount,
                    reason = "Merged with ${disposition.originalLabel} notification within 45s window",
                )

                // Notify Flutter UI of the merged update
                PaymentNotificationListener.sendCustomEventToFlutter(
                    packageName = sender,
                    title = "Dual Confirmed Payment",
                    text = "₹${result.amount} received via ${disposition.originalLabel} + SMS",
                    notificationKey = "SMS|$sender|${System.currentTimeMillis()}",
                )
                // Do NOT speak TTS again — the notification already spoke it!
            }

            is CrossChannelDisposition.Fresh -> {
                // No prior notification received — this is a fresh payment detected via SMS!
                Log.d(TAG, "Fresh payment detected via SMS: ₹${result.amount} from ${result.bankName} (Trust: ${result.trustLevel})")

                // Save to history (source: SMS, verification: NOT_VERIFIED, trust: MEDIUM/LOW)
                SharedPreferencesManager.addPayment(
                    amount = result.amount,
                    appName = result.bankName,
                    trustLevel = result.trustLevel,
                    verificationStatus = "NOT_VERIFIED",
                    source = "SMS",
                    parserVersion = result.parserVersion,
                )

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
                    notificationKey = "SMS|$sender|${System.currentTimeMillis()}",
                )

                // 3. TTS Announcement — only if Soundbox is ON and payment is MEDIUM trust (not LOW/flagged)
                if (result.trustLevel == "MEDIUM") {
                    val soundboxEnabled = try {
                        SharedPreferencesManager.isSoundboxEnabled()
                    } catch (e: Exception) {
                        true
                    }

                    if (soundboxEnabled) {
                        Log.d(TAG, "TTS: Speaking SMS payment of ₹${result.amount}")
                        // Speak via NotificationListener's TTS helper if running, or on-demand
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

package com.example.myupi

// PaymentNotificationListener.kt
//
// MyUPI NotificationListenerService — Background Soundbox (Milestone 8)
// -------------------------------------------------------
// Architecture:
//
//   Android notification
//       ↓
//   onNotificationPosted()
//       ↓
//   Dedup (seenKeys Set)             ← service-owned, survives Activity close
//       ↓
//   KotlinUpiDetector.detect()      ← app-specific, strict, mirrors Dart rules
//       ↓
//   SharedPreferencesManager         ← save payment history
//       ↓
//   Soundbox ON?                     ← check persisted setting before speaking
//       ↓
//   NativeTtsHelper.speakPayment()  ← android.speech.tts — works with no Flutter
//       ↓
//   EventChannel → Flutter UI       ← optional, best-effort, null-safe
//
// The Flutter EventChannel / Flutter engine is NOT required for
// background payment detection, history, or TTS.

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.plugin.common.EventChannel

class PaymentNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "MyUPI_BACKGROUND"

        // ── EventChannel sink ────────────────────────────────────────────────
        // Held by MainActivity. Null when Flutter engine is not running.
        // ALL accesses must be on the main thread (via mainLooper Handler).
        @Volatile
        var eventSink: EventChannel.EventSink? = null

        // ── Native TTS helper ────────────────────────────────────────────────
        // Singleton per-process. Initialized in onCreate(), shut down in onDestroy().
        @Volatile
        var ttsHelper: NativeTtsHelper? = null
    }

    // ── Service-level dedup set ──────────────────────────────────────────────
    // Keys: "packageName|tag|id" — same scheme as the Flutter layer.
    // Owned by the service so dedup works even when Flutter is closed.
    private val seenKeys = mutableSetOf<String>()

    // ── Lifecycle ────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "PaymentNotificationListener created — initializing storage and TTS.")
        // Initialize persistent storage first (required before TTS reads speech rate).
        SharedPreferencesManager.init(applicationContext)
        ttsHelper = NativeTtsHelper(applicationContext)
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Listener connected — MyUPI is now listening for notifications.")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.w(TAG, "Listener disconnected — notifications will not be received until reconnected.")
    }

    override fun onDestroy() {
        super.onDestroy()
        ttsHelper?.shutdown()
        ttsHelper = null
        Log.d(TAG, "PaymentNotificationListener destroyed — TTS shut down.")
    }

    // ── Main notification callback ────────────────────────────────────────────

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: "unknown"
        val extras      = sbn.notification?.extras

        val title = extras?.getCharSequence("android.title")?.toString() ?: ""
        val text  = extras?.getCharSequence("android.text")?.toString()  ?: ""

        // Notification identity key — same format used by Flutter.
        val notifTag = sbn.tag ?: ""
        val notifId  = sbn.id
        val notificationKey = "$packageName|$notifTag|$notifId"

        Log.d(TAG, "POSTED | Key: $notificationKey | Title: \"$title\" | Text: \"$text\"")

        // ── 1. Service-level deduplication ───────────────────────────────────
        // This runs before any detection. If we have already processed this
        // exact notification (same key), skip detection, history, and TTS.
        // We still forward to Flutter UI so the display can show it if needed.
        val isDuplicate: Boolean
        synchronized(seenKeys) {
            isDuplicate = !seenKeys.add(notificationKey)
            // Keep the set from growing unbounded (in-memory only).
            if (seenKeys.size > 300) seenKeys.clear()
        }

        if (isDuplicate) {
            Log.d(TAG, "Duplicate notification ignored — key: $notificationKey")
            // Do NOT speak or save. Still forward to Flutter (UI update only).
            sendToFlutter(packageName, title, text, notificationKey)
            return
        }

        // ── 2. Background UPI detection ──────────────────────────────────────
        val result = KotlinUpiDetector.detect(packageName, title, text)

        if (result == null || result.trustLevel == "LOW") {
            // Not a known UPI app or explicitly rejected (LOW trust)
            Log.v(TAG, "Package: $packageName | TrustLevel: LOW — skipped.")
            // Still send to Flutter so the UI can display non-payment notifications.
            sendToFlutter(packageName, title, text, notificationKey)
            return
        }

        Log.d(TAG,
            "Detection | App: ${result.appName} | " +
            "TrustLevel: ${result.trustLevel} | Amount: ${result.amount} | " +
            "Reason: ${result.reason}"
        )

        // ── 3. Save to payment history ───────────────────────────────────────
        // Both HIGH and MEDIUM trust payments are saved to history.
        if (!result.amount.isNullOrEmpty()) {
            try {
                SharedPreferencesManager.addPayment(
                    amount  = result.amount,
                    appName = result.appName,
                    trustLevel = result.trustLevel,
                )
                Log.d(TAG, "Payment history: saved ₹${result.amount} from ${result.appName} (Trust: ${result.trustLevel})")
            } catch (e: Exception) {
                Log.e(TAG, "Payment history: save failed — ${e.message}. TTS will still proceed.")
            }
        }

        // ── 4. Native TTS — only if Soundbox is ON AND payment is HIGH TRUST ─
        if (result.trustLevel == "HIGH" && !result.amount.isNullOrEmpty()) {
            val soundboxEnabled = try {
                SharedPreferencesManager.isSoundboxEnabled()
            } catch (e: Exception) {
                Log.e(TAG, "Could not read Soundbox setting — defaulting to ON: ${e.message}")
                true
            }

            if (soundboxEnabled) {
                Log.d(TAG, "TTS: Soundbox ON — speaking amount: ${result.amount}")
                ttsHelper?.speakPayment(result.amount)
                    ?: Log.w(TAG, "TTS: ttsHelper is null — cannot speak (service may be restarting).")
            } else {
                Log.d(TAG, "TTS: Soundbox OFF — payment detected but NOT speaking.")
            }
        } else if (result.trustLevel == "MEDIUM") {
            Log.d(TAG, "TTS: MEDIUM trust payment — NOT speaking.")
        }

        // ── 5. EventChannel → Flutter UI (best-effort, not required) ─────────
        sendToFlutter(packageName, title, text, notificationKey)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        if (sbn == null) return
        Log.d(TAG, "REMOVED | Package: ${sbn.packageName}")
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /**
     * Forward raw notification data to Flutter via EventChannel.
     * Safe when [eventSink] is null — EventChannel is optional for background mode.
     */
    private fun sendToFlutter(
        packageName: String,
        title: String,
        text: String,
        notificationKey: String,
    ) {
        val sink = eventSink ?: run {
            Log.v(TAG, "EventChannel unavailable — continuing background processing.")
            return
        }

        val event = mapOf(
            "packageName"     to packageName,
            "title"           to title,
            "text"            to text,
            "notificationKey" to notificationKey,
        )

        // EventSink must be called on the main thread.
        android.os.Handler(mainLooper).post {
            try {
                sink.success(event)
            } catch (e: Exception) {
                Log.e(TAG, "Error sending event to Flutter: ${e.message}")
            }
        }
    }
}

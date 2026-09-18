package com.example.myupi

// PaymentNotificationListener.kt
//
// MyUPI NotificationListenerService — Background Soundbox (Milestone 8 & Master Brief Part 1a)
// ---------------------------------------------------------------------------------------------
// Hardened with reliability techniques:
//   1. Reconcile on reconnect (getActiveNotifications() on onListenerConnected())
//   2. Request rebind if unbound (API 24+ requestRebind())
//   3. Notification update & ranking support (content hash prevents dropping updated amounts)
//   4. Grouped / summary notification expansion (FLAG_GROUP_SUMMARY, EXTRA_TEXT_LINES)
//   5. Cross-channel 45s deduplication & merge with Bank SMS channel via CrossChannelCoordinator

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
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

        /**
         * Rebind service programmatically if unbound by Android OEM memory killer.
         */
        fun rebindService(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                try {
                    requestRebind(ComponentName(context, PaymentNotificationListener::class.java))
                    Log.d(TAG, "Requested rebind for PaymentNotificationListener.")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to request rebind: ${e.message}")
                }
            }
        }

        /**
         * Send a custom event to Flutter UI via EventChannel on the main thread.
         */
        fun sendCustomEventToFlutter(
            packageName: String,
            title: String,
            text: String,
            notificationKey: String,
        ) {
            val sink = eventSink ?: return
            val event = mapOf(
                "packageName"     to packageName,
                "title"           to title,
                "text"            to text,
                "notificationKey" to notificationKey,
            )
            Handler(Looper.getMainLooper()).post {
                try {
                    sink.success(event)
                } catch (e: Exception) {
                    Log.e(TAG, "Error sending event to Flutter: ${e.message}")
                }
            }
        }
    }

    // ── Service-level sliding window deduplication ───────────────────────────
    // Key: "$packageName|$notifTag|$notifId|$contentHash" -> timestampMs
    // Sliding window of 45 seconds (45,000 ms) prevents duplicate announcements
    // from OS re-delivery or app status refreshes while allowing successive payments.
    private val dedupCache = mutableMapOf<String, Long>()
    private val DEDUP_WINDOW_MS = 45_000L

    private fun isDuplicateNotification(dedupKey: String, nowMs: Long): Boolean {
        synchronized(dedupCache) {
            // Evict expired entries older than 45 seconds
            val iterator = dedupCache.entries.iterator()
            while (iterator.hasNext()) {
                val entry = iterator.next()
                if (nowMs - entry.value > DEDUP_WINDOW_MS) {
                    iterator.remove()
                }
            }
            val lastSeen = dedupCache[dedupKey]
            if (lastSeen != null && (nowMs - lastSeen) <= DEDUP_WINDOW_MS) {
                return true
            }
            dedupCache[dedupKey] = nowMs
            return false
        }
    }

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
        // Ensure initialization if service was recovered by Android
        try {
            SharedPreferencesManager.init(applicationContext)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize SharedPreferencesManager: ${e.message}")
        }
        if (ttsHelper == null) {
            ttsHelper = NativeTtsHelper(applicationContext)
        }

        // Reliability Technique 1: Reconcile on reconnect (Master Brief Part 1a)
        reconcileActiveNotifications()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.w(TAG, "Listener disconnected — requesting rebind immediately (Master Brief Part 1a).")
        // Reliability Technique 2: Request rebind if unbound (Master Brief Part 1a)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                requestRebind(ComponentName(this, PaymentNotificationListener::class.java))
            } catch (e: Exception) {
                Log.e(TAG, "requestRebind failed in onListenerDisconnected: ${e.message}")
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        ttsHelper?.shutdown()
        ttsHelper = null
        Log.d(TAG, "PaymentNotificationListener destroyed — TTS shut down.")
    }

    override fun onNotificationRankingUpdate(rankingMap: RankingMap?) {
        super.onNotificationRankingUpdate(rankingMap)
        // Reliability Technique 3: Notification ranking/update handling
        // Re-check active notifications if ranking changes carry updated payment extras
    }

    // ── Main notification callback ────────────────────────────────────────────

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        processStatusBarNotification(sbn)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        if (sbn == null) return
        Log.d(TAG, "REMOVED | Package: ${sbn.packageName}")
    }

    /**
     * Core processing method for incoming notifications, also invoked during
     * reconnect reconciliation.
     */
    private fun processStatusBarNotification(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: "unknown"
        val title: String
        val text: String
        val extras = sbn.notification?.extras

        try {
            title = extras?.getCharSequence("android.title")?.toString() ?: ""
            text  = extras?.getCharSequence("android.text")?.toString()  ?: ""
        } catch (e: Exception) {
            Log.e(TAG, "Malformed notification extras from $packageName: ${e.message}")
            return
        }

        // Notification identity key — same format used by Flutter.
        val notifTag = sbn.tag ?: ""
        val notifId  = sbn.id
        val notificationKey = "$packageName|$notifTag|$notifId"

        // Deduplication key incorporates content hash so successive payments
        // with the same notification ID are not suppressed.
        val contentHash = (title + text).hashCode()
        val dedupKey = "$packageName|$notifTag|$notifId|$contentHash"
        val nowMs = System.currentTimeMillis()

        Log.d(TAG, "POSTED | Package: $packageName | Key: $notificationKey")

        // ── 1. Service-level deduplication (45s sliding window) ──────────────
        val isDuplicate = isDuplicateNotification(dedupKey, nowMs)

        if (isDuplicate) {
            Log.d(TAG, "Duplicate notification ignored within 45s window — key: $dedupKey")
            SharedPreferencesManager.addDiagnosticLog(
                appName = packageName,
                status = "DUPLICATE_SUPPRESSED",
                trustLevel = "NONE",
                amount = null,
                reason = "Identical notification repeated within 45s sliding window",
            )
            // Forward to Flutter (UI update only).
            sendToFlutter(packageName, title, text, notificationKey)
            return
        }

        // ── 2. Background UPI detection (with Grouped Notification fallback) ─
        var result = KotlinUpiDetector.detect(packageName, title, text)

        // Reliability Technique 4: Watch for grouped/summary notifications
        if (result == null || result.trustLevel == "LOW") {
            val lines = extras?.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            if (!lines.isNullOrEmpty()) {
                Log.d(TAG, "Inspecting ${lines.size} lines from grouped notification extras in $packageName")
                for (line in lines) {
                    val lineStr = line?.toString() ?: continue
                    val lineResult = KotlinUpiDetector.detect(packageName, title, lineStr)
                    if (lineResult != null && lineResult.trustLevel != "LOW") {
                        result = lineResult
                        Log.d(TAG, "Found payment match inside grouped notification line: ${result.amount}")
                        break
                    }
                }
            }
        }

        // Fallback to BigText if available and different from main text
        if (result == null || result.trustLevel == "LOW") {
            val bigText = extras?.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            if (!bigText.isNullOrBlank() && bigText != text) {
                val bigResult = KotlinUpiDetector.detect(packageName, title, bigText)
                if (bigResult != null && bigResult.trustLevel != "LOW") {
                    result = bigResult
                }
            }
        }

        if (result == null || result.trustLevel == "LOW") {
            // Not a known UPI app or explicitly rejected (LOW trust)
            Log.v(TAG, "Package: $packageName | TrustLevel: LOW — skipped.")
            if (result != null) {
                SharedPreferencesManager.addDiagnosticLog(
                    appName = result.appName,
                    status = "FILTERED_LOW_TRUST",
                    trustLevel = result.trustLevel,
                    amount = null,
                    reason = result.reason,
                )
            }
            // Forward to Flutter so UI can display non-payment notifications.
            sendToFlutter(packageName, title, text, notificationKey)
            return
        }

        // ── 3. Cross-Channel Coordination (45s deduplication & merge) ─────────
        val disposition = CrossChannelCoordinator.onNotificationDetected(result.amount ?: "", result.appName)

        when (disposition) {
            is CrossChannelDisposition.Merged -> {
                // An SMS already detected this payment within the 45s window!
                Log.d(TAG, "Cross-channel merge: Notification for ₹${result.amount} merged with ${disposition.originalLabel} SMS.")

                val combinedLabel = "${result.appName} + ${disposition.originalLabel}"
                SharedPreferencesManager.mergeRecentPayment(
                    amount = result.amount ?: "",
                    newSource = "BOTH",
                    combinedAppName = combinedLabel,
                    newTrustLevel = "HIGH",
                )

                SharedPreferencesManager.addDiagnosticLog(
                    appName = result.appName,
                    status = "MERGED_WITH_SMS",
                    trustLevel = "HIGH",
                    amount = result.amount,
                    reason = "Merged with ${disposition.originalLabel} SMS within 45s window",
                )
                // Do NOT speak TTS again — the SMS channel already announced it!
            }

            is CrossChannelDisposition.Fresh -> {
                // Fresh notification payment!
                SharedPreferencesManager.addDiagnosticLog(
                    appName = result.appName,
                    status = "MATCHED",
                    trustLevel = result.trustLevel,
                    amount = result.amount,
                    reason = result.reason,
                )

                Log.d(TAG,
                    "Detection | App: ${result.appName} | " +
                    "TrustLevel: ${result.trustLevel} | Amount: ${result.amount} | " +
                    "Reason: ${result.reason}"
                )

                // Save to payment history
                if (!result.amount.isNullOrEmpty()) {
                    try {
                        SharedPreferencesManager.addPayment(
                            amount  = result.amount,
                            appName = result.appName,
                            trustLevel = result.trustLevel,
                            verificationStatus = "NOT_VERIFIED",
                            source = "NOTIFICATION",
                            parserVersion = result.parserVersion,
                        )
                        Log.d(TAG, "Payment history: saved ₹${result.amount} from ${result.appName} (Trust: ${result.trustLevel}, Verification: NOT_VERIFIED, Source: NOTIFICATION)")
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
            }
        }

        // ── 5. EventChannel → Flutter UI (best-effort, not required) ─────────
        sendToFlutter(packageName, title, text, notificationKey)
    }

    /**
     * Reliability Technique 1: Reconcile on reconnect.
     * Process payment notifications that arrived in the system tray while the service
     * was dead, updating, or restarted.
     */
    private fun reconcileActiveNotifications() {
        try {
            val activeNotifs = activeNotifications ?: return
            val now = System.currentTimeMillis()
            val RECONCILE_MAX_AGE_MS = 3 * 60 * 1000L // Process up to 3-minute-old notifications

            val trustedPackages = KotlinUpiDetector.getTrustedPackages().keys
            for (sbn in activeNotifs) {
                val pkg = sbn.packageName ?: continue
                if (trustedPackages.contains(pkg)) {
                    val age = now - sbn.postTime
                    if (age in 0..RECONCILE_MAX_AGE_MS) {
                        Log.d(TAG, "Reconciling active notification from $pkg (age: ${age / 1000}s)")
                        processStatusBarNotification(sbn)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error during active notification reconciliation: ${e.message}")
        }
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
        Handler(Looper.getMainLooper()).post {
            try {
                sink.success(event)
            } catch (e: Exception) {
                Log.e(TAG, "Error sending event to Flutter: ${e.message}")
            }
        }
    }
}

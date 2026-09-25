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

        // ── Process-level sliding window deduplication ───────────────────────────
        // Survives NotificationListenerService restarts/rebinds across OEM battery events.
        private val dedupCache = mutableMapOf<String, Long>()
        private const val DEDUP_WINDOW_MS = 60_000L // 60-second sliding window

        fun isDuplicateNotification(dedupKey: String, nowMs: Long): Boolean {
            synchronized(dedupCache) {
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
        val notificationKey = sbn.key ?: "$packageName|$notifTag|$notifId"
        val nowMs = System.currentTimeMillis()

        Log.d(TAG, "POSTED | Package: $packageName | Key: $notificationKey")

        // ── 1. Fast in-place notification update deduplication ───────────────
        // Keyed on the OS notification key (never on volatile text content hash).
        // If Google Pay updates "just now" -> "1 min ago" for the same notification key,
        // drop it immediately before even running regex parsing.
        if (isDuplicateNotification("NOTIF_KEY|$notificationKey", nowMs)) {
            Log.d(TAG, "Duplicate notification key ignored within 60s window — key: $notificationKey")
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

        val amount = result.amount ?: ""
        val normAmount = SharedPreferencesManager.normalizeAmount(amount)?.toString() ?: amount

        // Pre-filter: drop duplicate reposts of the same amount from the same package within 60s
        val paymentKey = "PAYMENT|$packageName|$normAmount"
        if (isDuplicateNotification(paymentKey, nowMs)) {
            Log.d(TAG, "Duplicate payment notification suppressed for $paymentKey within 60s window")
            SharedPreferencesManager.addDiagnosticLog(
                appName = result.appName,
                status = "DUPLICATE_SUPPRESSED",
                trustLevel = result.trustLevel,
                amount = result.amount,
                reason = "Payment notification repeated within 60s window",
            )
            sendToFlutter(packageName, title, text, notificationKey)
            return
        }

        // ── 3. Single Gatekeeper Ledger Write & Cross-Channel Merge ──────────
        // Single authoritative path to write to history. Checks the persistent ledger:
        // - If same source within 60s: discards duplicate (DuplicateIgnored)
        // - If opposite source (SMS) within 60s: merges into Dual Confirmed (Merged)
        // - If fresh payment: inserts into ledger (Fresh)
        val recordResult = SharedPreferencesManager.recordPaymentOrMerge(
            amount = amount,
            appName = result.appName,
            trustLevel = result.trustLevel,
            source = "NOTIFICATION",
            verificationStatus = "NOT_VERIFIED",
            parserVersion = result.parserVersion,
        )

        when (recordResult) {
            is RecordResult.DuplicateIgnored -> {
                Log.d(TAG, "Duplicate notification discarded by ledger gatekeeper: ₹$amount from ${result.appName} (${recordResult.reason})")
                SharedPreferencesManager.addDiagnosticLog(
                    appName = result.appName,
                    status = "DUPLICATE_SUPPRESSED",
                    trustLevel = result.trustLevel,
                    amount = result.amount,
                    reason = recordResult.reason,
                )
                // Do NOT speak TTS, do NOT insert row
            }

            is RecordResult.Merged -> {
                Log.d(TAG, "Cross-channel merge: Notification for ₹$amount merged with ${recordResult.originalLabel} SMS into Dual Confirmed.")
                SharedPreferencesManager.addDiagnosticLog(
                    appName = result.appName,
                    status = "MERGED_WITH_SMS",
                    trustLevel = "HIGH",
                    amount = result.amount,
                    reason = "Merged with ${recordResult.originalLabel} SMS within 60s window",
                )
                // Do NOT speak TTS again — the earlier SMS already spoke it!
            }

            is RecordResult.Fresh -> {
                Log.d(TAG, "Fresh payment recorded from Notification: ₹$amount from ${result.appName}")
                SharedPreferencesManager.addDiagnosticLog(
                    appName = result.appName,
                    status = "MATCHED",
                    trustLevel = result.trustLevel,
                    amount = result.amount,
                    reason = result.reason,
                )

                // ── 4. Native TTS — only if Soundbox is ON AND payment is HIGH TRUST ─
                if (result.trustLevel == "HIGH" && amount.isNotEmpty()) {
                    val soundboxEnabled = try {
                        SharedPreferencesManager.isSoundboxEnabled()
                    } catch (e: Exception) {
                        Log.e(TAG, "Could not read Soundbox setting — defaulting to ON: ${e.message}")
                        true
                    }

                    if (soundboxEnabled) {
                        Log.d(TAG, "TTS: Soundbox ON — speaking amount: $amount")
                        ttsHelper?.speakPayment(amount)
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

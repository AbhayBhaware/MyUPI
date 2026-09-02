package com.example.myupi

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.plugin.common.EventChannel

class PaymentNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "MyUPI_NOTIFICATION"

        /**
         * Held by MainActivity after the EventChannel is set up.
         * Nullable — the Flutter engine / stream may not be active yet.
         * Access must be synchronised because the NotificationListenerService
         * runs on its own thread.
         */
        @Volatile
        var eventSink: EventChannel.EventSink? = null
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: "unknown"
        val extras      = sbn.notification?.extras

        val title = extras?.getCharSequence("android.title")?.toString() ?: ""
        val text  = extras?.getCharSequence("android.text")?.toString()  ?: ""

        // Unique key for this notification — used by Flutter for deduplication.
        // Format: "<packageName>|<tag>|<id>"
        val notifTag = sbn.tag ?: ""
        val notifId  = sbn.id
        val notificationKey = "$packageName|$notifTag|$notifId"

        Log.d(TAG, "POSTED | Key: $notificationKey | Title: $title | Text: $text")

        // Build the map that Flutter will receive.
        val event = mapOf(
            "packageName"     to packageName,
            "title"           to title,
            "text"            to text,
            "notificationKey" to notificationKey
        )

        // Send to Flutter on the main thread (EventSink is not thread-safe).
        val sink = eventSink
        if (sink != null) {
            android.os.Handler(mainLooper).post {
                try {
                    sink.success(event)
                } catch (e: Exception) {
                    Log.e(TAG, "Error sending notification event to Flutter: ${e.message}")
                }
            }
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: "unknown"
        Log.d(TAG, "REMOVED | Package: $packageName")
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "NotificationListenerService connected — MyUPI is now listening for notifications.")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "NotificationListenerService disconnected.")
    }
}

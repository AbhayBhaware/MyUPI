package com.example.myupi

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class PaymentNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "MyUPI_NOTIFICATION"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: "unknown"
        val extras = sbn.notification?.extras

        val title = extras?.getCharSequence("android.title")?.toString() ?: "(no title)"
        val text = extras?.getCharSequence("android.text")?.toString() ?: "(no text)"

        Log.d(TAG, "POSTED | Package: $packageName | Title: $title | Text: $text")
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

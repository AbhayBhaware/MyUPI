package com.example.myupi

import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL = "com.example.myupi/notification_access"
        private const val EVENT_CHANNEL  = "com.example.myupi/notification_stream"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize SharedPreferences (safe to call multiple times — idempotent).
        SharedPreferencesManager.init(applicationContext)

        // ── MethodChannel ─────────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Notification access ───────────────────────────────────
                    "isNotificationAccessEnabled" -> {
                        val enabledPackages =
                            NotificationManagerCompat.getEnabledListenerPackages(this)
                        result.success(enabledPackages.contains(packageName))
                    }
                    "openNotificationAccessSettings" -> {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(null)
                    }

                    // ── TTS test ──────────────────────────────────────────────
                    "speakTest" -> {
                        // Route Test Soundbox button through native TTS.
                        // This is a dev/test action and does NOT save payment history.
                        PaymentNotificationListener.ttsHelper?.speakTest()
                        result.success(null)
                    }

                    // ── Soundbox ON/OFF ───────────────────────────────────────
                    "isSoundboxEnabled" -> {
                        result.success(SharedPreferencesManager.isSoundboxEnabled())
                    }
                    "setSoundboxEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        SharedPreferencesManager.setSoundboxEnabled(enabled)
                        result.success(null)
                    }

                    // ── Speech speed ──────────────────────────────────────────
                    "getSpeechSpeed" -> {
                        result.success(SharedPreferencesManager.getSpeechSpeed())
                    }
                    "setSpeechSpeed" -> {
                        val speed = call.argument<String>("speed") ?: "normal"
                        try {
                            SharedPreferencesManager.setSpeechSpeed(speed)
                            // Apply immediately to running TTS engine.
                            PaymentNotificationListener.ttsHelper?.updateSpeechRate()
                        } catch (e: IllegalArgumentException) {
                            result.error("INVALID_SPEED", e.message, null)
                            return@setMethodCallHandler
                        }
                        result.success(null)
                    }

                    // ── Payment history ───────────────────────────────────────
                    "getPaymentHistory" -> {
                        val records = SharedPreferencesManager.getHistory()
                        // Convert to a list of maps for Flutter (JSON-compatible).
                        val list = records.map { rec ->
                            mapOf(
                                "amount"      to rec.amount,
                                "appName"     to rec.appName,
                                "trustLevel"  to rec.trustLevel,
                                "timestampMs" to rec.timestampMs,
                            )
                        }
                        result.success(list)
                    }
                    "clearPaymentHistory" -> {
                        SharedPreferencesManager.clearHistory()
                        result.success(null)
                    }

                    // ── Onboarding ────────────────────────────────────────────
                    "isOnboardingCompleted" -> {
                        result.success(SharedPreferencesManager.isOnboardingCompleted())
                    }
                    "setOnboardingCompleted" -> {
                        SharedPreferencesManager.setOnboardingCompleted()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }

        // ── EventChannel (notification stream) ────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {

                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    // Hand the sink to the service so it can push events.
                    PaymentNotificationListener.eventSink = sink
                }

                override fun onCancel(arguments: Any?) {
                    // Flutter stopped listening — clear the sink to avoid sending
                    // events into a dead stream.
                    PaymentNotificationListener.eventSink = null
                }
            })
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clear the sink when the Activity is destroyed so the service
        // does not try to send to a stale reference.
        PaymentNotificationListener.eventSink = null
    }
}

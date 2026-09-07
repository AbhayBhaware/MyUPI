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
                                "amount"             to rec.amount,
                                "appName"            to rec.appName,
                                "trustLevel"         to rec.trustLevel,
                                "timestampMs"        to rec.timestampMs,
                                "verificationStatus" to rec.verificationStatus,
                                "source"             to rec.source,
                                "parserVersion"      to rec.parserVersion,
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

                    // ── Merchant Settings ─────────────────────────────────────
                    "getMerchantName" -> {
                        result.success(SharedPreferencesManager.getMerchantName())
                    }
                    "setMerchantName" -> {
                        val name = call.argument<String>("name") ?: "MyUPI"
                        SharedPreferencesManager.setMerchantName(name)
                        result.success(null)
                    }
                    "getAnnouncementFormat" -> {
                        result.success(SharedPreferencesManager.getAnnouncementFormat())
                    }
                    "setAnnouncementFormat" -> {
                        val format = call.argument<String>("format") ?: "A"
                        try {
                            SharedPreferencesManager.setAnnouncementFormat(format)
                        } catch (e: IllegalArgumentException) {
                            result.error("INVALID_FORMAT", e.message, null)
                            return@setMethodCallHandler
                        }
                        result.success(null)
                    }
                    "getIncludeShopName" -> {
                        result.success(SharedPreferencesManager.isIncludeShopNameEnabled())
                    }
                    "setIncludeShopName" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        SharedPreferencesManager.setIncludeShopNameEnabled(enabled)
                        result.success(null)
                    }
                    
                    // ── Language ──────────────────────────────────────────────
                    "getLanguage" -> {
                        result.success(SharedPreferencesManager.getLanguage())
                    }
                    "setLanguage" -> {
                        val lang = call.argument<String>("language") ?: "en-IN"
                        SharedPreferencesManager.setLanguage(lang)
                        PaymentNotificationListener.ttsHelper?.updateLanguage()
                        result.success(null)
                    }
                    "checkLanguageAvailability" -> {
                        val lang = call.argument<String>("language") ?: "en-IN"
                        val available = PaymentNotificationListener.ttsHelper?.isLanguageAvailable(lang) ?: false
                        result.success(available)
                    }

                    // ── Architecture & Verification Readiness (M18 & M19) ────
                    "getMerchantProfile" -> {
                        result.success(SharedPreferencesManager.getMerchantProfile())
                    }
                    "getFeatureFlags" -> {
                        result.success(SharedPreferencesManager.getFeatureFlags())
                    }
                    "getSubscriptionTier" -> {
                        result.success(SharedPreferencesManager.getSubscriptionTier())
                    }
                    "getSubscriptionState" -> {
                        result.success(SharedPreferencesManager.getSubscriptionState())
                    }
                    "setSubscriptionState" -> {
                        val state = call.argument<String>("state") ?: "INTRO_OFFER_AVAILABLE"
                        SharedPreferencesManager.setSubscriptionState(state)
                        result.success(null)
                    }
                    "getDiagnostics" -> {
                        val enabledPackages =
                            NotificationManagerCompat.getEnabledListenerPackages(this)
                        val accessGranted = enabledPackages.contains(packageName)
                        val trustedMap = KotlinUpiDetector.getTrustedPackages()
                        val diagnostics = mapOf(
                            "notificationAccessGranted" to accessGranted,
                            "serviceBound"              to (PaymentNotificationListener.eventSink != null),
                            "parserVersion"             to KotlinUpiDetector.UPI_PARSER_VERSION,
                            "supportedPackagesCount"    to trustedMap.size,
                            "supportedPackages"         to trustedMap.keys.toList(),
                            "soundboxEnabled"           to SharedPreferencesManager.isSoundboxEnabled(),
                            "speechSpeed"               to SharedPreferencesManager.getSpeechSpeed(),
                            "language"                  to SharedPreferencesManager.getLanguage(),
                            "announcementFormat"        to SharedPreferencesManager.getAnnouncementFormat(),
                            "includeShopName"           to SharedPreferencesManager.isIncludeShopNameEnabled(),
                            "totalStoredPayments"       to SharedPreferencesManager.getHistory().size,
                            "merchantId"                to SharedPreferencesManager.getMerchantId(),
                            "subscriptionTier"          to SharedPreferencesManager.getSubscriptionTier(),
                            "subscriptionState"         to SharedPreferencesManager.getSubscriptionState(),
                            "featureFlags"              to SharedPreferencesManager.getFeatureFlags(),
                        )
                        result.success(diagnostics)
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

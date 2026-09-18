package com.example.myupi

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL = "com.example.myupi/notification_access"
        private const val EVENT_CHANNEL  = "com.example.myupi/notification_stream"
        private const val SMS_PERMISSION_REQUEST_CODE = 2001
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

                    // ── SMS Permission (Master Brief Part 1b) ─────────────────
                    "isSmsPermissionGranted" -> {
                        val granted = ContextCompat.checkSelfPermission(
                            this, Manifest.permission.RECEIVE_SMS
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    }
                    "requestSmsPermission" -> {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS),
                            SMS_PERMISSION_REQUEST_CODE
                        )
                        result.success(null)
                    }

                    // ── Battery Optimization Exemption (Master Brief Part 1a) ─
                    "isBatteryOptimizationIgnored" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        val isIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            pm?.isIgnoringBatteryOptimizations(packageName) ?: false
                        } else {
                            true
                        }
                        result.success(isIgnored)
                    }
                    "requestIgnoreBatteryOptimization" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            try {
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                // Fallback to battery saver settings
                                val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                startActivity(fallback)
                                result.success(false)
                            }
                        } else {
                            result.success(true)
                        }
                    }

                    // ── Per-App Notification Settings (Master Brief Part 1d) ──
                    "openAppNotificationSettings" -> {
                        val targetPkg = call.argument<String>("package") ?: packageName
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, targetPkg)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$targetPkg")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                        }
                        try {
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INTENT_FAILED", e.message, null)
                        }
                    }

                    // ── Installed UPI Apps List ───────────────────────────────
                    "getInstalledUpiApps" -> {
                        val upiPackages = listOf(
                            "com.phonepe.app" to "PhonePe",
                            "com.phonepe.app.b2b" to "PhonePe Business",
                            "com.google.android.apps.nbu.paisa.user" to "Google Pay",
                            "net.one97.paytm" to "Paytm",
                            "in.org.npci.upiapp" to "BHIM",
                            "in.amazon.mShop.android.shopping" to "Amazon Pay"
                        )
                        val installed = upiPackages.mapNotNull { (pkg, name) ->
                            try {
                                packageManager.getPackageInfo(pkg, 0)
                                mapOf("package" to pkg, "name" to name)
                            } catch (e: Exception) {
                                null
                            }
                        }
                        result.success(installed)
                    }

                    // ── OEM Autostart Guidance (Master Brief Part 1a & 1d) ────
                    "getDeviceManufacturer" -> {
                        result.success(Build.MANUFACTURER)
                    }
                    "openAutostartSettings" -> {
                        val manufacturer = Build.MANUFACTURER.lowercase()
                        val intent = Intent()
                        var handled = false

                        try {
                            when {
                                manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco") -> {
                                    intent.component = ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                                }
                                manufacturer.contains("oppo") || manufacturer.contains("realme") -> {
                                    intent.component = ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")
                                }
                                manufacturer.contains("vivo") || manufacturer.contains("iqoo") -> {
                                    intent.component = ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")
                                }
                                manufacturer.contains("oneplus") -> {
                                    intent.component = ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity")
                                }
                                manufacturer.contains("samsung") -> {
                                    intent.component = ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")
                                }
                            }
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            handled = true
                        } catch (e: Exception) {
                            // Fallback to standard app info settings
                            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallback)
                            handled = true
                        }
                        result.success(handled)
                    }

                    // ── Rebind Notification Listener (Master Brief Part 1a) ──
                    "rebindNotificationListener" -> {
                        PaymentNotificationListener.rebindService(this)
                        result.success(null)
                    }

                    // ── TTS test ──────────────────────────────────────────────
                    "speakTest" -> {
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

                    // ── Architecture & Diagnostics (Master Brief) ────────────
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
                        
                        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        val isBatteryIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            pm?.isIgnoringBatteryOptimizations(packageName) ?: false
                        } else {
                            true
                        }

                        val smsGranted = ContextCompat.checkSelfPermission(
                            this, Manifest.permission.RECEIVE_SMS
                        ) == PackageManager.PERMISSION_GRANTED

                        val diagnostics = mapOf(
                            "notificationAccessGranted" to accessGranted,
                            "serviceBound"              to (PaymentNotificationListener.eventSink != null),
                            "smsPermissionGranted"      to smsGranted,
                            "batteryOptimizationIgnored" to isBatteryIgnored,
                            "deviceManufacturer"        to Build.MANUFACTURER,
                            "deviceModel"               to Build.MODEL,
                            "androidVersion"            to Build.VERSION.RELEASE,
                            "parserVersion"             to KotlinUpiDetector.UPI_PARSER_VERSION,
                            "smsParserVersion"          to BankSmsDetector.SMS_PARSER_VERSION,
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
                            "recentLogs"                to SharedPreferencesManager.getDiagnosticLogs(),
                        )
                        result.success(diagnostics)
                    }

                    else -> result.notImplemented()
                }
            }

        // ── EventChannel (notification & SMS payment stream) ─────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {

                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    PaymentNotificationListener.eventSink = sink
                }

                override fun onCancel(arguments: Any?) {
                    PaymentNotificationListener.eventSink = null
                }
            })
    }

    override fun onDestroy() {
        super.onDestroy()
        PaymentNotificationListener.eventSink = null
    }
}

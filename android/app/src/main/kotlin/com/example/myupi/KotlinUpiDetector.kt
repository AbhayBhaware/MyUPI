package com.example.myupi

// KotlinUpiDetector.kt
//
// Background UPI payment detection — mirrors the Dart UpiNotificationDetector.
// ----------------------------------------------------------------------------
// Rules are intentionally identical to lib/upi_detector.dart so the Kotlin
// background path and the Flutter display path agree on every result.
//
// Supported apps:
//   PhonePe     com.phonepe.app / com.phonepe.app.b2b
//   Paytm       net.one97.paytm
//   Google Pay  com.google.android.apps.nbu.paisa.user
//   Amazon Pay  in.amazon.mShop.android.shopping
//   BHIM        in.org.npci.upiapp
//
// Non-UPI packages (e.g. SMS) are rejected at the first gate.
//
// IMPORTANT: Each app has its own strict regex — no broad "₹ → payment" logic.

import android.util.Log

private const val TAG = "MyUPI_BACKGROUND"

// ─── Result ──────────────────────────────────────────────────────────────────

data class KotlinPaymentResult(
    val isPayment: Boolean,
    val appName: String,
    val amount: String?,   // raw amount string, e.g. "1", "1,250", "25.50"
    val reason: String,
)

// ─── Trusted package allowlist ────────────────────────────────────────────────

private val UPI_PACKAGES: Map<String, String> = mapOf(
    "com.phonepe.app"                      to "PhonePe",
    "com.phonepe.app.b2b"                  to "PhonePe for Business",
    "net.one97.paytm"                      to "Paytm",
    "com.google.android.apps.nbu.paisa.user" to "Google Pay",
    "in.org.npci.upiapp"                   to "BHIM",
    "in.amazon.mShop.android.shopping"     to "Amazon Pay",
    "com.mobikwik_new"                     to "MobiKwik",
    "com.freecharge.android"               to "Freecharge",
    "com.axis.mobile"                      to "Axis Mobile",
    "com.sbi.lotusintouch"                 to "SBI YONO",
    "com.csam.icici.bank.imobile"          to "iMobile (ICICI)",
    "com.snapwork.hdfc"                    to "HDFC MobileBanking",
)

// ─── Common negative keywords ─────────────────────────────────────────────────

private val COMMON_NEGATIVES = listOf(
    "failed", "failure", "declined", "pending",
    "cancelled", "canceled", "cancel", "cancellation",
    "refund", "refunded", "refunding",
    "reversed", "reversal",
    "expired",
    "request", "collect request", "requesting",
    "remind", "reminder",
    "debit", "debited",
    "paid to",
)

// ─── Amount regex ─────────────────────────────────────────────────────────────
// Matches: ₹<digits>[,<digits>][.<1-2 digits>]
// Used inside each app-specific pattern.

private val AMOUNT_PAT = """[\d,]+(?:\.\d{1,2})?"""

// ─── PhonePe ──────────────────────────────────────────────────────────────────
// Confirmed pattern (real device): "sent ₹<amount> to you"

private val PHONEPE_INCOMING =
    Regex("""sent\s+₹\s*($AMOUNT_PAT)\s+to\s+you""", RegexOption.IGNORE_CASE)

private fun detectPhonePe(pkg: String, title: String, text: String): KotlinPaymentResult {
    val combined = "${title.lowercase()} ${text.lowercase()}"
    for (neg in COMMON_NEGATIVES + listOf("sent to")) {
        if (combined.contains(neg)) {
            return KotlinPaymentResult(false, "PhonePe", null,
                "PhonePe: Negative signal \"$neg\"")
        }
    }
    val m = PHONEPE_INCOMING.find("$title $text")
    val amt = m?.groupValues?.getOrNull(1)?.takeIf { it.isNotEmpty() }
    return if (amt != null) {
        Log.d(TAG, "PhonePe payment matched. Amount: $amt")
        KotlinPaymentResult(true, "PhonePe", amt, "PhonePe incoming payment notification")
    } else {
        KotlinPaymentResult(false, "PhonePe", null,
            "PhonePe: No incoming-payment pattern matched.")
    }
}

// ─── Paytm ────────────────────────────────────────────────────────────────────
// Confirmed pattern (real device): "Received ₹<amount> from <sender>"

private val PAYTM_INCOMING =
    Regex("""received\s+₹\s*($AMOUNT_PAT)\s+from""", RegexOption.IGNORE_CASE)

private val PAYTM_NEGATIVES = COMMON_NEGATIVES + listOf("sent to")

private fun detectPaytm(pkg: String, title: String, text: String): KotlinPaymentResult {
    val combined = "${title.lowercase()} ${text.lowercase()}"
    for (neg in PAYTM_NEGATIVES) {
        if (combined.contains(neg)) {
            return KotlinPaymentResult(false, "Paytm", null,
                "Paytm: Negative signal \"$neg\"")
        }
    }
    val m = PAYTM_INCOMING.find("$title $text")
    val amt = m?.groupValues?.getOrNull(1)?.takeIf { it.isNotEmpty() }
    return if (amt != null) {
        Log.d(TAG, "Paytm payment matched. Amount: $amt")
        KotlinPaymentResult(true, "Paytm", amt, "Paytm incoming payment notification")
    } else {
        KotlinPaymentResult(false, "Paytm", null,
            "Paytm: No incoming-payment pattern matched.")
    }
}

// ─── Google Pay ───────────────────────────────────────────────────────────────
// Reference pattern: "<sender> sent ₹<amount> to you"
// Outgoing: "You sent ₹<amount> to <someone>" — rejected explicitly.

private val GPAY_INCOMING =
    Regex("""sent\s+₹\s*($AMOUNT_PAT)\s+to\s+you""", RegexOption.IGNORE_CASE)

private val GPAY_OUTGOING_YOU_SENT =
    Regex("""^\s*you\s+sent\b""", RegexOption.IGNORE_CASE)

private val GPAY_NEGATIVES = COMMON_NEGATIVES + listOf("paid to")

private fun detectGooglePay(pkg: String, title: String, text: String): KotlinPaymentResult {
    // Reject outgoing first
    if (GPAY_OUTGOING_YOU_SENT.containsMatchIn(text) ||
        GPAY_OUTGOING_YOU_SENT.containsMatchIn(title)) {
        return KotlinPaymentResult(false, "Google Pay", null,
            "Google Pay: Outgoing payment (\"you sent ...\") — not incoming.")
    }
    val combined = "${title.lowercase()} ${text.lowercase()}"
    for (neg in GPAY_NEGATIVES) {
        if (combined.contains(neg)) {
            return KotlinPaymentResult(false, "Google Pay", null,
                "Google Pay: Negative signal \"$neg\"")
        }
    }
    val m = GPAY_INCOMING.find("$title $text")
    val amt = m?.groupValues?.getOrNull(1)?.takeIf { it.isNotEmpty() }
    return if (amt != null) {
        Log.d(TAG, "Google Pay payment matched. Amount: $amt")
        KotlinPaymentResult(true, "Google Pay", amt, "Google Pay incoming payment notification")
    } else {
        KotlinPaymentResult(false, "Google Pay", null,
            "Google Pay: No incoming-payment pattern matched.")
    }
}

// ─── Amazon Pay ───────────────────────────────────────────────────────────────
// Reference pattern: "You received ₹<amount> from <sender>"

private val AMAZON_INCOMING =
    Regex("""you\s+received\s+₹\s*($AMOUNT_PAT)\s+from""", RegexOption.IGNORE_CASE)

private val AMAZON_NEGATIVES = COMMON_NEGATIVES + listOf("sent to")

private fun detectAmazonPay(pkg: String, title: String, text: String): KotlinPaymentResult {
    val combined = "${title.lowercase()} ${text.lowercase()}"
    for (neg in AMAZON_NEGATIVES) {
        if (combined.contains(neg)) {
            return KotlinPaymentResult(false, "Amazon Pay", null,
                "Amazon Pay: Negative signal \"$neg\"")
        }
    }
    val m = AMAZON_INCOMING.find("$title $text")
    val amt = m?.groupValues?.getOrNull(1)?.takeIf { it.isNotEmpty() }
    return if (amt != null) {
        Log.d(TAG, "Amazon Pay payment matched. Amount: $amt")
        KotlinPaymentResult(true, "Amazon Pay", amt, "Amazon Pay incoming payment notification")
    } else {
        KotlinPaymentResult(false, "Amazon Pay", null,
            "Amazon Pay: No incoming-payment pattern matched.")
    }
}

// ─── BHIM ─────────────────────────────────────────────────────────────────────
// Reference pattern: "₹<amount> received from <sender>"

private val BHIM_INCOMING =
    Regex("""₹\s*($AMOUNT_PAT)\s+received\s+from""", RegexOption.IGNORE_CASE)

private val BHIM_NEGATIVES = COMMON_NEGATIVES + listOf("sent to")

private fun detectBhim(pkg: String, title: String, text: String): KotlinPaymentResult {
    val combined = "${title.lowercase()} ${text.lowercase()}"
    for (neg in BHIM_NEGATIVES) {
        if (combined.contains(neg)) {
            return KotlinPaymentResult(false, "BHIM", null,
                "BHIM: Negative signal \"$neg\"")
        }
    }
    val m = BHIM_INCOMING.find("$title $text")
    val amt = m?.groupValues?.getOrNull(1)?.takeIf { it.isNotEmpty() }
    return if (amt != null) {
        Log.d(TAG, "BHIM payment matched. Amount: $amt")
        KotlinPaymentResult(true, "BHIM", amt, "BHIM incoming payment notification")
    } else {
        KotlinPaymentResult(false, "BHIM", null,
            "BHIM: No incoming-payment pattern matched.")
    }
}

// ─── Main entry point ─────────────────────────────────────────────────────────

object KotlinUpiDetector {

    /**
     * Analyse a single notification.
     *
     * Returns null if the package is not a known UPI app (fast reject).
     * Returns a [KotlinPaymentResult] otherwise.
     */
    fun detect(packageName: String, title: String, text: String): KotlinPaymentResult? {
        val safeTitle = title.trim()
        val safeText  = text.trim()

        // 1. Trusted-package gate — non-UPI packages (including SMS apps) are
        //    rejected here and NEVER reach any payment parser.
        if (!UPI_PACKAGES.containsKey(packageName)) {
            Log.v(TAG, "Non-UPI package ignored: $packageName")
            return null
        }

        Log.d(TAG, "Detecting | Package: $packageName | Title: \"$safeTitle\" | Text: \"$safeText\"")

        // 2. Route to app-specific detector.
        return when (packageName) {
            "com.phonepe.app",
            "com.phonepe.app.b2b"                    -> detectPhonePe(packageName, safeTitle, safeText)

            "net.one97.paytm"                         -> detectPaytm(packageName, safeTitle, safeText)

            "com.google.android.apps.nbu.paisa.user"  -> detectGooglePay(packageName, safeTitle, safeText)

            "in.amazon.mShop.android.shopping"        -> detectAmazonPay(packageName, safeTitle, safeText)

            "in.org.npci.upiapp"                      -> detectBhim(packageName, safeTitle, safeText)

            else -> {
                // Known UPI app but no app-specific detector yet.
                // Log and treat as non-payment (conservative — no false TTS).
                Log.d(TAG, "Known UPI app $packageName — no app-specific detector, skipping.")
                KotlinPaymentResult(false, UPI_PACKAGES[packageName] ?: packageName,
                    null, "No app-specific detector for $packageName")
            }
        }
    }
}

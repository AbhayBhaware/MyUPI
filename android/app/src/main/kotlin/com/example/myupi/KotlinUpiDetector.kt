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

import android.util.Log

private const val TAG = "MyUPI_BACKGROUND"

// ─── Result ──────────────────────────────────────────────────────────────────

data class KotlinPaymentResult(
    val trustLevel: String, // "HIGH", "MEDIUM", "LOW"
    val appName: String,
    val amount: String?,    // raw amount string, e.g. "1", "1,250", "25.50"
    val reason: String,
    val parserVersion: Int = KotlinUpiDetector.UPI_PARSER_VERSION,
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

// ─── Regex Patterns ───────────────────────────────────────────────────────────

private val AMOUNT_PAT = """[\d,]+(?:\.\d{1,2})?"""

// Fallback regex to check if there is an amount anywhere
private val GENERIC_AMOUNT_PRESENT = Regex("""₹\s*[\d,]+(?:\.\d{1,2})?""")

// ─── PhonePe ──────────────────────────────────────────────────────────────────

private val PHONEPE_PATTERNS = listOf(
    Regex("""sent\s+₹\s*($AMOUNT_PAT)\s+to\s+you""", RegexOption.IGNORE_CASE),
    Regex("""(?:payment\s+of\s+)?₹\s*($AMOUNT_PAT)\s+received""", RegexOption.IGNORE_CASE),
    Regex("""received\s+₹\s*($AMOUNT_PAT)""", RegexOption.IGNORE_CASE),
)

private fun detectPhonePe(pkg: String, title: String, text: String): KotlinPaymentResult {
    val combined = "${title.lowercase()} ${text.lowercase()}"
    for (neg in COMMON_NEGATIVES) {
        if (combined.contains(neg)) {
            return KotlinPaymentResult("LOW", "PhonePe", null, "PhonePe: Negative signal \"$neg\"")
        }
    }
    
    val searchIn = "$title $text"
    for (pat in PHONEPE_PATTERNS) {
        val m = pat.find(searchIn)
        val amt = m?.groupValues?.getOrNull(1)?.takeIf { it.isNotEmpty() }
        if (amt != null) {
            val appLabel = if (pkg.contains("b2b")) "PhonePe for Business" else "PhonePe"
            Log.d(TAG, "$appLabel payment matched. Amount: $amt")
            return KotlinPaymentResult("HIGH", appLabel, amt, "$appLabel incoming payment notification")
        }
    }
    
    val fallbackLabel = if (pkg.contains("b2b")) "PhonePe for Business" else "PhonePe"
    return detectGeneric(pkg, title, text, fallbackLabel)
}

// ─── Paytm ────────────────────────────────────────────────────────────────────

private val PAYTM_PATTERNS = listOf(
    Regex("""received\s+₹\s*($AMOUNT_PAT)""", RegexOption.IGNORE_CASE),
    Regex("""₹\s*($AMOUNT_PAT)\s+received""", RegexOption.IGNORE_CASE),
)

private fun detectPaytm(pkg: String, title: String, text: String): KotlinPaymentResult {
    val combined = "${title.lowercase()} ${text.lowercase()}"
    for (neg in COMMON_NEGATIVES) {
        if (combined.contains(neg)) {
            return KotlinPaymentResult("LOW", "Paytm", null, "Paytm: Negative signal \"$neg\"")
        }
    }
    
    val searchIn = "$title $text"
    for (pat in PAYTM_PATTERNS) {
        val m = pat.find(searchIn)
        val amt = m?.groupValues?.getOrNull(1)?.takeIf { it.isNotEmpty() }
        if (amt != null) {
            Log.d(TAG, "Paytm payment matched. Amount: $amt")
            return KotlinPaymentResult("HIGH", "Paytm", amt, "Paytm incoming payment notification")
        }
    }
    
    return detectGeneric(pkg, title, text, "Paytm")
}

// ─── Google Pay ───────────────────────────────────────────────────────────────

private val GPAY_PATTERNS = listOf(
    Regex("""sent\s+₹\s*($AMOUNT_PAT)\s+to\s+you""", RegexOption.IGNORE_CASE),
    Regex("""received\s+₹\s*($AMOUNT_PAT)""", RegexOption.IGNORE_CASE),
    Regex("""₹\s*($AMOUNT_PAT)\s+received""", RegexOption.IGNORE_CASE),
    Regex("""paid\s+you\s+₹\s*($AMOUNT_PAT)""", RegexOption.IGNORE_CASE),
)
private val GPAY_OUTGOING_YOU_SENT = Regex("""^\s*you\s+sent\b""", RegexOption.IGNORE_CASE)
private val GPAY_NEGATIVES = COMMON_NEGATIVES + listOf("paid to")

private fun detectGooglePay(pkg: String, title: String, text: String): KotlinPaymentResult {
    if (GPAY_OUTGOING_YOU_SENT.containsMatchIn(text) || GPAY_OUTGOING_YOU_SENT.containsMatchIn(title)) {
        return KotlinPaymentResult("LOW", "Google Pay", null, "Google Pay: Outgoing payment (\"you sent ...\") — not incoming.")
    }
    
    val combined = "${title.lowercase()} ${text.lowercase()}"
    for (neg in GPAY_NEGATIVES) {
        if (combined.contains(neg)) {
            return KotlinPaymentResult("LOW", "Google Pay", null, "Google Pay: Negative signal \"$neg\"")
        }
    }
    
    val searchIn = "$title $text"
    for (pat in GPAY_PATTERNS) {
        val m = pat.find(searchIn)
        val amt = m?.groupValues?.getOrNull(1)?.takeIf { it.isNotEmpty() }
        if (amt != null) {
            Log.d(TAG, "Google Pay payment matched. Amount: $amt")
            return KotlinPaymentResult("HIGH", "Google Pay", amt, "Google Pay incoming payment notification")
        }
    }
    
    return detectGeneric(pkg, title, text, "Google Pay")
}

// ─── Amazon Pay ───────────────────────────────────────────────────────────────

private val AMAZON_PATTERNS = listOf(
    Regex("""(?:you\s+)?received\s+₹\s*($AMOUNT_PAT)""", RegexOption.IGNORE_CASE),
    Regex("""₹\s*($AMOUNT_PAT)\s+received""", RegexOption.IGNORE_CASE),
)

private fun detectAmazonPay(pkg: String, title: String, text: String): KotlinPaymentResult {
    val combined = "${title.lowercase()} ${text.lowercase()}"
    for (neg in COMMON_NEGATIVES) {
        if (combined.contains(neg)) {
            return KotlinPaymentResult("LOW", "Amazon Pay", null, "Amazon Pay: Negative signal \"$neg\"")
        }
    }
    
    val searchIn = "$title $text"
    for (pat in AMAZON_PATTERNS) {
        val m = pat.find(searchIn)
        val amt = m?.groupValues?.getOrNull(1)?.takeIf { it.isNotEmpty() }
        if (amt != null) {
            Log.d(TAG, "Amazon Pay payment matched. Amount: $amt")
            return KotlinPaymentResult("HIGH", "Amazon Pay", amt, "Amazon Pay incoming payment notification")
        }
    }
    
    return detectGeneric(pkg, title, text, "Amazon Pay")
}

// ─── BHIM ─────────────────────────────────────────────────────────────────────

private val BHIM_PATTERNS = listOf(
    Regex("""₹\s*($AMOUNT_PAT)\s+received""", RegexOption.IGNORE_CASE),
    Regex("""received\s+₹\s*($AMOUNT_PAT)""", RegexOption.IGNORE_CASE),
)

private fun detectBhim(pkg: String, title: String, text: String): KotlinPaymentResult {
    val combined = "${title.lowercase()} ${text.lowercase()}"
    for (neg in COMMON_NEGATIVES) {
        if (combined.contains(neg)) {
            return KotlinPaymentResult("LOW", "BHIM", null, "BHIM: Negative signal \"$neg\"")
        }
    }
    
    val searchIn = "$title $text"
    for (pat in BHIM_PATTERNS) {
        val m = pat.find(searchIn)
        val amt = m?.groupValues?.getOrNull(1)?.takeIf { it.isNotEmpty() }
        if (amt != null) {
            Log.d(TAG, "BHIM payment matched. Amount: $amt")
            return KotlinPaymentResult("HIGH", "BHIM", amt, "BHIM incoming payment notification")
        }
    }
    
    return detectGeneric(pkg, title, text, "BHIM")
}

// ─── Generic Fallback ─────────────────────────────────────────────────────────

private val GENERIC_POSITIVE_KEYWORDS = listOf(
    "received", "credited", "credit", "money received", 
    "payment received", "upi payment received", "amount received", "amount credited"
)
private val GENERIC_AMOUNT_EXTRACT = Regex("""₹\s*($AMOUNT_PAT)""")

private fun detectGeneric(pkg: String, title: String, text: String, appName: String): KotlinPaymentResult {
    val combined = "${title.lowercase()} ${text.lowercase()}"
    for (neg in COMMON_NEGATIVES) {
        if (combined.contains(neg)) {
            return KotlinPaymentResult("LOW", appName, null, "Negative signal \"$neg\"")
        }
    }
    
    val searchIn = "$title $text"
    val amtMatch = GENERIC_AMOUNT_EXTRACT.find(searchIn)
    val amt = amtMatch?.groupValues?.getOrNull(1)?.takeIf { it.isNotEmpty() }
    
    val matched = mutableListOf<String>()
    for (pos in GENERIC_POSITIVE_KEYWORDS) {
        if (combined.contains(pos)) matched.add(pos)
    }
    
    if (matched.isNotEmpty() && amt != null) {
        return KotlinPaymentResult("HIGH", appName, amt, "Fallback payment matched keywords [${matched.joinToString(", ")}]")
    }
    
    if (matched.isNotEmpty()) {
        return KotlinPaymentResult("MEDIUM", appName, null, "Payment keywords found: ${matched.joinToString(", ")} (amount missing)")
    }
    
    return KotlinPaymentResult("LOW", appName, null, "From UPI app \"$appName\" but no confirmed payment pattern found.")
}

// ─── Main entry point ─────────────────────────────────────────────────────────

object KotlinUpiDetector {

    const val UPI_PARSER_VERSION = 1

    fun getTrustedPackages(): Map<String, String> = UPI_PACKAGES

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

        Log.d(TAG, "Detecting | Package: $packageName")

        // 2. Route to app-specific detector.
        return when (packageName) {
            "com.phonepe.app",
            "com.phonepe.app.b2b"                    -> detectPhonePe(packageName, safeTitle, safeText)

            "net.one97.paytm"                         -> detectPaytm(packageName, safeTitle, safeText)

            "com.google.android.apps.nbu.paisa.user"  -> detectGooglePay(packageName, safeTitle, safeText)

            "in.amazon.mShop.android.shopping"        -> detectAmazonPay(packageName, safeTitle, safeText)

            "in.org.npci.upiapp"                      -> detectBhim(packageName, safeTitle, safeText)

            else -> {
                val appName = UPI_PACKAGES[packageName] ?: packageName
                Log.d(TAG, "Known UPI app $packageName — using generic fallback.")
                detectGeneric(packageName, safeTitle, safeText, appName)
            }
        }
    }
}

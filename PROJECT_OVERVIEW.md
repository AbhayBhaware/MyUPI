# MyUPI — Project Overview

> **Turn your Android smartphone into a smart UPI payment soundbox with instant voice alerts in 8 Indian languages.**

---

## 1. Executive Summary

**MyUPI** is an offline-first, low-latency Android audio soundbox application designed for Indian merchants, shopkeepers, and small business owners. It replaces expensive dedicated hardware soundbox devices (which typically cost ₹125–₹150/month in rental and SIM fees) by intercepting incoming UPI payment notifications and speaking aloud the payment amount in real-time.

- **Primary Goal:** Eliminate hardware soundbox costs (saving merchants ₹1,500+/year) while providing instant, reliable payment announcements.
- **Target Platform:** Android (Flutter UI + Native Kotlin Background Service).
- **Languages Supported (8):** English (India), Hindi, Marathi, Gujarati, Tamil, Telugu, Bengali, and Kannada.
- **Privacy & Security:** 100% on-device processing, Zero-PII policy, no backend server or cloud dependency required for MVP.

---

## 2. System Architecture

MyUPI uses a **hybrid Flutter + Native Kotlin architecture** engineered for 100% background reliability:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        MyUPI ARCHITECTURE LAYOUT                       │
└────────────────────────────────────────────────────────────────────────┘

    [ INCOMING UPI NOTIFICATIONS ]
     (PhonePe, Google Pay, Paytm, BHIM, Bank UPI Apps)
                 │
                 ▼
    [ ANDROID OS NOTIFICATION SUBSYSTEM ]
                 │
                 ▼
    [ PaymentNotificationListener.kt ] (Android NotificationListenerService)
     ├─ 1. Package Allowlist Filter (12 trusted UPI apps)
     ├─ 2. Sliding Window Deduplication (45-second cache)
     ├─ 3. Strict RegEx Parser & Negative Keyword Filter (v1)
     ├─ 4. Trust Level Assignment (HIGH / MEDIUM / LOW)
     ├─ 5. Local Ledger Storage (SharedPreferences ring buffer, max 500)
     └─ 6. Native Android TextToSpeech Engine (Latency < 500ms)
                 │
                 │ (MethodChannel & EventChannel)
                 ▼
    [ FLUTTER UI LAYER ] (Runs on demand, survives UI kill/close)
     ├─ Dashboard & Soundbox Status Toggle
     ├─ Transaction Ledger & History Screen
     ├─ Voice, Speed, Shop Name & Announcement Settings
     ├─ Google Play Subscription Paywall (₹1 intro -> ₹49/mo)
     └─ Developer Diagnostics & Zero-PII Telemetry
```

### Decoupled Lifecycle Independence
A critical architectural requirement is that **voice announcements and payment ledger logging never depend on the Flutter UI or Dart VM being alive**:
- If the Flutter app is closed, swiped away, or memory-reclaimed by Android, [PaymentNotificationListener.kt](file:///c:/Users/HP/Flutter%20Project/MyUPI/android/app/src/main/kotlin/com/example/myupi/PaymentNotificationListener.kt) and [NativeTtsHelper.kt](file:///c:/Users/HP/Flutter%20Project/MyUPI/android/app/src/main/kotlin/com/example/myupi/NativeTtsHelper.kt) run autonomously in the native background process.
- When the merchant opens the Flutter app, [LocalPaymentRepository](file:///c:/Users/HP/Flutter%20Project/MyUPI/lib/repositories/payment_repository.dart#L25) loads transactions directly from [SharedPreferencesManager.kt](file:///c:/Users/HP/Flutter%20Project/MyUPI/android/app/src/main/kotlin/com/example/myupi/SharedPreferencesManager.kt).

---

## 3. Directory & File Structure

```
MyUPI/
├── android/app/src/main/kotlin/com/example/myupi/
│   ├── MainActivity.kt                 # MethodChannel & EventChannel bridges
│   ├── PaymentNotificationListener.kt  # NotificationListenerService implementation
│   ├── KotlinUpiDetector.kt            # Native parser, regex, allowlist & dedup
│   ├── NativeTtsHelper.kt              # Native Android TextToSpeech engine
│   └── SharedPreferencesManager.kt     # Ring buffer ledger & persistent preferences
├── lib/
│   ├── main.dart                       # App initialization & service wiring
│   ├── app_channels.dart               # Channel name constants
│   ├── upi_detector.dart               # Dart regex parser (in-app test tool)
│   ├── tts_service.dart                # Flutter TTS wrapper for UI previews
│   ├── models/
│   │   ├── payment_event.dart          # Canonical domain model for payments
│   │   ├── merchant_profile.dart       # Shop name, voice settings & language config
│   │   ├── subscription_state.dart     # Subscription lifecycle state machine
│   │   ├── subscription_tier.dart      # Free vs Pro tiers
│   │   └── feature_flags.dart          # Feature toggle definitions
│   ├── repositories/
│   │   └── payment_repository.dart     # Repository interface & local implementation
│   ├── services/
│   │   ├── billing_service.dart        # Google Play In-App Purchase client
│   │   ├── subscription_manager.dart   # Subscription state manager
│   │   ├── entitlement_manager.dart    # Feature entitlement gates
│   │   └── payment_source.dart         # Payment source abstraction
│   ├── screens/
│   │   ├── home_screen.dart            # Main dashboard & live feed
│   │   ├── history_screen.dart         # Payment ledger & search
│   │   ├── settings_screen.dart        # Language, shop name & audio settings
│   │   ├── paywall_screen.dart         # Subscription checkout & value proposition
│   │   ├── diagnostics_screen.dart     # Real-time system telemetry & Zero-PII audit
│   │   ├── help_support_screen.dart    # Battery optimization guides & FAQs
│   │   └── about_screen.dart           # App info, terms & disclaimers
│   ├── theme/                          # App theme, typography & palette
│   └── widgets/                        # Shared UI components & stat cards
└── docs/
    ├── architecture.md                 # Complete system architecture
    ├── google-play-subscription.md     # Google Play Billing implementation guide
    ├── payment-verification-architecture.md # Future payment verification roadmap
    ├── play-store-readiness.md         # Play Store listing metadata & submission guide
    └── subscription-product.md         # Subscription product specification
```

---

## 4. Key Architectural Patterns & Guarantees

### 1. Trust Score vs. Payment Verification
- **Trust Level (`HIGH`, `MEDIUM`, `LOW`):** Evaluates heuristic confidence that the Android notification is authentic (valid package, strict regex match, no negative words like "debited" or "failed").
- **Verification Status (`NOT_VERIFIED`):** Every notification-detected payment is strictly tagged `NOT_VERIFIED`. The app never displays fake "Bank Verified" checkmarks or misleads merchants into confusing UI notifications with settled banking deposits.

### 2. Zero-PII Policy
- No customer phone numbers, UPI IDs (VPA), or bank account numbers are extracted, logged, or announced.
- Diagnostics displays anonymized telemetry without persisting or exposing raw notification text.

### 3. Commercial Subscription Model
- **Product ID:** `myupi_soundbox_pro`
- **Pricing:** Introductory offer of **₹1 for the 1st month**, renewing at **₹49/month** recurring.
- **Graceful Degradation:** Free tier retains full offline soundbox functionality, standard languages, and local transaction logging even if subscription expires.

---

## 5. Documentation Directory Index

Detailed technical specifications are available in the [`docs/`](file:///c:/Users/HP/Flutter%20Project/MyUPI/docs) folder:

| Document | Description |
| :--- | :--- |
| [architecture.md](file:///c:/Users/HP/Flutter%20Project/MyUPI/docs/architecture.md) | Comprehensive system architecture, data contracts, and Android lifecycle design |
| [payment-verification-architecture.md](file:///c:/Users/HP/Flutter%20Project/MyUPI/docs/payment-verification-architecture.md) | Dual-path roadmap to integrate licensed Payment Aggregators (Cashfree, Razorpay) |
| [google-play-subscription.md](file:///c:/Users/HP/Flutter%20Project/MyUPI/docs/google-play-subscription.md) | Technical guide for Google Play Billing Library integration, testing & rules |
| [subscription-product.md](file:///c:/Users/HP/Flutter%20Project/MyUPI/docs/subscription-product.md) | Commercial product tiers, subscription state machine, and paywall UX specs |
| [play-store-readiness.md](file:///c:/Users/HP/Flutter%20Project/MyUPI/docs/play-store-readiness.md) | Store listing copy, permission justification declarations, and release checklists |

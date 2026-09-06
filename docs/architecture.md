# MyUPI Architecture & Future Verification Foundation

**Version:** 1.0 (Milestone 18)  
**Status:** Production Soundbox MVP + Future Verification Readiness  
**Target Platform:** Android (Flutter UI + Native Kotlin Foreground/Background Service)

---

## 1. Executive Summary

MyUPI is an offline-first, low-latency Android audio soundbox application designed for Indian merchants. It converts incoming UPI payment notifications into immediate, localized voice announcements (available in 8 Indian languages) and maintains a secure, local payment ledger.

Milestone 18 establishes a clean architectural foundation that decouples the current notification-based MVP from future payment verification backends without breaking existing merchant workflows, local persistence, or background processing.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        MyUPI ARCHITECTURE LAYOUT                       │
└────────────────────────────────────────────────────────────────────────┘

    [ INCOMING SIGNALS ]
     ├─ Android Notification (Active MVP) ─────────► [ NotificationPaymentSource ] ──┐
     └─ PA Webhook / Bank API (Future Ready) ──────► [ VerifiedPaymentSource ]     ──┤
                                                                                     ▼
    [ PROCESSING PIPELINE ]                                                [ PaymentEvent ]
     ├─ Trusted Package Allowlist (12 apps)                                 ├─ amount
     ├─ Strict Pattern Parser (v1)                                          ├─ appName
     ├─ Negative Keyword Filtering                                          ├─ timestamp
     ├─ In-Memory Duplicate Window (45s)                                    ├─ trustLevel (HIGH/MED/LOW)
     └─ Audio Engine (Native Android TTS)                                   ├─ verificationStatus (NOT_VERIFIED)
                                                                            ├─ source (NOTIFICATION)
    [ STORAGE & REPOSITORIES ]                                              └─ parserVersion (v1)
     ├─ SharedPreferences Ledger (max 500) ◄─────────────────────────────────────────┤
     └─ PaymentRepository Interface ◄────────────────────────────────────────────────┘
           ▲
           └───────── Flutter UI Layer (Dashboard, History, Settings, Diagnostics)
```

---

## 2. Current MVP Architecture & Boundaries

### 2.1 The Notification-Based Pipeline
In the current production MVP, payment detection operates entirely on-device via Android's `NotificationListenerService`:

```
Incoming UPI Push Notification (PhonePe, Google Pay, Paytm, etc.)
  │
  ▼
[ PaymentNotificationListener.kt ] (Android NotificationListenerService)
  │
  ├─ 1. Package Allowlist Gate: Check against 12 known UPI packages.
  │     Non-UPI packages (e.g., SMS, social apps) dropped immediately.
  │
  ├─ 2. Deduplication Gate: Check (package + title + text) against
  │     in-memory sliding window cache (45 seconds). Drop duplicates.
  │
  ├─ 3. Strict Parser & Trust Engine:
  │     - Match against strict regex patterns (v1).
  │     - Eliminate negative keywords ("failed", "debited", "refund", etc.).
  │     - Assign TrustLevel: HIGH, MEDIUM, or LOW.
  │     - Assign Source: NOTIFICATION.
  │     - Assign VerificationStatus: NOT_VERIFIED.
  │
  ├─ 4. Local Ledger Persistence:
  │     Write structured record to SharedPreferences (max 500 records).
  │
  ├─ 5. Native TTS Audio Announcement:
  │     If Soundbox is ON and TrustLevel is HIGH:
  │     Dispatch localized announcement via Android TextToSpeech engine.
  │
  └─ 6. Live UI Stream (Optional):
        If Flutter Activity is alive, dispatch event through EventChannel.
```

### 2.2 Strict MVP Operational Boundaries
To ensure reliability and compliance, the MVP adheres to the following constraints:
- **No External Backend**: Zero dependency on Firebase, AWS, or custom cloud servers.
- **No Direct Bank/UPI Integrations**: The app does NOT pretend to connect directly to NPCI or bank servers.
- **No Authentication / Merchant KYC**: Operates locally without login credentials, phone OTPs, or passwords.
- **Complete Zero-PII Policy**: Customer UPI IDs (VPA), phone numbers, and bank account numbers are NEVER captured, stored, or announced.

---

## 3. Trust Score vs. Payment Verification

A foundational architectural distinction in MyUPI is the separation between **Trust Score** and **Verification Status**:

| Dimension | Trust Score (`trustLevel`) | Verification Status (`verificationStatus`) |
| :--- | :--- | :--- |
| **Definition** | Heuristic confidence that the Android notification is an authentic incoming payment alert. | Cryptographic and accounting proof of settled funds in the merchant's bank account. |
| **Determined By** | Local parsing heuristics: allowlisted package ID, strict regex pattern, lack of negative keywords. | Bank settlement webhooks, Payment Gateway/Aggregator APIs, or NPCI settlement feeds. |
| **Values** | `HIGH`, `MEDIUM`, `LOW` | `NOT_VERIFIED` (MVP Default), `VERIFIED`, `FAILED`, `UNKNOWN` |
| **MVP Status** | **Fully active** (governs TTS announcements & warning badges). | **All notifications tagged `NOT_VERIFIED`**. |
| **Merchant Guarantee** | Protects against basic notification spoofing & accidental triggers. | Guaranteed bank-level financial finality (requires future aggregator phase). |

> [!IMPORTANT]
> **No Fake Verification**: MyUPI explicitly documents and tags all notification-detected payments as `NOT_VERIFIED`. The application never displays false "Bank Verified" checkmarks or misleads merchants into believing notifications equal settled banking deposits.

---

## 4. Core Domain Models & Abstractions

### 4.1 PaymentEvent (`lib/models/payment_event.dart`)
The canonical domain model representing any transaction signal across the application:

```dart
class PaymentEvent {
  final String amount;
  final String appName;
  final DateTime timestamp;
  final TrustLevel trustLevel;               // high, medium, low
  final VerificationStatus verificationStatus; // notVerified (default), verified, failed, unknown
  final PaymentSource source;                 // notification (default), paymentProvider, unknown
  final int parserVersion;                    // 1 (current engine version)
  // ...
}
```

### 4.2 PaymentSource (`lib/services/payment_source.dart`)
Abstraction decoupling incoming payment data providers:
- `NotificationPaymentSource`: Active MVP source listening to Android `NotificationListenerService`.
- `FutureVerifiedPaymentSource`: Architectural placeholder for licensed Payment Aggregator webhooks (Cashfree, Razorpay, PhonePe PG).

### 4.3 PaymentRepository (`lib/repositories/payment_repository.dart`)
Repository pattern abstracting data access:
- `PaymentRepository`: Interface declaring `getPaymentHistory()`, `clearPaymentHistory()`, `getMerchantProfile()`, `getFeatureFlags()`, `getSubscriptionTier()`, and `getDiagnostics()`.
- `LocalPaymentRepository`: Implementation delegating to Android `MethodChannel` and `SharedPreferencesManager`.

### 4.4 MerchantProfile (`lib/models/merchant_profile.dart`)
Encapsulates localized merchant identity:
- `merchantId`: Unique UUID generated and stored locally upon first launch.
- `shopName`: Merchant store name (default: "MyUPI").
- `preferredLanguage`: Active voice language code (e.g., `en-IN`, `hi-IN`).
- `speechSpeed`: Speech rate (`slow`, `normal`, `fast`).
- `announcementFormat`: Template format (`A`, `B`, `C`).
- `soundboxEnabled`: Master audio toggle.
- `includeShopName`: Flag indicating whether to append shop name to voice announcements.

### 4.5 FeatureFlags & SubscriptionTier
- `FeatureFlags`: `notificationSoundbox` (true), `verifiedPayments` (false), `backendSync` (false), `premiumFeatures` (false).
- `SubscriptionTier`: Defaulting to `FREE`. Ready for future tiered service levels.

---

## 5. Decoupled Service & Android Lifecycle Independence

A primary requirement of the MyUPI soundbox is that **voice announcements and payment history logging must NEVER depend on the Flutter UI or Dart VM being alive**.

```
┌─────────────────────────────────────────────────────────────┐
│                 OS LEVEL: ANDROID SYSTEM                    │
└────────────────┬────────────────────────────┬───────────────┘
                 │                            │
  [ NotificationListenerService ]     [ Flutter UI Process ]
                 │                    (Can be closed, killed,
                 │                     or paused anytime)
                 ▼                            │
  ┌───────────────────────────────┐           │
  │ Native Kotlin Background      │           │
  │ - SharedPreferencesManager    │           ▼
  │ - TextToSpeech Audio Engine   │    [ MethodChannel / UI ]
  │ - KotlinUpiDetector           │    Reads persisted data
  │ - Deduplication Memory Window │    when launched by user.
  └───────────────────────────────┘
```

1. **Autonomous Operation**: `PaymentNotificationListener` handles notification interception, parsing, history persistence, and TTS speech completely in native Kotlin.
2. **State Persistence**: When Flutter boots or the user opens the History screen, it reads the persisted list from `SharedPreferences` via `getPaymentHistory`.
3. **No Lost Transactions**: If the Flutter engine crashes or the user swipes the app away from recent tasks, incoming payments are still announced and saved to the ledger.

---

## 6. Versioned UPI Parser Engine

Payment parsing logic is versioned (`UPI_PARSER_VERSION = 1`):
- **Dart Parser**: `lib/upi_detector.dart` (`kParserVersion = 1`).
- **Kotlin Background Parser**: `KotlinUpiDetector.kt` (`UPI_PARSER_VERSION = 1`).
- **Diagnostics Integration**: The active parser version is reported in Developer Diagnostics and stored with every payment record for auditability.
- **Future Upgrades**: Enables seamless rollout of parser updates (e.g., v2 for new regional banks) without breaking historic data records.

---

## 7. Developer Diagnostics & Privacy Filter

The Developer Diagnostics screen (`lib/screens/diagnostics_screen.dart`) provides real-time system visibility while enforcing strict privacy boundaries:

- **System Health**: Notification Access status, background service binding, audio state.
- **Parser Telemetry**: Parser engine version (`v1`), trusted package allowlist count and identifiers.
- **Feature Flags & Entitlements**: Active feature toggles and subscription tier (`FREE`).
- **Zero-PII Assurance**:
  - Zero raw notification strings are rendered or retained.
  - Zero customer phone numbers, UPI IDs, or account numbers.
  - Anonymized merchant identifier (local UUID).

---

## 8. Future Verification Integration Points

When business requirements demand cryptographic bank-level verification, MyUPI is architected to evolve through licensed Payment Aggregators (PAs) without discarding the notification soundbox:

```
┌────────────────────────────────────────────────────────────────────────┐
│               FUTURE DUAL-PATH VERIFICATION ARCHITECTURE              │
└────────────────────────────────────────────────────────────────────────┘

 [ Dynamic Merchant QR ] (Order ID / txId embedded: upi://pay?pa=...&tr=tx123)
       │
       ├─► Customer pays in any UPI App
       │       │
       │       ├─► 1. Instant Notification Path (0.5s latency)
       │       │      OS Notification ──► MyUPI Soundbox ──► Instant Speech
       │       │      (status: NOT_VERIFIED, source: NOTIFICATION)
       │       │
       │       └─► 2. Bank Settlement Path (1-3s latency)
       │              NPCI ──► Bank ──► PA (Razorpay/Cashfree/PhonePe PG)
       │                                       │
       │                                       ▼ [ Webhook ]
       │                              Cloud Aggregator Relay
       │                                       │
       │                                       ▼ [ FCM Push / SSE ]
       │                              MyUPI App (status promoted to: VERIFIED)
```

1. **Dual-Path Strategy**:
   - **Path 1 (Speed)**: Notification soundbox provides instant merchant audio feedback within 500ms.
   - **Path 2 (Finality)**: Secure webhook reconciles the transaction with bank settlement within 2-3 seconds, promoting the record's `verificationStatus` from `NOT_VERIFIED` to `VERIFIED`.
2. **Repository Readiness**: `PaymentRepository` and `PaymentEvent` already contain `verificationStatus`, `source`, and `parserVersion`. Future cloud sync or webhook listeners simply update existing repository entities.

---

## 9. Architectural Principles Checklist

- [x] **Zero Fake Verification**: Every notification-detected payment is labeled `NOT_VERIFIED`.
- [x] **Zero External Backend / Zero Firebase**: Completely self-contained.
- [x] **Decoupled Background Execution**: Detection and TTS run natively when Flutter engine is offline.
- [x] **Clean Abstractions**: `PaymentEvent`, `PaymentSource`, `PaymentRepository`, `MerchantProfile`, `FeatureFlags`.
- [x] **Backward Compatibility**: Existing database records migrate safely with fallback defaults.
- [x] **Developer Diagnostics**: Inspectable system state with strict Zero-PII filtering.

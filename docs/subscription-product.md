# MyUPI Smart Soundbox — Subscription Product & Paywall Architecture

**Document Version:** 1.0 (Milestone 19)  
**Status:** Product Architecture & Paywall UX (Zero Actual Billing)  
**Commercial Model:** ₹1 for the first month → Then ₹49/month recurring  

---

## 1. Product Model & Value Proposition

MyUPI is an offline-first, low-latency Android audio soundbox application designed for Indian merchants. It converts incoming UPI notifications from apps like PhonePe, Google Pay, Paytm, BHIM, and bank apps into immediate spoken announcements in 8 Indian languages.

### The Commercial Proposition
Hardware soundbox machines distributed by major payment aggregators typically carry hefty upfront costs, mandatory monthly SIM/rental fees (₹125–₹150/month), charging maintenance overhead, and proprietary vendor lock-in.

MyUPI empowers small merchants to:
> **"Turn your phone into a smart UPI Soundbox."**  
> **"Get instant voice announcements for your UPI payments."**  
> **"Save ₹1,500+ every year over hardware soundbox rentals."**

---

## 2. Commercial Pricing Structure

> [!IMPORTANT]
> **Billing Status Notice:**  
> **₹1 first month → ₹49/month is the intended commercial pricing model and is NOT currently connected to real billing.**  
> In Milestone 19, no real payment transactions occur. No payment gateways (Razorpay, Cashfree, PhonePe PG) or Google Play Billing SDKs are integrated. The application does not charge merchants or collect banking/card credentials.

### Pricing Details:
1. **Special Introductory Offer:**
   - **₹1 for the first month** (30 days of full access).
   - Designed to eliminate merchant adoption friction and build trust in voice reliability.
2. **Standard Recurring Price:**
   - **₹49 per month** thereafter.
   - Automatically billed monthly unless cancelled.
   - Merchant can cancel anytime directly from Settings without penalties or dark patterns.
3. **Transparent Disclosure:**
   - Every surface displaying "₹1" explicitly discloses the recurring ₹49/month follow-up pricing:  
     *"₹1 for your first month, then ₹49/month. Auto-renews monthly unless cancelled."*

---

## 3. Subscription State Model

The subscription lifecycle is defined by a clean, centralized state machine in `lib/models/subscription_state.dart`:

```
┌────────────────────────────────────────────────────────────────────────┐
│                     SUBSCRIPTION LIFECYCLE STATES                      │
└────────────────────────────────────────────────────────────────────────┘

    [ Fresh Install / Default ]
                │
                ▼
     INTRO_OFFER_AVAILABLE ──(Future Checkout)──► ACTIVE
                │                                    │
                │                                    ├─► GRACE_PERIOD (payment retry)
                │                                    │        │
                ▼                                    │        ▼
         NOT_SUBSCRIBED                              ├─► CANCELLED (active until end)
                                                     │        │
                                                     ▼        ▼
                                                  EXPIRED ◄───┘
```

| State | Definition | Entitlement Level | Merchant UI Label |
| :--- | :--- | :--- | :--- |
| `INTRO_OFFER_AVAILABLE` | **Default initial state**. Merchant has not subscribed yet; ₹1 offer is ready. | Standard Free | "Intro Offer Available" |
| `NOT_SUBSCRIBED` | Merchant declined intro offer or dismissed trial. | Standard Free | "Free Plan" |
| `ACTIVE` | Merchant has a valid, paid recurring subscription. | **Full Premium** | "MyUPI Premium Active" |
| `GRACE_PERIOD` | Renewal billing failed; temporary grace access granted. | **Full Premium** | "Grace Period" |
| `CANCELLED` | Merchant cancelled renewal, but the paid period is still unexpired. | **Full Premium** | "Cancelled (Active Until Period End)" |
| `EXPIRED` | Paid period ended without renewal; privileges revoked. | Standard Free | "Plan Expired" |
| `UNKNOWN` | Unrecognized state from persistence fallback. | Standard Free | "Standard Plan" |

---

## 4. Centralized Entitlement Architecture

Rather than scattering `if (isPremium)` checks across Flutter widgets, all capability decisions are mediated by `EntitlementManager` (`lib/services/entitlement_manager.dart`):

```
SubscriptionState
       ↓
SubscriptionManager.instance
       ↓
EntitlementManager
       ↓
Feature Access Query (e.g. canCustomizeShopAnnouncement, canExportHistory)
```

### Feature Entitlement Matrix:

| Feature Category | Capability Method | Free / Intro Offer | Premium / Active |
| :--- | :--- | :---: | :---: |
| **Basic Voice Soundbox** | `isCoreSoundboxAllowed` | ✅ **Allowed** | ✅ **Allowed** |
| **UPI Notification Parser** | `canDetectUpiPayments` | ✅ **Allowed** | ✅ **Allowed** |
| **Native Android TTS** | `canUseNativeTts` | ✅ **Allowed** | ✅ **Allowed** |
| **Duplicate Protection (45s)** | `isDuplicateProtectionActive` | ✅ **Allowed** | ✅ **Allowed** |
| **Local Payment History** | `canStorePaymentHistory` | ✅ (Up to 50 records) | ✅ (Up to 500 records) |
| **Default Voice Languages** | `canUseLanguage('en-IN'/'hi-IN')` | ✅ **Allowed** | ✅ **Allowed** |
| **Regional Indian Languages (8)** | `canUseAllIndianLanguages` | Standard (EN/HI) | ✅ **All 8 Languages** |
| **Voice Announcement Format A** | `canUseAnnouncementFormat('A')` | ✅ **Allowed** | ✅ **Allowed** |
| **Voice Formats B & C** | `canUseAdvancedAnnouncements` | Standard Format A | ✅ **Formats A, B, C** |
| **Shop Name in Audio** | `canCustomizeShopAnnouncement` | Disabled | ✅ **Enabled** |
| **Collection Insights** | `canUseAdvancedAnalytics` | Basic Daily Total | ✅ **Advanced Analytics** |
| **Export History (CSV/PDF)** | `canExportHistory` | Disabled | ✅ **Enabled** |

---

## 5. Core Soundbox Protection Guarantee

> [!CAUTION]
> **Zero Paywall Interference with Payment Safety:**  
> The subscription system is strictly decoupled from the core payment detection and audio announcement engine.

1. **Autonomous Android Background Service:**  
   `PaymentNotificationListener.kt` operates natively in the background. It intercepts push notifications, runs the strict allowlist regex, writes the ledger record, and invokes native Android TTS. It **never pauses for a paywall**.
2. **Zero Audio Interruption:**  
   The application never displays promotional popups, modal paywalls, or alert dialogs while an incoming payment is being parsed or announced.
3. **Emergency Fallback:**  
   Even if a merchant's subscription expires or cancels, basic soundbox functionality (voice announcement of amount and app name) remains active.

---

## 6. Paywall UX & User Flow

### Entry Points:
1. **Onboarding Completion:**  
   `Welcome` → `Notification Access` → `Soundbox Setup` → `Test Sound` → `Ready` → `Premium Intro`.  
   *The merchant is never blocked; they can tap "Continue with Free Soundbox" and enter the dashboard immediately without paying.*
2. **Merchant Dashboard (`HomeScreen`):**  
   A non-intrusive banner displays "Special Offer: ₹1 First Month" below the collection card.
3. **Settings Screen (`SettingsScreen`):**  
   A dedicated `MYUPI PREMIUM` card displays the current plan status, benefits, "View Premium Plans", and "Restore Purchases".

### Paywall Design Standards:
- **No Dark Patterns:** No artificial countdown timers, fake scarcity badges ("Only 2 left!"), or hidden auto-renewal clauses.
- **Honest Call-To-Action:** Primary CTA is labeled **"Subscriptions Coming Soon"** to avoid deceiving merchants into believing a purchase was executed.
- **Honest Restoration:** Secondary action **"Restore Purchases"** opens an informative modal clarifying that restoration will activate when billing launches.

---

## 7. Developer-Only Subscription State Simulator

To enable end-to-end testing of all UI states without billing SDKs, a dedicated development tool is embedded in **Developer Diagnostics** (`lib/screens/diagnostics_screen.dart`):

- **Prominent Tag:** Marked with an amber warning: `[DEVELOPMENT ONLY]`.
- **Functionality:** Toggles local state between `INTRO_OFFER_AVAILABLE`, `ACTIVE`, `GRACE_PERIOD`, `CANCELLED`, `EXPIRED`, and `NOT_SUBSCRIBED`.
- **Scope:** Persisted exclusively in local `SharedPreferences` on the test device for UI validation. It is isolated from production merchant flows.

---

## 8. Privacy & Data Minimization

In compliance with MyUPI's zero-PII architectural policy:
- **No Financial Secrets Stored:** Zero card numbers, CVVs, expiry dates, bank accounts, UPI PINs, OTPs, or passwords.
- **No Remote User Profiling:** Subscription state remains local to the device during this milestone.
- **No Ad Trackers:** Zero third-party ad networks or tracking telemetry scripts.

# MyUPI — Google Play Store Readiness & Submission Guide

**Document Version:** 1.0.0  
**Target Release:** Production v1.0.0 (Build 1)  
**App Name:** MyUPI  
**Package Name:** `com.example.myupi`

---

## 1. App Store Listing Metadata

### App Title
> **MyUPI - UPI Payment Soundbox**  
*(29 / 30 characters)*

### Short Description
> **Turn your phone into a smart UPI payment soundbox. Instant voice alerts.**  
*(75 / 80 characters)*

### Full Description
```text
Turn your Android phone into a smart UPI payment soundbox without any monthly machine rent or hardware costs!

MyUPI is designed specifically for Indian merchants, shopkeepers, and small business owners. Whenever a customer pays you via UPI, MyUPI instantly speaks out the payment amount aloud through your phone speaker in your preferred language.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WHY MERCHANTS LOVE MYUPI
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔊 INSTANT VOICE ALERTS:
Never miss a payment during rush hours. As soon as a payment arrives, your phone announces it aloud: "Received ₹500 on PhonePe".

🇮🇳 8 INDIAN LANGUAGES SUPPORTED:
Choose your preferred voice announcement language:
• English (India)
• हिन्दी (Hindi)
• मराठी (Marathi)
• ગુજરાતી (Gujarati)
• தமிழ் (Tamil)
• తెలుగు (Telugu)
• বাংলা (Bengali)
• ಕನ್ನಡ (Kannada)

🏪 CUSTOM SHOP BRANDING:
Personalize your announcements with your shop name (e.g., "Received ₹200 at Sharma Kirana Store").

📱 WORKS WITH ALL MAJOR UPI APPS:
Supports payment notifications from:
• PhonePe & PhonePe Business
• Google Pay & Google Pay for Business
• Paytm & Paytm for Business
• BHIM UPI
• Leading Indian bank UPI apps (SBI YONO, HDFC PayZapp, ICICI iMobile, Axis Pay, etc.)

🛡️ 100% PRIVATE & ON-DEVICE:
• Zero cloud servers or tracking.
• No bank logins, passwords, or UPI PINs needed.
• All notifications are processed strictly on your device.
• Does not read your personal SMS or OTPs.

⚡ NO EXTRA HARDWARE OR MONTHLY RENT:
Traditional soundbox machines charge ₹125 to ₹200 every month plus initial deposit fees. With MyUPI, your existing smartphone acts as your soundbox — saving you thousands of rupees every year!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SUBSCRIPTION & PLANS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Core soundbox features with English announcements.
• Introductory Offer: ₹1 for the first month.
• Premium recurring: ₹49/month.
• Unlocks all 8 Indian regional languages, speech speed controls, custom shop voice branding, and priority announcements.
• Cancel anytime via Google Play Store with zero cancellation fees.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HOW TO GET STARTED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Install MyUPI from Google Play.
2. Grant Notification Access so MyUPI can hear incoming payment alerts.
3. Choose your preferred language and test your phone speaker.
4. Enter your shop name.
5. You're ready! Keep your media volume up during business hours.

MyUPI is independently developed to empower Indian local retail businesses.
```

---

## 2. Google Play Data Safety Declaration

Google Play requires a comprehensive Data Safety section. Below is the exact declaration to input into the Play Console:

| Question | Answer | Rationale |
| :--- | :--- | :--- |
| **Does your app collect or share any user data?** | **No** (App core functionality) | Core app collects **zero** personal information, financial data, or credentials. |
| **Data shared with third parties?** | **No** | Zero user data is shared with any external third party. |
| **Data collected on-device?** | **No personal data collected** | Transaction records and preferences remain strictly on the local device. |
| **Is data encrypted in transit?** | **Yes** | Google Play Billing communications are end-to-end encrypted by Google Play Services. |
| **Can users request data deletion?** | **Yes** | Users can delete all local data anytime by tapping "Clear Data" in Android settings or uninstalling the app. |

### Financial & Payment Data Clarification
- **Google Play In-App Billing:** When users purchase the optional ₹1/₹49 subscription, Google Play processes the purchase. The app receives only an obfuscated purchase token to verify entitlement. MyUPI never accesses or stores credit cards, debit cards, UPI PINs, or bank account numbers.

---

## 3. App Permissions & Justification

### Mandatory Permission: `NotificationListenerService`
- **Permission Name:** `android.permission.BIND_NOTIFICATION_LISTENER_SERVICE`
- **Official Rationale for Play Console Reviewers:**
  > *"MyUPI is an assistive audio utility and payment soundbox for small merchants in India. The core functional purpose of the app is to announce incoming UPI merchant payments aloud via Text-to-Speech so that shopkeepers can verify transactions without looking at their phone screen. NotificationListenerService is strictly used to detect payment confirmation notifications from verified Indian UPI applications (PhonePe, Google Pay, Paytm, BHIM). No personal SMS, OTPs, chat messages, or personal notifications are read, stored, or transmitted off the device."*

### Zero High-Risk Permissions
The app strictly **does NOT request**:
- ❌ No `READ_SMS` / `RECEIVE_SMS`
- ❌ No `READ_CONTACTS`
- ❌ No `ACCESS_FINE_LOCATION`
- ❌ No `CAMERA`
- ❌ No `RECORD_AUDIO`
- ❌ No `READ_EXTERNAL_STORAGE` / `MANAGE_EXTERNAL_STORAGE`

---

## 4. Google Play Console Setup & Pricing Configuration

### Subscription Product Configuration
In **Play Console > Monetize > Subscriptions**:
1. **Subscription ID:** `myupi_premium_monthly`
2. **Base Plan ID:** `monthly-plan`
   - **Type:** Auto-renewing
   - **Billing Period:** 1 month
   - **Price (INR):** `₹49.00` (inclusive of tax)
   - **Grace Period:** 7 days
3. **Offer ID:** `intro-1rs-offer`
   - **Eligibility:** New subscribers only
   - **Phases:**
     - Type: Discounted price
     - Price: `₹1.00`
     - Duration: 1 month
   - **Recurrence:** Followed by regular base plan price of ₹49.00/month.

### In-App Purchase Acknowledgment
- BillingService implements `InAppPurchase.completePurchase()` to ensure all purchases are acknowledged within Google's mandatory 3-day window, preventing automatic refunds.

---

## 5. Pre-Launch Release Checklist

- [x] **App Icon & Branding:** Clean high-resolution launcher icon and "MyUPI" app label.
- [x] **Zero Developer Terminology:** Developer Diagnostics hidden behind 7-tap version gesture in About screen.
- [x] **6-Step Onboarding Flow:** Welcome → Notification Access → Soundbox Setup → Shop Profile → Test Soundbox → Ready.
- [x] **Local Multi-language TTS:** Offline announcements across 8 Indian languages.
- [x] **Zero PII Guarantee:** No customer identifiers, phone numbers, or account balances in UI or logs.
- [x] **Privacy Policy & Terms:** Accessible directly inside `AboutScreen` without requiring internet access.
- [x] **Help & Support:** Comprehensive FAQ covering OEM battery optimization, TTS setup, and subscription management.
- [x] **Google Play Billing Verification:** Restore purchases, license tester validation, and sanitized diagnostics.
- [x] **Release Build Target:** Signed Android App Bundle (AAB) targeting current Google Play target SDK.

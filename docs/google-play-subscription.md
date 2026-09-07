# Google Play Subscription Integration & Play Console Architecture

## Milestone 20: Real Google Play Billing Architecture

This document specifies the technical and operational design of the Google Play Subscription Billing integration in **MyUPI**, separating verified official facts, architectural recommendations, and working assumptions.

---

## 1. Regulatory & Technical Distinctions

### FACT (Verified Official Google Documentation)
1. **Google Play Subscription Model (Play Billing Library 5/6/7)**:
   - Google Play decouples subscriptions into **Subscription Products**, **Base Plans**, and **Offers**.
   - A single subscription product (e.g. `myupi_soundbox_pro`) can have multiple base plans defining billing period and renewal type (e.g. `monthly-recurring` for auto-renewing 1-month cycles).
   - Base plans can have multiple offers defining introductory discounts or free trials (e.g. `intro-offer-1inr` for first-month discount).
2. **Purchase Acknowledgement (Mandatory 3-Day Rule)**:
   - Google Play strictly requires that all non-consumed purchases (including recurring subscriptions) must be acknowledged within **3 days (72 hours)**.
   - Any purchase not acknowledged within 3 days is **automatically refunded and revoked** by Google Play.
   - Acknowledgement is implemented via `InAppPurchase.instance.completePurchase(purchase)`.
   - Repeated acknowledgement of already acknowledged purchases must be prevented.
3. **Purchase States**:
   - `PurchaseStatus.purchased`: Payment succeeded; entitlement is granted once validated and acknowledged.
   - `PurchaseStatus.pending`: Payment is processing (e.g., slow UPI bank processing, delayed debit, or parental approval). Premium entitlement **must NOT** be granted until confirmation is received.
   - `PurchaseStatus.canceled`: The merchant closed the Play Store sheet. No charge is made.
   - `PurchaseStatus.error`: Billing network or platform failure. Must display merchant-friendly error; never crash or expose raw stack traces.
   - `PurchaseStatus.restored`: Re-emitted upon `restorePurchases()`.
4. **License Testing Behavior**:
   - License testers added in Google Play Console (*Setup > License testing*) are not charged real money when using the Google Play Test Instrument ("Test card, always approves", "Test card, always declines", etc.).
   - Test subscription billing periods are drastically accelerated by Google Play:
     - A 1-month subscription renews every **5 minutes** (instead of 30 days).
     - It auto-renews up to **6 times** maximum before transitioning to expired.
5. **Pricing Floor Rules in India**:
   - Google Play Console enforces regional price minimums per currency. While Google introduced sub-dollar pricing in India (lowering the floor to ₹10 for apps/IAPs), subscriptions allow specific pricing tiers set in Play Console.
   - If Play Console enforces a minimum threshold of ₹10 for subscriptions/offers in India during product creation, the introductory price in Play Console must be configured to the lowest permitted floor (₹10) or ₹1 if accepted.
   - The app UI **never hardcodes the price as the source of truth**; it displays the dynamic localized price returned by Google Play `ProductDetails`.
6. **Core Soundbox Decoupling**:
   - `NotificationListenerService` and `NativeTtsHelper` execute in the native Android background process completely decoupled from the Play Billing client.
   - Google Play outages, network failures, or expired subscriptions **never crash or stop soundbox detection**.

### RECOMMENDATION (Best Practices)
1. **Use Official `in_app_purchase: ^3.3.0` & `in_app_purchase_android: ^0.5.3`**:
   - Maintained directly by Google's Flutter team.
   - Fully implements Play Billing Library 6/7.
2. **On-Device Restore Flow**:
   - Provide a clear "Restore Purchases" button that triggers `InAppPurchase.instance.restorePurchases()`.
3. **Graceful Degradation**:
   - When a subscription expires, local payment history is **never deleted or truncated**.
   - Standard features (offline detection, duplicate protection, English/Hindi voices) remain 100% active.

### ASSUMPTION
1. **Play Console Setup**:
   - The developer will create the subscription product `myupi_soundbox_pro` in the Google Play Console under the registered app package.
   - When running on a physical test device without active Play Store publishing, the app gracefully falls back to displaying connectivity status without crashing.

---

## 2. Google Play Product Model

### Product Specifications

| Entity | Identifier / Value | Description |
| :--- | :--- | :--- |
| **Subscription ID** | `myupi_soundbox_pro` | Master subscription product ID in Play Console |
| **Product Name** | MyUPI Soundbox Pro | Merchant-facing product title |
| **Base Plan ID** | `monthly-recurring` | 1-month auto-renewing billing cycle |
| **Base Plan Price** | ₹49 / month | Regular recurring price for India (INR) |
| **Offer ID** | `intro-offer-1inr` | Introductory pricing offer attached to `monthly-recurring` |
| **Eligibility** | New customer acquisition | Available only to users who haven't subscribed before |
| **Offer Phase 1** | ₹1 for 1 month (or ₹10 if Console minimum enforced) | Discounted single payment / fixed price phase |
| **Offer Phase 2** | Follows base plan: ₹49/month | Recurring automatic renewal until cancelled |

---

## 3. End-to-End Purchase Flow

```
┌───────────────────────────────────────────────────────────┐
│                       PaywallScreen                       │
│  - Mounts: calls BillingService.instance.queryProducts()  │
│  - Displays dynamic Play Store price: ₹1 (or ₹10) / ₹49   │
└─────────────────────────────┬─────────────────────────────┘
                              │
                    User taps "Start Premium"
                              │
                              ▼
┌───────────────────────────────────────────────────────────┐
│                      BillingService                       │
│  - Prepares GooglePlayPurchaseParam with offerIdToken     │
│  - Calls InAppPurchase.instance.buyNonConsumable(...)     │
└─────────────────────────────┬─────────────────────────────┘
                              │
                  Google Play Purchase Sheet
                              │
                              ▼
┌───────────────────────────────────────────────────────────┐
│               purchaseStream (BillingService)             │
│                                                           │
│  Case 1: PurchaseStatus.pending                           │
│  - Do NOT grant premium                                   │
│  - Show pending notification to merchant                  │
│                                                           │
│  Case 2: PurchaseStatus.canceled                          │
│  - Dismiss dialog; no charge made                         │
│                                                           │
│  Case 3: PurchaseStatus.error                             │
│  - Map error code to merchant-friendly message            │
│  - No crash; no raw stack trace                           │
│                                                           │
│  Case 4: PurchaseStatus.purchased / restored               │
│  - Validate productID == 'myupi_soundbox_pro'             │
│  - Mandatory Acknowledgement:                             │
│      if (purchase.pendingCompletePurchase) {              │
│        await _iap.completePurchase(purchase);             │
│      }                                                    │
│  - Sanitize token: e.g. "GPA.3341...6789"                │
│  - Update SubscriptionManager:                            │
│      updateFromPurchase(orderId, purchaseToken)           │
└─────────────────────────────┬─────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────┐
│                    SubscriptionManager                    │
│  - Sets state: SubscriptionState.active                   │
│  - Sets autoRenewing: true                                │
│  - Persists state to native SharedPreferences via         │
│    MethodChannel ('setSubscriptionState', 'ACTIVE')       │
└─────────────────────────────┬─────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────┐
│                    EntitlementManager                     │
│  - hasPremiumEntitlement = true                           │
│  - Unlocks: All 8 Indian languages, Shop voice branding,  │
│    Advanced announcement styles, CSV/PDF export           │
└───────────────────────────────────────────────────────────┘
```

---

## 4. Purchase Acknowledgement Details

- **Why is it mandatory?**
  Google Play implemented purchase acknowledgement to eliminate accidental double-billing and force apps to confirm receipt delivery. Any non-consumed purchase that is not acknowledged within **72 hours (3 days)** is automatically refunded and revoked by Google Play.
- **Implementation**:
  ```dart
  if (purchase.pendingCompletePurchase) {
    await _iap.completePurchase(purchase);
    _lastPurchaseAcknowledged = true;
  }
  ```
- **Duplicate Prevention**:
  `completePurchase` is only called when `pendingCompletePurchase` is `true`. Once acknowledged, `pendingCompletePurchase` becomes `false`.

---

## 5. Subscription Lifecycle States

| State | Definition | Entitlement Status | Soundbox Engine |
| :--- | :--- | :--- | :--- |
| `NOT_SUBSCRIBED` | Fresh installation; no subscription history. | Standard (Free) | Operational (Offline) |
| `INTRO_OFFER_AVAILABLE` | Free tier eligible for ₹1 first month offer. | Standard (Free) | Operational (Offline) |
| `ACTIVE` | Google Play subscription active and paid. | **Unlocked (Premium)** | Operational (Offline) |
| `GRACE_PERIOD` | Google Play payment retry period (up to 7 days). | **Unlocked (Premium)** | Operational (Offline) |
| `CANCELLED` | Cancelled by user, but current billing cycle unexpired. | **Unlocked (Premium)** | Operational (Offline) |
| `EXPIRED` | Billing cycle expired without renewal. | Standard (Free) | Operational (Offline) |

### Non-Disruptive Expiry Behavior
When a subscription transitions to `EXPIRED`:
1. Core Soundbox engine continues detecting UPI payments from PhonePe, GPay, Paytm, BHIM, and bank apps with 100% reliability.
2. English (`en-IN`) and Hindi (`hi-IN`) remain fully functional.
3. Custom shop voice branding returns to standard audio format.
4. **All stored merchant transaction history remains 100% intact.** Zero merchant records are ever pruned due to subscription expiration.

---

## 6. Safe Developer Diagnostics

To ensure zero security or privacy risks, developer diagnostics adhere to the following rules:
- **No Sensitive PII**: No customer phone numbers, UPI IDs, or account numbers.
- **No Financial Secrets**: No card details, CVV, OTP, or UPI PINs.
- **Sanitized Purchase Tokens**: Raw tokens are strictly masked:
  - Tokens longer than 8 characters display only prefix and suffix (e.g. `GPA.3341...6789`).
  - Full raw purchase tokens are never logged or stored.
- **Status Monitored**:
  - Billing Client Status (`CONNECTED` / `UNAVAILABLE`)
  - Target Product ID (`myupi_soundbox_pro`)
  - Product Found Status (`FOUND` / `NOT FOUND`)
  - Live Introductory & Recurring Prices
  - Purchase Acknowledged Status (`YES (Within 3 Days)`)
  - Last Billing Refresh Timestamp

---

## 7. Exact Manual Steps Required in Google Play Console

To enable real subscription purchases on Google Play, perform the following steps in your Google Play Console:

### Step 1: Create the Subscription Product
1. Log in to [Google Play Console](https://play.google.com/console).
2. Select your app (*MyUPI*).
3. In the left navigation, navigate to **Monetize > Products > Subscriptions**.
4. Click **Create subscription**.
5. Fill in the fields:
   - **Product ID**: `myupi_soundbox_pro`
   - **Name**: `MyUPI Soundbox Pro`
   - **Description**: `Smart audio soundbox announcements for UPI payments without monthly machine rent.`
6. Click **Save**.

### Step 2: Configure the Base Plan
1. Inside `myupi_soundbox_pro`, under **Base plans**, click **Add base plan**.
2. **Base plan ID**: `monthly-recurring`
3. **Type**: `Auto-renewing`
4. **Billing period**: `1 month`
5. **Grace period**: `7 days` (recommended)
6. **Customer changes**: `Charge immediately`
7. Under **Prices and availability**:
   - Click **Set prices**.
   - Select **India (INR)**: enter `₹49.00`.
   - Update other regions if applicable.
8. Click **Save** and then click **Activate base plan**.

### Step 3: Configure the Introductory Offer
1. Inside `monthly-recurring`, under **Offers**, click **Add offer**.
2. **Offer ID**: `intro-offer-1inr`
3. **Eligibility criteria**: Select **New customer acquisition** (users who have never had a subscription for this app).
4. Under **Phases**:
   - Click **Add phase**.
   - **Type**: `Discounted fixed price` (or `Single payment`).
   - **Duration**: `1 billing period` (1 month).
   - **Price**: Enter `₹1.00`. *(Note: If Play Console enforces an INR minimum floor of ₹10 for your developer account, enter ₹10.00. The app dynamically detects and displays the configured price).*
5. Click **Save** and then click **Activate offer**.

### Step 4: Configure License Testers
1. In the Play Console left menu, navigate to **Setup > License testing**.
2. Under **License testers**, add the Gmail addresses of your test accounts.
3. Under **License test response**, select `RESPOND_NORMALLY`.
4. Click **Save changes**.

### Step 5: Upload Build to Internal Testing Track
1. Build the production App Bundle:
   ```bash
   flutter build appbundle --release
   ```
2. Navigate to **Testing > Internal testing**.
3. Create a new release and upload the `.aab` file.
4. Add your license tester email to the internal tester list and accept the invitation on the test device.
5. On the test device, open the Play Store link to install the internal testing build.
6. Open MyUPI > Go to Settings > Tap "Upgrade to Premium" > Test with Google Play's test instrument ("Test card, always approves").

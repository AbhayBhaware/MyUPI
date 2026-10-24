# MyUPI Soundbox — Database, Security & Settings Deep Audit

**Date:** 2026-10-13  
**Target Project:** MyUPI Soundbox (`com.myupi.soundbox`)  
**Scope:** Firebase Database, Security Rules, Authentication, State Synchronization, Settings Screen Integrity  

---

## 1. Executive Summary & Core Diagnosis

A comprehensive deep audit of the MyUPI codebase revealed multiple structural glitches connecting the **Database**, **Security Layer**, **Native Kotlin Storage**, and the **Settings Screen**. 

The primary symptom reported—the Settings screen displaying stale, mismatched, or blank data—is coupled with a **"Split-Brain" Architecture** where merchant settings and database states are fragmented across three separate storage layers:

```
[Firebase Realtime Database REST API]
         ▲
         │ (Incomplete 1-Way Calls)
         ▼
[Flutter In-Memory Profile Cache]
         ▲
         │ (Incomplete 1-Way Calls)
         ▼
[Android Native SharedPreferencesManager]
         │
         ▼ (Reads for Background Voice)
[Kotlin PaymentNotificationListener & TTS]
```

### Key Glitches Identified:
1. **Critical PII Data Exposure Risk:** `findDuplicateAccount()` requests `GET /users.json`, querying the complete database of every merchant registered in the app.
2. **Broken Two-Way Sync in Settings:** Editing the Shop Name in Settings only updates Android SharedPreferences, leaving Firebase RTDB untouched. Conversely, editing the UPI ID updates Firebase RTDB but neglects native Android storage.
3. **Engine Mismatch:** The core data access service is titled `FirestoreService`, yet it executes HTTP REST requests against Firebase Realtime Database (`https://myupi1-default-rtdb.firebaseio.com`) without the resilience or offline caching of an official SDK.
4. **Token Expiration Lockouts:** HTTP REST calls rely on manual token refreshes (`?auth=$token`); an expired token or network timeout during background lifecycle transitions triggers HTTP 401/403, cascading into "Database Permission Denied" errors.

---

## 2. Deep Security Audit & Vulnerabilities

### 2.1 Critical Vulnerability: Bulk Merchant PII Exposure in `findDuplicateAccount`
- **Location:** `lib/services/firestore_service.dart:151-205`
- **Vulnerability Code:**
  ```dart
  final url = '$rtdbUrl/$kCollectionUsers.json$authParam';
  final res = await _client.get(uri, headers: headers);
  final allUsers = jsonDecode(res.body);
  ```
- **The Risk:**
  - This endpoint fetches the **entire** `/users` root tree.
  - If Firebase Realtime Database rules allow authenticated users to read `/users`, **any logged-in merchant can dump the complete database**: personal phone numbers, shop names, owner names, UPI VPAs, and emails of all other merchants.
  - If rules properly restrict reads to `auth.uid === $uid`, this call returns HTTP 401/403, rendering duplicate detection useless.
- **Remediation:** Remove the insecure `/users.json` bulk dump. Merchant uniqueness should be handled by Firebase Auth (phone and email are already intrinsically unique per Firebase Auth user account).

---

### 2.2 Token Expiry & Authentication Flow Risks
- **Location:** `lib/services/firestore_service.dart:56-105`
- **Mechanism:** Direct REST calls with `?auth=$token` and `Authorization: Bearer $token`.
- **The Risk:**
  - Firebase ID tokens expire strictly after 1 hour (3600 seconds).
  - While `getIdToken(true)` is called in `getUserProfile` and `saveUserProfile`, network latency or failure during token refresh causes HTTP 401 Unauthorized.
  - When HTTP 401 occurs, `AuthGate` interprets it as a fatal error and locks the user out with an error screen, even if the user is genuinely logged into Firebase Auth.
- **Remediation:** 
  1. Wrap all database operations with automatic token refresh retries.
  2. Implement an offline-first fallback: If Firebase is temporarily unreachable, fall back to the locally cached profile so the merchant is never locked out of their Soundbox.

---

### 2.3 Absence of Version-Controlled Database Security Rules
- **Status:** There is currently no `database.rules.json` file committed to the repository.
- **The Risk:** The database risks either being completely open (`".read": true, ".write": true`) or overly restrictive, causing unpredictable 401 errors.
- **Hardened Rules Specification:**
  ```json
  {
    "rules": {
      "users": {
        "$uid": {
          ".read": "auth != null && auth.uid === $uid",
          ".write": "auth != null && auth.uid === $uid",
          ".validate": "newData.hasChildren(['shopName', 'setupComplete'])",
          "shopName": { ".validate": "newData.isString() && newData.val().length > 0 && newData.val().length <= 60" },
          "upiId": { ".validate": "newData.isString()" },
          "setupComplete": { ".validate": "newData.isBoolean()" },
          "phone": { ".validate": "newData.isString()" },
          "email": { ".validate": "newData.isString()" }
        }
      }
    }
  }
  ```

---

## 3. Database & Settings Glitches

### 3.1 Split-Brain Storage Between Kotlin & Firebase RTDB

| Feature | Where it is saved when modified in Settings | Where it is saved when modified in Setup Wizard | Where Native Voice Engine reads it |
| :--- | :--- | :--- | :--- |
| **Shop Name** | Android `SharedPreferences` only ❌ | Both Android & Firebase ✅ | Android `SharedPreferences` |
| **UPI ID** | Firebase RTDB only ❌ | Both Android & Firebase ✅ | Reads from Firebase profile |
| **Language** | Android `SharedPreferences` only ❌ | Android `SharedPreferences` only | Android `SharedPreferences` |
| **Include Shop Name**| Android `SharedPreferences` only ❌ | Android `SharedPreferences` only | Android `SharedPreferences` |

#### The Glitch in Action:
1. When a merchant changes their shop name in Settings via `_showEditMerchantNameDialog()`:
   ```dart
   _setMerchantName(text); // Calls kMethodChannel.invokeMethod('setMerchantName')
   ```
   **It never calls `FirestoreService.instance.saveUserProfile()`!**
2. Consequently, Firebase RTDB still holds the old name (`"Aatta Chakki"`).
3. If the merchant opens the app on a fresh device, or re-installs, `AuthGate` loads `"Aatta Chakki"` from Firebase, completely overwriting whatever the merchant entered!
4. The exact inverse glitch happens with **UPI ID**: Updating UPI ID updates Firebase RTDB, but never informs Android SharedPreferences.

---

### 3.2 Lack of Initial Sync on App Launch
When the app launches:
- `AuthGate` loads `UserProfile` from Firebase RTDB (`shopName: "Aatta Chakki"`).
- But `SharedPreferencesManager` in Android may have defaulted to `"MyUPI"`.
- Because the app never pushed the loaded Firebase profile into Android SharedPreferences upon successful login, the background Soundbox announces payments as `"MyUPI"` instead of the merchant's real shop name!

---

## 4. Remediation Action Plan

### Phase 1: Security & Database Hardening
1. **Create `database.rules.json`:** Add strict per-UID read/write rules to the repository.
2. **Sanitize `findDuplicateAccount`:** Remove bulk `GET /users.json` calls to prevent mass PII data exfiltration.
3. **Resilient Token & Offline Handling:** Implement local SharedPreferences caching for the full `UserProfile`. If Firebase is unreachable or network drops, load from local cache so merchants are never blocked.

### Phase 2: Full Two-Way Synchronization
1. **Settings Screen Synchronization:**
   - Updating Shop Name must update **both** native Kotlin SharedPreferences AND Firebase RTDB.
   - Updating UPI ID must update **both** native Kotlin SharedPreferences AND Firebase RTDB.
   - Updating Language or Soundbox preferences must be synchronized across both layers.
2. **App Startup Reconciliation:**
   - In `AuthGate` (or `ShellPage`), once the profile is retrieved from Firebase, immediately invoke `kMethodChannel.invokeMethod('setMerchantName', ...)` to guarantee native Android background TTS is in 100% parity with cloud storage.

### Phase 3: Validation & Testing
1. Verify with unit & integration tests that profile modifications persist to both layers.
2. Verify offline behavior: simulate disconnected network and confirm Settings still loads merchant profile from local storage without blanking out.

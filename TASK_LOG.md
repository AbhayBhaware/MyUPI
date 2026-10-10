# MyUPI Task Log & Execution Record

## AGENT TASK v4 — UI/UX Audit & Enhancement Execution

### Packages Added (Flutter-side only)
- `wakelock_plus: ^1.8.1`: Keeps screen awake on checkout counter and during full-screen QR mode. Safely releases on app pause, backgrounding, and dialog dismiss.
- `volume_controller: ^3.7.1`: Media stream volume listener and quick volume sheet controller for merchant soundbox readiness.
- `screen_brightness: ^2.1.11`: Safely boosts display brightness during full-screen QR display and restores previous brightness on close, pause, or error.
- `share_plus: ^13.3.1`: Daily reconciliation report sharing to WhatsApp/messaging (totals only, zero customer PII).
- `shared_preferences: ^2.5.6`: Local UI preference storage for Counter Kiosk Mode toggle.

---

### Phase 1 — Countertop Quick Wins
- [x] **Keep Screen Awake (`wakelock_plus`)**: Created `CounterKioskService` with lifecycle observer. Added opt-in switch in Settings with clear battery drain notice.
- [x] **Volume Pill + Quick Slider**: Created `VolumeIndicatorPill` widget displaying live media volume percentage and muted indicator, tapping into a quick volume slider sheet with test audio.
- [x] **Repeat Announcement Button**: Added to `PaymentCard` and Most Recent Payment on `HomeScreen`. Calls `TtsService.instance.speakPayment(...)` with zero ledger mutation.
- [x] **Specific-Amount QR Mode**: Added amount modal in `QrCodeCard` with validation (plain decimal, max 2 decimals, cap ₹1,00,000), fixed amount banner with 1-tap clear, and full-screen QR dialog with safe `ScreenBrightness` + `WakelockPlus` lifecycle restoration.
- [x] **Affordances**: Enhanced `StatCard` with ripple and chevron affordances; verified live arrival glow.

---

### Phase 2 — History & Reconciliation
- [x] **Sticky In-Memory Search & Filters**: Added amount/app search bar and source filter chips (`All`, `Google Pay`, `PhonePe`, `Paytm`, `SMS`) to `HistoryScreen`.
- [x] **WhatsApp Daily Summary Share (`share_plus`)**: Added 1-tap summary generation in `HistoryScreen` containing date, total collection (Indian digit grouping), transaction count, and per-app subtotals. **Zero PII — totals and counts only.**
- [x] **Transaction Detail Sheet**: Created `TransactionDetailBottomSheet`. **Zero-PII**: shows amount, app name, exact timestamp with seconds, source channel, trust level, calm bank verification footnote, and re-speak button. Never displays raw notification/SMS text.
- [x] **Test Announcement Empty State**: Added "Play Test Announcement" button in `HistoryScreen` empty state. Pure audio test; never writes to the ledger.

---

### Phase 3 — Conversion & Polish
- [x] **Paywall Comparison Table**: Added side-by-side comparison between Hardware Soundbox (up to ₹1,500–₹1,800/yr) and MyUPI (₹540 in year 1: ₹1 first month + ₹49 × 11; ₹588/yr thereafter).
- [x] **Trust Badges**: Added 3 truthful claims on paywall (Works Offline, Zero Bank Account Linking, Cancel Anytime via Google Play).
- [x] **FAQ Accordions**: Added 4 expandable FAQ questions on paywall addressing savings, security, cancellation, and offline capability.
- [x] **Early Onboarding Voice Demo**: Added "Hear Sample Announcement" preview buttons in `StepSoundScreen` and `StepShopProfileScreen` using existing `TtsService` soundbox path.
- [x] **Indian Font Fallbacks**: Added Noto font fallbacks (`Noto Sans Devanagari`, `Noto Sans Tamil`, `Noto Sans Telugu`, etc.) to `AppTypography`.
- [x] **Outdoor High-Contrast Palette**: Added `OutdoorColors` token set in `AppColors` for street stall direct sunlight readability.
- [x] **Unified Currency Formatter**: Created `CurrencyFormatter` with `en_IN` Lakhs/Crores grouping.

---

### Guardrail Verification & Prohibited Checks
- [x] No string anywhere says "verified" or "checked" for detected payments.
- [x] Zero raw notification/SMS text displayed or logged.
- [x] Neither re-speak nor test announcements write to the ledger.
- [x] Native guardrailed files (`PaymentNotificationListener.kt`, `SmsReceiver.kt`, `KotlinUpiDetector.kt`, `NativeTtsHelper.kt`, `SharedPreferencesManager.kt`) remained completely untouched.

---

### Deferred Items (Requires Separate Architecture Approval)
1. **Audio Route Badge (Loudspeaker vs Bluetooth)**:
   - *Reason*: Determining whether the active audio output stream is currently routed to the internal speaker, a Bluetooth soundbox, or a wired jack requires querying Android's native `AudioManager` (`getDevices` / `isBluetoothA2dpOn`). This requires modifications to `MainActivity.kt` and adding native method channels, which is barred under the task's native code guardrail.
2. **TTS Per-Language Engine Download Status ("Downloaded / Needs Download")**:
   - *Reason*: Querying whether specific regional voice data files (e.g. Hindi, Tamil, Telugu) are installed on the device's Google Speech Services engine requires native Android `TextToSpeech.Engine.ACTION_CHECK_TTS_DATA` intent queries, not supported via Flutter's standard `flutter_tts` package. Deferred to prevent touching---

## AGENT TASK — Professional Announcement Wording

### 1. Key Architectural & Wording Changes
- **Amount-First Wording**: Amount spoken in first ~1.5s to ensure instant clarity in noisy merchant retail environments.
- **Say "rupees", never "Rs." or "₹"**: Explicit word `"rupees"` used everywhere; paise omitted when zero; plain decimal formatting.
- **Phonetic Brand Spelling**: Brand name "MyUPI" spelled phonetically per language so TTS engines read letter-by-letter rather than "my-u-pee":
  - `en-IN`: `My U P I`
  - `hi`: `माय यू पी आई`
  - `mr`: `माय यू पी आय`
  - `gu`: `માય યુ પી આઈ`
  - `ta`: `மை யூ பி ஐ`
  - `te`: `మై యు పి ஐ`
  - `bn`: `মাই ইউ পি আই`
  - `kn`: `ಮೈ ಯು ಪಿ ಐ`
- **Shop Name Handling**:
  - Strips emojis and punctuation (`*#_|~`), replaces `&` with `and`, collapses whitespace.
  - Capped at ~30 characters / 5 words cut cleanly at word boundaries.
  - Positioned strictly at the end of the announcement.
  - Settings screen displays hint: `"Long names are shortened when spoken."`
- **Formats**:
  - **A (Standard, default)**: `{amount} rupees received on My U P I` (appends shop name if "Include Shop Name" is enabled).
  - **B (Short)**: `{amount} rupees received` (never includes shop name).
  - **C (With shop name)**: `{amount} rupees received on My U P I for {shop}` (falls back cleanly to format A if shop name is empty).
- **Parity Across Dart & Kotlin**:
  - Pure builder `SpeechTemplateBuilder` implemented in Dart (`lib/utils/speech_template_builder.dart`).
  - Mirror pure builder `SpeechTemplateBuilder` implemented in Kotlin (`android/app/src/main/kotlin/com/example/myupi/SpeechTemplateBuilder.kt`).
  - Identical test table of inputs → expected strings tested in both Dart and Kotlin test suites.
  - UI Settings preview, Test announcement, Onboarding voice preview, Repeat announcement, and native background announcement all share the pure builders.

### 2. Guardrail Compliance
- Native edits restricted strictly to `NativeTtsHelper.kt` (delegation to `SpeechTemplateBuilder.kt`).
- Zero modifications made to audio playback, queueing, TTS engine selection, detection, dedup, ledger, SMS receiver, channels, billing, or auth.

### 3. Test Updates (`test/upi_detector_test.dart`)
- Updated M17 TTS Speech text generation tests to reflect the new soundbox standards:
  - English: `"500 rupees received on My U P I"`
  - Hindi: `"माय यू पी आई पर 500 रुपये प्राप्त हुए"`
  - Marathi: `"माय यू पी आय वर 500 रुपये मिळाले"`
  - English with shop name: `"500 rupees received on My U P I for Ramesh Kirana"`
  - Hindi with shop name: `"माय यू पी आई पर 500 रुपये प्राप्त हुए, Ramesh Kirana के लिए"`
  - Short format: `"500 rupees received"`
  - New test suites added: `test/speech_template_builder_test.dart` (Dart) and `android/app/src/test/kotlin/com/example/myupi/SpeechTemplateBuilderTest.kt` (Kotlin).

---

## AGENT TASK — Pro Redesign, Splash & Overflow-Proof System

### 1. Phase Execution Record
- **Phase A (Overflow System & Matrix Tests)**:
  - Created shared widgets `SwitchRow`, `NavRow`, `StackedField` in `lib/widgets/settings_rows.dart` with bounded `Expanded` text columns and min 48×48 dp touch targets.
  - Replaced inline fixed-width dropdowns with modal bottom-sheet pickers (`showSelectionBottomSheet` in `lib/widgets/selection_bottom_sheet.dart`) per Android Settings guidelines.
  - Compacted `QrCodeCard`: removed fake verified tick, sized QR to 170 dp, UPI ID wrapped with `Flexible` + `FittedBox(fit: BoxFit.scaleDown)`, single centered `"Scan with any UPI app"` banner.
  - Implemented `test/overflow_matrix_test.dart`: 84 automated tests across widths 320/360/411 dp × text scales 1.0/1.3/1.6/2.0 across `HomeScreen`, `QrCodeCard`, `SettingsScreen`, `HistoryScreen`, `PaywallScreen`, `WelcomeScreen`, `StepShopProfileScreen`. **All 84 tests pass with zero layout exceptions.**
- **Phase B (Professional Splash Experience)**:
  - Configured Android 12+ `flutter_native_splash` with `#F8FAFE` (dark `#0F172A`), centered vector logo mark within safe circular mask, and 800×320 wordmark branding.
  - Added `FlutterNativeSplash.preserve` with a hard timeout of 2 seconds in `main.dart`.
  - Replaced `_AuthLoadingSplash` (white boxed sticker with spinner) with `_HomeSkeletonPlaceholder` (grey placeholder blocks in Home layout) in `AuthGate`, holding native splash during auth/pref resolution and fading directly to interactive Home.
- **Phase C (Home Screen Rebuild)**:
  - Rebuilt `HomeScreen` strictly to Section 4.1 wireframe:
    - Header: App logo, 1-line shop name with ellipsis, `VolumeIndicatorPill`. Removed header gear and duplicate status pill.
    - Soundbox Status Card: ONE full-width card (min 56 dp). Calm green/blue when ON; loud amber warning card with `[Turn on]` button when OFF.
    - Hero Card: Big amount, source, time, `[Repeat]` announcement button, and combined stats row (`Today ₹... · ... payments →`).
    - Alert strip for notification/battery warnings, offer banner, and anti-fraud footer.
- **Phase D (Settings IA & Setup Health Card)**:
  - Reorganized `SettingsScreen` into 7 clear sections:
    1. *Setup Health Card (top)*: 4-step checklist (Notification access, Battery optimization, UPI ID, Sound preview) showing progress and "All Set • Soundbox Ready" when complete.
    2. *Voice*: Language (shows native script name), Voice type (with HUMAN badge), Announcement style, Attention Chime toggle, integrated Sample Announcement preview box with Play Sample button, Speech Speed picker.
    3. *Shop*: Shop name (NavRow), Include shop name (SwitchRow), UPI ID (confirm-protected edit).
    4. *Counter Mode*: Keep screen awake (SwitchRow), Media Volume (NavRow opening volume sheet).
    5. *Plan*: Compact Premium card with "Restore purchases" as a NavRow inside the card.
    6. *Help & Reliability*: Reliability checklist, Notification access, Help & support, WhatsApp chat button, About MyUPI.
    7. *Account*: Profile info, Sign out confirmation, Delete account confirmation.
- **Phase E (History Polish & 2-Step Onboarding)**:
  - `TransactionDetailBottomSheet`: Neutral `Icons.payments_outlined` badge with `"Payment detected"` (removed green tick); confidence levels formatted as High / Medium / Low; amber `"Verify in bank • SMS-only detection without push notification"` footnote for SMS alerts.
  - History day header totals formatted with `CurrencyFormatter`.
  - Polished `SetupWizardScreen`: 2-step setup where Shop Name is the single required field, handle suggestions for UPI ID (`@okhdfcbank`, `@okaxis`, `@oksbi`, `@okicici`, `@ybl`, `@paytm`), and "Hear Your Soundbox" preview box.

### 2. Changed Test Assertions (`test/milestone21_merchant_experience_test.dart`)
- Updated Settings category assertions to match Section 4.2 Pro Redesign IA:
  - Checked for SectionHeaders `VOICE`, `SHOP`, `PLAN`, `HELP & RELIABILITY`.
  - Checked for items `Soundbox`, `Announcement Language`, `Shop / Business Name`, `Include Shop Name`.
  - Changed `expect(find.text('Notification Access'), findsOneWidget)` to `findsWidgets` (present in Setup Health Card and Help & Reliability).
- Updated HomeScreen assertions to match Section 4.1 wireframe:
  - Changed `expect(find.text('ACTIVE'), findsOneWidget)` to `expect(find.text('Soundbox is ON'), findsOneWidget)`.
  - Changed `expect(find.text('Most Recent Payment'), findsOneWidget)` to `expect(find.text('Last payment'), findsOneWidget)`.
  - Changed `expect(find.text('PhonePe'), findsWidgets)` to `expect(find.textContaining('PhonePe'), findsWidgets)` (matches `'PhonePe · 4:18 PM'` combined subtitle).

### 3. Guardrail Verification
- Zero edits to `PaymentNotificationListener.kt`, `SmsReceiver.kt`, `KotlinUpiDetector.kt`.
- Zero edits to ledger/dedup/trust logic, billing/subscription/entitlement, `AuthGate` routing conditions, Firestore rules, channel contracts.
- Static analysis: `flutter analyze` completed with 0 errors and 0 warnings.
- Test suite: `flutter test` completed with **315 passing tests and 0 failures**.



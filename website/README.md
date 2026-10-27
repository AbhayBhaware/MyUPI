# MyUPI Website & Privacy Policy for Google Play Store

This folder contains the official, Google Play-compliant **Privacy Policy** and **Terms of Service** web pages for **MyUPI: Smart UPI Soundbox**, pre-configured for instant hosting on **GitHub Pages**.

---

## 📁 Included Files

- [`index.html`](index.html): The primary Privacy Policy page (loads automatically on the root URL).
- [`privacy-policy.html`](privacy-policy.html): Direct URL endpoint mirror for Google Play Console submission.
- [`terms.html`](terms.html): Complementary Terms of Service page required for merchant and subscription apps.
- [`styles.css`](styles.css): Modern, responsive, clean styling with print-friendly CSS.
- [`.nojekyll`](.nojekyll): Bypasses Jekyll processing on GitHub Pages to ensure fast, direct static asset delivery.
- `assets/logo.png`: High-resolution application icon.

---

## 🚀 How to Enable GitHub Pages (Choose Method 1 or 2)

Your GitHub repository is:  
**`https://github.com/AbhayBhaware/MyUPI`**

### Method 1: Using GitHub Actions (Recommended & Already Configured)
We have added an automated workflow file at [`.github/workflows/deploy-pages.yml`](../.github/workflows/deploy-pages.yml).

1. Commit and push the `website/` and `.github/` folders to your GitHub repository:
   ```bash
   git add website .github
   git commit -m "Add Play Store privacy policy website and GitHub Pages deploy action"
   git push origin main
   ```
2. On GitHub, navigate to **Settings** > **Pages** (under the "Code and automation" section).
3. Under **Build and deployment** > **Source**, choose **GitHub Actions**.
4. That's it! GitHub will automatically run the deployment workflow.
5. Your Privacy Policy will be live at:
   - **`https://abhaybhaware.github.io/MyUPI/`**
   - **`https://abhaybhaware.github.io/MyUPI/privacy-policy.html`**

---

### Method 2: Deploying to a dedicated `gh-pages` branch
If you prefer traditional branch deployment:
```bash
# Push the website folder directly to a gh-pages branch
git subtree push --prefix website origin gh-pages
```
Then go to **Settings** > **Pages** > **Source** > **Deploy from a branch** > select `gh-pages` / `/ (root)`.

---

## 📋 URLs to Submit in Google Play Console

Once published, enter either of these URLs in your Google Play Console under **Policy and programs** > **App content** > **Privacy Policy**:

- Primary URL: `https://abhaybhaware.github.io/MyUPI/privacy-policy.html`
- Or: `https://abhaybhaware.github.io/MyUPI/`

---

## ✅ Google Play Compliance Highlights Included in this Policy

1. **Prominent Disclosures:**
   - `BIND_NOTIFICATION_LISTENER_SERVICE`: Explicitly documents that notification access is used solely on-device to announce payment amounts from approved UPI applications.
   - `RECEIVE_SMS` / `READ_SMS`: Strictly scoped to banking credit confirmations as a backup alert mechanism. Personal messages and OTPs are explicitly declared as untouched and never stored off-device.
   - `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`: Clear justification for continuous soundbox background operation.
2. **Account & Data Deletion:**
   - Provides clear in-app instructions and a dedicated support email (`abhaybhaware2001@gmail.com`) for handling user data and account deletion requests within 7 business days, satisfying Google Play's 2024+ user data deletion policy.
3. **Zero-PII Local Storage:**
   - Explains that transaction ledgers are stored strictly in local Android storage on the merchant's device and are never sent to external servers or sold to data brokers.

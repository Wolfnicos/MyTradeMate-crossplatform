# Privacy Policy for MyTradeMate

**Last Updated:** October 23, 2025  
**Effective Date:** October 23, 2025

---

## Introduction

MyTradeMate ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we handle information when you use our mobile application (the "App").

**TL;DR:** We don't collect, store, or transmit any of your personal data. Everything stays on your device.

---

## Information We DO NOT Collect

We want to be crystal clear: **MyTradeMate does not collect, store, or transmit any personal information.**

Specifically, we DO NOT collect:
- ❌ Your name, email, or contact information
- ❌ Your Binance API keys or credentials
- ❌ Your trading history or portfolio data
- ❌ Your device information or identifiers
- ❌ Your location data
- ❌ Your usage analytics or behavior
- ❌ Any cookies or tracking data
- ❌ Any personally identifiable information (PII)

---

## How Your Data is Stored

### Local Storage Only

All data in MyTradeMate is stored **locally on your device** using:

1. **FlutterSecureStorage** (for API keys)
   - Your Binance API keys are encrypted and stored in your device's secure keychain
   - iOS: Stored in iOS Keychain
   - Android: Stored in Android Keystore
   - Never transmitted to our servers (we don't have servers!)

2. **SharedPreferences** (for app settings)
   - Theme preference (light/dark mode)
   - Quote currency preference (USDT/EUR/USDC)
   - Paper trading mode toggle
   - Risk disclaimer acceptance flag
   - No personal information stored

### What This Means:
- ✅ Your data never leaves your device
- ✅ We cannot access your API keys
- ✅ We cannot see your portfolio
- ✅ We cannot track your trades
- ✅ If you uninstall the app, all data is deleted

---

## Third-Party Services

MyTradeMate connects to external services to provide functionality:

### 1. Binance API
- **Purpose:** Fetch market data, portfolio balances, and execute trades
- **Data Sent:** Your API keys (encrypted in transit via HTTPS)
- **Data Received:** Market prices, your portfolio balances, order status
- **Privacy Policy:** https://www.binance.com/en/privacy
- **Note:** We do not control Binance's data practices. Please review their privacy policy.

### 2. Coinpaprika API
- **Purpose:** Fetch cryptocurrency logos
- **Data Sent:** Cryptocurrency symbol (e.g., "BTC")
- **Data Received:** Logo image URL
- **Privacy Policy:** https://coinpaprika.com/privacy-policy
- **Note:** No personal information is sent to Coinpaprika

### Important:
- All API calls are made **directly from your device** to these services
- We do not act as a middleman or proxy
- We do not log or store any API requests or responses

---

## Permissions Used

MyTradeMate requests the following permissions:

### iOS Permissions:

**1. Internet Access**
- **Why:** Required to connect to Binance API and fetch market data
- **What we access:** Only Binance API endpoints and Coinpaprika API
- **What we don't access:** Your browsing history, other apps, personal files

**2. Face ID / Touch ID (Optional)**
- **Why:** Secure authentication when opening the app
- **What we access:** Only the authentication result (success/failure)
- **What we don't access:** Your biometric data (handled by iOS)
- **Note:** You can skip biometric authentication in settings

### Android Permissions:

**1. Internet Access**
- Same as iOS (see above)

**2. Network State**
- **Why:** Check if you have internet connection before making API calls
- **What we access:** Connection status (connected/disconnected)
- **What we don't access:** Your network traffic, browsing history

**3. Biometric Authentication (Optional)**
- Same as iOS (see above)

---

## Data Security

Even though we don't collect data, we take security seriously:

### Encryption:
- ✅ API keys encrypted using FlutterSecureStorage
- ✅ All API calls use HTTPS (TLS 1.2+)
- ✅ No plaintext storage of sensitive data

### Authentication:
- ✅ Optional biometric authentication (Face ID / Fingerprint)
- ✅ Password hashing using SHA-256
- ✅ No passwords stored on device (only hashes)

### Best Practices:
- ✅ Order confirmation dialogs prevent accidental trades
- ✅ Risk disclaimer on first launch
- ✅ Paper trading mode for safe testing
- ✅ No automatic trade execution (user must confirm)

---

## Your Rights

Since we don't collect any data, there's nothing for us to:
- Delete (it's already on your device only)
- Export (you control your device)
- Correct (you can edit settings in the app)
- Access (we can't access it anyway)

### To Delete Your Data:
Simply uninstall the app. All data will be permanently deleted from your device.

### To Export Your Data:
Your data is stored locally. You can:
- Take screenshots of your portfolio
- Export trade history from Binance directly
- Back up your device (includes app data)

---

## Children's Privacy

MyTradeMate is **NOT intended for users under 18 years of age.**

Cryptocurrency trading involves financial risk and is only suitable for adults. We do not knowingly collect information from anyone under 18.

If you are under 18, please do not use this app.

---

## Changes to This Privacy Policy

We may update this Privacy Policy from time to time. Changes will be posted:
- In the app (Settings → Privacy Policy)
- On our website: https://mytrademate.com/privacy
- With an updated "Last Updated" date at the top

**Material changes** will be notified via:
- In-app notification
- Email (if we add email collection in the future)

---

## International Users

MyTradeMate is available worldwide. Since we don't collect data, there are no data transfers or storage concerns.

However, please note:
- Binance availability varies by country
- Some countries restrict cryptocurrency trading
- You are responsible for complying with local laws

---

## GDPR Compliance (EU Users)

For users in the European Union:

**Data Controller:** You are the data controller of your own data (it's on your device).

**Legal Basis:** Not applicable (we don't process personal data).

**Your Rights:**
- Right to access: You have full access to your device
- Right to erasure: Uninstall the app
- Right to portability: Back up your device
- Right to object: Don't use the app

**Data Protection Officer:** Not required (we don't process data).

---

## CCPA Compliance (California Users)

For users in California:

**Personal Information Collected:** None

**Sale of Personal Information:** We do not sell personal information (we don't collect it).

**Your Rights:**
- Right to know: We don't collect data
- Right to delete: Uninstall the app
- Right to opt-out: Not applicable

---

## Contact Us

If you have questions about this Privacy Policy:

**Email:** privacy@mytrademate.com  
**Website:** https://mytrademate.com/contact  
**Response Time:** Within 48 hours

For technical support:
**Email:** support@mytrademate.com

---

## Disclaimer

MyTradeMate is a tool for managing cryptocurrency trading. We are not:
- A financial advisor
- A broker or exchange
- Responsible for your trading decisions
- Liable for financial losses

**Use at your own risk.** Cryptocurrency trading involves substantial risk of loss.

---

## Summary

**What we collect:** Nothing  
**What we store:** Nothing (except locally on your device)  
**What we share:** Nothing  
**What we sell:** Nothing  

**Your data = Your device = Your control**

---

**MyTradeMate Team**  
Building privacy-first crypto tools

*Last Updated: October 23, 2025*

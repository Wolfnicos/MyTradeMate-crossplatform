# MyTradeMate - AI-Powered Crypto Trading Assistant

<div align="center">

![MyTradeMate Logo](assets/logo.png)

**Trade Smarter with AI Intelligence**

[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-blue.svg)](https://github.com/yourusername/mytrademate)
[![Flutter](https://img.shields.io/badge/Flutter-3.9.2-02569B.svg?logo=flutter)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.0-orange.svg)](https://github.com/yourusername/mytrademate/releases)

[Download on App Store](#) | [Get it on Google Play](#) | [Documentation](docs/) | [Support](SUPPORT_FAQ.md)

</div>

---

## 🚀 Overview

MyTradeMate is a powerful mobile application that brings institutional-grade AI trading tools to your pocket. Get real-time BUY/SELL signals, track your portfolio, and execute trades with confidence.

### ✨ Key Features

- 🤖 **AI Neural Engine** - Multi-timeframe predictions powered by ensemble ML models
- 📊 **Professional Trading** - 4 order types (Market, Limit, Stop-Limit, Stop-Market)
- 💼 **Portfolio Tracking** - Real-time portfolio valuation and analytics
- 📈 **Advanced Charts** - Candlestick charts with multiple timeframes
- 🔒 **Bank-Level Security** - Encrypted API keys and biometric authentication
- 🎨 **Beautiful UI** - Modern glassmorphic design with dark mode
- 📱 **Cross-Platform** - Native iOS and Android apps

---

## 📸 Screenshots

<div align="center">

| Dashboard | AI Strategies | Trading |
|-----------|---------------|---------|
| ![Dashboard](screenshots/dashboard.png) | ![AI](screenshots/ai.png) | ![Trading](screenshots/trading.png) |

| Charts | Portfolio | Settings |
|--------|-----------|----------|
| ![Charts](screenshots/charts.png) | ![Portfolio](screenshots/portfolio.png) | ![Settings](screenshots/settings.png) |

</div>

---

## 🎯 Why MyTradeMate?

### For Traders
- ✅ AI-powered signals across 6 timeframes (5m, 15m, 1h, 4h, 1d, 7d)
- ✅ 76 technical indicators analyzed per prediction
- ✅ Confidence scoring for every signal
- ✅ Real-time market data from Binance
- ✅ Paper trading mode for risk-free practice

### For Developers
- ✅ Clean Flutter architecture with Provider pattern
- ✅ Modular codebase with clear separation of concerns
- ✅ TensorFlow Lite integration for on-device ML
- ✅ Secure credential storage with FlutterSecureStorage
- ✅ Comprehensive error handling and retry logic

### For Privacy-Conscious Users
- ✅ No data collection (everything stays on your device)
- ✅ No tracking or analytics
- ✅ Open source (coming soon)
- ✅ Your keys, your crypto

---

## 🏗️ Architecture

```
lib/
├── main.dart                 # App entry point
├── theme/                    # App theme and styling
│   └── app_theme.dart
├── screens/                  # UI screens
│   ├── dashboard_screen.dart
│   ├── market_screen.dart
│   ├── ai_strategies_screen.dart
│   ├── orders_screen.dart
│   ├── portfolio_screen.dart
│   └── settings_screen.dart
├── services/                 # Business logic
│   ├── binance_service.dart
│   ├── app_settings_service.dart
│   ├── auth_service.dart
│   └── crypto_icon_service.dart
├── ml/                       # Machine learning
│   ├── ensemble_predictor.dart
│   ├── unified_ml_service.dart
│   └── crypto_ml_service.dart
├── widgets/                  # Reusable components
│   ├── glass_card.dart
│   ├── crypto_avatar.dart
│   └── charts/
└── utils/                    # Utilities
    ├── error_handler.dart
    └── responsive.dart
```

---

## 🛠️ Tech Stack

### Frontend
- **Flutter 3.9.2** - Cross-platform UI framework
- **Dart 3.0** - Programming language
- **Provider** - State management
- **SharedPreferences** - Local storage
- **FlutterSecureStorage** - Encrypted credential storage

### Machine Learning
- **TensorFlow Lite** - On-device ML inference
- **Ensemble Models** - Multiple models voting for predictions
- **76 Features** - Technical indicators and candlestick patterns

### APIs & Services
- **Binance API** - Market data and trading
- **Coinpaprika API** - Cryptocurrency logos
- **HTTP** - REST API calls
- **WebSocket** - Real-time data (coming soon)

### Security
- **HMAC-SHA256** - API request signing
- **AES Encryption** - Credential storage
- **Biometric Auth** - Face ID / Touch ID / Fingerprint

---

## 📦 Installation

### Prerequisites
- Flutter SDK 3.9.2 or higher
- Dart SDK 3.0 or higher
- iOS 12.0+ / Android 6.0+
- Binance account with API keys

### Clone Repository
```bash
git clone https://github.com/yourusername/mytrademate.git
cd mytrademate
```

### Install Dependencies
```bash
flutter pub get
```

### Run on iOS
```bash
flutter run -d ios
```

### Run on Android
```bash
flutter run -d android
```

### Build Release
```bash
# iOS
flutter build ios --release

# Android
flutter build apk --release
flutter build appbundle --release
```

---

## 🔧 Configuration

### 1. Binance API Keys

Create API keys at https://www.binance.com/en/my/settings/api-management

**Permissions:**
- ✅ Enable Reading (required)
- ✅ Enable Spot & Margin Trading (for PREMIUM mode)
- ❌ Enable Withdrawals (NOT recommended)

### 2. App Configuration

Edit `lib/services/app_settings_service.dart`:

```dart
// Default quote currency
String _quoteCurrency = 'USDT'; // or 'EUR', 'USDC'

// Paper trading mode (safe for testing)
bool _paperTradingEnabled = true;

// Biometric authentication
bool _biometricEnabled = false;
```

### 3. AI Models

AI models are included in `assets/models/`:
- `btc_model.tflite` (27MB)
- `eth_model.tflite` (27MB)
- `bnb_model.tflite` (27MB)
- `sol_model.tflite` (27MB)
- `wlfi_model.tflite` (27MB)
- `trump_model.tflite` (27MB)

Models are loaded automatically on first launch.

---

## 🎓 Usage

### Getting Started

1. **Download App**
   - iOS: App Store
   - Android: Google Play

2. **Complete Onboarding**
   - Swipe through welcome screens
   - Accept risk disclaimer

3. **Connect API**
   - Go to Settings → API Configuration
   - Enter Binance API Key and Secret
   - Choose READ (free) or TRADING (premium)

4. **Start Trading!**
   - View portfolio on Dashboard
   - Check AI signals in AI Strategies
   - Place orders in Orders tab

### FREE vs PREMIUM

| Feature | FREE | PREMIUM |
|---------|------|---------|
| Portfolio Viewing | ✅ | ✅ |
| Real-time Prices | ✅ | ✅ |
| Charts (all timeframes) | ✅ | ✅ |
| AI Predictions (1D) | ✅ | ✅ |
| AI Predictions (5m-4h) | ❌ | ✅ |
| Trading Orders | ❌ | ✅ |
| Advanced Indicators | ❌ | ✅ |

**Upgrade:** Create Binance API key with TRADING permission

---

## 🤖 AI Predictions

### How It Works

1. **Data Collection**
   - Fetch historical price data from Binance
   - Calculate 76 technical indicators
   - Detect 25 candlestick patterns

2. **Model Inference**
   - Run 6 specialized TFLite models
   - Each model votes (BUY/SELL/HOLD)
   - Ensemble voting with confidence scoring

3. **Signal Generation**
   - Aggregate votes across models
   - Apply confidence thresholds
   - Return final prediction with confidence %

### Supported Timeframes
- **5m** - Scalping (seconds to minutes)
- **15m** - Day trading (minutes to hours)
- **1h** - Day trading (hours)
- **4h** - Swing trading (days)
- **1d** - Swing trading (weeks)
- **7d** - Position trading (months)

### Confidence Levels
- **80-100%** - High confidence (strong signal)
- **60-80%** - Medium confidence (moderate signal)
- **Below 60%** - Low confidence (weak signal)

---

## 📊 Trading

### Order Types

**1. Market Order**
- Executes immediately at current price
- Best for: Quick entries/exits
- Risk: Slippage on volatile markets

**2. Limit Order**
- Executes only at specified price (or better)
- Best for: Getting exact entry price
- Risk: May not fill if price doesn't reach limit

**3. Stop-Limit Order**
- Triggers limit order when price hits stop price
- Best for: Stop-loss or breakout entries
- Risk: May not fill in fast-moving markets

**4. Stop-Market Order**
- Triggers market order when price hits stop price
- Best for: Guaranteed stop-loss execution
- Risk: Slippage on execution

### Paper Trading

Practice trading with **$10,000 virtual funds**:
1. Go to Settings
2. Toggle "Paper Trading Mode" ON
3. Place orders like normal (no real money at risk)

Perfect for beginners and testing strategies!

---

## 🔒 Security

### Data Privacy
- ✅ No data collection
- ✅ Everything stored locally on your device
- ✅ No tracking or analytics
- ✅ No third-party data sharing

### API Security
- ✅ Keys encrypted with FlutterSecureStorage
- ✅ HTTPS for all API calls
- ✅ HMAC-SHA256 request signing
- ✅ No withdrawal permissions required

### Authentication
- ✅ Biometric authentication (Face ID / Touch ID / Fingerprint)
- ✅ Password hashing with SHA-256
- ✅ No passwords stored on device

### Best Practices
- ✅ Never enable withdrawal permissions on API
- ✅ Use strong passwords
- ✅ Enable biometric authentication
- ✅ Revoke API keys if compromised

---

## 🐛 Known Issues

### Current Limitations
- WebSocket not implemented (polling REST API instead)
- No push notifications for AI signals
- Limited to Binance exchange
- No multi-language support yet

### Planned Fixes
- [ ] WebSocket for real-time price updates
- [ ] Push notifications
- [ ] More exchanges (Coinbase, Kraken)
- [ ] Multi-language support
- [ ] Advanced charting tools

See [Issues](https://github.com/yourusername/mytrademate/issues) for full list.

---

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `flutter format` before committing
- Add tests for new features
- Update documentation

---

## 📝 Documentation

- [Privacy Policy](PRIVACY_POLICY.md)
- [Terms of Service](TERMS_OF_SERVICE.md)
- [Support & FAQ](SUPPORT_FAQ.md)
- [Technical Audit](TECHNICAL_AUDIT_2025.md)
- [Implementation Summary](IMPLEMENTATION_SUMMARY_OCT23.md)
- [App Store Assets](APP_STORE_ASSETS.md)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Binance** - For providing excellent API documentation
- **Coinpaprika** - For free cryptocurrency logos
- **Flutter Team** - For the amazing framework
- **TensorFlow** - For TFLite mobile ML
- **Community** - For feedback and feature requests

---

## 📞 Contact

- **Email:** support@mytrademate.com
- **Website:** https://mytrademate.com
- **Twitter:** [@MyTradeMate](https://twitter.com/mytrademate)
- **Discord:** [Join our community](https://discord.gg/mytrademate)

---

## ⚠️ Disclaimer

**IMPORTANT:** Cryptocurrency trading involves substantial risk of loss and is not suitable for every investor. This app provides tools and information but does NOT constitute financial, investment, or trading advice.

- Past performance does not guarantee future results
- AI predictions are not 100% accurate
- You may lose all invested capital
- Always do your own research
- Only invest what you can afford to lose

**MyTradeMate is a tool, not a financial advisor. Trade responsibly.**

---

## 🌟 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=yourusername/mytrademate&type=Date)](https://star-history.com/#yourusername/mytrademate&Date)

---

<div align="center">

**Made with ❤️ by the MyTradeMate Team**

[⬆ Back to Top](#mytrademate---ai-powered-crypto-trading-assistant)

</div>

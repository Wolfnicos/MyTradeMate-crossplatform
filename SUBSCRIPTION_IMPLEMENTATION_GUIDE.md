# 💎 MyTradeMate - Subscription Implementation Guide

## 📋 Pricing Model

### FREE (Read-Only)
- **Price:** $0 - Forever
- **Features:**
  - Portfolio viewing
  - Real-time prices
  - Charts (all timeframes)
  - AI predictions (1D only)
  - Read-only API mode

### PREMIUM
- **Monthly:** $9.99/month
- **Annual:** $79.99/year (save 33%)
- **Free Trial:** 7 days
- **Features:**
  - Everything in FREE
  - AI predictions (ALL timeframes: 5m-7d)
  - Trading capabilities
  - 4 order types (Market, Limit, Stop-Limit, Stop-Market)
  - Advanced indicators
  - Volatility & Liquidity analysis
  - Priority support

---

## 🛠️ Implementation Steps

### Phase 1: Setup (1-2 hours)

#### 1.1 Add Dependencies

**File:** `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Existing dependencies...
  
  # In-App Purchases
  in_app_purchase: ^3.1.13
  
  # OR use RevenueCat (recommended - easier)
  purchases_flutter: ^6.9.0
```

**Why RevenueCat?**
- ✅ Handles iOS + Android with same code
- ✅ Server-side receipt validation
- ✅ Analytics dashboard
- ✅ Webhook support
- ✅ Free up to $10k MRR

---

#### 1.2 Create RevenueCat Account

1. Go to https://www.revenuecat.com/
2. Sign up (free)
3. Create new project: "MyTradeMate"
4. Get API keys:
   - iOS: App Store Connect API key
   - Android: Google Play Service Account JSON

---

### Phase 2: Configure App Store & Google Play (2-3 hours)

#### 2.1 iOS - App Store Connect

1. **Create In-App Purchases:**
   - Go to App Store Connect
   - Select MyTradeMate app
   - Go to "Features" → "In-App Purchases"
   - Click "+" to create new subscription

2. **Monthly Subscription:**
   - Type: Auto-Renewable Subscription
   - Reference Name: `Premium Monthly`
   - Product ID: `mytrademate_premium_monthly`
   - Subscription Group: `Premium`
   - Price: $9.99/month
   - Free Trial: 7 days

3. **Annual Subscription:**
   - Type: Auto-Renewable Subscription
   - Reference Name: `Premium Annual`
   - Product ID: `mytrademate_premium_annual`
   - Subscription Group: `Premium`
   - Price: $79.99/year
   - Free Trial: 7 days

4. **Localization:**
   - Add English description
   - Add Romanian description (optional)

---

#### 2.2 Android - Google Play Console

1. **Create Subscriptions:**
   - Go to Google Play Console
   - Select MyTradeMate app
   - Go to "Monetize" → "Subscriptions"
   - Click "Create subscription"

2. **Monthly Subscription:**
   - Product ID: `mytrademate_premium_monthly`
   - Name: `Premium Monthly`
   - Price: $9.99/month
   - Free Trial: 7 days
   - Billing Period: 1 month

3. **Annual Subscription:**
   - Product ID: `mytrademate_premium_annual`
   - Name: `Premium Annual`
   - Price: $79.99/year
   - Free Trial: 7 days
   - Billing Period: 1 year

---

### Phase 3: Code Implementation (3-4 hours)

#### 3.1 Create Subscription Service

**File:** `lib/services/subscription_service.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // Subscription status
  bool _isPremium = false;
  bool _isLoading = false;
  String? _expirationDate;
  
  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;
  String? get expirationDate => _expirationDate;

  // Product IDs
  static const String monthlyProductId = 'mytrademate_premium_monthly';
  static const String annualProductId = 'mytrademate_premium_annual';

  /// Initialize RevenueCat
  Future<void> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Configure RevenueCat
      await Purchases.setLogLevel(LogLevel.debug);
      
      PurchasesConfiguration configuration;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        configuration = PurchasesConfiguration('appl_YOUR_IOS_API_KEY');
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        configuration = PurchasesConfiguration('goog_YOUR_ANDROID_API_KEY');
      } else {
        throw UnsupportedError('Platform not supported');
      }
      
      await Purchases.configure(configuration);
      
      // Check current subscription status
      await checkSubscriptionStatus();
      
      debugPrint('✅ RevenueCat initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize RevenueCat: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if user has active subscription
  Future<void> checkSubscriptionStatus() async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      
      // Check if user has active premium entitlement
      _isPremium = customerInfo.entitlements.all['premium']?.isActive ?? false;
      
      if (_isPremium) {
        final expirationDateMs = customerInfo.entitlements.all['premium']?.expirationDate;
        if (expirationDateMs != null) {
          _expirationDate = DateTime.parse(expirationDateMs).toString();
        }
      }
      
      debugPrint('✅ Subscription status: ${_isPremium ? "PREMIUM" : "FREE"}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to check subscription: $e');
      _isPremium = false;
      notifyListeners();
    }
  }

  /// Get available offerings
  Future<Offerings?> getOfferings() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      return offerings;
    } catch (e) {
      debugPrint('❌ Failed to get offerings: $e');
      return null;
    }
  }

  /// Purchase subscription
  Future<bool> purchaseSubscription(Package package) async {
    try {
      _isLoading = true;
      notifyListeners();

      CustomerInfo customerInfo = await Purchases.purchasePackage(package);
      
      // Check if purchase was successful
      _isPremium = customerInfo.entitlements.all['premium']?.isActive ?? false;
      
      if (_isPremium) {
        debugPrint('✅ Purchase successful! User is now PREMIUM');
        notifyListeners();
        return true;
      } else {
        debugPrint('⚠️ Purchase completed but premium not active');
        return false;
      }
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('ℹ️ User cancelled purchase');
      } else {
        debugPrint('❌ Purchase error: ${e.message}');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Restore purchases
  Future<bool> restorePurchases() async {
    try {
      _isLoading = true;
      notifyListeners();

      CustomerInfo customerInfo = await Purchases.restorePurchases();
      _isPremium = customerInfo.entitlements.all['premium']?.isActive ?? false;
      
      debugPrint('✅ Purchases restored. Premium: $_isPremium');
      notifyListeners();
      return _isPremium;
    } catch (e) {
      debugPrint('❌ Failed to restore purchases: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cancel subscription (redirect to store)
  Future<void> manageSubscription() async {
    try {
      await Purchases.showManagementURL();
    } catch (e) {
      debugPrint('❌ Failed to open management URL: $e');
    }
  }
}
```

---

#### 3.2 Create Paywall Screen

**File:** `lib/screens/paywall_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({Key? key}) : super(key: key);

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _subscriptionService = SubscriptionService();
  Offerings? _offerings;
  bool _isLoading = true;
  int _selectedIndex = 1; // Default to annual (better deal)

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() => _isLoading = true);
    final offerings = await _subscriptionService.getOfferings();
    setState(() {
      _offerings = offerings;
      _isLoading = false;
    });
  }

  Future<void> _purchasePackage(Package package) async {
    final success = await _subscriptionService.purchaseSubscription(package);
    if (success && mounted) {
      Navigator.pop(context, true); // Return true to indicate success
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_offerings == null || _offerings!.current == null) {
      return const Center(
        child: Text(
          'No subscriptions available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final packages = _offerings!.current!.availablePackages;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: Column(
        children: [
          // Header
          const Icon(Icons.auto_awesome, size: 80, color: Colors.white),
          const SizedBox(height: AppTheme.spacing16),
          const Text(
            'Unlock Premium',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          const Text(
            'Get AI-powered trading signals',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white70,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacing32),
          
          // Features
          _buildFeature('🤖', 'AI Predictions on ALL timeframes'),
          _buildFeature('📊', '4 Advanced order types'),
          _buildFeature('⚡', 'Real-time trading signals'),
          _buildFeature('📈', 'Volatility & Liquidity analysis'),
          _buildFeature('🎯', 'Priority support'),
          
          const SizedBox(height: AppTheme.spacing32),
          
          // Subscription options
          ...packages.asMap().entries.map((entry) {
            final index = entry.key;
            final package = entry.value;
            return _buildSubscriptionOption(
              package: package,
              isSelected: _selectedIndex == index,
              onTap: () => setState(() => _selectedIndex = index),
            );
          }).toList(),
          
          const SizedBox(height: AppTheme.spacing24),
          
          // Subscribe button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _subscriptionService.isLoading
                  ? null
                  : () => _purchasePackage(packages[_selectedIndex]),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
              ),
              child: _subscriptionService.isLoading
                  ? const CircularProgressIndicator()
                  : const Text(
                      'Start 7-Day Free Trial',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          // Restore purchases
          TextButton(
            onPressed: () async {
              final restored = await _subscriptionService.restorePurchases();
              if (restored && mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text(
              'Restore Purchases',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          
          const SizedBox(height: AppTheme.spacing8),
          
          // Terms
          const Text(
            'Cancel anytime. Auto-renews after trial.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white60,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionOption({
    required Package package,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isAnnual = package.identifier.contains('annual');
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? AppTheme.primary : Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.storeProduct.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.primary : Colors.white,
                    ),
                  ),
                  if (isAnnual)
                    Text(
                      'Save 33%',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? AppTheme.success : Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              package.storeProduct.priceString,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.primary : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

#### 3.3 Update App Settings Service

**File:** `lib/services/app_settings_service.dart`

Add subscription check:

```dart
import 'subscription_service.dart';

class AppSettingsService extends ChangeNotifier {
  // ... existing code ...
  
  final _subscriptionService = SubscriptionService();
  
  // Check if user has premium (subscription OR trading API)
  bool get isPremium {
    return _subscriptionService.isPremium || isTradingEnabled;
  }
  
  // Initialize
  Future<void> initialize() async {
    await _subscriptionService.initialize();
    await _subscriptionService.checkSubscriptionStatus();
    // ... rest of initialization
  }
}
```

---

#### 3.4 Update AI Strategies Screen

**File:** `lib/screens/ai_strategies_screen.dart`

Replace the lock screen with paywall:

```dart
if (!AppSettingsService().isPremium) {
  return PaywallScreen(); // Show paywall instead of lock screen
}
```

---

### Phase 4: Update Documentation (30 min)

Update all docs to reflect new pricing:
- ✅ index.html
- ✅ support.html
- ✅ terms.html
- ✅ App Store description
- ✅ Google Play description

---

## 📱 Testing Checklist

### iOS Testing
- [ ] Create sandbox test user in App Store Connect
- [ ] Test monthly subscription purchase
- [ ] Test annual subscription purchase
- [ ] Test 7-day free trial
- [ ] Test subscription cancellation
- [ ] Test restore purchases
- [ ] Test subscription expiration

### Android Testing
- [ ] Create test account in Google Play Console
- [ ] Test monthly subscription purchase
- [ ] Test annual subscription purchase
- [ ] Test 7-day free trial
- [ ] Test subscription cancellation
- [ ] Test restore purchases
- [ ] Test subscription expiration

---

## 🚀 Launch Checklist

- [ ] RevenueCat configured
- [ ] iOS subscriptions created in App Store Connect
- [ ] Android subscriptions created in Google Play Console
- [ ] Code implemented and tested
- [ ] Privacy Policy updated (mention subscriptions)
- [ ] Terms of Service updated (refund policy)
- [ ] App Store screenshots show "Premium" features
- [ ] Support email ready for subscription questions

---

## 📊 Analytics to Track

- Conversion rate (free → premium)
- Trial start rate
- Trial → paid conversion
- Churn rate
- MRR (Monthly Recurring Revenue)
- LTV (Lifetime Value)

---

## 💡 Tips

1. **Offer annual upfront** - Users save money, you get cash flow
2. **7-day trial is sweet spot** - Long enough to see value, short enough to convert
3. **Show value early** - Let users see locked features to create desire
4. **Remind before trial ends** - Send notification 1 day before trial expires
5. **Easy cancellation** - Builds trust, reduces support tickets

---

## 🆘 Support

**RevenueCat Docs:** https://docs.revenuecat.com/
**Flutter Plugin:** https://pub.dev/packages/purchases_flutter

---

**Status:** Ready to implement 🚀
**Estimated Time:** 6-8 hours total
**Difficulty:** Medium


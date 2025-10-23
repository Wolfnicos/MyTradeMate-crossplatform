# Strategia Aplicației MyTradeMate - Ianuarie 2025

## 📱 Modelul de Business

### 🆓 FREE MODE (Read-Only + AI Teaser)
**Permisiune API:** READ ONLY

**Ce poate face utilizatorul:**
- ✅ Conectare la Binance API (sau alte exchange-uri)
- ✅ Vizualizare portofoliu complet (toate monedele + balanțe)
- ✅ Vizualizare prețuri în timp real
- ✅ Grafice candlestick (toate timeframe-urile: 5m, 15m, 1h, 4h, 1d)
- ✅ Date de piață (24h change, volume)
- ✅ Istoric tranzacții (read-only)
- ✅ **AI Predictions pe 1D (Daily) DOAR** 🎁
  - Vede BUY/SELL/HOLD cu explicație
  - Vede confidence score
  - Vede de ce AI recomandă acea acțiune
  - **NU execută automat** - user decide singur

**Ce NU poate face:**
- ❌ **AI Predictions pe timeframe-uri scurte** (5m, 15m, 1h, 4h) - LOCKED 🔒
- ❌ **Trading** (nu poate plasa ordine - API e READ ONLY)
- ❌ **Volatility & Liquidity indicators** (doar în Premium)
- ❌ **Model contributions** (ce modele AI au votat)

**Mesaj pentru utilizator:**
> "💡 AI recomandă BUY pe BTC (1D). Upgrade la Premium pentru predicții pe toate timeframe-urile și trading."

---

### 💎 PREMIUM MODE (Trading + Full AI)
**Permisiune API:** TRADING (SPOT & MARGIN TRADING)

**Ce poate face utilizatorul:**
- ✅ **Tot din FREE MODE**
- ✅ **AI Predictions COMPLETE:**
  - BUY/SELL/HOLD pe fiecare monedă
  - Confidence score (0-100%)
  - **Predicții pe TOATE timeframe-urile:** 5m, 15m, 1h, 4h, 1d, 7d 🔓
  - Volatility & Liquidity indicators (ATR, Volume percentile)
  - Model contributions (ce modele AI au votat)
  - Explicații detaliate de ce AI recomandă acea acțiune
- ✅ **Trading Manual (User decide):**
  - **Market Order** - cumpără/vinde instant la preț curent
  - **Limit Order** - cumpără/vinde la preț specific (ex: cumpără BTC la $95,000)
  - **Stop-Limit** - activează limit order când prețul atinge stop price
  - **Stop-Market** - activează market order când prețul atinge stop price
  - OCO Orders (One-Cancels-Other) - TP + SL simultan
- ✅ **AI Strategies Screen complet activ:**
  - Vizualizare predicții în timp real pe toate timeframe-urile
  - Refresh manual predictions
  - Comparație între timeframe-uri (5m vs 1h vs 1d)
- ✅ **Risk Management Tools:**
  - Setare stop-loss % (ex: 3%)
  - Setare take-profit % (ex: 6%)
  - Calculator position sizing

**IMPORTANT:** 
> ⚠️ **AI NU execută automat!** AI doar recomandă (BUY/SELL/HOLD), dar **user decide și plasează ordinul manual** în Orders Screen.

**Mesaj pentru utilizator:**
> "🤖 AI-ul tău personal analizează piața 24/7 pe toate timeframe-urile. Tu decizi când să cumperi/vinzi."

---

## 🔒 Situația Actuală (Ianuarie 2025)

### API Binance în Test Mode
- **Status:** READ ONLY
- **Ce funcționează:**
  - ✅ Fetch balances (`getAccountBalances()`)
  - ✅ Fetch prices (`fetchTicker24h()`)
  - ✅ Fetch candles (`fetchKlines()`)
  - ✅ Fetch open orders (`fetchOpenOrders()`)
- **Ce NU funcționează:**
  - ❌ Place orders (`placeMarketOrder()`) → va da eroare 401/403
  - ❌ Cancel orders (`cancelOrder()`) → va da eroare 401/403

### Ce trebuie implementat:
1. **Detectare automată a permisiunii API**
   - La conectare, aplicația verifică dacă API key are permisiune TRADING
   - Dacă DA → activează Premium Mode
   - Dacă NU → activează Free Mode

2. **UI adaptat la permisiune**
   - Free Mode: ascunde/blochează AI Strategies Screen
   - Free Mode: ascunde butonul "Place Order" din Orders Screen
   - Free Mode: afișează banner "Upgrade to Premium"

3. **Sistem de plată (viitor)**
   - User plătește → primește API key cu permisiune TRADING
   - Sau: user își creează propriul API key cu TRADING și îl adaugă în app

---

## 📂 Structura Codului Actual

### ✅ Ce funcționează corect:

#### 1. **Dashboard Screen** (`lib/screens/dashboard_screen.dart`)
- ✅ Portfolio Overview Card (afișează balanțe)
- ✅ AI Neural Engine Card (status modele AI)
- ✅ Market Overview (BTC, ETH, BNB, SOL, WLFI, TRUMP)
- **Funcționează în:** FREE + PREMIUM

#### 2. **Market Screen** (`lib/screens/market_screen.dart`)
- ✅ Candlestick charts
- ✅ Timeframe selector (5m, 15m, 1h, 4h, 1d)
- ✅ Price display cu 24h change
- **Funcționează în:** FREE + PREMIUM

#### 3. **AI Strategies Screen** (`lib/screens/ai_strategies_screen.dart`)
- ✅ Symbol selector (din portofoliu)
- ✅ Timeframe selector (5m, 15m, 1h, 4h, 1d)
- ✅ AI Prediction Card:
  - BUY/SELL/HOLD signal
  - Confidence score
  - Volatility badge (ATR)
  - Liquidity badge (Volume percentile)
- ✅ Model Contributions (ce modele AI au votat)
- **Funcționează în:** DOAR PREMIUM (trebuie blocat în FREE)

#### 4. **Orders Screen** (`lib/screens/orders_screen.dart`)
- ✅ BUY/SELL toggle
- ✅ Symbol picker (din portofoliu)
- ✅ Amount input
- ✅ Current price display
- ✅ Total calculation
- ✅ Open Orders Card (afișează ordine active)
- ⚠️ Execute button → trebuie blocat în FREE mode
- **Funcționează în:** DOAR PREMIUM (trebuie blocat în FREE)

#### 5. **Portfolio Screen** (`lib/screens/portfolio_screen.dart`)
- ✅ Total portfolio value
- ✅ Lista monedelor cu balanțe
- ✅ Donut chart (distribuție portofoliu)
- **Funcționează în:** FREE + PREMIUM

#### 6. **Settings Screen** (`lib/screens/settings_screen.dart`)
- ✅ API Key management
- ✅ Quote currency selector (USDT, EUR, USD, USDC)
- ✅ Theme selector (Light/Dark/System)
- ✅ Biometric authentication toggle
- **Funcționează în:** FREE + PREMIUM

---

## 🔧 Ce trebuie modificat:

### 1. **Detectare automată permisiune API**

**Fișier:** `lib/services/app_settings_service.dart`

**Status actual:**
```dart
String _permissionLevel = 'read'; // hardcoded
bool get isTradingEnabled => _permissionLevel.toLowerCase() == 'trading';
```

**Ce trebuie adăugat:**
```dart
// Auto-detect API permission level from Binance
Future<void> detectApiPermission() async {
  try {
    final binance = BinanceService();
    await binance.loadCredentials();
    
    // Try to fetch account info (requires READ permission)
    final canRead = await binance.testConnection();
    
    if (!canRead) {
      _permissionLevel = 'none';
      notifyListeners();
      return;
    }
    
    // Try to place a test order with 0 quantity (will fail but tells us if TRADING is enabled)
    try {
      // This will fail with "Invalid quantity" if TRADING is enabled
      // or with "Unauthorized" if only READ is enabled
      await binance.placeMarketOrder(
        symbol: 'BTCUSDT',
        side: 'BUY',
        quantity: 0.0, // Invalid quantity to trigger error
      );
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      
      if (errorMsg.contains('unauthorized') || 
          errorMsg.contains('403') || 
          errorMsg.contains('api-key does not have permission')) {
        _permissionLevel = 'read';
      } else if (errorMsg.contains('invalid quantity') || 
                 errorMsg.contains('min notional')) {
        // Error about quantity means TRADING is enabled!
        _permissionLevel = 'trading';
      } else {
        _permissionLevel = 'read'; // Default to read-only
      }
    }
    
    await setPermissionLevel(_permissionLevel);
    debugPrint('✅ API Permission detected: $_permissionLevel');
    
  } catch (e) {
    debugPrint('❌ Failed to detect API permission: $e');
    _permissionLevel = 'read'; // Safe default
  }
}
```

### 2. **Blocare AI Strategies Screen în FREE mode**

**Fișier:** `lib/screens/ai_strategies_screen.dart`

**Adaugă la începutul `build()` method:**
```dart
@override
Widget build(BuildContext context) {
  // Check if trading is enabled
  final tradingEnabled = AppSettingsService().isTradingEnabled;
  
  if (!tradingEnabled) {
    // Show upgrade screen instead of AI predictions
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: AppTheme.warning,
                ),
                const SizedBox(height: AppTheme.spacing24),
                Text(
                  'AI Predictions Locked',
                  style: AppTheme.displayMedium.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacing16),
                Text(
                  'Upgrade to Premium to unlock:\n\n'
                  '🤖 AI BUY/SELL/HOLD predictions\n'
                  '📊 Multi-timeframe analysis\n'
                  '⚡ Real-time trading signals\n'
                  '🎯 Confidence scoring\n'
                  '📈 Volatility & liquidity indicators',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacing32),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to upgrade/settings
                    Navigator.pushNamed(context, '/settings');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing32,
                      vertical: AppTheme.spacing16,
                    ),
                  ),
                  child: Text(
                    'Upgrade to Premium',
                    style: AppTheme.headingMedium.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing16),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/settings');
                  },
                  child: Text(
                    'Configure API Key',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Rest of existing code for PREMIUM users...
  return Scaffold(
    // ... existing AI Strategies UI
  );
}
```

### 3. **Blocare Orders Screen în FREE mode**

**Fișier:** `lib/screens/orders_screen.dart`

**Deja implementat parțial!** (linia ~450)
```dart
if (tradingEnabled)
  // Show order form
else
  GlassCard(
    child: Column(
      children: [
        // "Trading disabled (Read-only mode)" message
      ],
    ),
  )
```

**✅ Acest cod e deja corect!** Doar trebuie să te asiguri că `AppSettingsService().isTradingEnabled` returnează `false` când API e READ ONLY.

### 4. **Banner "Upgrade to Premium" în Dashboard**

**Fișier:** `lib/screens/dashboard_screen.dart`

**Adaugă după Portfolio Overview Card:**
```dart
// After PortfolioOverviewCard
const SizedBox(height: AppTheme.spacing16),

// Upgrade Banner (only in FREE mode)
if (!AppSettingsService().isTradingEnabled)
  GlassCard(
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.1),
            AppTheme.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Icon(Icons.auto_awesome, color: Colors.white, size: 24),
          ),
          const SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unlock AI Trading',
                  style: AppTheme.headingMedium,
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  'Get AI predictions and auto-trading',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: AppTheme.primary, size: 16),
        ],
      ),
    ),
  ),
```

---

## 🧪 Plan de Testare

### Test 1: FREE Mode (READ ONLY API)
1. ✅ Conectează API key cu permisiune READ ONLY
2. ✅ Verifică că Dashboard afișează portofoliul
3. ✅ Verifică că Market Screen afișează grafice
4. ✅ Verifică că AI Strategies Screen e blocat (afișează "Upgrade")
5. ✅ Verifică că Orders Screen e blocat (afișează "Trading disabled")
6. ✅ Verifică că banner "Upgrade to Premium" apare în Dashboard

### Test 2: PREMIUM Mode (TRADING API)
1. ✅ Conectează API key cu permisiune TRADING
2. ✅ Verifică că toate ecranele sunt deblocate
3. ✅ Verifică că AI Strategies Screen afișează predicții
4. ✅ Verifică că Orders Screen permite plasarea ordinelor
5. ✅ Plasează un ordin de test (cu sumă mică!)
6. ✅ Verifică că ordinul apare în Open Orders

---

## 📋 Checklist Implementare

### Prioritate 1 (Critică)
- [ ] Implementează `detectApiPermission()` în `AppSettingsService`
- [ ] Apelează `detectApiPermission()` la conectarea API key
- [ ] Blochează AI Strategies Screen în FREE mode
- [ ] Verifică că Orders Screen e deja blocat în FREE mode
- [ ] Adaugă banner "Upgrade to Premium" în Dashboard

### Prioritate 2 (Importantă)
- [ ] Adaugă indicator vizual în Settings pentru permisiune API (READ vs TRADING)
- [ ] Adaugă tooltip-uri care explică diferența FREE vs PREMIUM
- [ ] Testează cu API key READ ONLY real
- [ ] Testează cu API key TRADING real (cu sume mici!)

### Prioritate 3 (Nice-to-have)
- [ ] Adaugă animație la deblocarea Premium features
- [ ] Adaugă onboarding pentru utilizatori noi (explică FREE vs PREMIUM)
- [ ] Adaugă statistici de utilizare (câte predicții AI au fost corecte)

---

## 💡 Întrebări pentru Clarificare

1. **Cum va plăti utilizatorul pentru Premium?**
   - In-app purchase (Apple/Google)?
   - Abonament lunar/anual?
   - Plată unică?

2. **Unde va fi stocat status-ul Premium?**
   - Local (SharedPreferences)?
   - Backend server?
   - Verificare prin API key permission?

3. **Ce se întâmplă dacă user schimbă API key-ul?**
   - Re-detectează automat permisiunea?
   - Cere re-autentificare?

---

## 📞 Contact

Pentru întrebări despre implementare, contactează echipa de dezvoltare.

**Status:** ✅ Strategia clarificată și documentată  
**Data:** 23 Ianuarie 2025

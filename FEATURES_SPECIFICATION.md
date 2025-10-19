# 📊 SPECIFICAȚII COMPLETE FEATURES PENTRU ANTRENARE ML

## 🎯 SPECIFICAȚII GENERALE

### Input Shape
```
[60, 76]
```
- **60 timesteps** (60 candle-uri istorice consecutive)
- **76 features** per timestep

### Output Shape
```
[3]
```
- **Class 0**: SELL
- **Class 1**: HOLD
- **Class 2**: BUY

### Date Necesare
Minim **260 candle-uri** pentru fiecare sample (pentru calcul SMA200 + 60 sequence)

---

## 📋 LISTA COMPLETĂ FEATURES (76 TOTAL)

### 🕯️ CANDLE PATTERNS (Indices 0-24) - 25 features

Toate valorile sunt **binare (0.0 sau 1.0)**:

| Index | Feature Name | Description |
|-------|--------------|-------------|
| 0 | doji | Doji pattern |
| 1 | dragonfly_doji | Dragonfly doji |
| 2 | gravestone_doji | Gravestone doji |
| 3 | long_legged_doji | Long-legged doji |
| 4 | hammer | Hammer pattern |
| 5 | inverted_hammer | Inverted hammer |
| 6 | shooting_star | Shooting star |
| 7 | hanging_man | Hanging man |
| 8 | spinning_top | Spinning top |
| 9 | marubozu_bullish | Bullish marubozu |
| 10 | marubozu_bearish | Bearish marubozu |
| 11 | bullish_engulfing | Bullish engulfing |
| 12 | bearish_engulfing | Bearish engulfing |
| 13 | piercing_line | Piercing line |
| 14 | dark_cloud_cover | Dark cloud cover |
| 15 | bullish_harami | Bullish harami |
| 16 | bearish_harami | Bearish harami |
| 17 | tweezer_bottom | Tweezer bottom |
| 18 | tweezer_top | Tweezer top |
| 19 | morning_star | Morning star |
| 20 | evening_star | Evening star |
| 21 | three_white_soldiers | Three white soldiers |
| 22 | three_black_crows | Three black crows |
| 23 | rising_three | Rising three methods |
| 24 | falling_three | Falling three methods |

### 📈 PRICE ACTION (Indices 25-29) - 5 features

| Index | Feature Name | Formula | Description |
|-------|--------------|---------|-------------|
| 25 | returns | (close[i] - close[i-1]) / close[i-1] | Simple returns |
| 26 | log_returns | log(close[i] / close[i-1]) | Logarithmic returns |
| 27 | volatility | std(returns, window=20) | 20-period rolling volatility |
| 28 | hl_range | (high - low) / close | High-low range normalized by close |
| 29 | close_position | (close - low) / (high - low) | Close position within range |

### 📊 RSI (Indices 30-32) - 3 features

| Index | Feature Name | Formula | Description |
|-------|--------------|---------|-------------|
| 30 | rsi | RSI(14) | Relative Strength Index (0-100) |
| 31 | rsi_oversold | 1 if RSI < 30 else 0 | Binary oversold flag |
| 32 | rsi_overbought | 1 if RSI > 70 else 0 | Binary overbought flag |

### 📉 MACD (Indices 33-37) - 5 features

| Index | Feature Name | Formula | Description |
|-------|--------------|---------|-------------|
| 33 | macd | EMA(12) - EMA(26) | MACD line |
| 34 | macd_signal | EMA(macd, 9) | Signal line |
| 35 | macd_histogram | macd - macd_signal | MACD histogram |
| 36 | macd_cross_above | 1 if bullish crossover else 0 | MACD crosses above signal |
| 37 | macd_cross_below | 1 if bearish crossover else 0 | MACD crosses below signal |

### 📏 BOLLINGER BANDS (Indices 38-43) - 6 features

| Index | Feature Name | Formula | Description |
|-------|--------------|---------|-------------|
| 38 | bb_upper | SMA(20) + 2*std | Upper band |
| 39 | bb_middle | SMA(20) | Middle band |
| 40 | bb_lower | SMA(20) - 2*std | Lower band |
| 41 | bb_width | (upper - lower) / middle | Band width |
| 42 | bb_position | (close - lower) / (upper - lower) | Position within bands |
| 43 | bb_squeeze | 1 if width < 0.1 else 0 | Squeeze indicator |

### 💥 ATR (Indices 44-45) - 2 features

| Index | Feature Name | Formula | Description |
|-------|--------------|---------|-------------|
| 44 | atr | ATR(14) | Average True Range |
| 45 | atr_pct | ATR / close | ATR as percentage of price |

### 📐 ADX (Indices 46-47) - 2 features

| Index | Feature Name | Formula | Description |
|-------|--------------|---------|-------------|
| 46 | adx | ADX(14) | Average Directional Index |
| 47 | trending | 1 if ADX > 25 else 0 | Strong trend indicator |

### 🎲 STOCHASTIC (Indices 48-51) - 4 features

| Index | Feature Name | Formula | Description |
|-------|--------------|---------|-------------|
| 48 | stoch_k | %K(14) | Stochastic %K (0-100) |
| 49 | stoch_d | SMA(%K, 3) | Stochastic %D |
| 50 | stoch_oversold | 1 if %K < 20 else 0 | Oversold flag |
| 51 | stoch_overbought | 1 if %K > 80 else 0 | Overbought flag |

### ☁️ ICHIMOKU (Indices 52-58) - 7 features

| Index | Feature Name | Formula | Description |
|-------|--------------|---------|-------------|
| 52 | ichimoku_tenkan | (high9 + low9) / 2 | Conversion line (9-period) |
| 53 | ichimoku_kijun | (high26 + low26) / 2 | Base line (26-period) |
| 54 | ichimoku_senkou_a | (tenkan + kijun) / 2 | Leading span A |
| 55 | ichimoku_senkou_b | (high52 + low52) / 2 | Leading span B (52-period) |
| 56 | ichimoku_cloud_green | 1 if senkou_a > senkou_b else 0 | Bullish cloud |
| 57 | ichimoku_above_cloud | 1 if close > max(senkou_a, senkou_b) else 0 | Price above cloud |
| 58 | ichimoku_below_cloud | 1 if close < min(senkou_a, senkou_b) else 0 | Price below cloud |

### 📊 VOLUME METRICS (Indices 59-63) - 5 features

| Index | Feature Name | Formula | Description |
|-------|--------------|---------|-------------|
| 59 | volume | volume | Raw volume |
| 60 | vol_sma | SMA(volume, 20) | 20-period volume SMA |
| 61 | vol_ratio | volume / vol_sma | Volume relative to average |
| 62 | obv | On-Balance Volume | Cumulative volume indicator |
| 63 | high_volume | 1 if vol_ratio > 1.5 else 0 | High volume flag |

### 📈 MOVING AVERAGES (Indices 64-72) - 9 features

| Index | Feature Name | Formula | Description |
|-------|--------------|---------|-------------|
| 64 | sma20 | SMA(20) | 20-period simple MA |
| 65 | sma50 | SMA(50) | 50-period simple MA |
| 66 | sma200 | SMA(200) | 200-period simple MA |
| 67 | price_above_sma20 | 1 if close > sma20 else 0 | Above 20-day MA |
| 68 | price_above_sma50 | 1 if close > sma50 else 0 | Above 50-day MA |
| 69 | price_above_sma200 | 1 if close > sma200 else 0 | Above 200-day MA |
| 70 | golden_cross | 1 if sma50 crosses above sma200 else 0 | Bullish crossover |
| 71 | death_cross | 1 if sma50 crosses below sma200 else 0 | Bearish crossover |
| 72 | sma_alignment | Derived from above | (Not used directly, counted in total) |

### 📊 TREND INDICATORS (Indices 73-75) - 3 features

| Index | Feature Name | Formula | Description |
|-------|--------------|---------|-------------|
| 73 | higher_high | 1 if high > high[i-1] else 0 | Higher high |
| 74 | lower_low | 1 if low < low[i-1] else 0 | Lower low |
| 75 | uptrend | 1 if close > sma20 > sma50 else 0 | Uptrend alignment |

**NOTA:** În implementarea curentă sunt 76 features (0-75), ultima fiind `downtrend`:

| Index | Feature Name | Formula | Description |
|-------|--------------|---------|-------------|
| 75 | downtrend | 1 if close < sma20 < sma50 else 0 | Downtrend alignment |

---

## 🔧 PYTHON: COD COMPLET PENTRU GENERARE FEATURES

```python
import pandas as pd
import numpy as np
import talib

def build_76_features(df):
    """
    Construiește exact cele 76 de features pentru fiecare timestep.

    Args:
        df: DataFrame cu coloanele ['open', 'high', 'low', 'close', 'volume']
        Minim 260 rows pentru SMA200

    Returns:
        numpy array cu shape (len(df), 76)
    """
    assert len(df) >= 260, "Need at least 260 candles for SMA200"

    features = pd.DataFrame(index=df.index)

    # Extract OHLCV
    opens = df['open'].values
    highs = df['high'].values
    lows = df['low'].values
    closes = df['close'].values
    volumes = df['volume'].values

    # === CANDLE PATTERNS (0-24) ===
    pattern_funcs = [
        ('doji', talib.CDLDOJI),
        ('dragonfly_doji', talib.CDLDRAGONFLYDOJI),
        ('gravestone_doji', talib.CDLGRAVESTONEDOJI),
        ('long_legged_doji', talib.CDLLONGLEGGEDDOJI),
        ('hammer', talib.CDLHAMMER),
        ('inverted_hammer', talib.CDLINVERTEDHAMMER),
        ('shooting_star', talib.CDLSHOOTINGSTAR),
        ('hanging_man', talib.CDLHANGINGMAN),
        ('spinning_top', talib.CDLSPINNINGTOP),
        ('marubozu', talib.CDLMARUBOZU),  # For bullish
        ('marubozu', talib.CDLMARUBOZU),  # For bearish (will split)
        ('engulfing', talib.CDLENGULFING),  # Will split to bullish/bearish
        ('engulfing', talib.CDLENGULFING),
        ('piercing', talib.CDLPIERCING),
        ('darkcloudcover', talib.CDLDARKCLOUDCOVER),
        ('harami', talib.CDLHARAMI),  # Will split
        ('harami', talib.CDLHARAMI),
        ('2crows', talib.CDL2CROWS),  # Tweezer approximation
        ('2crows', talib.CDL2CROWS),
        ('morningstar', talib.CDLMORNINGSTAR),
        ('eveningstar', talib.CDLEVENINGSTAR),
        ('3whitesoldiers', talib.CDL3WHITESOLDIERS),
        ('3blackcrows', talib.CDL3BLACKCROWS),
        ('risefall3methods', talib.CDLRISEFALL3METHODS),  # Will split
        ('risefall3methods', talib.CDLRISEFALL3METHODS),
    ]

    # Simplified: detect all 25 patterns
    features['doji'] = (talib.CDLDOJI(opens, highs, lows, closes) != 0).astype(float)
    features['dragonfly_doji'] = (talib.CDLDRAGONFLYDOJI(opens, highs, lows, closes) != 0).astype(float)
    features['gravestone_doji'] = (talib.CDLGRAVESTONEDOJI(opens, highs, lows, closes) != 0).astype(float)
    features['long_legged_doji'] = (talib.CDLLONGLEGGEDDOJI(opens, highs, lows, closes) != 0).astype(float)
    features['hammer'] = (talib.CDLHAMMER(opens, highs, lows, closes) != 0).astype(float)
    features['inverted_hammer'] = (talib.CDLINVERTEDHAMMER(opens, highs, lows, closes) != 0).astype(float)
    features['shooting_star'] = (talib.CDLSHOOTINGSTAR(opens, highs, lows, closes) != 0).astype(float)
    features['hanging_man'] = (talib.CDLHANGINGMAN(opens, highs, lows, closes) != 0).astype(float)
    features['spinning_top'] = (talib.CDLSPINNINGTOP(opens, highs, lows, closes) != 0).astype(float)

    marubozu = talib.CDLMARUBOZU(opens, highs, lows, closes)
    features['marubozu_bullish'] = (marubozu > 0).astype(float)
    features['marubozu_bearish'] = (marubozu < 0).astype(float)

    engulfing = talib.CDLENGULFING(opens, highs, lows, closes)
    features['bullish_engulfing'] = (engulfing > 0).astype(float)
    features['bearish_engulfing'] = (engulfing < 0).astype(float)

    features['piercing_line'] = (talib.CDLPIERCING(opens, highs, lows, closes) != 0).astype(float)
    features['dark_cloud_cover'] = (talib.CDLDARKCLOUDCOVER(opens, highs, lows, closes) != 0).astype(float)

    harami = talib.CDLHARAMI(opens, highs, lows, closes)
    features['bullish_harami'] = (harami > 0).astype(float)
    features['bearish_harami'] = (harami < 0).astype(float)

    # Tweezer patterns (approximation)
    features['tweezer_bottom'] = ((lows == lows.shift(1)) & (closes > opens)).astype(float)
    features['tweezer_top'] = ((highs == highs.shift(1)) & (closes < opens)).astype(float)

    features['morning_star'] = (talib.CDLMORNINGSTAR(opens, highs, lows, closes) != 0).astype(float)
    features['evening_star'] = (talib.CDLEVENINGSTAR(opens, highs, lows, closes) != 0).astype(float)
    features['three_white_soldiers'] = (talib.CDL3WHITESOLDIERS(opens, highs, lows, closes) != 0).astype(float)
    features['three_black_crows'] = (talib.CDL3BLACKCROWS(opens, highs, lows, closes) != 0).astype(float)

    # Rising/Falling three methods (approximation)
    features['rising_three'] = ((closes > closes.shift(3)) & (closes > opens)).astype(float)
    features['falling_three'] = ((closes < closes.shift(3)) & (closes < opens)).astype(float)

    # === PRICE ACTION (25-29) ===
    features['returns'] = closes.pct_change()
    features['log_returns'] = np.log(closes / closes.shift(1))
    features['volatility'] = features['returns'].rolling(20).std()
    features['hl_range'] = (highs - lows) / closes
    features['close_position'] = (closes - lows) / ((highs - lows) + 1e-10)

    # === RSI (30-32) ===
    rsi = talib.RSI(closes, timeperiod=14)
    features['rsi'] = rsi
    features['rsi_oversold'] = (rsi < 30).astype(float)
    features['rsi_overbought'] = (rsi > 70).astype(float)

    # === MACD (33-37) ===
    macd, signal, hist = talib.MACD(closes, fastperiod=12, slowperiod=26, signalperiod=9)
    features['macd'] = macd
    features['macd_signal'] = signal
    features['macd_histogram'] = hist
    features['macd_cross_above'] = ((macd > signal) & (macd.shift(1) <= signal.shift(1))).astype(float)
    features['macd_cross_below'] = ((macd < signal) & (macd.shift(1) >= signal.shift(1))).astype(float)

    # === BOLLINGER BANDS (38-43) ===
    bb_upper, bb_middle, bb_lower = talib.BBANDS(closes, timeperiod=20, nbdevup=2, nbdevdn=2)
    features['bb_upper'] = bb_upper
    features['bb_middle'] = bb_middle
    features['bb_lower'] = bb_lower
    features['bb_width'] = (bb_upper - bb_lower) / bb_middle
    features['bb_position'] = (closes - bb_lower) / ((bb_upper - bb_lower) + 1e-10)
    features['bb_squeeze'] = (features['bb_width'] < 0.1).astype(float)

    # === ATR (44-45) ===
    atr = talib.ATR(highs, lows, closes, timeperiod=14)
    features['atr'] = atr
    features['atr_pct'] = atr / closes

    # === ADX (46-47) ===
    adx = talib.ADX(highs, lows, closes, timeperiod=14)
    features['adx'] = adx
    features['trending'] = (adx > 25).astype(float)

    # === STOCHASTIC (48-51) ===
    stoch_k, stoch_d = talib.STOCH(highs, lows, closes, fastk_period=14, slowk_period=3, slowd_period=3)
    features['stoch_k'] = stoch_k
    features['stoch_d'] = stoch_d
    features['stoch_oversold'] = (stoch_k < 20).astype(float)
    features['stoch_overbought'] = (stoch_k > 80).astype(float)

    # === ICHIMOKU (52-58) ===
    # Tenkan-sen (9-period)
    tenkan = (highs.rolling(9).max() + lows.rolling(9).min()) / 2
    # Kijun-sen (26-period)
    kijun = (highs.rolling(26).max() + lows.rolling(26).min()) / 2
    # Senkou Span A
    senkou_a = (tenkan + kijun) / 2
    # Senkou Span B (52-period)
    senkou_b = (highs.rolling(52).max() + lows.rolling(52).min()) / 2

    features['ichimoku_tenkan'] = tenkan
    features['ichimoku_kijun'] = kijun
    features['ichimoku_senkou_a'] = senkou_a
    features['ichimoku_senkou_b'] = senkou_b
    features['ichimoku_cloud_green'] = (senkou_a > senkou_b).astype(float)
    features['ichimoku_above_cloud'] = ((closes > senkou_a) & (closes > senkou_b)).astype(float)
    features['ichimoku_below_cloud'] = ((closes < senkou_a) & (closes < senkou_b)).astype(float)

    # === VOLUME (59-63) ===
    vol_sma = talib.SMA(volumes, timeperiod=20)
    obv = talib.OBV(closes, volumes)

    features['volume'] = volumes
    features['vol_sma'] = vol_sma
    features['vol_ratio'] = volumes / (vol_sma + 1e-10)
    features['obv'] = obv
    features['high_volume'] = (features['vol_ratio'] > 1.5).astype(float)

    # === MOVING AVERAGES (64-72) ===
    sma20 = talib.SMA(closes, timeperiod=20)
    sma50 = talib.SMA(closes, timeperiod=50)
    sma200 = talib.SMA(closes, timeperiod=200)

    features['sma20'] = sma20
    features['sma50'] = sma50
    features['sma200'] = sma200
    features['price_above_sma20'] = (closes > sma20).astype(float)
    features['price_above_sma50'] = (closes > sma50).astype(float)
    features['price_above_sma200'] = (closes > sma200).astype(float)
    features['golden_cross'] = ((sma50 > sma200) & (sma50.shift(1) <= sma200.shift(1))).astype(float)
    features['death_cross'] = ((sma50 < sma200) & (sma50.shift(1) >= sma200.shift(1))).astype(float)

    # === TREND INDICATORS (73-75) ===
    features['higher_high'] = (highs > highs.shift(1)).astype(float)
    features['lower_low'] = (lows < lows.shift(1)).astype(float)
    features['uptrend'] = ((closes > sma20) & (sma20 > sma50)).astype(float)
    features['downtrend'] = ((closes < sma20) & (sma20 < sma50)).astype(float)

    # Replace NaN/Inf with 0
    features = features.replace([np.inf, -np.inf], np.nan).fillna(0)

    return features.values  # Returns numpy array (n, 76)


def create_sequences(features, labels, sequence_length=60):
    """
    Creează secvențe de 60 timesteps pentru training.

    Args:
        features: numpy array (n, 76)
        labels: numpy array (n,) cu valori 0 (SELL), 1 (HOLD), 2 (BUY)
        sequence_length: 60 timesteps

    Returns:
        X: numpy array (num_samples, 60, 76)
        y: numpy array (num_samples, 3) one-hot encoded
    """
    X, y = [], []

    for i in range(len(features) - sequence_length):
        X.append(features[i:i+sequence_length])
        y.append(labels[i+sequence_length])

    X = np.array(X)

    # One-hot encode labels
    from tensorflow.keras.utils import to_categorical
    y = to_categorical(y, num_classes=3)

    return X, y
```

---

## ✅ VERIFICARE FINALĂ

Înainte de a antrena, verifică:

```python
# Verifică shape-ul
print(f"Features shape: {features.shape}")  # Should be (n, 76)
print(f"X shape: {X.shape}")  # Should be (num_samples, 60, 76)
print(f"y shape: {y.shape}")  # Should be (num_samples, 3)

# Verifică că nu ai NaN/Inf
assert not np.isnan(X).any(), "Found NaN in features!"
assert not np.isinf(X).any(), "Found Inf in features!"
```

---

## 🚫 ARHITECTURI NU COMPATIBILE

```python
# ❌ NU MERGE pe iOS/Android
model.add(LSTM(128))           # Folosește FlexTensorListReserve
model.add(GRU(64))             # Folosește FlexTensorListReserve
model.add(Bidirectional(...))  # Folosește FlexTensorListReserve
```

## ✅ ARHITECTURI COMPATIBILE

```python
# ✅ MERGE pe iOS/Android
model.add(Conv1D(64, 3))           # Convolutions 1D
model.add(Dense(128))              # Fully connected
model.add(GlobalAveragePooling1D()) # Pooling
```

---

## 📦 DEPENDENCIES PYTHON

```bash
pip install numpy pandas ta-lib tensorflow scikit-learn
```

**NOTA:** TA-Lib necesită instalare separată:
- macOS: `brew install ta-lib`
- Linux: `sudo apt-get install ta-lib`
- Windows: Descarcă binaries de pe https://www.lfd.uci.edu/~gohlke/pythonlibs/

---

**Document creat:** 2025-10-18
**Versiune:** 1.0
**Compatibil cu:** iOS 13+, Android API 21+

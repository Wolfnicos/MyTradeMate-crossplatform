#!/usr/bin/env python3
"""
TRANSFORMER-BASED MODEL for crypto prediction - SOTA architecture
Uses multi-head attention for better temporal pattern recognition
Expected accuracy: 55-65% (vs current CNN: 43-56%)
"""

import os
import json
import numpy as np
import pandas as pd
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
import talib
import ccxt
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from datetime import datetime
import joblib
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration
SEQUENCE_LENGTH = 60
NUM_FEATURES = 76
NUM_CLASSES = 3  # SELL, HOLD, BUY

# Training coins (diverse portfolio)
TRAINING_COINS = ['BTC', 'ETH', 'BNB', 'SOL', 'ADA', 'XRP', 'DOT', 'MATIC', 'AVAX', 'LINK']

def build_exact_76_features(df):
    """
    EXACT SAME 76 features as coin-specific models
    Uses TALib candle patterns (features 0-24) + technical indicators
    """

    features = pd.DataFrame(index=df.index)

    opens = df['open'].values
    highs = df['high'].values
    lows = df['low'].values
    closes = df['close'].values
    volumes = df['volume'].values

    # ========== 0-24: CANDLE PATTERNS (25 features) ==========
    features['f0'] = (talib.CDLDOJI(opens, highs, lows, closes) != 0).astype(float)
    features['f1'] = (talib.CDLDRAGONFLYDOJI(opens, highs, lows, closes) != 0).astype(float)
    features['f2'] = (talib.CDLGRAVESTONEDOJI(opens, highs, lows, closes) != 0).astype(float)
    features['f3'] = (talib.CDLLONGLEGGEDDOJI(opens, highs, lows, closes) != 0).astype(float)
    features['f4'] = (talib.CDLHAMMER(opens, highs, lows, closes) != 0).astype(float)
    features['f5'] = (talib.CDLINVERTEDHAMMER(opens, highs, lows, closes) != 0).astype(float)
    features['f6'] = (talib.CDLSHOOTINGSTAR(opens, highs, lows, closes) != 0).astype(float)
    features['f7'] = (talib.CDLHANGINGMAN(opens, highs, lows, closes) != 0).astype(float)
    features['f8'] = (talib.CDLSPINNINGTOP(opens, highs, lows, closes) != 0).astype(float)

    marubozu = talib.CDLMARUBOZU(opens, highs, lows, closes)
    features['f9'] = (marubozu > 0).astype(float)
    features['f10'] = (marubozu < 0).astype(float)

    engulfing = talib.CDLENGULFING(opens, highs, lows, closes)
    features['f11'] = (engulfing > 0).astype(float)
    features['f12'] = (engulfing < 0).astype(float)

    features['f13'] = (talib.CDLPIERCING(opens, highs, lows, closes) != 0).astype(float)
    features['f14'] = (talib.CDLDARKCLOUDCOVER(opens, highs, lows, closes) != 0).astype(float)

    harami = talib.CDLHARAMI(opens, highs, lows, closes)
    features['f15'] = (harami > 0).astype(float)
    features['f16'] = (harami < 0).astype(float)

    # Tweezer patterns
    features['f17'] = ((lows == pd.Series(lows).shift(1)) & (closes > opens)).astype(float)
    features['f18'] = ((highs == pd.Series(highs).shift(1)) & (closes < opens)).astype(float)

    features['f19'] = (talib.CDLMORNINGSTAR(opens, highs, lows, closes) != 0).astype(float)
    features['f20'] = (talib.CDLEVENINGSTAR(opens, highs, lows, closes) != 0).astype(float)
    features['f21'] = (talib.CDL3WHITESOLDIERS(opens, highs, lows, closes) != 0).astype(float)
    features['f22'] = (talib.CDL3BLACKCROWS(opens, highs, lows, closes) != 0).astype(float)

    # Rising/Falling three
    features['f23'] = ((closes > pd.Series(closes).shift(3)) & (closes > opens)).astype(float)
    features['f24'] = ((closes < pd.Series(closes).shift(3)) & (closes < opens)).astype(float)

    # ========== 25-29: PRICE ACTION (5 features) ==========
    features['f25'] = df['close'].pct_change()  # returns
    features['f26'] = np.log(df['close'] / df['close'].shift(1))  # log_returns
    features['f27'] = df['close'].pct_change().rolling(20).std()  # volatility
    features['f28'] = (highs - lows) / closes  # hl_range
    features['f29'] = (closes - lows) / (highs - lows + 1e-10)  # close_position

    # ========== 30-32: RSI (3 features) ==========
    rsi = talib.RSI(closes, timeperiod=14)
    features['f30'] = rsi  # rsi
    features['f31'] = (rsi < 30).astype(float)  # rsi_oversold
    features['f32'] = (rsi > 70).astype(float)  # rsi_overbought

    # ========== 33-37: MACD (5 features) ==========
    macd, signal, hist = talib.MACD(closes, fastperiod=12, slowperiod=26, signalperiod=9)
    features['f33'] = macd  # macd
    features['f34'] = signal  # macd_signal
    features['f35'] = hist  # macd_hist
    features['f36'] = (hist > 0).astype(float)  # macd_positive
    features['f37'] = (macd > signal).astype(float)  # macd_above_signal

    # ========== 38-40: STOCHASTIC (3 features) ==========
    slowk, slowd = talib.STOCH(highs, lows, closes, fastk_period=14, slowk_period=3, slowd_period=3)
    features['f38'] = slowk  # stoch_k
    features['f39'] = slowd  # stoch_d
    features['f40'] = ((slowk > slowd) & (slowk < 80)).astype(float)  # stoch_bullish

    # ========== 41-43: BOLLINGER BANDS (3 features) ==========
    bb_upper, bb_mid, bb_lower = talib.BBANDS(closes, timeperiod=20, nbdevup=2, nbdevdn=2)
    features['f41'] = (closes - bb_lower) / (bb_upper - bb_lower + 1e-10)  # bb_position
    features['f42'] = (closes > bb_upper).astype(float)  # bb_above_upper
    features['f43'] = (closes < bb_lower).astype(float)  # bb_below_lower

    # ========== 44-46: ATR (3 features) ==========
    atr = talib.ATR(highs, lows, closes, timeperiod=14)
    features['f44'] = atr  # atr
    features['f45'] = atr / closes  # atr_pct
    features['f46'] = (features['f45'] > features['f45'].rolling(20).mean()).astype(float)  # high_atr

    # ========== 47-51: ADX (5 features) ==========
    adx = talib.ADX(highs, lows, closes, timeperiod=14)
    plus_di = talib.PLUS_DI(highs, lows, closes, timeperiod=14)
    minus_di = talib.MINUS_DI(highs, lows, closes, timeperiod=14)
    features['f47'] = adx  # adx
    features['f48'] = plus_di  # plus_di
    features['f49'] = minus_di  # minus_di
    features['f50'] = (adx > 25).astype(float)  # strong_trend
    features['f51'] = ((plus_di > minus_di) & (adx > 25)).astype(float)  # strong_uptrend

    # ========== 52-58: ICHIMOKU (7 features) ==========
    # Tenkan-sen (9-period)
    tenkan = (pd.Series(highs).rolling(9).max() + pd.Series(lows).rolling(9).min()) / 2
    # Kijun-sen (26-period)
    kijun = (pd.Series(highs).rolling(26).max() + pd.Series(lows).rolling(26).min()) / 2
    # Senkou Span A (26-period leading)
    senkou_a = (tenkan + kijun) / 2
    # Senkou Span B (52-period)
    senkou_b = (pd.Series(highs).rolling(52).max() + pd.Series(lows).rolling(52).min()) / 2

    features['f52'] = tenkan  # ichimoku_tenkan
    features['f53'] = kijun  # ichimoku_kijun
    features['f54'] = senkou_a  # ichimoku_senkou_a
    features['f55'] = senkou_b  # ichimoku_senkou_b
    features['f56'] = (senkou_a > senkou_b).astype(float)  # ichimoku_cloud_green
    features['f57'] = ((closes > senkou_a.values) & (closes > senkou_b.values)).astype(float)  # ichimoku_above_cloud
    features['f58'] = ((closes < senkou_a.values) & (closes < senkou_b.values)).astype(float)  # ichimoku_below_cloud

    # ========== 59-63: VOLUME METRICS (5 features) ==========
    vol_sma = talib.SMA(volumes, timeperiod=20)
    obv = talib.OBV(closes, volumes)

    features['f59'] = volumes  # volume
    features['f60'] = vol_sma  # vol_sma
    features['f61'] = volumes / (vol_sma + 1e-10)  # vol_ratio
    features['f62'] = obv  # obv
    features['f63'] = (features['f61'] > 1.5).astype(float)  # high_volume

    # ========== 64-72: MOVING AVERAGES (9 features) ==========
    sma20 = talib.SMA(closes, timeperiod=20)
    sma50 = talib.SMA(closes, timeperiod=50)
    sma200 = talib.SMA(closes, timeperiod=200)

    features['f64'] = sma20  # sma20
    features['f65'] = sma50  # sma50
    features['f66'] = sma200  # sma200
    features['f67'] = (closes > sma20).astype(float)  # price_above_sma20
    features['f68'] = (closes > sma50).astype(float)  # price_above_sma50
    features['f69'] = (closes > sma200).astype(float)  # price_above_sma200
    features['f70'] = ((sma50 > sma200) & (pd.Series(sma50).shift(1) <= pd.Series(sma200).shift(1))).astype(float)  # golden_cross
    features['f71'] = ((sma50 < sma200) & (pd.Series(sma50).shift(1) >= pd.Series(sma200).shift(1))).astype(float)  # death_cross
    features['f72'] = ((sma20 > sma50) & (sma50 > sma200)).astype(float)  # sma_alignment

    # ========== 73-75: TREND INDICATORS (3 features) ==========
    features['f73'] = (highs > pd.Series(highs).shift(1)).astype(float)  # higher_high
    features['f74'] = (lows < pd.Series(lows).shift(1)).astype(float)  # lower_low
    features['f75'] = ((closes > sma20) & (sma20 > sma50)).astype(float)  # uptrend

    # Clean NaN/Inf
    features = features.replace([np.inf, -np.inf], np.nan).fillna(0)

    # Verify exactly 76 features
    assert features.shape[1] == 76, f"Expected 76 features, got {features.shape[1]}"

    return features.values

def fetch_multi_coin_data(timeframe='5m', limit_per_coin=1500):
    """Fetch data from multiple coins for general model training"""

    exchange = ccxt.binance({'enableRateLimit': True})
    all_data = []

    for coin in TRAINING_COINS:
        try:
            symbol = f"{coin}/USDT"
            logger.info(f"Fetching {symbol} {timeframe}...")

            ohlcv = exchange.fetch_ohlcv(symbol, timeframe, limit=limit_per_coin)
            df = pd.DataFrame(ohlcv, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume'])
            df['timestamp'] = pd.to_datetime(df['timestamp'], unit='ms')
            df['coin'] = coin

            all_data.append(df)

        except Exception as e:
            logger.warning(f"Could not fetch {coin}: {e}")

    combined_df = pd.concat(all_data, ignore_index=True)
    logger.info(f"Total data points: {len(combined_df)} from {len(all_data)} coins")

    return combined_df

class TransformerBlock(layers.Layer):
    """Transformer block with multi-head attention"""

    def __init__(self, embed_dim, num_heads, ff_dim, dropout=0.1):
        super(TransformerBlock, self).__init__()
        self.att = layers.MultiHeadAttention(num_heads=num_heads, key_dim=embed_dim)
        self.ffn = keras.Sequential([
            layers.Dense(ff_dim, activation="relu"),
            layers.Dense(embed_dim),
        ])
        self.layernorm1 = layers.LayerNormalization(epsilon=1e-6)
        self.layernorm2 = layers.LayerNormalization(epsilon=1e-6)
        self.dropout1 = layers.Dropout(dropout)
        self.dropout2 = layers.Dropout(dropout)

    def call(self, inputs, training=False):
        attn_output = self.att(inputs, inputs)
        attn_output = self.dropout1(attn_output, training=training)
        out1 = self.layernorm1(inputs + attn_output)
        ffn_output = self.ffn(out1)
        ffn_output = self.dropout2(ffn_output, training=training)
        return self.layernorm2(out1 + ffn_output)

def create_transformer_model():
    """
    State-of-the-art Transformer model for crypto prediction
    Uses multi-head attention to capture complex temporal patterns
    """

    # Hyperparameters
    embed_dim = 128  # Embedding dimension
    num_heads = 8    # Number of attention heads
    ff_dim = 256     # Feed-forward dimension

    inputs = layers.Input(shape=(SEQUENCE_LENGTH, NUM_FEATURES))

    # Initial projection to embedding dimension
    x = layers.Dense(embed_dim)(inputs)

    # Positional encoding
    positions = tf.range(start=0, limit=SEQUENCE_LENGTH, delta=1)
    position_embeddings = layers.Embedding(
        input_dim=SEQUENCE_LENGTH, output_dim=embed_dim
    )(positions)
    x = x + position_embeddings

    # Stack 3 Transformer blocks
    x = TransformerBlock(embed_dim, num_heads, ff_dim, dropout=0.15)(x)
    x = TransformerBlock(embed_dim, num_heads, ff_dim, dropout=0.15)(x)
    x = TransformerBlock(embed_dim, num_heads, ff_dim, dropout=0.15)(x)

    # Global average pooling
    x = layers.GlobalAveragePooling1D()(x)

    # Classification head with dropout
    x = layers.Dense(256, activation='relu')(x)
    x = layers.Dropout(0.4)(x)
    x = layers.Dense(128, activation='relu')(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(64, activation='relu')(x)
    x = layers.Dropout(0.2)(x)

    # Output layer
    outputs = layers.Dense(NUM_CLASSES, activation='softmax')(x)

    model = keras.Model(inputs=inputs, outputs=outputs)
    return model

def train_transformer_model(timeframe='5m'):
    """Train Transformer model on combined data with EXACT 76 features"""

    logger.info(f"\n{'='*60}")
    logger.info(f"Training TRANSFORMER model for {timeframe} with 76 features")
    logger.info(f"{'='*60}")

    # MAXIMUM candles per coin based on timeframe
    if timeframe == '5m':
        limit_per_coin = 1500  # Max from Binance for 5m
    elif timeframe == '1d':
        limit_per_coin = 1000  # Max from Binance for daily
    else:
        limit_per_coin = 1000

    # 1. Fetch multi-coin data
    combined_df = fetch_multi_coin_data(timeframe, limit_per_coin=limit_per_coin)

    if combined_df is None or len(combined_df) < 1000:
        logger.error("Not enough combined data")
        return None

    # 2. Extract features
    X_all = build_exact_76_features(combined_df)

    # 3. Create labels (BUY if price goes up > 0.5%, SELL if down < -0.5%, else HOLD)
    future_returns = combined_df['close'].pct_change(10).shift(-10)  # Look 10 candles ahead

    y_all = np.zeros(len(combined_df), dtype=int)
    y_all[future_returns > 0.005] = 2   # BUY
    y_all[future_returns < -0.005] = 0  # SELL
    y_all[(future_returns >= -0.005) & (future_returns <= 0.005)] = 1  # HOLD

    # 4. Create sequences
    sequences = []
    labels = []

    for i in range(len(X_all) - SEQUENCE_LENGTH - 10):
        sequences.append(X_all[i:i+SEQUENCE_LENGTH])
        labels.append(y_all[i + SEQUENCE_LENGTH])

    X = np.array(sequences)
    y = np.array(labels)

    logger.info(f"Total sequences: {len(X)} from {len(TRAINING_COINS)} coins")

    # 5. Check class distribution
    unique, counts = np.unique(y, return_counts=True)
    logger.info(f"Class distribution - SELL: {counts[0]}, HOLD: {counts[1]}, BUY: {counts[2]}")
    for cls, count in zip(unique, counts):
        logger.info(f"  Class {cls}: {count/len(y)*100:.1f}%")

    # 6. Train/test split
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    # 7. Normalize features
    scaler = StandardScaler()
    X_train_flat = X_train.reshape(-1, NUM_FEATURES)
    scaler.fit(X_train_flat)

    X_train_scaled = scaler.transform(X_train.reshape(-1, NUM_FEATURES)).reshape(X_train.shape)
    X_test_scaled = scaler.transform(X_test.reshape(-1, NUM_FEATURES)).reshape(X_test.shape)

    logger.info(f"✅ Scaler mean[0] = {scaler.mean_[0]:.6f} (should be ~0.12 for candle patterns)")

    # 8. Calculate class weights
    class_weights = {}
    total_samples = len(y_train)
    for cls in unique:
        class_count = np.sum(y_train == cls)
        class_weights[cls] = total_samples / (len(unique) * class_count)
    logger.info(f"Class weights: {class_weights}")

    # 9. Create and compile Transformer model
    model = create_transformer_model()

    # Custom loss with label smoothing for TF 2.13 compatibility
    def label_smoothing_loss(y_true, y_pred, smoothing=0.1):
        """Label smoothing loss for better calibration"""
        num_classes = 3
        confidence = 1.0 - smoothing
        smoothing_value = smoothing / (num_classes - 1)

        # One-hot encode y_true
        y_true_one_hot = tf.one_hot(tf.cast(y_true, tf.int32), depth=num_classes)

        # Apply label smoothing
        y_true_smooth = y_true_one_hot * confidence + smoothing_value

        # Categorical crossentropy
        loss = -tf.reduce_sum(y_true_smooth * tf.math.log(y_pred + 1e-7), axis=-1)
        return tf.reduce_mean(loss)

    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=0.0005),
        loss=label_smoothing_loss,
        metrics=['accuracy']
    )

    model.summary()

    # 10. Callbacks
    callbacks = [
        keras.callbacks.EarlyStopping(
            monitor='val_loss',
            patience=15,
            restore_best_weights=True,
            verbose=1
        ),
        keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=7,
            min_lr=1e-7,
            verbose=1
        )
    ]

    # 11. Train
    logger.info("\n🚀 Starting Transformer training...")
    history = model.fit(
        X_train_scaled, y_train,
        validation_data=(X_test_scaled, y_test),
        epochs=200,
        batch_size=64,
        class_weight=class_weights,
        callbacks=callbacks,
        verbose=1
    )

    # 12. Evaluate
    test_loss, test_acc = model.evaluate(X_test_scaled, y_test, verbose=0)
    logger.info(f"\n🎯 Test Accuracy: {test_acc:.4f}")

    # 13. Convert to TFLite
    output_name = f"general_{timeframe}"
    tflite_path = f"assets/ml/{output_name}.tflite"

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS
    ]
    converter._experimental_lower_tensor_list_ops = False
    tflite_model = converter.convert()

    os.makedirs("assets/ml", exist_ok=True)
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)

    model_size_kb = len(tflite_model) / 1024
    logger.info(f"✅ Saved TFLite model: {tflite_path} ({model_size_kb:.2f} KB)")

    # 14. Save scaler as JSON
    scaler_json_path = f"assets/ml/{output_name}_scaler.json"
    scaler_data = {
        'mean': scaler.mean_.tolist(),
        'std': scaler.scale_.tolist(),
    }
    with open(scaler_json_path, 'w') as f:
        json.dump(scaler_data, f, indent=2)
    logger.info(f"✅ Saved scaler: {scaler_json_path}")

    # 15. Save metadata
    metadata = {
        'type': 'GENERAL',
        'architecture': 'TRANSFORMER',
        'timeframe': timeframe,
        'trained_on': TRAINING_COINS,
        'test_accuracy': float(test_acc),
        'train_samples': int(len(X_train)),
        'test_samples': int(len(X_test)),
        'model_size_kb': float(model_size_kb),
        'num_features': NUM_FEATURES,
        'num_classes': NUM_CLASSES,
        'calibration': 'label_smoothing_0.1',
        'scaler_path': f'{output_name}_scaler.json',
        'feature_extraction': 'build_exact_76_features',
        'date': datetime.now().isoformat()
    }

    metadata_path = f"assets/ml/{output_name}_metadata.json"
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f, indent=2)
    logger.info(f"✅ Saved metadata: {metadata_path}")

    logger.info(f"\n✅ TRANSFORMER {timeframe} training COMPLETE!")
    logger.info(f"   Test Accuracy: {test_acc:.4f}")
    logger.info(f"   Model: {tflite_path}")
    logger.info(f"   Scaler: {scaler_json_path}")

    return model, scaler, test_acc

if __name__ == '__main__':
    logger.info("\n🚀 Starting TRANSFORMER model training for general crypto prediction...\n")

    # Train 5m short-term scalping model
    logger.info("=" * 60)
    logger.info("TRAINING SHORT-TERM (5m) TRANSFORMER MODEL")
    logger.info("=" * 60)
    model_5m, scaler_5m, acc_5m = train_transformer_model(timeframe='5m')

    # Train 1d long-term trend model
    logger.info("\n" + "=" * 60)
    logger.info("TRAINING LONG-TERM (1d) TRANSFORMER MODEL")
    logger.info("=" * 60)
    model_1d, scaler_1d, acc_1d = train_transformer_model(timeframe='1d')

    logger.info("\n" + "=" * 60)
    logger.info("🎉 ALL TRANSFORMER MODELS TRAINED SUCCESSFULLY!")
    logger.info("=" * 60)
    logger.info(f"✅ general_5m:  {acc_5m:.4f} accuracy")
    logger.info(f"✅ general_1d:  {acc_1d:.4f} accuracy")
    logger.info("\nTransformer models ready for deployment!")

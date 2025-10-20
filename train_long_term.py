#!/usr/bin/env python3
"""
MODELE GENERALE PENTRU 1D și 7D (Daily și Weekly)
Predicții simple: UP sau DOWN (2 clase în loc de 3)
"""

import os
import json
import numpy as np
import pandas as pd
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
import ccxt
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from datetime import datetime
import joblib
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configurație
SEQUENCE_LENGTH = 60
NUM_FEATURES = 76
NUM_CLASSES = 2  # Doar UP sau DOWN pentru trend pe termen lung

# Monede diverse pentru training
TRAINING_COINS = ['BTC', 'ETH', 'BNB', 'SOL', 'ADA', 'XRP', 'MATIC', 'DOT', 'AVAX', 'LINK']
TIMEFRAMES = {'1d': '1d', '7d': '1d'}  # Folosim daily candles pentru ambele

def fetch_long_term_data(timeframe='1d', limit_per_coin=365):
    """Fetch date pentru perioade lungi (1d/7d predictions)"""

    exchange = ccxt.binance({'enableRateLimit': True})
    all_data = []

    for coin in TRAINING_COINS:
        try:
            symbol = f"{coin}/USDT"
            logger.info(f"Fetching {symbol} daily data...")

            # Fetch daily data
            ohlcv = exchange.fetch_ohlcv(symbol, '1d', limit=limit_per_coin)
            df = pd.DataFrame(ohlcv, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume'])
            df['timestamp'] = pd.to_datetime(df['timestamp'], unit='ms')

            # Adaugă identificator monedă
            df['coin'] = coin

            all_data.append(df)

        except Exception as e:
            logger.warning(f"Could not fetch {coin}: {e}")

    combined_df = pd.concat(all_data, ignore_index=True)
    logger.info(f"Total daily candles: {len(combined_df)} from {len(all_data)} coins")

    return combined_df

def build_76_features_for_daily(df):
    """
    Build 76 features pentru date daily
    Adaptate pentru timeframe mai lung
    """

    features = pd.DataFrame(index=df.index)

    closes = df['close'].values
    opens = df['open'].values
    highs = df['high'].values
    lows = df['low'].values
    volumes = df['volume'].values

    # 1. Price trends (0-15)
    for period in [3, 7, 14, 21, 30]:
        features[f'return_{period}d'] = df['close'].pct_change(period)
        features[f'volatility_{period}d'] = df['close'].pct_change().rolling(period).std()
        features[f'volume_change_{period}d'] = df['volume'].pct_change(period)

    # 2. Moving averages pentru daily (16-30)
    for period in [7, 14, 21, 50, 100, 200]:
        ma = df['close'].rolling(period).mean()
        features[f'ma_{period}_ratio'] = closes / (ma + 1e-10)

        if period <= 50:
            features[f'ma_{period}_slope'] = ma.pct_change(5)  # 5-day slope

    # 3. Support/Resistance pe termen lung (31-40)
    for period in [30, 60, 90]:
        features[f'high_{period}d'] = df['high'].rolling(period).max() / closes
        features[f'low_{period}d'] = closes / (df['low'].rolling(period).min() + 1e-10)
        features[f'range_{period}d'] = (df['high'].rolling(period).max() - df['low'].rolling(period).min()) / closes

    features['52w_high'] = df['high'].rolling(252).max() / closes  # 52-week high

    # 4. RSI pe diferite perioade (41-45)
    for period in [14, 21, 28]:
        delta = df['close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
        rs = gain / (loss + 1e-10)
        features[f'rsi_{period}'] = 100 - (100 / (1 + rs))

    # 5. Volume analysis (46-55)
    features['volume_ma_10'] = df['volume'].rolling(10).mean() / (df['volume'].mean() + 1e-10)
    features['volume_ma_30'] = df['volume'].rolling(30).mean() / (df['volume'].mean() + 1e-10)
    features['volume_trend'] = df['volume'].rolling(30).mean() / (df['volume'].rolling(90).mean() + 1e-10)

    # OBV trend
    obv = (df['volume'] * np.sign(df['close'].diff())).cumsum()
    features['obv_normalized'] = obv / (obv.abs().rolling(30).mean() + 1e-10)
    features['obv_slope'] = obv.pct_change(10)

    # Accumulation/Distribution
    money_flow_mult = ((closes - lows) - (highs - closes)) / (highs - lows + 1e-10)
    money_flow_vol = money_flow_mult * volumes
    features['ad_line'] = money_flow_vol.cumsum() / 1e9
    features['ad_slope'] = features['ad_line'].pct_change(10)

    # 6. Market structure (56-65)
    # Higher timeframe trends
    features['weekly_trend'] = df['close'].pct_change(7)
    features['monthly_trend'] = df['close'].pct_change(30)
    features['quarterly_trend'] = df['close'].pct_change(90)

    # Volatility metrics
    features['atr_14'] = ((df['high'] - df['low']).rolling(14).mean()) / closes
    features['atr_30'] = ((df['high'] - df['low']).rolling(30).mean()) / closes

    # Price patterns
    features['higher_highs'] = (df['high'] > df['high'].shift(1)).rolling(10).sum() / 10
    features['higher_lows'] = (df['low'] > df['low'].shift(1)).rolling(10).sum() / 10
    features['trend_strength'] = abs(df['close'].pct_change(20))

    # 7. Momentum indicators (66-75)
    # Rate of change
    for period in [10, 20, 30]:
        features[f'roc_{period}'] = df['close'].pct_change(period) * 100

    # Commodity Channel Index (use DataFrame columns for rolling operations)
    typical_price_series = (df['high'] + df['low'] + df['close']) / 3
    sma_tp = typical_price_series.rolling(20).mean()
    mad = abs(typical_price_series - sma_tp).rolling(20).mean()
    features['cci'] = (typical_price_series - sma_tp) / (0.015 * mad + 1e-10)

    # Money Flow Index
    raw_money_flow = typical_price_series * df['volume']
    positive_flow = raw_money_flow.where(typical_price_series > typical_price_series.shift(1), 0)
    negative_flow = raw_money_flow.where(typical_price_series < typical_price_series.shift(1), 0)
    money_ratio = positive_flow.rolling(14).sum() / (negative_flow.rolling(14).sum() + 1e-10)
    features['mfi'] = 100 - (100 / (1 + money_ratio))

    # Fill remaining features to get exactly 76
    features['spread'] = (highs - lows) / closes

    # Ensure exactly 76 features
    features = features.fillna(0)
    features = features.replace([np.inf, -np.inf], 0)

    if len(features.columns) > 76:
        features = features.iloc[:, :76]
    elif len(features.columns) < 76:
        for i in range(len(features.columns), 76):
            features[f'feature_{i}'] = 0

    return features.values

def create_trend_model():
    """Model pentru trend prediction (UP/DOWN) cu calibrare corectă"""

    model = keras.Sequential([
        layers.Input(shape=(SEQUENCE_LENGTH, NUM_FEATURES)),

        # Procesare temporală
        layers.Conv1D(64, 5, padding='same'),  # Kernel mai mare pentru patterns pe termen lung
        layers.BatchNormalization(),
        layers.Activation('relu'),
        layers.MaxPooling1D(2),

        layers.Conv1D(32, 5, padding='same'),
        layers.BatchNormalization(),
        layers.Activation('relu'),
        layers.MaxPooling1D(2),

        layers.Conv1D(16, 3, padding='same'),
        layers.BatchNormalization(),
        layers.Activation('relu'),

        # Agregare
        layers.GlobalAveragePooling1D(),

        # Classification pentru UP/DOWN - minimal regularization
        layers.Dense(64, activation='relu'),
        layers.Dropout(0.3),  # Light dropout
        layers.Dense(32, activation='relu'),
        layers.Dropout(0.2),  # Light dropout

        # Output: 2 clase (DOWN, UP)
        layers.Dense(2, activation='softmax')
    ])

    return model

def train_daily_weekly_model(prediction_days=1):
    """
    Antrenează model pentru predicții pe 1 zi sau 7 zile
    prediction_days: 1 pentru daily, 7 pentru weekly
    """

    model_name = '1d' if prediction_days == 1 else '7d'

    logger.info(f"\n{'='*60}")
    logger.info(f"Training GENERAL {model_name} trend model")
    logger.info(f"Prediction horizon: {prediction_days} days")
    logger.info(f"{'='*60}")

    # 1. Fetch data
    combined_df = fetch_long_term_data('1d', limit_per_coin=500)

    if combined_df is None or len(combined_df) < 1000:
        logger.error("Not enough data")
        return None

    # 2. Process each coin
    all_X = []
    all_y = []

    for coin in combined_df['coin'].unique():
        coin_data = combined_df[combined_df['coin'] == coin].copy()
        coin_data = coin_data.sort_values('timestamp').reset_index(drop=True)

        if len(coin_data) < 100:
            continue

        # Build features
        features = build_76_features_for_daily(coin_data)

        if features is None or len(features) < 100:
            continue

        # Create labels pentru trend pe N zile
        future_returns = coin_data['close'].pct_change(prediction_days).shift(-prediction_days)

        # Binary labels: 0 = DOWN, 1 = UP
        labels = (future_returns > 0).astype(int)

        # Create sequences
        for i in range(SEQUENCE_LENGTH, len(features) - prediction_days):
            if not np.isnan(labels.iloc[i]):
                all_X.append(features[i-SEQUENCE_LENGTH:i])
                all_y.append(labels.iloc[i])

    X = np.array(all_X, dtype=np.float32)
    y = np.array(all_y, dtype=np.int32)

    logger.info(f"Total sequences: {len(X)}")
    logger.info(f"UP labels: {(y==1).sum()} ({(y==1).mean():.1%})")
    logger.info(f"DOWN labels: {(y==0).sum()} ({(y==0).mean():.1%})")

    # 3. Normalize
    scaler = StandardScaler()
    X_reshaped = X.reshape(-1, NUM_FEATURES)
    X_scaled = scaler.fit_transform(X_reshaped)
    X = X_scaled.reshape(-1, SEQUENCE_LENGTH, NUM_FEATURES)

    # 4. Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    # One-hot encode
    y_train_cat = keras.utils.to_categorical(y_train, 2)
    y_test_cat = keras.utils.to_categorical(y_test, 2)

    # 5. Build and train
    model = create_trend_model()

    # Label smoothing = 0.1 pentru a preveni overconfidence (100% predictions)
    # Transformă [0, 1] în [0.05, 0.95] → modelul învață să fie mai puțin sigur
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=0.0005),  # Lower LR pentru stability
        loss=keras.losses.CategoricalCrossentropy(label_smoothing=0.1),
        metrics=['accuracy']
    )

    # Class weights pentru balanced training
    class_weight = {0: 1.0, 1: 1.0}
    if (y_train == 1).mean() < 0.4:  # Dacă sunt prea puține UP
        class_weight[1] = 1.5
    elif (y_train == 0).mean() < 0.4:  # Dacă sunt prea puține DOWN
        class_weight[0] = 1.5

    callbacks = [
        keras.callbacks.EarlyStopping(
            monitor='val_accuracy',
            patience=25,
            restore_best_weights=True
        ),
        keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=10,
            min_lr=1e-7
        )
    ]

    history = model.fit(
        X_train, y_train_cat,
        validation_data=(X_test, y_test_cat),
        epochs=100,
        batch_size=32,
        class_weight=class_weight,
        callbacks=callbacks,
        verbose=1
    )

    # 6. Evaluate
    test_loss, test_acc = model.evaluate(X_test, y_test_cat, verbose=0)

    # Confusion matrix pentru debugging
    predictions = model.predict(X_test)
    pred_classes = np.argmax(predictions, axis=1)

    from sklearn.metrics import confusion_matrix, classification_report
    cm = confusion_matrix(y_test, pred_classes)

    logger.info(f"\nTest Accuracy: {test_acc:.2%}")
    logger.info(f"Confusion Matrix:")
    logger.info(f"  DOWN predicted: {cm[0,0]} correct, {cm[0,1]} wrong")
    logger.info(f"  UP predicted: {cm[1,1]} correct, {cm[1,0]} wrong")

    # 7. Convert to TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]

    tflite_model = converter.convert()

    # 8. Save
    os.makedirs('assets/ml', exist_ok=True)

    tflite_path = f'assets/ml/general_{model_name}.tflite'
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)

    # Save scaler in JSON format (for Flutter)
    scaler_json = {
        'mean': scaler.mean_.tolist(),
        'std': scaler.scale_.tolist(),
    }
    scaler_json_path = f'assets/ml/general_{model_name}_scaler.json'
    with open(scaler_json_path, 'w') as f:
        json.dump(scaler_json, f, indent=2)

    # Also save .pkl for Python compatibility
    scaler_pkl_path = f'assets/ml/general_{model_name}_scaler.pkl'
    joblib.dump(scaler, scaler_pkl_path)

    metadata = {
        'type': 'GENERAL_TREND',
        'prediction_horizon': f'{prediction_days} day(s)',
        'timeframe': model_name,
        'trained_on': TRAINING_COINS,
        'test_accuracy': float(test_acc),
        'confusion_matrix': cm.tolist(),
        'train_samples': len(X_train),
        'test_samples': len(X_test),
        'model_size_kb': len(tflite_model) / 1024,
        'num_features': NUM_FEATURES,  # Required by Flutter CryptoMLService
        'num_classes': 2,  # Binary: DOWN (0) vs UP (1)
        'calibration': 'label_smoothing_0.1',  # Label smoothing for probability calibration
        'scaler_path': f'general_{model_name}_scaler.json',  # Path to scaler JSON
        'date': datetime.now().isoformat()
    }

    metadata_path = f'assets/ml/general_{model_name}_metadata.json'
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f, indent=2)

    logger.info(f"\n✅ Model saved: {tflite_path}")
    logger.info(f"📊 Size: {metadata['model_size_kb']:.1f} KB")
    logger.info(f"🎯 Accuracy: {test_acc:.2%}")

    return metadata

def main():
    """Train both 1d and 7d models"""

    results = []

    # Train 1-day prediction model
    metadata_1d = train_daily_weekly_model(prediction_days=1)
    if metadata_1d:
        results.append(metadata_1d)

    # Train 7-day prediction model
    metadata_7d = train_daily_weekly_model(prediction_days=7)
    if metadata_7d:
        results.append(metadata_7d)

    # Summary
    if results:
        logger.info(f"\n{'='*60}")
        logger.info(f"✅ TREND MODELS COMPLETE")
        logger.info(f"Models trained: {len(results)}")

        for r in results:
            logger.info(f"  - general_{r['timeframe']}.tflite: {r['test_accuracy']:.2%} accuracy")
            logger.info(f"    Predicts: {r['prediction_horizon']} trend (UP/DOWN)")

if __name__ == '__main__':
    main()

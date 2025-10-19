#!/usr/bin/env python3
"""
ANTRENARE MODELE GENERALE pentru ORICE CRYPTO
Antrenează pe date combinate de la mai multe monede
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
NUM_CLASSES = 3

# Monede pentru training general (diverse)
TRAINING_COINS = ['BTC', 'ETH', 'BNB', 'SOL', 'ADA', 'DOGE', 'XRP', 'MATIC']
TIMEFRAMES = ['5m', '15m', '1h']

def fetch_multi_coin_data(timeframe='15m', limit_per_coin=1500):
    """Fetch data de la mai multe monede pentru training general"""

    exchange = ccxt.binance({'enableRateLimit': True})
    all_data = []

    for coin in TRAINING_COINS:
        try:
            symbol = f"{coin}/USDT"
            logger.info(f"Fetching {symbol} {timeframe}...")

            ohlcv = exchange.fetch_ohlcv(symbol, timeframe, limit=limit_per_coin)
            df = pd.DataFrame(ohlcv, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume'])
            
            # Adaugă coin identifier
            df['coin'] = coin
            
            # Normalizează prețurile (important pentru general model)
            df['price_normalized'] = df['close'] / df['close'].iloc[0]
            
            all_data.append(df)
            
        except Exception as e:
            logger.warning(f"Could not fetch {coin}: {e}")
    
    # Combine toate datele
    combined_df = pd.concat(all_data, ignore_index=True)
    logger.info(f"Total data points: {len(combined_df)} from {len(all_data)} coins")
    
    return combined_df

def build_76_features_normalized(df):
    """
    Build 76 features cu normalizare pentru general model
    Features sunt mai generice și normalizate pentru a funcționa pe orice crypto
    """
    
    features = pd.DataFrame(index=df.index)
    
    # Folosim prețuri normalizate pentru features
    closes = df['close'].values
    opens = df['open'].values
    highs = df['high'].values
    lows = df['low'].values
    volumes = df['volume'].values
    
    # 1. Price ratios (0-9) - mai generice decât prețuri absolute
    features['close_open_ratio'] = closes / (opens + 1e-10)
    features['high_low_ratio'] = highs / (lows + 1e-10)
    features['close_high_ratio'] = closes / (highs + 1e-10)
    features['close_low_ratio'] = closes / (lows + 1e-10)
    features['volume_ratio'] = volumes / (volumes.mean() + 1e-10)
    
    # Returns pe diferite perioade
    for i in [1, 3, 5, 7, 10]:
        features[f'return_{i}'] = df['close'].pct_change(i)
    
    # 2. Moving averages ratios (10-25)
    for period in [5, 10, 20, 50]:
        ma = df['close'].rolling(period).mean()
        features[f'ma_{period}_ratio'] = closes / (ma + 1e-10)
        features[f'ma_{period}_slope'] = ma.pct_change()
    
    # 3. Volatility metrics (26-35)
    for period in [5, 10, 20]:
        features[f'volatility_{period}'] = df['close'].pct_change().rolling(period).std()
        features[f'range_{period}'] = (df['high'] - df['low']).rolling(period).mean() / df['close']
    
    features['atr_ratio'] = ((df['high'] - df['low']).rolling(14).mean()) / df['close']
    
    # 4. Volume indicators (36-45)
    features['volume_sma_5'] = volumes / df['volume'].rolling(5).mean()
    features['volume_sma_10'] = volumes / df['volume'].rolling(10).mean()
    features['volume_sma_20'] = volumes / df['volume'].rolling(20).mean()
    features['volume_std'] = df['volume'].rolling(20).std() / (df['volume'].mean() + 1e-10)
    
    # OBV normalized
    obv = (df['volume'] * np.sign(df['close'].diff())).cumsum()
    features['obv_normalized'] = obv / (obv.abs().mean() + 1e-10)
    
    # 5. RSI pe diferite perioade (46-50)
    for period in [7, 14, 21, 28]:
        delta = df['close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
        rs = gain / (loss + 1e-10)
        features[f'rsi_{period}'] = 100 - (100 / (1 + rs))
        
    features['rsi_oversold'] = (features['rsi_14'] < 30).astype(float)
    
    # 6. Pattern detection (51-65)
    # Higher highs/lows
    features['higher_high'] = (highs > pd.Series(highs).shift(1)).astype(float)
    features['lower_low'] = (lows < pd.Series(lows).shift(1)).astype(float)
    features['higher_low'] = (lows > pd.Series(lows).shift(1)).astype(float)
    features['lower_high'] = (highs < pd.Series(highs).shift(1)).astype(float)
    
    # Candle patterns
    body = abs(closes - opens)
    features['body_ratio'] = body / (highs - lows + 1e-10)
    features['upper_shadow'] = (highs - np.maximum(closes, opens)) / (body + 1e-10)
    features['lower_shadow'] = (np.minimum(closes, opens) - lows) / (body + 1e-10)
    features['is_green'] = (closes > opens).astype(float)
    features['is_doji'] = (body / (highs - lows + 1e-10) < 0.1).astype(float)
    
    # Consecutive patterns
    for i in range(1, 6):
        features[f'green_streak_{i}'] = (df['close'] > df['open']).rolling(i).sum() / i
    
    # 7. Support/Resistance levels (66-70)
    for period in [20, 50]:
        features[f'distance_from_high_{period}'] = (df['high'].rolling(period).max() - closes) / closes
        features[f'distance_from_low_{period}'] = (closes - df['low'].rolling(period).min()) / closes
    
    features['pivot_point'] = (highs + lows + closes) / 3
    features['pivot_ratio'] = closes / (features['pivot_point'] + 1e-10)
    
    # 8. Fill remaining to get exactly 76 (71-75)
    # Market microstructure
    features['spread'] = (df['high'] - df['low']) / df['close']
    features['typical_price'] = (highs + lows + closes) / 3
    features['weighted_close'] = (highs + lows + 2 * closes) / 4
    features['price_position'] = (closes - lows) / (highs - lows + 1e-10)
    features['volume_price_trend'] = (df['volume'] * df['close'].pct_change()).cumsum() / 1e6
    
    # Ensure exactly 76 features
    features = features.fillna(0)
    features = features.replace([np.inf, -np.inf], 0)
    
    # Select first 76 columns
    if len(features.columns) > 76:
        features = features.iloc[:, :76]
    elif len(features.columns) < 76:
        # Add dummy features if needed
        for i in range(len(features.columns), 76):
            features[f'feature_{i}'] = 0
    
    return features.values

def create_general_model():
    """Model optimizat pentru general trading"""
    
    model = keras.Sequential([
        layers.Input(shape=(SEQUENCE_LENGTH, NUM_FEATURES)),
        
        # Feature extraction layers
        layers.Conv1D(128, 3, padding='same'),
        layers.BatchNormalization(),
        layers.Activation('relu'),
        layers.MaxPooling1D(2),
        
        layers.Conv1D(64, 3, padding='same'),
        layers.BatchNormalization(),
        layers.Activation('relu'),
        layers.MaxPooling1D(2),
        
        layers.Conv1D(32, 3, padding='same'),
        layers.BatchNormalization(),
        layers.Activation('relu'),
        
        # Global features
        layers.GlobalAveragePooling1D(),
        
        # Classification layers with higher dropout to prevent overfitting
        layers.Dense(128, activation='relu'),
        layers.Dropout(0.5),
        layers.Dense(64, activation='relu'),
        layers.Dropout(0.4),
        layers.Dense(32, activation='relu'),
        layers.Dropout(0.3),

        # Output
        layers.Dense(NUM_CLASSES, activation='softmax')
    ])
    
    return model

def train_general_model(timeframe='15m'):
    """Antrenează model general pe date combinate"""
    
    logger.info(f"\n{'='*60}")
    logger.info(f"Training GENERAL model for {timeframe}")
    logger.info(f"{'='*60}")
    
    # 1. Fetch multi-coin data
    combined_df = fetch_multi_coin_data(timeframe, limit_per_coin=1000)
    
    if combined_df is None or len(combined_df) < 1000:
        logger.error("Not enough combined data")
        return None
    
    # 2. Process each coin's data
    all_X = []
    all_y = []
    
    for coin in combined_df['coin'].unique():
        coin_data = combined_df[combined_df['coin'] == coin].copy()
        coin_data = coin_data.sort_values('timestamp').reset_index(drop=True)
        
        if len(coin_data) < 100:
            continue
        
        # Build features
        features = build_76_features_normalized(coin_data)
        
        if features is None or len(features) < 100:
            continue
        
        # Create labels using percentile-based approach for PERFECT 33/33/33 distribution
        returns = coin_data['close'].pct_change(3).shift(-3)

        # Calculate percentiles (bottom 33% = SELL, top 33% = BUY, middle = HOLD)
        sell_threshold = np.nanpercentile(returns, 33)
        buy_threshold = np.nanpercentile(returns, 67)

        labels = np.ones(len(returns))  # Default HOLD
        labels[returns < sell_threshold] = 0  # SELL (bottom 33%)
        labels[returns > buy_threshold] = 2   # BUY (top 33%)
        
        # Create sequences
        for i in range(SEQUENCE_LENGTH, len(features) - 3):
            all_X.append(features[i-SEQUENCE_LENGTH:i])
            all_y.append(labels[i])
    
    X = np.array(all_X, dtype=np.float32)
    y = np.array(all_y, dtype=np.int32)

    logger.info(f"Total sequences: {len(X)} from {len(combined_df['coin'].unique())} coins")

    # Check class distribution
    unique, counts = np.unique(y, return_counts=True)
    class_dist = dict(zip(unique, counts))
    logger.info(f"Class distribution - SELL: {class_dist.get(0, 0)}, HOLD: {class_dist.get(1, 0)}, BUY: {class_dist.get(2, 0)}")
    for cls in [0, 1, 2]:
        pct = (class_dist.get(cls, 0) / len(y)) * 100
        logger.info(f"  Class {cls}: {pct:.1f}%")

    # 3. Normalize globally
    scaler = StandardScaler()
    X_reshaped = X.reshape(-1, NUM_FEATURES)
    X_scaled = scaler.fit_transform(X_reshaped)
    X = X_scaled.reshape(-1, SEQUENCE_LENGTH, NUM_FEATURES)
    
    # 4. Train/test split
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    # Compute class weights to handle imbalance
    from sklearn.utils.class_weight import compute_class_weight
    class_weights_array = compute_class_weight('balanced', classes=np.unique(y_train), y=y_train)
    class_weights = {i: class_weights_array[i] for i in range(len(class_weights_array))}
    logger.info(f"Class weights: {class_weights}")

    # One-hot encode
    y_train_cat = keras.utils.to_categorical(y_train, NUM_CLASSES)
    y_test_cat = keras.utils.to_categorical(y_test, NUM_CLASSES)
    
    # 5. Build and train model
    model = create_general_model()
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=0.001),
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )
    
    # Callbacks - reduced patience to prevent overfitting
    callbacks = [
        keras.callbacks.EarlyStopping(
            monitor='val_loss',
            patience=10,
            restore_best_weights=True
        ),
        keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=5,
            min_lr=1e-6
        )
    ]

    # Train with class weights
    history = model.fit(
        X_train, y_train_cat,
        validation_data=(X_test, y_test_cat),
        epochs=100,
        batch_size=64,
        class_weight=class_weights,
        callbacks=callbacks,
        verbose=1
    )
    
    # 6. Evaluate
    test_loss, test_acc = model.evaluate(X_test, y_test_cat, verbose=0)
    logger.info(f"Test Accuracy: {test_acc:.2%}")
    
    # 7. Convert to TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
    
    tflite_model = converter.convert()
    
    # 8. Save
    os.makedirs('assets/ml', exist_ok=True)
    
    # Save TFLite
    tflite_path = f'assets/ml/general_{timeframe}.tflite'
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
    
    # Save scaler
    scaler_path = f'assets/ml/general_{timeframe}_scaler.pkl'
    joblib.dump(scaler, scaler_path)
    
    # Save metadata
    metadata = {
        'type': 'GENERAL',
        'timeframe': timeframe,
        'trained_on': TRAINING_COINS,
        'test_accuracy': float(test_acc),
        'train_samples': len(X_train),
        'test_samples': len(X_test),
        'model_size_kb': len(tflite_model) / 1024,
        'date': datetime.now().isoformat()
    }
    
    metadata_path = f'assets/ml/general_{timeframe}_metadata.json'
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f, indent=2)
    
    logger.info(f"✅ General model saved: {tflite_path}")
    logger.info(f"📊 Size: {metadata['model_size_kb']:.1f} KB")
    logger.info(f"🎯 Accuracy: {test_acc:.2%}")
    
    return metadata

def main():
    """Antrenează toate modelele generale"""
    
    results = []
    
    for timeframe in TIMEFRAMES:
        try:
            metadata = train_general_model(timeframe)
            if metadata:
                results.append(metadata)
        except Exception as e:
            logger.error(f"Error training general {timeframe}: {e}")
    
    # Summary
    if results:
        avg_acc = np.mean([r['test_accuracy'] for r in results])
        logger.info(f"\n{'='*60}")
        logger.info(f"✅ GENERAL MODELS COMPLETE")
        logger.info(f"Models trained: {len(results)}")
        logger.info(f"Average accuracy: {avg_acc:.2%}")
        
        for r in results:
            logger.info(f"  - general_{r['timeframe']}.tflite: {r['test_accuracy']:.2%} accuracy")

if __name__ == '__main__':
    main()

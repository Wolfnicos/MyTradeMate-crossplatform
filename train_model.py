#!/usr/bin/env python3
"""
Training script pentru modele ML compatibile iOS
Rulează în Docker cu TensorFlow 2.13
"""

import tensorflow as tf
import numpy as np
import sys
import os

# Verifică versiunea TensorFlow
print(f"🔧 TensorFlow version: {tf.__version__}")

def build_model():
    """Model CNN 2D - EXACT arhitectura ta"""
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(60, 76)),
        tf.keras.layers.Reshape((60, 76, 1)),

        # Conv Block 1
        tf.keras.layers.Conv2D(32, (3, 3), activation='relu', padding='same'),
        tf.keras.layers.MaxPooling2D((2, 2)),
        tf.keras.layers.Dropout(0.2),

        # Conv Block 2
        tf.keras.layers.Conv2D(64, (3, 3), activation='relu', padding='same'),
        tf.keras.layers.MaxPooling2D((2, 2)),
        tf.keras.layers.Dropout(0.3),

        # Conv Block 3
        tf.keras.layers.Conv2D(128, (3, 3), activation='relu', padding='same'),
        tf.keras.layers.GlobalAveragePooling2D(),

        # Dense layers
        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.Dropout(0.4),
        tf.keras.layers.Dense(3, activation='softmax')  # SELL, HOLD, BUY
    ])

    return model

def train_model(coin, timeframe, X_train, y_train, X_val, y_val):
    """Antrenează un model pentru o monedă și timeframe"""
    print(f"\n{'='*60}")
    print(f"🚀 Training {coin} {timeframe}")
    print(f"{'='*60}")

    # Build model
    model = build_model()
    model.compile(
        optimizer='adam',
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )

    # Training
    print(f"\n📊 Training data shape: {X_train.shape}")
    print(f"📊 Labels shape: {y_train.shape}")

    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=50,
        batch_size=32,
        callbacks=[
            tf.keras.callbacks.EarlyStopping(patience=10, restore_best_weights=True),
            tf.keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=5)
        ],
        verbose=1
    )

    # Evaluate
    val_loss, val_acc = model.evaluate(X_val, y_val)
    print(f"\n✅ Validation accuracy: {val_acc:.4f}")

    return model, val_acc

def convert_to_tflite(model, output_path):
    """Convertește modelul la TFLite compatibil iOS"""
    print(f"\n🔄 Converting to TFLite...")

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    tflite_model = converter.convert()

    # Salvează
    with open(output_path, 'wb') as f:
        f.write(tflite_model)

    size_mb = len(tflite_model) / 1024 / 1024
    print(f"✅ Model saved: {output_path} ({size_mb:.2f} MB)")

    # Verifică
    interpreter = tf.lite.Interpreter(model_path=output_path)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print(f"✅ Model verified!")
    print(f"   Input shape: {input_details[0]['shape']}")
    print(f"   Output shape: {output_details[0]['shape']}")

    return True

def main():
    """Main training loop - ALL 18 models with REAL DATA"""
    print("="*60)
    print("🚀 ML Model Training for iOS - ALL 18 MODELS")
    print(f"   TensorFlow: {tf.__version__}")
    print("="*60)
    print("\n📊 Using REAL data from Binance!\n")

    coins = ['btc', 'eth', 'bnb', 'sol', 'trump', 'wlfi']
    timeframes = ['5m', '15m', '1h']

    os.makedirs('/workspace/output', exist_ok=True)

    success_count = 0
    fail_count = 0

    for coin in coins:
        for timeframe in timeframes:
            try:
                print(f"\n{'='*60}")
                print(f"🚀 Training {coin.upper()} {timeframe}")
                print(f"{'='*60}")

                # Load REAL data
                data_path = '/workspace/data'
                X_train = np.load(f'{data_path}/{coin}_{timeframe}_X_train.npy')
                y_train = np.load(f'{data_path}/{coin}_{timeframe}_y_train.npy')
                X_val = np.load(f'{data_path}/{coin}_{timeframe}_X_val.npy')
                y_val = np.load(f'{data_path}/{coin}_{timeframe}_y_val.npy')

                print(f"📦 Loaded {len(X_train)} training samples, {len(X_val)} validation samples")

                # Train
                model, accuracy = train_model(coin, timeframe, X_train, y_train, X_val, y_val)

                # Convert to TFLite
                output_path = f'/workspace/output/{coin}_{timeframe}_model.tflite'
                convert_to_tflite(model, output_path)

                print(f"✅ {coin.upper()} {timeframe} COMPLETE! (Val Acc: {accuracy:.4f})\n")
                success_count += 1

            except Exception as e:
                print(f"❌ {coin.upper()} {timeframe} FAILED: {e}\n")
                fail_count += 1
                continue

    print("\n" + "="*60)
    print("✅ TRAINING COMPLETE!")
    print("="*60)
    print(f"\nSuccessful: {success_count}/18")
    print(f"Failed: {fail_count}/18")
    print(f"\nModels saved to: /workspace/output/")
    print(f"Copy to: assets/ml/\n")

if __name__ == '__main__':
    main()

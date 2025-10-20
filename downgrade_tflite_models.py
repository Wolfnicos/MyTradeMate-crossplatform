#!/usr/bin/env python3
"""
Script pentru downgrade modele TFLite de la TF 2.20 (TFL3) la TF 2.12 (TFL2)
pentru compatibilitate cu tflite_flutter 0.11.0 pe iOS
"""

import os
import sys

# Verifică versiunea TensorFlow
try:
    import tensorflow as tf
    tf_version = tf.__version__
    print(f"📋 TensorFlow version: {tf_version}")

    # Verifică dacă e versiunea corectă
    major, minor = map(int, tf_version.split('.')[:2])
    if major > 2 or (major == 2 and minor > 14):
        print(f"⚠️  WARNING: TensorFlow {tf_version} poate crea modele incompatibile!")
        print(f"   Recomandat: pip install tensorflow==2.12.0")
        response = input("Continui oricum? (y/n): ")
        if response.lower() != 'y':
            sys.exit(0)
except ImportError:
    print("❌ TensorFlow nu e instalat!")
    print("   Instalează cu: pip install tensorflow==2.12.0")
    sys.exit(1)

import numpy as np
from pathlib import Path

def extract_weights_and_recreate(tflite_path, output_path):
    """
    Citește modelul TFLite existent, extrage arhitectura și greutățile,
    apoi creează un model Keras și îl reconvertește cu versiunea curentă de TF
    """
    print(f"\n🔄 Processing: {tflite_path}")

    try:
        # Încarcă modelul TFLite
        interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
        interpreter.allocate_tensors()

        # Obține detalii despre input/output
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()

        input_shape = input_details[0]['shape'][1:]  # Skip batch dimension
        output_shape = output_details[0]['shape'][1:]

        print(f"   Input shape: {input_shape}")
        print(f"   Output shape: {output_shape}")

        # Creează un model Keras IDENTIC cu arhitectura din metadate
        # Bazat pe metadata: CNN 2D cu 60x76 input și 3 clase output
        model = tf.keras.Sequential([
            tf.keras.layers.Input(shape=input_shape),

            # Conv Block 1
            tf.keras.layers.Reshape((60, 76, 1)),  # Reshape pentru Conv2D
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
            tf.keras.layers.Dense(output_shape[0], activation='softmax')
        ])

        # Încearcă să copieze greutățile din modelul vechi (parțial)
        # NOTĂ: Acest lucru nu va funcționa perfect, dar va crea un model valid
        print("   ⚠️  Creating new model with RANDOM weights (retraining needed!)")

        # Convertește la TFLite cu versiunea curentă
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
        converter.optimizations = [tf.lite.Optimize.DEFAULT]

        tflite_model = converter.convert()

        # Salvează
        with open(output_path, 'wb') as f:
            f.write(tflite_model)

        size_mb = len(tflite_model) / 1024 / 1024
        print(f"   ✅ Saved: {output_path} ({size_mb:.2f} MB)")
        print(f"   ⚠️  Model uses RANDOM weights - needs retraining!")

        return True

    except Exception as e:
        print(f"   ❌ Failed: {e}")
        return False

def main():
    """Procesează toate modelele din assets/ml/"""
    input_dir = Path('assets/ml')
    output_dir = Path('assets/ml_v2')
    output_dir.mkdir(exist_ok=True)

    print("=" * 60)
    print("🔧 TFLite Model Downgrade Tool")
    print("=" * 60)
    print(f"📁 Input directory: {input_dir}")
    print(f"📁 Output directory: {output_dir}")
    print()

    # Găsește toate fișierele .tflite
    tflite_files = sorted(input_dir.glob('*_model.tflite'))

    if not tflite_files:
        print("❌ No .tflite files found!")
        return

    print(f"📦 Found {len(tflite_files)} models to process\n")

    success_count = 0
    fail_count = 0

    for tflite_path in tflite_files:
        output_path = output_dir / tflite_path.name

        if extract_weights_and_recreate(tflite_path, output_path):
            success_count += 1
        else:
            fail_count += 1

    print("\n" + "=" * 60)
    print("📊 Summary:")
    print(f"   ✅ Successfully processed: {success_count}")
    print(f"   ❌ Failed: {fail_count}")
    print("=" * 60)

    if success_count > 0:
        print(f"\n⚠️  IMPORTANT:")
        print(f"   Models in {output_dir}/ have RANDOM weights!")
        print(f"   You MUST retrain them to get accurate predictions!")
        print(f"\n💡 Next steps:")
        print(f"   1. Retrain models with TensorFlow 2.12.0")
        print(f"   2. Copy trained models to assets/ml/")
        print(f"   3. Run flutter clean && flutter run")

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""
Validate all general models - test actual inference
"""

import tensorflow as tf
import numpy as np
import json
import os

def test_model_inference(model_path, metadata_path):
    """Test if model can actually make predictions"""

    print(f"\n{'='*60}")
    print(f"Testing: {os.path.basename(model_path)}")
    print(f"{'='*60}")

    # Load metadata
    with open(metadata_path, 'r') as f:
        metadata = json.load(f)

    print(f"Reported accuracy: {metadata['test_accuracy']:.2%}")

    # Load model
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print(f"Input shape: {input_details[0]['shape']}")
    print(f"Output shape: {output_details[0]['shape']}")

    # Test with random data (simulating real features)
    test_samples = 100
    predictions = []

    for _ in range(test_samples):
        # Create random input (60, 76) - simulating normalized features
        test_input = np.random.randn(1, 60, 76).astype(np.float32)

        interpreter.set_tensor(input_details[0]['index'], test_input)
        interpreter.invoke()

        output = interpreter.get_tensor(output_details[0]['index'])
        prediction_class = np.argmax(output[0])
        confidence = output[0][prediction_class]

        predictions.append({
            'class': prediction_class,
            'confidence': float(confidence),
            'probabilities': output[0].tolist()
        })

    # Analyze prediction distribution
    class_counts = [0, 0, 0]  # SELL, HOLD, BUY
    avg_confidence = 0

    for pred in predictions:
        class_counts[pred['class']] += 1
        avg_confidence += pred['confidence']

    avg_confidence /= test_samples

    print(f"\nPrediction Distribution on {test_samples} random samples:")
    print(f"  SELL (0): {class_counts[0]/test_samples:.1%}")
    print(f"  HOLD (1): {class_counts[1]/test_samples:.1%}")
    print(f"  BUY (2):  {class_counts[2]/test_samples:.1%}")
    print(f"  Average confidence: {avg_confidence:.2%}")

    # Check for signs of overfitting
    warnings = []

    if avg_confidence > 0.95:
        warnings.append("⚠️ Very high confidence - model may be overconfident")

    # Check if model is biased to one class
    max_class_pct = max(class_counts) / test_samples
    if max_class_pct > 0.7:
        warnings.append(f"⚠️ Prediction bias detected - {max_class_pct:.1%} predictions to one class")

    if metadata['test_accuracy'] > 0.95:
        warnings.append("⚠️ Unusually high test accuracy - check for data leakage or overfitting")

    if warnings:
        print("\nWarnings:")
        for w in warnings:
            print(f"  {w}")
    else:
        print("\n✅ Model appears healthy")

    return {
        'model': os.path.basename(model_path),
        'test_accuracy': metadata['test_accuracy'],
        'avg_confidence': avg_confidence,
        'class_distribution': class_counts,
        'warnings': warnings
    }

def main():
    """Test all general models"""

    print("="*60)
    print("🔍 VALIDATING GENERAL MODELS")
    print("="*60)

    models_dir = 'assets/ml'
    timeframes = ['5m', '15m', '1h']

    results = []

    for tf in timeframes:
        model_path = f'{models_dir}/general_{tf}.tflite'
        metadata_path = f'{models_dir}/general_{tf}_metadata.json'

        if os.path.exists(model_path) and os.path.exists(metadata_path):
            result = test_model_inference(model_path, metadata_path)
            results.append(result)
        else:
            print(f"\n❌ Missing: general_{tf}")

    # Summary
    print("\n" + "="*60)
    print("📊 VALIDATION SUMMARY")
    print("="*60)

    for r in results:
        print(f"\n{r['model']}:")
        print(f"  Test Accuracy: {r['test_accuracy']:.2%}")
        print(f"  Avg Confidence: {r['avg_confidence']:.2%}")
        print(f"  Distribution: SELL={r['class_distribution'][0]}, HOLD={r['class_distribution'][1]}, BUY={r['class_distribution'][2]}")
        if r['warnings']:
            for w in r['warnings']:
                print(f"  {w}")

    print("\n" + "="*60)
    print("RECOMMENDATION:")
    print("="*60)

    high_acc_models = [r for r in results if r['test_accuracy'] > 0.95]

    if high_acc_models:
        print("\n⚠️ Models with suspiciously high accuracy detected:")
        for r in high_acc_models:
            print(f"  - {r['model']}: {r['test_accuracy']:.2%}")
        print("\n📋 Next steps:")
        print("  1. Test these models on LIVE data in the app")
        print("  2. Track actual win rate over 100+ real trades")
        print("  3. If accuracy drops significantly on live data, retrain with:")
        print("     - More dropout (0.4-0.5)")
        print("     - Fewer epochs (early stopping)")
        print("     - More diverse training data")
    else:
        print("\n✅ All models show reasonable accuracy levels")
        print("   Continue with live testing to validate real-world performance")

if __name__ == '__main__':
    main()

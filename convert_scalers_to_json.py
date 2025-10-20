#!/usr/bin/env python3
"""
Convert existing .pkl scalers to .json for Flutter to load
"""
import os
import json
import joblib
import glob

def convert_scalers():
    # Find all .pkl scaler files
    pkl_files = glob.glob('assets/ml/*_scaler.pkl')

    print(f"Found {len(pkl_files)} scaler .pkl files")

    for pkl_path in pkl_files:
        try:
            # Load scaler from .pkl
            scaler = joblib.load(pkl_path)

            # Extract mean and std
            scaler_json = {
                'mean': scaler.mean_.tolist(),
                'std': scaler.scale_.tolist(),
            }

            # Save as JSON
            json_path = pkl_path.replace('_scaler.pkl', '_scaler.json')
            with open(json_path, 'w') as f:
                json.dump(scaler_json, f, indent=2)

            print(f"✅ Converted: {os.path.basename(pkl_path)} → {os.path.basename(json_path)}")

        except Exception as e:
            print(f"❌ Failed to convert {pkl_path}: {e}")

if __name__ == '__main__':
    convert_scalers()
    print("\nDone!")

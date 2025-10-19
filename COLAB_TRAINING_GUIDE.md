# 🚀 Antrenare Modele ML folosind Google Colab (GRATUIT)

## De ce Google Colab?

✅ **GRATUIT** - nu costă nimic!
✅ **TensorFlow 2.12 deja instalat** - nu trebuie să instalezi nimic
✅ **GPU gratuit** - antrenare 10x mai rapidă
✅ **Funcționează pe orice Mac** - inclusiv Apple Silicon

---

## 📋 Pași Completi

### 1. Deschide Google Colab

Mergi la: https://colab.research.google.com/

### 2. Creează un Notebook Nou

Click pe **"New Notebook"**

### 3. Verifică Versiunea TensorFlow

Rulează în prima celulă:

```python
import tensorflow as tf
print(f"TensorFlow version: {tf.__version__}")
```

Ar trebui să vezi `2.15.x` sau similar (perfect pentru iOS!)

### 4. Downgrade la TensorFlow 2.12 (dacă e nevoie)

Dacă versiunea e prea nouă, downgrade-ează:

```python
!pip install tensorflow==2.12.0
```

Apoi **Runtime → Restart Runtime** și verifică din nou versiunea.

### 5. Upload Date de Antrenament

Folosește butonul 📁 din stânga pentru a upload-a:
- `X_train.npy` - datele de antrenament (shape: [N, 60, 76])
- `y_train.npy` - labels (shape: [N, 3], one-hot encoded)
- `X_val.npy` - date validare
- `y_val.npy` - labels validare

SAU mai simplu - folosește Google Drive:

```python
from google.colab import drive
drive.mount('/content/drive')

# Apoi citește datele din Drive
import numpy as np
X_train = np.load('/content/drive/MyDrive/ML_Data/X_train.npy')
y_train = np.load('/content/drive/MyDrive/ML_Data/y_train.npy')
```

### 6. Antrenează Modelul

Copiază acest cod **EXACT** (arhitectura ta CNN 2D):

```python
import tensorflow as tf
import numpy as np

# Verifică versiunea (IMPORTANT!)
print(f"TensorFlow version: {tf.__version__}")
assert tf.__version__.startswith('2.12'), f"Wrong version: {tf.__version__}"

def build_model():
    """Model CNN 2D compatibil iOS - EXACT arhitectura ta"""
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(60, 76)),

        # Reshape pentru Conv2D
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

# Build și compile
model = build_model()
model.compile(
    optimizer='adam',
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

# Summary
model.summary()

# Training
history = model.fit(
    X_train, y_train,
    validation_data=(X_val, y_val),
    epochs=50,
    batch_size=32,
    callbacks=[
        tf.keras.callbacks.EarlyStopping(patience=10, restore_best_weights=True),
        tf.keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=5)
    ]
)

# Evaluate
test_loss, test_acc = model.evaluate(X_test, y_test)
print(f'\n✅ Test accuracy: {test_acc:.4f}')
```

### 7. Convertește la TFLite

```python
# Convertește la TFLite cu TF 2.12
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
converter.optimizations = [tf.lite.Optimize.DEFAULT]

tflite_model = converter.convert()

# Salvează
coin = 'btc'
timeframe = '5m'
filename = f'{coin}_{timeframe}_model.tflite'

with open(filename, 'wb') as f:
    f.write(tflite_model)

size_mb = len(tflite_model) / 1024 / 1024
print(f'\n✅ Model saved: {filename} ({size_mb:.2f} MB)')

# Verifică că funcționează
interpreter = tf.lite.Interpreter(model_path=filename)
interpreter.allocate_tensors()
print(f'✅ Model verified - ready for iOS!')
```

### 8. Download Modelul

Click pe 📁 din stânga → click dreapta pe `btc_5m_model.tflite` → **Download**

### 9. Repetă pentru Toate Modelele

Trebuie să antrenezi 18 modele:
- 6 monede: btc, eth, bnb, sol, trump, wlfi
- 3 timeframes: 5m, 15m, 1h

**TIP:** Folosește un loop:

```python
coins = ['btc', 'eth', 'bnb', 'sol', 'trump', 'wlfi']
timeframes = ['5m', '15m', '1h']

for coin in coins:
    for tf in timeframes:
        print(f'\n{"="*60}')
        print(f'Training {coin} {tf}...')
        print("="*60)

        # Load data specific pentru coin și timeframe
        X_train = np.load(f'/content/drive/MyDrive/ML_Data/{coin}_{tf}_X_train.npy')
        y_train = np.load(f'/content/drive/MyDrive/ML_Data/{coin}_{tf}_y_train.npy')

        # Build model
        model = build_model()
        model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])

        # Train
        model.fit(X_train, y_train, epochs=50, batch_size=32)

        # Convert
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
        tflite_model = converter.convert()

        # Save
        filename = f'{coin}_{tf}_model.tflite'
        with open(filename, 'wb') as f:
            f.write(tflite_model)

        print(f'✅ {filename} saved!')
```

### 10. Download Toate Modelele

După training, download-ează toate cele 18 fișiere `.tflite` și copiază-le în `assets/ml/`

### 11. Rebuild Flutter App

```bash
flutter clean
flutter run -d 00008150-00084C1622C0401C
```

---

## 🎯 Avantaje Google Colab

✅ **Nu trebuie să instalezi nimic pe Mac**
✅ **GPU gratuit** - antrenare mult mai rapidă
✅ **Funcționează 100%** - TensorFlow 2.12 garantat
✅ **Poți salva notebook-ul** pentru viitor
✅ **Poți conecta Google Drive** pentru date

---

## 💡 Tips

- **Salvează notebook-ul frecvent** (File → Save)
- **Folosește GPU gratuit** (Runtime → Change runtime type → GPU)
- **Upload datele în Google Drive** pentru acces rapid
- **Salvează și modelele Keras** (`.keras` files) pentru reconversii viitoare

---

## 🚨 Limitări

- **12 ore max** per sesiune - apoi se resetează
- **Disk space limitat** - download-ează modelele imediat
- **GPU limitat la câteva ore pe zi** (dar suficient pentru 18 modele!)

---

**Link direct:** https://colab.research.google.com/

**Mult succes! 🚀**

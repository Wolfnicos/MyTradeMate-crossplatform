# 📚 Ghid Complet: Antrenare Modele ML pentru iOS/Android

## ✅ CE TREBUIE PENTRU CA MODELELE SĂ MEARGĂ

### 1. **NUMĂR DE FEATURES: 76**

Aplicația așteaptă exact **76 de features per timestep**:
- 25 candle patterns (doji, hammer, engulfing, etc.)
- 51 technical indicators (RSI, MACD, Bollinger, ATR, etc.)

### 2. **INPUT SHAPE: [60, 76]**

- **60 timesteps** (60 candle-uri istorice)
- **76 features** per timestep
- Batch shape pentru TFLite: `[1, 60, 76]`

### 3. **OUTPUT SHAPE: [1, 3]**

Modelele trebuie să returneze **3 clase**:
- Class 0: **SELL**
- Class 1: **HOLD**
- Class 2: **BUY**

---

## ❌ CE NU TREBUIE FOLOSIT (FOARTE IMPORTANT!)

### **NU folosi aceste layere/operații:**

```python
# ❌ NU MERGE pe iOS/Android
model.add(LSTM(...))           # Folosește FlexTensorListReserve
model.add(GRU(...))            # Folosește FlexTensorListReserve
model.add(Bidirectional(...))  # Folosește FlexTensorListReserve
```

**Motivul:** Aceste layere folosesc operații TensorFlow avansate (`FlexTensorListReserve`) care nu sunt suportate în TFLite standard!

---

## ✅ CE SĂ FOLOSEȘTI ÎN SCHIMB

### **Layere compatibile TFLite:**

```python
# ✅ MERGE pe iOS/Android
from tensorflow.keras.layers import (
    Dense,              # Fully connected layers
    Conv1D,             # 1D Convolutions
    MaxPooling1D,       # Pooling
    GlobalAveragePooling1D,
    Dropout,
    BatchNormalization,
    Flatten,
    Reshape
)
```

### **Exemplu: Arhitectură CNN 1D (RECOMANDATĂ)**

```python
import tensorflow as tf
from tensorflow.keras import layers, models

def build_tflite_compatible_model(sequence_length=60, num_features=76, num_classes=3):
    """
    Model CNN 1D compatibil TFLite pentru iOS/Android
    Input: [batch, 60, 76]
    Output: [batch, 3] (SELL, HOLD, BUY)
    """
    model = models.Sequential([
        # Input layer
        layers.Input(shape=(sequence_length, num_features)),

        # Conv Block 1
        layers.Conv1D(64, kernel_size=3, activation='relu', padding='same'),
        layers.BatchNormalization(),
        layers.MaxPooling1D(pool_size=2),
        layers.Dropout(0.2),

        # Conv Block 2
        layers.Conv1D(128, kernel_size=3, activation='relu', padding='same'),
        layers.BatchNormalization(),
        layers.MaxPooling1D(pool_size=2),
        layers.Dropout(0.3),

        # Conv Block 3
        layers.Conv1D(256, kernel_size=3, activation='relu', padding='same'),
        layers.BatchNormalization(),
        layers.GlobalAveragePooling1D(),

        # Dense layers
        layers.Dense(128, activation='relu'),
        layers.Dropout(0.4),
        layers.Dense(64, activation='relu'),
        layers.Dropout(0.3),

        # Output layer (3 classes: SELL, HOLD, BUY)
        layers.Dense(num_classes, activation='softmax')
    ])

    return model

# Compilare
model = build_tflite_compatible_model()
model.compile(
    optimizer='adam',
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

print(model.summary())
```

---

## 📋 PAȘI COMPLETI DE ANTRENARE ȘI CONVERSIE

### **Pasul 1: Pregătește datele**

```python
import numpy as np

# Datele tale trebuie să aibă shape-ul:
X_train.shape  # (num_samples, 60, 76)
y_train.shape  # (num_samples, 3)  # One-hot encoded SELL/HOLD/BUY

# Exemplu de one-hot encoding:
# SELL = [1, 0, 0]
# HOLD = [0, 1, 0]
# BUY  = [0, 0, 1]
```

### **Pasul 2: Antrenează modelul**

```python
# Antrenare
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

# Evaluare
test_loss, test_acc = model.evaluate(X_test, y_test)
print(f'Test accuracy: {test_acc:.4f}')
```

### **Pasul 3: Convertește la TFLite (CEL MAI IMPORTANT!)**

```python
def convert_to_tflite_standard(model, output_path):
    """
    Convertește modelul la TFLite FĂRĂ Select TF Ops
    COMPATIBIL cu iOS/Android
    """
    # Crează converter
    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    # ✅ SETĂRI CRITICE - DOAR OPERAȚII TFLITE STANDARD
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS  # Doar ops TFLite standard
    ]

    # Optimizări (opțional dar recomandat)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    # ❌ NU activa acestea (cauzează probleme pe iOS/Android):
    # converter.target_spec.supported_ops = [
    #     tf.lite.OpsSet.TFLITE_BUILTINS,
    #     tf.lite.OpsSet.SELECT_TF_OPS  # ❌ NU!
    # ]

    # Convertește
    tflite_model = converter.convert()

    # Salvează
    with open(output_path, 'wb') as f:
        f.write(tflite_model)

    print(f'✅ Model salvat: {output_path}')
    print(f'📦 Dimensiune: {len(tflite_model) / 1024 / 1024:.2f} MB')

    return tflite_model

# Folosește funcția
tflite_model = convert_to_tflite_standard(
    model,
    'assets/models/btc_model.tflite'
)
```

### **Pasul 4: Testează modelul TFLite**

```python
def test_tflite_model(tflite_path, test_sample):
    """
    Testează modelul TFLite înainte de a-l pune în app
    """
    # Încarcă interpreter
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()

    # Obține input/output details
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print("📊 Model Info:")
    print(f"   Input shape: {input_details[0]['shape']}")
    print(f"   Output shape: {output_details[0]['shape']}")

    # Test inference
    test_input = test_sample.reshape(1, 60, 76).astype(np.float32)
    interpreter.set_tensor(input_details[0]['index'], test_input)
    interpreter.invoke()
    output = interpreter.get_tensor(output_details[0]['index'])

    # Rezultat
    probabilities = output[0]
    prediction = np.argmax(probabilities)
    labels = ['SELL', 'HOLD', 'BUY']

    print(f"\n🔮 Prediction: {labels[prediction]}")
    print(f"📊 Probabilities:")
    for i, label in enumerate(labels):
        print(f"   {label}: {probabilities[i]*100:.2f}%")

    return probabilities

# Testează
test_sample = X_test[0]  # Ia un exemplu de test
test_tflite_model('assets/models/btc_model.tflite', test_sample)
```

---

## 📁 STRUCTURA FINALĂ FIȘIERE

Pentru fiecare monedă (btc, eth, bnb, sol, trump, wlfi):

```
assets/models/
├── btc_model.tflite     # Model TFLite (2-3 MB)
├── eth_model.tflite
├── bnb_model.tflite
├── sol_model.tflite
├── trump_model.tflite
└── wlfi_model.tflite
```

---

## ✅ CHECKLIST FINAL

Înainte de a pune modelul în aplicație, verifică:

- [ ] **Input shape corect:** `[1, 60, 76]`
- [ ] **Output shape corect:** `[1, 3]`
- [ ] **NU folosește LSTM/GRU/Bidirectional**
- [ ] **Conversie cu `TFLITE_BUILTINS` only**
- [ ] **Testat cu interpreter TFLite în Python**
- [ ] **Dimensiune rezonabilă (2-5 MB)**
- [ ] **Accuracy > 50%** (altfel e random guessing)

---

## 🚀 SCRIPT COMPLET DE ANTRENARE

```python
#!/usr/bin/env python3
"""
Script complet de antrenare modele TFLite pentru iOS/Android
"""
import tensorflow as tf
import numpy as np
from sklearn.model_selection import train_test_split

def prepare_data(coin='btc'):
    """
    Încarcă și pregătește datele
    Returnează: X_train, X_val, X_test, y_train, y_val, y_test
    """
    # TODO: Încarcă datele tale aici
    # X shape: (num_samples, 60, 76)
    # y shape: (num_samples, 3) one-hot encoded
    pass

def build_model():
    """Model CNN 1D compatibil TFLite"""
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(60, 76)),
        tf.keras.layers.Conv1D(64, 3, activation='relu', padding='same'),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.MaxPooling1D(2),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Conv1D(128, 3, activation='relu', padding='same'),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.MaxPooling1D(2),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Conv1D(256, 3, activation='relu', padding='same'),
        tf.keras.layers.GlobalAveragePooling1D(),
        tf.keras.layers.Dense(128, activation='relu'),
        tf.keras.layers.Dropout(0.4),
        tf.keras.layers.Dense(3, activation='softmax')
    ])
    return model

def train_and_convert(coin='btc'):
    """Antrenează și convertește modelul"""
    print(f"🚀 Training model for {coin.upper()}...")

    # 1. Pregătește datele
    X_train, X_val, X_test, y_train, y_val, y_test = prepare_data(coin)

    # 2. Build model
    model = build_model()
    model.compile(
        optimizer='adam',
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )

    # 3. Train
    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=50,
        batch_size=32,
        callbacks=[
            tf.keras.callbacks.EarlyStopping(patience=10, restore_best_weights=True)
        ]
    )

    # 4. Evaluate
    test_loss, test_acc = model.evaluate(X_test, y_test)
    print(f'✅ Test accuracy: {test_acc:.4f}')

    # 5. Convert to TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    tflite_model = converter.convert()

    # 6. Save
    output_path = f'assets/models/{coin}_model.tflite'
    with open(output_path, 'wb') as f:
        f.write(tflite_model)

    print(f'💾 Model saved: {output_path} ({len(tflite_model)/1024/1024:.2f} MB)')

    return model, history

if __name__ == '__main__':
    coins = ['btc', 'eth', 'bnb', 'sol', 'trump', 'wlfi']

    for coin in coins:
        train_and_convert(coin)
```

---

## 📞 SUPORT

Dacă modelul nu se încarcă, verifică log-urile:
- iOS: Vezi Console app / Device logs
- Android: `adb logcat | grep TFLite`

**Eroare comună:** `FlexTensorListReserve not supported`
**Soluție:** Modelul folosește LSTM/GRU. Reconstruiește cu CNN 1D!

---

**Mult succes la antrenare! 🚀**

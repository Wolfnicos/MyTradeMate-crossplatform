# 🔧 Ghid Reantrenare Modele pentru iOS Compatibility

## ⚠️ PROBLEMA IDENTIFICATĂ

Modelele tale actuale sunt antrenate cu **TensorFlow 2.20.0** (schema TFL3) dar **tflite_flutter 0.11.0** pe iOS suportă doar **TensorFlow 2.12.0** (schema TFL2).

```
❌ Model actual: TensorFlow 2.20.0 → TFL3 schema → INCOMPATIBIL cu iOS
✅ Necesar:     TensorFlow 2.12.0 → TFL2 schema → COMPATIBIL cu iOS
```

---

## 📋 PAȘI DE URMAT

### 1. Instalează TensorFlow 2.12.0

```bash
# Creează un environment virtual nou (RECOMANDAT)
python3 -m venv venv_tf212
source venv_tf212/bin/activate

# Instalează TensorFlow 2.12.0
pip install tensorflow==2.12.0 numpy pandas scikit-learn ta-lib

# Verifică versiunea
python -c "import tensorflow as tf; print(tf.__version__)"
# Output: 2.12.0
```

### 2. Folosește Același Script de Training

**Modelele tale sunt CORECTE** - folosesc CNN 2D (CONV_2D, MAX_POOL_2D) care e perfect compatibil!

**NU schimba arhitectura!** Doar reantrenează cu TF 2.12.0:

```python
import tensorflow as tf

# Verifică versiunea ÎNAINTE de a antrena
assert tf.__version__.startswith('2.12'), f"Wrong TF version: {tf.__version__}"

# Modelul tău EXACT așa cum e acum (CNN 2D) - NU schimba nimic!
model = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(60, 76)),

    # Exact arhitectura ta actuală
    tf.keras.layers.Reshape((60, 76, 1)),
    tf.keras.layers.Conv2D(32, (3, 3), activation='relu', padding='same'),
    tf.keras.layers.MaxPooling2D((2, 2)),
    tf.keras.layers.Dropout(0.2),

    tf.keras.layers.Conv2D(64, (3, 3), activation='relu', padding='same'),
    tf.keras.layers.MaxPooling2D((2, 2)),
    tf.keras.layers.Dropout(0.3),

    tf.keras.layers.Conv2D(128, (3, 3), activation='relu', padding='same'),
    tf.keras.layers.GlobalAveragePooling2D(),

    tf.keras.layers.Dense(64, activation='relu'),
    tf.keras.layers.Dropout(0.4),
    tf.keras.layers.Dense(3, activation='softmax')  # SELL, HOLD, BUY
])

# Training (același proces ca înainte)
model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])
model.fit(X_train, y_train, validation_data=(X_val, y_val), epochs=50, batch_size=32)

# ✅ CONVERSIE TFLite cu TF 2.12.0
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]  # DOAR builtin ops
converter.optimizations = [tf.lite.Optimize.DEFAULT]

tflite_model = converter.convert()

# Salvează
with open('btc_5m_model.tflite', 'wb') as f:
    f.write(tflite_model)

print(f"✅ Model saved with TF {tf.__version__}")
```

### 3. Verifică Compatibilitatea

După conversie, verifică că modelul e compatibil:

```python
import tensorflow as tf

# Încarcă modelul
interpreter = tf.lite.Interpreter(model_path='btc_5m_model.tflite')
interpreter.allocate_tensors()

# Verifică input/output
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print(f"✅ Input shape: {input_details[0]['shape']}")   # [1, 60, 76]
print(f"✅ Output shape: {output_details[0]['shape']}")  # [1, 3]

# Test inference
test_input = np.random.randn(1, 60, 76).astype(np.float32)
interpreter.set_tensor(input_details[0]['index'], test_input)
interpreter.invoke()
output = interpreter.get_tensor(output_details[0]['index'])

print(f"✅ Model works! Output: {output}")
```

### 4. Înlocuiește Modelele în Assets

```bash
# Copiază modelele noi în assets/ml/
cp btc_5m_model.tflite assets/ml/
cp btc_15m_model.tflite assets/ml/
cp btc_1h_model.tflite assets/ml/
# ... etc pentru toate cele 18 modele

# Rebuild Flutter app
flutter clean
flutter run -d 00008150-00084C1622C0401C
```

---

## 🎯 CHECKLIST FINAL

Înainte de a rula app-ul, verifică:

- [ ] **TensorFlow 2.12.0 instalat** (`python -c "import tensorflow as tf; print(tf.__version__)"`)
- [ ] **Modelele reantrenate** cu TF 2.12.0
- [ ] **Toate cele 18 modele** convertite și copiate în `assets/ml/`
- [ ] **Test în Python** - modelele se încarcă cu `tf.lite.Interpreter`
- [ ] **Flutter clean + rebuild** după înlocuirea modelelor

---

## 📊 Date Necesare pentru Training

Dacă ai nevoie să recreezi datele de antrenament, folosește:

- **76 features** exact cum sunt definite în `FEATURES_SPECIFICATION.md`
- **60 timesteps** (60 candle-uri istorice)
- **3 clase**: SELL (0), HOLD (1), BUY (2) - one-hot encoded

---

## 💡 TIP: Salvează și Modelele Keras!

Pentru viitor, salvează și modelele Keras (nu doar TFLite):

```python
# După training, salvează modelul Keras
model.save(f'{coin}_{timeframe}_model.keras')

# Astfel poți reconverti oricând fără retraining
model = tf.keras.models.load_model('btc_5m_model.keras')
converter = tf.lite.TFLiteConverter.from_keras_model(model)
# ... conversie
```

---

## 🚨 Erori Comune

### "Wrong TF version"
```bash
# Dezactivează env vechi, activează cel nou
deactivate
source venv_tf212/bin/activate
```

### "Model still doesn't load on iOS"
```python
# Verifică schema modelului
with open('btc_5m_model.tflite', 'rb') as f:
    header = f.read(20)
    print(header)  # Ar trebui să înceapă cu b'TFL3' sau b'TFL2'
```

### "Accuracy scăzută după retraining"
- Normal - antrenează mai multe epochs
- Folosește exact aceleași date de training ca înainte
- Verifică că preprocessing-ul e identic

---

**Mult succes! 🚀**

Odată ce reantrenezi cu TF 2.12.0, modelele VOR MERGE pe iOS!

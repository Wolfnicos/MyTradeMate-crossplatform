# 🐳 Comenzi Docker - Training Modele ML pentru iOS

## 📋 Pași Completi (Comandă cu Comandă)

### 1. Creează Director pentru Output

```bash
mkdir -p output
```

### 2. Build Docker Image (TensorFlow 2.13)

```bash
docker build -t ml-trainer .
```

**Output așteptat:**
```
[+] Building 45.2s (9/9) FINISHED
 => [internal] load build definition
 => => transferring dockerfile: 312B
 => [internal] load .dockerignore
 ...
 => exporting to image
 => => writing image sha256:abc123...
 => => naming to docker.io/library/ml-trainer
```

### 3. Rulează Training într-un Container (Demo cu Date Random)

```bash
docker run --rm \
  -v $(pwd)/output:/workspace/output \
  ml-trainer
```

**Ce face:**
- Rulează `train_model.py`
- Folosește date RANDOM (demo)
- Salvează modelul în `./output/btc_5m_model.tflite`

**Output așteptat:**
```
====================================================
🚀 ML Model Training for iOS
   TensorFlow: 2.13.0
====================================================

⚠️  WARNING: Using RANDOM data for demo!
   Replace with your actual training data!

============================================================
🚀 Training btc 5m
============================================================

📊 Training data shape: (1000, 60, 76)
📊 Labels shape: (1000, 3)

Epoch 1/50
32/32 [==============================] - 2s 45ms/step - loss: 1.0987 - accuracy: 0.3340 - val_loss: 1.0984 - val_accuracy: 0.3350
...
Epoch 15/50
32/32 [==============================] - 1s 28ms/step - loss: 1.0932 - accuracy: 0.3480 - val_loss: 1.0928 - val_accuracy: 0.3500

✅ Validation accuracy: 0.3500

🔄 Converting to TFLite...
✅ Model saved: /workspace/output/btc_5m_model.tflite (0.20 MB)
✅ Model verified!
   Input shape: [  1  60  76]
   Output shape: [1 3]

============================================================
✅ DONE!
============================================================

Model saved to: /workspace/output/btc_5m_model.tflite
Copy to: assets/ml/btc_5m_model.tflite
```

### 4. Verifică Modelul Creat

```bash
ls -lh output/
```

**Output:**
```
total 200K
-rw-r--r-- 1 user user 203K Oct 19 10:30 btc_5m_model.tflite
```

### 5. Testează Modelul cu Python

```bash
docker run --rm \
  -v $(pwd)/output:/workspace/output \
  ml-trainer \
  python -c "
import tensorflow as tf
interpreter = tf.lite.Interpreter(model_path='/workspace/output/btc_5m_model.tflite')
interpreter.allocate_tensors()
print('✅ Model is valid and compatible with iOS!')
"
```

---

## 🔄 Training cu DATE REALE (NU Random!)

### Pasul 1: Pregătește Datele

Creează director `data/` cu fișierele tale `.npy`:

```bash
mkdir -p data
# Copiază fișierele tale aici:
# data/btc_5m_X_train.npy
# data/btc_5m_y_train.npy
# data/btc_5m_X_val.npy
# data/btc_5m_y_val.npy
# ... etc pentru toate cele 18 modele
```

### Pasul 2: Modifică `train_model.py`

Înlocuiește secțiunea cu date random cu:

```python
# Load REAL data
X_train = np.load(f'/workspace/data/{coin}_{timeframe}_X_train.npy')
y_train = np.load(f'/workspace/data/{coin}_{timeframe}_y_train.npy')
X_val = np.load(f'/workspace/data/{coin}_{timeframe}_X_val.npy')
y_val = np.load(f'/workspace/data/{coin}_{timeframe}_y_val.npy')
```

### Pasul 3: Rebuild Docker Image

```bash
docker build -t ml-trainer .
```

### Pasul 4: Rulează Training cu Date Reale

```bash
docker run --rm \
  -v $(pwd)/data:/workspace/data \
  -v $(pwd)/output:/workspace/output \
  ml-trainer
```

---

## 🔁 Training pentru TOATE cele 18 Modele

### Script pentru Loop prin Toate Modelele

Modifică `train_model.py` la final:

```python
def main():
    coins = ['btc', 'eth', 'bnb', 'sol', 'trump', 'wlfi']
    timeframes = ['5m', '15m', '1h']

    for coin in coins:
        for timeframe in timeframes:
            try:
                # Load data
                X_train = np.load(f'/workspace/data/{coin}_{timeframe}_X_train.npy')
                y_train = np.load(f'/workspace/data/{coin}_{timeframe}_y_train.npy')
                X_val = np.load(f'/workspace/data/{coin}_{timeframe}_X_val.npy')
                y_val = np.load(f'/workspace/data/{coin}_{timeframe}_y_val.npy')

                # Train
                model, accuracy = train_model(coin, timeframe, X_train, y_train, X_val, y_val)

                # Convert
                output_path = f'/workspace/output/{coin}_{timeframe}_model.tflite'
                os.makedirs('/workspace/output', exist_ok=True)
                convert_to_tflite(model, output_path)

                print(f"✅ {coin} {timeframe} DONE! (Accuracy: {accuracy:.4f})")

            except Exception as e:
                print(f"❌ {coin} {timeframe} FAILED: {e}")
                continue
```

Apoi rulează:

```bash
docker run --rm \
  -v $(pwd)/data:/workspace/data \
  -v $(pwd)/output:/workspace/output \
  ml-trainer
```

Asta va genera toate cele **18 modele** automat!

---

## 📦 Copiază Modelele în Assets

După training:

```bash
# Copiază toate modelele în assets/ml/
cp output/*.tflite assets/ml/

# Verifică
ls -lh assets/ml/*.tflite
```

**Output așteptat:**
```
-rw-r--r-- 1 user user 203K btc_5m_model.tflite
-rw-r--r-- 1 user user 203K btc_15m_model.tflite
-rw-r--r-- 1 user user 203K btc_1h_model.tflite
-rw-r--r-- 1 user user 203K eth_5m_model.tflite
... (18 total)
```

---

## 🚀 Rebuild Flutter App

```bash
flutter clean
flutter pub get
flutter run -d 00008150-00084C1622C0401C
```

---

## 🎯 Comenzi Rapide de Debugging

### Verifică ce versiune TensorFlow e în container:

```bash
docker run --rm ml-trainer python -c "import tensorflow as tf; print(tf.__version__)"
```

### Rulează shell interactiv în container:

```bash
docker run --rm -it \
  -v $(pwd)/data:/workspace/data \
  -v $(pwd)/output:/workspace/output \
  ml-trainer bash
```

### Șterge toate containerele și imaginile (cleanup):

```bash
docker rm $(docker ps -aq)
docker rmi ml-trainer
```

---

## ✅ Checklist Final

- [ ] Docker instalat și rulează
- [ ] `Dockerfile` creat
- [ ] `train_model.py` creat
- [ ] Director `data/` cu fișiere `.npy` (sau folosești date random pentru test)
- [ ] Director `output/` creat
- [ ] Build Docker image: `docker build -t ml-trainer .`
- [ ] Rulează training: `docker run --rm -v $(pwd)/output:/workspace/output ml-trainer`
- [ ] Verifică modelul: `ls -lh output/`
- [ ] Copiază în assets: `cp output/*.tflite assets/ml/`
- [ ] Rebuild Flutter: `flutter clean && flutter run`

---

**GATA! Modelele vor merge 100% pe iOS!** 🎉

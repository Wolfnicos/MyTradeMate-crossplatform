# 🇷🇴 GHID PAS CU PAS - MyTradeMate

## 📱 PAS 1: GENERARE KEYSTORE ANDROID (OBLIGATORIU)

### Rulează această comandă în Terminal:

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

### Ce o să te întrebe (și ce să răspunzi):

**1. Enter keystore password:**
- Alege o **parolă puternică** (minim 8 caractere, cu litere și cifre)
- Exemplu: `MyTrade2025!Secure`
- **IMPORTANT:** Salvează-o undeva sigur (1Password, LastPass, etc.)

**2. Re-enter new password:**
- Rescrie exact aceeași parolă

**3. What is your first and last name?**
- Exemplu: `Dragos Lupu` (numele tău)

**4. What is the name of your organizational unit?**
- Exemplu: `Development` sau `Engineering`

**5. What is the name of your organization?**
- Exemplu: `MyTradeMate` sau numele companiei tale

**6. What is the name of your City or Locality?**
- Exemplu: `Bucuresti` sau orașul tău

**7. What is the name of your State or Province?**
- Exemplu: `Romania` sau județul tău

**8. What is the two-letter country code for this unit?**
- Răspunde: `RO` (pentru România)

**9. Is CN=..., OU=..., O=..., L=..., ST=..., C=RO correct?**
- Răspunde: `yes`

**10. Enter key password for <upload>**
- Apasă **ENTER** (va folosi aceeași parolă ca la keystore)

### Verificare:

După ce se termină, verifică că fișierul există:

```bash
ls -lh ~/upload-keystore.jks
```

Ar trebui să vezi ceva de genul:
```
-rw-r--r--  1 lupudragos  staff   2.0K 24 Oct 23:55 /Users/lupudragos/upload-keystore.jks
```

---

## ✅ Când ai terminat Pasul 1, spune-mi și trecem la Pasul 2!

---

## 📝 NOTIȚE IMPORTANTE:

**SALVEAZĂ PAROLA ȘI KEYSTORE-UL!**
- Fă backup la `~/upload-keystore.jks` pe minim 2 locații:
  - USB stick
  - Cloud storage (Google Drive, Dropbox)
  - Password manager (1Password, LastPass)

**DACĂ PIERZI KEYSTORE-UL:**
- Nu vei mai putea actualiza aplicația pe Google Play
- Va trebui să publici o aplicație nouă cu alt package name
- Pierzi toți utilizatorii existenți

**NU FACE:**
- ❌ Nu da commit la keystore în Git
- ❌ Nu trimite keystore pe email/Slack/Discord
- ❌ Nu pui parola în cod

---

## 🆘 PROBLEME?

**Error: keytool: command not found**
```bash
# Verifică dacă ai Java instalat:
java -version

# Dacă nu merge, instalează Java JDK:
brew install openjdk@17
```

**Error: Keystore file already exists**
```bash
# Șterge keystore-ul vechi:
rm ~/upload-keystore.jks

# Și rulează din nou comanda keytool
```

---

**Gata cu instrucțiunile - RULEAZĂ COMANDA și spune-mi când e gata!** 🚀

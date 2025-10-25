# Android Release Signing Setup Guide

## ⚠️ IMPORTANT: You MUST complete this before releasing to Google Play

The app is now configured to use proper release signing, but you need to generate a keystore first.

---

## Step 1: Generate Upload Keystore

Run this command in your terminal (from anywhere):

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

**You will be prompted for:**
1. **Keystore password** - Choose a STRONG password (save it securely!)
2. **Key password** - Can be the same as keystore password
3. **Name and organizational details** - Enter your company/personal details
   - First and last name
   - Organizational unit
   - Organization name
   - City/Locality
   - State/Province
   - Country code (2 letters, e.g., US)

**Example interaction:**
```
Enter keystore password: [your-strong-password]
Re-enter new password: [your-strong-password]
What is your first and last name?
  [Unknown]:  John Doe
What is the name of your organizational unit?
  [Unknown]:  Development
What is the name of your organization?
  [Unknown]:  MyTradeMate
What is the name of your City or Locality?
  [Unknown]:  San Francisco
What is the name of your State or Province?
  [Unknown]:  California
What is the two-letter country code for this unit?
  [Unknown]:  US
Is CN=John Doe, OU=Development, O=MyTradeMate, L=San Francisco, ST=California, C=US correct?
  [no]:  yes

Enter key password for <upload>
	(RETURN if same as keystore password): [press RETURN]
```

---

## Step 2: Create key.properties File

Create a file at `android/key.properties` with this content:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/Users/YOUR_USERNAME/upload-keystore.jks
```

**Replace:**
- `YOUR_KEYSTORE_PASSWORD` - Password you entered in Step 1
- `YOUR_KEY_PASSWORD` - Key password (same as keystore password if you pressed RETURN)
- `YOUR_USERNAME` - Your Mac username (run `whoami` to find it)

**Example:**
```properties
storePassword=MySecurePassword123!
keyPassword=MySecurePassword123!
keyAlias=upload
storeFile=/Users/johndoe/upload-keystore.jks
```

---

## Step 3: Verify Configuration

Test that signing works:

```bash
cd /Users/lupudragos/Development/MyTradeMate/mytrademate
flutter clean
flutter build appbundle --release
```

**If successful, you'll see:**
```
✓ Built build/app/outputs/bundle/release/app-release.aab (XX.X MB).
```

**If you see an error about keystore, check:**
1. `key.properties` file exists in `android/` directory
2. Path to keystore file is correct (absolute path)
3. Passwords are correct
4. No extra spaces in key.properties

---

## Step 4: Secure Your Keystore

### CRITICAL SECURITY STEPS:

1. **Backup your keystore file** to 2+ secure locations:
   - External hard drive
   - Encrypted cloud storage (1Password, LastPass, etc.)
   - USB drive in safe place

2. **Save passwords securely:**
   - Use password manager (1Password, LastPass, Bitwarden)
   - Store in encrypted note
   - NEVER commit to git

3. **Verify key.properties is in .gitignore:**
   ```bash
   grep "key.properties" android/.gitignore
   ```
   Should output: `key.properties`

⚠️ **WARNING: If you lose the keystore, you CANNOT update your app on Google Play. You'll have to publish a new app with a different package name.**

---

## Step 5: Google Play Console Setup

When uploading to Google Play Console for the first time:

1. Go to **Release > Setup > App Integrity**
2. Enroll in **Google Play App Signing**
3. Upload your **upload certificate** (Google will generate a separate app signing key)

To extract your upload certificate:

```bash
keytool -export -rfc \
  -keystore ~/upload-keystore.jks \
  -alias upload \
  -file upload_certificate.pem
```

Upload `upload_certificate.pem` to Google Play Console.

---

## Troubleshooting

### Error: "keystore not found"
- Check the `storeFile` path in `key.properties`
- Use absolute path (e.g., `/Users/johndoe/upload-keystore.jks`)
- Verify file exists: `ls -la ~/upload-keystore.jks`

### Error: "incorrect password"
- Double-check passwords in `key.properties`
- No extra spaces before/after passwords
- Password is case-sensitive

### Error: "key.properties not found"
- File must be at `android/key.properties` (not `android/app/key.properties`)
- Verify: `ls -la android/key.properties`

### Build still uses debug signing
- Delete `build/` directory: `rm -rf build/`
- Run `flutter clean`
- Rebuild: `flutter build appbundle --release`

---

## Quick Reference

**Generate keystore:**
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Build release AAB:**
```bash
flutter build appbundle --release
```

**Build release APK (for testing):**
```bash
flutter build apk --release
```

**Extract certificate:**
```bash
keytool -export -rfc -keystore ~/upload-keystore.jks -alias upload -file upload_certificate.pem
```

**Verify keystore:**
```bash
keytool -list -v -keystore ~/upload-keystore.jks -alias upload
```

---

## Next Steps After Signing Setup

1. ✅ Generate keystore (Step 1)
2. ✅ Create key.properties (Step 2)
3. ✅ Test build (Step 3)
4. ✅ Backup keystore securely (Step 4)
5. Create Google Play Console account
6. Create app listing
7. Upload AAB file
8. Complete Store Listing (description, screenshots, etc.)
9. Submit for review

---

**Questions?** Check [Flutter's official signing documentation](https://docs.flutter.dev/deployment/android#signing-the-app)

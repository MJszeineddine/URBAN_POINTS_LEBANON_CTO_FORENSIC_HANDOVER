# Android App Signing Configuration

## Overview

This guide covers Android app signing for both debug and release builds of Urban Points Lebanon mobile apps (Customer and Merchant).

---

## Prerequisites

- Android SDK installed
- Java Development Kit (JDK) 17+
- Keytool (included with JDK)

---

## Generate Release Keystore

### 1. Create Keystore

```bash
keytool -genkey -v -keystore urbanpoints-release.keystore \
  -alias urbanpoints-key \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000

# You'll be prompted for:
# - Keystore password (SAVE THIS SECURELY!)
# - Key password (can be same as keystore password)
# - Your name: Urban Points Lebanon
# - Organizational unit: Engineering
# - Organization: Urban Points Lebanon
# - City: Beirut
# - State: Beirut
# - Country code: LB
```

### 2. Secure the Keystore

```bash
# Move to secure location (NOT in git repository)
mv urbanpoints-release.keystore ~/secure/keys/

# Set restrictive permissions
chmod 600 ~/secure/keys/urbanpoints-release.keystore

# Backup to encrypted storage
# CRITICAL: Store in password manager or secure vault
```

---

## Configure Gradle for Signing

### 1. Create key.properties

Create `android/key.properties` (add to .gitignore):

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=urbanpoints-key
storeFile=/Users/YOUR_USERNAME/secure/keys/urbanpoints-release.keystore
```

### 2. Update android/app/build.gradle

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config ...

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
        
        debug {
            applicationIdSuffix ".debug"
            debuggable true
        }
    }

    flavorDimensions "environment"
    productFlavors {
        production {
            dimension "environment"
            applicationId "com.urbanpoints.customer"  // or merchant
            versionCode 1
            versionName "1.0.0"
        }
        
        staging {
            dimension "environment"
            applicationId "com.urbanpoints.customer.staging"
            versionCode 1
            versionName "1.0.0-staging"
        }
    }
}
```

---

## Build Signed APK/Bundle

### APK (for testing)

```bash
cd source/apps/mobile-customer
flutter build apk --release --flavor production
# Output: build/app/outputs/flutter-apk/app-production-release.apk
```

### App Bundle (for Google Play)

```bash
cd source/apps/mobile-customer
flutter build appbundle --release --flavor production
# Output: build/app/outputs/bundle/productionRelease/app-production-release.aab
```

---

## Verify Signing

```bash
# Verify APK signature
jarsigner -verify -verbose -certs \
  build/app/outputs/flutter-apk/app-production-release.apk

# Check signing certificate
keytool -printcert -jarfile \
  build/app/outputs/flutter-apk/app-production-release.apk
```

---

## Google Play Console Setup

### 1. Create App

1. Go to https://play.google.com/console
2. Click "Create app"
3. Fill in details:
   - App name: Urban Points Customer (or Merchant)
   - Default language: English (US)
   - App or game: App
   - Free or paid: Free
4. Accept declarations

### 2. App Signing

Google Play App Signing is RECOMMENDED:

1. Go to "Release" > "Setup" > "App signing"
2. Choose "Continue" to let Google manage your app signing key
3. Upload your upload key certificate

```bash
# Generate upload key certificate
keytool -export -rfc \
  -keystore urbanpoints-release.keystore \
  -alias urbanpoints-key \
  -file upload_certificate.pem
```

### 3. Store Listing

Required information:
- App name
- Short description (max 80 chars)
- Full description (max 4000 chars)
- App icon (512x512 px)
- Feature graphic (1024x500 px)
- Screenshots (minimum 2)
- Privacy policy URL: https://urbanpoints.lb/privacy
- Contact email: support@urbanpoints.lb

### 4. Content Rating

1. Go to "Content rating"
2. Fill out questionnaire
3. Submit for rating

### 5. Target Audience & Content

1. Select target age group: 13+
2. Add content declarations
3. Confirm no ads (if applicable)

### 6. Release

1. Create production release
2. Upload app bundle
3. Add release notes
4. Review and roll out

---

## CI/CD Integration

### GitHub Actions (see .github/workflows/deploy.yml)

Environment secrets required:
- `ANDROID_KEYSTORE_BASE64`: Base64-encoded keystore
- `ANDROID_KEY_ALIAS`: Key alias
- `ANDROID_KEY_PASSWORD`: Key password
- `ANDROID_STORE_PASSWORD`: Keystore password

```bash
# Encode keystore for GitHub Secrets
base64 -i urbanpoints-release.keystore | pbcopy
# Paste into GitHub repository secrets
```

---

## ProGuard Configuration

Create `android/app/proguard-rules.pro`:

```proguard
# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Stripe
-keep class com.stripe.android.** { *; }

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.examples.android.model.** { <fields>; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep line numbers for debugging
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
```

---

## Troubleshooting

### Issue: "Failed to read key from the keystore"

**Solution:**
- Verify keystore path is correct
- Check keystore password
- Ensure keystore file has read permissions

### Issue: "minSdkVersion XX cannot be smaller than version XX"

**Solution:**
```gradle
android {
    defaultConfig {
        minSdkVersion 21  // Or higher as required
    }
}
```

### Issue: "Duplicate class found"

**Solution:**
```gradle
android {
    packagingOptions {
        exclude 'META-INF/*.kotlin_module'
    }
}
```

---

## Security Best Practices

1. **Never commit keystore to version control**
   - Add `*.keystore` to `.gitignore`
   - Add `key.properties` to `.gitignore`

2. **Store passwords securely**
   - Use password manager
   - Use CI/CD secrets for automation

3. **Backup keystore**
   - Store in multiple secure locations
   - Encrypted cloud storage
   - Physical backup

4. **Enable Google Play App Signing**
   - Google manages signing key
   - You manage upload key
   - Easier key rotation

5. **Monitor for security issues**
   - Enable Play Console security alerts
   - Regular security audits
   - Keep dependencies updated

---

## Reference Links

- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [Flutter Build and Release](https://docs.flutter.dev/deployment/android)
- [Google Play Console](https://play.google.com/console)
- [ProGuard Configuration](https://developer.android.com/studio/build/shrink-code)

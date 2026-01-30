# iOS App Signing Configuration

## Overview

This guide covers iOS app signing and provisioning for Urban Points Lebanon mobile apps (Customer and Merchant).

---

## Prerequisites

- macOS with Xcode 15+ installed
- Apple Developer Account (paid membership required)
- Access to App Store Connect

---

## Apple Developer Account Setup

### 1. Enroll in Apple Developer Program

1. Go to https://developer.apple.com/programs/
2. Sign in with Apple ID
3. Enroll (requires $99/year fee)
4. Wait for approval (usually 24-48 hours)

### 2. Create App IDs

1. Go to https://developer.apple.com/account/resources/identifiers/list
2. Click "+" to create new App ID
3. Fill in details:
   - **Customer App:**
     - Description: Urban Points Customer
     - Bundle ID: `com.urbanpoints.customer`
     - Capabilities: Push Notifications, Sign in with Apple, In-App Purchase
   
   - **Merchant App:**
     - Description: Urban Points Merchant
     - Bundle ID: `com.urbanpoints.merchant`
     - Capabilities: Push Notifications, Sign in with Apple, Camera

---

## Create iOS Project in Flutter

### 1. Initialize iOS Project

```bash
cd source/apps/mobile-customer
flutter create --platforms=ios .

# This creates the ios/ directory
```

### 2. Configure Xcode Project

```bash
# Open Xcode
open ios/Runner.xcworkspace

# In Xcode:
# 1. Select Runner project
# 2. Select Runner target
# 3. General tab:
#    - Bundle Identifier: com.urbanpoints.customer
#    - Version: 1.0.0
#    - Build: 1
#    - Deployment Target: iOS 13.0 or higher
```

---

## Signing & Capabilities

### 1. Automatic Signing (Development)

In Xcode:
1. Select Runner target
2. Signing & Capabilities tab
3. Check "Automatically manage signing"
4. Select your Team
5. Xcode will create development certificates and provisioning profiles

### 2. Manual Signing (Production)

#### Create Certificates

1. Go to https://developer.apple.com/account/resources/certificates/list
2. Click "+" to create certificate

**Distribution Certificate (for App Store):**
- Type: Apple Distribution
- Generate CSR:
  ```bash
  # Open Keychain Access > Certificate Assistant > Request Certificate
  # Save to disk as: UrbanPoints.certSigningRequest
  ```
- Upload CSR
- Download certificate (distribution.cer)
- Double-click to install in Keychain

**Development Certificate (for testing):**
- Type: Apple Development
- Follow same CSR process
- Download and install

#### Create Provisioning Profiles

**App Store Profile:**
1. Go to https://developer.apple.com/account/resources/profiles/list
2. Click "+" to create profile
3. Type: App Store
4. App ID: Select `com.urbanpoints.customer`
5. Certificate: Select your Distribution certificate
6. Profile Name: Urban Points Customer App Store
7. Download profile (UrbanPointsCustomer_AppStore.mobileprovision)

**Development Profile:**
1. Type: iOS App Development
2. App ID: Select `com.urbanpoints.customer`
3. Certificate: Select your Development certificate
4. Devices: Select test devices
5. Download profile

#### Install Profiles

```bash
# Open downloaded .mobileprovision file
# or copy to:
cp UrbanPointsCustomer_AppStore.mobileprovision \
  ~/Library/MobileDevice/Provisioning\ Profiles/
```

#### Configure in Xcode

1. Signing & Capabilities tab
2. Uncheck "Automatically manage signing"
3. Debug:
   - Provisioning Profile: Urban Points Customer Development
   - Signing Certificate: Apple Development
4. Release:
   - Provisioning Profile: Urban Points Customer App Store
   - Signing Certificate: Apple Distribution

---

## Configure Capabilities

### 1. Push Notifications

In Xcode:
1. Signing & Capabilities tab
2. Click "+ Capability"
3. Select "Push Notifications"

In Firebase Console:
1. Project Settings > Cloud Messaging
2. Upload APNs Authentication Key
   - Get from: https://developer.apple.com/account/resources/authkeys/list
   - Key ID and Team ID required

### 2. Sign in with Apple

In Xcode:
1. Add "Sign in with Apple" capability

In Apple Developer:
1. Identifier must have "Sign in with Apple" enabled

### 3. Associated Domains

For universal links and deep linking:

```
Domains:
- applinks:urbanpoints.lb
- applinks:www.urbanpoints.lb
```

---

## Build Configuration

### 1. Create Schemes

In Xcode:
1. Product > Scheme > Manage Schemes
2. Create schemes:
   - **Runner (Debug)**: Development build
   - **Runner (Staging)**: Staging environment
   - **Runner (Release)**: Production App Store build

### 2. Build Settings

In Xcode:
1. Runner target > Build Settings
2. Key settings:
   - **Code Signing Style**: Manual (for production)
   - **Development Team**: Your team ID
   - **Code Signing Identity**: 
     - Debug: Apple Development
     - Release: Apple Distribution
   - **Provisioning Profile**:
     - Debug: Development profile
     - Release: App Store profile

### 3. Info.plist Configuration

Edit `ios/Runner/Info.plist`:

```xml
<dict>
    <!-- App Transport Security -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
    </dict>
    
    <!-- Camera Permission -->
    <key>NSCameraUsageDescription</key>
    <string>Urban Points needs camera access to scan QR codes.</string>
    
    <!-- Location Permission -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Urban Points uses your location to find nearby offers.</string>
    
    <!-- Photo Library Permission -->
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Urban Points needs access to save QR codes.</string>
    
    <!-- Face ID Permission -->
    <key>NSFaceIDUsageDescription</key>
    <string>Urban Points uses Face ID for secure authentication.</string>
    
    <!-- URL Schemes -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>urbanpoints</string>
            </array>
        </dict>
    </array>
</dict>
```

---

## Build for Testing

### TestFlight (Internal Testing)

```bash
cd source/apps/mobile-customer

# Build for testing
flutter build ios --release

# Open Xcode
open ios/Runner.xcworkspace

# In Xcode:
# 1. Select "Any iOS Device" as destination
# 2. Product > Archive
# 3. Wait for archive to complete
# 4. Organizer window opens
# 5. Select archive > "Distribute App"
# 6. Choose "App Store Connect"
# 7. Upload
```

### Add Testers

1. Go to App Store Connect > TestFlight
2. Add internal testers (up to 100)
3. Add external testers (up to 10,000, requires review)

---

## Build for Production

### 1. Update Version

Update version in `pubspec.yaml`:

```yaml
version: 1.0.0+1  # version+build_number
```

And in Xcode:
- Version: 1.0.0
- Build: 1

### 2. Build Archive

```bash
flutter build ios --release --no-codesign
```

Then in Xcode:
1. Product > Archive
2. Select archive > "Distribute App"
3. App Store Connect
4. Upload
5. Wait for processing

---

## App Store Connect Configuration

### 1. Create App

1. Go to https://appstoreconnect.apple.com
2. My Apps > "+" > New App
3. Fill in:
   - Platform: iOS
   - Name: Urban Points Customer
   - Primary Language: English (U.S.)
   - Bundle ID: com.urbanpoints.customer
   - SKU: urbanpoints-customer-001

### 2. App Information

- **Category**: Lifestyle
- **Content Rights**: No
- **Age Rating**: Fill questionnaire (likely 4+)
- **Privacy Policy URL**: https://urbanpoints.lb/privacy
- **Support URL**: https://urbanpoints.lb/support

### 3. Pricing and Availability

- Price: Free
- Availability: All countries
- Pre-order: No

### 4. Prepare for Submission

Required assets:

**App Preview and Screenshots:**
- 6.5" Display (iPhone 14 Pro Max, 15 Pro Max): 1290 x 2796 pixels
- 5.5" Display (iPhone 8 Plus): 1242 x 2208 pixels
- iPad Pro (3rd gen) 12.9": 2048 x 2732 pixels
- Minimum 2 screenshots per size

**App Icon:**
- 1024 x 1024 pixels (App Store)
- No alpha channel, no transparency

**Description:**
```
Urban Points Lebanon - Your digital loyalty card for Beirut and beyond.

Earn points at your favorite merchants, discover exclusive offers, and redeem rewards instantly with secure QR codes.

Features:
• Browse offers from top merchants
• Generate secure QR codes for redemptions
• Track your points balance
• Get notified about new offers
• Manage your profile and preferences

Safe, secure, and simple to use!
```

**Keywords:**
```
loyalty, points, rewards, offers, discounts, lebanon, beirut, qr code, shopping, deals
```

**Promotional Text (max 170 chars):**
```
Join thousands of users earning rewards! Download now and get 100 bonus points on your first redemption.
```

### 5. Build Selection

1. Select uploaded build from TestFlight
2. Add "What's New in This Version" release notes
3. Submit for Review

---

## Submission Checklist

- [ ] App builds and runs without crashes
- [ ] All functionality works as expected
- [ ] Privacy policy is accessible
- [ ] Support contact information is valid
- [ ] Screenshots accurately represent the app
- [ ] App description is accurate
- [ ] Test account provided (if login required)
- [ ] Compliance documentation ready
- [ ] Age rating is appropriate
- [ ] App follows Apple guidelines

---

## App Review Guidelines Compliance

Key points for approval:

1. **Performance**: App must be stable and complete
2. **Design**: Follow iOS Human Interface Guidelines
3. **Legal**: Terms and privacy policy required
4. **Safety**: Protect user data and privacy
5. **Business**: No misleading information

---

## CI/CD Integration

### GitHub Actions

Required secrets:
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_KEY_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_CONTENT` (base64 encoded)
- `MATCH_PASSWORD` (if using fastlane match)
- `IOS_CERTIFICATE_PASSWORD`

### Fastlane (Optional)

Create `ios/fastlane/Fastfile`:

```ruby
default_platform(:ios)

platform :ios do
  desc "Push a new beta build to TestFlight"
  lane :beta do
    build_app(workspace: "Runner.xcworkspace", scheme: "Runner")
    upload_to_testflight(skip_waiting_for_build_processing: true)
  end

  desc "Push a new release build to the App Store"
  lane :release do
    build_app(workspace: "Runner.xcworkspace", scheme: "Runner")
    upload_to_app_store(
      submit_for_review: false,
      automatic_release: false
    )
  end
end
```

---

## Troubleshooting

### Issue: "No signing certificate found"

**Solution:**
1. Open Keychain Access
2. Ensure certificate is in "My Certificates"
3. Verify certificate is not expired
4. Check certificate is linked to private key

### Issue: "Profile doesn't match bundle identifier"

**Solution:**
- Verify Bundle ID in Xcode matches App ID
- Regenerate provisioning profile
- Download and install new profile

### Issue: "Invalid Provisioning Profile"

**Solution:**
- Check profile includes correct devices
- Verify certificate is included in profile
- Profile must not be expired

### Issue: "App Store Connect build processing stuck"

**Solution:**
- Wait 15-30 minutes (normal processing time)
- Check for email from Apple about issues
- Verify Info.plist doesn't have errors

---

## Reference Links

- [iOS Developer Portal](https://developer.apple.com/account)
- [App Store Connect](https://appstoreconnect.apple.com)
- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

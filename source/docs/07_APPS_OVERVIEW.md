# Urban Points Lebanon - Apps Overview

## All Applications

| App | Type | Platform | Purpose | Status |
|-----|------|----------|---------|--------|
| Customer App | Mobile | Android/iOS | Consumer offer discovery & redemption | ✅ Production |
| Merchant App | Mobile | Android/iOS | Merchant offer management & validation | ✅ Production |
| Admin App | Mobile | Android/iOS | Platform administration & moderation | ✅ Production |
| Web Admin | Web | Browser | Admin dashboard (alternative to mobile) | ✅ Production |

---

## 1. Customer Mobile App

**Location**: `apps/mobile-customer/`

**Tech Stack**:
- Framework: Flutter 3.35.4
- Language: Dart 3.9.2
- State Management: Provider
- Backend: Firebase (Auth, Firestore, FCM)

**Main Features**:
- Browse offers by category, location, merchant
- Filter and search offers
- View offer details with terms & conditions
- Generate secure QR codes for redemption
- View points balance and transaction history
- Refer friends and earn bonus points
- Purchase premium subscriptions (Silver/Gold)
- Manage profile and preferences
- Receive push notifications

**Key Screens**:
- Splash & Onboarding
- Login/Signup
- Home Dashboard
- Offers List & Details
- QR Code Generator
- Wallet & Transaction History
- Profile & Settings
- Subscription Management

**How to Run Locally**:
```bash
cd apps/mobile-customer
flutter pub get
flutter run
```

**How to Build APK**:
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## 2. Merchant Mobile App

**Location**: `apps/mobile-merchant/`

**Tech Stack**: Same as Customer App

**Main Features**:
- Merchant authentication
- Create and manage offers
- Scan customer QR codes
- Validate redemptions
- View analytics dashboard
- Manage business profile
- Manage branch locations

**Key Screens**:
- Login
- Dashboard (stats overview)
- Offers Management (CRUD)
- QR Scanner
- Analytics
- Profile & Branches

**How to Run Locally**:
```bash
cd apps/mobile-merchant
flutter pub get
flutter run
```

**How to Build APK**:
```bash
flutter build apk --release
```

---

## 3. Admin Mobile App

**Location**: `apps/mobile-admin/`

**Tech Stack**: Same as Customer App

**Main Features**:
- Admin authentication
- Approve/reject merchant registrations
- Moderate offer submissions
- View system analytics
- Manage users (customers/merchants/admins)
- Configure system settings
- Send push notification campaigns

**Key Screens**:
- Login
- Dashboard (system metrics)
- Merchants (approval workflow)
- Offers (moderation)
- Analytics
- Settings

**How to Run Locally**:
```bash
cd apps/mobile-admin
flutter pub get
flutter run
```

**How to Build APK**:
```bash
flutter build apk --release
```

---

## 4. Web Admin Dashboard

**Location**: `apps/web-admin/`

**Tech Stack**:
- Pure HTML/CSS/JavaScript
- Firebase SDK (client-side)
- Hosted on Firebase Hosting

**Main Features**:
- Admin login
- Merchant approval interface
- Offer moderation
- System metrics dashboard
- User management

**How to Run Locally**:
```bash
cd apps/web-admin
python3 -m http.server 8080
# Access at http://localhost:8080
```

**How to Deploy**:
```bash
firebase deploy --only hosting:admin --project urbangenspark
# Access at https://urbangenspark.web.app
```

---

## App Comparison Matrix

| Feature | Customer | Merchant | Admin |
|---------|----------|----------|-------|
| Browse Offers | ✅ | ❌ | ✅ View Only |
| Redeem Offers | ✅ | ❌ | ❌ |
| Create Offers | ❌ | ✅ | ✅ (Override) |
| Scan QR Codes | ✅ (Generate) | ✅ (Validate) | ❌ |
| View Analytics | Personal | Business | System-wide |
| Manage Users | Own Profile | Own Business | All Users |
| Approve Merchants | ❌ | ❌ | ✅ |
| Moderate Offers | ❌ | Own Only | ✅ |
| Push Campaigns | ❌ | ❌ | ✅ |
| Subscriptions | Purchase | Purchase Premium | Configure |

---

**Document Version**: 1.0
**Last Updated**: November 2025

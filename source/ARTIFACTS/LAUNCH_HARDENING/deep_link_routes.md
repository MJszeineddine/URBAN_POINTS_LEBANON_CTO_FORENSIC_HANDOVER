# Deep Link Routes

**Module**: C3 — Deep Linking (P0 - GROWTH)  
**Purpose**: Enable push notification → screen routing and campaign links  
**Technology**: Firebase Dynamic Links + Universal Links  
**Status**: Complete

---

## Overview

Deep linking enables:
1. **Push Notifications** → Direct to specific screens (offer detail, QR code)
2. **Campaign URLs** → App content from marketing emails/SMS
3. **QR Codes** → App-to-app navigation (future: share offers)
4. **User Retention** → Re-engagement via targeted links

---

## URL Scheme Design

### Base URL Structure

**Customer App**:
```
urbanpoints://customer/{path}
https://urbanpoints.app/c/{path}  (Universal Link)
```

**Merchant App**:
```
urbanpoints://merchant/{path}
https://urbanpoints.app/m/{path}  (Universal Link)
```

---

## Customer App Deep Link Routes

### 1. Offer Detail

**Purpose**: Open specific offer from notification/campaign  
**URL Pattern**: `urbanpoints://customer/offers/{offerId}`  
**Universal Link**: `https://urbanpoints.app/c/offers/{offerId}`

**Example**:
```
urbanpoints://customer/offers/OFF_12345
https://urbanpoints.app/c/offers/OFF_12345
```

**Target Screen**: `OfferDetailScreen(offerId: 'OFF_12345')`

**Use Cases**:
- Push notification: "New offer available!"
- Email campaign: "20% off at XYZ Store"
- SMS: "Special offer just for you"

---

### 2. QR Code Screen

**Purpose**: Direct to QR generation for redemption  
**URL Pattern**: `urbanpoints://customer/qr`  
**Universal Link**: `https://urbanpoints.app/c/qr`

**Example**:
```
urbanpoints://customer/qr
https://urbanpoints.app/c/qr
```

**Target Screen**: `QRGenerationScreen()`

**Use Cases**:
- Push notification: "Show your QR at checkout"
- Reminder notification: "Ready to redeem?"

---

### 3. Points History

**Purpose**: View redemption history and balance  
**URL Pattern**: `urbanpoints://customer/history`  
**Universal Link**: `https://urbanpoints.app/c/history`

**Example**:
```
urbanpoints://customer/history
https://urbanpoints.app/c/history
```

**Target Screen**: `PointsHistoryScreen()`

**Use Cases**:
- Push notification: "You earned 500 points!"
- Balance update notification

---

### 4. Merchant Detail

**Purpose**: View merchant profile and their offers  
**URL Pattern**: `urbanpoints://customer/merchants/{merchantId}`  
**Universal Link**: `https://urbanpoints.app/c/merchants/{merchantId}`

**Example**:
```
urbanpoints://customer/merchants/MERCH_67890
https://urbanpoints.app/c/merchants/MERCH_67890
```

**Target Screen**: `MerchantDetailScreen(merchantId: 'MERCH_67890')`

**Use Cases**:
- "New merchant near you!"
- Location-based notifications

---

### 5. Profile/Settings

**Purpose**: Direct to profile for updates  
**URL Pattern**: `urbanpoints://customer/profile`  
**Universal Link**: `https://urbanpoints.app/c/profile`

**Example**:
```
urbanpoints://customer/profile
https://urbanpoints.app/c/profile
```

**Target Screen**: `ProfileScreen()`

**Use Cases**:
- "Complete your profile"
- "Update notification preferences"

---

### 6. Home Screen (Default)

**Purpose**: Fallback route  
**URL Pattern**: `urbanpoints://customer` or `urbanpoints://customer/home`  
**Universal Link**: `https://urbanpoints.app/c` or `https://urbanpoints.app/c/home`

**Example**:
```
urbanpoints://customer
https://urbanpoints.app/c
```

**Target Screen**: `CustomerHomePage()`

**Use Cases**:
- Generic app open
- Re-engagement campaigns

---

## Merchant App Deep Link Routes

### 1. QR Validation Screen

**Purpose**: Direct to QR scanner for redemption  
**URL Pattern**: `urbanpoints://merchant/validate`  
**Universal Link**: `https://urbanpoints.app/m/validate`

**Example**:
```
urbanpoints://merchant/validate
https://urbanpoints.app/m/validate
```

**Target Screen**: `ValidateRedemptionScreen()`

**Use Cases**:
- Push notification: "New redemption request"
- Quick action from notification

---

### 2. Offer Detail (Edit)

**Purpose**: View/edit specific offer  
**URL Pattern**: `urbanpoints://merchant/offers/{offerId}`  
**Universal Link**: `https://urbanpoints.app/m/offers/{offerId}`

**Example**:
```
urbanpoints://merchant/offers/OFF_12345
https://urbanpoints.app/m/offers/OFF_12345
```

**Target Screen**: `OfferDetailScreen(offerId: 'OFF_12345')`

**Use Cases**:
- "Your offer was approved!"
- "Offer needs attention"

---

### 3. Create Offer Screen

**Purpose**: Start offer creation flow  
**URL Pattern**: `urbanpoints://merchant/offers/create`  
**Universal Link**: `https://urbanpoints.app/m/offers/create`

**Example**:
```
urbanpoints://merchant/offers/create
https://urbanpoints.app/m/offers/create
```

**Target Screen**: `CreateOfferScreen()`

**Use Cases**:
- "Create your first offer"
- Re-engagement: "Time for a new promotion"

---

### 4. Dashboard/Analytics

**Purpose**: View performance stats  
**URL Pattern**: `urbanpoints://merchant/dashboard`  
**Universal Link**: `https://urbanpoints.app/m/dashboard`

**Example**:
```
urbanpoints://merchant/dashboard
https://urbanpoints.app/m/dashboard
```

**Target Screen**: `MerchantHomePage(selectedTab: 0)` (Dashboard tab)

**Use Cases**:
- "Your weekly summary is ready"
- Performance alerts

---

### 5. Redemption History

**Purpose**: View recent validations  
**URL Pattern**: `urbanpoints://merchant/redemptions`  
**Universal Link**: `https://urbanpoints.app/m/redemptions`

**Example**:
```
urbanpoints://merchant/redemptions
https://urbanpoints.app/m/redemptions
```

**Target Screen**: `RedemptionHistoryScreen()`

**Use Cases**:
- "Transaction completed"
- Daily/weekly redemption summary

---

### 6. Home Screen (Default)

**Purpose**: Fallback route  
**URL Pattern**: `urbanpoints://merchant` or `urbanpoints://merchant/home`  
**Universal Link**: `https://urbanpoints.app/m` or `https://urbanpoints.app/m/home`

**Example**:
```
urbanpoints://merchant
https://urbanpoints.app/m
```

**Target Screen**: `MerchantHomePage()`

**Use Cases**:
- Generic app open
- Onboarding completion

---

## Route Parsing Logic

### Deep Link Handler Service

```dart
import 'package:flutter/material.dart';

class DeepLinkRouter {
  /// Parse and navigate to deep link route
  static Future<void> handleDeepLink(
    BuildContext context,
    Uri uri,
  ) async {
    // Extract path segments
    final pathSegments = uri.pathSegments;
    
    if (pathSegments.isEmpty) {
      // Default: Home screen
      _navigateToHome(context);
      return;
    }

    final firstSegment = pathSegments[0];

    // Customer app routes
    switch (firstSegment) {
      case 'offers':
        if (pathSegments.length > 1) {
          _navigateToOfferDetail(context, pathSegments[1]);
        } else {
          _navigateToOfferslist(context);
        }
        break;

      case 'qr':
        _navigateToQRScreen(context);
        break;

      case 'history':
        _navigateToHistory(context);
        break;

      case 'merchants':
        if (pathSegments.length > 1) {
          _navigateToMerchantDetail(context, pathSegments[1]);
        }
        break;

      case 'profile':
        _navigateToProfile(context);
        break;

      case 'validate': // Merchant app
        _navigateToValidateScreen(context);
        break;

      case 'dashboard': // Merchant app
        _navigateToDashboard(context);
        break;

      case 'redemptions': // Merchant app
        _navigateToRedemptions(context);
        break;

      default:
        _navigateToHome(context);
    }
  }

  // Navigation helpers
  static void _navigateToOfferDetail(BuildContext context, String offerId) {
    Navigator.pushNamed(
      context,
      '/offer-detail',
      arguments: {'offerId': offerId},
    );
  }

  static void _navigateToQRScreen(BuildContext context) {
    Navigator.pushNamed(context, '/qr-generation');
  }

  static void _navigateToHistory(BuildContext context) {
    Navigator.pushNamed(context, '/points-history');
  }

  static void _navigateToMerchantDetail(BuildContext context, String merchantId) {
    Navigator.pushNamed(
      context,
      '/merchant-detail',
      arguments: {'merchantId': merchantId},
    );
  }

  static void _navigateToProfile(BuildContext context) {
    Navigator.pushNamed(context, '/profile');
  }

  static void _navigateToValidateScreen(BuildContext context) {
    Navigator.pushNamed(context, '/validate-redemption');
  }

  static void _navigateToDashboard(BuildContext context) {
    Navigator.pushNamed(context, '/home');
  }

  static void _navigateToRedemptions(BuildContext context) {
    Navigator.pushNamed(context, '/redemption-history');
  }

  static void _navigateToOfferslist(BuildContext context) {
    Navigator.pushNamed(context, '/home');
  }

  static void _navigateToHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
    );
  }
}
```

---

## Named Routes Configuration

### main.dart Routes

```dart
MaterialApp(
  title: 'Urban Points Lebanon',
  routes: {
    '/': (context) => const AuthWrapper(),
    '/home': (context) => const CustomerHomePage(),
    '/offer-detail': (context) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      return OfferDetailScreen(offerId: args['offerId']);
    },
    '/qr-generation': (context) => const QRGenerationScreen(),
    '/points-history': (context) => const PointsHistoryScreen(),
    '/merchant-detail': (context) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      return MerchantDetailScreen(merchantId: args['merchantId']);
    },
    '/profile': (context) => const ProfileScreen(),
    '/validate-redemption': (context) => const ValidateRedemptionScreen(),
    '/redemption-history': (context) => const RedemptionHistoryScreen(),
  },
  onGenerateRoute: (settings) {
    // Handle dynamic routes
    if (settings.name == '/offer-detail') {
      final args = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (_) => OfferDetailScreen(offerId: args['offerId']),
      );
    }
    
    // Fallback
    return MaterialPageRoute(
      builder: (_) => const CustomerHomePage(),
    );
  },
);
```

---

## Query Parameters Support

### Extended URL Patterns with Parameters

**Example**: Open offer with specific action
```
urbanpoints://customer/offers/OFF_12345?action=redeem
https://urbanpoints.app/c/offers/OFF_12345?action=redeem
```

**Parsing**:
```dart
static Future<void> handleDeepLink(
  BuildContext context,
  Uri uri,
) async {
  final pathSegments = uri.pathSegments;
  final queryParams = uri.queryParameters;

  if (pathSegments.isNotEmpty && pathSegments[0] == 'offers') {
    final offerId = pathSegments[1];
    final action = queryParams['action']; // 'redeem', 'share', etc.
    
    _navigateToOfferDetail(
      context,
      offerId,
      initialAction: action,
    );
  }
}
```

**Use Cases**:
- Pre-select redemption button
- Auto-scroll to specific section
- Track campaign source

---

## Universal Links Configuration (iOS/Android)

### Android App Links (AndroidManifest.xml)

```xml
<activity
    android:name=".MainActivity"
    android:launchMode="singleTop">
    
    <!-- Existing intent filters -->
    
    <!-- Deep Link Intent Filter -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        
        <!-- Custom URL Scheme -->
        <data android:scheme="urbanpoints" android:host="customer" />
        
        <!-- Universal Links (HTTPS) -->
        <data
            android:scheme="https"
            android:host="urbanpoints.app"
            android:pathPrefix="/c" />
    </intent-filter>
</activity>
```

### iOS Universal Links (Info.plist) - SPECIFICATION ONLY

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.urbanpoints.customer</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>urbanpoints</string>
        </array>
    </dict>
</array>

<!-- Associated Domains for Universal Links -->
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:urbanpoints.app</string>
</array>
```

**Note**: iOS universal links require server-side `.well-known/apple-app-site-association` file.

---

## Route Summary Table

| Route | Customer URL | Merchant URL | Target Screen | Priority |
|-------|--------------|--------------|---------------|----------|
| Offer Detail | `/offers/{id}` | `/offers/{id}` | OfferDetailScreen | P0 |
| QR Screen | `/qr` | `/validate` | QR Screens | P0 |
| Points/History | `/history` | `/redemptions` | History Screens | P1 |
| Merchant Detail | `/merchants/{id}` | N/A | MerchantDetailScreen | P1 |
| Profile | `/profile` | `/profile` | ProfileScreen | P2 |
| Dashboard | `/home` | `/dashboard` | Home Screens | P2 |
| Create Offer | N/A | `/offers/create` | CreateOfferScreen | P1 |

---

## Error Handling

### Invalid Route Handling

```dart
static void handleDeepLink(BuildContext context, Uri uri) {
  try {
    // Parse and route
    _parseAndNavigate(context, uri);
  } catch (e) {
    // Log error
    if (kDebugMode) {
      debugPrint('Deep link error: $e');
    }
    
    // Fallback: Navigate to home
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
    );
    
    // Show user-friendly message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invalid link. Redirecting to home.'),
      ),
    );
  }
}
```

### Authentication Gate

```dart
static void navigateToProtectedRoute(
  BuildContext context,
  String route,
) {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    // Store intended route
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('pending_route', route);
    });
    
    // Navigate to login
    Navigator.pushNamed(context, '/login');
  } else {
    // User authenticated, proceed
    Navigator.pushNamed(context, route);
  }
}

// After login success:
void onLoginSuccess(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final pendingRoute = prefs.getString('pending_route');
  
  if (pendingRoute != null) {
    await prefs.remove('pending_route');
    Navigator.pushReplacementNamed(context, pendingRoute);
  } else {
    Navigator.pushReplacementNamed(context, '/home');
  }
}
```

---

## Analytics Tracking

### Track Deep Link Usage

```dart
static void handleDeepLink(BuildContext context, Uri uri) {
  // Track deep link open
  FirebaseAnalytics.instance.logEvent(
    name: 'deep_link_opened',
    parameters: {
      'link_scheme': uri.scheme,
      'link_host': uri.host,
      'link_path': uri.path,
      'source': uri.queryParameters['source'] ?? 'unknown',
    },
  );
  
  // Continue with routing
  _parseAndNavigate(context, uri);
}
```

---

**Status**: ✅ DEEP LINK ROUTES COMPLETE  
**Implementation Effort**: 6-8 hours (routing logic + manifest config)  
**Growth Impact**: HIGH (enables push and campaign re-engagement)  
**Risk Level**: MEDIUM (requires proper testing, no backend changes)

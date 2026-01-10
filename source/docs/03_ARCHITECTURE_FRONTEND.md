# Urban Points Lebanon - Frontend Architecture

## Technology Stacks

### Mobile Apps (Customer, Merchant, Admin)
- **Framework**: Flutter 3.35.4
- **Language**: Dart 3.9.2
- **State Management**: Provider
- **Local Storage**: Hive + hive_flutter (document DB), shared_preferences (key-value)
- **HTTP Client**: http package
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **QR Code**: qr_flutter, qr_code_scanner
- **Image Handling**: cached_network_image
- **Maps**: google_maps_flutter

### Web Admin Dashboard
- **Stack**: Static HTML/CSS/JavaScript
- **Hosting**: Firebase Hosting
- **API Integration**: Fetch API
- **UI Framework**: Custom CSS

---

## Mobile App Architecture

### Directory Structure (All Mobile Apps)

```
apps/mobile-{customer|merchant|admin}/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── firebase_options.dart     # Firebase configuration
│   ├── models/                   # Data models
│   │   ├── customer.dart
│   │   ├── merchant.dart
│   │   └── offer.dart
│   ├── services/                 # Business logic services
│   │   ├── auth_service.dart
│   │   └── fcm_service.dart
│   └── screens/                  # UI screens
│       ├── auth/
│       │   ├── login_screen.dart
│       │   └── signup_screen.dart
│       └── [app-specific screens]
├── android/                      # Android configuration
├── ios/                          # iOS configuration
├── web/                          # Web build output
└── pubspec.yaml                  # Dependencies
```

### Common Dependencies (All Apps)

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: 3.6.0
  firebase_auth: 5.3.1
  cloud_firestore: 5.4.3
  firebase_messaging: 15.1.3
  provider: 6.1.5+1
  hive: 2.2.3
  hive_flutter: 1.1.0
  shared_preferences: 2.5.3
  http: 1.5.0
  cached_network_image: 3.4.1
  qr_flutter: 4.1.0
  qr_code_scanner: 1.0.1
  google_maps_flutter: 2.5.0
```

---

## Customer Mobile App

### Main User Flows

1. **Onboarding → Authentication → Home**
2. **Browse Offers → View Details → Redeem**
3. **View Wallet → Transaction History**
4. **Profile → Settings → Subscription**

### Key Screens

| Screen | Purpose | Key Features |
|--------|---------|--------------|
| Splash | App initialization | Branding, Firebase init |
| Onboarding | First-time user guidance | Swipeable cards, skip option |
| Login | User authentication | Email/phone + password |
| Signup | Account creation | Form validation, referral code |
| Home | Main dashboard | Featured offers, wallet balance |
| Offers List | Browse all offers | Filters, search, categories |
| Offer Details | Detailed offer view | Description, terms, merchant info |
| QR Generator | Generate redemption QR | 60-second countdown timer |
| Wallet | Points balance | Current balance, transaction log |
| History | Past redemptions | List view, filters |
| Profile | User account | Edit details, photo upload |
| Settings | App preferences | Notifications, language |
| Subscription | Premium tiers | Silver/Gold plans, payment |

### State Management Pattern

```dart
// Provider pattern for state
class OffersProvider extends ChangeNotifier {
  List<Offer> _offers = [];
  bool _isLoading = false;

  Future<void> fetchOffers() async {
    _isLoading = true;
    notifyListeners();
    
    _offers = await FirestoreService.getOffers();
    
    _isLoading = false;
    notifyListeners();
  }
}

// Usage in UI
Consumer<OffersProvider>(
  builder: (context, provider, child) {
    if (provider.isLoading) return CircularProgressIndicator();
    return ListView.builder(...);
  }
)
```

---

## Merchant Mobile App

### Main User Flows

1. **Authentication → Dashboard**
2. **Create Offer → Submit for Approval**
3. **Scan Customer QR → Validate Redemption**
4. **View Analytics → Review Performance**

### Key Screens

| Screen | Purpose | Key Features |
|--------|---------|--------------|
| Login | Merchant authentication | Business credentials |
| Dashboard | Merchant home | Quick stats, pending offers |
| Offers Management | CRUD for offers | Create, edit, delete offers |
| QR Scanner | Validate redemptions | Camera access, validation |
| Analytics | Performance metrics | Charts, top offers |
| Profile | Business profile | Edit details, branches |

---

## Admin Mobile App

### Main User Flows

1. **Authentication → Admin Dashboard**
2. **Review Merchants → Approve/Reject**
3. **Moderate Offers → Approve/Reject**
4. **View System Analytics**

### Key Screens

| Screen | Purpose | Key Features |
|--------|---------|--------------|
| Login | Admin authentication | Secure login |
| Dashboard | System overview | Key metrics, alerts |
| Merchants | Merchant management | Approve, block, view details |
| Offers | Offer moderation | Approve, reject, edit |
| Analytics | System analytics | Charts, exports |
| Settings | System configuration | Parameters, rules |

---

## API Integration Layer

### Centralized API Client

```dart
class ApiClient {
  static final baseUrl = 'https://us-central1-urbangenspark.cloudfunctions.net';
  
  static Future<Map<String, dynamic>> callFunction(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    
    final response = await http.post(
      Uri.parse('$baseUrl/$functionName'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );
    
    return jsonDecode(response.body);
  }
}
```

---

## Web Admin Dashboard

### Technology
- Pure HTML/CSS/JavaScript (no framework)
- Firebase SDK (client-side)
- Responsive design (mobile-friendly)

### Key Features
- Merchant approval interface
- Offer moderation
- System metrics dashboard
- User management

---

**Document Version**: 1.0
**Last Updated**: November 2025

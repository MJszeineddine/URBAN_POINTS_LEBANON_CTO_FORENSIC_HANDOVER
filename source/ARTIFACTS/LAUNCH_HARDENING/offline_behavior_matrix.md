# Offline Behavior Matrix

**Module**: C2 — Offline Safety Net (P1)  
**Purpose**: Prevent "app feels broken" states when network unavailable  
**Technology**: Firestore offline persistence + connectivity_plus  
**Status**: Complete

---

## Overview

Define behavior for each screen/feature when offline to ensure graceful degradation instead of error states.

---

## Offline Detection Strategy

### Technology Stack
```yaml
dependencies:
  connectivity_plus: ^8.0.1  # Network state monitoring
  cloud_firestore: 5.4.3      # Has built-in offline persistence
```

### Connectivity Service
```dart
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  
  /// Check current connectivity status
  static Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
  
  /// Stream of connectivity changes
  static Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map((result) {
      return result != ConnectivityResult.none;
    });
  }
}
```

---

## Screen-by-Screen Offline Behavior

### CUSTOMER APP

#### 1. Home Screen (Offers List)

**Online Behavior**:
- Fetch offers from Firestore
- Real-time updates via snapshot listener
- Images load from URLs

**Offline Behavior**:
```
┌─────────────────────────────────────────┐
│ [!] Offline Mode                        │  ← Banner at top
│     Showing cached offers               │
├─────────────────────────────────────────┤
│                                         │
│  [Offer Card 1 - Cached]                │
│  [Offer Card 2 - Cached]                │
│  [Offer Card 3 - Cached]                │
│                                         │
│  ⟳ Tap to retry                         │  ← If no cache
└─────────────────────────────────────────┘
```

**Implementation**:
- Firestore offline persistence automatically caches queries
- Show banner: "Offline Mode • Showing cached offers"
- Disable pull-to-refresh (or show "No connection" on attempt)
- If no cache available: Show empty state with retry button

**Code Pattern**:
```dart
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
    .collection('offers')
    .where('is_active', isEqualTo: true)
    .snapshots(),
  builder: (context, snapshot) {
    // Check metadata for cache source
    if (snapshot.hasData && snapshot.data!.metadata.isFromCache) {
      // Show offline banner
      _showOfflineBanner();
    }
    
    if (snapshot.hasError) {
      return OfflineErrorWidget(
        onRetry: () => setState(() {}),
      );
    }
    
    if (!snapshot.hasData) {
      return const CircularProgressIndicator();
    }
    
    return ListView.builder(...);
  },
)
```

---

#### 2. Offer Detail Screen

**Online Behavior**:
- Load offer details
- Load merchant info
- Display redemption button

**Offline Behavior**:
```
┌─────────────────────────────────────────┐
│ [← Back]                                │
│                                         │
│  [Cached Offer Image]                   │
│                                         │
│  Offer Title (cached)                   │
│  Description (cached)                   │
│  Points Required: 500 (cached)          │
│                                         │
│  [!] Offline - Cannot redeem now        │  ← Disabled button with message
│                                         │
│  Merchant: XYZ Store (cached)           │
└─────────────────────────────────────────┘
```

**Implementation**:
- Display cached offer data
- **Disable "Redeem" button** with tooltip: "Connect to internet to redeem"
- Merchant info from cache (if available)
- No real-time stock/availability updates

---

#### 3. QR Code Generation Screen

**Online Behavior**:
- Generate secure QR with backend token
- Display 6-digit code
- Show expiration timer

**Offline Behavior**:
```
┌─────────────────────────────────────────┐
│  My QR Code                             │
│                                         │
│     [!] No Connection                   │
│                                         │
│  Cannot generate QR code offline.      │
│  QR codes require secure validation.   │
│                                         │
│  ┌─────────────────────┐               │
│  │   Connect & Retry   │               │
│  └─────────────────────┘               │
│                                         │
│  Last generated:                        │
│  • Expired 5 min ago (if available)     │
└─────────────────────────────────────────┘
```

**Implementation**:
- **Block QR generation** (requires Cloud Function call)
- Show clear message: "QR codes require internet connection"
- Display last generated QR if still valid (<15 min ago) from cache
- Provide retry button that checks connectivity first

**Rationale**: QR tokens must be cryptographically secure and validated server-side. Offline generation would compromise security.

---

#### 4. Points History Screen

**Online Behavior**:
- Fetch redemption history
- Real-time balance updates

**Offline Behavior**:
```
┌─────────────────────────────────────────┐
│ Points History                          │
│                                         │
│ [!] Offline • Showing cached history    │  ← Banner
│                                         │
│ Current Balance: 1,250 pts (cached)     │
│                                         │
│ Recent Activity (cached):               │
│ • Dec 28: +500 pts - XYZ Store          │
│ • Dec 25: -300 pts - Redeemed Offer     │
│ • Dec 20: +400 pts - ABC Store          │
│                                         │
│ ⟳ Refresh (disabled)                    │
└─────────────────────────────────────────┘
```

**Implementation**:
- Display cached balance and history
- Show offline banner
- Disable pull-to-refresh with message
- Show last sync time: "Last updated: 10 minutes ago"

---

#### 5. Profile Screen

**Online Behavior**:
- Display user profile
- Allow edits with Firestore updates

**Offline Behavior**:
```
┌─────────────────────────────────────────┐
│ Profile                                 │
│                                         │
│ [Profile Photo - cached]                │
│ Name: John Doe (cached)                 │
│ Email: john@example.com (cached)        │
│ Phone: +961 XXX (cached)                │
│                                         │
│ [!] Offline - Changes will sync later   │  ← Warning banner
│                                         │
│ ┌────────────┐                          │
│ │ Edit       │ ← Enabled (local edits) │
│ └────────────┘                          │
└─────────────────────────────────────────┘
```

**Implementation**:
- Allow profile edits in offline mode
- Queue changes locally (Firestore handles sync when online)
- Show banner: "Offline • Changes will sync when connected"
- Validation still works (email format, required fields)

---

### MERCHANT APP

#### 1. Home Screen (Dashboard)

**Online Behavior**:
- Real-time redemption stats
- Today's earnings
- Active offers count

**Offline Behavior**:
```
┌─────────────────────────────────────────┐
│ Dashboard                               │
│                                         │
│ [!] Offline • Showing last known data   │
│                                         │
│ Today's Stats (cached):                 │
│ • Redemptions: 12 (as of 10:30 AM)      │
│ • Points Awarded: 3,400                 │
│ • Active Offers: 5                      │
│                                         │
│ ⟳ Reconnect for live updates            │
└─────────────────────────────────────────┘
```

**Implementation**:
- Display last cached statistics
- Show timestamp: "Last updated: 10:30 AM"
- Disable real-time listener
- Retry button attempts reconnection

---

#### 2. QR Validation Screen

**Online Behavior**:
- Scan customer QR
- Validate with Cloud Function
- Award points immediately

**Offline Behavior**:
```
┌─────────────────────────────────────────┐
│ Validate QR                             │
│                                         │
│   [!] No Internet Connection            │
│                                         │
│  QR validation requires internet        │
│  to prevent fraud and ensure security.  │
│                                         │
│  Please connect to:                     │
│  • WiFi                                 │
│  • Mobile data                          │
│                                         │
│  ┌─────────────────────┐               │
│  │   Retry Connection  │               │
│  └─────────────────────┘               │
└─────────────────────────────────────────┘
```

**Implementation**:
- **Block QR scanning** when offline
- Show prominent error: "Internet required for validation"
- Disable camera access
- Provide clear retry with connectivity check

**Rationale**: QR validation requires real-time fraud checks and token verification. Offline validation would enable abuse.

---

#### 3. My Offers Screen

**Online Behavior**:
- Display merchant's offers
- Edit/delete functionality
- Create new offers

**Offline Behavior**:
```
┌─────────────────────────────────────────┐
│ My Offers                               │
│                                         │
│ [!] Offline Mode                        │
│                                         │
│ [Offer 1 - cached]                      │
│ [Offer 2 - cached]                      │
│ [Offer 3 - cached]                      │
│                                         │
│ ┌──────────────────┐                    │
│ │ Create Offer     │ ← Disabled         │
│ └──────────────────┘                    │
│                                         │
│ Note: Editing requires internet         │
└─────────────────────────────────────────┘
```

**Implementation**:
- Show cached offers (read-only)
- Disable "Create Offer" button with tooltip
- Allow viewing offer details
- Block edit/delete actions with message

---

#### 4. Analytics Screen

**Online Behavior**:
- Fetch redemption analytics
- Chart data
- Export reports

**Offline Behavior**:
```
┌─────────────────────────────────────────┐
│ Analytics                               │
│                                         │
│ [!] Offline • Last snapshot             │
│                                         │
│ [Cached Chart - Last 7 Days]            │
│                                         │
│ Summary (cached from Dec 28, 10 AM):    │
│ • Total Redemptions: 245                │
│ • Total Points: 68,400                  │
│ • Most Popular Offer: 20% Off           │
│                                         │
│ 📊 Export (disabled offline)            │
└─────────────────────────────────────────┘
```

**Implementation**:
- Display last cached analytics data
- Show cache timestamp prominently
- Disable export functionality
- Charts render from cached data

---

## Offline Banner Component

### Universal Banner Widget

```dart
class OfflineBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const OfflineBanner({
    super.key,
    this.message = 'Offline Mode • Showing cached data',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.orange.withValues(alpha: 0.2),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 20, color: Colors.orange[900]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.orange[900],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}
```

---

## Empty State Fallback Widget

### When No Cache Available

```dart
class NoDataOfflineWidget extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const NoDataOfflineWidget({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Retry CTA Rules

### When to Show Retry Button

| Scenario | Show Retry | Behavior |
|----------|-----------|----------|
| Cached data available | Optional (banner) | Refreshes data on tap |
| No cached data | **Required** | Attempts reconnection, shows loading |
| Security-critical action (QR) | **Required** | Checks connectivity, then proceeds |
| Profile edit attempted | No retry needed | Queues for later sync |
| Cloud Function required | **Required** | Must be online to proceed |

### Retry Button Implementation

```dart
Future<void> _handleRetry() async {
  // Check connectivity first
  final isOnline = await ConnectivityService.isOnline();
  
  if (!isOnline) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Still offline. Please check your connection.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }
  
  // Trigger data reload
  setState(() {
    _isLoading = true;
  });
  
  try {
    await _fetchData();
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
```

---

## Connectivity State Management

### Global Connectivity Provider

```dart
class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  StreamSubscription<bool>? _subscription;

  bool get isOnline => _isOnline;

  ConnectivityProvider() {
    _initConnectivity();
  }

  void _initConnectivity() async {
    _isOnline = await ConnectivityService.isOnline();
    notifyListeners();

    _subscription = ConnectivityService.onConnectivityChanged.listen((online) {
      _isOnline = online;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

### Usage in Widgets

```dart
@override
Widget build(BuildContext context) {
  return ChangeNotifierProvider(
    create: (_) => ConnectivityProvider(),
    child: Consumer<ConnectivityProvider>(
      builder: (context, connectivity, child) {
        if (!connectivity.isOnline) {
          return Column(
            children: [
              OfflineBanner(),
              Expanded(child: _buildCachedContent()),
            ],
          );
        }
        return _buildOnlineContent();
      },
    ),
  );
}
```

---

## Summary Matrix

| Feature | Offline Behavior | Cache Used | Retry CTA | Risk Level |
|---------|------------------|-----------|-----------|-----------|
| **Customer App** | | | | |
| Offers List | Show cached | ✅ Yes | Optional | Low |
| Offer Detail | Show cached | ✅ Yes | No | Low |
| QR Generation | Block action | ❌ No | Required | High (security) |
| Points History | Show cached | ✅ Yes | Optional | Low |
| Profile View | Show cached | ✅ Yes | No | Low |
| Profile Edit | Allow (queue) | N/A | No | Low |
| **Merchant App** | | | | |
| Dashboard | Show cached | ✅ Yes | Optional | Low |
| QR Validation | Block action | ❌ No | Required | High (security) |
| Offers List | Show cached | ✅ Yes | No | Low |
| Create Offer | Block action | ❌ No | Required | Medium |
| Analytics | Show cached | ✅ Yes | Optional | Low |

---

## Implementation Checklist

- [ ] Enable Firestore offline persistence in app initialization
- [ ] Add `connectivity_plus` dependency
- [ ] Create `ConnectivityService` utility class
- [ ] Create `OfflineBanner` reusable widget
- [ ] Create `NoDataOfflineWidget` for empty states
- [ ] Add cache metadata checks in StreamBuilders
- [ ] Implement retry logic for critical actions
- [ ] Block QR generation/validation when offline
- [ ] Add offline mode tests
- [ ] Document offline behavior in user help section

---

**Status**: ✅ OFFLINE BEHAVIOR MATRIX COMPLETE  
**Implementation Effort**: 6-8 hours  
**User Impact**: HIGH (prevents confusion, maintains trust)  
**Risk Level**: LOW (leverages built-in Firestore persistence)

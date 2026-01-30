# UX Guardrails

**Module**: C5 — UX Guardrails (ZERO-RISK)  
**Purpose**: Store reviewer safety and user confidence  
**Status**: Complete

---

## Overview

Comprehensive UX standards to ensure:
1. **No blank screens** during normal operation
2. **Clear loading states** for all async operations
3. **Helpful error messages** instead of technical errors
4. **Empty state guidance** when no data exists
5. **Store reviewer confidence** (no broken states)

---

## Empty State Inventory

### CUSTOMER APP

#### 1. Offers List Empty State

**Trigger**: No active offers in system  
**Screen**: Home Screen (Offers Tab)

```
┌─────────────────────────────────────────┐
│ Urban Points Lebanon                    │
├─────────────────────────────────────────┤
│                                         │
│            🎁                           │
│                                         │
│      No Offers Available Yet            │
│                                         │
│   We're partnering with local           │
│   merchants to bring you exclusive      │
│   deals. Check back soon!               │
│                                         │
│   ┌─────────────────────┐              │
│   │  Explore Merchants  │              │
│   └─────────────────────┘              │
│                                         │
└─────────────────────────────────────────┘
```

**Component**:
```dart
class OffersEmptyState extends StatelessWidget {
  const OffersEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.card_giftcard_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No Offers Available Yet',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'We\'re partnering with local merchants to bring you exclusive deals. Check back soon!',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Navigate to merchants list
              },
              child: const Text('Explore Merchants'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

#### 2. Points History Empty State

**Trigger**: No transactions yet  
**Screen**: Points History Screen

```
┌─────────────────────────────────────────┐
│ ← Points History                        │
├─────────────────────────────────────────┤
│                                         │
│   Current Balance                       │
│   0 points                              │
│                                         │
│ ──────────────────────────────────────  │
│                                         │
│            📊                           │
│                                         │
│      No Transactions Yet                │
│                                         │
│   Visit a partner merchant and          │
│   show your QR code to earn your        │
│   first points!                         │
│                                         │
│   ┌─────────────────────┐              │
│   │   View My QR Code   │              │
│   └─────────────────────┘              │
│                                         │
└─────────────────────────────────────────┘
```

---

#### 3. Search Results Empty State

**Trigger**: Search query returns no offers  
**Screen**: Offers List (After Search)

```
┌─────────────────────────────────────────┐
│ 🔍 "pizza"                       ✕      │
├─────────────────────────────────────────┤
│                                         │
│            🔍                           │
│                                         │
│      No Results Found                   │
│                                         │
│   Try different keywords or browse      │
│   all available offers                  │
│                                         │
│   ┌─────────────────────┐              │
│   │   Clear Search      │              │
│   └─────────────────────┘              │
│                                         │
└─────────────────────────────────────────┘
```

---

#### 4. Merchants List Empty State

**Trigger**: No merchants in system (rare)  
**Screen**: Merchants Screen

```
┌─────────────────────────────────────────┐
│ Merchants                               │
├─────────────────────────────────────────┤
│                                         │
│            🏪                           │
│                                         │
│      No Merchants Yet                   │
│                                         │
│   We're onboarding local businesses.    │
│   Stay tuned for partner stores!        │
│                                         │
│   ┌─────────────────────┐              │
│   │   Back to Home      │              │
│   └─────────────────────┘              │
│                                         │
└─────────────────────────────────────────┘
```

---

### MERCHANT APP

#### 5. My Offers Empty State

**Trigger**: Merchant hasn't created any offers yet  
**Screen**: My Offers Screen

```
┌─────────────────────────────────────────┐
│ My Offers                               │
├─────────────────────────────────────────┤
│                                         │
│            📋                           │
│                                         │
│      No Offers Created Yet              │
│                                         │
│   Create your first offer to start      │
│   attracting customers with Urban       │
│   Points loyalty rewards                │
│                                         │
│   ┌─────────────────────┐              │
│   │   Create Offer      │              │
│   └─────────────────────┘              │
│                                         │
│   💡 Tip: Popular offers include        │
│      discounts and bonus points         │
│                                         │
└─────────────────────────────────────────┘
```

---

#### 6. Redemption History Empty State

**Trigger**: No redemptions processed yet  
**Screen**: Redemption History Screen

```
┌─────────────────────────────────────────┐
│ ← Redemption History                    │
├─────────────────────────────────────────┤
│                                         │
│            ✓                            │
│                                         │
│      No Redemptions Yet                 │
│                                         │
│   Scan customer QR codes to validate    │
│   and award points. Your redemption     │
│   history will appear here              │
│                                         │
│   ┌─────────────────────┐              │
│   │   Scan QR Code      │              │
│   └─────────────────────┘              │
│                                         │
└─────────────────────────────────────────┘
```

---

#### 7. Dashboard Empty State

**Trigger**: First-time merchant with no activity  
**Screen**: Dashboard (Zero Stats)

```
┌─────────────────────────────────────────┐
│ Dashboard                               │
├─────────────────────────────────────────┤
│                                         │
│   Today's Stats                         │
│   ┌───────────────┐                     │
│   │ Redemptions   │                     │
│   │      0        │                     │
│   └───────────────┘                     │
│                                         │
│   🚀 Get Started                        │
│                                         │
│   1. Create your first offer            │
│   2. Scan customer QR codes             │
│   3. Watch your stats grow!             │
│                                         │
│   ┌─────────────────────┐              │
│   │   Create Offer      │              │
│   └─────────────────────┘              │
│                                         │
└─────────────────────────────────────────┘
```

---

## Loading Skeleton Rules

### Principle: **Show Structure, Not Blank Space**

### Customer App Loading Skeletons

#### Offers List Loading

```dart
class OffersListSkeleton extends StatelessWidget {
  const OffersListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 5, // Show 5 placeholder cards
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.all(8.0),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 150,
                  color: Colors.white,
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 200,
                        height: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 150,
                        height: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 100,
                        height: 24,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

**Usage**:
```dart
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance.collection('offers').snapshots(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const OffersListSkeleton(); // ✅ Show skeleton
    }
    
    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return const OffersEmptyState(); // ✅ Show empty state
    }
    
    return ListView.builder(...); // ✅ Show data
  },
)
```

---

#### Profile Screen Loading

```
┌─────────────────────────────────────────┐
│ Profile                                 │
├─────────────────────────────────────────┤
│                                         │
│   [██████████]  ← Avatar skeleton       │
│                                         │
│   [█████████████████] ← Name skeleton   │
│   [████████████] ← Email skeleton       │
│                                         │
│   Points Balance                        │
│   [████████]    ← Balance skeleton      │
│                                         │
│   ┌────────────────────────┐           │
│   │   Loading...           │           │
│   └────────────────────────┘           │
│                                         │
└─────────────────────────────────────────┘
```

---

### Merchant App Loading Skeletons

#### Dashboard Stats Loading

```
┌─────────────────────────────────────────┐
│ Dashboard                               │
├─────────────────────────────────────────┤
│                                         │
│   Today's Stats                         │
│   ┌───────────────┬───────────────┐    │
│   │ Redemptions   │ Points Awarded│    │
│   │ [████████]    │ [████████]    │    │
│   └───────────────┴───────────────┘    │
│                                         │
│   Active Offers: [████]                 │
│                                         │
│   ┌─────────────────────────────┐      │
│   │   Loading data...           │      │
│   └─────────────────────────────┘      │
│                                         │
└─────────────────────────────────────────┘
```

---

## Error Message Standards

### Principle: **User-Friendly, Actionable, Non-Technical**

### Error Categories

#### 1. Network Errors

**❌ BAD**:
```
Error: SocketException: Failed to connect to 10.0.2.2:8080
```

**✅ GOOD**:
```
┌─────────────────────────────────────────┐
│            🌐                           │
│                                         │
│      No Internet Connection             │
│                                         │
│   Please check your connection and      │
│   try again                             │
│                                         │
│   ┌─────────────────────┐              │
│   │      Retry          │              │
│   └─────────────────────┘              │
│                                         │
└─────────────────────────────────────────┘
```

**Implementation**:
```dart
try {
  final response = await http.get(uri);
  // Process response
} on SocketException {
  _showErrorDialog(
    title: 'No Internet Connection',
    message: 'Please check your connection and try again',
    actionLabel: 'Retry',
    onAction: _retryFetch,
  );
} catch (e) {
  _showErrorDialog(
    title: 'Something Went Wrong',
    message: 'We couldn\'t load the data. Please try again.',
    actionLabel: 'Retry',
    onAction: _retryFetch,
  );
}
```

---

#### 2. Authentication Errors

**❌ BAD**:
```
FirebaseAuthException: [firebase_auth/user-not-found]
```

**✅ GOOD**:
```
┌─────────────────────────────────────────┐
│            ⚠️                           │
│                                         │
│      Login Failed                       │
│                                         │
│   Email or password is incorrect.       │
│   Please try again or reset your        │
│   password.                             │
│                                         │
│   ┌─────────────────────┐              │
│   │   Try Again         │              │
│   └─────────────────────┘              │
│                                         │
│   Forgot Password?                      │
│                                         │
└─────────────────────────────────────────┘
```

---

#### 3. Data Not Found Errors

**❌ BAD**:
```
Error: Document does not exist
```

**✅ GOOD**:
```
┌─────────────────────────────────────────┐
│            ℹ️                           │
│                                         │
│      Offer Not Available                │
│                                         │
│   This offer may have expired or        │
│   been removed by the merchant          │
│                                         │
│   ┌─────────────────────┐              │
│   │   View All Offers   │              │
│   └─────────────────────┘              │
│                                         │
└─────────────────────────────────────────┘
```

---

#### 4. Permission Errors

**❌ BAD**:
```
Error: Permission denied
```

**✅ GOOD** (Camera Permission for QR Scanner):
```
┌─────────────────────────────────────────┐
│            📷                           │
│                                         │
│      Camera Access Needed               │
│                                         │
│   To scan QR codes, please allow        │
│   camera access in your device          │
│   settings                              │
│                                         │
│   ┌─────────────────────┐              │
│   │   Open Settings     │              │
│   └─────────────────────┘              │
│                                         │
│   ┌─────────────────────┐              │
│   │   Cancel            │              │
│   └─────────────────────┘              │
│                                         │
└─────────────────────────────────────────┘
```

---

#### 5. Server Errors

**❌ BAD**:
```
Error 500: Internal Server Error
```

**✅ GOOD**:
```
┌─────────────────────────────────────────┐
│            🔧                           │
│                                         │
│      Service Temporarily Down           │
│                                         │
│   We're experiencing technical issues.  │
│   Please try again in a few minutes.    │
│                                         │
│   ┌─────────────────────┐              │
│   │      Retry          │              │
│   └─────────────────────┘              │
│                                         │
│   Still having issues?                  │
│   Contact Support                       │
│                                         │
└─────────────────────────────────────────┘
```

---

## Loading State Guidelines

### 1. Button Loading States

**❌ BAD**: Button disappears or stays enabled
**✅ GOOD**: Button shows loading indicator and disables

```dart
ElevatedButton(
  onPressed: _isLoading ? null : _handleSubmit,
  child: _isLoading
      ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
      : const Text('Submit'),
)
```

---

### 2. Full-Screen Loading

**Use Case**: Initial app load, authentication check

```dart
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            Image.asset(
              'assets/logo.png',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### 3. Pull-to-Refresh Loading

```dart
RefreshIndicator(
  onRefresh: _refreshData,
  child: ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) {
      return ListTile(title: Text(items[index]));
    },
  ),
)
```

---

### 4. Infinite Scroll Loading

```dart
ListView.builder(
  itemCount: items.length + (_isLoadingMore ? 1 : 0),
  itemBuilder: (context, index) {
    if (index == items.length) {
      // Loading indicator at bottom
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return ListTile(title: Text(items[index]));
  },
)
```

---

## Summary Checklist

### Empty States (ALL screens must have)
- [ ] Offers list empty state
- [ ] Points history empty state
- [ ] Search results empty state
- [ ] Merchants list empty state
- [ ] My offers empty state (Merchant)
- [ ] Redemption history empty state (Merchant)
- [ ] Dashboard zero state (Merchant)

### Loading States (ALL async operations must have)
- [ ] List loading skeleton
- [ ] Profile loading skeleton
- [ ] Dashboard loading skeleton
- [ ] Button loading indicator
- [ ] Full-screen loading (app launch)
- [ ] Pull-to-refresh indicator
- [ ] Infinite scroll loading

### Error Messages (ALL error paths must have)
- [ ] Network error dialog
- [ ] Authentication error dialog
- [ ] Data not found error
- [ ] Permission error dialog
- [ ] Server error dialog
- [ ] Validation error messages (forms)

---

## Implementation Priority

**P0 (Store Approval)**:
- Empty states for primary screens (Offers, History, Dashboard)
- Network error handling
- Loading skeletons for lists

**P1 (User Polish)**:
- Empty states for secondary screens
- Permission error dialogs
- Inline validation messages

**P2 (Nice-to-Have)**:
- Animated loading states
- Custom error illustrations
- Haptic feedback on errors

---

**Status**: ✅ UX GUARDRAILS COMPLETE  
**Implementation Effort**: 8-12 hours  
**Store Review Impact**: CRITICAL (prevents rejection for blank screens)  
**User Confidence**: HIGH (professional polish)

# Cache Policy

**Module**: C2 — Offline Safety Net  
**Purpose**: Define caching strategy for offline data availability  
**Technology**: Firestore offline persistence + local storage  
**Status**: Complete

---

## Overview

Establish clear caching rules for different data types to balance:
- **Data freshness** vs **Offline availability**
- **Storage usage** vs **User experience**
- **Security** vs **Convenience**

---

## Firestore Offline Persistence Configuration

### Initialization (main.dart)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // ✅ Enable Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Or set limit: 100 * 1024 * 1024 (100MB)
  );
  
  runApp(const MyApp());
}
```

### Cache Size Recommendations

| Platform | Recommended Size | Notes |
|----------|------------------|-------|
| Android | 100 MB | Balance between offline data and device storage |
| iOS | 100 MB | iOS manages cache more aggressively |
| Web | 40 MB | Browser quota limitations |

**Default**: `CACHE_SIZE_UNLIMITED` (Firestore manages automatically)  
**Recommended for Production**: 100 MB explicit limit

---

## Data Type Cache Policies

### 1. OFFERS (Customer App)

**Data Type**: Active offers list  
**Update Frequency**: Real-time (when online)  
**Cache Strategy**: **CACHE_FIRST**

```dart
// Firestore query with snapshot listener
FirebaseFirestore.instance
  .collection('offers')
  .where('is_active', isEqualTo: true)
  .where('valid_until', isGreaterThan: Timestamp.now())
  .snapshots(); // Automatically uses cache when offline
```

**Cache Behavior**:
- **Online**: Fresh data from server, cache updated automatically
- **Offline**: Serve from cache (last known state)
- **TTL**: Until manually refreshed or evicted by Firestore
- **Max Age**: 7 days (implicit - Firestore manages)

**Storage Estimate**: ~50-200 KB per 50 offers (with metadata)

---

### 2. MERCHANT DATA (Customer App)

**Data Type**: Merchant profiles (name, location, logo)  
**Update Frequency**: Low (merchants update infrequently)  
**Cache Strategy**: **CACHE_FIRST**

```dart
FirebaseFirestore.instance
  .collection('merchants')
  .doc(merchantId)
  .snapshots();
```

**Cache Behavior**:
- **Online**: Fetch on demand, cache indefinitely
- **Offline**: Serve from cache
- **TTL**: 30 days (implicit)
- **Invalidation**: Manual refresh or app restart

**Storage Estimate**: ~5-10 KB per merchant profile

---

### 3. CUSTOMER PROFILE (Customer App)

**Data Type**: User profile (name, email, points balance, photo URL)  
**Update Frequency**: Medium (user edits occasionally)  
**Cache Strategy**: **CACHE_AND_SYNC**

```dart
FirebaseFirestore.instance
  .collection('customers')
  .doc(userId)
  .snapshots();
```

**Cache Behavior**:
- **Online**: Real-time sync with server
- **Offline**: 
  - Read from cache
  - Write to cache, sync when online (Firestore handles automatically)
- **TTL**: Indefinite (user's own data)
- **Conflict Resolution**: Last-write-wins (Firestore default)

**Storage Estimate**: ~2-5 KB per user

---

### 4. POINTS HISTORY (Customer App)

**Data Type**: Redemption transactions  
**Update Frequency**: Real-time (when online)  
**Cache Strategy**: **CACHE_FIRST**

```dart
FirebaseFirestore.instance
  .collection('redemptions')
  .where('customer_id', isEqualTo: userId)
  .orderBy('created_at', descending: true)
  .limit(50) // Cache only recent history
  .snapshots();
```

**Cache Behavior**:
- **Online**: Real-time updates
- **Offline**: Display cached transactions
- **TTL**: 7 days
- **Limit**: Cache only last 50 transactions (reduces storage)

**Storage Estimate**: ~5-10 KB per 50 transactions

---

### 5. QR TOKENS (Customer App)

**Data Type**: Generated QR codes with secure tokens  
**Update Frequency**: Every 15 minutes (expiration)  
**Cache Strategy**: **NO_CACHE**

**Cache Behavior**:
- **Online**: Generate fresh token via Cloud Function
- **Offline**: **Block generation** (security requirement)
- **TTL**: 15 minutes (server-enforced)
- **Storage**: NOT cached (security risk)

**Rationale**: QR tokens must be cryptographically secure and validated server-side. Caching would enable replay attacks.

---

### 6. MERCHANT DASHBOARD STATS (Merchant App)

**Data Type**: Today's stats (redemptions, points awarded)  
**Update Frequency**: Real-time (when online)  
**Cache Strategy**: **CACHE_FIRST with timestamp**

```dart
// Custom caching with timestamp
class DashboardCache {
  static const String _keyStats = 'dashboard_stats';
  static const String _keyTimestamp = 'dashboard_stats_timestamp';
  static const Duration _maxAge = Duration(hours: 1);

  static Future<Map<String, dynamic>?> getCachedStats() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_keyTimestamp);
    
    if (timestamp != null) {
      final age = DateTime.now().difference(DateTime.parse(timestamp));
      if (age < _maxAge) {
        final json = prefs.getString(_keyStats);
        return json != null ? jsonDecode(json) : null;
      }
    }
    return null;
  }

  static Future<void> cacheStats(Map<String, dynamic> stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStats, jsonEncode(stats));
    await prefs.setString(_keyTimestamp, DateTime.now().toIso8601String());
  }
}
```

**Cache Behavior**:
- **Online**: Fetch fresh data, update cache
- **Offline**: Serve cache if < 1 hour old
- **TTL**: 1 hour
- **Display**: Show "Last updated: X minutes ago"

**Storage Estimate**: ~1-2 KB

---

### 7. MERCHANT OFFERS (Merchant App)

**Data Type**: Merchant's own offers  
**Update Frequency**: Medium (merchant edits)  
**Cache Strategy**: **CACHE_AND_SYNC**

```dart
FirebaseFirestore.instance
  .collection('offers')
  .where('merchant_id', isEqualTo: merchantId)
  .snapshots();
```

**Cache Behavior**:
- **Online**: Real-time sync
- **Offline**: Read-only access to cache
- **TTL**: Indefinite (merchant's own data)
- **Write Offline**: Block (requires admin approval)

**Storage Estimate**: ~10-50 KB per 20 offers

---

### 8. VALIDATION HISTORY (Merchant App)

**Data Type**: Recent QR validations  
**Update Frequency**: Real-time  
**Cache Strategy**: **CACHE_FIRST (limited)**

```dart
FirebaseFirestore.instance
  .collection('redemptions')
  .where('merchant_id', isEqualTo: merchantId)
  .orderBy('created_at', descending: true)
  .limit(100) // Cache only recent 100 validations
  .snapshots();
```

**Cache Behavior**:
- **Online**: Real-time updates
- **Offline**: Display cached validations
- **TTL**: 24 hours
- **Limit**: 100 most recent

**Storage Estimate**: ~10-20 KB per 100 validations

---

## Cache Invalidation Rules

### Automatic Invalidation Triggers

1. **App Update**: Clear cache on version mismatch
2. **User Logout**: Clear all user-specific cache
3. **Firestore SDK**: Automatic LRU eviction when cache full
4. **Manual Refresh**: User-initiated pull-to-refresh

### Manual Cache Clearing

```dart
class CacheManager {
  /// Clear all Firestore cache
  static Future<void> clearFirestoreCache() async {
    await FirebaseFirestore.instance.clearPersistence();
  }
  
  /// Clear specific user data cache
  static Future<void> clearUserCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dashboard_stats');
    await prefs.remove('dashboard_stats_timestamp');
    // Add other user-specific keys
  }
  
  /// Clear on logout
  static Future<void> clearOnLogout() async {
    await clearFirestoreCache();
    await clearUserCache();
  }
}
```

### Settings Integration

```dart
// Add to Settings screen
ListTile(
  leading: const Icon(Icons.cleaning_services_outlined),
  title: const Text('Clear Cached Data'),
  subtitle: const Text('Free up storage space'),
  onTap: () async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache?'),
        content: const Text('This will remove offline data. You\'ll need internet to reload.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await CacheManager.clearFirestoreCache();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache cleared')),
      );
    }
  },
)
```

---

## Cache Storage Estimates

### Customer App Total Storage

| Data Type | Estimate | Priority |
|-----------|----------|----------|
| Offers (50) | 200 KB | High |
| Merchants (20) | 200 KB | Medium |
| User Profile | 5 KB | High |
| Points History (50) | 10 KB | Medium |
| Images (thumbnails) | 2-5 MB | Low |
| **Total** | **~5.5 MB** | - |

### Merchant App Total Storage

| Data Type | Estimate | Priority |
|-----------|----------|----------|
| Dashboard Stats | 2 KB | High |
| Merchant Offers (20) | 50 KB | High |
| Validation History (100) | 20 KB | Medium |
| Analytics Cache | 10 KB | Low |
| **Total** | **~100 KB** | - |

**Note**: Image caching handled by Flutter's image cache (default: 1000 images or 100 MB)

---

## Performance Optimization

### Firestore Query Optimization

```dart
// ✅ GOOD - Limits cache size
FirebaseFirestore.instance
  .collection('offers')
  .where('is_active', isEqualTo: true)
  .limit(50) // Limit cached documents
  .snapshots();

// ❌ BAD - Caches potentially thousands of documents
FirebaseFirestore.instance
  .collection('offers')
  .snapshots();
```

### Selective Field Caching

```dart
// ✅ GOOD - Cache only needed fields
FirebaseFirestore.instance
  .collection('merchants')
  .doc(merchantId)
  .get()
  .then((doc) {
    // Extract only needed fields
    return {
      'name': doc.data()?['name'],
      'logo_url': doc.data()?['logo_url'],
    };
  });

// Avoids caching large fields like:
// - High-res images (use URLs instead)
// - Full address (if not displayed)
// - Internal metadata
```

---

## Cache Health Monitoring

### Diagnostic Function

```dart
class CacheHealthMonitor {
  /// Get cache size estimate
  static Future<Map<String, dynamic>> getCacheHealth() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Estimate SharedPreferences size
    final keys = prefs.getKeys();
    int sharedPrefsSize = 0;
    for (final key in keys) {
      final value = prefs.get(key);
      if (value is String) {
        sharedPrefsSize += value.length;
      }
    }
    
    return {
      'shared_prefs_size_kb': (sharedPrefsSize / 1024).toStringAsFixed(2),
      'shared_prefs_keys_count': keys.length,
      'firestore_cache_status': 'enabled', // Firestore doesn't expose size
      'last_sync': prefs.getString('last_successful_sync'),
    };
  }
  
  /// Log cache health (for debugging)
  static Future<void> logCacheHealth() async {
    final health = await getCacheHealth();
    if (kDebugMode) {
      debugPrint('Cache Health: $health');
    }
  }
}
```

---

## Offline-First Query Patterns

### Pattern 1: Prioritize Cache, Update in Background

```dart
Future<List<Offer>> getOffers() async {
  try {
    // Get from cache first (immediate)
    final cacheSnapshot = await FirebaseFirestore.instance
      .collection('offers')
      .get(const GetOptions(source: Source.cache));
    
    final cachedOffers = cacheSnapshot.docs
      .map((doc) => Offer.fromFirestore(doc.data(), doc.id))
      .toList();
    
    // If cache available, return immediately
    if (cachedOffers.isNotEmpty) {
      // Fetch from server in background
      _updateFromServer();
      return cachedOffers;
    }
    
    // No cache, fetch from server
    return await _fetchFromServer();
  } catch (e) {
    // Fallback to server
    return await _fetchFromServer();
  }
}

Future<void> _updateFromServer() async {
  // Non-blocking server fetch
  FirebaseFirestore.instance
    .collection('offers')
    .get(const GetOptions(source: Source.server))
    .then((snapshot) {
      // Triggers UI update via StreamBuilder
    });
}
```

### Pattern 2: Cache with Expiration Check

```dart
class CachedData<T> {
  final T data;
  final DateTime cachedAt;
  final Duration maxAge;

  CachedData(this.data, this.cachedAt, this.maxAge);

  bool get isExpired => DateTime.now().difference(cachedAt) > maxAge;
}

Future<List<Offer>> getOffersWithExpiry() async {
  // Check cache age
  final cache = await _getCachedOffers();
  
  if (cache != null && !cache.isExpired) {
    return cache.data;
  }
  
  // Cache expired or unavailable, fetch fresh
  return await _fetchAndCacheOffers();
}
```

---

## Security Considerations

### Data That Should NEVER Be Cached

1. **QR Tokens**: Cryptographic tokens expire quickly
2. **Auth Tokens**: Firebase handles, don't override
3. **Payment Info**: PCI compliance (even though app doesn't store cards)
4. **Admin Credentials**: Merchant/admin passwords
5. **Sensitive PII**: Beyond basic profile (addresses, IDs)

### Cache Encryption

**Note**: Firestore offline persistence is NOT encrypted by default.

**Recommendation for Sensitive Data**:
```dart
// If caching sensitive data in SharedPreferences:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const storage = FlutterSecureStorage();

// Write
await storage.write(key: 'sensitive_data', value: encryptedValue);

// Read
final value = await storage.read(key: 'sensitive_data');
```

**Status**: Current implementation does NOT cache sensitive data, so encryption not required.

---

## Testing Cache Behavior

### Manual Test Cases

1. **Offline Launch**: Airplane mode → Launch app → Verify cached data displays
2. **Cache Invalidation**: Clear cache → Launch offline → Verify empty state/retry
3. **Online→Offline→Online**: Verify smooth transitions
4. **Cache Size**: Monitor storage after 7 days of use
5. **Cache Clear**: Settings → Clear cache → Verify data refetches

### Automated Tests

```dart
testWidgets('Displays cached offers when offline', (tester) async {
  // Setup: Populate Firestore cache
  await setupFirestoreCache();
  
  // Simulate offline
  await ConnectivityService.setOfflineMode(true);
  
  // Launch app
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();
  
  // Verify cached offers displayed
  expect(find.text('Cached Offer 1'), findsOneWidget);
  expect(find.byType(OfflineBanner), findsOneWidget);
});
```

---

## Summary

| Aspect | Policy |
|--------|--------|
| **Primary Technology** | Firestore offline persistence (built-in) |
| **Cache Size Limit** | 100 MB (recommended) |
| **Default Behavior** | Cache-first for reads, sync writes when online |
| **Security Data** | Never cached (QR tokens, auth) |
| **User Control** | Manual cache clear in Settings |
| **TTL Strategy** | Firestore auto-manages, except custom stats (1h) |
| **Offline Writes** | Queued automatically by Firestore |
| **Storage Estimate** | Customer: ~5 MB, Merchant: ~100 KB |

---

**Status**: ✅ CACHE POLICY COMPLETE  
**Implementation Effort**: 3-4 hours (enable persistence + add cache clear)  
**User Impact**: HIGH (enables offline usage)  
**Risk Level**: LOW (leverages Firestore built-in features)

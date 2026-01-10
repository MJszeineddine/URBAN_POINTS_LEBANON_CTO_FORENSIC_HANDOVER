# Urban Points Lebanon - GitHub Copilot Context

## Repository Purpose

This monorepo contains the **complete Urban Points Lebanon ecosystem** - a loyalty and offers platform connecting consumers, merchants, and administrators in Lebanon. The system enables offer discovery, points earning/redemption, and merchant management.

---

## Quick Navigation

### Entry Points

**Backend (Firebase Cloud Functions)**:
- `backend/firebase-functions/src/index.ts` - Main Cloud Functions export file
- Key functions: generateSecureQRToken, validateRedemption, calculateDailyStats

**Mobile Apps**:
- `apps/mobile-customer/lib/main.dart` - Customer app entry
- `apps/mobile-merchant/lib/main.dart` - Merchant app entry  

**Web Admin**:
- `apps/web-admin/index.html` - Web admin dashboard

**Infrastructure**:
- `infra/firebase.json` - Firebase project configuration
- `infra/firestore.rules` - Database security rules
- `infra/firestore.indexes.json` - Query optimization indexes

**Deployment**:
- `scripts/deploy_production.sh` - One-command deployment
- `scripts/configure_firebase_env.sh` - Environment setup

---

## Module Organization

### Backend (`backend/firebase-functions/src/`)

```
index.ts              # Main entry (19 Cloud Functions)
├── Auth & Users      # User authentication, OTP verification
├── Points Economy    # Award/deduct points, atomic transactions
├── QR Security       # Generate/validate secure QR tokens
├── Redemptions       # Offer redemption logic
├── Offers            # Offer CRUD operations  
├── Subscriptions     # Premium tier management
privacy.ts            # GDPR compliance (export/delete data)
sms.ts                # SMS/OTP services
paymentWebhooks.ts    # Payment gateway webhooks (OMT, Whish, Stripe)
subscriptionAutomation.ts  # Subscription renewals, reminders
pushCampaigns.ts      # Push notification campaigns
```

### Mobile Apps (`apps/mobile-{customer|merchant|admin}/lib/`)

```
main.dart             # App entry point, Firebase initialization
firebase_options.dart # Platform-specific Firebase config
models/               # Data models (Customer, Merchant, Offer)
services/             # Business logic services
├── auth_service.dart      # Authentication
├── fcm_service.dart       # Push notifications
└── firestore_service.dart # Database operations
screens/              # UI screens
├── auth/             # Login, signup
├── home/             # Main dashboard
├── offers/           # Offer browsing, details, redemption
├── profile/          # User profile management
└── settings/         # App configuration
```

---

## How to Add New Features

### Example 1: Add New Offer Type (BOGO - Buy-One-Get-One)

**Step 1**: Update Data Model

```dart
// apps/mobile-customer/lib/models/offer.dart
class Offer {
  final String discountType; // Add 'bogof' to enum
  // existing fields...
  
  bool get isBOGOF => discountType == 'bogof';
}
```

**Step 2**: Update Backend Validation

```typescript
// backend/firebase-functions/src/index.ts
interface OfferValidationRules {
  discountType: 'percentage' | 'fixed_amount' | 'bogof'; // Add bogof
  // existing rules...
}

function validateOffer(offer: Offer) {
  if (offer.discountType === 'bogof') {
    // BOGOF-specific validation
    if (!offer.original_price) {
      throw new Error('BOGOF offers require original_price');
    }
  }
  // existing validation...
}
```

**Step 3**: Update UI

```dart
// apps/mobile-customer/lib/screens/offer_details_screen.dart
Widget buildDiscountBadge(Offer offer) {
  if (offer.isBOGOF) {
    return Badge(text: 'Buy 1 Get 1 FREE', color: Colors.green);
  }
  // existing badge logic...
}
```

**Step 4**: Update Firestore Rules

```javascript
// infra/firestore.rules
match /offers/{offerId} {
  allow create: if request.resource.data.discount_type in 
    ['percentage', 'fixed_amount', 'bogof'] && // Add bogof
    isValidOfferStructure(request.resource.data);
}
```

---

### Example 2: Add Merchant-Level Analytics Report

**Step 1**: Create Analytics Function

```typescript
// backend/firebase-functions/src/index.ts
export const getMerchantAnalytics = functions.https.onCall(
  async (data: { merchantId: string, period: string }, context) => {
    // Verify authentication
    if (!context.auth || context.auth.uid !== data.merchantId) {
      throw new functions.https.HttpsError('unauthenticated', 'Not authorized');
    }
    
    const db = admin.firestore();
    
    // Fetch redemptions for merchant
    const redemptions = await db.collection('redemptions')
      .where('merchant_id', '==', data.merchantId)
      .where('redeemed_at', '>=', getPeriodStartDate(data.period))
      .get();
    
    // Calculate metrics
    const metrics = {
      total_redemptions: redemptions.size,
      total_revenue: calculateRevenue(redemptions.docs),
      top_offers: getTopOffers(redemptions.docs),
      customer_demographics: getCustomerDemographics(redemptions.docs)
    };
    
    return { success: true, metrics };
  }
);
```

**Step 2**: Create Mobile UI Screen

```dart
// apps/mobile-merchant/lib/screens/analytics_details_screen.dart
class AnalyticsDetailsScreen extends StatefulWidget {
  @override
  _AnalyticsDetailsScreenState createState() => _AnalyticsDetailsScreenState();
}

class _AnalyticsDetailsScreenState extends State<AnalyticsDetailsScreen> {
  String selectedPeriod = 'week';
  Map<String, dynamic>? analyticsData;
  
  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }
  
  Future<void> _loadAnalytics() async {
    final result = await FirebaseFunctions.instance
      .httpsCallable('getMerchantAnalytics')
      .call({ 'merchantId': currentUserId, 'period': selectedPeriod });
    
    setState(() {
      analyticsData = result.data['metrics'];
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Analytics Details')),
      body: analyticsData == null 
        ? CircularProgressIndicator()
        : ListView(
            children: [
              MetricCard('Total Redemptions', analyticsData!['total_redemptions']),
              MetricCard('Revenue', '\$${analyticsData!['total_revenue']}'),
              TopOffersChart(analyticsData!['top_offers']),
              CustomerDemographicsChart(analyticsData!['customer_demographics']),
            ],
          ),
    );
  }
}
```

**Step 3**: Add Navigation

```dart
// apps/mobile-merchant/lib/screens/dashboard_screen.dart
ElevatedButton(
  child: Text('View Detailed Analytics'),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AnalyticsDetailsScreen()),
    );
  },
)
```

---

### Example 3: Add Push Notifications for Expiring Offers

**Step 1**: Create Scheduled Function

```typescript
// backend/firebase-functions/src/index.ts
export const sendOfferExpiryNotifications = functions.pubsub
  .schedule('every day 09:00')
  .timeZone('Asia/Beirut')
  .onRun(async (context) => {
    const db = admin.firestore();
    const messaging = admin.messaging();
    
    // Find offers expiring in 24 hours
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    
    const expiringOffers = await db.collection('offers')
      .where('status', '==', 'active')
      .where('valid_until', '<=', tomorrow)
      .where('valid_until', '>=', new Date())
      .get();
    
    // Get users who favorited these offers
    for (const offerDoc of expiringOffers.docs) {
      const offer = offerDoc.data();
      
      const usersWithFavorite = await db.collection('customers')
        .where('favorite_offer_ids', 'array-contains', offerDoc.id)
        .where('notification_enabled', '==', true)
        .get();
      
      // Send notification to each user
      const tokens = usersWithFavorite.docs
        .map(doc => doc.data().fcm_token)
        .filter(token => token);
      
      if (tokens.length > 0) {
        await messaging.sendMulticast({
          tokens: tokens,
          notification: {
            title: 'Offer Expiring Soon!',
            body: `"${offer.title}" expires tomorrow. Redeem now!`
          },
          data: {
            type: 'offer_expiring',
            offer_id: offerDoc.id
          }
        });
      }
    }
  });
```

**Step 2**: Handle Notification in App

```dart
// apps/mobile-customer/lib/services/fcm_service.dart
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  if (message.data['type'] == 'offer_expiring') {
    final offerId = message.data['offer_id'];
    
    // Show in-app notification
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(message.notification?.title ?? ''),
        content: Text(message.notification?.body ?? ''),
        actions: [
          TextButton(
            child: Text('View Offer'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OfferDetailsScreen(offerId: offerId),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
});
```

---

### Example 4: Add Customer Review System

**Step 1**: Update Data Model

```typescript
// backend/firebase-functions/src/index.ts
interface Review {
  id: string;
  user_id: string;
  merchant_id: string;
  offer_id?: string;
  redemption_id?: string;
  rating: number; // 1-5
  comment?: string;
  status: 'published' | 'pending_moderation' | 'rejected';
  merchant_response?: string;
  created_at: FirebaseFirestore.Timestamp;
}
```

**Step 2**: Create Cloud Function

```typescript
export const submitReview = functions.https.onCall(
  async (data: {merchantId: string, offerId?: string, rating: number, comment?: string}, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }
    
    // Validate rating
    if (data.rating < 1 || data.rating > 5) {
      throw new functions.https.HttpsError('invalid-argument', 'Rating must be 1-5');
    }
    
    const db = admin.firestore();
    const reviewRef = db.collection('reviews').doc();
    
    await reviewRef.set({
      id: reviewRef.id,
      user_id: context.auth.uid,
      merchant_id: data.merchantId,
      offer_id: data.offerId || null,
      rating: data.rating,
      comment: data.comment || null,
      status: 'pending_moderation',
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Update merchant average rating
    await updateMerchantRating(data.merchantId);
    
    return { success: true, review_id: reviewRef.id };
  }
);
```

**Step 3**: Add UI Screen

```dart
// apps/mobile-customer/lib/screens/submit_review_screen.dart
class SubmitReviewScreen extends StatefulWidget {
  final String merchantId;
  final String? offerId;
  
  SubmitReviewScreen({required this.merchantId, this.offerId});
  
  @override
  _SubmitReviewScreenState createState() => _SubmitReviewScreenState();
}

class _SubmitReviewScreenState extends State<SubmitReviewScreen> {
  int rating = 0;
  final commentController = TextEditingController();
  
  Future<void> _submitReview() async {
    try {
      await FirebaseFunctions.instance
        .httpsCallable('submitReview')
        .call({
          'merchantId': widget.merchantId,
          'offerId': widget.offerId,
          'rating': rating,
          'comment': commentController.text.trim()
        });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review submitted successfully!'))
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit review: $e'))
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Write Review')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Rate your experience', style: TextStyle(fontSize: 18)),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 40,
                  ),
                  onPressed: () => setState(() => rating = index + 1),
                );
              }),
            ),
            SizedBox(height: 24),
            TextField(
              controller: commentController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Comment (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: rating > 0 ? _submitReview : null,
              child: Text('Submit Review'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### Example 5: Add Geo-Location Based Offer Filtering

**Step 1**: Add Location Field to Offers

Already exists in data model: `location` (geopoint field)

**Step 2**: Create Nearby Offers Function

```typescript
export const getNearbyOffers = functions.https.onCall(
  async (data: {lat: number, lng: number, radius: number}, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }
    
    const db = admin.firestore();
    const offersRef = db.collection('offers');
    
    // Firestore doesn't support radius queries directly
    // Use geohash or fetch all and filter in-memory
    const allOffers = await offersRef
      .where('status', '==', 'active')
      .get();
    
    const nearbyOffers = allOffers.docs
      .map(doc => ({ id: doc.id, ...doc.data() }))
      .filter(offer => {
        if (!offer.location) return false;
        const distance = calculateDistance(
          data.lat, data.lng,
          offer.location._latitude, offer.location._longitude
        );
        return distance <= data.radius;
      })
      .sort((a, b) => {
        const distA = calculateDistance(data.lat, data.lng, a.location._latitude, a.location._longitude);
        const distB = calculateDistance(data.lat, data.lng, b.location._latitude, b.location._longitude);
        return distA - distB;
      });
    
    return { success: true, offers: nearbyOffers };
  }
);

function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Earth radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c; // Distance in km
}
```

**Step 3**: Add UI Filter

```dart
// apps/mobile-customer/lib/screens/offers_list_screen.dart
Future<void> _loadNearbyOffers() async {
  // Get current location
  final position = await Geolocator.getCurrentPosition();
  
  // Call Cloud Function
  final result = await FirebaseFunctions.instance
    .httpsCallable('getNearbyOffers')
    .call({
      'lat': position.latitude,
      'lng': position.longitude,
      'radius': 5.0 // 5 km radius
    });
  
  setState(() {
    offers = (result.data['offers'] as List)
      .map((json) => Offer.fromJson(json))
      .toList();
  });
}
```

---

## Common Patterns

### Firebase Cloud Functions Pattern

```typescript
export const yourFunction = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(async (data: RequestType, context): Promise<ResponseType> => {
    // 1. Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Not authorized');
    }
    
    // 2. Validate input
    if (!data.requiredField) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required field');
    }
    
    // 3. Business logic
    const db = admin.firestore();
    const result = await db.collection('items').doc(data.id).get();
    
    // 4. Return response
    return { success: true, data: result.data() };
  });
```

### Flutter Screen Pattern

```dart
class YourScreen extends StatefulWidget {
  @override
  _YourScreenState createState() => _YourScreenState();
}

class _YourScreenState extends State<YourScreen> {
  bool _isLoading = true;
  String? _error;
  List<Item> _items = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    try {
      setState(() { _isLoading = true; _error = null; });
      
      final result = await FirebaseFunctions.instance
        .httpsCallable('yourFunction')
        .call({});
      
      setState(() {
        _items = (result.data['items'] as List)
          .map((json) => Item.fromJson(json))
          .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Your Screen')),
      body: _isLoading
        ? Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Text('Error: $_error'))
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                return ItemCard(item: _items[index]);
              },
            ),
    );
  }
}
```

---

## Testing Guidelines

### Backend Tests

```typescript
// backend/firebase-functions/src/__tests__/yourFunction.test.ts
import { yourFunction } from '../index';

describe('yourFunction', () => {
  it('should return success for valid input', async () => {
    const data = { requiredField: 'value' };
    const context = { auth: { uid: 'user123' } };
    
    const result = await yourFunction(data, context);
    
    expect(result.success).toBe(true);
    expect(result.data).toBeDefined();
  });
  
  it('should throw error for unauthenticated request', async () => {
    const data = { requiredField: 'value' };
    const context = {}; // No auth
    
    await expect(yourFunction(data, context)).rejects.toThrow('unauthenticated');
  });
});
```

### Mobile Tests

```dart
// apps/mobile-customer/test/models/offer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:your_app/models/offer.dart';

void main() {
  group('Offer', () {
    test('fromJson creates valid Offer', () {
      final json = {
        'id': 'offer123',
        'title': 'Test Offer',
        'discount_value': 20.0,
        // ... other fields
      };
      
      final offer = Offer.fromJson(json);
      
      expect(offer.id, 'offer123');
      expect(offer.title, 'Test Offer');
      expect(offer.discountValue, 20.0);
    });
  });
}
```

---

## Performance Optimization Tips

1. **Use Firestore Composite Indexes**: Define in `firestore.indexes.json`
2. **Limit Query Results**: Use `.limit(20)` to paginate
3. **Cache Static Data**: Use Hive for local caching in mobile apps
4. **Optimize Cloud Functions**: Set appropriate memory and timeout
5. **Use Batched Writes**: Reduce Firestore write operations

---

**Document Version**: 1.0
**Last Updated**: November 2025
**Target Audience**: AI assistants (GitHub Copilot, ChatGPT, Claude), new developers

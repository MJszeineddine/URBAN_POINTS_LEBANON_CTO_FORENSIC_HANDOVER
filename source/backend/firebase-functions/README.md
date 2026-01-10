# Urban Points Lebanon - Firebase Cloud Functions

## Overview

This package contains serverless backend functions for Urban Points Lebanon platform.

## Functions

### 1. `generateSecureQRToken`
**Purpose:** Generate secure, time-limited QR codes for offer redemption

**Type:** `https.onCall` (Callable Function)

**Authentication:** Required (Firebase Auth)

**Request:**
```typescript
{
  userId: string;        // Must match authenticated user
  offerId: string;       // Valid offer ID from Firestore
  merchantId: string;    // Valid merchant ID
  deviceHash: string;    // Device fingerprint
  geoLat?: number;       // Optional: User latitude
  geoLng?: number;       // Optional: User longitude
  partySize: number;     // Number of people (2-8)
}
```

**Response:**
```typescript
{
  success: boolean;
  token?: string;        // Base64-encoded secure token
  displayCode?: string;  // 6-digit fallback code
  expiresAt?: string;    // ISO timestamp (60s from now)
  error?: string;
}
```

**Security Features:**
- 60-second token expiry
- HMAC-SHA256 signature
- Device binding
- Single-use enforcement
- Prevents duplicate redemptions

**Error Codes:**
- `Unauthenticated` - No auth context
- `User mismatch` - userId doesn't match auth.uid
- `Missing required fields` - Invalid request
- `Offer not found` - Invalid offerId
- `Offer is inactive` - Offer disabled
- `Merchant not found` - Invalid merchantId
- `Offer already redeemed` - Duplicate redemption attempt

---

### 2. `validateRedemption`
**Purpose:** Validate and process redemption requests from merchants

**Type:** `https.onCall` (Callable Function)

**Authentication:** Required (Merchant account)

**Request:**
```typescript
{
  token?: string;        // QR token (exclusive with displayCode)
  displayCode?: string;  // 6-digit code (exclusive with token)
  merchantId: string;    // Merchant performing validation
  staffId?: string;      // Optional: Staff member ID
}
```

**Response:**
```typescript
{
  success: boolean;
  redemptionId?: string;       // Created redemption document ID
  offerTitle?: string;         // Offer name
  customerName?: string;       // Customer name
  pointsAwarded?: number;      // Points deducted
  error?: string;
}
```

**Validation Checks:**
1. Token/code format validation
2. Signature verification (for tokens)
3. Expiry check
4. Merchant match
5. Single-use enforcement
6. Offer and customer existence

**Side Effects:**
- Creates redemption record
- Marks token as used
- Deducts points from customer

**Error Codes:**
- `Unauthenticated` - No auth context
- `Invalid token signature` - Tampered token
- `Token expired` - Expired (>60s)
- `Invalid or used display code` - Code not found/already used
- `Merchant mismatch` - Wrong merchant
- `Token already used` - Duplicate redemption
- `Offer not found` - Invalid offer
- `Customer not found` - Invalid customer

---

### 3. `calculateDailyStats`
**Purpose:** Aggregate daily redemption statistics

**Type:** `https.onCall` (Callable Function)

**Authentication:** Required (Admin recommended)

**Request:**
```typescript
{
  date?: string;  // Optional: ISO date (default: today)
}
```

**Response:**
```typescript
{
  success: boolean;
  date?: string;
  stats?: {
    totalRedemptions: number;
    totalPointsRedeemed: number;
    uniqueCustomers: number;
    topMerchants: Array<{
      merchantId: string;
      redemptionCount: number;
    }>;
    averagePointsPerRedemption: number;
  };
  error?: string;
}
```

**Caching:**
Results are cached in `daily_stats` collection for quick retrieval.

**Use Cases:**
- Admin dashboard analytics
- Daily performance reports
- Merchant rankings
- Customer engagement metrics

---

## Deployment

### Prerequisites
```bash
npm install -g firebase-tools
firebase login
```

### Build
```bash
cd functions
npm run build
```

### Deploy All Functions
```bash
firebase deploy --only functions
```

### Deploy Single Function
```bash
firebase deploy --only functions:generateSecureQRToken
```

### View Logs
```bash
firebase functions:log
```

---

## Environment Variables

Set these in Firebase Console → Functions → Configuration:

```bash
# QR token signing secret
QR_TOKEN_SECRET=your-secret-key-here
```

Or via CLI:
```bash
firebase functions:config:set qr.token_secret="your-secret-key"
```

---

## Testing

### Local Emulator
```bash
firebase emulators:start --only functions
```

### Call Functions Locally
```javascript
// In Flutter app, change endpoint to:
// http://localhost:5001/urbangenspark/us-central1/generateSecureQRToken
```

---

## Performance

### Cold Start
- Target: < 200ms
- Optimizations:
  - Minimal dependencies
  - Code splitting
  - Admin SDK singleton

### Execution Time
- `generateSecureQRToken`: ~150-300ms
- `validateRedemption`: ~200-400ms
- `calculateDailyStats`: ~500-2000ms (depending on data volume)

---

## Security Best Practices

1. ✅ **Authentication Required** - All functions check `context.auth`
2. ✅ **Input Validation** - Validate all request data
3. ✅ **Rate Limiting** - Use Firebase App Check (TODO: Session 3)
4. ✅ **Secrets Management** - Environment variables for sensitive data
5. ✅ **HTTPS Only** - Callable functions enforce HTTPS
6. ✅ **Least Privilege** - Functions have minimal Firestore permissions

---

## Monitoring

### Firebase Console
- Functions → Metrics tab shows:
  - Invocations
  - Execution time
  - Memory usage
  - Error rate

### Alerts (TODO: Session 4)
- Set up Cloud Monitoring alerts
- Error rate > 0.1%
- Execution time > 500ms
- Memory usage > 512MB

---

## Future Enhancements (Later Sessions)

**Session 3 (Security):**
- Firebase App Check integration
- Rate limiting per user
- IP-based abuse detection

**Session 4 (Analytics):**
- BigQuery export
- Real-time dashboard webhooks
- Scheduled daily reports

**Session 5 (Testing):**
- Jest unit tests
- Integration tests with emulator
- Load testing with k6

---

## Troubleshooting

### "Unauthenticated" Error
- Ensure Firebase Auth token is included
- Check token hasn't expired
- Verify user is signed in

### "Internal error" Response
- Check Firebase Functions logs
- Verify Firestore permissions
- Check network connectivity

### Token Signature Verification Fails
- Verify QR_TOKEN_SECRET matches
- Check token hasn't been tampered with
- Ensure token format is valid base64

---

**Version:** 1.0  
**Last Updated:** November 9, 2025  
**Next Review:** After Session 3 (Security hardening)

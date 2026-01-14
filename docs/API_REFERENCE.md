# API Reference - Urban Points Lebanon

## Overview

Urban Points Lebanon provides a suite of Cloud Functions for managing loyalty points, offers, payments, and user authentication. All functions are deployed on Google Cloud Platform and are accessible via HTTPS.

**Base URL:** `https://us-central1-urbangenspark.cloudfunctions.net/`

**Authentication:** Firebase Auth ID token required in request headers or context

---

## Table of Contents

1. [Authentication Functions](#authentication-functions)
2. [Points & Redemption](#points--redemption)
3. [Offers Management](#offers-management)
4. [Payment & Subscriptions](#payment--subscriptions)
5. [QR Code Functions](#qr-code-functions)
6. [Admin Functions](#admin-functions)
7. [Privacy & GDPR](#privacy--gdpr)
8. [SMS & Notifications](#sms--notifications)
9. [Error Codes](#error-codes)

---

## Authentication Functions

### `getUserProfile`

Get current user profile information.

**Type:** Callable Function  
**Authentication:** Required  
**Rate Limit:** 100 requests/minute

**Request:**
```typescript
{
  userId: string;
}
```

**Response:**
```typescript
{
  success: boolean;
  profile?: {
    uid: string;
    email: string;
    displayName: string;
    role: 'customer' | 'merchant' | 'admin';
    createdAt: Timestamp;
    pointsBalance?: number;
    subscriptionStatus?: string;
  };
  error?: string;
}
```

**Example:**
```javascript
const getUserProfile = firebase.functions().httpsCallable('getUserProfile');
const result = await getUserProfile({ userId: currentUser.uid });
console.log(result.data.profile);
```

---

### `setCustomClaims`

Set custom claims for role-based access control (admin only).

**Type:** Callable Function  
**Authentication:** Admin required  
**Rate Limit:** 10 requests/minute

**Request:**
```typescript
{
  userId: string;
  claims: {
    role: 'customer' | 'merchant' | 'admin';
    merchantId?: string;
  };
}
```

**Response:**
```typescript
{
  success: boolean;
  error?: string;
}
```

---

## Points & Redemption

### `processPointsEarning`

Award points to a customer for an offer redemption.

**Type:** Callable Function  
**Authentication:** Merchant required  
**Rate Limit:** 1000 requests/minute

**Request:**
```typescript
{
  customerId: string;
  merchantId: string;
  offerId: string;
  amount: number;
  redemptionId: string;
}
```

**Response:**
```typescript
{
  success: boolean;
  newBalance?: number;
  transactionId?: string;
  error?: string;
}
```

**Validation:**
- `amount` must be > 0 and ≤ 10,000
- Merchant must own the offer
- Customer must exist
- Idempotent (same `redemptionId` returns cached result)

---

### `processRedemption`

Redeem points using a QR code.

**Type:** Callable Function  
**Authentication:** Merchant required  
**Rate Limit:** 500 requests/minute

**Request:**
```typescript
{
  token: string;           // QR token
  pin: string;             // 6-digit PIN
  merchantId: string;
  offerId: string;
  latitude?: number;
  longitude?: number;
}
```

**Response:**
```typescript
{
  success: boolean;
  redemption?: {
    id: string;
    customerId: string;
    pointsAwarded: number;
    timestamp: Timestamp;
  };
  error?: string;
}
```

**Security:**
- QR token expires after 60 seconds
- PIN must match token
- Device binding prevents replay attacks
- Single-use enforcement

---

### `getPointsBalance`

Get customer's current points balance and breakdown.

**Type:** Callable Function  
**Authentication:** Required (customer or admin)  
**Rate Limit:** 100 requests/minute

**Request:**
```typescript
{
  userId: string;
}
```

**Response:**
```typescript
{
  success: boolean;
  balance?: {
    total: number;
    earned: number;
    redeemed: number;
    expiring: number;
    expiryDate?: Timestamp;
  };
  error?: string;
}
```

---

## Offers Management

### `createOffer`

Create a new offer (merchant only).

**Type:** Callable Function  
**Authentication:** Merchant required  
**Rate Limit:** 50 requests/minute

**Request:**
```typescript
{
  title: string;                    // Max 100 chars
  description: string;              // Max 500 chars
  pointsRequired: number;           // 0-10,000
  category: string;
  validFrom: Timestamp;
  validUntil: Timestamp;
  maxRedemptions?: number;
  termsAndConditions?: string;
}
```

**Response:**
```typescript
{
  success: boolean;
  offerId?: string;
  status?: 'draft' | 'pending' | 'active';
  error?: string;
}
```

**Workflow:**
1. Offer created with status `pending`
2. Admin reviews and approves/rejects
3. Approved offers become `active`
4. Expired offers become `expired` automatically

---

### `updateOfferStatus`

Update offer status (admin or merchant).

**Type:** Callable Function  
**Authentication:** Admin or merchant (owner) required  
**Rate Limit:** 50 requests/minute

**Request:**
```typescript
{
  offerId: string;
  status: 'active' | 'paused' | 'expired';
  reason?: string;
}
```

**Response:**
```typescript
{
  success: boolean;
  error?: string;
}
```

---

### `aggregateOfferStats`

Get statistics for an offer.

**Type:** Callable Function  
**Authentication:** Merchant or admin required  
**Rate Limit:** 100 requests/minute

**Request:**
```typescript
{
  offerId: string;
  startDate?: Timestamp;
  endDate?: Timestamp;
}
```

**Response:**
```typescript
{
  success: boolean;
  stats?: {
    totalRedemptions: number;
    totalPointsAwarded: number;
    uniqueCustomers: number;
    averageRating?: number;
    revenueGenerated?: number;
  };
  error?: string;
}
```

---

## Payment & Subscriptions

### `initiatePaymentCallable`

Initiate Stripe payment for merchant subscription.

**Type:** Callable Function  
**Authentication:** Merchant required  
**Rate Limit:** 20 requests/minute

**Request:**
```typescript
{
  merchantId: string;
  planId: string;
  paymentMethodId?: string;
}
```

**Response:**
```typescript
{
  success: boolean;
  clientSecret?: string;      // For Stripe PaymentIntent
  subscriptionId?: string;
  error?: string;
}
```

**Usage Flow:**
1. Call `initiatePaymentCallable` to get `clientSecret`
2. Use Stripe SDK to confirm payment on client
3. Webhook updates subscription status in Firestore
4. Query subscription status to verify

---

### `createCheckoutSession`

Create Stripe Checkout session.

**Type:** Callable Function  
**Authentication:** Merchant required  
**Rate Limit:** 20 requests/minute

**Request:**
```typescript
{
  priceId: string;           // Stripe Price ID
  successUrl: string;
  cancelUrl: string;
}
```

**Response:**
```typescript
{
  success: boolean;
  sessionId?: string;
  url?: string;              // Redirect to this URL
  error?: string;
}
```

---

### `createBillingPortalSession`

Create Stripe Customer Portal session.

**Type:** Callable Function  
**Authentication:** Merchant required  
**Rate Limit:** 20 requests/minute

**Request:**
```typescript
{
  returnUrl: string;
}
```

**Response:**
```typescript
{
  success: boolean;
  url?: string;              // Redirect to this URL
  error?: string;
}
```

---

### `stripeWebhook`

Handle Stripe webhook events (internal).

**Type:** HTTP Function  
**Authentication:** Stripe signature verification  
**Rate Limit:** None

**Handled Events:**
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.payment_succeeded`
- `invoice.payment_failed`

**Webhook URL:** `https://us-central1-${PROJECT_ID}.cloudfunctions.net/stripeWebhook`

---

## QR Code Functions

### `generateSecureQRToken`

Generate secure QR code for offer redemption.

**Type:** Callable Function  
**Authentication:** Customer required  
**Rate Limit:** 100 requests/minute

**Request:**
```typescript
{
  userId: string;
  offerId: string;
  merchantId: string;
  deviceHash: string;
  geoLat?: number;
  geoLng?: number;
  partySize: number;
}
```

**Response:**
```typescript
{
  success: boolean;
  token?: string;            // Encrypted token
  displayCode?: string;      // 6-digit PIN for verification
  expiresAt?: string;        // ISO timestamp
  error?: string;
}
```

**Security Features:**
- HMAC-SHA256 signature
- 60-second expiration
- Device binding
- Replay attack prevention
- Single-use enforcement

---

## Admin Functions

### `adminUpdateUserRole`

Update user role (admin only).

**Type:** Callable Function  
**Authentication:** Admin required  
**Rate Limit:** 10 requests/minute

**Request:**
```typescript
{
  userId: string;
  role: 'customer' | 'merchant' | 'admin';
}
```

**Response:**
```typescript
{
  success: boolean;
  error?: string;
}
```

---

### `adminDisableOffer`

Disable/remove an offer (admin only).

**Type:** Callable Function  
**Authentication:** Admin required  
**Rate Limit:** 50 requests/minute

**Request:**
```typescript
{
  offerId: string;
  reason: string;
}
```

**Response:**
```typescript
{
  success: boolean;
  error?: string;
}
```

---

### `calculateDailyStats`

Calculate daily statistics (internal/scheduled).

**Type:** Scheduled Function  
**Schedule:** Daily at 1 AM Lebanon time  
**Authentication:** Internal

**Calculates:**
- Total redemptions
- Points awarded
- Revenue generated
- Active users
- Top offers
- Merchant rankings

---

## Privacy & GDPR

### `exportUserData`

Export all user data (GDPR Article 15).

**Type:** Callable Function  
**Authentication:** Required (own data only)  
**Rate Limit:** 5 requests/hour

**Request:**
```typescript
{
  userId: string;
  format?: 'json' | 'csv';
}
```

**Response:**
```typescript
{
  success: boolean;
  data?: {
    customer: object;
    redemptions: array;
    qrTokens: array;
    exportDate: string;
  };
  error?: string;
}
```

---

### `deleteUserData`

Permanently delete user data (GDPR Article 17).

**Type:** Callable Function  
**Authentication:** Required (own data only) or Admin  
**Rate Limit:** 2 requests/hour

**Request:**
```typescript
{
  userId: string;
  confirmation: string;      // Must be "DELETE_MY_DATA"
}
```

**Response:**
```typescript
{
  success: boolean;
  deletedCollections?: string[];
  error?: string;
}
```

**Warning:** This action is irreversible!

---

## SMS & Notifications

### `sendSMS`

Send SMS message.

**Type:** Callable Function  
**Authentication:** Required for non-OTP  
**Rate Limit:** 5 SMS/hour per user

**Request:**
```typescript
{
  phoneNumber: string;       // Lebanese format: +961XXXXXXXX
  message: string;
  type: 'otp' | 'notification' | 'promotional';
}
```

**Response:**
```typescript
{
  success: boolean;
  messageId?: string;
  error?: string;
}
```

**Providers:**
- Touch Lebanon (primary)
- Alfa Lebanon (fallback)
- Twilio (international)

---

### `verifyOTP`

Verify OTP code.

**Type:** Callable Function  
**Authentication:** Not required  
**Rate Limit:** 10 requests/minute

**Request:**
```typescript
{
  phoneNumber: string;
  code: string;              // 6-digit code
}
```

**Response:**
```typescript
{
  success: boolean;
  valid?: boolean;
  error?: string;
}
```

---

## Error Codes

### Authentication Errors
- `unauthenticated`: No auth token provided
- `permission-denied`: Insufficient permissions
- `invalid-argument`: Invalid user ID or token

### Validation Errors
- `invalid-argument`: Invalid request parameters
- `out-of-range`: Value exceeds allowed range
- `already-exists`: Resource already exists
- `not-found`: Resource not found

### Business Logic Errors
- `failed-precondition`: Precondition not met (e.g., insufficient points)
- `resource-exhausted`: Rate limit exceeded
- `unavailable`: Service temporarily unavailable
- `deadline-exceeded`: Request timeout

### Payment Errors
- `payment-required`: Subscription required
- `payment-failed`: Payment processing failed
- `invalid-payment-method`: Payment method invalid

---

## Rate Limiting

All functions implement rate limiting based on user ID or IP address:

| Function Type | Default Limit |
|--------------|---------------|
| Authentication | 100/min |
| Read Operations | 100/min |
| Write Operations | 50/min |
| Payment Operations | 20/min |
| SMS Operations | 5/hour |
| Data Export | 5/hour |

**Response when rate limited:**
```typescript
{
  success: false,
  error: 'Rate limit exceeded. Try again later.',
  retryAfter: 60  // seconds
}
```

---

## Webhooks

### External Webhooks

Configure webhook URLs in your service provider dashboards:

| Provider | URL Pattern |
|----------|-------------|
| Stripe | `https://us-central1-${PROJECT_ID}.cloudfunctions.net/stripeWebhook` |
| OMT | `https://us-central1-${PROJECT_ID}.cloudfunctions.net/omtWebhook` |
| Whish | `https://us-central1-${PROJECT_ID}.cloudfunctions.net/whishWebhook` |

All webhooks require signature verification.

---

## Testing

### Emulator Suite

```bash
firebase emulators:start
```

Functions available at: `http://localhost:5001/`

### Test with curl

```bash
# Generate QR token
curl -X POST http://localhost:5001/urbanpoints/us-central1/generateSecureQRToken \
  -H "Authorization: Bearer ${ID_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user-123",
    "offerId": "test-offer-456",
    "merchantId": "test-merchant-789",
    "deviceHash": "device-hash",
    "partySize": 2
  }'
```

---

## Support

For API issues:
- Check function logs: `firebase functions:log`
- Monitor errors: https://console.cloud.google.com/errors
- Documentation: `/docs`
- Email: api-support@urbanpoints.lb

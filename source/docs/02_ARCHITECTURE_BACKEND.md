# Urban Points Lebanon - Backend Architecture

## Technology Stack

### Primary Backend: Firebase Cloud Functions
- **Runtime**: Node.js 20
- **Language**: TypeScript 5.3
- **Framework**: Firebase Functions SDK
- **Database**: Firestore (NoSQL)
- **Authentication**: Firebase Auth
- **Storage**: Firebase Cloud Storage
- **Deployment**: Firebase CLI

### Secondary Backend: REST API (Legacy/Compatibility)
- **Runtime**: Node.js 20
- **Language**: TypeScript 5.3
- **Framework**: Express.js 4.18
- **Database**: PostgreSQL 15
- **ORM**: pg (node-postgres)
- **Authentication**: JWT (jsonwebtoken)
- **Deployment**: PM2 process manager

---

## Directory Structure

### Firebase Cloud Functions (`backend/firebase-functions/`)

```
backend/firebase-functions/
├── src/
│   ├── index.ts                    # Main entry point, exports all functions
│   ├── privacy.ts                  # GDPR compliance functions
│   ├── sms.ts                      # SMS/OTP verification
│   ├── paymentWebhooks.ts          # Payment gateway webhooks
│   ├── subscriptionAutomation.ts   # Subscription lifecycle management
│   ├── pushCampaigns.ts            # Push notification campaigns
│   └── __tests__/                  # Unit tests
│       ├── qr-functions.test.ts
│       ├── points-functions.test.ts
│       ├── alert-functions.test.ts
│       └── privacy-functions.test.ts
├── lib/                            # Compiled JavaScript (build output)
├── node_modules/                   # Dependencies
├── package.json                    # Dependencies and scripts
├── tsconfig.json                   # TypeScript configuration
├── jest.config.js                  # Test configuration
└── .eslintrc.js                    # Code quality rules
```

### REST API (`backend/rest-api/`)

```
backend/rest-api/
├── src/
│   ├── server.ts                   # Express app entry point
│   ├── config/
│   │   └── database.ts             # PostgreSQL connection config
│   ├── types/
│   │   └── index.ts                # TypeScript type definitions
│   ├── middleware/                 # (to be added)
│   ├── routes/                     # (to be added)
│   ├── controllers/                # (to be added)
│   ├── services/                   # (to be added)
│   └── models/                     # (to be added)
├── dist/                           # Compiled JavaScript
├── node_modules/                   # Dependencies
├── package.json                    # Dependencies and scripts
├── tsconfig.json                   # TypeScript configuration
└── .env                            # Environment variables (NOT in repo)
```

---

## Main Services and Modules

### 1. Authentication Service
**Location**: Firebase Auth + Cloud Functions  
**Responsibilities**:
- User registration (email/phone)
- Login/logout
- OTP verification (SMS)
- Session management
- Password reset
- Account linking

**Key Functions**:
- `sendSMS(phoneNumber, message)` - Send verification SMS
- `verifyOTP(phoneNumber, code)` - Validate OTP code
- `cleanupExpiredOTPs()` - Scheduled cleanup of expired OTPs

### 2. User Management Service
**Location**: `functions/src/index.ts` (to be extracted)  
**Responsibilities**:
- User profile CRUD operations
- User preferences management
- Account status management
- User search and filtering

**Firestore Collections**:
- `customers/` - Consumer profiles
- `merchants/` - Merchant profiles
- `admins/` - Administrator accounts

### 3. Merchant Management Service
**Location**: Cloud Functions  
**Responsibilities**:
- Merchant registration and approval
- Business profile management
- Branch/location management
- Merchant verification
- Merchant analytics

**Key Operations**:
- Create merchant profile
- Update merchant details
- Add/remove branches
- Approve/reject merchant registration
- View merchant analytics

### 4. Offers Service
**Location**: Cloud Functions  
**Responsibilities**:
- Offer creation and management
- Offer approval workflow
- Offer search and filtering
- Offer expiration handling
- Offer analytics

**Firestore Collections**:
- `offers/` - All offers
- `offer_categories/` - Offer categorization

**Key Operations**:
- Create offer (merchant)
- Update offer (merchant)
- Delete offer (merchant/admin)
- Approve/reject offer (admin)
- List offers (with filters)
- Get offer details

### 5. Points Economy Service
**Location**: `functions/src/index.ts`  
**Responsibilities**:
- Points awarding (referrals, promotions)
- Points deduction (redemptions)
- Points balance management
- Transaction history
- Atomic operations for consistency

**Key Functions**:
- `awardPoints(userId, amount, reason)` - Add points to user wallet
- `deductPoints(userId, amount, offerId)` - Deduct points for redemption
- `getPointsBalance(userId)` - Get current balance
- `getPointsHistory(userId)` - Get transaction log

**Business Logic**:
- **Referral Points**: 500 for referrer, 100 for referee
- **Atomic Transactions**: Prevent double-spending and race conditions
- **Negative Balance Prevention**: Validate sufficient balance before deduction

### 6. Redemption Service
**Location**: `functions/src/index.ts`  
**Responsibilities**:
- QR token generation
- QR token validation
- Redemption eligibility checks
- Redemption processing
- Redemption history

**Key Functions**:
```typescript
generateSecureQRToken(data: QRTokenRequest): QRTokenResponse
validateRedemption(data: RedemptionRequest): RedemptionResponse
checkRedemptionEligibility(userId, offerId): EligibilityResponse
```

**Security Measures**:
- **60-second expiry**: Tokens expire after 1 minute
- **HMAC SHA-256 signature**: Cryptographic integrity check
- **Device binding**: Token tied to device hash
- **Single-use enforcement**: Token invalidated after use
- **Replay attack prevention**: Token cannot be reused

**Redemption Rules** (8 rules enforced):
1. Customer must have sufficient points
2. Offer must require premium subscription if customer doesn't have it
3. Customer can only redeem offer once
4. Offer must be active
5. Offer must not be expired
6. Offer must not exceed max redemption count
7. Merchant must be approved and active
8. Customer account must be active

### 7. Subscription Service
**Location**: `functions/src/subscriptionAutomation.ts`  
**Responsibilities**:
- Subscription purchase processing
- Payment webhook handling (OMT, Whish Money, Stripe)
- Subscription renewal automation
- Expiry reminders
- Subscription analytics

**Key Functions**:
```typescript
processSubscriptionRenewals() // Scheduled daily
sendExpiryReminders()          // Scheduled daily
cleanupExpiredSubscriptions()  // Scheduled weekly
calculateSubscriptionMetrics() // On-demand analytics
```

**Subscription Tiers**:
- **Free**: Default tier, basic features
- **Silver**: $4.99/month, enhanced features
- **Gold**: $9.99/month, premium features

### 8. Analytics Service
**Location**: `functions/src/index.ts`  
**Responsibilities**:
- Daily statistics aggregation
- Merchant performance metrics
- Customer engagement metrics
- Offer performance analytics
- Revenue tracking

**Key Function**:
```typescript
calculateDailyStats() // Scheduled at 01:00 UTC daily
```

**Metrics Calculated**:
- Total users (customers, merchants, admins)
- Active offers count
- Redemptions count (daily, weekly, monthly)
- Points issued and redeemed
- Top merchants by redemptions
- Top offers by popularity
- Subscription revenue
- Customer retention rate

### 9. Push Notification Service
**Location**: `functions/src/pushCampaigns.ts`  
**Responsibilities**:
- Push notification campaigns
- Personalized notifications
- Scheduled campaigns
- Notification targeting (segments)
- Notification analytics

**Key Functions**:
```typescript
processScheduledCampaigns()      // Scheduled every hour
sendPersonalizedNotification()   // On-demand
scheduleCampaign()               // Campaign creation
```

**Notification Types**:
- Offer expiry reminders
- New offer alerts
- Points balance updates
- Redemption confirmations
- Subscription reminders
- Promotional campaigns

### 10. Privacy and Compliance Service
**Location**: `functions/src/privacy.ts`  
**Responsibilities**:
- GDPR data export
- Right to erasure (data deletion)
- Data retention policy enforcement
- Audit logging

**Key Functions**:
```typescript
exportUserData(userId)       // GDPR data export
deleteUserData(userId)       // GDPR right to erasure
cleanupExpiredData()         // Scheduled cleanup
```

**Data Retention**:
- **OTPs**: 10 minutes
- **QR Tokens**: 60 seconds
- **Audit Logs**: 90 days
- **Redemptions**: Indefinite (immutable audit trail)
- **User Data**: Until deletion request

---

## Request Flow Architecture

### Typical Cloud Function Request Flow

```
1. Client Request (Mobile/Web App)
   ↓ HTTPS
2. Firebase Auth Middleware
   ↓ Validates JWT token
3. Cloud Function Entry Point
   ↓ Extracts authenticated user context
4. Business Logic Layer
   ↓ Validates request data (Joi schemas)
   ↓ Applies business rules
   ↓ Checks authorization (Firestore rules)
5. Data Access Layer
   ↓ Firestore queries/transactions
6. Response Generation
   ↓ Format response (success/error)
7. Client Response
   ↓ JSON response with status code
```

### Example: QR Token Generation Flow

```
Customer App
  ↓ POST /generateSecureQRToken
  ↓ Headers: Authorization: Bearer <Firebase JWT>
  ↓ Body: { userId, offerId, merchantId, deviceHash, partySize }
    ↓
Firebase Auth
  ↓ Validates JWT token
  ↓ Extracts uid (user ID)
    ↓
Cloud Function: generateSecureQRToken()
  ↓ Verify user matches authenticated user
  ↓ Fetch offer details from Firestore
  ↓ Fetch user points balance
  ↓ Check redemption eligibility (8 rules)
  ↓ Generate token payload:
     {
       userId, offerId, merchantId, deviceHash,
       timestamp, expiresAt, partySize
     }
  ↓ Sign payload with HMAC SHA-256
  ↓ Create QR token document in Firestore
  ↓ Return token and display code
    ↓
Customer App
  ↓ Receives token
  ↓ Generates QR code image
  ↓ Displays to user (60-second countdown)
```

---

## Database Schema (Firestore)

### Collections Overview

| Collection | Purpose | Key Fields |
|-----------|---------|------------|
| `customers` | Consumer profiles | email, name, phone, points_balance, subscription_tier |
| `merchants` | Merchant profiles | business_name, category, logo_url, branches, status |
| `admins` | Admin accounts | email, name, role, permissions |
| `offers` | Promotional offers | title, description, discount_pct, min_spend, expires_at, merchant_id |
| `qr_tokens` | Temporary QR codes | token, user_id, offer_id, merchant_id, expires_at, device_hash |
| `redemptions` | Redemption records | user_id, offer_id, merchant_id, points_spent, redeemed_at |
| `transactions` | Points transactions | user_id, type, amount, reason, created_at |
| `subscriptions` | User subscriptions | user_id, tier, status, expires_at, payment_method |
| `campaigns` | Push campaigns | title, message, target_segment, scheduled_at, sent_at |
| `branches` | Merchant locations | merchant_id, name, address, lat, lng, phone |
| `reviews` | Customer reviews | user_id, merchant_id, rating, comment, created_at |
| `referrals` | Referral tracking | referrer_id, referee_id, status, points_awarded, created_at |
| `otps` | OTP codes | phone, code, expires_at, verified |
| `analytics_daily` | Daily aggregates | date, metrics (JSON) |
| `audit_logs` | System audit trail | action, user_id, resource_type, resource_id, timestamp |

### Firestore Security Rules

**Location**: `infra/firestore.rules`

**Key Principles**:
1. **Authenticated Access**: Most collections require authentication
2. **Role-Based Access**: Customers, merchants, and admins have different permissions
3. **Cloud Functions-Only Writes**: Critical collections (qr_tokens, redemptions, transactions) can only be written by Cloud Functions
4. **Owner-Only Access**: Users can only read/write their own data
5. **Admin Verification**: Admin access verified via `admins` collection lookup

**Example Rules**:
```javascript
// Customers collection - read own data, Cloud Functions write only
match /customers/{customerId} {
  allow read: if request.auth.uid == customerId || isAdmin();
  allow write: if false; // Cloud Functions only
}

// Offers collection - everyone can read, merchants can create, admins approve
match /offers/{offerId} {
  allow read: if true;
  allow create: if request.auth != null && isMerchant();
  allow update: if isAdmin() || (isMerchant() && resource.data.merchant_id == request.auth.uid);
  allow delete: if isAdmin();
}

// QR Tokens - read own tokens, Cloud Functions only write
match /qr_tokens/{tokenId} {
  allow read: if request.auth.uid == resource.data.user_id || 
                 request.auth.uid == resource.data.merchant_id || 
                 isAdmin();
  allow write: if false; // Cloud Functions only
}
```

### Firestore Indexes

**Location**: `infra/firestore.indexes.json`

**Composite Indexes** (15 total):
1. `redemptions`: (user_id ASC, redeemed_at DESC)
2. `redemptions`: (merchant_id ASC, redeemed_at DESC)
3. `redemptions`: (offer_id ASC, redeemed_at DESC)
4. `offers`: (merchant_id ASC, created_at DESC)
5. `offers`: (status ASC, expires_at ASC)
6. `offers`: (category ASC, created_at DESC)
7. `transactions`: (user_id ASC, created_at DESC)
8. `subscriptions`: (user_id ASC, expires_at DESC)
9. `subscriptions`: (status ASC, expires_at ASC)
10. `campaigns`: (status ASC, scheduled_at ASC)
11. `branches`: (merchant_id ASC, created_at DESC)
12. `reviews`: (merchant_id ASC, created_at DESC)
13. `referrals`: (referrer_id ASC, created_at DESC)
14. `audit_logs`: (user_id ASC, timestamp DESC)
15. `analytics_daily`: (date DESC)

---

## Environment Configuration

### Firebase Cloud Functions Config

**Setting Environment Variables**:
```bash
# Security (auto-generated by configure_firebase_env.sh)
firebase functions:config:set security.hmac_secret="<32-byte-base64-secret>"

# Subscription Pricing
firebase functions:config:set subscription.silver_price="4.99"
firebase functions:config:set subscription.gold_price="9.99"

# Points Economy
firebase functions:config:set points.referrer_bonus="500"
firebase functions:config:set points.referee_bonus="100"

# Payment Gateways (manual configuration required)
firebase functions:config:set omt.api_key="<omt-key>"
firebase functions:config:set omt.merchant_id="<omt-merchant-id>"
firebase functions:config:set whish.api_key="<whish-key>"
firebase functions:config:set whish.merchant_id="<whish-merchant-id>"
firebase functions:config:set stripe.secret_key="<stripe-key>"
firebase functions:config:set stripe.webhook_secret="<stripe-webhook-secret>"

# Optional: Slack Alerts
firebase functions:config:set slack.webhook_url="<slack-webhook>"
```

### REST API Environment Variables

**File**: `backend/rest-api/.env` (create from `.env.example`)

```bash
# Server
PORT=3000
NODE_ENV=production

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=urban_points_lebanon
DB_USER=postgres
DB_PASSWORD=<secure-password>

# JWT
JWT_SECRET=<secure-random-string>
JWT_EXPIRY=7d

# CORS
CORS_ORIGIN=https://urbanpoints.lebanon.com

# Rate Limiting
RATE_LIMIT_WINDOW=15m
RATE_LIMIT_MAX_REQUESTS=100
```

---

## Error Handling

### Cloud Functions Error Responses

```typescript
// Success Response
{
  success: true,
  data: { ... },
  message: "Operation completed successfully"
}

// Error Response
{
  success: false,
  error: "Error message",
  code: "ERROR_CODE",
  details: { ... } // Optional
}
```

### Common Error Codes

| Code | Meaning | HTTP Status |
|------|---------|-------------|
| `UNAUTHENTICATED` | User not logged in | 401 |
| `UNAUTHORIZED` | Insufficient permissions | 403 |
| `INVALID_REQUEST` | Malformed request data | 400 |
| `NOT_FOUND` | Resource doesn't exist | 404 |
| `ALREADY_EXISTS` | Duplicate resource | 409 |
| `INSUFFICIENT_POINTS` | Not enough points in wallet | 400 |
| `TOKEN_EXPIRED` | QR token expired | 400 |
| `ALREADY_REDEEMED` | Offer already redeemed by user | 400 |
| `OFFER_INACTIVE` | Offer not active | 400 |
| `MERCHANT_NOT_APPROVED` | Merchant awaiting approval | 403 |
| `MAX_REDEMPTIONS_REACHED` | Offer redemption limit reached | 400 |

---

## Testing

### Unit Tests

**Framework**: Jest  
**Location**: `functions/src/__tests__/`

**Test Coverage**:
- QR token generation and validation
- Points award and deduction
- Redemption eligibility checks
- Privacy functions (export, delete)
- Alert functions (notifications)

**Running Tests**:
```bash
cd backend/firebase-functions
npm test              # Run all tests
npm run test:watch    # Watch mode
npm run test:coverage # Coverage report
```

### Integration Tests

**Location**: `scripts/` (various test scripts)

**Test Scenarios**:
- End-to-end redemption flow
- Subscription purchase and renewal
- Payment webhook processing
- Scheduled function execution

---

## Deployment

### Firebase Cloud Functions Deployment

**Command**:
```bash
cd backend/firebase-functions
npm run build                    # Compile TypeScript
firebase deploy --only functions # Deploy to Firebase
```

**Automated Deployment**:
```bash
cd scripts
./deploy_production.sh  # All-in-one deployment script
```

### REST API Deployment

**Process Manager**: PM2

**Commands**:
```bash
cd backend/rest-api
npm run build              # Compile TypeScript
pm2 start dist/server.js   # Start with PM2
pm2 logs                   # View logs
pm2 restart all            # Restart
```

---

## Monitoring and Logging

### Firebase Console
- **Functions Dashboard**: View function invocations, errors, execution time
- **Firestore Dashboard**: Monitor read/write operations, storage usage
- **Auth Dashboard**: Track user signups, logins, authentication methods

### Cloud Function Logs
```bash
firebase functions:log --project urbangenspark
firebase functions:log --only generateSecureQRToken
```

### Custom Logging
All functions log to Firebase Functions console with structured logging:
```typescript
console.log('INFO', { operation: 'generateQRToken', userId, offerId });
console.error('ERROR', { operation: 'validateRedemption', error: err.message });
```

---

## Performance Optimization

### Cost Optimization Strategies
1. **Minimal Memory Allocation**: 256MB for most functions
2. **No Cold Start Protection**: minInstances=0 to save costs
3. **Query Optimization**: Use composite indexes, limit result sets
4. **Caching**: Client-side caching for static data
5. **Batch Operations**: Process multiple operations in single function call

### Scalability Limits
- **Max Instances**: 10 per function (prevent runaway costs)
- **Timeout**: 60 seconds per function
- **Concurrent Requests**: Auto-scales based on demand
- **Firestore Reads**: Optimized queries, indexed fields

---

**Document Version**: 1.0  
**Last Updated**: November 2025  
**Target Audience**: Backend developers, DevOps engineers

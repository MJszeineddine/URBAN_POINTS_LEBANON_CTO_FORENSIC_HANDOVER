# Urban Points Lebanon - Data Models

## Overview

This document describes all core data entities in the Urban Points Lebanon ecosystem. The system uses Firestore (NoSQL) as the primary database, with collections organized for optimal query performance and real-time synchronization.

---

## Core Entities

### 1. Customer (User)

**Collection**: `customers`

**Purpose**: Consumer profiles who browse offers, earn points, and redeem rewards.

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique user ID (Firebase Auth UID) |
| `email` | string | Yes | User email address |
| `phone` | string | No | Phone number (E.164 format) |
| `name` | string | Yes | Full name |
| `photo_url` | string | No | Profile photo URL |
| `points_balance` | number | Yes | Current points balance (default: 0) |
| `total_points_earned` | number | Yes | Lifetime points earned |
| `total_points_spent` | number | Yes | Lifetime points spent |
| `subscription_tier` | string | Yes | 'free', 'silver', 'gold' (default: 'free') |
| `subscription_expires_at` | timestamp | No | Subscription expiry date |
| `referral_code` | string | Yes | Unique referral code (6 chars) |
| `referred_by` | string | No | Referrer user ID |
| `total_referrals` | number | Yes | Number of successful referrals (default: 0) |
| `favorite_offer_ids` | array | Yes | List of favorited offer IDs (default: []) |
| `language` | string | Yes | 'en' or 'ar' (default: 'en') |
| `notification_enabled` | boolean | Yes | Push notification preference (default: true) |
| `fcm_token` | string | No | Firebase Cloud Messaging token |
| `location` | geopoint | No | Last known location (for nearby offers) |
| `status` | string | Yes | 'active', 'suspended', 'deleted' (default: 'active') |
| `created_at` | timestamp | Yes | Account creation timestamp |
| `updated_at` | timestamp | Yes | Last update timestamp |

**Indexes**:
- `email` (unique)
- `phone` (unique)
- `referral_code` (unique)
- `subscription_tier` + `subscription_expires_at` (composite)
- `status` + `created_at` (composite)

**Security Rules**:
- Read: Own data only (or admin)
- Write: Cloud Functions only

---

### 2. Merchant

**Collection**: `merchants`

**Purpose**: Business profiles that create offers and validate redemptions.

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique merchant ID (Firebase Auth UID) |
| `email` | string | Yes | Business email |
| `phone` | string | Yes | Business phone |
| `business_name` | string | Yes | Official business name |
| `business_name_ar` | string | No | Business name in Arabic |
| `description` | string | Yes | Business description |
| `description_ar` | string | No | Description in Arabic |
| `logo_url` | string | No | Business logo URL |
| `cover_image_url` | string | No | Cover/banner image URL |
| `category` | string | Yes | 'restaurant', 'retail', 'services', 'entertainment', 'health', 'beauty', 'travel', 'other' |
| `subcategory` | string | No | More specific category |
| `website` | string | No | Business website URL |
| `social_media` | map | No | Social links: {facebook, instagram, twitter} |
| `address` | string | Yes | Primary address |
| `city` | string | Yes | City name |
| `country` | string | Yes | 'Lebanon' (default) |
| `location` | geopoint | No | Primary location coordinates |
| `branches` | array | No | List of branch IDs |
| `subscription_tier` | string | Yes | 'basic', 'premium' (default: 'basic') |
| `subscription_expires_at` | timestamp | No | Premium subscription expiry |
| `total_offers_created` | number | Yes | Total offers created (default: 0) |
| `total_redemptions` | number | Yes | Total redemptions processed (default: 0) |
| `average_rating` | number | Yes | Average customer rating (default: 0) |
| `total_reviews` | number | Yes | Total reviews received (default: 0) |
| `status` | string | Yes | 'pending', 'approved', 'suspended', 'rejected' (default: 'pending') |
| `approval_notes` | string | No | Admin notes for approval/rejection |
| `approved_by` | string | No | Admin ID who approved |
| `approved_at` | timestamp | No | Approval timestamp |
| `created_at` | timestamp | Yes | Registration timestamp |
| `updated_at` | timestamp | Yes | Last update timestamp |

**Indexes**:
- `email` (unique)
- `category` + `status` (composite)
- `status` + `created_at` (composite)
- `city` + `category` (composite)

**Security Rules**:
- Read: Anyone authenticated
- Write: Own data (update only) or admin

---

### 3. Admin

**Collection**: `admins`

**Purpose**: Platform administrators with elevated privileges.

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique admin ID (Firebase Auth UID) |
| `email` | string | Yes | Admin email |
| `name` | string | Yes | Admin full name |
| `role` | string | Yes | 'super_admin', 'moderator', 'support' (default: 'moderator') |
| `permissions` | array | Yes | List of permission strings |
| `status` | string | Yes | 'active', 'suspended' (default: 'active') |
| `created_by` | string | No | Admin ID who created this account |
| `created_at` | timestamp | Yes | Account creation timestamp |
| `last_login_at` | timestamp | No | Last login timestamp |

**Permissions**:
- `approve_merchants`
- `moderate_offers`
- `manage_users`
- `view_analytics`
- `configure_system`
- `manage_admins` (super_admin only)

**Security Rules**:
- Read: Own data or super_admin
- Write: super_admin only

---

### 4. Offer

**Collection**: `offers`

**Purpose**: Promotional deals created by merchants.

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Auto-generated offer ID |
| `merchant_id` | string | Yes | Owner merchant ID |
| `title` | string | Yes | Offer title |
| `title_ar` | string | No | Title in Arabic |
| `description` | string | Yes | Detailed description |
| `description_ar` | string | No | Description in Arabic |
| `image_url` | string | No | Offer image URL |
| `category` | string | Yes | Same as merchant categories |
| `discount_type` | string | Yes | 'percentage', 'fixed_amount', 'bogof' (buy-one-get-one-free) |
| `discount_value` | number | Yes | Discount percentage or fixed amount |
| `original_price` | number | No | Original price (for reference) |
| `min_spend` | number | No | Minimum spend requirement |
| `points_required` | number | Yes | Points cost to redeem |
| `premium_only` | boolean | Yes | Requires Silver/Gold subscription (default: false) |
| `valid_from` | timestamp | Yes | Offer start date |
| `valid_until` | timestamp | Yes | Offer end date |
| `max_redemptions` | number | No | Total redemption limit (null = unlimited) |
| `current_redemptions` | number | Yes | Current redemption count (default: 0) |
| `max_redemptions_per_user` | number | Yes | Per-user limit (default: 1) |
| `terms_and_conditions` | string | Yes | Legal terms |
| `terms_and_conditions_ar` | string | No | Terms in Arabic |
| `applicable_branches` | array | No | Specific branch IDs (null = all branches) |
| `days_of_week` | array | No | Valid days: ['monday', 'tuesday', ...] (null = all days) |
| `time_slots` | array | No | Valid time ranges: [{start: 'HH:mm', end: 'HH:mm'}] |
| `status` | string | Yes | 'draft', 'pending_approval', 'active', 'paused', 'expired', 'rejected' (default: 'draft') |
| `approval_notes` | string | No | Admin moderation notes |
| `approved_by` | string | No | Admin ID who approved |
| `approved_at` | timestamp | No | Approval timestamp |
| `featured` | boolean | Yes | Show in featured section (default: false) |
| `priority` | number | Yes | Display priority (higher = top) (default: 0) |
| `views_count` | number | Yes | Total views (default: 0) |
| `favorites_count` | number | Yes | Times favorited (default: 0) |
| `created_at` | timestamp | Yes | Creation timestamp |
| `updated_at` | timestamp | Yes | Last update timestamp |

**Indexes**:
- `merchant_id` + `created_at` DESC (composite)
- `status` + `valid_until` ASC (composite)
- `category` + `status` (composite)
- `featured` + `priority` DESC (composite)

**Security Rules**:
- Read: Anyone authenticated
- Create: Authenticated merchants only
- Update: Owner merchant or admin
- Delete: Admin only

---

### 5. QR Token

**Collection**: `qr_tokens`

**Purpose**: Temporary tokens for secure offer redemption.

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Auto-generated token ID |
| `token` | string | Yes | Encrypted token string (HMAC SHA-256) |
| `display_code` | string | Yes | Human-readable 6-digit code |
| `user_id` | string | Yes | Customer ID |
| `offer_id` | string | Yes | Offer ID |
| `merchant_id` | string | Yes | Merchant ID |
| `device_hash` | string | Yes | Device fingerprint (IP + User-Agent hash) |
| `geo_lat` | number | No | Customer latitude |
| `geo_lng` | number | No | Customer longitude |
| `party_size` | number | Yes | Number of people in party (default: 1) |
| `generated_at` | timestamp | Yes | Token generation time |
| `expires_at` | timestamp | Yes | Token expiry (60 seconds after generation) |
| `redeemed` | boolean | Yes | Redemption status (default: false) |
| `redeemed_at` | timestamp | No | Redemption timestamp |
| `redeemed_by` | string | No | Merchant ID who validated |

**Indexes**:
- `user_id` + `generated_at` DESC (composite)
- `expires_at` ASC (for cleanup)
- `token` (unique, for fast lookup)

**Security Rules**:
- Read: Owner customer, target merchant, or admin
- Write: Cloud Functions only

**Lifecycle**:
1. Generated by customer app (Cloud Function call)
2. Valid for 60 seconds
3. Scanned by merchant app (validation)
4. Marked as redeemed or expired
5. Cleaned up after 24 hours

---

### 6. Redemption

**Collection**: `redemptions`

**Purpose**: Permanent record of completed offer redemptions.

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Auto-generated redemption ID |
| `user_id` | string | Yes | Customer ID |
| `offer_id` | string | Yes | Offer ID |
| `merchant_id` | string | Yes | Merchant ID |
| `branch_id` | string | No | Specific branch ID |
| `qr_token_id` | string | Yes | Reference to QR token used |
| `points_spent` | number | Yes | Points deducted |
| `discount_applied` | number | Yes | Discount value applied |
| `party_size` | number | Yes | Number of people |
| `customer_location` | geopoint | No | Customer location at redemption |
| `merchant_location` | geopoint | No | Merchant branch location |
| `redeemed_at` | timestamp | Yes | Redemption timestamp |
| `redeemed_by_merchant` | string | Yes | Merchant account that validated |
| `status` | string | Yes | 'completed', 'disputed', 'refunded' (default: 'completed') |
| `notes` | string | No | Additional notes |

**Indexes**:
- `user_id` + `redeemed_at` DESC (composite)
- `merchant_id` + `redeemed_at` DESC (composite)
- `offer_id` + `redeemed_at` DESC (composite)
- `redeemed_at` DESC (for analytics)

**Security Rules**:
- Read: Owner customer, owner merchant, or admin
- Write: Cloud Functions only (immutable after creation)

---

### 7. Transaction

**Collection**: `transactions`

**Purpose**: Points transaction ledger for audit trail.

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Auto-generated transaction ID |
| `user_id` | string | Yes | Customer ID |
| `type` | string | Yes | 'earned', 'spent', 'bonus', 'refund', 'expired' |
| `amount` | number | Yes | Points amount (positive for earned, negative for spent) |
| `balance_after` | number | Yes | Points balance after transaction |
| `reason` | string | Yes | Transaction reason |
| `reference_type` | string | No | 'redemption', 'referral', 'signup_bonus', 'admin_adjustment' |
| `reference_id` | string | No | Related entity ID (redemption_id, referral_id, etc.) |
| `metadata` | map | No | Additional transaction details |
| `created_at` | timestamp | Yes | Transaction timestamp |

**Indexes**:
- `user_id` + `created_at` DESC (composite)
- `type` + `created_at` DESC (composite)

**Security Rules**:
- Read: Own transactions only (or admin)
- Write: Cloud Functions only (immutable)

---

### 8. Subscription

**Collection**: `subscriptions`

**Purpose**: Premium subscription records.

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Auto-generated subscription ID |
| `user_id` | string | Yes | Customer ID |
| `tier` | string | Yes | 'silver', 'gold' |
| `status` | string | Yes | 'active', 'expired', 'cancelled', 'pending_payment' |
| `payment_method` | string | Yes | 'omt', 'whish', 'stripe', 'manual' |
| `payment_amount` | number | Yes | Amount paid |
| `payment_currency` | string | Yes | 'USD' (default) |
| `payment_transaction_id` | string | No | External payment reference |
| `started_at` | timestamp | Yes | Subscription start date |
| `expires_at` | timestamp | Yes | Subscription expiry date |
| `auto_renew` | boolean | Yes | Auto-renewal enabled (default: true) |
| `renewal_reminder_sent` | boolean | Yes | Reminder email sent (default: false) |
| `cancelled_at` | timestamp | No | Cancellation timestamp |
| `cancellation_reason` | string | No | User-provided reason |
| `created_at` | timestamp | Yes | Purchase timestamp |

**Indexes**:
- `user_id` + `expires_at` DESC (composite)
- `status` + `expires_at` ASC (composite - for renewal processing)
- `expires_at` ASC (for reminders)

**Security Rules**:
- Read: Own subscriptions only (or admin)
- Write: Cloud Functions only

---

### 9. Branch

**Collection**: `branches`

**Purpose**: Merchant location branches.

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Auto-generated branch ID |
| `merchant_id` | string | Yes | Owner merchant ID |
| `name` | string | Yes | Branch name |
| `name_ar` | string | No | Branch name in Arabic |
| `address` | string | Yes | Full address |
| `city` | string | Yes | City name |
| `location` | geopoint | Yes | Coordinates (lat, lng) |
| `phone` | string | Yes | Branch phone number |
| `email` | string | No | Branch email |
| `hours` | map | Yes | Operating hours: {monday: {open: 'HH:mm', close: 'HH:mm'}, ...} |
| `status` | string | Yes | 'active', 'temporarily_closed', 'permanently_closed' (default: 'active') |
| `created_at` | timestamp | Yes | Creation timestamp |
| `updated_at` | timestamp | Yes | Last update timestamp |

**Indexes**:
- `merchant_id` + `status` (composite)
- `location` (geohash for nearby queries)

**Security Rules**:
- Read: Anyone authenticated
- Write: Owner merchant or admin

---

### 10. Campaign

**Collection**: `campaigns`

**Purpose**: Push notification campaigns.

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Auto-generated campaign ID |
| `title` | string | Yes | Campaign title |
| `message` | string | Yes | Notification message |
| `target_segment` | string | Yes | 'all', 'premium', 'free', 'inactive_users', 'specific_users' |
| `target_user_ids` | array | No | Specific user IDs (if target_segment = 'specific_users') |
| `action_type` | string | No | 'open_offer', 'open_url', 'open_screen' |
| `action_data` | map | No | Action parameters (offer_id, url, screen_name) |
| `scheduled_at` | timestamp | Yes | Scheduled send time |
| `sent_at` | timestamp | No | Actual send time |
| `status` | string | Yes | 'draft', 'scheduled', 'sending', 'sent', 'failed' (default: 'draft') |
| `total_recipients` | number | Yes | Total users targeted (default: 0) |
| `total_sent` | number | Yes | Successfully sent (default: 0) |
| `total_failed` | number | Yes | Failed deliveries (default: 0) |
| `total_opened` | number | Yes | Notifications opened (default: 0) |
| `created_by` | string | Yes | Admin ID who created campaign |
| `created_at` | timestamp | Yes | Creation timestamp |

**Indexes**:
- `status` + `scheduled_at` ASC (composite - for processing)
- `created_at` DESC (for listing)

**Security Rules**:
- Read: Admins only
- Write: Admins only

---

### 11. Referral

**Collection**: `referrals`

**Purpose**: Track referral relationships and rewards.

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Auto-generated referral ID |
| `referrer_id` | string | Yes | User who referred |
| `referee_id` | string | Yes | User who was referred |
| `referral_code` | string | Yes | Code used |
| `status` | string | Yes | 'pending', 'completed', 'invalid' (default: 'pending') |
| `referrer_points_awarded` | number | Yes | Points given to referrer (default: 500) |
| `referee_points_awarded` | number | Yes | Points given to referee (default: 100) |
| `completed_at` | timestamp | No | When both parties received points |
| `created_at` | timestamp | Yes | Referral timestamp |

**Indexes**:
- `referrer_id` + `created_at` DESC (composite)
- `referee_id` (unique - one referral per user)
- `status` + `created_at` (composite)

**Security Rules**:
- Read: Own referrals only (referrer or referee) or admin
- Write: Cloud Functions only

---

### 12. Review

**Collection**: `reviews`

**Purpose**: Customer reviews for merchants/offers.

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Auto-generated review ID |
| `user_id` | string | Yes | Customer ID |
| `merchant_id` | string | Yes | Merchant ID |
| `offer_id` | string | No | Specific offer ID (optional) |
| `redemption_id` | string | No | Related redemption |
| `rating` | number | Yes | 1-5 stars |
| `comment` | string | No | Review text |
| `status` | string | Yes | 'published', 'pending_moderation', 'rejected' (default: 'pending_moderation') |
| `merchant_response` | string | No | Merchant reply to review |
| `merchant_responded_at` | timestamp | No | Response timestamp |
| `created_at` | timestamp | Yes | Review timestamp |
| `updated_at` | timestamp | Yes | Last update timestamp |

**Indexes**:
- `merchant_id` + `created_at` DESC (composite)
- `user_id` + `created_at` DESC (composite)
- `status` + `created_at` DESC (composite)

**Security Rules**:
- Read: Anyone authenticated
- Create: Authenticated customers only
- Update: Own review (customer) or merchant response (merchant)
- Delete: Admin only

---

### 13. OTP

**Collection**: `otps`

**Purpose**: Temporary OTP codes for phone verification.

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Auto-generated OTP ID |
| `phone` | string | Yes | Phone number (E.164 format) |
| `code` | string | Yes | 6-digit OTP code |
| `expires_at` | timestamp | Yes | Expiry time (10 minutes after generation) |
| `verified` | boolean | Yes | Verification status (default: false) |
| `verified_at` | timestamp | No | Verification timestamp |
| `attempts` | number | Yes | Verification attempts (default: 0) |
| `created_at` | timestamp | Yes | Generation timestamp |

**Indexes**:
- `phone` + `expires_at` DESC (composite)
- `expires_at` ASC (for cleanup)

**Security Rules**:
- Read: Admin only
- Write: Cloud Functions only

**Lifecycle**:
- Generated on signup/login
- Valid for 10 minutes
- Max 3 verification attempts
- Auto-cleanup after expiry

---

### 14. Analytics Daily

**Collection**: `analytics_daily`

**Purpose**: Daily aggregated statistics.

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Date in YYYY-MM-DD format |
| `date` | timestamp | Yes | Date timestamp |
| `metrics` | map | Yes | Daily metrics (see below) |
| `calculated_at` | timestamp | Yes | Calculation timestamp |

**Metrics Structure**:
```javascript
{
  users: {
    total: 10000,
    new_signups: 50,
    active_today: 500,
    premium_users: 200
  },
  merchants: {
    total: 150,
    active: 140,
    new_signups: 2
  },
  offers: {
    total: 500,
    active: 450,
    new_created: 10
  },
  redemptions: {
    total_today: 100,
    total_this_week: 600,
    total_this_month: 2500
  },
  points: {
    issued_today: 50000,
    spent_today: 30000
  },
  revenue: {
    subscriptions_today: 249.50,
    total_this_month: 5000.00
  }
}
```

**Indexes**:
- `date` DESC (for time series queries)

**Security Rules**:
- Read: Admins only
- Write: Cloud Functions only

---

### 15. Audit Log

**Collection**: `audit_logs`

**Purpose**: System audit trail for compliance.

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Auto-generated log ID |
| `action` | string | Yes | Action performed |
| `actor_id` | string | Yes | User who performed action |
| `actor_type` | string | Yes | 'customer', 'merchant', 'admin', 'system' |
| `resource_type` | string | Yes | 'offer', 'user', 'merchant', 'redemption', etc. |
| `resource_id` | string | Yes | Affected resource ID |
| `changes` | map | No | Before/after values |
| `ip_address` | string | No | Client IP address |
| `user_agent` | string | No | Client user agent |
| `timestamp` | timestamp | Yes | Action timestamp |

**Indexes**:
- `actor_id` + `timestamp` DESC (composite)
- `resource_type` + `resource_id` + `timestamp` DESC (composite)
- `timestamp` DESC (for log viewing)

**Retention**: 90 days

**Security Rules**:
- Read: Admins only
- Write: Cloud Functions only

---

## Relationships

### Entity Relationship Diagram

```
Customer (1) ──────< (*) Redemption
    │                       │
    │                       ├──────> (1) Offer
    │                       └──────> (1) Merchant
    │
    ├──────< (*) Transaction
    ├──────< (*) QR Token
    ├──────< (*) Subscription
    ├──────< (*) Review
    └──────< (*) Referral (as referrer or referee)

Merchant (1) ──────< (*) Offer
    │
    ├──────< (*) Branch
    ├──────< (*) Redemption
    └──────< (*) Review

Offer (1) ──────< (*) Redemption
    │
    ├──────< (*) QR Token
    └──────< (*) Review

Admin (1) ──────< (*) Audit Log
    │
    └──────< (*) Campaign
```

---

## Data Validation Rules

### Common Patterns

```typescript
// Email validation
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Phone validation (E.164 format)
const phoneRegex = /^\+[1-9]\d{1,14}$/;

// Referral code (6 alphanumeric characters)
const referralCodeRegex = /^[A-Z0-9]{6}$/;

// Points balance (non-negative integer)
const pointsValidator = (value: number) => value >= 0 && Number.isInteger(value);

// Percentage (0-100)
const percentageValidator = (value: number) => value >= 0 && value <= 100;

// Rating (1-5 stars)
const ratingValidator = (value: number) => value >= 1 && value <= 5;
```

---

## Data Migration Strategy

When adding new fields or changing schema:

1. **Additive Changes**: Add new optional fields without touching existing data
2. **Firestore Migration Script**: Create script to update all existing documents
3. **Backward Compatibility**: Ensure old app versions can handle new schema
4. **Gradual Rollout**: Deploy backend changes before client updates

---

**Document Version**: 1.0
**Last Updated**: November 2025
**Target Audience**: Backend developers, database administrators
